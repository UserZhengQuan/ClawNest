import AppKit
import SwiftUI

@MainActor
final class CommandOutputPanelController {
    private var windowController: NSWindowController?
    private weak var trackedWindow: NSWindow?

    func show(viewModel: StatusPanelViewModel) {
        let controller = windowController ?? makeWindowController(viewModel: viewModel)
        windowController = controller

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController(viewModel: StatusPanelViewModel) -> NSWindowController {
        let hostingController = NSHostingController(rootView: CommandOutputView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Command Output"
        window.identifier = NSUserInterfaceItemIdentifier("clawnest.command.output")
        window.setContentSize(NSSize(width: 680, height: 460))
        window.minSize = NSSize(width: 560, height: 360)
        window.isReleasedWhenClosed = false
        window.styleMask.insert(.resizable)
        window.center()

        trackedWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.windowController = nil
                self?.trackedWindow = nil
            }
        }

        return NSWindowController(window: window)
    }
}
