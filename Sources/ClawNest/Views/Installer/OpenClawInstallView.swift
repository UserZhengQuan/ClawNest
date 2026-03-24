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

            if !model.knownOpenClawInstances.isEmpty {
                knownInstances
            }

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

            Group {
                if layout.formStacksVertically {
                    VStack(alignment: .leading, spacing: 12) {
                        installButton
                        Text(localized("Every install gets its own state, workspace, and reserved port range.", "每次安装都会创建独立 state、workspace 和保留端口范围。", language: language))
                            .font(.caption)
                            .foregroundStyle(AppShellPalette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(spacing: 12) {
                        installButton
                        Text(localized("Every install gets its own state, workspace, and reserved port range.", "每次安装都会创建独立 state、workspace 和保留端口范围。", language: language))
                            .font(.caption)
                            .foregroundStyle(AppShellPalette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }

    private var installDirectoryField: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Install directory", "安装目录", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppShellPalette.textTertiary)

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
                .foregroundStyle(AppShellPalette.textTertiary)

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
            .foregroundStyle(AppShellPalette.textPrimary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (model.installValidation.isValid
                    ? Color(red: 0.89, green: 0.96, blue: 0.91)
                    : Color(red: 0.98, green: 0.91, blue: 0.90)),
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
                .foregroundStyle(AppShellPalette.textTertiary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(AppShellPalette.textPrimary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
    }

    private var knownInstances: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("Known Claws", "已知 Claw", language: language))
                .font(.headline)
                .foregroundStyle(AppShellPalette.textPrimary)

            ForEach(model.knownOpenClawInstances) { instance in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(instance.gatewayPort))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(AppShellPalette.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppShellPalette.subtleStrongFill, in: Capsule())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(instance.launchAgentLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppShellPalette.textPrimary)
                        Text(instance.installDirectoryPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppShellPalette.textTertiary)
                    }

                    Spacer()
                }
                .padding(14)
                .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium - 2, style: .continuous))
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
}
