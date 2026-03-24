import Foundation
import XCTest
@testable import ClawNest

final class OpenClawInstallerTests: XCTestCase {
    func testSnapshotDescribesOfficialInstallFlow() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = MemoryInstalledOpenClawInstanceStore(
            instances: [
                InstalledOpenClawInstance(
                    installDirectoryPath: tempRoot.appendingPathComponent("existing", isDirectory: true).path,
                    stateDirectoryPath: tempRoot.appendingPathComponent("existing/state", isDirectory: true).path,
                    workspaceDirectoryPath: tempRoot.appendingPathComponent("existing/workspace", isDirectory: true).path,
                    gatewayPort: 19789,
                    launchAgentLabel: "ai.clawnest.openclaw.19789",
                    dashboardURLString: "http://127.0.0.1:19789/",
                    reservedPorts: [19789, 19791, 19800],
                    installedAt: .now
                )
            ]
        )

        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(),
            registryStore: store,
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )

        let snapshot = await installer.snapshot(
            for: OpenClawInstallDraft(
                installDirectoryPath: tempRoot.appendingPathComponent("candidate", isDirectory: true).path,
                gatewayPortText: "19789"
            )
        )

        XCTAssertTrue(snapshot.validation.isValid)
        XCTAssertNil(snapshot.validation.preview)
        XCTAssertTrue(snapshot.validation.message.contains("official OpenClaw CLI"))
        XCTAssertEqual(snapshot.knownInstances.count, 1)
    }

    func testInstallRunsOfficialInstallerAndResolvesGlobalCLI() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let runner = InstallerCommandRunner(
            existingOpenClawPath: nil,
            installedOpenClawPath: "/usr/local/bin/openclaw"
        )
        let installer = OpenClawInstaller(
            runner: runner,
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )

        let result = try await installer.install(
            draft: OpenClawInstallDraft(
                installDirectoryPath: tempRoot.appendingPathComponent("ignored", isDirectory: true).path,
                gatewayPortText: "20789"
            )
        )

        XCTAssertEqual(result.installedCommand, "/usr/local/bin/openclaw")
        XCTAssertTrue(result.summary.contains("openclaw onboard --install-daemon"))

        let commands = await runner.recordedCommands()
        XCTAssertTrue(commands.contains("/bin/zsh -lc command -v openclaw"))
        XCTAssertTrue(commands.contains { $0.contains("https://openclaw.ai/install.sh") && $0.contains("--no-onboard") })
        XCTAssertFalse(commands.contains { $0.contains("install-cli.sh") })
        XCTAssertFalse(commands.contains { $0.contains("launchctl") })
    }

    func testInstallReusesExistingOpenClawWithoutRunningInstaller() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let runner = InstallerCommandRunner(existingOpenClawPath: "/opt/homebrew/bin/openclaw")
        let installer = OpenClawInstaller(
            runner: runner,
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )

        let result = try await installer.install(
            draft: OpenClawInstallDraft(
                installDirectoryPath: tempRoot.appendingPathComponent("ignored", isDirectory: true).path,
                gatewayPortText: "21789"
            )
        )

        XCTAssertEqual(result.installedCommand, "/opt/homebrew/bin/openclaw")
        let commands = await runner.recordedCommands()
        XCTAssertEqual(
            commands,
            [
                "/bin/zsh -lc command -v openclaw",
                "/bin/zsh -lc xcode-select -p",
                "/bin/zsh -lc command -v brew"
            ]
        )
    }

    func testInstallFailsWhenOfficialInstallerDoesNotExposeCLIOnPath() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                existingOpenClawPath: nil,
                installedOpenClawPath: nil
            ),
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )

        do {
            _ = try await installer.install(
                draft: OpenClawInstallDraft(
                    installDirectoryPath: tempRoot.appendingPathComponent("ignored", isDirectory: true).path,
                    gatewayPortText: "22789"
                )
            )
            XCTFail("Expected missing binary error")
        } catch let error as OpenClawInstallError {
            guard case .missingOpenClawBinary = error else {
                return XCTFail("Unexpected installer error: \(error)")
            }
        }
    }

    func testInstallSurfacesOfficialInstallerFailureOutput() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                existingOpenClawPath: nil,
                installedOpenClawPath: nil,
                installerExitCode: 1,
                installerStdout: "",
                installerStderr: "curl: (6) Could not resolve host"
            ),
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )

        do {
            _ = try await installer.install(
                draft: OpenClawInstallDraft(
                    installDirectoryPath: tempRoot.appendingPathComponent("ignored", isDirectory: true).path,
                    gatewayPortText: "23789"
                )
            )
            XCTFail("Expected installer failure")
        } catch let error as OpenClawInstallError {
            guard case let .installScriptFailed(message) = error else {
                return XCTFail("Unexpected installer error: \(error)")
            }
            XCTAssertTrue(message.contains("Could not resolve host"))
        }
    }

    func testInstallReportsStageUpdatesWhenHomebrewIsMissing() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let runner = InstallerCommandRunner(
            existingOpenClawPath: nil,
            installedOpenClawPath: "/usr/local/bin/openclaw",
            existingDeveloperToolsPath: "/Library/Developer/CommandLineTools",
            existingHomebrewPath: nil,
            installedHomebrewPath: "/opt/homebrew/bin/brew",
            installerOutputChunks: [
                CommandOutputChunk(stream: .stdout, text: "Installing Homebrew\n"),
                CommandOutputChunk(stream: .stdout, text: "Installing OpenClaw CLI\n")
            ]
        )
        let installer = OpenClawInstaller(
            runner: runner,
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )
        let progressSink = RecordingProgressSink()

        _ = try await installer.install(
            draft: OpenClawInstallDraft(
                installDirectoryPath: tempRoot.appendingPathComponent("ignored", isDirectory: true).path,
                gatewayPortText: "24789"
            ),
            progressRelay: progressSink.makeRelay()
        )

        let updates = progressSink.recordedUpdates()
        XCTAssertTrue(containsActivation(for: .checkingEnvironment, in: updates))
        XCTAssertTrue(containsCompletion(for: .installingDeveloperTools, in: updates))
        XCTAssertTrue(containsActivation(for: .installingHomebrew, in: updates))
        XCTAssertTrue(containsActivation(for: .installingOpenClawCLI, in: updates))
        XCTAssertTrue(containsActivation(for: .finalizing, in: updates))
    }

    func testInstallReportsSkippedStagesWhenExistingCLIIsReused() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(existingOpenClawPath: "/opt/homebrew/bin/openclaw"),
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )
        let progressSink = RecordingProgressSink()

        let result = try await installer.install(
            draft: OpenClawInstallDraft(
                installDirectoryPath: tempRoot.appendingPathComponent("ignored", isDirectory: true).path,
                gatewayPortText: "25789"
            ),
            progressRelay: progressSink.makeRelay()
        )

        let updates = progressSink.recordedUpdates()
        XCTAssertTrue(result.summary.contains("skipped the official installer"))
        XCTAssertTrue(containsSkip(for: .installingDeveloperTools, in: updates))
        XCTAssertTrue(containsSkip(for: .installingHomebrew, in: updates))
        XCTAssertTrue(containsSkip(for: .installingOpenClawCLI, in: updates))
        XCTAssertTrue(containsActivation(for: .finalizing, in: updates))
    }
}

private final class MemoryInstalledOpenClawInstanceStore: InstalledOpenClawInstanceStoring {
    private var instances: [InstalledOpenClawInstance]

    init(instances: [InstalledOpenClawInstance] = []) {
        self.instances = instances
    }

    func load() -> [InstalledOpenClawInstance] {
        instances
    }

    func save(_ instances: [InstalledOpenClawInstance]) {
        self.instances = instances
    }

    func upsert(_ instance: InstalledOpenClawInstance) {
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index] = instance
        } else {
            instances.append(instance)
        }
    }
}

private actor InstallerCommandRunner: CommandRunning {
    private var commands: [String] = []
    private let existingOpenClawPath: String?
    private let installedOpenClawPath: String?
    private let existingDeveloperToolsPath: String?
    private let installedDeveloperToolsPath: String?
    private let existingHomebrewPath: String?
    private let installedHomebrewPath: String?
    private let installerExitCode: Int32
    private let installerStdout: String
    private let installerStderr: String
    private let installerOutputChunks: [CommandOutputChunk]
    private var installerHasRun = false

    init(
        existingOpenClawPath: String? = nil,
        installedOpenClawPath: String? = "/usr/local/bin/openclaw",
        existingDeveloperToolsPath: String? = "/Library/Developer/CommandLineTools",
        installedDeveloperToolsPath: String? = "/Library/Developer/CommandLineTools",
        existingHomebrewPath: String? = nil,
        installedHomebrewPath: String? = "/opt/homebrew/bin/brew",
        installerExitCode: Int32 = 0,
        installerStdout: String = "{\"level\":\"info\",\"message\":\"installed\"}\n",
        installerStderr: String = "",
        installerOutputChunks: [CommandOutputChunk] = []
    ) {
        self.existingOpenClawPath = existingOpenClawPath
        self.installedOpenClawPath = installedOpenClawPath
        self.existingDeveloperToolsPath = existingDeveloperToolsPath
        self.installedDeveloperToolsPath = installedDeveloperToolsPath
        self.existingHomebrewPath = existingHomebrewPath
        self.installedHomebrewPath = installedHomebrewPath
        self.installerExitCode = installerExitCode
        self.installerStdout = installerStdout
        self.installerStderr = installerStderr
        self.installerOutputChunks = installerOutputChunks
    }

    func run(
        command: String,
        arguments: [String],
        environment: [String: String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        commands.append(([command] + arguments).joined(separator: " "))

        if command == "/bin/zsh", arguments == ["-lc", "command -v openclaw"] {
            let resolvedPath = installerHasRun ? installedOpenClawPath : existingOpenClawPath
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: resolvedPath == nil ? 1 : 0,
                stdout: resolvedPath.map { "\($0)\n" } ?? "",
                stderr: "",
                launchError: nil
            )
        }

        if command == "/bin/zsh", arguments == ["-lc", "xcode-select -p"] {
            let resolvedPath = installerHasRun ? (installedDeveloperToolsPath ?? existingDeveloperToolsPath) : existingDeveloperToolsPath
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: resolvedPath == nil ? 1 : 0,
                stdout: resolvedPath.map { "\($0)\n" } ?? "",
                stderr: "",
                launchError: nil
            )
        }

        if command == "/bin/zsh", arguments == ["-lc", "command -v brew"] {
            let resolvedPath = installerHasRun ? (installedHomebrewPath ?? existingHomebrewPath) : existingHomebrewPath
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: resolvedPath == nil ? 1 : 0,
                stdout: resolvedPath.map { "\($0)\n" } ?? "",
                stderr: "",
                launchError: nil
            )
        }

        if command == "/bin/zsh",
           let installCommand = arguments.last,
           installCommand.contains("https://openclaw.ai/install.sh") {
            installerHasRun = true
            let streamedChunks: [CommandOutputChunk]
            if installerOutputChunks.isEmpty {
                streamedChunks = [
                    CommandOutputChunk(stream: .stdout, text: installerStdout),
                    CommandOutputChunk(stream: .stderr, text: installerStderr)
                ].filter { !$0.text.isEmpty }
            } else {
                streamedChunks = installerOutputChunks
            }
            streamedChunks.forEach { chunk in
                outputHandler?(chunk)
            }
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: installerExitCode,
                stdout: installerStdout,
                stderr: installerStderr,
                launchError: nil
            )
        }

        return CommandResult(
            command: command,
            arguments: arguments,
            exitCode: 0,
            stdout: "",
            stderr: "",
            launchError: nil
        )
    }

    func recordedCommands() -> [String] {
        commands
    }
}

private final class RecordingProgressSink: @unchecked Sendable {
    private let lock = NSLock()
    private var updates: [OpenClawInstallProgressUpdate] = []

    func makeRelay() -> OpenClawInstallProgressRelay {
        OpenClawInstallProgressRelay { update in
            self.lock.lock()
            self.updates.append(update)
            self.lock.unlock()
        }
    }

    func recordedUpdates() -> [OpenClawInstallProgressUpdate] {
        lock.lock()
        defer { lock.unlock() }
        return updates
    }
}

private func containsActivation(
    for stage: OpenClawInstallStage,
    in updates: [OpenClawInstallProgressUpdate]
) -> Bool {
    updates.contains {
        guard case let .activate(candidate, _) = $0 else { return false }
        return candidate == stage
    }
}

private func containsCompletion(
    for stage: OpenClawInstallStage,
    in updates: [OpenClawInstallProgressUpdate]
) -> Bool {
    updates.contains {
        guard case let .complete(candidate, _) = $0 else { return false }
        return candidate == stage
    }
}

private func containsSkip(
    for stage: OpenClawInstallStage,
    in updates: [OpenClawInstallProgressUpdate]
) -> Bool {
    updates.contains {
        guard case let .skip(candidate, _) = $0 else { return false }
        return candidate == stage
    }
}
