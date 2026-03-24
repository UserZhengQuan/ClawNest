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
            installProgressSection
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

    private var installProgressSection: some View {
        let progress = model.installProgress

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Installation Progress", "安装进度", language: language))
                        .font(.headline)
                        .foregroundStyle(AppShellPalette.textPrimary)
                    Text(progressHeadline(for: progress))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppShellPalette.textPrimary)
                }

                Spacer()

                Text(progressStatusLabel(for: progress))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progressStatusColor(for: progress))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(progressStatusColor(for: progress).opacity(0.16), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(progress.stages) { stage in
                    HStack(spacing: 12) {
                        Text(progressSymbol(for: stage.state))
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(progressColor(for: stage.state))
                            .frame(width: 18, alignment: .center)

                        Text(stageTitle(stage.stage))
                            .font(.subheadline.weight(stage.state == .active ? .semibold : .regular))
                            .foregroundStyle(AppShellPalette.textPrimary)

                        Spacer()

                        Text(stageStateLabel(stage.state))
                            .font(.caption)
                            .foregroundStyle(progressColor(for: stage.state))
                    }
                }
            }
            .padding(14)
            .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("Current Step", "当前步骤", language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppShellPalette.textTertiary)

                Text(progress.detail)
                    .font(.subheadline)
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))

            if let failure = progress.failure {
                installFailureView(failure)
            } else if progress.isComplete {
                Text(localized("Installation is complete. Continue with the official onboarding step if this Mac still needs first-run setup.", "安装已完成。如果这台 Mac 还没完成首次设置，请继续执行官方 onboarding。", language: language))
                    .font(.footnote)
                    .foregroundStyle(AppShellPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private func installFailureView(_ failure: OpenClawInstallFailure) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Step Failed", "步骤失败", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.92, green: 0.39, blue: 0.38))

            Text(stageTitle(failure.stage))
                .font(.headline)
                .foregroundStyle(AppShellPalette.textPrimary)

            Text(failure.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppShellPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(failure.recoverySuggestion)
                .font(.footnote)
                .foregroundStyle(AppShellPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if failure.stage == .installingDeveloperTools {
                Button(localized("Install Developer Tools", "安装开发者工具", language: language)) {
                    model.installDeveloperTools()
                }
                .buttonStyle(.bordered)
            }

            if let rawOutput = failure.rawOutput,
               !rawOutput.isEmpty,
               rawOutput != failure.summary {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("Installer Output", "安装器输出", language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppShellPalette.textTertiary)

                    Text(rawOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppShellPalette.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(AppShellPalette.codeBackground, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 6, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.98, green: 0.91, blue: 0.90), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
    }

    private func progressHeadline(for progress: OpenClawInstallProgress) -> String {
        if let failure = progress.failure {
            return stageTitle(failure.stage)
        }

        if let currentStage = progress.currentStage {
            return stageTitle(currentStage)
        }

        if progress.isComplete {
            return localized("Completed", "已完成", language: language)
        }

        return localized("Ready to Install", "准备安装", language: language)
    }

    private func progressStatusLabel(for progress: OpenClawInstallProgress) -> String {
        if progress.failure != nil {
            return localized("Failed", "失败", language: language)
        }

        if progress.isComplete {
            return localized("Completed", "已完成", language: language)
        }

        if progress.hasStarted {
            return localized("In Progress", "进行中", language: language)
        }

        return localized("Waiting", "等待中", language: language)
    }

    private func progressStatusColor(for progress: OpenClawInstallProgress) -> Color {
        if progress.failure != nil {
            return Color(red: 0.92, green: 0.39, blue: 0.38)
        }

        if progress.isComplete {
            return Color(red: 0.29, green: 0.88, blue: 0.53)
        }

        if progress.hasStarted {
            return Color(red: 0.95, green: 0.72, blue: 0.38)
        }

        return AppShellPalette.textTertiary
    }

    private func progressSymbol(for state: OpenClawInstallStageState) -> String {
        switch state {
        case .pending:
            return "○"
        case .active:
            return "●"
        case .completed:
            return "✓"
        case .failed:
            return "✕"
        case .skipped:
            return "↷"
        }
    }

    private func progressColor(for state: OpenClawInstallStageState) -> Color {
        switch state {
        case .pending:
            return AppShellPalette.textTertiary
        case .active:
            return Color(red: 0.95, green: 0.72, blue: 0.38)
        case .completed:
            return Color(red: 0.29, green: 0.88, blue: 0.53)
        case .failed:
            return Color(red: 0.92, green: 0.39, blue: 0.38)
        case .skipped:
            return Color(red: 0.34, green: 0.73, blue: 0.94)
        }
    }

    private func stageStateLabel(_ state: OpenClawInstallStageState) -> String {
        switch state {
        case .pending:
            return localized("Pending", "待执行", language: language)
        case .active:
            return localized("Active", "进行中", language: language)
        case .completed:
            return localized("Completed", "已完成", language: language)
        case .failed:
            return localized("Failed", "失败", language: language)
        case .skipped:
            return localized("Skipped", "已跳过", language: language)
        }
    }

    private func stageTitle(_ stage: OpenClawInstallStage) -> String {
        switch stage {
        case .checkingEnvironment:
            return localized("Checking Environment", "检查环境", language: language)
        case .installingDeveloperTools:
            return localized("Installing Developer Tools", "安装开发者工具", language: language)
        case .installingHomebrew:
            return localized("Installing Homebrew", "安装 Homebrew", language: language)
        case .installingOpenClawCLI:
            return localized("Installing OpenClaw CLI", "安装 OpenClaw CLI", language: language)
        case .finalizing:
            return localized("Finalizing", "收尾处理中", language: language)
        }
    }
}
