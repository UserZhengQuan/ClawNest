import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    @State private var selectedSection: WorkspaceSection = .claw
    @State private var selectedWorkbenchSection: ClawWorkbenchSection = .overview

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceLayoutMetrics(containerSize: proxy.size)

            ZStack {
                AppShellBackgroundView(layout: layout)

                HStack(spacing: 0) {
                    WorkspaceSidebarView(
                        layout: layout,
                        language: model.language,
                        selectedSection: selectedSection,
                        onSelectSection: { selectedSection = $0 }
                    )

                    Divider()
                        .overlay(AppShellPalette.divider)

                    detailSurface(layout: layout)
                }
                .padding(layout.rootPadding)
            }
        }
        .preferredColorScheme(.light)
        .frame(minWidth: ClawNestLayout.Window.minimumWidth, minHeight: ClawNestLayout.Window.minimumHeight)
    }

    @ViewBuilder
    private func detailSurface(layout: WorkspaceLayoutMetrics) -> some View {
        ClawWorkspaceView(
            model: model,
            layout: layout,
            language: model.language,
            selectedWorkbenchSection: $selectedWorkbenchSection
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(layout.surfacePadding)
    }
}
