import Foundation
import XCTest
@testable import ClawNest

final class OpenClawStatusServiceTests: XCTestCase {
    func testDefaultLocationsUseStandardOpenClawPaths() {
        let homeDirectory = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let defaults = OpenClawDefaults.standard(homeDirectory: homeDirectory)

        XCTAssertEqual(defaults.gatewayURL.absoluteString, "http://127.0.0.1:18789/")
        XCTAssertEqual(defaults.port, 18789)
        XCTAssertEqual(defaults.paths.map(\.url.path), [
            "/Users/tester/.openclaw",
            "/Users/tester/.openclaw/openclaw.json",
            "/Users/tester/.openclaw/logs"
        ])
    }

    func testPlaceholderSnapshotUsesNeutralMenuBarIndicator() {
        let snapshot = OpenClawStatusSnapshot.placeholder(defaults: defaults)

        XCTAssertEqual(snapshot.menuBarIndicatorState, .neutral)
    }

    func testInterpreterMarksRunningWhenProbeReportsHealthy() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 0,
                stdout: #"{"runtime":"running","rpcProbe":"ok","listening":"127.0.0.1:18789"}"#,
                stderr: "",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: true,
                health: .healthy
            ),
            checkedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.runtimeStatus, .running)
        XCTAssertEqual(snapshot.gateway.health, .healthy)
        XCTAssertEqual(snapshot.lastCheckedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(snapshot.menuBarIndicatorState, .healthy)
    }

    func testInterpreterMarksStoppedWhenCommandIsMissingAndGatewayIsDown() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 127,
                stdout: "",
                stderr: "zsh: command not found: openclaw",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: false,
                health: .unhealthy
            )
        )

        XCTAssertEqual(snapshot.runtimeStatus, .stopped)
        XCTAssertEqual(snapshot.gateway.health, .unhealthy)
    }

    func testInterpreterMarksRunningWhenGatewayHealthIsHealthyWithoutCli() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 127,
                stdout: "",
                stderr: "zsh: command not found: openclaw",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: true,
                health: .healthy
            )
        )

        XCTAssertEqual(snapshot.runtimeStatus, .running)
    }

    func testInterpreterMarksUnknownWhenGatewayIsOnlyReachableWithoutCli() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 127,
                stdout: "",
                stderr: "zsh: command not found: openclaw",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: true,
                health: .unavailable
            )
        )

        XCTAssertEqual(snapshot.runtimeStatus, .unknown)
    }

    func testInterpreterMarksUnknownWhenProbeIsAmbiguous() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 0,
                stdout: #"{"runtime":"running","rpcProbe":"failed","lastGatewayError":"connection refused"}"#,
                stderr: "",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: false,
                health: .unhealthy
            )
        )

        XCTAssertEqual(snapshot.runtimeStatus, .unknown)
    }

    func testInterpreterMarksUnknownWhenProbeSaysStoppedButPortIsReachable() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 0,
                stdout: #"{"runtime":"stopped"}"#,
                stderr: "",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: true,
                health: .unavailable
            )
        )

        XCTAssertEqual(snapshot.runtimeStatus, .unknown)
    }

    func testInterpreterParsesJSONAfterConfigWarnings() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["gateway", "status", "--json"],
                exitCode: 0,
                stdout: """
                Config warnings:
                - duplicate plugin id detected
                {\"runtime\":\"running\",\"rpcProbe\":\"ok\",\"listening\":\"127.0.0.1:18789\"}
                """,
                stderr: "",
                launchError: nil
            ),
            gatewayCheck: GatewayHealthCheckResult(
                isReachable: true,
                health: .healthy
            )
        )

        XCTAssertEqual(snapshot.runtimeStatus, .running)
    }

    func testRefreshUsesResolvedPathAndShellEnvironment() async {
        let runner = StatusServiceRunner()
        let service = OpenClawStatusService(
            defaults: defaults,
            runner: runner,
            commandResolver: StatusStubCommandResolver(resolvedPath: "/opt/homebrew/bin/openclaw"),
            environmentProvider: StatusStubEnvironmentProvider(environment: [
                "PATH": "/opt/homebrew/bin:/usr/bin:/bin"
            ]),
            gatewayChecker: StubGatewayChecker()
        )

        let snapshot = await service.refresh()
        let invocation = await runner.lastInvocation()

        XCTAssertEqual(invocation?.command, "/opt/homebrew/bin/openclaw")
        XCTAssertEqual(invocation?.arguments, ["gateway", "status", "--json"])
        XCTAssertEqual(invocation?.environment["PATH"], "/opt/homebrew/bin:/usr/bin:/bin")
        XCTAssertEqual(snapshot.runtimeStatus, .running)
    }

    func testDiagnosticStatusUsesOfficialGatewayStatusCommand() async {
        let runner = StatusServiceRunner()
        let service = OpenClawStatusService(
            defaults: defaults,
            runner: runner,
            commandResolver: StatusStubCommandResolver(resolvedPath: "/opt/homebrew/bin/openclaw"),
            environmentProvider: StatusStubEnvironmentProvider(environment: [
                "PATH": "/opt/homebrew/bin:/usr/bin:/bin"
            ]),
            gatewayChecker: StubGatewayChecker()
        )

        _ = await service.diagnosticStatus()
        let invocation = await runner.lastInvocation()

        XCTAssertEqual(invocation?.command, "/opt/homebrew/bin/openclaw")
        XCTAssertEqual(invocation?.arguments, ["gateway", "status"])
        XCTAssertEqual(invocation?.environment["PATH"], "/opt/homebrew/bin:/usr/bin:/bin")
    }

private let interpreter = OpenClawStatusInterpreter()
    private let defaults = OpenClawDefaults.standard(
        homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    )
}

private struct StatusServiceInvocation {
    let command: String
    let arguments: [String]
    let environment: [String: String]
}

private actor StatusServiceRunner: CommandRunning {
    private var invocation: StatusServiceInvocation?

    func run(
        command: String,
        arguments: [String],
        environment: [String : String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        invocation = StatusServiceInvocation(
            command: command,
            arguments: arguments,
            environment: environment
        )
        return CommandResult(
            command: command,
            arguments: arguments,
            exitCode: 0,
            stdout: #"{"runtime":"running","rpcProbe":"ok","listening":"127.0.0.1:18789"}"#,
            stderr: "",
            launchError: nil
        )
    }

    func lastInvocation() -> StatusServiceInvocation? {
        invocation
    }
}

private struct StubGatewayChecker: GatewayHealthChecking {
    func check(url: URL) async -> GatewayHealthCheckResult {
        GatewayHealthCheckResult(isReachable: true, health: .healthy)
    }
}

private struct StatusStubCommandResolver: CommandResolving {
    let resolvedPath: String?

    func resolve(_ command: String) async -> String? {
        resolvedPath
    }
}

private struct StatusStubEnvironmentProvider: CommandEnvironmentProviding {
    let environment: [String: String]

    func executionEnvironment() async -> [String : String] {
        environment
    }
}
