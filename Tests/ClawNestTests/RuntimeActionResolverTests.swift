import XCTest
@testable import ClawNest

final class RuntimeActionResolverTests: XCTestCase {
    private let resolver = RuntimeActionResolver()
    private let configuration = ClawNestConfiguration.standard

    func testMissingCLIShowsInstallInsteadOfLifecycleActions() {
        let snapshot = GatewaySnapshot(
            level: .missingCLI,
            headline: "Missing",
            detail: "OpenClaw CLI is missing.",
            lastCheck: .now,
            lastHealthy: nil,
            dashboardURL: configuration.dashboardURL,
            metrics: [],
            rawProbe: "",
            logSummary: nil
        )

        let actions = resolver.resolve(snapshot: snapshot, cliInstalled: false).actions

        XCTAssertEqual(actions, [.install, .refreshStatus, .revealLogs])
    }

    func testOfflineRuntimeShowsStartAndRepair() {
        let snapshot = GatewaySnapshot(
            level: .offline,
            headline: "Offline",
            detail: "Gateway is offline.",
            lastCheck: .now,
            lastHealthy: nil,
            dashboardURL: configuration.dashboardURL,
            metrics: [],
            rawProbe: "",
            logSummary: nil
        )

        let actions = resolver.resolve(snapshot: snapshot, cliInstalled: true).actions

        XCTAssertEqual(actions, [.refreshStatus, .start, .repair, .revealLogs])
    }
}
