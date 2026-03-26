import Foundation

protocol CommandResolving: Sendable {
    func resolve(_ command: String) async -> String?
}

actor ShellCommandResolver: CommandResolving {
    private let runner: CommandRunning
    private var cache: [String: String?] = [:]

    init(runner: CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
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

        for shellFlag in ["-lc", "-ic"] {
            let result = await runner.run(
                command: "/bin/zsh",
                arguments: [shellFlag, "command -v \(shellQuoted(command))"]
            )

            guard result.exitCode == 0 else { continue }
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            if path.contains("/") {
                return path
            }
        }

        return nil
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
