import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: StatusPanelViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusSection
                gatewaySection
                pathsSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 680, minHeight: 500, alignment: .topLeading)
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenClaw Status")
                    .font(.system(size: 28, weight: .semibold))

                Text("Local, read-only status viewer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Refresh") {
                    viewModel.refreshNow()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    private var statusSection: some View {
        SectionCard(title: "Status") {
            LabeledRow(label: "State") {
                StatusBadge(status: viewModel.snapshot.runtimeStatus)
            }

            Divider()

            LabeledRow(label: "Last checked") {
                Text(viewModel.lastCheckedText)
            }
        }
    }

    private var gatewaySection: some View {
        SectionCard(title: "Gateway") {
            LabeledRow(label: "URL") {
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

            LabeledRow(label: "Health") {
                HealthBadge(status: viewModel.snapshot.gateway.health)
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
                .frame(width: 96, alignment: .leading)

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

private struct HealthBadge: View {
    let status: GatewayHealthStatus

    var body: some View {
        Label(status.label, systemImage: status.symbolName)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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
