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
}

private struct StubStatusService: OpenClawStatusServing {
    let snapshots: [OpenClawStatusSnapshot]

    func refresh() async -> OpenClawStatusSnapshot {
        snapshots.first ?? .placeholder()
    }
}

private final class RecordingActionService: OpenClawControlActionServing, @unchecked Sendable {
    let executeExpectation = XCTestExpectation(description: "execute called")
    private(set) var executedActions: [OpenClawControlAction] = []

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

        let result = CommandResult(
            command: "openclaw",
            arguments: ["gateway", action == .restart ? "restart" : action.rawValue],
            exitCode: 0,
            stdout: "ok",
            stderr: "",
            launchError: nil
        )

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
