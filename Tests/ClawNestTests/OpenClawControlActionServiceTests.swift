import Foundation
import XCTest
@testable import ClawNest

final class OpenClawControlActionServiceTests: XCTestCase {
    func testOfficialCommandMappingsUseExpectedDefaults() {
        let defaults = OpenClawDefaults.standard(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        )
        let service = OpenClawControlActionService(defaults: defaults, runner: ProcessCommandRunner())

        XCTAssertEqual(service.descriptor(for: .start)?.renderedCommand, "openclaw gateway start")
        XCTAssertEqual(service.descriptor(for: .restart)?.renderedCommand, "openclaw gateway restart")
        XCTAssertEqual(service.descriptor(for: .stop)?.renderedCommand, "openclaw gateway stop")
        XCTAssertEqual(service.descriptor(for: .repair)?.renderedCommand, "openclaw doctor --fix")
    }

    func testNonCommandActionsDoNotExposeDescriptors() {
        let service = OpenClawControlActionService()

        XCTAssertNil(service.descriptor(for: .refresh))
        XCTAssertNil(service.descriptor(for: .openChat))
    }

    func testExecuteUsesResolvedPathAndShellEnvironment() async {
        let runner = ActionServiceRunner()
        let service = OpenClawControlActionService(
            runner: runner,
            commandResolver: StubCommandResolver(resolvedPath: "/opt/homebrew/bin/openclaw"),
            environmentProvider: StubEnvironmentProvider(environment: [
                "PATH": "/opt/homebrew/bin:/usr/bin:/bin"
            ])
        )

        guard let stream = service.execute(.stop) else {
            return XCTFail("Expected executable stream")
        }

        for await _ in stream {}

        let invocation = await runner.lastInvocation()
        XCTAssertEqual(invocation?.command, "/opt/homebrew/bin/openclaw")
        XCTAssertEqual(invocation?.arguments, ["gateway", "stop"])
        XCTAssertEqual(invocation?.environment["PATH"], "/opt/homebrew/bin:/usr/bin:/bin")
    }

    func testStartUsesGatewayInstallWhenLaunchAgentIsNotLoaded() async {
        let runner = ActionServiceRunner(results: [
            CommandResult(
                command: "/bin/launchctl",
                arguments: ["print", "gui/501/ai.openclaw.gateway"],
                exitCode: 113,
                stdout: "",
                stderr: "service not loaded",
                launchError: nil
            ),
            CommandResult(
                command: "/opt/homebrew/bin/openclaw",
                arguments: ["gateway", "install"],
                exitCode: 0,
                stdout: "Installed LaunchAgent",
                stderr: "",
                launchError: nil
            )
        ])
        let service = OpenClawControlActionService(
            runner: runner,
            commandResolver: StubCommandResolver(resolvedPath: "/opt/homebrew/bin/openclaw"),
            environmentProvider: StubEnvironmentProvider(environment: [
                "PATH": "/opt/homebrew/bin:/usr/bin:/bin"
            ])
        )

        guard let stream = service.execute(.start) else {
            return XCTFail("Expected executable stream")
        }

        for await _ in stream {}

        let invocations = await runner.invocations()
        XCTAssertEqual(invocations.dropFirst().first?.command, "/opt/homebrew/bin/openclaw")
        XCTAssertEqual(invocations.dropFirst().first?.arguments, ["gateway", "install"])
    }

    func testStartUsesGatewayStartWhenLaunchAgentIsLoaded() async {
        let runner = ActionServiceRunner(results: [
            CommandResult(
                command: "/bin/launchctl",
                arguments: ["print", "gui/501/ai.openclaw.gateway"],
                exitCode: 0,
                stdout: "state = running",
                stderr: "",
                launchError: nil
            ),
            CommandResult(
                command: "/opt/homebrew/bin/openclaw",
                arguments: ["gateway", "start"],
                exitCode: 0,
                stdout: "ok",
                stderr: "",
                launchError: nil
            )
        ])
        let service = OpenClawControlActionService(
            runner: runner,
            commandResolver: StubCommandResolver(resolvedPath: "/opt/homebrew/bin/openclaw"),
            environmentProvider: StubEnvironmentProvider(environment: [
                "PATH": "/opt/homebrew/bin:/usr/bin:/bin"
            ])
        )

        guard let stream = service.execute(.start) else {
            return XCTFail("Expected executable stream")
        }

        for await _ in stream {}

        let invocations = await runner.invocations()
        XCTAssertEqual(invocations.dropFirst().first?.command, "/opt/homebrew/bin/openclaw")
        XCTAssertEqual(invocations.dropFirst().first?.arguments, ["gateway", "start"])
    }

    func testFinishedRecordMarksStartAsFailedWhenServiceIsNotLoaded() {
        let record = CommandExecutionRecord.finished(
            action: .start,
            result: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "start"],
                exitCode: 0,
                stdout: """
                Gateway service not loaded.
                Start with: openclaw gateway install
                """,
                stderr: "",
                launchError: nil
            )
        )

        XCTAssertEqual(record.status, .failed)
    }
}

private struct StubCommandResolver: CommandResolving {
    let resolvedPath: String?

    func resolve(_ command: String) async -> String? {
        resolvedPath
    }
}

private struct StubEnvironmentProvider: CommandEnvironmentProviding {
    let environment: [String: String]

    func executionEnvironment() async -> [String : String] {
        environment
    }
}

private actor ActionServiceRunner: CommandRunning {
    private var recordedInvocations: [Invocation] = []
    private var queuedResults: [CommandResult]

    struct Invocation {
        let command: String
        let arguments: [String]
        let environment: [String: String]
    }

    init(results: [CommandResult] = []) {
        self.queuedResults = results
    }

    func run(
        command: String,
        arguments: [String],
        environment: [String : String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        recordedInvocations.append(Invocation(command: command, arguments: arguments, environment: environment))
        if !queuedResults.isEmpty {
            return queuedResults.removeFirst()
        }
        return CommandResult(
            command: command,
            arguments: arguments,
            exitCode: 0,
            stdout: "ok",
            stderr: "",
            launchError: nil
        )
    }

    func lastInvocation() -> Invocation? {
        recordedInvocations.last
    }

    func invocations() -> [Invocation] {
        recordedInvocations
    }
}
