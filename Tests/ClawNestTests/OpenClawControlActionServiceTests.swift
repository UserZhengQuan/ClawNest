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
    private var invocation: Invocation?

    struct Invocation {
        let command: String
        let arguments: [String]
        let environment: [String: String]
    }

    func run(
        command: String,
        arguments: [String],
        environment: [String : String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        invocation = Invocation(command: command, arguments: arguments, environment: environment)
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
        invocation
    }
}
