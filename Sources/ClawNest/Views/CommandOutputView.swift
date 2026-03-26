import SwiftUI

struct CommandOutputView: View {
    @ObservedObject var viewModel: StatusPanelViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command Output")
                        .font(.system(size: 24, weight: .semibold))

                    Text("Shows the most recent official OpenClaw command result.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                CommandOutputPanel(record: viewModel.commandOutput)
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 360, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct CommandOutputPanel: View {
    let record: CommandExecutionRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .frame(minHeight: 220, maxHeight: 320)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
            } else {
                Text("No Start, Restart, Stop, or Repair command has run yet.")
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

struct CommandStatusBadge: View {
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
