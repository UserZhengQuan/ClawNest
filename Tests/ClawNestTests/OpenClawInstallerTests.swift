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
        XCTAssertEqual(commands, ["/bin/zsh -lc command -v openclaw"])
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
    private let installerExitCode: Int32
    private let installerStdout: String
    private let installerStderr: String
    private var installerHasRun = false

    init(
        existingOpenClawPath: String? = nil,
        installedOpenClawPath: String? = "/usr/local/bin/openclaw",
        installerExitCode: Int32 = 0,
        installerStdout: String = "{\"level\":\"info\",\"message\":\"installed\"}\n",
        installerStderr: String = ""
    ) {
        self.existingOpenClawPath = existingOpenClawPath
        self.installedOpenClawPath = installedOpenClawPath
        self.installerExitCode = installerExitCode
        self.installerStdout = installerStdout
        self.installerStderr = installerStderr
    }

    func run(command: String, arguments: [String], environment: [String: String]) async -> CommandResult {
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
}
