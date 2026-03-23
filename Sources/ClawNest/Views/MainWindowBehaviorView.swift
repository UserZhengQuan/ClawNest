import AppKit
import SwiftUI

struct MainWindowBehaviorView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        Task { @MainActor in
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            context.coordinator.attach(to: nsView.window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private weak var configuredWindow: NSWindow?

        func attach(to window: NSWindow?) {
            guard let window else { return }
            configuredWindow = window
            configure(window)
        }

        private func configure(_ window: NSWindow) {
            window.identifier = NSUserInterfaceItemIdentifier("clawnest.main.window")
            window.tabbingMode = .disallowed
            window.styleMask.insert(.resizable)
            window.collectionBehavior.remove(.fullScreenDisallowsTiling)

            let minimumSize = NSSize(width: ClawNestLayout.Window.minimumWidth, height: ClawNestLayout.Window.minimumHeight)
            let maximumSize = NSSize(width: ClawNestLayout.Window.maximumWidth, height: ClawNestLayout.Window.maximumHeight)

            window.minSize = minimumSize
            window.contentMinSize = minimumSize
            window.maxSize = maximumSize
            window.contentMaxSize = maximumSize

            if window.delegate !== self {
                window.delegate = self
            }
        }

        func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
            preferredZoomFrame(for: window)
        }

        func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
            true
        }

        private func preferredZoomFrame(for window: NSWindow) -> NSRect {
            guard let screen = window.screen ?? NSScreen.main else {
                return window.frame
            }

            let visibleFrame = screen.visibleFrame.insetBy(
                dx: ClawNestLayout.Window.zoomedHorizontalInset,
                dy: ClawNestLayout.Window.zoomedVerticalInset
            )
            let width = min(visibleFrame.width, ClawNestLayout.Window.maximumWidth)
            let height = min(visibleFrame.height, ClawNestLayout.Window.maximumHeight)
            let origin = CGPoint(
                x: visibleFrame.midX - (width / 2),
                y: visibleFrame.maxY - height
            )

            return NSRect(origin: origin, size: CGSize(width: width, height: height)).integral
        }
    }
}

@MainActor
enum MainWindowController {
    static func zoomFrontWindow() {
        frontWindow()?.zoom(nil)
    }

    static func restoreFrontWindow() {
        guard let window = frontWindow(), window.isZoomed else { return }
        window.zoom(nil)
    }

    static var canZoomFrontWindow: Bool {
        frontWindow() != nil
    }

    static var canRestoreFrontWindow: Bool {
        frontWindow()?.isZoomed == true
    }

    private static func frontWindow() -> NSWindow? {
        NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.identifier?.rawValue == "clawnest.main.window" })
    }
}
