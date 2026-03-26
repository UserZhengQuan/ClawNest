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
                arguments: ["health", "--json"],
                exitCode: 0,
                stdout: #"{"ok":true,"status":"ready"}"#,
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
                arguments: ["health", "--json"],
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

    func testInterpreterMarksRunningWhenGatewayIsReachableWithoutCli() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["health", "--json"],
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

        XCTAssertEqual(snapshot.runtimeStatus, .running)
    }

    func testInterpreterMarksUnknownWhenProbeIsAmbiguous() {
        let snapshot = interpreter.makeSnapshot(
            defaults: defaults,
            commandResult: CommandResult(
                command: "openclaw",
                arguments: ["health", "--json"],
                exitCode: 0,
                stdout: #"{"status":"warming"}"#,
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

    private let interpreter = OpenClawStatusInterpreter()
    private let defaults = OpenClawDefaults.standard(
        homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    )
}
