import AppKit
import Foundation

@MainActor
extension AppModel {
    func installOpenClaw() {
        Task {
            isInstallingOpenClaw = true
            installStatusMessage = nil
            defer { isInstallingOpenClaw = false }

            do {
                let result = try await openClawInstaller.install()
                installStatusMessage = result.summary
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .success,
                        title: "OpenClaw CLI installed",
                        message: result.summary,
                        command: nil
                    )
                )
                saveConfiguration(updatedConfiguration(afterInstalling: result.installedCommand))
                await refreshInstallSnapshot()
                await refresh(trigger: .manual)
            } catch {
                installStatusMessage = error.localizedDescription
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .error,
                        title: "OpenClaw CLI install failed",
                        message: error.localizedDescription,
                        command: nil
                    )
                )
                await refreshInstallSnapshot()
            }
        }
    }

    private func updatedConfiguration(afterInstalling installedCommand: String) -> ClawNestConfiguration {
        var updated = configuration
        updated.openClawCommand = installedCommand
        return updated
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
        installSnapshot = await openClawInstaller.snapshot(currentCommand: configuration.openClawCommand)
    }
}
