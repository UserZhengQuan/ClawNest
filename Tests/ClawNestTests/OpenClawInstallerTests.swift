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
        let commands = await runner.recordedCommands()
        XCTAssertEqual(commands, ["/bin/zsh -lc command -v 'openclaw'"])
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
}

private actor InstallerCommandRunner: CommandRunning {
    private var commands: [String] = []
    private let resolvedCommandsBeforeInstall: [String: String?]
    private let resolvedCommandsAfterInstall: [String: String?]
    private let installerExitCode: Int32
    private let installerStdout: String
    private let installerStderr: String
    private var installerHasRun = false

    init(
        resolvedCommandsBeforeInstall: [String: String?],
        resolvedCommandsAfterInstall: [String: String?],
        installerExitCode: Int32 = 0,
        installerStdout: String = "{\"level\":\"info\",\"message\":\"installed\"}\n",
        installerStderr: String = ""
    ) {
        self.resolvedCommandsBeforeInstall = resolvedCommandsBeforeInstall
        self.resolvedCommandsAfterInstall = resolvedCommandsAfterInstall
        self.installerExitCode = installerExitCode
        self.installerStdout = installerStdout
        self.installerStderr = installerStderr
    }

    func run(command: String, arguments: [String], environment: [String: String]) async -> CommandResult {
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

        if command == "/bin/zsh",
           let installCommand = arguments.last,
           installCommand.contains("https://openclaw.ai/install.sh") {
            installerHasRun = true
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
