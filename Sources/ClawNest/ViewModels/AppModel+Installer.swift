import AppKit
import Foundation

@MainActor
extension AppModel {
    func installOpenClaw() {
        let progressSink = InstallProgressSink(model: self)
        Task {
            isInstallingOpenClaw = true
            installStatusMessage = nil
            installProgress = .idle
            applyInstallProgress(
                .activate(
                    stage: .checkingEnvironment,
                    detail: "Inspecting this Mac for an existing OpenClaw CLI, Apple Command Line Tools, and Homebrew."
                )
            )
            defer { isInstallingOpenClaw = false }

            do {
                let result = try await openClawInstaller.install(
                    progressRelay: progressSink.makeRelay()
                )

                if installProgress.stageState(for: .finalizing) == .pending {
                    applyInstallProgress(
                        .activate(
                            stage: .finalizing,
                            detail: "Saving the resolved OpenClaw CLI path and refreshing ClawNest."
                        )
                    )
                } else {
                    applyInstallProgress(
                        .setDetail("Saving the resolved OpenClaw CLI path and refreshing ClawNest.")
                    )
                }

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
                applyInstallProgress(.finish(detail: result.summary))
                installStatusMessage = result.summary
            } catch {
                let failureUpdate = fallbackInstallFailure(for: error)
                applyInstallProgress(failureUpdate)
                installStatusMessage = installProgress.failure?.summary ?? error.localizedDescription
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .error,
                        title: "OpenClaw CLI install failed",
                        message: installProgress.failure?.summary ?? error.localizedDescription,
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
            applyInstallProgress(
                .activate(
                    stage: .installingDeveloperTools,
                    detail: "macOS should now show the Command Line Tools installer. Finish that install, then retry OpenClaw."
                )
            )
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
            applyInstallProgress(
                .fail(
                    stage: .installingDeveloperTools,
                    summary: "ClawNest could not start the Apple Command Line Tools installer.",
                    recoverySuggestion: "Run `xcode-select --install` manually in Terminal, then retry Install OpenClaw.",
                    rawOutput: error.localizedDescription
                )
            )
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

    private func applyInstallProgress(_ update: OpenClawInstallProgressUpdate) {
        installProgress.apply(update)
    }

    private func fallbackInstallFailure(for error: Error) -> OpenClawInstallProgressUpdate {
        let rawOutput = error.localizedDescription
        let normalizedOutput = rawOutput.lowercased()

        if normalizedOutput.contains("xcode-select --install") ||
            normalizedOutput.contains("command line tools") ||
            normalizedOutput.contains("developer tools") {
            return .fail(
                stage: .installingDeveloperTools,
                summary: "Apple Command Line Tools still need to be installed before OpenClaw can continue.",
                recoverySuggestion: "Finish the macOS Command Line Tools install, then retry Install OpenClaw.",
                rawOutput: rawOutput
            )
        }

        if normalizedOutput.contains("homebrew") ||
            normalizedOutput.contains("brew install") ||
            normalizedOutput.contains("/opt/homebrew") ||
            normalizedOutput.contains("/usr/local/homebrew") {
            return .fail(
                stage: .installingHomebrew,
                summary: "Homebrew could not be installed automatically.",
                recoverySuggestion: "Confirm the Homebrew installer or permission prompts completed, then retry Install OpenClaw.",
                rawOutput: rawOutput
            )
        }

        if let installError = error as? OpenClawInstallError,
           case .missingOpenClawBinary = installError {
            return .fail(
                stage: .finalizing,
                summary: "The official installer finished, but ClawNest still could not find `openclaw` on PATH.",
                recoverySuggestion: "Open a new terminal to confirm `command -v openclaw`, then retry or add the installed location to PATH manually.",
                rawOutput: rawOutput
            )
        }

        let stage = installProgress.currentStage ?? .installingOpenClawCLI

        if normalizedOutput.contains("could not resolve host") ||
            normalizedOutput.contains("failed to connect") ||
            normalizedOutput.contains("timed out") ||
            normalizedOutput.contains("network") {
            return .fail(
                stage: stage,
                summary: "The official installer could not reach the network.",
                recoverySuggestion: "Check internet access, then retry Install OpenClaw.",
                rawOutput: rawOutput
            )
        }

        return .fail(
            stage: stage,
            summary: "The official OpenClaw installer exited before finishing.",
            recoverySuggestion: "Review the installer output below, resolve the blocking issue, then retry Install OpenClaw.",
            rawOutput: rawOutput
        )
    }
}

private final class InstallProgressSink: @unchecked Sendable {
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
    }

    func makeRelay() -> OpenClawInstallProgressRelay {
        OpenClawInstallProgressRelay { [weak self] update in
            Task { @MainActor [weak self] in
                self?.model?.installProgress.apply(update)
            }
        }
    }
}
