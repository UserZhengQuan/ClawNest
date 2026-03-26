import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: StatusPanelViewModel

    private let actions: [OpenClawControlAction] = [
        .refresh,
        .openChat,
        .start,
        .restart,
        .stop,
        .repair
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusSection
                pathsSection
                actionsSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 720, minHeight: 680, alignment: .topLeading)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenClaw Control Panel")
                    .font(.system(size: 28, weight: .semibold))

                Text("Local OpenClaw status with official control commands")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isRefreshing || viewModel.isCommandRunning {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var statusSection: some View {
        SectionCard(title: "Status") {
            LabeledRow(label: "OpenClaw status") {
                StatusBadge(status: viewModel.snapshot.runtimeStatus)
            }

            Divider()

            LabeledRow(label: "Gateway URL") {
                Text(viewModel.snapshot.gateway.url.absoluteString)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            Divider()

            LabeledRow(label: "Port") {
                Text(String(viewModel.snapshot.gateway.port))
                    .font(.system(.body, design: .monospaced))
            }

            Divider()

            LabeledRow(label: "Last checked time") {
                Text(viewModel.lastCheckedText)
            }
        }
    }

    private var pathsSection: some View {
        SectionCard(title: "Paths") {
            ForEach(Array(viewModel.snapshot.paths.enumerated()), id: \.element.id) { index, item in
                PathRow(
                    item: item,
                    onCopy: { viewModel.copy(item.url) },
                    onReveal: { viewModel.reveal(item.url) }
                )

                if index < viewModel.snapshot.paths.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var actionsSection: some View {
        SectionCard(title: "Actions") {
            Text("Control actions call official OpenClaw commands directly when a command is shown below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                ActionRow(
                    action: action,
                    command: viewModel.commandPreview(for: action),
                    isDisabled: isDisabled(action),
                    isRunning: viewModel.isRunning(action: action),
                    onRun: { viewModel.perform(action) }
                )

                if index < actions.count - 1 {
                    Divider()
                }
            }

            if let actionNote = viewModel.actionNote {
                Divider()

                Label(actionNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            CommandOutputPanel(record: viewModel.commandOutput)
        }
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

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 128, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusBadge: View {
    let status: OpenClawRuntimeStatus

    var body: some View {
        Label(status.label, systemImage: status.symbolName)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(status.color.opacity(0.14), in: Capsule())
            .foregroundStyle(status.color)
    }
}

private struct CommandStatusBadge: View {
    let status: CommandExecutionStatus

    var body: some View {
        Label(status.label, systemImage: status.symbolName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.14), in: Capsule())
            .foregroundStyle(status.color)
    }
}

private struct PathRow: View {
    let item: OpenClawPathItem
    let onCopy: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.subheadline.weight(.medium))

            Text(item.url.path)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    pathButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    pathButtons
                }
            }
        }
    }

    private var pathButtons: some View {
        Group {
            Button("Copy", action: onCopy)
            Button("Reveal in Finder", action: onReveal)
        }
        .controlSize(.small)
    }
}

private struct ActionRow: View {
    let action: OpenClawControlAction
    let command: String?
    let isDisabled: Bool
    let isRunning: Bool
    let onRun: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                actionButton
                actionDetails
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                actionButton
                actionDetails
            }
        }
    }

    private var actionButton: some View {
        Button(action.title, action: onRun)
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isDisabled)
            .frame(width: 112, alignment: .leading)
    }

    private var actionDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.subtitle)
                .font(.subheadline)

            if let command {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Command is running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CommandOutputPanel: View {
    let record: CommandExecutionRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Output")
                .font(.headline)

            Text("Shows the most recent Start, Restart, Stop, or Repair run.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let record {
                MetadataRow(label: "Command") {
                    Text(record.command)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                MetadataRow(label: "Status") {
                    CommandStatusBadge(status: record.status)
                }

                MetadataRow(label: "Started at") {
                    Text(formattedDate(record.startedAt))
                }

                MetadataRow(label: "Finished at") {
                    Text(record.finishedAt.map(formattedDate) ?? "Still running")
                }

                MetadataRow(label: "Duration") {
                    Text(record.duration.map(formattedDuration) ?? "Pending")
                }

                MetadataRow(label: "Exit code") {
                    Text(record.exitCode.map(String.init) ?? "Pending")
                        .font(.system(.body, design: .monospaced))
                }

                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 18) {
                        OutputTextBlock(title: "Stdout", text: record.stdout)
                        OutputTextBlock(title: "Stderr", text: record.stderrWithLaunchError)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .frame(minHeight: 220, maxHeight: 280)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
            } else {
                Text("Run Start, Restart, Stop, or Repair to inspect the latest official command output.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .standard)
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2fs", duration)
    }
}

private struct MetadataRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct OutputTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "(empty)" : text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
