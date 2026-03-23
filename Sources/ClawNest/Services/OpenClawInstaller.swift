import Foundation
import Darwin

struct ReservedPort: Identifiable, Equatable, Codable, Sendable {
    let port: Int
    let purpose: String

    var id: Int { port }
}

struct OpenClawInstallDraft: Equatable, Sendable {
    var installDirectoryPath: String
    var gatewayPortText: String

    static func suggestedDefault() -> OpenClawInstallDraft {
        let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("ClawNest", isDirectory: true)
            .appendingPathComponent("openclaw-19789", isDirectory: true)

        return OpenClawInstallDraft(
            installDirectoryPath: baseDirectory.path,
            gatewayPortText: "19789"
        )
    }
}

struct OpenClawInstallPreview: Equatable, Sendable {
    let installDirectoryPath: String
    let stateDirectoryPath: String
    let workspaceDirectoryPath: String
    let logsDirectoryPath: String
    let configPath: String
    let launchAgentLabel: String
    let reservedPorts: [ReservedPort]
}

struct OpenClawInstallValidation: Equatable, Sendable {
    let isValid: Bool
    let message: String
    let preview: OpenClawInstallPreview?

    static let idle = OpenClawInstallValidation(
        isValid: false,
        message: "Choose an install directory and a unique gateway port.",
        preview: nil
    )
}

struct InstalledOpenClawInstance: Codable, Identifiable, Equatable, Sendable {
    let installDirectoryPath: String
    let stateDirectoryPath: String
    let workspaceDirectoryPath: String
    let gatewayPort: Int
    let launchAgentLabel: String
    let dashboardURLString: String
    let reservedPorts: [Int]
    let installedAt: Date

    var id: String { installDirectoryPath }
}

struct OpenClawInstallerSnapshot: Sendable {
    let validation: OpenClawInstallValidation
    let knownInstances: [InstalledOpenClawInstance]
}

struct OpenClawInstallResult: Sendable {
    let instance: InstalledOpenClawInstance
    let suggestedConfiguration: ClawNestConfiguration
    let summary: String
}

enum OpenClawInstallError: LocalizedError {
    case invalidInput(String)
    case conflictingPort(String)
    case installScriptFailed(String)
    case missingOpenClawBinary
    case missingGit(String)
    case filesystemFailure(String)
    case launchAgentFailure(String)

    var errorDescription: String? {
        switch self {
        case let .invalidInput(message),
             let .conflictingPort(message),
             let .installScriptFailed(message),
             let .missingGit(message),
             let .filesystemFailure(message),
             let .launchAgentFailure(message):
            return message
        case .missingOpenClawBinary:
            return "OpenClaw finished installing, but the `openclaw` executable still could not be found."
        }
    }
}

actor OpenClawInstaller {
    private let runner: CommandRunning
    private let registryStore: InstalledOpenClawInstanceStoring
    private let portInspector: PortInspector
    private let homeDirectory: URL

    init(
        runner: CommandRunning = ProcessCommandRunner(),
        registryStore: InstalledOpenClawInstanceStoring = UserDefaultsInstalledOpenClawInstanceStore(),
        portInspector: PortInspector = PortInspector(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.runner = runner
        self.registryStore = registryStore
        self.portInspector = portInspector
        self.homeDirectory = homeDirectory
    }

    func snapshot(for draft: OpenClawInstallDraft) -> OpenClawInstallerSnapshot {
        let knownInstances = registryStore.load().sorted { $0.gatewayPort < $1.gatewayPort }

        do {
            let plan = try makePlan(from: draft)
            let conflicts = try conflicts(for: plan, knownInstances: knownInstances)

            if let firstConflict = conflicts.first {
                return OpenClawInstallerSnapshot(
                    validation: OpenClawInstallValidation(
                        isValid: false,
                        message: firstConflict,
                        preview: plan.preview
                    ),
                    knownInstances: knownInstances
                )
            }

            return OpenClawInstallerSnapshot(
                validation: OpenClawInstallValidation(
                    isValid: true,
                    message: "OpenClaw can be installed here. ClawNest will reserve the listed ports and create an isolated state/workspace layout.",
                    preview: plan.preview
                ),
                knownInstances: knownInstances
            )
        } catch {
            return OpenClawInstallerSnapshot(
                validation: OpenClawInstallValidation(
                    isValid: false,
                    message: error.localizedDescription,
                    preview: nil
                ),
                knownInstances: knownInstances
            )
        }
    }

    func install(draft: OpenClawInstallDraft) async throws -> OpenClawInstallResult {
        let knownInstances = registryStore.load()
        let plan = try makePlan(from: draft)
        let conflicts = try conflicts(for: plan, knownInstances: knownInstances)

        if let firstConflict = conflicts.first {
            throw OpenClawInstallError.conflictingPort(firstConflict)
        }

        let openClawExecutable = try await ensureOpenClawInstalled(for: plan)
        let nodeExecutable = await resolveExecutable(named: "node")

        do {
            try createDirectories(for: plan)
            try writeConfig(for: plan)
            let launchEnvironment = launchAgentEnvironment(
                plan: plan,
                openClawExecutable: openClawExecutable,
                nodeExecutable: nodeExecutable
            )
            try writeLaunchAgent(
                for: plan,
                openClawExecutable: openClawExecutable,
                environment: launchEnvironment
            )
            try await activateLaunchAgent(for: plan)
        } catch let error as OpenClawInstallError {
            throw error
        } catch {
            throw OpenClawInstallError.filesystemFailure(error.localizedDescription)
        }

        let instance = InstalledOpenClawInstance(
            installDirectoryPath: plan.installDirectory.path,
            stateDirectoryPath: plan.stateDirectory.path,
            workspaceDirectoryPath: plan.workspaceDirectory.path,
            gatewayPort: plan.gatewayPort,
            launchAgentLabel: plan.launchAgentLabel,
            dashboardURLString: plan.dashboardURL.absoluteString,
            reservedPorts: plan.reservedPorts.map(\.port),
            installedAt: .now
        )
        registryStore.upsert(instance)

        let configuration = ClawNestConfiguration(
            openClawCommand: openClawExecutable,
            dashboardURLString: instance.dashboardURLString,
            launchAgentLabel: instance.launchAgentLabel,
            probeIntervalSeconds: 45,
            autoRestartEnabled: false
        )

        return OpenClawInstallResult(
            instance: instance,
            suggestedConfiguration: configuration,
            summary: "OpenClaw was installed into \(plan.installDirectory.path) and attached to ClawNest on port \(plan.gatewayPort)."
        )
    }

    private func makePlan(from draft: OpenClawInstallDraft) throws -> OpenClawInstallPlan {
        let trimmedPath = NSString(string: draft.installDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        guard !trimmedPath.isEmpty else {
            throw OpenClawInstallError.invalidInput("Pick an install directory for this OpenClaw instance.")
        }

        guard let gatewayPort = Int(draft.gatewayPortText), (1024 ... 65000).contains(gatewayPort) else {
            throw OpenClawInstallError.invalidInput("Gateway port must be an integer between 1024 and 65000.")
        }

        let installDirectory = URL(fileURLWithPath: trimmedPath, isDirectory: true)
        let stateDirectory = installDirectory.appendingPathComponent("state", isDirectory: true)
        let workspaceDirectory = installDirectory.appendingPathComponent("workspace", isDirectory: true)
        let logsDirectory = installDirectory.appendingPathComponent("logs", isDirectory: true)
        let configPath = stateDirectory.appendingPathComponent("openclaw.json")
        let launchAgentLabel = "ai.clawnest.openclaw.\(gatewayPort)"
        let launchAgentPlistURL = homeDirectory
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(launchAgentLabel).plist")
        let dashboardURL = URL(string: "http://127.0.0.1:\(gatewayPort)/")!
        let reservedPorts = Self.reservedPorts(forGatewayPort: gatewayPort)

        if reservedPorts.contains(where: { $0.port > 65535 }) {
            throw OpenClawInstallError.invalidInput("Port \(gatewayPort) leaves too little room for OpenClaw's derived browser ports. Choose a lower gateway port.")
        }

        return OpenClawInstallPlan(
            installDirectory: installDirectory,
            stateDirectory: stateDirectory,
            workspaceDirectory: workspaceDirectory,
            logsDirectory: logsDirectory,
            configPath: configPath,
            gatewayPort: gatewayPort,
            dashboardURL: dashboardURL,
            launchAgentLabel: launchAgentLabel,
            launchAgentPlistURL: launchAgentPlistURL,
            reservedPorts: reservedPorts
        )
    }

    private func conflicts(
        for plan: OpenClawInstallPlan,
        knownInstances: [InstalledOpenClawInstance]
    ) throws -> [String] {
        var messages: [String] = []
        let plannedPorts = Set(plan.reservedPorts.map(\.port))

        for instance in knownInstances where instance.installDirectoryPath != plan.installDirectory.path {
            let overlap = plannedPorts.intersection(instance.reservedPorts)
            if !overlap.isEmpty {
                messages.append(
                    "This install would reuse ports \(overlap.sorted().map(String.init).joined(separator: ", ")) already reserved by \(instance.installDirectoryPath)."
                )
            }
        }

        let unavailable = portInspector.unavailableReservations(in: plan.reservedPorts)
        if let firstUnavailable = unavailable.first {
            messages.append("Port \(firstUnavailable.port) (\(firstUnavailable.purpose)) is already in use on this machine.")
        }

        return messages
    }

    private func ensureOpenClawInstalled(for plan: OpenClawInstallPlan) async throws -> String {
        let prefixedOpenClawPath = plan.installDirectory.appendingPathComponent("bin/openclaw").path

        if FileManager.default.isExecutableFile(atPath: prefixedOpenClawPath) {
            return prefixedOpenClawPath
        }

        guard await resolveExecutable(named: "git") != nil else {
            throw OpenClawInstallError.missingGit(
                "Git is not available on this Mac yet. ClawNest now uses OpenClaw's local-prefix installer, but that installer still requires Git. Install Apple's Command Line Tools first with `xcode-select --install`, then retry."
            )
        }

        let installCommand = "curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install-cli.sh | bash -s -- --json --no-onboard --prefix '\(shellQuoted(plan.installDirectory.path))'"
        let installResult = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", installCommand]
        )

        if installResult.exitCode != 0 {
            let output = cleanedInstallerOutput(from: installResult)
                .ifEmpty("The official local-prefix installer exited without producing output.")
            throw OpenClawInstallError.installScriptFailed(output)
        }

        if FileManager.default.isExecutableFile(atPath: prefixedOpenClawPath) {
            return prefixedOpenClawPath
        }

        throw OpenClawInstallError.missingOpenClawBinary
    }

    private func resolveExecutable(named binary: String) async -> String? {
        let result = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", "command -v \(binary)"]
        )

        guard result.exitCode == 0 else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func createDirectories(for plan: OpenClawInstallPlan) throws {
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: plan.installDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: plan.stateDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: plan.workspaceDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: plan.logsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: plan.launchAgentPlistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func writeConfig(for plan: OpenClawInstallPlan) throws {
        let config: [String: Any] = [
            "gateway": [
                "bind": "loopback",
                "mode": "local",
                "port": plan.gatewayPort
            ],
            "agents": [
                "defaults": [
                    "workspace": plan.workspaceDirectory.path
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: plan.configPath, options: .atomic)
    }

    private func writeLaunchAgent(
        for plan: OpenClawInstallPlan,
        openClawExecutable: String,
        environment: [String: String]
    ) throws {
        let plist: [String: Any] = [
            "Label": plan.launchAgentLabel,
            "ProgramArguments": [
                openClawExecutable,
                "gateway",
                "--port",
                String(plan.gatewayPort),
                "--bind",
                "loopback"
            ],
            "RunAtLoad": true,
            "KeepAlive": true,
            "WorkingDirectory": plan.installDirectory.path,
            "EnvironmentVariables": environment,
            "StandardOutPath": plan.logsDirectory.appendingPathComponent("gateway.stdout.log").path,
            "StandardErrorPath": plan.logsDirectory.appendingPathComponent("gateway.stderr.log").path
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plan.launchAgentPlistURL, options: .atomic)
    }

    private func launchAgentEnvironment(
        plan: OpenClawInstallPlan,
        openClawExecutable: String,
        nodeExecutable: String?
    ) -> [String: String] {
        var pathComponents: [String] = []
        pathComponents.append(URL(fileURLWithPath: openClawExecutable).deletingLastPathComponent().path)
        if let nodeExecutable {
            pathComponents.append(URL(fileURLWithPath: nodeExecutable).deletingLastPathComponent().path)
        }
        if let existingPath = ProcessInfo.processInfo.environment["PATH"] {
            pathComponents.append(existingPath)
        }
        pathComponents.append("/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")

        let mergedPath = pathComponents
            .flatMap { $0.split(separator: ":").map(String.init) }
            .reduce(into: [String]()) { acc, item in
                if !acc.contains(item) {
                    acc.append(item)
                }
            }
            .joined(separator: ":")

        return [
            "OPENCLAW_STATE_DIR": plan.stateDirectory.path,
            "OPENCLAW_CONFIG_PATH": plan.configPath.path,
            "PATH": mergedPath,
            "HOME": homeDirectory.path
        ]
    }

    private func cleanedInstallerOutput(from result: CommandResult) -> String {
        let output = result.combinedOutput.ifEmpty(result.launchError ?? "")
        return stripANSIEscapes(from: output)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func stripANSIEscapes(from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private func shellQuoted(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "'\"'\"'")
    }

    private func activateLaunchAgent(for plan: OpenClawInstallPlan) async throws {
        let domain = "gui/\(getuid())"

        _ = await runner.run(
            command: "launchctl",
            arguments: ["bootout", domain, plan.launchAgentPlistURL.path]
        )

        let bootstrap = await runner.run(
            command: "launchctl",
            arguments: ["bootstrap", domain, plan.launchAgentPlistURL.path]
        )
        guard bootstrap.exitCode == 0 else {
            throw OpenClawInstallError.launchAgentFailure(
                bootstrap.combinedOutput.ifEmpty("launchctl bootstrap failed for \(plan.launchAgentLabel).")
            )
        }

        let kickstart = await runner.run(
            command: "launchctl",
            arguments: ["kickstart", "-k", "\(domain)/\(plan.launchAgentLabel)"]
        )
        guard kickstart.exitCode == 0 else {
            throw OpenClawInstallError.launchAgentFailure(
                kickstart.combinedOutput.ifEmpty("launchctl kickstart failed for \(plan.launchAgentLabel).")
            )
        }
    }

    private static func reservedPorts(forGatewayPort gatewayPort: Int) -> [ReservedPort] {
        var ports: [ReservedPort] = [
            ReservedPort(port: gatewayPort, purpose: "Gateway HTTP + Control UI"),
            ReservedPort(port: gatewayPort + 2, purpose: "Browser control service")
        ]

        for port in (gatewayPort + 11) ... (gatewayPort + 110) {
            ports.append(ReservedPort(port: port, purpose: "Browser CDP pool"))
        }

        return ports
    }
}

protocol InstalledOpenClawInstanceStoring {
    func load() -> [InstalledOpenClawInstance]
    func save(_ instances: [InstalledOpenClawInstance])
    func upsert(_ instance: InstalledOpenClawInstance)
}

struct UserDefaultsInstalledOpenClawInstanceStore: InstalledOpenClawInstanceStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [InstalledOpenClawInstance] {
        guard let data = defaults.data(forKey: Keys.instances),
              let instances = try? JSONDecoder().decode([InstalledOpenClawInstance].self, from: data)
        else {
            return []
        }

        return instances
    }

    func save(_ instances: [InstalledOpenClawInstance]) {
        guard let data = try? JSONEncoder().encode(instances) else { return }
        defaults.set(data, forKey: Keys.instances)
    }

    func upsert(_ instance: InstalledOpenClawInstance) {
        var instances = load()

        if let existingIndex = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[existingIndex] = instance
        } else {
            instances.append(instance)
        }

        save(instances.sorted { $0.gatewayPort < $1.gatewayPort })
    }
}

private enum Keys {
    static let instances = "clawnest.installedOpenClawInstances"
}

struct PortInspector {
    private let availabilityProbe: @Sendable (Int) -> Bool

    init(availabilityProbe: @escaping @Sendable (Int) -> Bool = PortInspector.defaultAvailabilityProbe(_:)) {
        self.availabilityProbe = availabilityProbe
    }

    func unavailableReservations(in reservations: [ReservedPort]) -> [ReservedPort] {
        reservations.filter { !availabilityProbe($0.port) }
    }

    private static func defaultAvailabilityProbe(_ port: Int) -> Bool {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return false }
        defer { close(socketDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { reboundPointer in
                bind(socketDescriptor, reboundPointer, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }

        return bindResult == 0
    }
}

private struct OpenClawInstallPlan {
    let installDirectory: URL
    let stateDirectory: URL
    let workspaceDirectory: URL
    let logsDirectory: URL
    let configPath: URL
    let gatewayPort: Int
    let dashboardURL: URL
    let launchAgentLabel: String
    let launchAgentPlistURL: URL
    let reservedPorts: [ReservedPort]

    var preview: OpenClawInstallPreview {
        OpenClawInstallPreview(
            installDirectoryPath: installDirectory.path,
            stateDirectoryPath: stateDirectory.path,
            workspaceDirectoryPath: workspaceDirectory.path,
            logsDirectoryPath: logsDirectory.path,
            configPath: configPath.path,
            launchAgentLabel: launchAgentLabel,
            reservedPorts: reservedPorts
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
