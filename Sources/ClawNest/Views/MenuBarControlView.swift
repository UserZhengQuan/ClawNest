import AppKit
import SwiftUI

struct MenuBarControlView: View {
    @ObservedObject var viewModel: StatusPanelViewModel
    let outputPanelController: CommandOutputPanelController

    var body: some View {
        infoSection

        Divider()

        actionsSection

        if let actionNote = viewModel.actionNote {
            Divider()

            Text(actionNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 320, alignment: .leading)
        }

        Divider()

        Button("Quit ClawNest") {
            NSApp.terminate(nil)
        }
    }

    private var infoSection: some View {
        Group {
            InfoMenuRow(label: "OpenClaw", value: viewModel.snapshot.runtimeStatus.label)
            InfoMenuRow(label: "Gateway", value: viewModel.snapshot.gateway.url.absoluteString)
            InfoMenuRow(label: "Root path", value: viewModel.rootPathText)
            InfoMenuRow(label: "Last checked", value: viewModel.lastCheckedText)
        }
    }

    private var actionsSection: some View {
        Group {
            actionButton(.openChat)
            actionButton(.refresh)
            actionButton(.start)
            actionButton(.restart)
            actionButton(.stop)
            actionButton(.repair)
        }
    }

    private func actionButton(_ action: OpenClawControlAction) -> some View {
        Button {
            if action.usesOfficialCommand {
                outputPanelController.show(viewModel: viewModel)
            }
            viewModel.perform(action)
        } label: {
            Label(action.title, systemImage: action.systemImage)
        }
        .disabled(isDisabled(action))
    }

    private func isDisabled(_ action: OpenClawControlAction) -> Bool {
        switch action {
        case .refresh:
            return viewModel.isRefreshing || viewModel.isCommandRunning
        case .openChat:
            return false
        case .start, .restart, .stop, .repair:
            return viewModel.isRefreshing || viewModel.isCommandRunning
        }
    }
}

private struct InfoMenuRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 320, alignment: .leading)
    }
}

struct MenuBarStatusIconView: View {
    let state: MenuBarIndicatorState

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(for: state))
    }
}

enum MenuBarIconRenderer {
    static func image(for state: MenuBarIndicatorState) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let baseImage = NSImage(
            systemSymbolName: "bolt.circle.fill",
            accessibilityDescription: "ClawNest Status"
        )?.withSymbolConfiguration(configuration) ?? NSImage(size: NSSize(width: 18, height: 18))

        let tintedImage = baseImage.copy() as? NSImage ?? baseImage
        tintedImage.isTemplate = false
        tintedImage.lockFocus()
        color(for: state).set()
        NSRect(origin: .zero, size: tintedImage.size).fill(using: .sourceAtop)
        tintedImage.unlockFocus()
        tintedImage.size = NSSize(width: 18, height: 18)
        return tintedImage
    }

    private static func color(for state: MenuBarIndicatorState) -> NSColor {
        switch state {
        case .neutral:
            return .white
        case .healthy:
            return NSColor(calibratedRed: 0.18, green: 0.72, blue: 0.30, alpha: 1)
        case .unhealthy:
            return NSColor(calibratedRed: 0.86, green: 0.24, blue: 0.22, alpha: 1)
        }
    }
}
