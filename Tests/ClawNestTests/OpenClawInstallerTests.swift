import Foundation
import XCTest
@testable import ClawNest

final class OpenClawInstallerTests: XCTestCase {
    func testSnapshotDescribesMissingCLICleanly() async throws {
        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                resolvedCommandsBeforeInstall: ["openclaw": nil],
                resolvedCommandsAfterInstall: ["openclaw": nil]
            )
        )

        let snapshot = await installer.snapshot(currentCommand: "openclaw")

        XCTAssertFalse(snapshot.isInstalled)
        XCTAssertNil(snapshot.resolvedCommandPath)
        XCTAssertTrue(snapshot.message.contains("not installed yet"))
        XCTAssertTrue(snapshot.nextStep.contains("openclaw onboard --install-daemon"))
    }

    func testSnapshotCallsOutConfiguredCommandMismatch() async throws {
        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                resolvedCommandsBeforeInstall: [
                    "custom-openclaw": nil,
                    "openclaw": "/usr/local/bin/openclaw"
                ],
                resolvedCommandsAfterInstall: [
                    "custom-openclaw": nil,
                    "openclaw": "/usr/local/bin/openclaw"
                ]
            )
        )

        let snapshot = await installer.snapshot(currentCommand: "custom-openclaw")

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertEqual(snapshot.resolvedCommandPath, "/usr/local/bin/openclaw")
        XCTAssertTrue(snapshot.message.contains("did not resolve"))
    }

    func testInstallRunsOfficialInstallerAndResolvesGlobalCLI() async throws {
        let runner = InstallerCommandRunner(
            resolvedCommandsBeforeInstall: ["openclaw": nil],
            resolvedCommandsAfterInstall: ["openclaw": "/usr/local/bin/openclaw"]
        )
        let installer = OpenClawInstaller(runner: runner)

        let result = try await installer.install()

        XCTAssertEqual(result.installedCommand, "/usr/local/bin/openclaw")
        XCTAssertTrue(result.summary.contains("openclaw onboard --install-daemon"))

        let commands = await runner.recordedCommands()
        XCTAssertTrue(commands.contains("/bin/zsh -lc command -v 'openclaw'"))
        XCTAssertTrue(commands.contains("/bin/zsh -lc xcode-select -p"))
        XCTAssertTrue(commands.contains("/bin/zsh -lc command -v 'brew'"))
        XCTAssertTrue(commands.contains { $0.contains("https://openclaw.ai/install.sh") && $0.contains("--no-onboard") })
        XCTAssertFalse(commands.contains { $0.contains("launchctl") })
    }

    func testInstallReusesExistingOpenClawWithoutRunningInstaller() async throws {
        let runner = InstallerCommandRunner(
            resolvedCommandsBeforeInstall: ["openclaw": "/opt/homebrew/bin/openclaw"],
            resolvedCommandsAfterInstall: ["openclaw": "/opt/homebrew/bin/openclaw"]
        )
        let installer = OpenClawInstaller(runner: runner)

        let result = try await installer.install()

        XCTAssertEqual(result.installedCommand, "/opt/homebrew/bin/openclaw")
        XCTAssertTrue(result.summary.contains("skipped the official installer"))

        let commands = await runner.recordedCommands()
        XCTAssertEqual(commands.count, 3)
        XCTAssertTrue(commands.contains("/bin/zsh -lc command -v 'openclaw'"))
        XCTAssertTrue(commands.contains("/bin/zsh -lc xcode-select -p"))
        XCTAssertTrue(commands.contains("/bin/zsh -lc command -v 'brew'"))
    }

    func testInstallFailsWhenOfficialInstallerDoesNotExposeCLIOnPath() async throws {
        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                resolvedCommandsBeforeInstall: ["openclaw": nil],
                resolvedCommandsAfterInstall: ["openclaw": nil]
            )
        )

        do {
            _ = try await installer.install()
            XCTFail("Expected missing binary error")
        } catch let error as OpenClawInstallError {
            guard case .missingOpenClawBinary = error else {
                return XCTFail("Unexpected installer error: \(error)")
            }
        }
    }

    func testInstallSurfacesOfficialInstallerFailureOutput() async throws {
        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                resolvedCommandsBeforeInstall: ["openclaw": nil],
                resolvedCommandsAfterInstall: ["openclaw": nil],
                installerExitCode: 1,
                installerStdout: "",
                installerStderr: "curl: (6) Could not resolve host"
            )
        )

        do {
            _ = try await installer.install()
            XCTFail("Expected installer failure")
        } catch let error as OpenClawInstallError {
            guard case let .installScriptFailed(message) = error else {
                return XCTFail("Unexpected installer error: \(error)")
            }
            XCTAssertTrue(message.contains("Could not resolve host"))
        }
    }

    func testInstallReportsStageUpdatesWhenHomebrewIsMissing() async throws {
        let runner = InstallerCommandRunner(
            resolvedCommandsBeforeInstall: ["openclaw": nil],
            resolvedCommandsAfterInstall: ["openclaw": "/usr/local/bin/openclaw"],
            developerToolsPathBeforeInstall: "/Library/Developer/CommandLineTools",
            developerToolsPathAfterInstall: "/Library/Developer/CommandLineTools",
            homebrewPathBeforeInstall: nil,
            homebrewPathAfterInstall: "/opt/homebrew/bin/brew",
            installerOutputChunks: [
                CommandOutputChunk(stream: .stdout, text: "Installing Homebrew\n"),
                CommandOutputChunk(stream: .stdout, text: "Installing OpenClaw CLI\n")
            ]
        )
        let installer = OpenClawInstaller(runner: runner)
        let progressSink = RecordingProgressSink()

        _ = try await installer.install(progressRelay: progressSink.makeRelay())

        let updates = progressSink.recordedUpdates()
        XCTAssertTrue(containsActivation(for: .checkingEnvironment, in: updates))
        XCTAssertTrue(containsCompletion(for: .installingDeveloperTools, in: updates))
        XCTAssertTrue(containsActivation(for: .installingHomebrew, in: updates))
        XCTAssertTrue(containsActivation(for: .installingOpenClawCLI, in: updates))
        XCTAssertTrue(containsActivation(for: .finalizing, in: updates))
    }

    func testInstallReportsSkippedStagesWhenExistingCLIIsReused() async throws {
        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(
                resolvedCommandsBeforeInstall: ["openclaw": "/opt/homebrew/bin/openclaw"],
                resolvedCommandsAfterInstall: ["openclaw": "/opt/homebrew/bin/openclaw"]
            )
        )
        let progressSink = RecordingProgressSink()

        let result = try await installer.install(progressRelay: progressSink.makeRelay())

        let updates = progressSink.recordedUpdates()
        XCTAssertTrue(result.summary.contains("skipped the official installer"))
        XCTAssertTrue(containsSkip(for: .installingDeveloperTools, in: updates))
        XCTAssertTrue(containsSkip(for: .installingHomebrew, in: updates))
        XCTAssertTrue(containsSkip(for: .installingOpenClawCLI, in: updates))
        XCTAssertTrue(containsActivation(for: .finalizing, in: updates))
    }
}

private actor InstallerCommandRunner: CommandRunning {
    private var commands: [String] = []
    private let resolvedCommandsBeforeInstall: [String: String?]
    private let resolvedCommandsAfterInstall: [String: String?]
    private let developerToolsPathBeforeInstall: String?
    private let developerToolsPathAfterInstall: String?
    private let homebrewPathBeforeInstall: String?
    private let homebrewPathAfterInstall: String?
    private let installerExitCode: Int32
    private let installerStdout: String
    private let installerStderr: String
    private let installerOutputChunks: [CommandOutputChunk]
    private var installerHasRun = false

    init(
        resolvedCommandsBeforeInstall: [String: String?] = [:],
        resolvedCommandsAfterInstall: [String: String?] = [:],
        developerToolsPathBeforeInstall: String? = "/Library/Developer/CommandLineTools",
        developerToolsPathAfterInstall: String? = "/Library/Developer/CommandLineTools",
        homebrewPathBeforeInstall: String? = nil,
        homebrewPathAfterInstall: String? = "/opt/homebrew/bin/brew",
        installerExitCode: Int32 = 0,
        installerStdout: String = "{\"level\":\"info\",\"message\":\"installed\"}\n",
        installerStderr: String = "",
        installerOutputChunks: [CommandOutputChunk] = []
    ) {
        self.resolvedCommandsBeforeInstall = resolvedCommandsBeforeInstall
        self.resolvedCommandsAfterInstall = resolvedCommandsAfterInstall
        self.developerToolsPathBeforeInstall = developerToolsPathBeforeInstall
        self.developerToolsPathAfterInstall = developerToolsPathAfterInstall
        self.homebrewPathBeforeInstall = homebrewPathBeforeInstall
        self.homebrewPathAfterInstall = homebrewPathAfterInstall
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

        if command == "/bin/zsh",
           arguments.count == 2,
           arguments[0] == "-lc",
           let resolvedCommand = resolvedCommandName(from: arguments[1]) {
            let table = installerHasRun ? resolvedCommandsAfterInstall : resolvedCommandsBeforeInstall
            let resolvedPath = table[resolvedCommand] ?? nil
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
            let resolvedPath = installerHasRun ? (developerToolsPathAfterInstall ?? developerToolsPathBeforeInstall) : developerToolsPathBeforeInstall
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: resolvedPath == nil ? 1 : 0,
                stdout: resolvedPath.map { "\($0)\n" } ?? "",
                stderr: "",
                launchError: nil
            )
        }

        if command == "/bin/zsh", arguments == ["-lc", "command -v 'brew'"] {
            let resolvedPath = installerHasRun ? (homebrewPathAfterInstall ?? homebrewPathBeforeInstall) : homebrewPathBeforeInstall
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

    private func resolvedCommandName(from shellCommand: String) -> String? {
        guard shellCommand.hasPrefix("command -v ") else { return nil }
        var name = shellCommand.replacingOccurrences(of: "command -v ", with: "")
        if name.hasPrefix("'"), name.hasSuffix("'"), name.count >= 2 {
            name.removeFirst()
            name.removeLast()
        }
        return name
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
