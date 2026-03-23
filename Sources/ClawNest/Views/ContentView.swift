import Foundation
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    @State private var selectedSection: WorkspaceSection = .chat
    @State private var selectedConversationID: String?
    @State private var selectedClawID: String?
    @State private var selectedClawDetailSection: ClawDetailSection = .overview
    @State private var selectedMomentFilterID = WorkspaceMomentFilter.allID

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceLayoutMetrics(containerSize: proxy.size)

            ZStack {
                AppShellBackgroundView(layout: layout)

                HStack(spacing: 0) {
                    WorkspaceSidebarView(
                        layout: layout,
                        language: currentLanguage,
                        currentClaw: currentClaw,
                        selectedSection: selectedSection,
                        liveClawCount: claws.filter(\.isOnline).count,
                        clawCount: claws.count,
                        momentCount: momentPosts.count,
                        snapshot: model.snapshot,
                        onSelectSection: { selectedSection = $0 }
                    )

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    detailSurface(layout: layout)
                }
                .padding(layout.rootPadding)
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: ClawNestLayout.Window.minimumWidth, minHeight: ClawNestLayout.Window.minimumHeight)
    }

    private var currentLanguage: AppLanguage {
        model.language
    }

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: currentLanguage)
    }

    @ViewBuilder
    private func detailSurface(layout: WorkspaceLayoutMetrics) -> some View {
        Group {
            switch selectedSection {
            case .chat:
                ChatWorkspaceView(
                    model: model,
                    layout: layout,
                    language: currentLanguage,
                    currentClaw: currentClaw,
                    selectedConversation: selectedConversation,
                    conversations: conversations,
                    onSelectConversation: { selectedConversationID = $0 },
                    onOpenClaws: { selectedSection = .claws },
                    onOpenMoments: { selectedSection = .moments }
                )
            case .claws:
                ClawsWorkspaceView(
                    model: model,
                    layout: layout,
                    language: currentLanguage,
                    currentClaw: currentClaw,
                    claws: claws,
                    selectedClaw: selectedClaw,
                    selectedClawDetailSection: $selectedClawDetailSection,
                    selectedClawMomentPosts: selectedClawMomentPosts,
                    selectedClawTasks: selectedClawTasks,
                    onSelectClaw: showClawDetails(_:section:),
                    onOpenChat: openChat(for:),
                    onStartClaw: startClaw(_:)
                )
            case .moments:
                MomentsWorkspaceView(
                    layout: layout,
                    language: currentLanguage,
                    momentFilters: momentFilters,
                    activeMomentFilterID: activeMomentFilterID,
                    filteredMomentPosts: filteredMomentPosts,
                    onSelectFilter: { selectedMomentFilterID = $0 }
                )
            case .mine:
                MineWorkspaceView(
                    model: model,
                    layout: layout,
                    language: currentLanguage,
                    currentClaw: currentClaw,
                    clawCount: claws.count,
                    momentCount: momentPosts.count,
                    onOpenClaws: { selectedSection = .claws },
                    onOpenMoments: { selectedSection = .moments }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(layout.surfacePadding)
    }

    private var claws: [ClawSummary] {
        let deviceName = Host.current().localizedName ?? "This Mac"
        let palettes = ClawPalette.defaults
        let currentPort = model.configuration.dashboardURL.port ?? 18789
        let currentLastActive = model.snapshot.lastHealthy ?? model.snapshot.lastCheck
        let currentKnownInstance = model.knownOpenClawInstances.first {
            $0.launchAgentLabel == model.configuration.launchAgentLabel || $0.dashboardURLString == model.configuration.dashboardURLString
        }

        var summaries: [ClawSummary] = []

        let currentPalette = palettes[0]
        summaries.append(
            ClawSummary(
                id: currentKnownInstance?.installDirectoryPath ?? "current-\(model.configuration.launchAgentLabel)",
                name: currentKnownInstance.map { "Claw \($0.gatewayPort)" } ?? t("Home Claw", "主 Claw"),
                avatarText: currentKnownInstance.map { "\($0.gatewayPort % 100)" } ?? "HM",
                machineLabel: "\(deviceName) • Port \(currentPort)",
                statusLabel: model.snapshot.level.label(in: currentLanguage),
                statusDescription: model.snapshot.detail,
                statusColor: model.snapshot.level.tintColor,
                healthLabel: model.snapshot.level.label(in: currentLanguage),
                installDirectoryPath: currentKnownInstance?.installDirectoryPath ?? "Using `\(model.configuration.openClawCommand)` from the current runtime",
                launchAgentLabel: model.configuration.launchAgentLabel,
                dashboardURLString: model.configuration.dashboardURL.absoluteString,
                reservedPorts: currentKnownInstance?.reservedPorts ?? [currentPort],
                lastActiveAt: currentLastActive,
                isCurrent: true,
                isOnline: model.snapshot.level != .offline && model.snapshot.level != .missingCLI,
                canStart: true,
                alertBadge: currentClawAlertBadge,
                primaryColor: currentPalette.primary,
                secondaryColor: currentPalette.secondary,
                agents: currentClawAgents()
            )
        )

        let remainingInstances = model.knownOpenClawInstances.filter { instance in
            instance.installDirectoryPath != currentKnownInstance?.installDirectoryPath
        }

        for (index, instance) in remainingInstances.enumerated() {
            let palette = palettes[(index + 1) % palettes.count]
            summaries.append(
                ClawSummary(
                    id: instance.installDirectoryPath,
                    name: "Claw \(instance.gatewayPort)",
                    avatarText: "\(instance.gatewayPort % 100)",
                    machineLabel: "\(deviceName) • Port \(instance.gatewayPort)",
                    statusLabel: t("Offline", "离线"),
                    statusDescription: t("Installed and remembered by ClawNest. Remote live status for this non-current Claw is still a placeholder.", "这个实例已经被 ClawNest 记住，但非当前 Claw 的实时状态还只是占位。"),
                    statusColor: Color(red: 0.95, green: 0.72, blue: 0.38),
                    healthLabel: t("Not connected", "未连接"),
                    installDirectoryPath: instance.installDirectoryPath,
                    launchAgentLabel: instance.launchAgentLabel,
                    dashboardURLString: instance.dashboardURLString,
                    reservedPorts: instance.reservedPorts,
                    lastActiveAt: instance.installedAt,
                    isCurrent: false,
                    isOnline: false,
                    canStart: false,
                    alertBadge: nil,
                    primaryColor: palette.primary,
                    secondaryColor: palette.secondary,
                    agents: placeholderAgents()
                )
            )
        }

        return summaries
    }

    private var currentClaw: ClawSummary {
        claws.first(where: \.isCurrent) ?? claws[0]
    }

    private var selectedClaw: ClawSummary {
        claws.first(where: { $0.id == selectedClawID }) ?? currentClaw
    }

    private var currentClawAlertBadge: ClawAlertBadge? {
        let errorCount = model.diagnostics.filter { $0.level == .error }.count
        let warningCount = model.diagnostics.filter { $0.level == .warning }.count

        if model.snapshot.level == .offline || model.snapshot.level == .missingCLI || errorCount > 0 {
            return ClawAlertBadge(
                label: errorCount > 0 ? t("\(errorCount) issue", "\(errorCount) 个问题") : t("Offline", "离线"),
                systemImage: "exclamationmark.octagon.fill",
                tint: Color(red: 0.92, green: 0.39, blue: 0.38)
            )
        }

        if model.snapshot.level == .degraded || warningCount > 0 {
            return ClawAlertBadge(
                label: warningCount > 0 ? t("\(warningCount) alerts", "\(warningCount) 个提醒") : t("Attention", "需关注"),
                systemImage: "exclamationmark.triangle.fill",
                tint: Color(red: 0.97, green: 0.69, blue: 0.33)
            )
        }

        return nil
    }

    private var selectedClawMomentPosts: [MomentFeedItem] {
        momentPosts.filter { $0.clawID == selectedClaw.id }
    }

    private var selectedClawTasks: [ClawTaskSummary] {
        if selectedClaw.isCurrent {
            var tasks: [ClawTaskSummary] = [
                ClawTaskSummary(
                    title: t("Health monitor", "健康监看"),
                    detail: t("Checking this Claw every \(Int(model.configuration.probeIntervalSeconds)) seconds in observe-first mode.", "以观察优先模式每 \(Int(model.configuration.probeIntervalSeconds)) 秒检查一次这个 Claw。"),
                    statusLabel: t("Running", "运行中"),
                    systemImage: "waveform.path.ecg",
                    tint: Color(red: 0.31, green: 0.86, blue: 0.54),
                    timestamp: model.snapshot.lastCheck
                ),
                ClawTaskSummary(
                    title: t("Dashboard link", "Dashboard 连接"),
                    detail: dashboardTaskDetail,
                    statusLabel: dashboardTaskStatus,
                    systemImage: dashboardTaskIcon,
                    tint: dashboardTaskTint,
                    timestamp: model.snapshot.lastCheck
                ),
                ClawTaskSummary(
                    title: t("Recovery lane", "恢复通道"),
                    detail: model.configuration.autoRestartEnabled
                        ? t("Automatic recovery is armed after repeated offline probes.", "连续离线探测后会启用自动恢复。")
                        : t("Observe-only mode is active. Recovery stays opt-in.", "当前是观察模式，恢复操作保持手动触发。"),
                    statusLabel: model.configuration.autoRestartEnabled ? t("Armed", "已启用") : t("Passive", "被动模式"),
                    systemImage: model.configuration.autoRestartEnabled ? "bolt.badge.clock.fill" : "shield.lefthalf.filled",
                    tint: model.configuration.autoRestartEnabled ? Color(red: 0.96, green: 0.67, blue: 0.36) : Color(red: 0.38, green: 0.78, blue: 0.84),
                    timestamp: model.snapshot.lastCheck
                )
            ]

            if let installStatusMessage = model.installStatusMessage, !installStatusMessage.isEmpty {
                tasks.append(
                    ClawTaskSummary(
                        title: t("Installer lane", "安装通道"),
                        detail: installStatusMessage,
                        statusLabel: model.isInstallingOpenClaw ? t("Running", "运行中") : t("Latest", "最近"),
                        systemImage: model.isInstallingOpenClaw ? "shippingbox.fill" : "tray.and.arrow.down.fill",
                        tint: Color(red: 0.98, green: 0.66, blue: 0.38),
                        timestamp: .now
                    )
                )
            }

            return tasks
        }

        return [
            ClawTaskSummary(
                title: t("Remote task sync", "远程任务同步"),
                detail: t("Task history for non-current Claws has a reserved slot in the UI, but the data bridge is not wired yet.", "非当前 Claw 的任务历史已经在 UI 里预留位置，但数据桥还没有接上。"),
                statusLabel: t("Soon", "即将支持"),
                systemImage: "clock.arrow.2.circlepath",
                tint: Color.white.opacity(0.72),
                timestamp: selectedClaw.lastActiveAt
            ),
            ClawTaskSummary(
                title: t("Lifecycle control", "生命周期控制"),
                detail: t("Start and stop actions for individual remote Claws still need real per-instance lifecycle support.", "单独远程 Claw 的启动和停止动作还需要真实的按实例生命周期支持。"),
                statusLabel: t("Pending", "待支持"),
                systemImage: "bolt.horizontal.circle",
                tint: selectedClaw.secondaryColor,
                timestamp: selectedClaw.lastActiveAt
            )
        ]
    }

    private var dashboardTaskDetail: String {
        if let dashboardWebError = model.dashboardWebError {
            return dashboardWebError
        }
        if model.isDashboardLoading {
            return t("The embedded dashboard is trying to reconnect.", "内嵌 dashboard 正在尝试重新连接。")
        }
        return t("The embedded dashboard surface is responsive.", "内嵌 dashboard 界面当前可用。")
    }

    private var dashboardTaskStatus: String {
        if model.dashboardWebError != nil {
            return t("Needs help", "需要处理")
        }
        if model.isDashboardLoading {
            return t("Reconnecting", "重连中")
        }
        return t("Healthy", "正常")
    }

    private var dashboardTaskIcon: String {
        if model.dashboardWebError != nil {
            return "exclamationmark.triangle.fill"
        }
        if model.isDashboardLoading {
            return "arrow.triangle.2.circlepath.circle.fill"
        }
        return "network"
    }

    private var dashboardTaskTint: Color {
        if model.dashboardWebError != nil {
            return Color(red: 0.92, green: 0.39, blue: 0.38)
        }
        if model.isDashboardLoading {
            return Color(red: 0.34, green: 0.73, blue: 0.94)
        }
        return Color(red: 0.31, green: 0.86, blue: 0.54)
    }

    private func currentClawAgents() -> [ClawAgentSummary] {
        [
            ClawAgentSummary(
                name: t("Companion", "陪伴者"),
                role: t("Primary conversation surface", "主会话界面"),
                status: model.snapshot.level.label(in: currentLanguage),
                actions: [
                    AgentActionSummary(title: t("Open", "打开"), systemImage: "message.fill", recoveryAction: .openDashboard),
                    AgentActionSummary(title: t("Refresh", "刷新"), systemImage: "arrow.clockwise", recoveryAction: .refresh)
                ]
            ),
            ClawAgentSummary(
                name: t("Caretaker", "守护者"),
                role: t("Recovery and repair", "恢复与修复"),
                status: model.isBusy ? t("Working", "处理中") : t("Standing by", "待命"),
                actions: [
                    AgentActionSummary(title: t("Restart", "重启"), systemImage: "bolt.badge.clock", recoveryAction: .restartGateway),
                    AgentActionSummary(title: t("Repair", "修复"), systemImage: "wrench.and.screwdriver", recoveryAction: .repairConfiguration)
                ]
            ),
            ClawAgentSummary(
                name: t("Archivist", "记录者"),
                role: t("Logs and memory traces", "日志与记忆痕迹"),
                status: model.snapshot.logSummary == nil ? t("Watching", "监看中") : t("Log snapshot ready", "日志快照已就绪"),
                actions: [
                    AgentActionSummary(title: t("Logs", "日志"), systemImage: "text.page", recoveryAction: .revealLogs),
                    AgentActionSummary(title: t("Guide", "指南"), systemImage: "book.closed", recoveryAction: .openInstallGuide)
                ]
            )
        ]
    }

    private func placeholderAgents() -> [ClawAgentSummary] {
        [
            ClawAgentSummary(
                name: t("Companion", "陪伴者"),
                role: t("Remote chat sync", "远程聊天同步"),
                status: t("Soon", "即将支持"),
                actions: [AgentActionSummary(title: t("Soon", "即将支持"), systemImage: "sparkles", recoveryAction: nil)]
            ),
            ClawAgentSummary(
                name: t("Caretaker", "守护者"),
                role: t("Remote recovery", "远程恢复"),
                status: t("Soon", "即将支持"),
                actions: [AgentActionSummary(title: t("Soon", "即将支持"), systemImage: "bolt.horizontal", recoveryAction: nil)]
            ),
            ClawAgentSummary(
                name: t("Archivist", "记录者"),
                role: t("Shared memory feed", "共享记忆流"),
                status: t("Soon", "即将支持"),
                actions: [AgentActionSummary(title: t("Soon", "即将支持"), systemImage: "tray.full", recoveryAction: nil)]
            )
        ]
    }

    private var conversations: [ChatThreadSummary] {
        var threads: [ChatThreadSummary] = []

        threads.append(
            ChatThreadSummary(
                id: "live-\(currentClaw.id)",
                title: t("Main thread", "主线程"),
                preview: model.snapshot.headline,
                description: t("The live dashboard-backed chat for your active Claw.", "当前活动 Claw 的实时 dashboard 会话。"),
                clawName: currentClaw.name,
                clawAvatar: currentClaw.avatarText,
                agentName: t("Companion", "陪伴者"),
                machineLabel: currentClaw.machineLabel,
                timestampText: model.snapshot.lastCheck.formatted(date: .omitted, time: .shortened),
                primaryColor: currentClaw.primaryColor,
                secondaryColor: currentClaw.secondaryColor,
                kind: .liveDashboard
            )
        )

        threads.append(
            ChatThreadSummary(
                id: "caretaker-\(currentClaw.id)",
                title: t("Caretaker room", "守护者房间"),
                preview: model.diagnostics.first?.title ?? t("Status notes and recovery guidance", "状态说明与恢复建议"),
                description: t("A softer conversation surface for recovery and monitoring actions.", "用于恢复和监控动作的轻量会话界面。"),
                clawName: currentClaw.name,
                clawAvatar: currentClaw.avatarText,
                agentName: t("Caretaker", "守护者"),
                machineLabel: currentClaw.machineLabel,
                timestampText: model.snapshot.lastCheck.formatted(date: .omitted, time: .shortened),
                primaryColor: currentClaw.primaryColor,
                secondaryColor: currentClaw.secondaryColor,
                kind: .caretaker
            )
        )

        threads.append(
            ChatThreadSummary(
                id: "installer-\(currentClaw.id)",
                title: t("New Claw setup", "新 Claw 安装"),
                preview: model.installValidation.message,
                description: t("A guided handoff into the OpenClaw installer surface.", "一个引导式入口，带你进入 OpenClaw 安装界面。"),
                clawName: currentClaw.name,
                clawAvatar: currentClaw.avatarText,
                agentName: t("Provisioner", "部署者"),
                machineLabel: currentClaw.machineLabel,
                timestampText: t("Setup", "安装"),
                primaryColor: currentClaw.primaryColor,
                secondaryColor: currentClaw.secondaryColor,
                kind: .installer
            )
        )

        for claw in claws where !claw.isCurrent {
            threads.append(
                ChatThreadSummary(
                    id: "placeholder-\(claw.id)",
                    title: "\(claw.name) lounge",
                    preview: t("Remote chat sync for this Claw has a reserved slot in the UI.", "这个 Claw 的远程聊天同步已经在 UI 中预留位置。"),
                    description: t("The page is intentionally blank until real cross-Claw messaging exists.", "在真正支持跨 Claw 消息之前，这个页面会刻意保持为空。"),
                    clawName: claw.name,
                    clawAvatar: claw.avatarText,
                    agentName: t("Companion", "陪伴者"),
                    machineLabel: claw.machineLabel,
                    timestampText: t("Soon", "即将支持"),
                    primaryColor: claw.primaryColor,
                    secondaryColor: claw.secondaryColor,
                    kind: .placeholder
                )
            )
        }

        return threads
    }

    private var selectedConversation: ChatThreadSummary {
        conversations.first(where: { $0.id == selectedConversationID }) ?? conversations[0]
    }

    private var momentPosts: [MomentFeedItem] {
        var posts: [MomentFeedItem] = model.diagnostics.map { entry in
            MomentFeedItem(
                clawID: currentClaw.id,
                clawName: currentClaw.name,
                clawAvatar: currentClaw.avatarText,
                primaryColor: currentClaw.primaryColor,
                secondaryColor: currentClaw.secondaryColor,
                kindLabel: entry.level.momentLabel(in: currentLanguage),
                iconName: entry.level.momentIcon,
                headline: entry.title,
                body: entry.message,
                timestamp: entry.timestamp,
                command: entry.command
            )
        }

        for claw in claws where !claw.isCurrent {
            posts.append(
                MomentFeedItem(
                    clawID: claw.id,
                    clawName: claw.name,
                    clawAvatar: claw.avatarText,
                    primaryColor: claw.primaryColor,
                    secondaryColor: claw.secondaryColor,
                    kindLabel: t("New Claw", "新 Claw"),
                    iconName: "sparkles",
                    headline: t("Joined ClawNest", "已加入 ClawNest"),
                    body: t("\(claw.name) is installed at \(claw.installDirectoryPath) and waiting for deeper remote sync.", "\(claw.name) 已安装在 \(claw.installDirectoryPath)，正在等待更完整的远程同步能力。"),
                    timestamp: model.knownOpenClawInstances.first(where: { $0.installDirectoryPath == claw.id })?.installedAt ?? .now,
                    command: nil
                )
            )
        }

        if posts.isEmpty {
            posts.append(
                MomentFeedItem(
                    clawID: currentClaw.id,
                    clawName: currentClaw.name,
                    clawAvatar: currentClaw.avatarText,
                    primaryColor: currentClaw.primaryColor,
                    secondaryColor: currentClaw.secondaryColor,
                    kindLabel: t("Heartbeat", "心跳"),
                    iconName: "waveform.path.ecg",
                    headline: model.snapshot.headline,
                    body: model.snapshot.detail,
                    timestamp: model.snapshot.lastCheck,
                    command: nil
                )
            )
        }

        return posts.sorted { $0.timestamp > $1.timestamp }
    }

    private var momentFilters: [WorkspaceMomentFilter] {
        [
            WorkspaceMomentFilter(id: WorkspaceMomentFilter.allID, title: t("All Claws", "所有 Claw"), color: Color.white.opacity(0.78))
        ] + claws.map {
            WorkspaceMomentFilter(id: $0.id, title: $0.name, color: $0.primaryColor)
        }
    }

    private var activeMomentFilterID: String {
        momentFilters.contains(where: { $0.id == selectedMomentFilterID }) ? selectedMomentFilterID : WorkspaceMomentFilter.allID
    }

    private var filteredMomentPosts: [MomentFeedItem] {
        guard activeMomentFilterID != WorkspaceMomentFilter.allID else {
            return momentPosts
        }

        return momentPosts.filter { $0.clawID == activeMomentFilterID }
    }

    private func showClawDetails(_ claw: ClawSummary, section: ClawDetailSection = .overview) {
        selectedClawID = claw.id
        selectedClawDetailSection = section
    }

    private func openChat(for claw: ClawSummary) {
        selectedSection = .chat
        if claw.isCurrent {
            selectedConversationID = "live-\(claw.id)"
        } else {
            selectedConversationID = "placeholder-\(claw.id)"
        }
    }

    private func startClaw(_ claw: ClawSummary) {
        showClawDetails(claw, section: .overview)
        guard claw.isCurrent else { return }
        model.perform(.restartGateway)
    }
}
