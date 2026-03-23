import SwiftUI

struct ClawsWorkspaceView: View {
    @ObservedObject var model: AppModel
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    let currentClaw: ClawSummary
    let claws: [ClawSummary]
    let selectedClaw: ClawSummary
    @Binding var selectedClawDetailSection: ClawDetailSection
    let selectedClawMomentPosts: [MomentFeedItem]
    let selectedClawTasks: [ClawTaskSummary]
    let onSelectClaw: (ClawSummary, ClawDetailSection) -> Void
    let onOpenChat: (ClawSummary) -> Void
    let onStartClaw: (ClawSummary) -> Void

    var body: some View {
        Group {
            if layout.pageUsesVerticalRail {
                VStack(alignment: .leading, spacing: layout.groupSpacing) {
                    clawsRail
                    clawsDetailColumn
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    clawsRail
                        .frame(width: layout.clawsRailWidth)
                        .frame(maxHeight: .infinity)
                    clawsDetailColumn
                }
            }
        }
    }

    private var clawsDetailColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            WorkspaceHeaderView(
                eyebrow: t("Claws", "Claws"),
                title: t("Every Claw gets a face, a status, and a home page that feels alive.", "每个 Claw 都有自己的形象、状态，以及一个更鲜活的主页。"),
                subtitle: t("The left side is for fast scanning. The right side is the selected Claw home, broken into overview, agents, moments, tasks, logs, and settings.", "左侧负责快速扫视，右侧是当前 Claw 的主页，分成概览、Agents、动态、任务、日志和设置。")
            )

            selectedClawHomeHeader
            clawDetailSectionPicker

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    selectedClawDetailContent
                }
                .padding(layout.pageInset)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var clawsRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: t("Claw List", "Claw 列表"),
                subtitle: t("Warm cards, strong hierarchy, instant distinction.", "卡片温暖、层次清晰、彼此一眼可分。")
            )

            HStack(spacing: 10) {
                SmallStatCard(
                    title: t("Online", "在线"),
                    value: "\(claws.filter(\.isOnline).count)",
                    tint: Color(red: 0.31, green: 0.86, blue: 0.54)
                )
                SmallStatCard(
                    title: t("Total", "总数"),
                    value: "\(claws.count)",
                    tint: Color(red: 0.98, green: 0.66, blue: 0.38)
                )
                SmallStatCard(
                    title: t("Alerts", "提醒"),
                    value: "\(claws.compactMap(\.alertBadge).count)",
                    tint: Color(red: 0.94, green: 0.48, blue: 0.38)
                )
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(claws) { claw in
                        clawCard(claw)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            ShellCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("Bring in another Claw", "添加另一个 Claw"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(t("The installer is still the real one. This shortcut simply drops you into the Settings section where expansion lives.", "安装器仍然是可用的真实功能，这个入口只是带你跳到 Settings 里的扩展区域。"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)

                    Button(t("New Claw", "新建 Claw")) {
                        onSelectClaw(currentClaw, .settings)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentClaw.primaryColor)
                }
            }
        }
    }

    private func clawCard(_ claw: ClawSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                AvatarBadgeView(
                    text: claw.avatarText,
                    primaryColor: claw.primaryColor,
                    secondaryColor: claw.secondaryColor,
                    size: 58
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(claw.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if claw.isCurrent {
                            PillLabelView(label: t("Current", "当前"), systemImage: "heart.fill", tint: claw.primaryColor)
                        }
                    }

                    HStack(spacing: 8) {
                        StatusDotView(color: claw.statusColor)
                        Text(claw.statusLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.86))
                    }

                    Text(claw.machineLabel)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let badge = claw.alertBadge {
                    WarningBadgeView(badge: badge)
                }
            }

            FlowLayout(spacing: 12, rowSpacing: 12) {
                clawMetaPill(title: t("Last active", "最近活跃"), value: claw.lastActiveAt.formatted(date: .omitted, time: .shortened))
                clawMetaPill(title: t("Agents", "Agents"), value: "\(claw.agents.count)")
                clawMetaPill(title: t("Health", "健康"), value: claw.healthLabel)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.quickActionMinimumWidth), spacing: 8)], spacing: 8) {
                QuickActionButton(
                    title: t("Chat", "聊天"),
                    systemImage: "message.fill",
                    tint: claw.primaryColor
                ) {
                    onOpenChat(claw)
                }

                QuickActionButton(
                    title: t("Start", "启动"),
                    systemImage: "play.fill",
                    tint: Color(red: 0.28, green: 0.76, blue: 0.48),
                    disabled: !claw.canStart || model.isBusy
                ) {
                    onStartClaw(claw)
                }

                QuickActionButton(
                    title: t("Stop", "停止"),
                    systemImage: "stop.fill",
                    tint: Color(red: 0.92, green: 0.39, blue: 0.38),
                    disabled: true
                ) { }
                .help(t("Per-instance stop control is not implemented yet.", "按实例停止控制暂时还没有实现。"))

                QuickActionButton(
                    title: t("Details", "详情"),
                    systemImage: "rectangle.inset.filled.and.person.filled",
                    tint: claw.secondaryColor
                ) {
                    onSelectClaw(claw, .overview)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(selectedClaw.id == claw.id ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(selectedClaw.id == claw.id ? claw.primaryColor.opacity(0.42) : Color.white.opacity(0.05), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [claw.primaryColor, claw.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 92, height: 6)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                }
        )
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            onSelectClaw(claw, .overview)
        }
    }

    private var selectedClawHomeHeader: some View {
        ShellCard {
            if layout.headerStacksVertically {
                VStack(alignment: .leading, spacing: layout.groupSpacing) {
                    selectedClawHomeIdentity
                    selectedClawHomeActions
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    selectedClawHomeIdentity
                    Spacer(minLength: 12)
                    selectedClawHomeActions
                        .frame(width: 200)
                }
            }
        }
    }

    private var selectedClawHomeIdentity: some View {
        HStack(alignment: .top, spacing: 18) {
            AvatarBadgeView(
                text: selectedClaw.avatarText,
                primaryColor: selectedClaw.primaryColor,
                secondaryColor: selectedClaw.secondaryColor,
                size: ClawNestLayout.Size.clawHeaderAvatar
            )

            VStack(alignment: .leading, spacing: 10) {
                FlowLayout(spacing: 10, rowSpacing: 10) {
                    Text(selectedClaw.name)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if selectedClaw.isCurrent {
                        PillLabelView(label: t("Current", "当前"), systemImage: "bolt.fill", tint: selectedClaw.primaryColor)
                    }
                    if let badge = selectedClaw.alertBadge {
                        WarningBadgeView(badge: badge)
                    }
                }

                Text(selectedClaw.statusDescription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 10, rowSpacing: 10) {
                    PillLabelView(label: selectedClaw.machineLabel, systemImage: "macbook", tint: .white.opacity(0.18))
                    PillLabelView(label: "\(selectedClaw.agents.count) \(t("agents", "agents"))", systemImage: "person.2.fill", tint: selectedClaw.secondaryColor)
                    PillLabelView(label: selectedClaw.lastActiveAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock", tint: .white.opacity(0.18))
                    PillLabelView(label: selectedClaw.launchAgentLabel, systemImage: "antenna.radiowaves.left.and.right", tint: selectedClaw.secondaryColor)
                }
                .frame(maxWidth: layout.metadataWrapWidth, alignment: .leading)
            }
        }
    }

    private var selectedClawHomeActions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.quickActionMinimumWidth), spacing: 10)], spacing: 10) {
            QuickActionButton(
                title: t("Chat", "聊天"),
                systemImage: "message.fill",
                tint: selectedClaw.primaryColor
            ) {
                onOpenChat(selectedClaw)
            }

            QuickActionButton(
                title: t("Details", "详情"),
                systemImage: "rectangle.inset.filled.and.person.filled",
                tint: selectedClaw.secondaryColor
            ) {
                onSelectClaw(selectedClaw, .overview)
            }
        }
    }

    private var clawDetailSectionPicker: some View {
        ShellCard {
            FlowLayout(spacing: 10, rowSpacing: 10) {
                ForEach(ClawDetailSection.allCases) { section in
                    Button {
                        selectedClawDetailSection = section
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.systemImage)
                            Text(section.title(in: language))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedClawDetailSection == section ? Color.black : Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedClawDetailSection == section
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [selectedClaw.primaryColor, selectedClaw.secondaryColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        : AnyShapeStyle(Color.white.opacity(0.05))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedClawDetailContent: some View {
        switch selectedClawDetailSection {
        case .overview:
            clawOverviewContent
        case .agents:
            clawAgentsContent
        case .recentMoments:
            clawRecentMomentsContent
        case .tasks:
            clawTasksContent
        case .logs:
            clawLogsContent
        case .settings:
            clawSettingsContent
        }
    }

    private var clawOverviewContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedClaw.isCurrent {
                StatusHeroView(snapshot: model.snapshot, isBusy: model.isBusy, language: language, layout: layout)
            } else {
                remoteClawOverviewCard
            }

            DetailFactsGrid(
                layout: layout,
                facts: [
                    (t("Machine", "机器"), selectedClaw.machineLabel),
                    (t("Last active", "最近活跃"), selectedClaw.lastActiveAt.formatted(date: .abbreviated, time: .shortened)),
                    (t("Agents", "Agents"), "\(selectedClaw.agents.count)"),
                    (t("Recent moments", "最近动态"), "\(selectedClawMomentPosts.count)")
                ]
            )

            if selectedClaw.isCurrent {
                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            ControlPanelView(model: model, language: language)
                            overviewMetricsGroup
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            ControlPanelView(model: model, language: language)
                                .frame(width: layout.supportRailWidth)
                            overviewMetricsGroup
                        }
                    }
                }
            } else {
                PlaceholderCardView(
                    title: t("Remote overview is reserved.", "远程概览已预留。"),
                    bodyText: t("This Claw has identity, agents, and reserved ports, but live host telemetry for non-current Claws is still not wired.", "这个 Claw 已经有身份信息、agents 和预留端口，但非当前 Claw 的实时主机遥测还没有接上。")
                )
            }
        }
    }

    private var overviewMetricsGroup: some View {
        VStack(spacing: 20) {
            overviewSummaryCard
            MetricsPanelView(snapshot: model.snapshot, language: language, layout: layout)
        }
    }

    private var clawAgentsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: t("Agents", "Agents"),
                subtitle: t("Every agent under this Claw gets a role, a state, and a direct path into chat.", "这个 Claw 下的每个 agent 都有角色、状态和直达聊天的入口。")
            )

            ForEach(selectedClaw.agents) { agent in
                clawAgentHomeCard(agent)
            }
        }
    }

    private var clawRecentMomentsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: t("Recent Moments", "最近动态"),
                subtitle: t("Social-style updates for tasks, failures, memory changes, and health shifts.", "用社交动态的形式展示任务完成、失败、记忆变化和健康状态变化。")
            )

            if selectedClawMomentPosts.isEmpty {
                PlaceholderCardView(
                    title: t("No moments for this Claw yet.", "这个 Claw 还没有动态。"),
                    bodyText: t("Once this Claw reports activity, it will show up here as a timeline instead of raw status noise.", "当这个 Claw 开始产生事件时，它会在这里以时间流卡片的形式出现，而不是原始状态噪音。")
                )
            } else {
                ForEach(selectedClawMomentPosts) { post in
                    MomentCardView(post: post)
                }
            }
        }
    }

    private var clawTasksContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: t("Tasks", "任务"),
                subtitle: t("Running and recent work for this Claw belongs here.", "这个 Claw 的运行中任务和最近任务都应该出现在这里。")
            )

            ForEach(selectedClawTasks) { task in
                clawTaskCard(task)
            }
        }
    }

    private var clawLogsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: t("Logs", "日志"),
                subtitle: t("Runtime logs stay available without pushing users back into Terminal.", "运行日志依然可以直接查看，不需要把用户赶回终端。")
            )

            if selectedClaw.isCurrent {
                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            LatestLogView(summary: model.snapshot.logSummary, rawProbe: model.snapshot.rawProbe, language: language, logMinHeight: layout.logMinHeight)
                            ActivityFeedView(entries: Array(model.diagnostics.prefix(8)), language: language)
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            LatestLogView(summary: model.snapshot.logSummary, rawProbe: model.snapshot.rawProbe, language: language, logMinHeight: layout.logMinHeight)
                            ActivityFeedView(entries: Array(model.diagnostics.prefix(8)), language: language)
                        }
                    }
                }
            } else {
                PlaceholderCardView(
                    title: t("Per-Claw remote logs are not wired yet.", "按 Claw 归档的远程日志还没接上。"),
                    bodyText: t("When non-current Claws can stream their own runtime logs, this page will stop being empty.", "当非当前 Claw 也能回传各自的运行日志时，这个页面就不会再是空的。")
                )
            }
        }
    }

    private var clawSettingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PanelHeaderView(
                title: t("Settings", "设置"),
                subtitle: t("Configuration, providers, tools, permissions, and expansion live here.", "配置、模型提供方、工具、权限和扩展能力都放在这里。")
            )

            if selectedClaw.isCurrent {
                ConfigurationEditorView(
                    configuration: model.configuration,
                    isBusy: model.isBusy,
                    language: language,
                    layout: layout,
                    onSave: model.saveConfiguration(_:),
                    onReset: {
                        model.saveConfiguration(.standard)
                    }
                )

                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            PlaceholderCardView(
                                title: t("Model providers", "模型提供方"),
                                bodyText: t("Provider-level tuning is reserved here. The runtime configuration editor above is live today; provider-specific settings are still a placeholder.", "这里预留给模型提供方相关配置。上面的运行时编辑器已经可用，但 provider 级别设置还只是占位。")
                            )
                            PlaceholderCardView(
                                title: t("Tools and permissions", "工具与权限"),
                                bodyText: t("Tool allowlists, device permissions, and safer per-Claw policies belong in this section later.", "工具白名单、设备权限和更细的按 Claw 策略之后会落在这里。")
                            )
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            PlaceholderCardView(
                                title: t("Model providers", "模型提供方"),
                                bodyText: t("Provider-level tuning is reserved here. The runtime configuration editor above is live today; provider-specific settings are still a placeholder.", "这里预留给模型提供方相关配置。上面的运行时编辑器已经可用，但 provider 级别设置还只是占位。")
                            )
                            PlaceholderCardView(
                                title: t("Tools and permissions", "工具与权限"),
                                bodyText: t("Tool allowlists, device permissions, and safer per-Claw policies belong in this section later.", "工具白名单、设备权限和更细的按 Claw 策略之后会落在这里。")
                            )
                        }
                    }
                }

                OpenClawInstallView(model: model, language: language, layout: layout)
            } else {
                PlaceholderCardView(
                    title: t("Remote Claw settings are reserved.", "远程 Claw 设置已预留。"),
                    bodyText: t("ClawNest only edits the active runtime today. This page is ready for per-Claw settings once remote lifecycle management exists.", "ClawNest 目前只编辑活动 runtime。等远程生命周期管理接上后，这里就能放每个 Claw 自己的设置。")
                )

                ShellCard {
                    Group {
                        if layout.formStacksVertically {
                            VStack(alignment: .leading, spacing: 16) {
                                remoteSettingsPrompt
                                goToCurrentClawButton
                            }
                        } else {
                            HStack(alignment: .top, spacing: 16) {
                                remoteSettingsPrompt
                                Spacer()
                                goToCurrentClawButton
                            }
                        }
                    }
                }
            }
        }
    }

    private var remoteSettingsPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Need the live settings surface?", "需要当前可用的设置界面？"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(t("Jump back to the active Claw to edit runtime configuration or install another Claw.", "跳回活动 Claw 页面，就能编辑运行时配置或安装另一个 Claw。"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private var goToCurrentClawButton: some View {
        Button(t("Go to Current Claw", "前往当前 Claw")) {
            onSelectClaw(currentClaw, .settings)
        }
        .buttonStyle(.borderedProminent)
        .tint(currentClaw.primaryColor)
    }

    private var remoteClawOverviewCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("This Claw has a place, but not a full live link yet.", "这个 Claw 已经有位置，但还没有完整的实时连接。"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(t("You can already distinguish it, enter its detail home, and see its agents and reserved ports. Full remote lifecycle and telemetry support are still a placeholder.", "你已经可以区分它、进入它的主页，并查看它的 agents 和保留端口。完整的远程生命周期与遥测支持仍然是占位功能。"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                DetailFactsGrid(
                    layout: layout,
                    facts: [
                        (t("Install directory", "安装目录"), selectedClaw.installDirectoryPath),
                        ("LaunchAgent", selectedClaw.launchAgentLabel),
                        (t("Reserved ports", "保留端口"), selectedClaw.portSummary)
                    ]
                )
            }
        }
    }

    private var overviewSummaryCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Overview", "概览"))
                    .font(.headline)
                    .foregroundStyle(.white)

                DetailFactsGrid(
                    layout: layout,
                    facts: [
                        (t("Active agents", "活跃 Agents"), "\(selectedClaw.agents.count)"),
                        (t("Recent activity", "最近活动"), selectedClawMomentPosts.first?.headline ?? t("Quiet for now", "目前较安静"))
                    ]
                )

                Text(t("Health, runtime controls, and install/repair actions are already real. Tasks, remote telemetry, and deeper per-Claw settings are staged into the new layout without pretending they are done.", "健康状态、运行控制和安装/修复操作已经是真实可用的。任务、远程遥测和更深的按 Claw 设置则已经被安放到新布局里，但不会伪装成已完成功能。"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func clawAgentHomeCard(_ agent: ClawAgentSummary) -> some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(agent.role)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()

                    PillLabelView(label: agent.status, systemImage: "sparkles", tint: selectedClaw.primaryColor)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.quickActionMinimumWidth), spacing: 8)], spacing: 8) {
                    QuickActionButton(
                        title: t("Chat", "聊天"),
                        systemImage: "message.fill",
                        tint: selectedClaw.primaryColor
                    ) {
                        onOpenChat(selectedClaw)
                    }

                    ForEach(agent.actions) { action in
                        QuickActionButton(
                            title: action.title,
                            systemImage: action.systemImage,
                            tint: selectedClaw.secondaryColor,
                            disabled: action.recoveryAction == nil || (model.isBusy && action.recoveryAction != .openDashboard && action.recoveryAction != .revealLogs)
                        ) {
                            if let recoveryAction = action.recoveryAction {
                                model.perform(recoveryAction)
                            }
                        }
                    }
                }
            }
        }
    }

    private func clawTaskCard(_ task: ClawTaskSummary) -> some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(task.tint.opacity(0.20))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: task.systemImage)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(task.tint)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(task.detail)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(task.statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(task.tint)
                        Text(task.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.48))
                    }
                }
            }
        }
    }

    private func clawMetaPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: language)
    }
}
