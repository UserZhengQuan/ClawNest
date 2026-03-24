import AppKit
import SwiftUI

@main
struct ClawNestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            CommandMenu("Claws") {
                Button("About ClawNest") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }

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

                Divider()

                Button("Hide ClawNest") {
                    NSApp.hide(nil)
                }
                .keyboardShortcut("h", modifiers: [.command])

                Button("Hide Others") {
                    NSApp.hideOtherApplications(nil)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])

                Button("Show All") {
                    NSApp.unhideAllApplications(nil)
                }

                Divider()

                Button("Quit ClawNest") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }

        MenuBarExtra("ClawNest", systemImage: model.snapshot.level.menuBarSymbol) {
            MenuBarContentView(model: model)
                .environment(\.locale, Locale(identifier: model.language.localeIdentifier))
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            MainMenuController.keepOnlyClawsMenu()
        }
    }
}

@MainActor
enum MainMenuController {
    static func keepOnlyClawsMenu() {
        guard let mainMenu = NSApp.mainMenu,
              let clawsItem = mainMenu.items.first(where: { $0.title == "Claws" }) else {
            return
        }

        while mainMenu.numberOfItems > 0 {
            mainMenu.removeItem(at: 0)
        }

        mainMenu.addItem(clawsItem)
    }
}
