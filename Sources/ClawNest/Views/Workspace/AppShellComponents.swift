import SwiftUI

enum AppShellPalette {
    static let backgroundTop = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let backgroundBottom = Color(red: 0.97, green: 0.98, blue: 0.99)
    static let shellBackground = Color.white.opacity(0.94)
    static let sidebarBackground = Color.white.opacity(0.88)
    static let panelBackground = Color.white.opacity(0.94)
    static let subtleFill = Color.black.opacity(0.035)
    static let subtleStrongFill = Color.black.opacity(0.055)
    static let neutralTint = Color.black.opacity(0.08)
    static let border = Color.black.opacity(0.08)
    static let divider = Color.black.opacity(0.08)
    static let shadow = Color.black.opacity(0.06)
    static let textPrimary = Color(red: 0.15, green: 0.17, blue: 0.22)
    static let textSecondary = Color(red: 0.37, green: 0.40, blue: 0.47)
    static let textTertiary = Color(red: 0.51, green: 0.54, blue: 0.60)
    static let codeBackground = Color(red: 0.95, green: 0.96, blue: 0.98)

    static func tintedFill(_ tint: Color, opacity: Double = 0.12) -> Color {
        tint.opacity(opacity)
    }

    static func tintedStroke(_ tint: Color, opacity: Double = 0.24) -> Color {
        tint.opacity(opacity)
    }
}

struct AppShellBackgroundView: View {
    let layout: WorkspaceLayoutMetrics

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppShellPalette.backgroundTop, AppShellPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.canvas, style: .continuous)
                .fill(Color.white.opacity(0.46))
                .padding(ClawNestLayout.Spacing.small)
                .blur(radius: 16)
                .offset(y: -180)
        }
    }
}

struct WorkspaceSidebarView: View {
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    let selectedSection: WorkspaceSection
    let onSelectSection: (WorkspaceSection) -> Void

    var body: some View {
        VStack(spacing: layout.isCompactHeight ? 16 : 20) {
            sidebarBrandSection
            sidebarNavigationSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, layout.isCompactHeight ? 16 : 18)
        .frame(width: layout.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.shell, style: .continuous)
                .fill(AppShellPalette.sidebarBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.shell, style: .continuous)
                        .stroke(AppShellPalette.border, lineWidth: 1)
                )
                .shadow(color: AppShellPalette.shadow, radius: 18, y: 10)
        )
    }

    private var sidebarBrandSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppShellPalette.border, lineWidth: 1)
                )

            Image(systemName: "pawprint.fill")
                .font(.system(size: ClawNestLayout.Typography.avatarIcon, weight: .bold))
                .foregroundStyle(AppShellPalette.textPrimary)
        }
        .frame(width: ClawNestLayout.Size.sidebarLogo, height: ClawNestLayout.Size.sidebarLogo)
        .frame(maxWidth: .infinity)
    }

    private var sidebarNavigationSection: some View {
        VStack(spacing: 10) {
            ForEach([WorkspaceSection.claw]) { section in
                Button {
                    onSelectSection(section)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: ClawNestLayout.Typography.navIcon, weight: .semibold))
                            .frame(width: ClawNestLayout.Size.sidebarIconWidth, height: ClawNestLayout.Size.sidebarIconWidth)
                            .foregroundStyle(selectedSection == section ? section.sidebarTint : AppShellPalette.textSecondary)

                        Text(section.title(in: language))
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(selectedSection == section ? AppShellPalette.textPrimary : AppShellPalette.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .padding(.horizontal, 6)
                    .background(sidebarItemBackground(for: section))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sidebarItemBackground(for section: WorkspaceSection) -> some View {
        RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous)
            .fill(selectedSection == section ? AppShellPalette.tintedFill(section.sidebarTint) : AppShellPalette.subtleFill)
            .overlay(
                RoundedRectangle(cornerRadius: ClawNestLayout.Radius.medium, style: .continuous)
                    .stroke(selectedSection == section ? AppShellPalette.tintedStroke(section.sidebarTint) : AppShellPalette.border.opacity(0.8), lineWidth: 1)
            )
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
                .foregroundStyle(AppShellPalette.textTertiary)
                .tracking(2)
            Text(title)
                .font(.system(size: ClawNestLayout.Typography.workspaceTitle, weight: .bold, design: .rounded))
                .foregroundStyle(AppShellPalette.textPrimary)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(AppShellPalette.textSecondary)
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
                .foregroundStyle(AppShellPalette.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppShellPalette.textSecondary)
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
        .shadow(color: primaryColor.opacity(0.20), radius: 12, y: 6)
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
        .foregroundStyle(AppShellPalette.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, ClawNestLayout.Spacing.xSmall - 1)
        .background(AppShellPalette.tintedFill(tint, opacity: 0.14), in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppShellPalette.tintedStroke(tint, opacity: 0.18), lineWidth: 1)
        )
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
                .foregroundStyle(disabled ? AppShellPalette.textTertiary : AppShellPalette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: ClawNestLayout.Size.actionButtonMinHeight)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(disabled ? AppShellPalette.subtleFill : AppShellPalette.tintedFill(tint, opacity: 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(disabled ? AppShellPalette.border.opacity(0.65) : AppShellPalette.tintedStroke(tint, opacity: 0.22), lineWidth: 1)
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
                    .foregroundStyle(AppShellPalette.textPrimary)
                Text(bodyText)
                    .font(.footnote)
                    .foregroundStyle(AppShellPalette.textSecondary)
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
                .foregroundStyle(AppShellPalette.textTertiary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppShellPalette.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppShellPalette.tintedFill(tint, opacity: 0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct DetailFactCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppShellPalette.textTertiary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(AppShellPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                .fill(isOnline ? Color(red: 0.29, green: 0.88, blue: 0.53) : AppShellPalette.textTertiary.opacity(0.35))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppShellPalette.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppShellPalette.textSecondary)
            }

            Spacer()

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppShellPalette.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppShellPalette.subtleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ShellPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                .fill(AppShellPalette.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ClawNestLayout.Radius.xLarge, style: .continuous)
                        .stroke(AppShellPalette.border, lineWidth: 1)
                )
                .shadow(color: AppShellPalette.shadow, radius: 16, y: 8)
        )
    }
}

extension View {
    func shellPanelBackground() -> some View {
        modifier(ShellPanelBackground())
    }
}
