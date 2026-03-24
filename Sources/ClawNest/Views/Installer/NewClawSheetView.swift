import SwiftUI

struct NewClawSheetView: View {
    @ObservedObject var model: AppModel
    let language: AppLanguage
    let onClose: () -> Void

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: language)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceLayoutMetrics(containerSize: proxy.size)

            ZStack {
                AppShellBackgroundView(layout: layout)

                ScrollView {
                    VStack(alignment: .leading, spacing: layout.groupSpacing) {
                        ShellCard {
                            Group {
                                if layout.formStacksVertically {
                                    VStack(alignment: .leading, spacing: 16) {
                                        headerBody
                                        closeButton
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 16) {
                                        headerBody
                                        Spacer()
                                        closeButton
                                    }
                                }
                            }
                        }

                        OpenClawInstallView(model: model, language: language, layout: layout)

                        ShellCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t("After closing", "关闭后"))
                                    .font(.headline)
                                    .foregroundStyle(AppShellPalette.textPrimary)
                                Text(t("ClawNest will refresh known Claws and the latest runtime snapshot after this sheet closes.", "关闭这个弹窗后，ClawNest 会刷新已知 Claw 列表和最新运行时状态。"))
                                    .font(.footnote)
                                    .foregroundStyle(AppShellPalette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(layout.pageInset)
                }
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.light)
        .frame(minWidth: 880, minHeight: 720)
        .task {
            await model.refreshInstallSnapshot()
        }
        .interactiveDismissDisabled(model.isInstallingOpenClaw)
    }

    private var headerBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("New Claw", "新建 Claw"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppShellPalette.textPrimary)
            Text(t("Keep the main workspace stable while this sheet handles environment checks, installation, failure messages, and the next setup step.", "让主工作区保持稳定，把环境检测、安装过程、失败提示和下一步引导都收进这个弹窗里。"))
                .font(.subheadline)
                .foregroundStyle(AppShellPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var closeButton: some View {
        Button(t("Close", "关闭")) {
            onClose()
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.88, green: 0.90, blue: 0.94))
        .disabled(model.isInstallingOpenClaw)
    }
}
