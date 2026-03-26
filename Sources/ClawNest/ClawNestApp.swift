import SwiftUI

@MainActor
@main
struct ClawNestApp: App {
    @StateObject private var viewModel = StatusPanelViewModel()

    var body: some Scene {
        Window("ClawNest", id: "main") {
            ContentView(viewModel: viewModel)
        }
        .defaultSize(width: 720, height: 520)
    }
}
