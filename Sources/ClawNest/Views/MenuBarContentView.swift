import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: model.snapshot.level.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.snapshot.level.label(in: model.language))
                        .font(.headline)
                    Text(model.snapshot.headline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Text(model.snapshot.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let lastHealthy = model.snapshot.lastHealthy {
                Label(localized("Last healthy \(lastHealthy.formatted(.relative(presentation: .named)))", "最近一次正常：\(lastHealthy.formatted(.relative(presentation: .named)))", language: model.language), systemImage: "heart.text.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                quickAction(.refresh)
                quickAction(.restartGateway)
                quickAction(.openDashboard)
                quickAction(.revealLogs)
            }
        }
        .padding(ClawNestLayout.Spacing.medium)
        .frame(width: ClawNestLayout.Size.menuBarWidth)
    }

    private func quickAction(_ action: RecoveryAction) -> some View {
        Button {
            model.perform(action)
        } label: {
            Label(action.title(in: model.language), systemImage: action.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(model.isBusy && action != .openDashboard && action != .revealLogs)
    }

    private var statusColor: Color {
        switch model.snapshot.level {
        case .healthy:
            return Color(red: 0.15, green: 0.63, blue: 0.39)
        case .recovering:
            return Color(red: 0.14, green: 0.54, blue: 0.78)
        case .degraded:
            return Color(red: 0.90, green: 0.57, blue: 0.14)
        case .offline, .missingCLI:
            return Color(red: 0.76, green: 0.24, blue: 0.19)
        }
    }
}
