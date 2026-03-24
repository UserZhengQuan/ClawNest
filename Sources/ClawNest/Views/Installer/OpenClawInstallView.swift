import SwiftUI

struct OpenClawInstallView: View {
    @ObservedObject var model: AppModel
    let language: AppLanguage
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            statusBanner
            detailsSection
            nextStepSection
            installStatusSection
            actionSection
        }
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }

    private var header: some View {
        PanelHeaderView(
            title: localized("OpenClaw CLI", "OpenClaw CLI", language: language),
            subtitle: localized("This workbench only installs or verifies the OpenClaw CLI. Workspace, gateway, and launchd onboarding stay in the official `openclaw onboard --install-daemon` flow.", "这个工作台只负责安装或校验 OpenClaw CLI。workspace、gateway 和 launchd onboarding 仍然走官方 `openclaw onboard --install-daemon` 流程。", language: language)
        )
    }

    private var statusBanner: some View {
        Text(model.installSnapshot.message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppShellPalette.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (model.installSnapshot.isInstalled
                    ? Color(red: 0.89, green: 0.96, blue: 0.91)
                    : Color(red: 0.98, green: 0.91, blue: 0.90)),
                in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous)
            )
    }

    private var cliActions: [RuntimeAction] {
        let preferred: [RuntimeAction] = [.install, .repair, .refreshStatus]
        return preferred.filter(model.runtimeActions.contains)
    }

    private var detailsSection: some View {
        detailGrid(facts: detailFacts)
    }

    private var nextStepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("Next step", "下一步", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppShellPalette.textTertiary)
            Text(model.installSnapshot.nextStep)
                .font(.subheadline)
                .foregroundStyle(AppShellPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var installStatusSection: some View {
        if let installStatusMessage = model.installStatusMessage {
            VStack(alignment: .leading, spacing: 12) {
                Text(installStatusMessage)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if installStatusMessage.contains("xcode-select --install") {
                    Button(localized("Install Developer Tools", "安装开发者工具", language: language)) {
                        model.installDeveloperTools()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var actionSection: some View {
        FlowLayout(spacing: 12, rowSpacing: 12) {
            ForEach(cliActions) { action in
                actionButton(for: action)
            }
        }
    }

    @ViewBuilder
    private func actionButton(for action: RuntimeAction) -> some View {
        if action == .install {
            Button(action.title(in: language)) {
                model.perform(action)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .tint(Color(red: 0.96, green: 0.63, blue: 0.39))
            .disabled(!model.isActionEnabled(action))
        } else {
            Button(action.title(in: language)) {
                model.perform(action)
            }
            .buttonStyle(BorderedButtonStyle())
            .disabled(!model.isActionEnabled(action))
        }
    }

    private var detailFacts: [(String, String)] {
        if let resolvedCommandPath = model.installSnapshot.resolvedCommandPath {
            return [
                (localized("Detected CLI", "检测到的 CLI", language: language), resolvedCommandPath),
                (localized("Configured command", "当前配置命令", language: language), model.configuration.openClawCommand)
            ]
        }

        return [
            (localized("Configured command", "当前配置命令", language: language), model.configuration.openClawCommand)
        ]
    }

    private func detailGrid(facts: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.detailFactMinimumWidth), spacing: 14)], alignment: .leading, spacing: 14) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 8) {
                    Text(fact.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppShellPalette.textTertiary)
                    Text(fact.1)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(AppShellPalette.textPrimary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
            }
        }
    }
}
