import SwiftUI

struct AppShellBackgroundView: View {
    let layout: WorkspaceLayoutMetrics

    var body: some View {
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
}

struct WorkspaceSidebarView: View {
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    let currentClaw: ClawSummary
    let selectedSection: WorkspaceSection
    let liveClawCount: Int
    let clawCount: Int
    let momentCount: Int
    let snapshot: GatewaySnapshot
    let onSelectSection: (WorkspaceSection) -> Void

    var body: some View {
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
                    Text(localized("A companion workspace for every Claw", "每个 Claw 的陪伴式工作台", language: language))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("Now watching", "当前关注", language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
                HStack {
                    Text(currentClaw.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    StatusDotView(color: currentClaw.statusColor)
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
                Button {
                    onSelectSection(section)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: ClawNestLayout.Typography.navIcon, weight: .semibold))
                            .frame(width: ClawNestLayout.Size.sidebarIconWidth)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title(in: language))
                                .font(.headline)
                            Text(section.subtitle(in: language))
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
        }
    }

    private var sidebarPulseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("Nest pulse", "巢状态", language: language))
                .font(.headline)
                .foregroundStyle(.white)

            sidebarMetric(label: localized("Live Claws", "在线 Claw", language: language), value: "\(liveClawCount)")
            sidebarMetric(label: localized("Known Claws", "已知 Claw", language: language), value: "\(clawCount)")
            sidebarMetric(label: localized("Moments", "动态", language: language), value: "\(momentCount)")
            sidebarMetric(label: localized("Latest heartbeat", "最近心跳", language: language), value: snapshot.lastCheck.formatted(date: .omitted, time: .shortened))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var sidebarFooterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("Current Claw", "当前 Claw", language: language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
            Text(snapshot.headline)
                .font(.headline)
                .foregroundStyle(.white)
            Text(snapshot.detail)
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
}

struct WorkspaceHeaderView: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
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
}

struct PanelHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
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
}

struct ShellCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ClawNestLayout.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .shellPanelBackground()
    }
}

struct AvatarBadgeView: View {
    let text: String
    let primaryColor: Color
    let secondaryColor: Color
    let size: CGFloat

    var body: some View {
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
}

struct PillLabelView: View {
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
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
}

struct StatusDotView: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: ClawNestLayout.Size.pulseDot, height: ClawNestLayout.Size.pulseDot)
    }
}

struct WarningBadgeView: View {
    let badge: ClawAlertBadge

    var body: some View {
        Label(badge.label, systemImage: badge.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(badge.tint.opacity(0.22), in: Capsule())
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var disabled = false
    let action: () -> Void

    var body: some View {
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
}

struct PlaceholderCardView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(bodyText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SmallStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
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
}

struct DetailFactCard: View {
    let title: String
    let value: String

    var body: some View {
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
}

struct DetailFactsGrid: View {
    let layout: WorkspaceLayoutMetrics
    let facts: [(title: String, value: String)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.detailFactMinimumWidth), spacing: 16)], spacing: 16) {
            ForEach(Array(facts.enumerated()), id: \.offset) { _, fact in
                DetailFactCard(title: fact.title, value: fact.value)
            }
        }
    }
}

struct ConnectedDeviceRow: View {
    let name: String
    let detail: String
    let statusText: String
    let isOnline: Bool

    var body: some View {
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

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MomentCardView: View {
    let post: MomentFeedItem

    var body: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    AvatarBadgeView(
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
                            PillLabelView(label: post.kindLabel, systemImage: post.iconName, tint: post.primaryColor)
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
}

private struct ShellPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

extension View {
    func shellPanelBackground() -> some View {
        modifier(ShellPanelBackground())
    }
}
