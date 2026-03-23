import AppKit
import SwiftUI

@main
struct ClawNestApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup("ClawNest") {
            ContentView(model: model)
                .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
                .background(MainWindowBehaviorView())
        }
        .defaultSize(width: ClawNestLayout.Window.defaultWidth, height: ClawNestLayout.Window.defaultHeight)
        .commands {
            CommandGroup(after: .windowSize) {
                Divider()

                Button("Maximize Window") {
                    MainWindowController.zoomFrontWindow()
                }
                .keyboardShortcut("=", modifiers: [.command, .option])
                .disabled(!MainWindowController.canZoomFrontWindow)

                Button("Restore Window Size") {
                    MainWindowController.restoreFrontWindow()
                }
                .disabled(!MainWindowController.canRestoreFrontWindow)
            }
        }

        MenuBarExtra("ClawNest", systemImage: model.snapshot.level.menuBarSymbol) {
            MenuBarContentView(model: model)
                .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        }
    }
}
