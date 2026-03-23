import SwiftUI

struct MomentsWorkspaceView: View {
    let layout: WorkspaceLayoutMetrics
    let language: AppLanguage
    let momentFilters: [WorkspaceMomentFilter]
    let activeMomentFilterID: String
    let filteredMomentPosts: [MomentFeedItem]
    let onSelectFilter: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkspaceHeaderView(
                    eyebrow: t("Moments", "动态"),
                    title: t("A social feed for what each Claw has been up to.", "用社交动态流来展示每个 Claw 最近做了什么。"),
                    subtitle: t("Completed tasks, failed repairs, installs, and health shifts all land as readable timeline cards instead of terminal noise.", "完成任务、修复失败、安装事件和状态变化都会变成易读的时间流卡片，而不是终端噪音。")
                )

                ShellCard {
                    FlowLayout(spacing: 10, rowSpacing: 10) {
                        ForEach(momentFilters) { filter in
                            Button {
                                onSelectFilter(filter.id)
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
                    ShellCard {
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
                            MomentCardView(post: post)
                        }
                    }
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
    }

    private func t(_ english: String, _ simplifiedChinese: String) -> String {
        localized(english, simplifiedChinese, language: language)
    }
}
