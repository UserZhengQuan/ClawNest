import Foundation

protocol OpenClawStatusServing: Sendable {
    func refresh() async -> OpenClawStatusSnapshot
    func diagnosticStatus() async -> CommandResult
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
        let executionContext = await resolvedExecutionContext()
        async let probeResult = runner.run(
            command: executionContext.command,
            arguments: ["gateway", "status", "--json"],
            environment: executionContext.environment
        )
        async let gatewayCheck = gatewayChecker.check(url: defaults.gatewayURL)

        return interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: await probeResult,
            gatewayCheck: await gatewayCheck,
            checkedAt: Date()
        )
    }

    func diagnosticStatus() async -> CommandResult {
        let executionContext = await resolvedExecutionContext()
        return await runner.run(
            command: executionContext.command,
            arguments: ["gateway", "status"],
            environment: executionContext.environment
        )
    }

    private func resolvedExecutionContext() async -> (command: String, environment: [String: String]) {
        let openClawCommand = await commandResolver.resolve(defaults.openClawCommand) ?? defaults.openClawCommand
        let executionEnvironment = await environmentProvider.executionEnvironment()
        return (command: openClawCommand, environment: executionEnvironment)
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
        if isMissingCommand(commandResult) {
            if gatewayCheck.health == .healthy {
                return .running
            }

            return gatewayCheck.isReachable ? .unknown : .stopped
        }

        let probeState = probeState(from: commandResult)

        if probeState == .running {
            return .running
        }

        if probeState == .stopped {
            return gatewayCheck.isReachable ? .unknown : .stopped
        }

        if gatewayCheck.health == .healthy {
            return .running
        }

        if gatewayCheck.isReachable {
            return .unknown
        }

        return .unknown
    }

    private func probeState(from result: CommandResult) -> ProbeState {
        if isMissingCommand(result) {
            return .stopped
        }

        let probeSnapshot = extractedProbeSnapshot(from: result.stdout)
        let combinedText = [result.stdout, result.stderr, result.launchError]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let runtimeLine = probeSnapshot.runtime
        let rpcProbeLine = probeSnapshot.rpcProbe
        let listeningLine = probeSnapshot.listening
        let lastGatewayErrorLine = probeSnapshot.lastGatewayError

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

    private func extractedProbeSnapshot(from output: String) -> ProbeSnapshot {
        if let jsonSnapshot = probeSnapshotFromJSON(output) {
            return jsonSnapshot
        }

        return ProbeSnapshot(
            runtime: lineValue(in: output, forPrefix: "runtime:"),
            rpcProbe: lineValue(in: output, forPrefix: "rpc probe:"),
            listening: lineValue(in: output, forPrefix: "listening:"),
            lastGatewayError: lineValue(in: output, forPrefix: "last gateway error:")
        )
    }

    private func probeSnapshotFromJSON(_ output: String) -> ProbeSnapshot? {
        guard let json = parsedJSONObject(from: output) else {
            return nil
        }

        return ProbeSnapshot(
            runtime: firstString(in: json, preferredKeys: [
                ["runtime"],
                ["service", "runtime"],
                ["service", "status"],
                ["service", "state"],
                ["status", "runtime"]
            ]),
            rpcProbe: firstString(in: json, preferredKeys: [
                ["rpcProbe"],
                ["rpc_probe"],
                ["rpc", "status"],
                ["probe", "status"],
                ["probe"]
            ]),
            listening: firstString(in: json, preferredKeys: [
                ["listening"],
                ["listeners"],
                ["listener"],
                ["gateway", "listening"],
                ["gateway", "listeners"],
                ["url"]
            ]),
            lastGatewayError: firstString(in: json, preferredKeys: [
                ["lastGatewayError"],
                ["last_gateway_error"],
                ["error"],
                ["errors"],
                ["gateway", "error"]
            ])
        )
    }

    private func parsedJSONObject(from text: String) -> Any? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        if let directJSON = parseJSONDocument(trimmedText) {
            return directJSON
        }

        var searchStart = trimmedText.startIndex
        while let candidateStart = firstJSONCandidateStart(in: trimmedText, from: searchStart) {
            if let candidateRange = balancedJSONRange(in: trimmedText, from: candidateStart) {
                let candidate = String(trimmedText[candidateRange])
                if let candidateJSON = parseJSONDocument(candidate) {
                    return candidateJSON
                }
            }

            searchStart = trimmedText.index(after: candidateStart)
        }

        return nil
    }

    private func parseJSONDocument(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data)
    }

    private func firstJSONCandidateStart(in text: String, from start: String.Index) -> String.Index? {
        var index = start
        while index < text.endIndex {
            let character = text[index]
            if character == "{" || character == "[" {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }

    private func balancedJSONRange(in text: String, from start: String.Index) -> Range<String.Index>? {
        guard start < text.endIndex else {
            return nil
        }

        let opening = text[start]
        guard opening == "{" || opening == "[" else {
            return nil
        }

        var stack: [Character] = []
        var inString = false
        var isEscaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                switch character {
                case "\"":
                    inString = true
                case "{", "[":
                    stack.append(character)
                case "}", "]":
                    guard let last = stack.popLast(),
                          matchesJSONDelimiter(opening: last, closing: character) else {
                        return nil
                    }

                    if stack.isEmpty {
                        return start ..< text.index(after: index)
                    }
                default:
                    break
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    private func matchesJSONDelimiter(opening: Character, closing: Character) -> Bool {
        switch (opening, closing) {
        case ("{", "}"), ("[", "]"):
            return true
        default:
            return false
        }
    }

    private func firstString(in json: Any, preferredKeys: [[String]]) -> String {
        for keyPath in preferredKeys {
            if let value = stringValue(in: json, keyPath: keyPath), !value.isEmpty {
                return value.lowercased()
            }
        }

        return ""
    }

    private func stringValue(in json: Any, keyPath: [String]) -> String? {
        guard !keyPath.isEmpty else {
            return flattenedString(from: json)
        }

        guard let dictionary = json as? [String: Any] else {
            return nil
        }

        let nextKey = keyPath[0]
        guard let nextValue = dictionary.first(where: { $0.key.lowercased() == nextKey.lowercased() })?.value else {
            return nil
        }

        return stringValue(in: nextValue, keyPath: Array(keyPath.dropFirst()))
    }

    private func flattenedString(from value: Any) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            let components = array.compactMap(flattenedString(from:))
            return components.isEmpty ? nil : components.joined(separator: ", ")
        case let dictionary as [String: Any]:
            if let status = dictionary["status"] {
                return flattenedString(from: status)
            }
            if let state = dictionary["state"] {
                return flattenedString(from: state)
            }
            if let value = dictionary["value"] {
                return flattenedString(from: value)
            }
            return nil
        default:
            return nil
        }
    }

    private func lineValue(in text: String, forPrefix prefix: String) -> String {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { $0.hasPrefix(prefix) }?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private struct ProbeSnapshot {
        let runtime: String
        let rpcProbe: String
        let listening: String
        let lastGatewayError: String
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
