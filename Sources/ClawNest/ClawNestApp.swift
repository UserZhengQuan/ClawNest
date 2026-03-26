import AppKit
import SwiftUI

final class ClawNestApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@MainActor
@main
struct ClawNestApp: App {
    @NSApplicationDelegateAdaptor(ClawNestApplicationDelegate.self) private var appDelegate
    @StateObject private var viewModel: StatusPanelViewModel
    private let outputPanelController = CommandOutputPanelController()

    init() {
        let viewModel = StatusPanelViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)

        Task {
            await viewModel.loadIfNeeded()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarControlView(
                viewModel: viewModel,
                outputPanelController: outputPanelController
            )
        } label: {
            MenuBarStatusIconView(state: viewModel.menuBarIndicatorState)
        }
    }
}
