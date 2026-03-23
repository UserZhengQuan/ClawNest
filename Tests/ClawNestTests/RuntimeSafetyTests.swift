import Foundation
import XCTest
@testable import ClawNest

final class RuntimeSafetyTests: XCTestCase {
    func testStandardConfigurationIsObserveOnlyByDefault() {
        XCTAssertFalse(ClawNestConfiguration.standard.autoRestartEnabled)
    }

    func testObserveOnlyConfigurationDoesNotAutoRestartGateway() async {
        var configuration = ClawNestConfiguration.standard
        configuration.autoRestartEnabled = false

        let runner = ScriptedCommandRunner(
            healthResults: [
                .offlineProbe,
                .offlineProbe
            ]
        )

        let supervisor = GatewaySupervisor(
            configuration: configuration,
            runner: runner,
            logInspector: LogInspector(directoryURL: URL(fileURLWithPath: "/tmp/clawnest-tests-missing", isDirectory: true))
        )

        _ = await supervisor.refresh(trigger: .automaticPoll)
        _ = await supervisor.refresh(trigger: .automaticPoll)

        let commands = await runner.recordedCommands()
        XCTAssertEqual(commands, [
            "openclaw health --json",
            "openclaw health --json"
        ])
    }

    func testAppLaunchPerformsOnlyOneImmediateProbe() async throws {
        let store = FixedConfigurationStore(configuration: .standard)
        let runner = ScriptedCommandRunner(healthResults: [.healthyProbe])

        let model = await MainActor.run {
            AppModel(
                configurationStore: store,
                runner: runner,
                logInspector: LogInspector(directoryURL: URL(fileURLWithPath: "/tmp/clawnest-tests-missing", isDirectory: true))
            )
        }

        try await Task.sleep(for: .milliseconds(250))

        let commands = await runner.recordedCommands()
        XCTAssertEqual(commands, ["openclaw health --json"])
        withExtendedLifetime(model) {}
    }
}

private struct FixedConfigurationStore: ConfigurationStoring, Sendable {
    let configuration: ClawNestConfiguration

    func load() -> ClawNestConfiguration {
        configuration
    }

    func save(_ configuration: ClawNestConfiguration) {}
}

private actor ScriptedCommandRunner: CommandRunning {
    private var healthResults: [CommandResult]
    private var commands: [String] = []

    init(healthResults: [CommandResult]) {
        self.healthResults = healthResults
    }

    func run(command: String, arguments: [String], environment: [String : String]) async -> CommandResult {
        commands.append(([command] + arguments).joined(separator: " "))

        if command == "openclaw", arguments == ["health", "--json"] {
            if !healthResults.isEmpty {
                return healthResults.removeFirst()
            }
            return .healthyProbe
        }

        if command == "launchctl" {
            return CommandResult(
                command: command,
                arguments: arguments,
                exitCode: 0,
                stdout: "",
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
}

private extension CommandResult {
    static let healthyProbe = CommandResult(
        command: "openclaw",
        arguments: ["health", "--json"],
        exitCode: 0,
        stdout: #"{"ok":true,"status":"ready"}"#,
        stderr: "",
        launchError: nil
    )

    static let offlineProbe = CommandResult(
        command: "openclaw",
        arguments: ["health", "--json"],
        exitCode: 1,
        stdout: #"{"ok":false,"status":"offline","error":"probe failed"}"#,
        stderr: "",
        launchError: nil
    )
}
