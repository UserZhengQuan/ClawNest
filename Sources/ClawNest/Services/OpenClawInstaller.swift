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

private struct OpenClawInstallOutcome: Sendable {
    let executablePath: String
    let reusedExistingInstall: Bool
}

private struct OpenClawEnvironmentState: Sendable {
    let existingOpenClawPath: String?
    let developerToolsPath: String?
    let homebrewPath: String?

    var hasDeveloperTools: Bool { developerToolsPath != nil }
    var hasHomebrew: Bool { homebrewPath != nil }
}

private struct OpenClawInstallFailureContext: Sendable {
    let stage: OpenClawInstallStage
    let summary: String
    let recoverySuggestion: String
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

    func install(
        draft: OpenClawInstallDraft,
        progressRelay: OpenClawInstallProgressRelay? = nil
    ) async throws -> OpenClawInstallResult {
        _ = draft
        let outcome = try await ensureOpenClawInstalled(progressRelay: progressRelay)
        let summary: String

        if outcome.reusedExistingInstall {
            summary = "OpenClaw CLI is already available at \(outcome.executablePath). ClawNest reused that command and skipped the official installer."
        } else {
            summary = "OpenClaw CLI is installed and available to system terminals. Continue with `openclaw onboard --install-daemon` to configure the gateway and background service the official way."
        }

        return OpenClawInstallResult(
            installedCommand: outcome.executablePath,
            summary: summary
        )
    }

    private func ensureOpenClawInstalled(
        progressRelay: OpenClawInstallProgressRelay?
    ) async throws -> OpenClawInstallOutcome {
        progressRelay?.send(
            .activate(
                stage: .checkingEnvironment,
                detail: "Inspecting this Mac for an existing OpenClaw CLI, Apple Command Line Tools, and Homebrew."
            )
        )

        let initialEnvironment = await inspectEnvironment()
        progressRelay?.send(
            .complete(
                stage: .checkingEnvironment,
                detail: "Environment check finished. ClawNest now knows which install steps can be skipped."
            )
        )

        if let existingExecutable = initialEnvironment.existingOpenClawPath {
            progressRelay?.send(
                .skip(
                    stage: .installingDeveloperTools,
                    detail: "Skipping prerequisite installs because OpenClaw CLI is already available on this Mac."
                )
            )
            progressRelay?.send(
                .skip(
                    stage: .installingHomebrew,
                    detail: "Skipping prerequisite installs because OpenClaw CLI is already available on this Mac."
                )
            )
            progressRelay?.send(
                .skip(
                    stage: .installingOpenClawCLI,
                    detail: "ClawNest found an existing OpenClaw CLI at \(existingExecutable)."
                )
            )
            progressRelay?.send(
                .activate(
                    stage: .finalizing,
                    detail: "Reusing the existing OpenClaw CLI and updating ClawNest."
                )
            )
            return OpenClawInstallOutcome(
                executablePath: existingExecutable,
                reusedExistingInstall: true
            )
        }

        let progressTracker = OpenClawInstallStageTracker(
            initialEnvironment: initialEnvironment,
            progressRelay: progressRelay
        )
        progressTracker.prepareForInstallerLaunch()

        let installCommand = "curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard"
        let installResult = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", installCommand],
            outputHandler: { chunk in
                progressTracker.consume(chunk)
            }
        )

        if installResult.exitCode != 0 {
            let output = cleanedInstallerOutput(from: installResult)
                .ifEmpty("The official installer exited without producing output.")
            let failure = failureContext(
                for: output,
                currentStage: progressTracker.currentStage,
                initialEnvironment: initialEnvironment
            )
            progressRelay?.send(
                .fail(
                    stage: failure.stage,
                    summary: failure.summary,
                    recoverySuggestion: failure.recoverySuggestion,
                    rawOutput: output
                )
            )
            throw OpenClawInstallError.installScriptFailed(output)
        }

        let postEnvironment = await inspectEnvironment()
        progressTracker.markInstallerSucceeded(postEnvironment: postEnvironment)
        progressRelay?.send(
            .activate(
                stage: .finalizing,
                detail: "Refreshing the CLI path and handing the result back to ClawNest."
            )
        )

        if let installedExecutable = await resolveExecutable(named: "openclaw") {
            return OpenClawInstallOutcome(
                executablePath: installedExecutable,
                reusedExistingInstall: false
            )
        }

        progressRelay?.send(
            .fail(
                stage: .finalizing,
                summary: "The official installer finished, but ClawNest still could not find `openclaw` on PATH.",
                recoverySuggestion: "Open a new terminal to confirm `command -v openclaw`, then retry or add the installed location to PATH manually.",
                rawOutput: nil
            )
        )
        throw OpenClawInstallError.missingOpenClawBinary
    }

    private func inspectEnvironment() async -> OpenClawEnvironmentState {
        async let openClawPath = resolveExecutable(named: "openclaw")
        async let developerToolsPath = resolveDeveloperToolsPath()
        async let homebrewPath = resolveExecutable(named: "brew")

        return await OpenClawEnvironmentState(
            existingOpenClawPath: openClawPath,
            developerToolsPath: developerToolsPath,
            homebrewPath: homebrewPath
        )
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

    private func resolveDeveloperToolsPath() async -> String? {
        let result = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", "xcode-select -p"]
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

    private func failureContext(
        for output: String,
        currentStage: OpenClawInstallStage?,
        initialEnvironment: OpenClawEnvironmentState
    ) -> OpenClawInstallFailureContext {
        let normalizedOutput = output.lowercased()

        if normalizedOutput.contains("xcode-select --install") ||
            normalizedOutput.contains("command line tools") ||
            normalizedOutput.contains("developer tools") {
            return OpenClawInstallFailureContext(
                stage: .installingDeveloperTools,
                summary: "Apple Command Line Tools still need to be installed before OpenClaw can continue.",
                recoverySuggestion: "Finish the macOS Command Line Tools install, then retry Install OpenClaw."
            )
        }

        if normalizedOutput.contains("homebrew") ||
            normalizedOutput.contains("brew install") ||
            normalizedOutput.contains("/opt/homebrew") ||
            normalizedOutput.contains("/usr/local/homebrew") {
            return OpenClawInstallFailureContext(
                stage: .installingHomebrew,
                summary: "Homebrew could not be installed automatically.",
                recoverySuggestion: "Confirm the Homebrew installer or permission prompts completed, then retry Install OpenClaw."
            )
        }

        if normalizedOutput.contains("could not resolve host") ||
            normalizedOutput.contains("failed to connect") ||
            normalizedOutput.contains("timed out") ||
            normalizedOutput.contains("network") {
            let fallbackStage: OpenClawInstallStage = initialEnvironment.hasHomebrew
                ? .installingOpenClawCLI
                : .installingHomebrew
            return OpenClawInstallFailureContext(
                stage: currentStage ?? fallbackStage,
                summary: "The official installer could not reach the network.",
                recoverySuggestion: "Check internet access, then retry Install OpenClaw."
            )
        }

        return OpenClawInstallFailureContext(
            stage: currentStage ?? .installingOpenClawCLI,
            summary: "The official OpenClaw installer exited before finishing.",
            recoverySuggestion: "Review the installer output below, resolve the blocking issue, then retry Install OpenClaw."
        )
    }
}

private final class OpenClawInstallStageTracker: @unchecked Sendable {
    private let lock = NSLock()
    private let initialEnvironment: OpenClawEnvironmentState
    private let progressRelay: OpenClawInstallProgressRelay?

    private var currentActiveStage: OpenClawInstallStage?
    private var developerToolsResolved = false
    private var homebrewResolved = false
    private var openClawResolved = false

    init(
        initialEnvironment: OpenClawEnvironmentState,
        progressRelay: OpenClawInstallProgressRelay?
    ) {
        self.initialEnvironment = initialEnvironment
        self.progressRelay = progressRelay
    }

    var currentStage: OpenClawInstallStage? {
        lock.lock()
        defer { lock.unlock() }
        return currentActiveStage
    }

    func prepareForInstallerLaunch() {
        lock.lock()
        defer { lock.unlock() }

        if initialEnvironment.hasHomebrew {
            if initialEnvironment.hasDeveloperTools {
                completeLocked(
                    .installingDeveloperTools,
                    detail: "Apple Command Line Tools are already available on this Mac."
                )
            } else {
                skipLocked(
                    .installingDeveloperTools,
                    detail: "Homebrew is already installed, so this run does not need to request Apple Command Line Tools."
                )
            }

            completeLocked(
                .installingHomebrew,
                detail: "Homebrew is already available at \(initialEnvironment.homebrewPath ?? "a known location")."
            )
            activateLocked(
                .installingOpenClawCLI,
                detail: "Running the official OpenClaw installer."
            )
            return
        }

        if initialEnvironment.hasDeveloperTools {
            completeLocked(
                .installingDeveloperTools,
                detail: "Apple Command Line Tools are already available on this Mac."
            )
            activateLocked(
                .installingHomebrew,
                detail: "Homebrew is required by the current official OpenClaw install script on macOS. You may see macOS permission dialogs during this step."
            )
        } else {
            activateLocked(
                .installingDeveloperTools,
                detail: "This Mac needs Apple Command Line Tools before Homebrew can be installed. You may see a macOS installation dialog during this step."
            )
        }
    }

    func consume(_ chunk: CommandOutputChunk) {
        let normalizedOutput = chunk.text.lowercased()
        guard !normalizedOutput.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        if !developerToolsResolved,
           (normalizedOutput.contains("xcode-select") ||
            normalizedOutput.contains("command line tools") ||
            normalizedOutput.contains("developer tools")) {
            activateLocked(
                .installingDeveloperTools,
                detail: "The official installer is waiting on Apple Command Line Tools. Finish the macOS dialog, then the install can continue."
            )
        }

        if !homebrewResolved,
           (normalizedOutput.contains("homebrew") ||
            normalizedOutput.contains("brew install") ||
            normalizedOutput.contains("/opt/homebrew") ||
            normalizedOutput.contains("/usr/local/homebrew")) {
            if !developerToolsResolved && !initialEnvironment.hasHomebrew {
                completeLocked(
                    .installingDeveloperTools,
                    detail: "Apple Command Line Tools are ready, so Homebrew can continue."
                )
            }
            activateLocked(
                .installingHomebrew,
                detail: "The official installer is now setting up Homebrew."
            )
        }

        if !openClawResolved, normalizedOutput.contains("openclaw") {
            if !developerToolsResolved && !initialEnvironment.hasHomebrew {
                completeLocked(
                    .installingDeveloperTools,
                    detail: "Apple Command Line Tools are ready, so the install can continue."
                )
            }
            if !homebrewResolved && !initialEnvironment.hasHomebrew {
                completeLocked(
                    .installingHomebrew,
                    detail: "Homebrew is ready for the OpenClaw install."
                )
            }
            activateLocked(
                .installingOpenClawCLI,
                detail: "The official installer is now installing the OpenClaw CLI."
            )
        }
    }

    func markInstallerSucceeded(postEnvironment: OpenClawEnvironmentState) {
        lock.lock()
        defer { lock.unlock() }

        if !developerToolsResolved && !initialEnvironment.hasHomebrew {
            completeLocked(
                .installingDeveloperTools,
                detail: postEnvironment.hasDeveloperTools
                    ? "Apple Command Line Tools are ready."
                    : "The prerequisite check passed and the installer moved past developer tools."
            )
        }

        if !homebrewResolved && !initialEnvironment.hasHomebrew {
            let detail: String
            if let homebrewPath = postEnvironment.homebrewPath {
                detail = "Homebrew is now available at \(homebrewPath)."
            } else {
                detail = "Homebrew finished successfully for the current install session."
            }
            completeLocked(.installingHomebrew, detail: detail)
        }

        if !openClawResolved {
            activateLocked(
                .installingOpenClawCLI,
                detail: "The official installer is now installing the OpenClaw CLI."
            )
            completeLocked(
                .installingOpenClawCLI,
                detail: "The official OpenClaw installer finished."
            )
        }
    }

    private func activateLocked(_ stage: OpenClawInstallStage, detail: String) {
        currentActiveStage = stage
        progressRelay?.send(.activate(stage: stage, detail: detail))
    }

    private func completeLocked(_ stage: OpenClawInstallStage, detail: String) {
        switch stage {
        case .installingDeveloperTools:
            developerToolsResolved = true
        case .installingHomebrew:
            homebrewResolved = true
        case .installingOpenClawCLI:
            openClawResolved = true
        case .checkingEnvironment, .finalizing:
            break
        }
        if currentActiveStage == stage {
            currentActiveStage = nil
        }
        progressRelay?.send(.complete(stage: stage, detail: detail))
    }

    private func skipLocked(_ stage: OpenClawInstallStage, detail: String) {
        switch stage {
        case .installingDeveloperTools:
            developerToolsResolved = true
        case .installingHomebrew:
            homebrewResolved = true
        case .installingOpenClawCLI:
            openClawResolved = true
        case .checkingEnvironment, .finalizing:
            break
        }
        if currentActiveStage == stage {
            currentActiveStage = nil
        }
        progressRelay?.send(.skip(stage: stage, detail: detail))
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
