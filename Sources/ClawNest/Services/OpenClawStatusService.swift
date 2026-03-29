import Foundation

protocol OpenClawStatusServing: Sendable {
    func refresh() async -> OpenClawStatusSnapshot
}

protocol GatewayHealthChecking: Sendable {
    func check(url: URL) async -> GatewayHealthCheckResult
}

struct GatewayHealthCheckResult: Equatable, Sendable {
    let isReachable: Bool
    let health: GatewayHealthStatus
}

struct OpenClawStatusService: OpenClawStatusServing {
    private let defaults: OpenClawDefaults
    private let runner: CommandRunning
    private let commandResolver: any CommandResolving
    private let environmentProvider: any CommandEnvironmentProviding
    private let gatewayChecker: any GatewayHealthChecking
    private let interpreter: OpenClawStatusInterpreter

    init(
        defaults: OpenClawDefaults = .standard(),
        runner: CommandRunning = ProcessCommandRunner(),
        commandResolver: (any CommandResolving)? = nil,
        environmentProvider: (any CommandEnvironmentProviding)? = nil,
        gatewayChecker: any GatewayHealthChecking = URLSessionGatewayHealthChecker(),
        interpreter: OpenClawStatusInterpreter = OpenClawStatusInterpreter()
    ) {
        self.defaults = defaults
        self.runner = runner
        self.commandResolver = commandResolver ?? ShellCommandResolver(runner: runner)
        self.environmentProvider = environmentProvider ?? ShellCommandEnvironmentProvider(runner: runner)
        self.gatewayChecker = gatewayChecker
        self.interpreter = interpreter
    }

    func refresh() async -> OpenClawStatusSnapshot {
        let openClawCommand = await commandResolver.resolve(defaults.openClawCommand) ?? defaults.openClawCommand
        let executionEnvironment = await environmentProvider.executionEnvironment()

        async let probeResult = runner.run(
            command: openClawCommand,
            arguments: ["gateway", "status"],
            environment: executionEnvironment
        )
        async let gatewayCheck = gatewayChecker.check(url: defaults.gatewayURL)

        return interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: await probeResult,
            gatewayCheck: await gatewayCheck,
            checkedAt: Date()
        )
    }
}

struct OpenClawStatusInterpreter {
    func makeSnapshot(
        defaults: OpenClawDefaults,
        commandResult: CommandResult,
        gatewayCheck: GatewayHealthCheckResult,
        checkedAt: Date = .now
    ) -> OpenClawStatusSnapshot {
        OpenClawStatusSnapshot(
            runtimeStatus: runtimeStatus(from: commandResult, gatewayCheck: gatewayCheck),
            lastCheckedAt: checkedAt,
            gateway: GatewayStatusDetails(
                url: defaults.gatewayURL,
                port: defaults.port,
                health: gatewayCheck.health
            ),
            paths: defaults.paths
        )
    }

    private func runtimeStatus(
        from commandResult: CommandResult,
        gatewayCheck: GatewayHealthCheckResult
    ) -> OpenClawRuntimeStatus {
        let probeState = probeState(from: commandResult)

        if probeState == .running || gatewayCheck.isReachable {
            return .running
        }

        if probeState == .stopped {
            return .stopped
        }

        if isMissingCommand(commandResult) && !gatewayCheck.isReachable {
            return .stopped
        }

        return .unknown
    }

    private func probeState(from result: CommandResult) -> ProbeState {
        if isMissingCommand(result) {
            return .stopped
        }

        let combinedText = [result.stdout, result.stderr, result.launchError]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let runtimeLine = lineValue(in: result.stdout, forPrefix: "runtime:")
        let rpcProbeLine = lineValue(in: result.stdout, forPrefix: "rpc probe:")
        let listeningLine = lineValue(in: result.stdout, forPrefix: "listening:")
        let lastGatewayErrorLine = lineValue(in: result.stdout, forPrefix: "last gateway error:")

        if containsAny(of: "ok healthy ready running reachable", in: rpcProbeLine) {
            return .running
        }

        if containsAny(of: "127.0.0.1 localhost loopback http ws", in: listeningLine),
           !containsAny(of: "none no not", in: listeningLine) {
            return .running
        }

        if containsAnyPhrase(
            ["stopped", "not running", "unloaded", "missing", "absent", "inactive", "not installed"],
            in: runtimeLine
        ) {
            return .stopped
        }

        if containsAnyPhrase(["running", "active", "loaded"], in: runtimeLine),
           containsAnyPhrase(
            ["failed", "error", "refused", "timeout", "unreachable", "down"],
            in: rpcProbeLine + " " + lastGatewayErrorLine
           ) {
            return .unknown
        }

        if containsAny(of: "offline stopped unhealthy failed refused timeout error", in: combinedText) {
            return .stopped
        }

        if result.exitCode != 0 && !combinedText.isEmpty {
            return .stopped
        }

        return .unknown
    }

    private func isMissingCommand(_ result: CommandResult) -> Bool {
        if result.exitCode == 127 {
            return true
        }

        let errorText = [result.stderr, result.launchError ?? ""]
            .joined(separator: " ")
            .lowercased()

        return errorText.contains("command not found")
            || errorText.contains("not found")
            || errorText.contains("no such file")
    }

    private func containsAny(of needleList: String, in text: String) -> Bool {
        needleList
            .split(separator: " ")
            .contains { text.contains($0) }
    }

    private func containsAnyPhrase(_ phrases: [String], in text: String) -> Bool {
        phrases.contains { text.contains($0) }
    }

    private func lineValue(in text: String, forPrefix prefix: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { $0.hasPrefix(prefix) }?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private enum ProbeState {
        case running
        case stopped
        case unknown
    }
}

struct URLSessionGatewayHealthChecker: GatewayHealthChecking {
    func check(url: URL) async -> GatewayHealthCheckResult {
        let healthURL = url.appendingPathComponent("health", isDirectory: false)

        if let healthResult = await request(url: healthURL, expectsHealthPayload: true) {
            return healthResult
        }

        if let reachabilityResult = await request(url: url, expectsHealthPayload: false) {
            return reachabilityResult
        }

        return GatewayHealthCheckResult(
            isReachable: false,
            health: .unhealthy
        )
    }

    private func request(url: URL, expectsHealthPayload: Bool) async -> GatewayHealthCheckResult? {
        do {
            let (data, response) = try await performRequest(url: url)
            let body = String(decoding: data, as: UTF8.self).lowercased()

            if expectsHealthPayload {
                if response.statusCode == 404 {
                    return nil
                }

                if (200 ... 299).contains(response.statusCode),
                   (body.isEmpty || containsAny(of: "ok healthy ready running", in: body)) {
                    return GatewayHealthCheckResult(isReachable: true, health: .healthy)
                }

                if (500 ... 599).contains(response.statusCode)
                    || containsAny(of: "unhealthy offline failed error", in: body) {
                    return GatewayHealthCheckResult(isReachable: true, health: .unhealthy)
                }

                return GatewayHealthCheckResult(isReachable: true, health: .unavailable)
            }

            return GatewayHealthCheckResult(isReachable: true, health: .unavailable)
        } catch {
            return nil
        }
    }

    private func performRequest(url: URL) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, httpResponse)
    }

    private func containsAny(of needleList: String, in text: String) -> Bool {
        needleList
            .split(separator: " ")
            .contains { text.contains($0) }
    }
}
