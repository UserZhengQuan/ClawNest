import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: ClawNestLayout.Spacing.medium) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: model.snapshot.level.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(model.snapshot.level.tintColor)

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
                ForEach(model.runtimeActions) { action in
                    quickAction(action)
                }
            }
        }
        .padding(ClawNestLayout.Spacing.medium)
        .frame(width: ClawNestLayout.Size.menuBarWidth)
    }

    private func quickAction(_ action: RuntimeAction) -> some View {
        Button {
            model.perform(action)
        } label: {
            Label(action.title(in: model.language), systemImage: action.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(!model.isActionEnabled(action))
    }
}
