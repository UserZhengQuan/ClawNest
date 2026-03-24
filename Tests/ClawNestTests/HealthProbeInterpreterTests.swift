import XCTest
@testable import ClawNest

final class HealthProbeInterpreterTests: XCTestCase {
    private let interpreter = HealthProbeInterpreter()
    private let configuration = ClawNestConfiguration.standard

    func testHealthyProbeMapsToHealthySnapshot() {
        let result = CommandResult(
            command: "openclaw",
            arguments: ["health", "--json"],
            exitCode: 0,
            stdout: #"{"ok":true,"status":"ready","mode":"local","sessionCount":3}"#,
            stderr: "",
            launchError: nil
        )

        let snapshot = interpreter.interpret(
            result: result,
            configuration: configuration,
            lastHealthy: nil,
            logSummary: nil
        )

        XCTAssertEqual(snapshot.level, .healthy)
        XCTAssertTrue(snapshot.metrics.contains(StatusMetric("Status", value: "ready")))
        XCTAssertTrue(snapshot.metrics.contains(StatusMetric("Mode", value: "local")))
    }

    func testOfflineProbeKeepsFailureDetail() {
        let result = CommandResult(
            command: "openclaw",
            arguments: ["health", "--json"],
            exitCode: 1,
            stdout: #"{"ok":false,"status":"offline","error":"unauthorized"}"#,
            stderr: "",
            launchError: nil
        )

        let snapshot = interpreter.interpret(
            result: result,
            configuration: configuration,
            lastHealthy: Date(timeIntervalSince1970: 0),
            logSummary: nil
        )

        XCTAssertEqual(snapshot.level, .offline)
        XCTAssertEqual(snapshot.detail, "unauthorized")
    }

    func testMissingCLIMapsToSetupRequired() {
        let result = CommandResult(
            command: "openclaw",
            arguments: ["health", "--json"],
            exitCode: 127,
            stdout: "",
            stderr: "env: openclaw: No such file or directory",
            launchError: nil
        )

        let snapshot = interpreter.interpret(
            result: result,
            configuration: configuration,
            lastHealthy: nil,
            logSummary: nil
        )

        XCTAssertEqual(snapshot.level, .missingCLI)
        XCTAssertEqual(snapshot.detail, "ClawNest cannot manage the gateway until `openclaw` is available on the machine.")
    }
}
