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
                background(layout: layout)

                HStack(spacing: 0) {
                    sidebar(layout: layout)
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

    private func background(layout: WorkspaceLayoutMetrics) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.11),
                    Color(red: 0.15, green: 0.12, blue: 0.16),
                    Color(red: 0.08, green: 0.11, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.95, green: 0.54, blue: 0.32).opacity(0.18))
                .frame(width: layout.isCompactHeight ? 340 : 420, height: layout.isCompactHeight ? 340 : 420)
                .blur(radius: 80)
                .offset(x: -340, y: -260)

            Circle()
                .fill(Color(red: 0.28, green: 0.67, blue: 0.93).opacity(0.18))
                .frame(width: layout.isCompactHeight ? 360 : 440, height: layout.isCompactHeight ? 360 : 440)
                .blur(radius: 90)
                .offset(x: 420, y: 280)

            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.canvas, style: .continuous)
                .fill(.white.opacity(0.03))
                .padding(ClawNestLayout.Spacing.small)
                .blur(radius: 2)
        }
    }

    private func sidebar(layout: WorkspaceLayoutMetrics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.groupSpacing) {
                sidebarBrandSection
                sidebarNavigationSection
                sidebarPulseSection
                sidebarFooterSection
            }
            .padding(layout.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(width: layout.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.shell, style: .continuous)
                .fill(.black.opacity(0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.shell, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var sidebarBrandSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.98, green: 0.66, blue: 0.38), Color(red: 0.86, green: 0.34, blue: 0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: ClawNestLayout.Typography.avatarIcon, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: ClawNestLayout.Size.sidebarLogo, height: ClawNestLayout.Size.sidebarLogo)

                VStack(alignment: .leading, spacing: 3) {
                    Text("ClawNest")
                        .font(.system(size: ClawNestLayout.Typography.brand, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(t("A companion workspace for every Claw", "每个 Claw 的陪伴式工作台"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(t("Now watching", "当前关注"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
                HStack {
                    Text(currentClaw.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    statusDot(for: currentClaw.statusColor)
                }
                Text(currentClaw.machineLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous))
        }
    }

    private var sidebarNavigationSection: some View {
        VStack(spacing: 10) {
            ForEach(WorkspaceSection.allCases) { section in
                sidebarButton(for: section)
            }
        }
    }

    private func sidebarButton(for section: WorkspaceSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: ClawNestLayout.Typography.navIcon, weight: .semibold))
                    .frame(width: ClawNestLayout.Size.sidebarIconWidth)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title(in: currentLanguage))
                        .font(.headline)
                    Text(section.subtitle(in: currentLanguage))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()
            }
            .foregroundStyle(selectedSection == section ? Color.black : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(sectionBackground(isSelected: selectedSection == section))
        }
        .buttonStyle(.plain)
    }

    private var sidebarPulseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Nest pulse", "巢状态"))
                .font(.headline)
                .foregroundStyle(.white)

            sidebarMetric(label: t("Live Claws", "在线 Claw"), value: "\(claws.filter(\.isOnline).count)")
            sidebarMetric(label: t("Known Claws", "已知 Claw"), value: "\(claws.count)")
            sidebarMetric(label: t("Moments", "动态"), value: "\(momentPosts.count)")
            sidebarMetric(label: t("Latest heartbeat", "最近心跳"), value: model.snapshot.lastCheck.formatted(date: .omitted, time: .shortened))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var sidebarFooterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Current Claw", "当前 Claw"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Text(model.snapshot.headline)
                .font(.headline)
                .foregroundStyle(.white)
            Text(model.snapshot.detail)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [currentClaw.primaryColor.opacity(0.34), currentClaw.secondaryColor.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private func sectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous)
            .fill(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(red: 0.99, green: 0.72, blue: 0.42), Color(red: 0.93, green: 0.48, blue: 0.33)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(Color.white.opacity(0.04))
            )
    }

    private func sidebarMetric(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.68))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func detailSurface(layout: WorkspaceLayoutMetrics) -> some View {
        Group {
            switch selectedSection {
            case .chat:
                chatPage(layout: layout)
            case .claws:
                clawsPage(layout: layout)
            case .moments:
                momentsPage(layout: layout)
            case .mine:
                minePage(layout: layout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(layout.surfacePadding)
    }

    private func chatPage(layout: WorkspaceLayoutMetrics) -> some View {
        Group {
            if layout.pageUsesVerticalRail {
                VStack(alignment: .leading, spacing: layout.groupSpacing) {
                    chatListRail
                    chatMainColumn(layout: layout)
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    chatListRail
                        .frame(width: layout.chatRailWidth)
                        .frame(maxHeight: .infinity)

                    chatMainColumn(layout: layout)
                }
            }
        }
    }

    private func chatMainColumn(layout: WorkspaceLayoutMetrics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.groupSpacing) {
                workspaceHeader(
                    eyebrow: t("Chat", "聊天"),
                    title: t("Conversations stay attached to specific Claws and agents.", "每段对话都明确属于某个 Claw 和某个 agent。"),
                    subtitle: t("The main chat surface lives here, while recovery controls stay close by when a conversation needs help.", "主聊天界面在这里，遇到问题时恢复控制也会放在附近。")
                )

                conversationIdentityHeader(thread: selectedConversation, layout: layout)

                switch selectedConversation.kind {
                case .liveDashboard:
                    liveChatSurface(layout: layout)
                case .caretaker:
                    caretakerConversationSurface(layout: layout)
                case .installer:
                    installerConversationSurface(layout: layout)
                case .placeholder:
                    placeholderConversationSurface(for: selectedConversation, layout: layout)
                }
            }
            .padding(layout.pageInset)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatListRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(
                title: t("Recent Chats", "最近聊天"),
                subtitle: t("Different Claws, different agents, one nest.", "不同的 Claw，不同的 agent，同一个巢。")
            )

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversations) { thread in
                        Button {
                            selectedConversationID = thread.id
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    avatarBadge(
                                        text: thread.clawAvatar,
                                        primaryColor: thread.primaryColor,
                                        secondaryColor: thread.secondaryColor,
                                        size: 46
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(thread.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(thread.preview)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.66))
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 12)
                                }

                                HStack {
                                    labelPill(thread.clawName, systemImage: "pawprint.fill", tint: thread.primaryColor)
                                    labelPill(thread.agentName, systemImage: "sparkles", tint: thread.secondaryColor)
                                    Spacer()
                                    Text(thread.timestampText)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.white.opacity(0.48))
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(selectedConversation.id == thread.id ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(selectedConversation.id == thread.id ? thread.primaryColor.opacity(0.52) : Color.white.opacity(0.05), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            card {
                VStack(alignment: .leading, spacing: 10) {
                    Text(t("Conversation routing", "会话路由"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(t("Only the main dashboard-backed thread is live today. Remote multi-Claw chat sync is sketched into the UI and left as a placeholder.", "目前只有主 dashboard 会话是真实可用的，远程多 Claw 聊天同步还只是占位。"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func conversationIdentityHeader(thread: ChatThreadSummary, layout: WorkspaceLayoutMetrics) -> some View {
        Group {
            if layout.headerStacksVertically {
                VStack(alignment: .leading, spacing: layout.cardSpacing) {
                    avatarBadge(
                        text: thread.clawAvatar,
                        primaryColor: thread.primaryColor,
                        secondaryColor: thread.secondaryColor,
                        size: 68
                    )
                    conversationIdentityContent(thread: thread, layout: layout)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    avatarBadge(
                        text: thread.clawAvatar,
                        primaryColor: thread.primaryColor,
                        secondaryColor: thread.secondaryColor,
                        size: 68
                    )
                    conversationIdentityContent(thread: thread, layout: layout)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .background(cardBackground())
    }

    private func conversationIdentityContent(thread: ChatThreadSummary, layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(thread.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(thread.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 10, rowSpacing: 10) {
                labelPill(thread.clawName, systemImage: "pawprint.fill", tint: thread.primaryColor)
                labelPill(thread.agentName, systemImage: "brain.head.profile", tint: thread.secondaryColor)
                labelPill(thread.machineLabel, systemImage: "macbook", tint: .white.opacity(0.18))
            }
            .frame(maxWidth: layout.metadataWrapWidth, alignment: .leading)
        }
    }

    private func liveChatSurface(layout: WorkspaceLayoutMetrics) -> some View {
        Group {
            if layout.stacksMediumColumns {
                VStack(spacing: layout.groupSpacing) {
                    dashboardConversationPanel(layout: layout)
                    chatCompanionRail
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    dashboardConversationPanel(layout: layout)
                    chatCompanionRail
                        .frame(width: layout.compactSidebarWidth)
                }
            }
        }
    }

    private func dashboardConversationPanel(layout: WorkspaceLayoutMetrics) -> some View {
        DashboardPanelView(
            model: model,
            title: t("Current Conversation", "当前会话"),
            subtitle: t("The official dashboard stays embedded here so the active chat still feels native to the workspace.", "官方 dashboard 继续内嵌在这里，让主会话保持原生工作区的感觉。"),
            language: currentLanguage,
            dashboardMinHeight: layout.dashboardMinHeight,
            layout: layout
        )
    }

    private var chatCompanionRail: some View {
        VStack(spacing: 18) {
            compactStatusCard
            agentFocusCard
            card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(t("Need the full Claw deck?", "需要完整的 Claw 视图？"))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }

                    Text(t("Go to Claws for runtime settings, installer flow, logs, and the complete recovery surface.", "去 Claws 页面查看运行时设置、安装流程、日志和完整恢复能力。"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))

                    Button(t("Open Claws", "打开 Claws")) {
                        selectedSection = .claws
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentClaw.primaryColor)
                }
            }
        }
    }

    private func caretakerConversationSurface(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(spacing: 20) {
            StatusHeroView(snapshot: model.snapshot, isBusy: model.isBusy, language: currentLanguage, layout: layout)

            Group {
                if layout.stacksWideColumns {
                    VStack(spacing: layout.groupSpacing) {
                        ControlPanelView(model: model, language: currentLanguage)
                        caretakerConversationSecondaryContent
                    }
                } else {
                    HStack(alignment: .top, spacing: layout.groupSpacing) {
                        ControlPanelView(model: model, language: currentLanguage)
                            .frame(width: layout.supportRailWidth)
                        caretakerConversationSecondaryContent
                    }
                }
            }
        }
    }

    private var caretakerConversationSecondaryContent: some View {
        VStack(spacing: 20) {
            ActivityFeedView(entries: Array(model.diagnostics.prefix(6)), language: currentLanguage)
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("Deeper diagnostics live in Claws", "更完整的诊断在 Claws 页面"))
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(t("The caretaker thread is a soft landing. The detailed logs and runtime settings stay on the current Claw page.", "Caretaker 线程只是轻量入口，详细日志和运行时设置仍在当前 Claw 页面。"))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()

                    Button(t("Open Claws", "打开 Claws")) {
                        selectedSection = .claws
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func installerConversationSurface(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(spacing: 20) {
            OpenClawInstallView(model: model, language: currentLanguage, layout: layout)

            card {
                Group {
                    if layout.formStacksVertically {
                        VStack(alignment: .leading, spacing: 16) {
                            installerHandoffBody
                            installerHandoffButton
                        }
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            installerHandoffBody
                            Spacer()
                            installerHandoffButton
                        }
                    }
                }
            }
        }
    }

    private var installerHandoffBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Installer handoff", "安装引导"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(t("The install flow is fully usable already. Multi-step onboarding and prettier setup coaching will land later, so this thread simply points you at the working surface.", "安装流程已经可用，多步骤引导和更完整的新手提示后面再补，现在这个线程只负责带你到可用界面。"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var installerHandoffButton: some View {
        Button(t("Open Claws", "打开 Claws")) {
            selectedSection = .claws
        }
        .buttonStyle(.borderedProminent)
        .tint(currentClaw.primaryColor)
    }

    private func placeholderConversationSurface(for thread: ChatThreadSummary, layout: WorkspaceLayoutMetrics) -> some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("This conversation page is reserved.", "这个会话页已预留。"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(t("`\(thread.clawName)` with agent `\(thread.agentName)` is represented in the new layout, but real remote chat sync is not wired yet. The page stays empty on purpose instead of inventing fake controls.", "`\(thread.clawName)` 和 `\(thread.agentName)` 已经出现在新布局里，但真实的远程聊天同步还没接上，所以这里会故意保持为空。"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 12, rowSpacing: 12) {
                    Button(t("Open Moments", "打开 Moments")) {
                        selectedSection = .moments
                    }
                    .buttonStyle(.bordered)

                    Button(t("Open Claws", "打开 Claws")) {
                        selectedSection = .claws
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(thread.primaryColor)
                }
            }
        }
    }

    private func clawsPage(layout: WorkspaceLayoutMetrics) -> some View {
        Group {
            if layout.pageUsesVerticalRail {
                VStack(alignment: .leading, spacing: layout.groupSpacing) {
                    clawsRail(layout: layout)
                    clawsDetailColumn(layout: layout)
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    clawsRail(layout: layout)
                        .frame(width: layout.clawsRailWidth)
                        .frame(maxHeight: .infinity)
                    clawsDetailColumn(layout: layout)
                }
            }
        }
    }

    private func clawsDetailColumn(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            workspaceHeader(
                eyebrow: t("Claws", "Claws"),
                title: t("Every Claw gets a face, a status, and a home page that feels alive.", "每个 Claw 都有自己的形象、状态，以及一个更鲜活的主页。"),
                subtitle: t("The left side is for fast scanning. The right side is the selected Claw home, broken into overview, agents, moments, tasks, logs, and settings.", "左侧负责快速扫视，右侧是当前 Claw 的主页，分成概览、Agents、动态、任务、日志和设置。")
            )

            selectedClawHomeHeader(layout: layout)

            clawDetailSectionPicker(layout: layout)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    selectedClawDetailContent(layout: layout)
                }
                .padding(layout.pageInset)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clawsRail(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(
                title: t("Claw List", "Claw 列表"),
                subtitle: t("Warm cards, strong hierarchy, instant distinction.", "卡片温暖、层次清晰、彼此一眼可分。")
            )

            HStack(spacing: 10) {
                smallStatCard(
                    title: t("Online", "在线"),
                    value: "\(claws.filter(\.isOnline).count)",
                    tint: Color(red: 0.31, green: 0.86, blue: 0.54)
                )
                smallStatCard(
                    title: t("Total", "总数"),
                    value: "\(claws.count)",
                    tint: Color(red: 0.98, green: 0.66, blue: 0.38)
                )
                smallStatCard(
                    title: t("Alerts", "提醒"),
                    value: "\(claws.compactMap(\.alertBadge).count)",
                    tint: Color(red: 0.94, green: 0.48, blue: 0.38)
                )
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(claws) { claw in
                        clawCard(claw, layout: layout)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)

            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("Bring in another Claw", "添加另一个 Claw"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(t("The installer is still the real one. This shortcut simply drops you into the Settings section where expansion lives.", "安装器仍然是可用的真实功能，这个入口只是带你跳到 Settings 里的扩展区域。"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)

                    Button(t("New Claw", "新建 Claw")) {
                        showClawDetails(currentClaw, section: .settings)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentClaw.primaryColor)
                }
            }
        }
    }

    private func clawCard(_ claw: ClawSummary, layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                avatarBadge(
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
                            labelPill(t("Current", "当前"), systemImage: "heart.fill", tint: claw.primaryColor)
                        }
                    }

                    HStack(spacing: 8) {
                        statusDot(for: claw.statusColor)
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
                    warningBadge(badge)
                }
            }

            FlowLayout(spacing: 12, rowSpacing: 12) {
                clawMetaPill(title: t("Last active", "最近活跃"), value: claw.lastActiveAt.formatted(date: .omitted, time: .shortened))
                clawMetaPill(title: t("Agents", "Agents"), value: "\(claw.agents.count)")
                clawMetaPill(title: t("Health", "健康"), value: claw.healthLabel)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.quickActionMinimumWidth), spacing: 8)], spacing: 8) {
                cardQuickActionButton(
                    title: t("Chat", "聊天"),
                    systemImage: "message.fill",
                    tint: claw.primaryColor
                ) {
                    openChat(for: claw)
                }

                cardQuickActionButton(
                    title: t("Start", "启动"),
                    systemImage: "play.fill",
                    tint: Color(red: 0.28, green: 0.76, blue: 0.48),
                    disabled: !claw.canStart || model.isBusy
                ) {
                    startClaw(claw)
                }

                cardQuickActionButton(
                    title: t("Stop", "停止"),
                    systemImage: "stop.fill",
                    tint: Color(red: 0.92, green: 0.39, blue: 0.38),
                    disabled: true
                ) { }
                .help(t("Per-instance stop control is not implemented yet.", "按实例停止控制暂时还没有实现。"))

                cardQuickActionButton(
                    title: t("Details", "详情"),
                    systemImage: "rectangle.inset.filled.and.person.filled",
                    tint: claw.secondaryColor
                ) {
                    showClawDetails(claw, section: .overview)
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
            showClawDetails(claw, section: .overview)
        }
    }

    private func selectedClawHomeHeader(layout: WorkspaceLayoutMetrics) -> some View {
        card {
            if layout.headerStacksVertically {
                VStack(alignment: .leading, spacing: layout.groupSpacing) {
                    selectedClawHomeIdentity(layout: layout)
                    selectedClawHomeActions(layout: layout)
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    selectedClawHomeIdentity(layout: layout)
                    Spacer(minLength: 12)
                    selectedClawHomeActions(layout: layout)
                        .frame(width: 200)
                }
            }
        }
    }

    private func selectedClawHomeIdentity(layout: WorkspaceLayoutMetrics) -> some View {
        HStack(alignment: .top, spacing: 18) {
            avatarBadge(
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
                        labelPill(t("Current", "当前"), systemImage: "bolt.fill", tint: selectedClaw.primaryColor)
                    }
                    if let badge = selectedClaw.alertBadge {
                        warningBadge(badge)
                    }
                }

                Text(selectedClaw.statusDescription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 10, rowSpacing: 10) {
                    labelPill(selectedClaw.machineLabel, systemImage: "macbook", tint: .white.opacity(0.18))
                    labelPill("\(selectedClaw.agents.count) \(t("agents", "agents"))", systemImage: "person.2.fill", tint: selectedClaw.secondaryColor)
                    labelPill(selectedClaw.lastActiveAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock", tint: .white.opacity(0.18))
                    labelPill(selectedClaw.launchAgentLabel, systemImage: "antenna.radiowaves.left.and.right", tint: selectedClaw.secondaryColor)
                }
                .frame(maxWidth: layout.metadataWrapWidth, alignment: .leading)
            }
        }
    }

    private func selectedClawHomeActions(layout: WorkspaceLayoutMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.quickActionMinimumWidth), spacing: 10)], spacing: 10) {
            cardQuickActionButton(
                title: t("Chat", "聊天"),
                systemImage: "message.fill",
                tint: selectedClaw.primaryColor
            ) {
                openChat(for: selectedClaw)
            }

            cardQuickActionButton(
                title: t("Details", "详情"),
                systemImage: "rectangle.inset.filled.and.person.filled",
                tint: selectedClaw.secondaryColor
            ) {
                showClawDetails(selectedClaw, section: .overview)
            }
        }
    }

    private func clawDetailSectionPicker(layout: WorkspaceLayoutMetrics) -> some View {
        card {
            FlowLayout(spacing: 10, rowSpacing: 10) {
                ForEach(ClawDetailSection.allCases) { section in
                    Button {
                        selectedClawDetailSection = section
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.systemImage)
                            Text(section.title(in: currentLanguage))
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
    private func selectedClawDetailContent(layout: WorkspaceLayoutMetrics) -> some View {
        switch selectedClawDetailSection {
        case .overview:
            clawOverviewContent(layout: layout)
        case .agents:
            clawAgentsContent(layout: layout)
        case .recentMoments:
            clawRecentMomentsContent
        case .tasks:
            clawTasksContent
        case .logs:
            clawLogsContent(layout: layout)
        case .settings:
            clawSettingsContent(layout: layout)
        }
    }

    private func clawOverviewContent(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if selectedClaw.isCurrent {
                StatusHeroView(snapshot: model.snapshot, isBusy: model.isBusy, language: currentLanguage, layout: layout)
            } else {
                remoteClawOverviewCard(layout: layout)
            }

            detailFactsGrid(
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
                            ControlPanelView(model: model, language: currentLanguage)
                            overviewMetricsGroup(layout: layout)
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            ControlPanelView(model: model, language: currentLanguage)
                                .frame(width: layout.supportRailWidth)
                            overviewMetricsGroup(layout: layout)
                        }
                    }
                }
            } else {
                placeholderCard(
                    title: t("Remote overview is reserved.", "远程概览已预留。"),
                    body: t("This Claw has identity, agents, and reserved ports, but live host telemetry for non-current Claws is still not wired.", "这个 Claw 已经有身份信息、agents 和预留端口，但非当前 Claw 的实时主机遥测还没有接上。")
                )
            }
        }
    }

    private func overviewMetricsGroup(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(spacing: 20) {
            overviewSummaryCard(layout: layout)
            MetricsPanelView(snapshot: model.snapshot, language: currentLanguage, layout: layout)
        }
    }

    private func clawAgentsContent(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(
                title: t("Agents", "Agents"),
                subtitle: t("Every agent under this Claw gets a role, a state, and a direct path into chat.", "这个 Claw 下的每个 agent 都有角色、状态和直达聊天的入口。")
            )

            ForEach(selectedClaw.agents) { agent in
                clawAgentHomeCard(agent, layout: layout)
            }
        }
    }

    private var clawRecentMomentsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(
                title: t("Recent Moments", "最近动态"),
                subtitle: t("Social-style updates for tasks, failures, memory changes, and health shifts.", "用社交动态的形式展示任务完成、失败、记忆变化和健康状态变化。")
            )

            if selectedClawMomentPosts.isEmpty {
                placeholderCard(
                    title: t("No moments for this Claw yet.", "这个 Claw 还没有动态。"),
                    body: t("Once this Claw reports activity, it will show up here as a timeline instead of raw status noise.", "当这个 Claw 开始产生事件时，它会在这里以时间流卡片的形式出现，而不是原始状态噪音。")
                )
            } else {
                ForEach(selectedClawMomentPosts) { post in
                    momentCard(post)
                }
            }
        }
    }

    private var clawTasksContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(
                title: t("Tasks", "任务"),
                subtitle: t("Running and recent work for this Claw belongs here.", "这个 Claw 的运行中任务和最近任务都应该出现在这里。")
            )

            ForEach(selectedClawTasks) { task in
                clawTaskCard(task)
            }
        }
    }

    private func clawLogsContent(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(
                title: t("Logs", "日志"),
                subtitle: t("Runtime logs stay available without pushing users back into Terminal.", "运行日志依然可以直接查看，不需要把用户赶回终端。")
            )

            if selectedClaw.isCurrent {
                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            LatestLogView(summary: model.snapshot.logSummary, rawProbe: model.snapshot.rawProbe, language: currentLanguage, logMinHeight: layout.logMinHeight)
                            ActivityFeedView(entries: Array(model.diagnostics.prefix(8)), language: currentLanguage)
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            LatestLogView(summary: model.snapshot.logSummary, rawProbe: model.snapshot.rawProbe, language: currentLanguage, logMinHeight: layout.logMinHeight)
                            ActivityFeedView(entries: Array(model.diagnostics.prefix(8)), language: currentLanguage)
                        }
                    }
                }
            } else {
                placeholderCard(
                    title: t("Per-Claw remote logs are not wired yet.", "按 Claw 归档的远程日志还没接上。"),
                    body: t("When non-current Claws can stream their own runtime logs, this page will stop being empty.", "当非当前 Claw 也能回传各自的运行日志时，这个页面就不会再是空的。")
                )
            }
        }
    }

    private func clawSettingsContent(layout: WorkspaceLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            panelHeader(
                title: t("Settings", "设置"),
                subtitle: t("Configuration, providers, tools, permissions, and expansion live here.", "配置、模型提供方、工具、权限和扩展能力都放在这里。")
            )

            if selectedClaw.isCurrent {
                ConfigurationEditorView(
                    configuration: model.configuration,
                    isBusy: model.isBusy,
                    language: currentLanguage,
                    layout: layout,
                    onSave: model.saveConfiguration(_:),
                    onReset: {
                        model.saveConfiguration(.standard)
                    }
                )

                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            placeholderCard(
                                title: t("Model providers", "模型提供方"),
                                body: t("Provider-level tuning is reserved here. The runtime configuration editor above is live today; provider-specific settings are still a placeholder.", "这里预留给模型提供方相关配置。上面的运行时编辑器已经可用，但 provider 级别设置还只是占位。")
                            )
                            placeholderCard(
                                title: t("Tools and permissions", "工具与权限"),
                                body: t("Tool allowlists, device permissions, and safer per-Claw policies belong in this section later.", "工具白名单、设备权限和更细的按 Claw 策略之后会落在这里。")
                            )
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            placeholderCard(
                                title: t("Model providers", "模型提供方"),
                                body: t("Provider-level tuning is reserved here. The runtime configuration editor above is live today; provider-specific settings are still a placeholder.", "这里预留给模型提供方相关配置。上面的运行时编辑器已经可用，但 provider 级别设置还只是占位。")
                            )
                            placeholderCard(
                                title: t("Tools and permissions", "工具与权限"),
                                body: t("Tool allowlists, device permissions, and safer per-Claw policies belong in this section later.", "工具白名单、设备权限和更细的按 Claw 策略之后会落在这里。")
                            )
                        }
                    }
                }

                OpenClawInstallView(model: model, language: currentLanguage, layout: layout)
            } else {
                placeholderCard(
                    title: t("Remote Claw settings are reserved.", "远程 Claw 设置已预留。"),
                    body: t("ClawNest only edits the active runtime today. This page is ready for per-Claw settings once remote lifecycle management exists.", "ClawNest 目前只编辑活动 runtime。等远程生命周期管理接上后，这里就能放每个 Claw 自己的设置。")
                )

                card {
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
            showClawDetails(currentClaw, section: .settings)
        }
        .buttonStyle(.borderedProminent)
        .tint(currentClaw.primaryColor)
    }

    private func remoteClawOverviewCard(layout: WorkspaceLayoutMetrics) -> some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("This Claw has a place, but not a full live link yet.", "这个 Claw 已经有位置，但还没有完整的实时连接。"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(t("You can already distinguish it, enter its detail home, and see its agents and reserved ports. Full remote lifecycle and telemetry support are still a placeholder.", "你已经可以区分它、进入它的主页，并查看它的 agents 和保留端口。完整的远程生命周期与遥测支持仍然是占位功能。"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                detailFactsGrid(
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

    private func overviewSummaryCard(layout: WorkspaceLayoutMetrics) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Overview", "概览"))
                    .font(.headline)
                    .foregroundStyle(.white)

                detailFactsGrid(
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

    private func clawAgentHomeCard(_ agent: ClawAgentSummary, layout: WorkspaceLayoutMetrics) -> some View {
        card {
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

                    labelPill(agent.status, systemImage: "sparkles", tint: selectedClaw.primaryColor)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.quickActionMinimumWidth), spacing: 8)], spacing: 8) {
                    cardQuickActionButton(
                        title: t("Chat", "聊天"),
                        systemImage: "message.fill",
                        tint: selectedClaw.primaryColor
                    ) {
                        openChat(for: selectedClaw)
                    }

                    ForEach(agent.actions) { action in
                        cardQuickActionButton(
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
        card {
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

    private func placeholderCard(title: String, body: String) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func smallStatCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func cardQuickActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(disabled ? Color.white.opacity(0.42) : Color.white)
                .frame(maxWidth: .infinity, minHeight: ClawNestLayout.Size.actionButtonMinHeight)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(disabled ? Color.white.opacity(0.04) : tint.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(disabled ? Color.white.opacity(0.04) : tint.opacity(0.28), lineWidth: 1)
        )
        .disabled(disabled)
    }

    private func warningBadge(_ badge: ClawAlertBadge) -> some View {
        Label(badge.label, systemImage: badge.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(badge.tint.opacity(0.22), in: Capsule())
    }

    private func detailFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailFactsGrid(layout: WorkspaceLayoutMetrics, facts: [(title: String, value: String)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.detailFactMinimumWidth), spacing: 16)], spacing: 16) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                detailFact(title: fact.title, value: fact.value)
            }
        }
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

    private func momentsPage(layout: WorkspaceLayoutMetrics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceHeader(
                    eyebrow: t("Moments", "动态"),
                    title: t("A social feed for what each Claw has been up to.", "用社交动态流来展示每个 Claw 最近做了什么。"),
                    subtitle: t("Completed tasks, failed repairs, installs, and health shifts all land as readable timeline cards instead of terminal noise.", "完成任务、修复失败、安装事件和状态变化都会变成易读的时间流卡片，而不是终端噪音。")
                )

                card {
                    FlowLayout(spacing: 10, rowSpacing: 10) {
                        ForEach(momentFilters) { filter in
                            Button {
                                selectedMomentFilterID = filter.id
                            } label: {
                                Text(filter.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(activeMomentFilterID == filter.id ? Color.black : Color.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(activeMomentFilterID == filter.id ? AnyShapeStyle(filter.color) : AnyShapeStyle(Color.white.opacity(0.05)))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: layout.metadataWrapWidth, alignment: .leading)
                }

                if filteredMomentPosts.isEmpty {
                    card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(t("No moments in this lane yet.", "这个分组里还没有动态。"))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(t("The filter is ready, but that Claw does not have any surfaced activity for now.", "筛选器已经就位，但这个 Claw 目前还没有可展示的动态。"))
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredMomentPosts) { post in
                            momentCard(post)
                        }
                    }
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
    }

    private func momentCard(_ post: MomentFeedItem) -> some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    avatarBadge(
                        text: post.clawAvatar,
                        primaryColor: post.primaryColor,
                        secondaryColor: post.secondaryColor,
                        size: 58
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 10) {
                            Text(post.clawName)
                                .font(.headline)
                                .foregroundStyle(.white)
                            labelPill(post.kindLabel, systemImage: post.iconName, tint: post.primaryColor)
                        }

                        Text(post.headline)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer()
                }

                Text(post.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)

                if let command = post.command {
                    Text(command)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func minePage(layout: WorkspaceLayoutMetrics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceHeader(
                    eyebrow: t("Mine", "我的"),
                    title: t("Personal space, app preferences, and connected devices.", "个人空间、应用设置和已连接设备。"),
                    subtitle: t("This page stays softer and less technical. Runtime-specific controls live with the Claws that own them.", "这里会更柔和、更少技术味，运行时控制则放回各自所属的 Claw。")
                )

                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            mineProfileCard(layout: layout)
                            connectedDevicesCard
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            mineProfileCard(layout: layout)
                            connectedDevicesCard
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.settingsColumnMinimumWidth), spacing: layout.groupSpacing)], spacing: layout.groupSpacing) {
                    mineSettingsCard
                    mineGlobalPreferencesCard
                    minePersonalizationCard
                }

                card {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("Need actual controls?", "需要真正的控制入口？"))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(t("Open the current Claw for runtime settings and installer work, or Moments for the activity feed.", "去当前 Claw 页面查看运行时设置和安装功能，或者去 Moments 页面看动态流。"))
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        Spacer()

                        FlowLayout(spacing: 10, rowSpacing: 10) {
                            Button(t("Open Claws", "打开 Claws")) {
                                selectedSection = .claws
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(currentClaw.primaryColor)

                            Button(t("Open Moments", "打开 Moments")) {
                                selectedSection = .moments
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
    }

    private func mineProfileCard(layout: WorkspaceLayoutMetrics) -> some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    avatarBadge(
                        text: "ME",
                        primaryColor: Color(red: 0.99, green: 0.68, blue: 0.40),
                        secondaryColor: Color(red: 0.93, green: 0.40, blue: 0.35),
                        size: 68
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("You", "你"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(t("Claw keeper", "Claw 管理者"))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }

                Text(t("ClawNest already knows your active Mac, your current Claw, and the live feed of moments. Account sync, profile themes, and cross-device identity are still placeholders.", "ClawNest 已经知道你当前的 Mac、当前 Claw 和动态流。账号同步、主题和跨设备身份仍然是占位功能。"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                detailFactsGrid(
                    layout: layout,
                    facts: [
                        (t("Claws", "Claws"), "\(claws.count)"),
                        (t("Moments", "动态"), "\(momentPosts.count)")
                    ]
                )
            }
        }
    }

    private var connectedDevicesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("Connected devices", "已连接设备"))
                    .font(.headline)
                    .foregroundStyle(.white)

                connectedDeviceRow(
                    name: Host.current().localizedName ?? "This Mac",
                    detail: t("Current device", "当前设备"),
                    isOnline: true
                )
                connectedDeviceRow(
                    name: t("iPhone companion", "iPhone 伴侣端"),
                    detail: t("Placeholder", "占位"),
                    isOnline: false
                )
                connectedDeviceRow(
                    name: t("iPad glance mode", "iPad 概览端"),
                    detail: t("Placeholder", "占位"),
                    isOnline: false
                )
            }
        }
    }

    private var mineSettingsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Settings", "设置"))
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Language", "语言"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Picker("", selection: Binding(
                        get: { model.language },
                        set: { model.updateLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(t("English is the default. Simplified Chinese is available for the app shell and key controls.", "默认语言为 English。现在支持将应用外壳和关键控件切换为简体中文。"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var mineGlobalPreferencesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Global preferences", "全局偏好"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(t("Notification routing, feed density, personality presets, and account-level privacy rules are reserved here. The UI is laid out, but these controls are intentionally left empty for now.", "通知方式、动态密度、人格预设和账号级隐私规则都会放在这里。界面先留好，功能暂时不接。"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var minePersonalizationCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Personalization", "个性化"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(t("Avatar themes, nicknames for Claws, and warm profile customization belong on this page. Nothing is wired yet, so this remains a placeholder card.", "头像主题、Claw 昵称和更柔和的个人定制都会放在这里。目前还没接功能，所以先保留成占位卡片。"))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func connectedDeviceRow(name: String, detail: String, isOnline: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOnline ? Color(red: 0.29, green: 0.88, blue: 0.53) : Color.white.opacity(0.16))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Text(isOnline ? t("Connected", "已连接") : t("Soon", "即将支持"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var compactStatusCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(t("Claw presence", "Claw 状态"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    statusDot(for: currentClaw.statusColor)
                }

                Text(model.snapshot.headline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(model.snapshot.detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 10, rowSpacing: 10) {
                    labelPill(model.snapshot.level.label(in: currentLanguage), systemImage: model.snapshot.level.iconName, tint: currentClaw.primaryColor)
                    labelPill(model.snapshot.lastCheck.formatted(date: .omitted, time: .shortened), systemImage: "clock", tint: .white.opacity(0.18))
                }
            }
        }
    }

    private var agentFocusCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Agent focus", "Agent 焦点"))
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(Array(currentClaw.agents.prefix(3))) { agent in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(currentClaw.primaryColor.opacity(0.22))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(currentClaw.primaryColor)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(agent.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(agent.role)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                            Text(agent.status)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func workspaceHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.48))
                .tracking(2)
            Text(title)
                .font(.system(size: ClawNestLayout.Typography.workspaceTitle, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.white.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ClawNestLayout.Spacing.xSmall / 2)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(ClawNestLayout.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground())
    }

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
            .fill(.black.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func labelPill(_ label: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(label)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, ClawNestLayout.Spacing.xSmall - 1)
        .background(tint.opacity(0.20), in: Capsule())
    }

    private func avatarBadge(text: String, primaryColor: Color, secondaryColor: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(text)
                .font(.system(size: size * 0.27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: primaryColor.opacity(0.36), radius: 16, y: 8)
    }

    private func statusDot(for color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: ClawNestLayout.Size.pulseDot, height: ClawNestLayout.Size.pulseDot)
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
}

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case chat
    case claws
    case moments
    case mine

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .chat:
            return localized("Chat", "聊天", language: language)
        case .claws:
            return localized("Claws", "Claws", language: language)
        case .moments:
            return localized("Moments", "动态", language: language)
        case .mine:
            return localized("Mine", "我的", language: language)
        }
    }

    func subtitle(in language: AppLanguage) -> String {
        switch self {
        case .chat:
            return localized("Threads and agents", "线程与 agents", language: language)
        case .claws:
            return localized("Instances and controls", "实例与控制", language: language)
        case .moments:
            return localized("Timeline and stories", "时间流与动态", language: language)
        case .mine:
            return localized("Profile and preferences", "资料与偏好", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "message.badge.waveform"
        case .claws:
            return "square.grid.2x2.fill"
        case .moments:
            return "sparkles.tv"
        case .mine:
            return "person.crop.circle.fill"
        }
    }
}

private struct ClawPalette {
    let primary: Color
    let secondary: Color

    static let defaults: [ClawPalette] = [
        ClawPalette(primary: Color(red: 0.98, green: 0.66, blue: 0.38), secondary: Color(red: 0.91, green: 0.38, blue: 0.33)),
        ClawPalette(primary: Color(red: 0.38, green: 0.78, blue: 0.84), secondary: Color(red: 0.16, green: 0.46, blue: 0.82)),
        ClawPalette(primary: Color(red: 0.77, green: 0.53, blue: 0.96), secondary: Color(red: 0.42, green: 0.30, blue: 0.82)),
        ClawPalette(primary: Color(red: 0.57, green: 0.89, blue: 0.46), secondary: Color(red: 0.18, green: 0.63, blue: 0.35))
    ]
}

private struct ClawSummary: Identifiable {
    let id: String
    let name: String
    let avatarText: String
    let machineLabel: String
    let statusLabel: String
    let statusDescription: String
    let statusColor: Color
    let healthLabel: String
    let installDirectoryPath: String
    let launchAgentLabel: String
    let dashboardURLString: String
    let reservedPorts: [Int]
    let lastActiveAt: Date
    let isCurrent: Bool
    let isOnline: Bool
    let canStart: Bool
    let alertBadge: ClawAlertBadge?
    let primaryColor: Color
    let secondaryColor: Color
    let agents: [ClawAgentSummary]

    var portSummary: String {
        reservedPorts.sorted().map(String.init).joined(separator: ", ")
    }
}

private struct ClawAlertBadge {
    let label: String
    let systemImage: String
    let tint: Color
}

private struct ClawAgentSummary: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let status: String
    let actions: [AgentActionSummary]
}

private struct AgentActionSummary: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let recoveryAction: RecoveryAction?
}

private enum ChatThreadKind {
    case liveDashboard
    case caretaker
    case installer
    case placeholder
}

private struct ChatThreadSummary: Identifiable {
    let id: String
    let title: String
    let preview: String
    let description: String
    let clawName: String
    let clawAvatar: String
    let agentName: String
    let machineLabel: String
    let timestampText: String
    let primaryColor: Color
    let secondaryColor: Color
    let kind: ChatThreadKind
}

private struct MomentFeedItem: Identifiable {
    let id = UUID()
    let clawID: String
    let clawName: String
    let clawAvatar: String
    let primaryColor: Color
    let secondaryColor: Color
    let kindLabel: String
    let iconName: String
    let headline: String
    let body: String
    let timestamp: Date
    let command: String?
}

private struct WorkspaceMomentFilter: Identifiable {
    static let allID = "all"

    let id: String
    let title: String
    let color: Color
}

private enum ClawDetailSection: String, CaseIterable, Identifiable {
    case overview
    case agents
    case recentMoments
    case tasks
    case logs
    case settings

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .overview:
            return localized("Overview", "概览", language: language)
        case .agents:
            return localized("Agents", "Agents", language: language)
        case .recentMoments:
            return localized("Recent Moments", "最近动态", language: language)
        case .tasks:
            return localized("Tasks", "任务", language: language)
        case .logs:
            return localized("Logs", "日志", language: language)
        case .settings:
            return localized("Settings", "设置", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "square.grid.2x2.fill"
        case .agents:
            return "person.2.fill"
        case .recentMoments:
            return "sparkles.tv"
        case .tasks:
            return "checklist"
        case .logs:
            return "text.page.fill"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

private struct ClawTaskSummary: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let statusLabel: String
    let systemImage: String
    let tint: Color
    let timestamp: Date
}

private struct StatusHeroView: View {
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

private struct ControlPanelView: View {
    @ObservedObject var model: AppModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(title: localized("Claw Actions", "Claw 动作", language: language), subtitle: localized("The current runtime stays recoverable even when the dashboard surface is having a bad day.", "即使 dashboard 状态不好，当前 runtime 仍然可以在这里恢复。", language: language))

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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct MetricsPanelView: View {
    let snapshot: GatewaySnapshot
    let language: AppLanguage
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(title: localized("Runtime Details", "运行时细节", language: language), subtitle: localized("A warmer presentation of the same health data the app already knows how to collect.", "把已经采集到的健康数据，用更友好的方式展示出来。", language: language))

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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct DashboardPanelView: View {
    @ObservedObject var model: AppModel
    let title: String
    let subtitle: String
    let language: AppLanguage
    let dashboardMinHeight: CGFloat
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(title: title, subtitle: subtitle)

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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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

private struct ActivityFeedView: View {
    let entries: [DiagnosticEntry]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(title: localized("Caretaker Notes", "守护者笔记", language: language), subtitle: localized("The same diagnostics stream, softened into readable updates.", "同一条诊断流，用更可读的方式呈现。", language: language))

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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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

private struct LatestLogView: View {
    let summary: LogSummary?
    let rawProbe: String
    let language: AppLanguage
    let logMinHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            panelHeader(title: localized("Latest Log + Raw Probe", "最新日志与原始探测", language: language), subtitle: localized("The honest, unsoftened technical layer is still one glance away.", "最原始、最技术化的信息依然随时可看。", language: language))

            VStack(alignment: .leading, spacing: 10) {
                Text(summary?.path ?? localized("No OpenClaw log file was found under /tmp/openclaw yet.", "在 /tmp/openclaw 下还没有找到 OpenClaw 日志。", language: language))
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.52))
                Divider()
                    .overlay(Color.white.opacity(0.08))
                ScrollView {
                    Text(summary?.excerpt ?? rawProbe.ifEmpty(localized("No log excerpt or raw probe payload is available yet.", "还没有日志摘录或原始探测内容。", language: language)))
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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

private struct OpenClawInstallView: View {
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
            panelHeader(
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
                        .foregroundStyle(.white.opacity(0.70))
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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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
}

private struct ConfigurationEditorView: View {
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
            panelHeader(title: localized("Current Runtime Settings", "当前运行时设置", language: language), subtitle: localized("The technical knobs stay editable, but they now live behind the active Claw instead of taking over the whole app.", "技术参数依然可编辑，只是现在放到了活动 Claw 后面，而不是占满整个应用。", language: language))

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
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
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

private func panelHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.system(size: ClawNestLayout.Typography.sectionTitle, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension GatewayStatusLevel {
    var tintColor: Color {
        switch self {
        case .healthy:
            return Color(red: 0.29, green: 0.88, blue: 0.53)
        case .recovering:
            return Color(red: 0.34, green: 0.73, blue: 0.94)
        case .degraded:
            return Color(red: 0.95, green: 0.72, blue: 0.38)
        case .offline, .missingCLI:
            return Color(red: 0.92, green: 0.39, blue: 0.38)
        }
    }
}

private extension DiagnosticLevel {
    var momentLabel: String {
        switch self {
        case .success:
            return "Completed"
        case .info:
            return "Update"
        case .warning:
            return "Heads Up"
        case .error:
            return "Failed"
        }
    }

    var momentIcon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "sparkles"
        case .warning:
            return "exclamationmark.bubble.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
