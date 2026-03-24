import AppKit
import Foundation

@MainActor
extension AppModel {
    func updateInstallDirectoryPath(_ path: String) {
        installDraft.installDirectoryPath = path
        Task {
            await refreshInstallSnapshot()
        }
    }

    func updateInstallPortText(_ text: String) {
        installDraft.gatewayPortText = text
        Task {
            await refreshInstallSnapshot()
        }
    }

    func chooseInstallDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let currentPath = NSString(string: installDraft.installDirectoryPath).expandingTildeInPath
        if !currentPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: currentPath, isDirectory: true)
        }

        if panel.runModal() == .OK, let url = panel.url {
            updateInstallDirectoryPath(url.path)
        }
    }

    func installOpenClaw() {
        Task {
            isInstallingOpenClaw = true
            installStatusMessage = nil
            defer { isInstallingOpenClaw = false }

            do {
                let result = try await openClawInstaller.install(draft: installDraft)
                installStatusMessage = result.summary
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .success,
                        title: "OpenClaw installed",
                        message: result.summary,
                        command: nil
                    )
                )
                saveConfiguration(updatedConfiguration(afterInstalling: result.installedCommand))
                await refreshInstallSnapshot()
            } catch {
                installStatusMessage = error.localizedDescription
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .error,
                        title: "OpenClaw install failed",
                        message: error.localizedDescription,
                        command: nil
                    )
                )
            }
        }
    }

    private func updatedConfiguration(afterInstalling installedCommand: String) -> ClawNestConfiguration {
        var updated = configuration
        updated.openClawCommand = installedCommand

        if configurationLooksClawNestManaged(updated) {
            updated.dashboardURLString = ClawNestConfiguration.standard.dashboardURLString
            updated.launchAgentLabel = ClawNestConfiguration.standard.launchAgentLabel
        }

        return updated
    }

    private func configurationLooksClawNestManaged(_ configuration: ClawNestConfiguration) -> Bool {
        configuration.launchAgentLabel.hasPrefix("ai.clawnest.openclaw.")
    }

    func installDeveloperTools() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--install"]

        do {
            try process.run()
            appendDiagnostic(
                DiagnosticEntry(
                    timestamp: .now,
                    level: .info,
                    title: "Requested Apple developer tools",
                    message: "macOS should now show the Command Line Tools installer. Finish that install, then retry OpenClaw.",
                    command: "xcode-select --install"
                )
            )
            installStatusMessage = "macOS should now show the Command Line Tools installer. Finish that install, then retry OpenClaw."
        } catch {
            installStatusMessage = "Could not start `xcode-select --install`: \(error.localizedDescription)"
            appendDiagnostic(
                DiagnosticEntry(
                    timestamp: .now,
                    level: .warning,
                    title: "Developer tools prompt failed",
                    message: error.localizedDescription,
                    command: "xcode-select --install"
                )
            )
        }
    }

    func refreshInstallSnapshot() async {
        let snapshot = await openClawInstaller.snapshot(for: installDraft)
        installValidation = snapshot.validation
        knownOpenClawInstances = snapshot.knownInstances
    }
}
