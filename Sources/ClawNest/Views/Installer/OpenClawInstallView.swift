import SwiftUI

struct OpenClawInstallView: View {
    @ObservedObject var model: AppModel
    let language: AppLanguage
    let layout: WorkspaceLayoutMetrics

    private var directoryBinding: Binding<String> {
        Binding(
            get: { model.installDraft.installDirectoryPath },
            set: { model.updateInstallDirectoryPath($0) }
        )
    }

    private var portBinding: Binding<String> {
        Binding(
            get: { model.installDraft.gatewayPortText },
            set: { model.updateInstallPortText($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: localized("Grow the Nest", "扩展巢", language: language),
                subtitle: localized("Install another OpenClaw with its own home, its own gateway port, and its own LaunchAgent label.", "安装另一个 OpenClaw，为它分配独立目录、独立网关端口和独立 LaunchAgent 标签。", language: language)
            )

            Group {
                if layout.formStacksVertically {
                    VStack(alignment: .leading, spacing: 20) {
                        installDirectoryField
                        portField
                    }
                } else {
                    HStack(alignment: .top, spacing: 20) {
                        installDirectoryField
                        portField
                    }
                }
            }

            validationBanner

            if let preview = model.installValidation.preview {
                installPreview(preview)
            }

            installProgressSection

            if !model.knownOpenClawInstances.isEmpty {
                knownInstances
            }

            Group {
                if layout.formStacksVertically {
                    VStack(alignment: .leading, spacing: 12) {
                        installButton
                        Text(localized("Every install gets its own state, workspace, and reserved port range.", "每次安装都会创建独立 state、workspace 和保留端口范围。", language: language))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.56))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        installButton
                        Text(localized("Every install gets its own state, workspace, and reserved port range.", "每次安装都会创建独立 state、workspace 和保留端口范围。", language: language))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.56))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }

    private var installProgressSection: some View {
        let progress = model.installProgress

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Installation Progress", "安装进度", language: language))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(progressHeadline(for: progress))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
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
                            .foregroundStyle(.white)

                        Spacer()

                        Text(stageStateLabel(stage.state))
                            .font(.caption)
                            .foregroundStyle(progressColor(for: stage.state))
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("Current Step", "当前步骤", language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))

                Text(progress.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))

            if let failure = progress.failure {
                installFailureView(failure)
            } else if progress.isComplete {
                Text(localized("Installation is complete. You can close this modal or continue with the next setup step.", "安装已完成。你可以关闭弹窗，或继续下一步设置。", language: language))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var installDirectoryField: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Install directory", "安装目录", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            HStack(spacing: 10) {
                TextField(localized("Install directory", "安装目录", language: language), text: directoryBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Button(localized("Choose…", "选择…", language: language)) {
                    model.chooseInstallDirectory()
                }
                .buttonStyle(.bordered)
                .disabled(model.isInstallingOpenClaw)
            }
        }
    }

    private var portField: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Gateway port", "网关端口", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            TextField("19789", text: portBinding)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: ClawNestLayout.Size.portFieldWidth)
        }
    }

    private var installButton: some View {
        Button(model.isInstallingOpenClaw ? localized("Installing…", "安装中…", language: language) : localized("Install OpenClaw", "安装 OpenClaw", language: language)) {
            model.installOpenClaw()
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.96, green: 0.63, blue: 0.39))
        .disabled(model.isInstallingOpenClaw || !model.installValidation.isValid)
    }

    private var validationBanner: some View {
        Text(model.installValidation.message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (model.installValidation.isValid
                    ? Color(red: 0.12, green: 0.34, blue: 0.21)
                    : Color(red: 0.35, green: 0.13, blue: 0.15)),
                in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous)
            )
    }

    private func installPreview(_ preview: OpenClawInstallPreview) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.previewMetricMinimumWidth), spacing: 14)], alignment: .leading, spacing: 14) {
            previewMetric(localized("State", "状态目录", language: language), value: preview.stateDirectoryPath)
            previewMetric(localized("Workspace", "工作区", language: language), value: preview.workspaceDirectoryPath)
            previewMetric("LaunchAgent", value: preview.launchAgentLabel)
            previewMetric(localized("Ports", "端口", language: language), value: reservedPortSummary(for: preview))
        }
    }

    private func previewMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
    }

    private var knownInstances: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Known Claws", "已知 Claw", language: language))
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(model.knownOpenClawInstances) { instance in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(instance.gatewayPort))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06), in: Capsule())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(instance.launchAgentLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(instance.installDirectoryPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.56))
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
            }
        }
    }

    private func reservedPortSummary(for preview: OpenClawInstallPreview) -> String {
        guard let gatewayPort = preview.reservedPorts.first?.port,
              let browserControlPort = preview.reservedPorts.dropFirst().first?.port,
              let cdpStart = preview.reservedPorts.dropFirst(2).first?.port,
              let cdpEnd = preview.reservedPorts.last?.port
        else {
            return localized("No ports reserved", "没有保留端口", language: language)
        }

        return "\(gatewayPort), \(browserControlPort), \(cdpStart)-\(cdpEnd)"
    }

    private func installFailureView(_ failure: OpenClawInstallFailure) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Step Failed", "步骤失败", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.98, green: 0.62, blue: 0.58))

            Text(stageTitle(failure.stage))
                .font(.headline)
                .foregroundStyle(.white)

            Text(failure.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(failure.recoverySuggestion)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.68))
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
                        .foregroundStyle(.white.opacity(0.56))

                    Text(rawOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 6, style: .continuous))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.35, green: 0.13, blue: 0.15).opacity(0.72), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
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
            return Color(red: 0.98, green: 0.62, blue: 0.58)
        }

        if progress.isComplete {
            return Color(red: 0.54, green: 0.84, blue: 0.58)
        }

        if progress.hasStarted {
            return Color(red: 0.98, green: 0.72, blue: 0.42)
        }

        return .white.opacity(0.56)
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
            return .white.opacity(0.40)
        case .active:
            return Color(red: 0.98, green: 0.72, blue: 0.42)
        case .completed:
            return Color(red: 0.54, green: 0.84, blue: 0.58)
        case .failed:
            return Color(red: 0.98, green: 0.62, blue: 0.58)
        case .skipped:
            return Color(red: 0.56, green: 0.80, blue: 0.96)
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
