import Foundation

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
    let installedCommand: String
    let summary: String
}

enum OpenClawInstallError: LocalizedError {
    case installScriptFailed(String)
    case missingOpenClawBinary
    case filesystemFailure(String)

    var errorDescription: String? {
        switch self {
        case let .installScriptFailed(message),
             let .filesystemFailure(message):
            return message
        case .missingOpenClawBinary:
            return "OpenClaw finished installing, but the `openclaw` executable still could not be found."
        }
    }
}

actor OpenClawInstaller {
    private let runner: CommandRunning
    private let registryStore: InstalledOpenClawInstanceStoring

    init(
        runner: CommandRunning = ProcessCommandRunner(),
        registryStore: InstalledOpenClawInstanceStoring = UserDefaultsInstalledOpenClawInstanceStore(),
        portInspector: PortInspector = PortInspector(),
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        _ = portInspector
        _ = homeDirectory
        self.runner = runner
        self.registryStore = registryStore
    }

    func snapshot(for draft: OpenClawInstallDraft) -> OpenClawInstallerSnapshot {
        _ = draft
        let knownInstances = registryStore.load().sorted { $0.gatewayPort < $1.gatewayPort }

        return OpenClawInstallerSnapshot(
            validation: OpenClawInstallValidation(
                isValid: true,
                message: "ClawNest will install or reuse the official OpenClaw CLI. After that, continue with `openclaw onboard --install-daemon` to configure workspace, gateway, and the LaunchAgent the official way.",
                preview: nil
            ),
            knownInstances: knownInstances
        )
    }

    func install(draft: OpenClawInstallDraft) async throws -> OpenClawInstallResult {
        _ = draft
        let openClawExecutable = try await ensureOpenClawInstalled()

        return OpenClawInstallResult(
            installedCommand: openClawExecutable,
            summary: "OpenClaw CLI is installed and available to system terminals. Continue with `openclaw onboard --install-daemon` to configure the gateway and background service the official way."
        )
    }

    private func ensureOpenClawInstalled() async throws -> String {
        if let existingExecutable = await resolveExecutable(named: "openclaw") {
            return existingExecutable
        }

        let installCommand = "curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard"
        let installResult = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", installCommand]
        )

        if installResult.exitCode != 0 {
            let output = cleanedInstallerOutput(from: installResult)
                .ifEmpty("The official installer exited without producing output.")
            throw OpenClawInstallError.installScriptFailed(output)
        }

        if let installedExecutable = await resolveExecutable(named: "openclaw") {
            return installedExecutable
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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
