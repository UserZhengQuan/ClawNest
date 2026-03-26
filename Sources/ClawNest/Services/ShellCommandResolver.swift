import Foundation

protocol CommandResolving: Sendable {
    func resolve(_ command: String) async -> String?
}

actor ShellCommandResolver: CommandResolving {
    private let runner: CommandRunning
    private let shellProvider: any UserShellProviding
    private var cache: [String: String?] = [:]

    init(
        runner: CommandRunning = ProcessCommandRunner(),
        shellProvider: any UserShellProviding = SystemUserShellProvider()
    ) {
        self.runner = runner
        self.shellProvider = shellProvider
    }

    func resolve(_ command: String) async -> String? {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return nil }

        if let cached = cache[trimmedCommand] {
            return cached
        }

        let resolved = await resolveUncached(trimmedCommand)
        cache[trimmedCommand] = resolved
        return resolved
    }

    private func resolveUncached(_ command: String) async -> String? {
        let expandedPath = NSString(string: command).expandingTildeInPath
        if expandedPath.contains("/") {
            return expandedPath
        }

        let shell = shellProvider.currentShell()
        let request = ShellProbeScript.commandLookup(command)

        for mode in ShellInvocationMode.allCases {
            let result = await runner.run(
                command: shell.executablePath,
                arguments: shell.arguments(for: request.script, mode: mode)
            )
            let path = ShellProbeScript.extractPayload(
                from: result.stdout,
                startMarker: request.startMarker,
                endMarker: request.endMarker
            ) ?? fallbackPath(from: result.stdout)

            if let path, path.contains("/") {
                return path
            }
        }

        return nil
    }

    private func fallbackPath(from stdout: String) -> String? {
        stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                !line.isEmpty && line.contains("/") && !line.contains(" ")
            }
    }
}
