import Foundation
import SwiftUI

struct MineWorkspaceView: View {
    @ObservedObject var model: AppModel
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    let currentClaw: ClawSummary
    let clawCount: Int
    let momentCount: Int
    let onOpenClaws: () -> Void
    let onOpenMoments: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkspaceHeaderView(
                    eyebrow: t("Mine", "我的"),
                    title: t("Personal space, app preferences, and connected devices.", "个人空间、应用设置和已连接设备。"),
                    subtitle: t("This page stays softer and less technical. Runtime-specific controls live with the Claws that own them.", "这里会更柔和、更少技术味，运行时控制则放回各自所属的 Claw。")
                )

                Group {
                    if layout.stacksWideColumns {
                        VStack(spacing: layout.groupSpacing) {
                            mineProfileCard
                            connectedDevicesCard
                        }
                    } else {
                        HStack(alignment: .top, spacing: layout.groupSpacing) {
                            mineProfileCard
                            connectedDevicesCard
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: layout.settingsColumnMinimumWidth), spacing: layout.groupSpacing)], spacing: layout.groupSpacing) {
                    mineSettingsCard
                    mineGlobalPreferencesCard
                    minePersonalizationCard
                }

                ShellCard {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("Need actual controls?", "需要真正的控制入口？"))
                                .font(.headline)
                                .foregroundStyle(AppShellPalette.textPrimary)
                            Text(t("Open the current Claw for runtime settings and installer work, or Moments for the activity feed.", "去当前 Claw 页面查看运行时设置和安装功能，或者去 Moments 页面看动态流。"))
                                .font(.footnote)
                                .foregroundStyle(AppShellPalette.textSecondary)
                        }

                        Spacer()

                        FlowLayout(spacing: 10, rowSpacing: 10) {
                            Button(t("Open Claws", "打开 Claws")) {
                                onOpenClaws()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(currentClaw.primaryColor)

                            Button(t("Open Moments", "打开 Moments")) {
                                onOpenMoments()
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

    private var mineProfileCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AvatarBadgeView(
                        text: "ME",
                        primaryColor: Color(red: 0.99, green: 0.68, blue: 0.40),
                        secondaryColor: Color(red: 0.93, green: 0.40, blue: 0.35),
                        size: 68
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("You", "你"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppShellPalette.textPrimary)
                        Text(t("Claw keeper", "Claw 管理者"))
                            .font(.headline)
                            .foregroundStyle(AppShellPalette.textSecondary)
                    }
                }

                Text(t("ClawNest already knows your active Mac, your current Claw, and the live feed of moments. Account sync, profile themes, and cross-device identity are still placeholders.", "ClawNest 已经知道你当前的 Mac、当前 Claw 和动态流。账号同步、主题和跨设备身份仍然是占位功能。"))
                    .font(.body)
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                DetailFactsGrid(
                    layout: layout,
                    facts: [
                        (t("Claws", "Claws"), "\(clawCount)"),
                        (t("Moments", "动态"), "\(momentCount)")
                    ]
                )
            }
        }
    }

    private var connectedDevicesCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(t("Connected devices", "已连接设备"))
                    .font(.headline)
                    .foregroundStyle(AppShellPalette.textPrimary)

                ConnectedDeviceRow(
                    name: Host.current().localizedName ?? "This Mac",
                    detail: t("Current device", "当前设备"),
                    statusText: t("Connected", "已连接"),
                    isOnline: true
                )
                ConnectedDeviceRow(
                    name: t("iPhone companion", "iPhone 伴侣端"),
                    detail: t("Placeholder", "占位"),
                    statusText: t("Soon", "即将支持"),
                    isOnline: false
                )
                ConnectedDeviceRow(
                    name: t("iPad glance mode", "iPad 概览端"),
                    detail: t("Placeholder", "占位"),
                    statusText: t("Soon", "即将支持"),
                    isOnline: false
                )
            }
        }
    }

    private var mineSettingsCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Settings", "设置"))
                    .font(.headline)
                    .foregroundStyle(AppShellPalette.textPrimary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("Language", "语言"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppShellPalette.textTertiary)

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
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var mineGlobalPreferencesCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Global preferences", "全局偏好"))
                    .font(.headline)
                    .foregroundStyle(AppShellPalette.textPrimary)
                Text(t("Notification routing, feed density, personality presets, and account-level privacy rules are reserved here. The UI is laid out, but these controls are intentionally left empty for now.", "通知方式、动态密度、人格预设和账号级隐私规则都会放在这里。界面先留好，功能暂时不接。"))
                    .font(.footnote)
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var minePersonalizationCard: some View {
        ShellCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(t("Personalization", "个性化"))
                    .font(.headline)
                    .foregroundStyle(AppShellPalette.textPrimary)
                Text(t("Avatar themes, nicknames for Claws, and warm profile customization belong on this page. Nothing is wired yet, so this remains a placeholder card.", "头像主题、Claw 昵称和更柔和的个人定制都会放在这里。目前还没接功能，所以先保留成占位卡片。"))
                    .font(.footnote)
                    .foregroundStyle(AppShellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: language)
    }
}
