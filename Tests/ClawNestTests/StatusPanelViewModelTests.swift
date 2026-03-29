import Foundation
import XCTest
@testable import ClawNest

@MainActor
final class StatusPanelViewModelTests: XCTestCase {
    func testRestartDoesNotFallBackToStartWhenRuntimeIsNotRunning() async {
        let actionService = RecordingActionService()
        let viewModel = StatusPanelViewModel(
            statusService: StubStatusService(
                snapshots: [
                    .placeholder(),
                    .placeholder()
                ]
            ),
            actionService: actionService,
            systemActions: NoopLocalSystemActionHandler(),
            pollIntervalSeconds: 3_600
        )

        viewModel.perform(.restart)
        await fulfillment(of: [actionService.executeExpectation], timeout: 1)

        XCTAssertEqual(actionService.executedActions, [.restart])
    }

    func testStartMarksCommandSuccessfulAfterStatusTurnsRunning() async {
        let actionService = RecordingActionService(
            result: CommandResult(
                command: """
                $ openclaw gateway start
                $ openclaw gateway install
                $ openclaw gateway start
                """,
                arguments: [],
                exitCode: 0,
                stdout: """
                Gateway service not loaded.
                Start with: openclaw gateway install
                Installed LaunchAgent
                Started Gateway
                """,
                stderr: "",
                launchError: nil
            )
        )
        let viewModel = StatusPanelViewModel(
            statusService: SequencedStatusService(snapshots: [
                runningSnapshot()
            ]),
            actionService: actionService,
            systemActions: NoopLocalSystemActionHandler(),
            pollIntervalSeconds: 3_600
        )

        viewModel.perform(.start)
        await fulfillment(of: [actionService.executeExpectation], timeout: 1)

        for _ in 0 ..< 40 {
            if viewModel.commandOutput?.status == .success {
                break
            }
            try? await Task.sleep(for: .milliseconds(25))
        }

        XCTAssertEqual(viewModel.commandOutput?.status, .success)
    }

    private func runningSnapshot() -> OpenClawStatusSnapshot {
        let defaults = OpenClawDefaults.standard(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        )
        return OpenClawStatusSnapshot(
            runtimeStatus: .running,
            lastCheckedAt: .now,
            gateway: GatewayStatusDetails(
                url: defaults.gatewayURL,
                port: defaults.port,
                health: .healthy
            ),
            paths: defaults.paths
        )
    }
}

private struct StubStatusService: OpenClawStatusServing {
    let snapshots: [OpenClawStatusSnapshot]

    func refresh() async -> OpenClawStatusSnapshot {
        snapshots.first ?? .placeholder()
    }
}

private actor SequencedStatusService: OpenClawStatusServing {
    private var snapshots: [OpenClawStatusSnapshot]

    init(snapshots: [OpenClawStatusSnapshot]) {
        self.snapshots = snapshots
    }

    func refresh() async -> OpenClawStatusSnapshot {
        if snapshots.isEmpty {
            return .placeholder()
        }

        if snapshots.count == 1 {
            return snapshots[0]
        }

        return snapshots.removeFirst()
    }
}

private final class RecordingActionService: OpenClawControlActionServing, @unchecked Sendable {
    let executeExpectation = XCTestExpectation(description: "execute called")
    private(set) var executedActions: [OpenClawControlAction] = []
    private let result: CommandResult

    init(result: CommandResult? = nil) {
        self.result = result ?? CommandResult(
            command: "openclaw",
            arguments: ["gateway", "restart"],
            exitCode: 0,
            stdout: "ok",
            stderr: "",
            launchError: nil
        )
    }

    func descriptor(for action: OpenClawControlAction) -> OpenClawCommandDescriptor? {
        switch action {
        case .refresh, .openChat:
            return nil
        case .start:
            return OpenClawCommandDescriptor(command: "openclaw", arguments: ["gateway", "start"])
        case .restart:
            return OpenClawCommandDescriptor(command: "openclaw", arguments: ["gateway", "restart"])
        case .stop:
            return OpenClawCommandDescriptor(command: "openclaw", arguments: ["gateway", "stop"])
        case .repair:
            return OpenClawCommandDescriptor(command: "openclaw", arguments: ["doctor", "--fix"])
        }
    }

    func execute(_ action: OpenClawControlAction) -> AsyncStream<CommandExecutionEvent>? {
        executedActions.append(action)
        executeExpectation.fulfill()

        return AsyncStream { continuation in
            continuation.yield(.started(command: result.renderedCommand, startedAt: result.startedAt))
            continuation.yield(.finished(result))
            continuation.finish()
        }
    }
}

@MainActor
private struct NoopLocalSystemActionHandler: LocalSystemActionHandling {
    func copy(_ url: URL) {}
    func reveal(_ url: URL) {}
    func open(_ url: URL) -> Bool { false }
}
