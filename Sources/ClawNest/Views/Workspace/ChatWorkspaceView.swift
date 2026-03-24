import SwiftUI

struct ChatWorkspaceView: View {
    @ObservedObject var model: AppModel
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    let currentClaw: ClawSummary
    let selectedConversation: ChatThreadSummary
    let conversations: [ChatThreadSummary]
    let onSelectConversation: (String) -> Void
    let onCreateClaw: () -> Void
    let onOpenClaws: () -> Void
    let onOpenMoments: () -> Void

    var body: some View {
        Group {
            if layout.pageUsesVerticalRail {
                VStack(alignment: .leading, spacing: layout.groupSpacing) {
                    chatListRail
                    chatMainColumn
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    chatListRail
                        .frame(width: layout.chatRailWidth)
                        .frame(maxHeight: .infinity)

                    chatMainColumn
                }
            }
        }
    }

    private var chatMainColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.groupSpacing) {
                WorkspaceHeaderView(
                    eyebrow: t("Chat", "聊天"),
                    title: t("Conversations stay attached to specific Claws and agents.", "每段对话都明确属于某个 Claw 和某个 agent。"),
                    subtitle: t("The main chat surface lives here, while recovery controls stay close by when a conversation needs help.", "主聊天界面在这里，遇到问题时恢复控制也会放在附近。")
                )

                conversationIdentityHeader(thread: selectedConversation)

                switch selectedConversation.kind {
                case .liveDashboard:
                    liveChatSurface
                case .caretaker:
                    caretakerConversationSurface
                case .installer:
                    installerConversationSurface
                case .placeholder:
                    placeholderConversationSurface(for: selectedConversation)
                }
            }
            .padding(layout.pageInset)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatListRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            PanelHeaderView(
                title: t("Recent Chats", "最近聊天"),
                subtitle: t("Different Claws, different agents, one nest.", "不同的 Claw，不同的 agent，同一个巢。")
            )

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversations) { thread in
                        Button {
                            onSelectConversation(thread.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    AvatarBadgeView(
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
                                    PillLabelView(label: thread.clawName, systemImage: "pawprint.fill", tint: thread.primaryColor)
                                    PillLabelView(label: thread.agentName, systemImage: "sparkles", tint: thread.secondaryColor)
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

            ShellCard {
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

    private func conversationIdentityHeader(thread: ChatThreadSummary) -> some View {
        Group {
            if layout.headerStacksVertically {
                VStack(alignment: .leading, spacing: layout.cardSpacing) {
                    AvatarBadgeView(
                        text: thread.clawAvatar,
                        primaryColor: thread.primaryColor,
                        secondaryColor: thread.secondaryColor,
                        size: 68
                    )
                    conversationIdentityContent(thread: thread)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    AvatarBadgeView(
                        text: thread.clawAvatar,
                        primaryColor: thread.primaryColor,
                        secondaryColor: thread.secondaryColor,
                        size: 68
                    )
                    conversationIdentityContent(thread: thread)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .shellPanelBackground()
    }

    private func conversationIdentityContent(thread: ChatThreadSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(thread.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(thread.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 10, rowSpacing: 10) {
                PillLabelView(label: thread.clawName, systemImage: "pawprint.fill", tint: thread.primaryColor)
                PillLabelView(label: thread.agentName, systemImage: "brain.head.profile", tint: thread.secondaryColor)
                PillLabelView(label: thread.machineLabel, systemImage: "macbook", tint: .white.opacity(0.18))
            }
            .frame(maxWidth: layout.metadataWrapWidth, alignment: .leading)
        }
    }

    private var liveChatSurface: some View {
        Group {
            if layout.stacksMediumColumns {
                VStack(spacing: layout.groupSpacing) {
                    dashboardConversationPanel
                    chatCompanionRail
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    dashboardConversationPanel
                    chatCompanionRail
                        .frame(width: layout.compactSidebarWidth)
                }
            }
        }
    }

    private var dashboardConversationPanel: some View {
        DashboardPanelView(
            model: model,
            title: t("Current Conversation", "当前会话"),
            subtitle: t("The official dashboard stays embedded here so the active chat still feels native to the workspace.", "官方 dashboard 继续内嵌在这里，让主会话保持原生工作区的感觉。"),
            language: language,
            dashboardMinHeight: layout.dashboardMinHeight,
            layout: layout
        )
    }

    private var chatCompanionRail: some View {
        VStack(spacing: 18) {
            compactStatusCard
            agentFocusCard
            ShellCard {
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
                        onOpenClaws()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentClaw.primaryColor)
                }
            }
        }
    }

    private var caretakerConversationSurface: some View {
        VStack(spacing: 20) {
            StatusHeroView(snapshot: model.snapshot, isBusy: model.isBusy, language: language, layout: layout)

            Group {
                if layout.stacksWideColumns {
                    VStack(spacing: layout.groupSpacing) {
                        ControlPanelView(model: model, language: language)
                        caretakerConversationSecondaryContent
                    }
                } else {
                    HStack(alignment: .top, spacing: layout.groupSpacing) {
                        ControlPanelView(model: model, language: language)
                            .frame(width: layout.supportRailWidth)
                        caretakerConversationSecondaryContent
                    }
                }
            }
        }
    }

    private var caretakerConversationSecondaryContent: some View {
        VStack(spacing: 20) {
            ActivityFeedView(entries: Array(model.diagnostics.prefix(6)), language: language)

            ShellCard {
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
                        onOpenClaws()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var installerConversationSurface: some View {
        VStack(spacing: 20) {
            ShellCard {
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
            Text(t("New Claw now opens in a modal", "新建 Claw 现在通过弹窗打开"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(t("The actual install flow, environment checks, and failure feedback no longer occupy the main workspace. Open the dedicated modal to continue there.", "真正的安装流程、环境检测和失败反馈不再占用主工作区。打开独立弹窗后，再在里面继续。"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var installerHandoffButton: some View {
        Button(t("Open New Claw", "打开新建 Claw")) {
            onCreateClaw()
        }
        .buttonStyle(.borderedProminent)
        .tint(currentClaw.primaryColor)
    }

    private func placeholderConversationSurface(for thread: ChatThreadSummary) -> some View {
        ShellCard {
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
                        onOpenMoments()
                    }
                    .buttonStyle(.bordered)

                    Button(t("Open Claws", "打开 Claws")) {
                        onOpenClaws()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(thread.primaryColor)
                }
            }
        }
    }

    private var compactStatusCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(t("Claw presence", "Claw 状态"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    StatusDotView(color: currentClaw.statusColor)
                }

                Text(model.snapshot.headline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(model.snapshot.detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 10, rowSpacing: 10) {
                    PillLabelView(label: model.snapshot.level.label(in: language), systemImage: model.snapshot.level.iconName, tint: currentClaw.primaryColor)
                    PillLabelView(label: model.snapshot.lastCheck.formatted(date: .omitted, time: .shortened), systemImage: "clock", tint: .white.opacity(0.18))
                }
            }
        }
    }

    private var agentFocusCard: some View {
        ShellCard {
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

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: language)
    }
}
