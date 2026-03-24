import SwiftUI

struct ClawWorkspaceView: View {
    @ObservedObject var model: AppModel
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    @Binding var selectedWorkbenchSection: ClawWorkbenchSection

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WorkspaceHeaderView(
                eyebrow: t("Claw", "Claw"),
                title: t("OpenClaw Local Workbench", "OpenClaw 本地工作台"),
                subtitle: t("Install or verify the OpenClaw CLI, monitor the local runtime, run recovery actions, open the dashboard, and inspect logs from one honest surface.", "在一个真实收口的界面里完成 OpenClaw CLI 安装/校验、本地 runtime 监控、恢复动作、dashboard 打开和日志查看。")
            )

            workspaceIdentityCard
            sectionPicker

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionContent
                }
                .padding(layout.pageInset)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workspaceIdentityCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Single local workbench", "单一本地工作台"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppShellPalette.textPrimary)

                Text(t("ClawNest currently attaches to the OpenClaw runtime on this Mac. It does not provision extra Claws, remote runtimes, or per-instance dashboards.", "ClawNest 当前只连接这台 Mac 上的 OpenClaw runtime。它不会在当前版本里创建额外 Claw、远程 runtime 或按实例管理 dashboard。"))
                    .font(.body)
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 10, rowSpacing: 10) {
                    PillLabelView(label: Host.current().localizedName ?? "This Mac", systemImage: "macbook", tint: AppShellPalette.neutralTint)
                    PillLabelView(label: model.snapshot.level.label(in: language), systemImage: model.snapshot.level.iconName, tint: model.snapshot.level.tintColor)
                    PillLabelView(label: model.configuration.dashboardURL.absoluteString, systemImage: "network", tint: AppShellPalette.neutralTint)
                    PillLabelView(label: model.installSnapshot.resolvedCommandPath ?? model.configuration.openClawCommand, systemImage: "terminal", tint: AppShellPalette.neutralTint)
                }
                .frame(maxWidth: layout.metadataWrapWidth, alignment: .leading)
            }
        }
    }

    private var sectionPicker: some View {
        ShellCard {
            FlowLayout(spacing: 10, rowSpacing: 10) {
                ForEach(ClawWorkbenchSection.allCases) { section in
                    Button {
                        selectedWorkbenchSection = section
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.systemImage)
                            Text(section.title(in: language))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedWorkbenchSection == section ? AppShellPalette.textPrimary : AppShellPalette.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedWorkbenchSection == section
                                        ? AnyShapeStyle(AppShellPalette.tintedFill(WorkspaceSection.claw.sidebarTint))
                                        : AnyShapeStyle(AppShellPalette.subtleFill)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedWorkbenchSection == section ? AppShellPalette.tintedStroke(WorkspaceSection.claw.sidebarTint) : AppShellPalette.border.opacity(0.75), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedWorkbenchSection {
        case .overview:
            overviewContent
        case .dashboard:
            dashboardContent
        case .logs:
            logsContent
        case .settings:
            settingsContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            StatusHeroView(snapshot: model.snapshot, isBusy: model.isPerformingMutation, language: language, layout: layout)

            DetailFactsGrid(
                layout: layout,
                facts: [
                    (t("Machine", "机器"), Host.current().localizedName ?? "This Mac"),
                    (t("Runtime command", "运行时命令"), model.configuration.openClawCommand),
                    (t("Dashboard", "Dashboard"), model.configuration.dashboardURL.absoluteString),
                    ("LaunchAgent", model.configuration.launchAgentLabel)
                ]
            )

            if layout.stacksWideColumns {
                VStack(spacing: layout.groupSpacing) {
                    ControlPanelView(model: model, language: language)
                    OpenClawInstallView(model: model, language: language, layout: layout)
                    MetricsPanelView(snapshot: model.snapshot, language: language, layout: layout)
                    ActivityFeedView(entries: Array(model.diagnostics.prefix(8)), language: language)
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    VStack(spacing: layout.groupSpacing) {
                        ControlPanelView(model: model, language: language)
                        OpenClawInstallView(model: model, language: language, layout: layout)
                    }
                    VStack(spacing: layout.groupSpacing) {
                        MetricsPanelView(snapshot: model.snapshot, language: language, layout: layout)
                        ActivityFeedView(entries: Array(model.diagnostics.prefix(8)), language: language)
                    }
                }
            }
        }
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            DashboardPanelView(
                model: model,
                title: t("Local Dashboard", "本地 Dashboard"),
                subtitle: t("This is the real OpenClaw dashboard for the current local runtime. If it is unavailable, the overlay uses the same action model as the rest of the app.", "这里展示的是当前本地 runtime 的真实 OpenClaw dashboard。如果它不可用，overlay 也会使用和应用其他位置完全一致的动作模型。"),
                language: language,
                dashboardMinHeight: layout.dashboardMinHeight,
                layout: layout
            )

            DetailFactsGrid(
                layout: layout,
                facts: [
                    (t("Current state", "当前状态"), model.snapshot.level.label(in: language)),
                    (t("Last check", "最近检查"), model.snapshot.lastCheck.formatted(date: .abbreviated, time: .shortened)),
                    (t("CLI", "CLI"), model.installSnapshot.resolvedCommandPath ?? t("Not installed", "未安装")),
                    (t("Next step", "下一步"), model.installSnapshot.nextStep)
                ]
            )
        }
    }

    private var logsContent: some View {
        Group {
            if layout.stacksWideColumns {
                VStack(spacing: layout.groupSpacing) {
                    LatestLogView(summary: model.snapshot.logSummary, rawProbe: model.snapshot.rawProbe, language: language, logMinHeight: layout.logMinHeight)
                    ActivityFeedView(entries: Array(model.diagnostics.prefix(12)), language: language)
                }
            } else {
                HStack(alignment: .top, spacing: layout.groupSpacing) {
                    LatestLogView(summary: model.snapshot.logSummary, rawProbe: model.snapshot.rawProbe, language: language, logMinHeight: layout.logMinHeight)
                    ActivityFeedView(entries: Array(model.diagnostics.prefix(12)), language: language)
                }
            }
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            PanelHeaderView(
                title: t("Local Runtime Settings", "本地运行时设置"),
                subtitle: t("These controls only describe and adjust the runtime ClawNest is currently attached to.", "这些设置只描述和调整 ClawNest 当前连接的那个本地 runtime。")
            )

            ConfigurationEditorView(
                configuration: model.configuration,
                isBusy: model.isPerformingMutation,
                language: language,
                layout: layout,
                onSave: model.saveConfiguration(_:),
                onReset: {
                    model.saveConfiguration(.standard)
                }
            )

            OpenClawInstallView(model: model, language: language, layout: layout)
        }
    }

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: language)
    }
}
