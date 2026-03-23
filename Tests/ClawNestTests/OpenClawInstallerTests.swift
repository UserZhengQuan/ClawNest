import Darwin
import Foundation
import XCTest
@testable import ClawNest

final class OpenClawInstallerTests: XCTestCase {
    func testSnapshotRejectsPortsReservedByKnownInstance() async throws {
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

        XCTAssertFalse(snapshot.validation.isValid)
        XCTAssertTrue(snapshot.validation.message.contains("19789"))
    }

    func testInstallWritesConfigAndLaunchAgentForIsolatedInstance() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let installDirectory = tempRoot.appendingPathComponent("instance", isDirectory: true)
        let homeDirectory = tempRoot.appendingPathComponent("home", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = MemoryInstalledOpenClawInstanceStore()
        let runner = InstallerCommandRunner()
        let installer = OpenClawInstaller(
            runner: runner,
            registryStore: store,
            portInspector: PortInspector { _ in true },
            homeDirectory: homeDirectory
        )

        let result = try await installer.install(
            draft: OpenClawInstallDraft(
                installDirectoryPath: installDirectory.path,
                gatewayPortText: "20789"
            )
        )

        let configPath = installDirectory.appendingPathComponent("state/openclaw.json").path
        let plistPath = homeDirectory.appendingPathComponent("Library/LaunchAgents/ai.clawnest.openclaw.20789.plist").path

        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: plistPath))
        XCTAssertEqual(result.suggestedConfiguration.dashboardURLString, "http://127.0.0.1:20789/")
        XCTAssertEqual(result.suggestedConfiguration.launchAgentLabel, "ai.clawnest.openclaw.20789")

        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let configJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: configData) as? [String: Any])
        let gateway = try XCTUnwrap(configJSON["gateway"] as? [String: Any])
        XCTAssertEqual(gateway["port"] as? Int, 20789)

        let snapshot = await installer.snapshot(
            for: OpenClawInstallDraft(
                installDirectoryPath: installDirectory.path,
                gatewayPortText: "20789"
            )
        )
        XCTAssertEqual(snapshot.knownInstances.count, 1)
        XCTAssertEqual(snapshot.knownInstances.first?.gatewayPort, 20789)

        let commands = await runner.recordedCommands()
        XCTAssertTrue(commands.contains { $0.contains("install-cli.sh") && $0.contains("--prefix '") })
        XCTAssertTrue(commands.contains("launchctl bootstrap gui/\(getuid()) \(plistPath)"))
        XCTAssertTrue(commands.contains("launchctl kickstart -k gui/\(getuid())/ai.clawnest.openclaw.20789"))
    }

    func testInstallFailsCleanlyWhenGitIsMissing() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let installer = OpenClawInstaller(
            runner: InstallerCommandRunner(gitPath: nil),
            registryStore: MemoryInstalledOpenClawInstanceStore(),
            portInspector: PortInspector { _ in true },
            homeDirectory: tempRoot.appendingPathComponent("home", isDirectory: true)
        )

        do {
            _ = try await installer.install(
                draft: OpenClawInstallDraft(
                    installDirectoryPath: tempRoot.appendingPathComponent("instance", isDirectory: true).path,
                    gatewayPortText: "21789"
                )
            )
            XCTFail("Expected missing git error")
        } catch let error as OpenClawInstallError {
            guard case let .missingGit(message) = error else {
                return XCTFail("Unexpected installer error: \(error)")
            }
            XCTAssertTrue(message.contains("xcode-select --install"))
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
    private let gitPath: String?

    init(gitPath: String? = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    func run(command: String, arguments: [String], environment: [String : String]) async -> CommandResult {
        commands.append(([command] + arguments).joined(separator: " "))

        if command == "/bin/zsh", arguments == ["-lc", "command -v git"] {
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: gitPath == nil ? 1 : 0,
                stdout: gitPath.map { "\($0)\n" } ?? "",
                stderr: "",
                launchError: nil
            )
        }

        if command == "/bin/zsh", arguments == ["-lc", "command -v node"] {
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: 0,
                stdout: "/usr/local/bin/node\n",
                stderr: "",
                launchError: nil
            )
        }

        if command == "/bin/zsh",
           let installCommand = arguments.last,
           installCommand.contains("install-cli.sh"),
           let prefix = extractPrefix(from: installCommand) {
            let binDirectory = URL(fileURLWithPath: prefix, isDirectory: true).appendingPathComponent("bin", isDirectory: true)
            try? FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)
            let executableURL = binDirectory.appendingPathComponent("openclaw")
            try? "#!/bin/sh\nexit 0\n".write(to: executableURL, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: 0,
                stdout: "{\"level\":\"info\",\"message\":\"installed\"}\n",
                stderr: "",
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

    private func extractPrefix(from command: String) -> String? {
        guard let prefixRange = command.range(of: "--prefix '") else { return nil }
        let remainder = command[prefixRange.upperBound...]
        guard let closingQuote = remainder.firstIndex(of: "'") else { return nil }
        return String(remainder[..<closingQuote])
    }
}
