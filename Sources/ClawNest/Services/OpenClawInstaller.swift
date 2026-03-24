import Foundation

struct OpenClawInstallerSnapshot: Equatable, Sendable {
    let resolvedCommandPath: String?
    let message: String
    let nextStep: String

    var isInstalled: Bool {
        resolvedCommandPath != nil
    }
}

struct OpenClawInstallResult: Sendable {
    let installedCommand: String
    let summary: String
}

enum OpenClawInstallError: LocalizedError {
    case installScriptFailed(String)
    case missingOpenClawBinary

    var errorDescription: String? {
        switch self {
        case let .installScriptFailed(message):
            return message
        case .missingOpenClawBinary:
            return "OpenClaw finished installing, but the `openclaw` executable still could not be found."
        }
    }
}

actor OpenClawInstaller {
    private let runner: CommandRunning

    init(runner: CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
    }

    func snapshot(currentCommand: String) async -> OpenClawInstallerSnapshot {
        let configuredPath = await resolveExecutable(for: currentCommand)
        let defaultPath = currentCommand == "openclaw" ? configuredPath : await resolveExecutable(for: "openclaw")
        let resolvedPath = configuredPath ?? defaultPath

        if let resolvedPath {
            if configuredPath == nil, currentCommand != "openclaw" {
                return OpenClawInstallerSnapshot(
                    resolvedCommandPath: resolvedPath,
                    message: "OpenClaw CLI is installed, but the current runtime command `\(currentCommand)` did not resolve.",
                    nextStep: "Update the runtime command to the detected CLI path, then continue with dashboard, logs, and repair flows from this workspace."
                )
            }

            return OpenClawInstallerSnapshot(
                resolvedCommandPath: resolvedPath,
                message: "OpenClaw CLI is installed and ready for the local Claw workspace.",
                nextStep: "Use this workspace to refresh health, run repair, open the dashboard, or continue with `openclaw onboard --install-daemon` if first-run setup is still pending."
            )
        }

        return OpenClawInstallerSnapshot(
            resolvedCommandPath: nil,
            message: "OpenClaw CLI is not installed yet.",
            nextStep: "Install it here, then continue with `openclaw onboard --install-daemon` for the official onboarding flow."
        )
    }

    func install() async throws -> OpenClawInstallResult {
        let openClawExecutable = try await ensureOpenClawInstalled()

        return OpenClawInstallResult(
            installedCommand: openClawExecutable,
            summary: "OpenClaw CLI is installed and available to system terminals. Continue with `openclaw onboard --install-daemon` to finish the official onboarding and background-service setup."
        )
    }

    private func ensureOpenClawInstalled() async throws -> String {
        if let existingExecutable = await resolveExecutable(for: "openclaw") {
            return existingExecutable
        }

        let installCommand = "curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard"
        let installResult = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", installCommand]
        )

        if installResult.exitCode != 0 {
            let output = cleanedInstallerOutput(from: installResult)
                .ifEmpty("The official installer exited without producing output.")
            throw OpenClawInstallError.installScriptFailed(output)
        }

        if let installedExecutable = await resolveExecutable(for: "openclaw") {
            return installedExecutable
        }

        throw OpenClawInstallError.missingOpenClawBinary
    }

    private func resolveExecutable(for command: String) async -> String? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return nil }

        let expandedPath = NSString(string: trimmedCommand).expandingTildeInPath
        if expandedPath.contains("/") {
            return FileManager.default.isExecutableFile(atPath: expandedPath) ? expandedPath : nil
        }

        let result = await runner.run(
            command: "/bin/zsh",
            arguments: ["-lc", "command -v \(shellQuoted(trimmedCommand))"]
        )

        guard result.exitCode == 0 else { return nil }
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private func cleanedInstallerOutput(from result: CommandResult) -> String {
        let output = result.combinedOutput.ifEmpty(result.launchError ?? "")
        return stripANSIEscapes(from: output)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func stripANSIEscapes(from text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
