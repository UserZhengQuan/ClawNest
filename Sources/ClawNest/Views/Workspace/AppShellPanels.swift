import SwiftUI

struct StatusHeroView: View {
    let snapshot: GatewaySnapshot
    let isBusy: Bool
    let language: AppLanguage
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        Group {
            if layout.headerStacksVertically {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        statusIcon
                        statusText
                    }

                    FlowLayout(spacing: 12, rowSpacing: 12) {
                        statusChip(label: localized("Last Check", "最近检查", language: language), value: snapshot.lastCheck.formatted(date: .abbreviated, time: .shortened), alignment: .leading)
                        statusChip(label: localized("Last Healthy", "最近正常", language: language), value: snapshot.lastHealthy?.formatted(date: .abbreviated, time: .shortened) ?? localized("No successful probe yet", "还没有成功探测", language: language), alignment: .leading)

                        if isBusy {
                            Label(localized("Recovery action running", "恢复动作执行中", language: language), systemImage: "hourglass")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    statusIcon
                    statusText

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 10) {
                        statusChip(label: localized("Last Check", "最近检查", language: language), value: snapshot.lastCheck.formatted(date: .abbreviated, time: .shortened))
                        statusChip(label: localized("Last Healthy", "最近正常", language: language), value: snapshot.lastHealthy?.formatted(date: .abbreviated, time: .shortened) ?? localized("No successful probe yet", "还没有成功探测", language: language))

                        if isBusy {
                            Label(localized("Recovery action running", "恢复动作执行中", language: language), systemImage: "hourglass")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(ClawNestLayout.Spacing.xLarge + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundGradient, in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xxLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xxLarge, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusIcon: some View {
        Image(systemName: snapshot.level.iconName)
            .font(.system(size: ClawNestLayout.Typography.statusIcon, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: ClawNestLayout.Size.statusHeroIconBox, height: ClawNestLayout.Size.statusHeroIconBox)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.large, style: .continuous))
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.level.label(in: language).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))
                .tracking(2)

            Text(snapshot.headline)
                .font(.system(size: ClawNestLayout.Typography.heroTitle, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(snapshot.detail)
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusChip(label: String, value: String, alignment: HorizontalAlignment = .trailing) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.small, style: .continuous))
    }

    private var backgroundGradient: LinearGradient {
        switch snapshot.level {
        case .healthy:
            return LinearGradient(
                colors: [Color(red: 0.18, green: 0.64, blue: 0.43), Color(red: 0.12, green: 0.36, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .recovering:
            return LinearGradient(
                colors: [Color(red: 0.16, green: 0.57, blue: 0.84), Color(red: 0.12, green: 0.28, blue: 0.54)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .degraded:
            return LinearGradient(
                colors: [Color(red: 0.92, green: 0.58, blue: 0.24), Color(red: 0.56, green: 0.30, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .offline, .missingCLI:
            return LinearGradient(
                colors: [Color(red: 0.74, green: 0.29, blue: 0.24), Color(red: 0.35, green: 0.12, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct ControlPanelView: View {
    @ObservedObject var model: AppModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: localized("Claw Actions", "Claw 动作", language: language),
                subtitle: localized("The current runtime stays recoverable even when the dashboard surface is having a bad day.", "即使 dashboard 状态不好，当前 runtime 仍然可以在这里恢复。", language: language)
            )

            ForEach(model.snapshot.suggestedActions) { action in
                Button {
                    model.perform(action)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.systemImage)
                            .font(.title3)
                            .frame(width: 28)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.title(in: language))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(action.subtitle(in: language))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.isBusy && action != .openDashboard && action != .revealLogs && action != .openInstallGuide)
            }
        }
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }
}

struct MetricsPanelView: View {
    let snapshot: GatewaySnapshot
    let language: AppLanguage
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: localized("Runtime Details", "运行时细节", language: language),
                subtitle: localized("A warmer presentation of the same health data the app already knows how to collect.", "把已经采集到的健康数据，用更友好的方式展示出来。", language: language)
            )

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.detailFactMinimumWidth), spacing: 14)], alignment: .leading, spacing: 14) {
                ForEach(snapshot.metrics) { metric in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(metric.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.52))
                        Text(metric.value)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }
}

struct DashboardPanelView: View {
    @ObservedObject var model: AppModel
    let title: String
    let subtitle: String
    let language: AppLanguage
    let dashboardMinHeight: CGFloat
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(title: title, subtitle: subtitle)

            ZStack {
                DashboardWebView(
                    url: model.snapshot.dashboardURL,
                    reloadToken: model.dashboardReloadToken,
                    onStateChange: { state in
                        switch state {
                        case .loading:
                            model.dashboardDidStartLoading()
                        case .ready:
                            model.dashboardDidBecomeReady()
                        case let .failed(description):
                            model.dashboardDidFail(description)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: ClawNestLayout.Radius.large, style: .continuous))

                if overlayVisible {
                    overlayView
                }
            }
            .frame(minHeight: dashboardMinHeight)
        }
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }

    private var overlayVisible: Bool {
        model.snapshot.level == .offline || model.snapshot.level == .missingCLI || model.dashboardWebError != nil || model.isDashboardLoading
    }

    @ViewBuilder
    private var overlayView: some View {
        RoundedRectangle(cornerRadius: ClawNestLayout.Radius.large, style: .continuous)
            .fill(.black.opacity(0.56))
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: overlayIcon)
                        .font(.system(size: ClawNestLayout.Typography.overlayIcon, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(overlayTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Text(overlayMessage)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: ClawNestLayout.Size.overlayTextWidth)

                    FlowLayout(spacing: 12, rowSpacing: 12) {
                        Button(localized("Reload Surface", "重新加载界面", language: language)) {
                            model.reloadDashboard()
                        }
                        .buttonStyle(.borderedProminent)

                        if model.snapshot.level != .missingCLI {
                            Button(localized("Restart Gateway", "重启网关", language: language)) {
                                model.perform(.restartGateway)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(localized("Open Install Guide", "打开安装指南", language: language)) {
                                model.perform(.openInstallGuide)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(ClawNestLayout.Spacing.xLarge)
            }
    }

    private var overlayIcon: String {
        if model.isDashboardLoading {
            return "network.badge.shield.half.filled"
        }
        if model.snapshot.level == .missingCLI {
            return "shippingbox.fill"
        }
        return "waveform.path.ecg.rectangle"
    }

    private var overlayTitle: String {
        if model.isDashboardLoading {
            return localized("Dashboard is reconnecting", "Dashboard 正在重新连接", language: language)
        }
        if model.snapshot.level == .missingCLI {
            return localized("OpenClaw CLI is missing", "OpenClaw CLI 缺失", language: language)
        }
        return localized("Dashboard needs help", "Dashboard 需要处理", language: language)
    }

    private var overlayMessage: String {
        if let dashboardWebError = model.dashboardWebError {
            return dashboardWebError
        }
        return model.snapshot.detail
    }
}

struct ActivityFeedView: View {
    let entries: [DiagnosticEntry]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: localized("Caretaker Notes", "守护者笔记", language: language),
                subtitle: localized("The same diagnostics stream, softened into readable updates.", "同一条诊断流，用更可读的方式呈现。", language: language)
            )

            if entries.isEmpty {
                Text(localized("No moments yet.", "还没有动态。", language: language))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.56))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(entry.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white.opacity(0.48))
                            }

                            Text(entry.message)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.68))

                            if let command = entry.command {
                                Text(command)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white.opacity(0.52))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(backgroundColor(for: entry.level), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }

    private func backgroundColor(for level: DiagnosticLevel) -> Color {
        switch level {
        case .success:
            return Color(red: 0.12, green: 0.25, blue: 0.18).opacity(0.88)
        case .info:
            return Color.white.opacity(0.04)
        case .warning:
            return Color(red: 0.27, green: 0.19, blue: 0.08).opacity(0.92)
        case .error:
            return Color(red: 0.29, green: 0.11, blue: 0.13).opacity(0.92)
        }
    }
}

struct LatestLogView: View {
    let summary: LogSummary?
    let rawProbe: String
    let language: AppLanguage
    let logMinHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: localized("Latest Log + Raw Probe", "最新日志与原始探测", language: language),
                subtitle: localized("The honest, unsoftened technical layer is still one glance away.", "最原始、最技术化的信息依然随时可看。", language: language)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(summary?.path ?? localized("No OpenClaw log file was found under /tmp/openclaw yet.", "在 /tmp/openclaw 下还没有找到 OpenClaw 日志。", language: language))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.52))
                Divider()
                    .overlay(Color.white.opacity(0.08))
                ScrollView {
                    Text(summary?.excerpt ?? (rawProbe.isEmpty ? localized("No log excerpt or raw probe payload is available yet.", "还没有日志摘录或原始探测内容。", language: language) : rawProbe))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: logMinHeight)
            }
            .padding(ClawNestLayout.Spacing.large - 2)
            .background(Color.black.opacity(0.84), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium + 2, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
    }
}

struct ConfigurationEditorView: View {
    let configuration: ClawNestConfiguration
    let isBusy: Bool
    let language: AppLanguage
    let layout: WorkspaceLayoutMetrics
    let onSave: (ClawNestConfiguration) -> Void
    let onReset: () -> Void

    @State private var draft: ClawNestConfiguration

    init(
        configuration: ClawNestConfiguration,
        isBusy: Bool,
        language: AppLanguage,
        layout: WorkspaceLayoutMetrics,
        onSave: @escaping (ClawNestConfiguration) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.isBusy = isBusy
        self.language = language
        self.layout = layout
        self.onSave = onSave
        self.onReset = onReset
        _draft = State(initialValue: configuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: localized("Current Runtime Settings", "当前运行时设置", language: language),
                subtitle: localized("The technical knobs stay editable, but they now live behind the active Claw instead of taking over the whole app.", "技术参数依然可编辑，只是现在放到了活动 Claw 后面，而不是占满整个应用。", language: language)
            )

            Group {
                if layout.formStacksVertically {
                    VStack(alignment: .leading, spacing: 20) {
                        configurationFields
                        configurationControls
                    }
                } else {
                    HStack(alignment: .top, spacing: 20) {
                        configurationFields
                        configurationControls
                    }
                }
            }

            FlowLayout(spacing: 12, rowSpacing: 12) {
                Button(localized("Save Settings", "保存设置", language: language)) {
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.98, green: 0.66, blue: 0.38))
                .disabled(isBusy || draft == configuration)

                Button(localized("Reset to Defaults", "恢复默认", language: language)) {
                    draft = .standard
                    onReset()
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
        .padding(ClawNestLayout.Spacing.large + 2)
        .shellPanelBackground()
        .onChange(of: configuration) { _, newValue in
            draft = newValue
        }
    }

    private var configurationFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledField(localized("OpenClaw command", "OpenClaw 命令", language: language), text: $draft.openClawCommand)
            labeledField(localized("Dashboard URL", "Dashboard 地址", language: language), text: $draft.dashboardURLString)
            labeledField(localized("LaunchAgent label", "LaunchAgent 标签", language: language), text: $draft.launchAgentLabel)
        }
    }

    private var configurationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Probe interval", "探测间隔", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))

            HStack {
                Slider(value: $draft.probeIntervalSeconds, in: 15 ... 180, step: 15)
                Text("\(Int(draft.probeIntervalSeconds))s")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: ClawNestLayout.Size.sliderValueWidth)
            }

            Toggle(localized("Allow automatic gateway restart after repeated offline probes", "连续离线探测后允许自动重启网关", language: language), isOn: $draft.autoRestartEnabled)
                .toggleStyle(.switch)
                .foregroundStyle(.white)

            Text(localized("Still off by default. Leave it disabled if OpenClaw TUI and WebUI are already healthy and you only want passive monitoring.", "默认仍然关闭。如果 OpenClaw 的 TUI 和 WebUI 已经稳定，同时你只想被动监控，就继续保持关闭。", language: language))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
        }
    }
}
