import Darwin
import Foundation

enum ShellInvocationMode: CaseIterable, Sendable {
    case interactiveLogin
    case login
    case interactive
    case plain
}

struct UserShell: Equatable, Sendable {
    let executablePath: String

    func arguments(for script: String, mode: ShellInvocationMode) -> [String] {
        switch mode {
        case .interactiveLogin:
            return ["-i", "-l", "-c", script]
        case .login:
            return ["-l", "-c", script]
        case .interactive:
            return ["-i", "-c", script]
        case .plain:
            return ["-c", script]
        }
    }
}

protocol UserShellProviding: Sendable {
    func currentShell() -> UserShell
}

struct SystemUserShellProvider: UserShellProviding {
    private let environment: [String: String]
    private let fallbackShellPath: String
    private let preferredShellPath: @Sendable () -> String?
    private let isExecutableFile: @Sendable (String) -> Bool

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fallbackShellPath: String = "/bin/zsh",
        preferredShellPath: @escaping @Sendable () -> String? = Self.lookupPreferredShellPath,
        isExecutableFile: @escaping @Sendable (String) -> Bool = { path in
            FileManager.default.isExecutableFile(atPath: path)
        }
    ) {
        self.environment = environment
        self.fallbackShellPath = fallbackShellPath
        self.preferredShellPath = preferredShellPath
        self.isExecutableFile = isExecutableFile
    }

    func currentShell() -> UserShell {
        let candidates = [
            normalizedPath(environment["SHELL"]),
            normalizedPath(preferredShellPath()),
            fallbackShellPath
        ].compactMap { $0 }

        for candidate in candidates where isExecutableFile(candidate) {
            return UserShell(executablePath: candidate)
        }

        return UserShell(executablePath: fallbackShellPath)
    }

    private func normalizedPath(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return NSString(string: trimmed).expandingTildeInPath
    }

    private static func lookupPreferredShellPath() -> String? {
        guard let passwordEntry = getpwuid(getuid()) else {
            return nil
        }

        let shell = String(cString: passwordEntry.pointee.pw_shell)
        return shell.isEmpty ? nil : shell
    }
}

struct ShellProbeRequest: Equatable, Sendable {
    let script: String
    let startMarker: String
    let endMarker: String
}

enum ShellProbeScript {
    private static let pathStartMarker = "__CLAWNEST_PATH_BEGIN__"
    private static let pathEndMarker = "__CLAWNEST_PATH_END__"
    private static let commandStartMarker = "__CLAWNEST_COMMAND_BEGIN__"
    private static let commandEndMarker = "__CLAWNEST_COMMAND_END__"

    static func pathProbe() -> ShellProbeRequest {
        ShellProbeRequest(
            script: """
            printf '%s\\n' '\(pathStartMarker)'
            printf '%s\\n' "$PATH"
            printf '%s\\n' '\(pathEndMarker)'
            """,
            startMarker: pathStartMarker,
            endMarker: pathEndMarker
        )
    }

    static func commandLookup(_ command: String) -> ShellProbeRequest {
        let quotedCommand = shellQuoted(command)
        return ShellProbeRequest(
            script: """
            __clawnest_resolved_command="$(command -v \(quotedCommand) 2>/dev/null || true)"
            printf '%s\\n' '\(commandStartMarker)'
            printf '%s\\n' "$__clawnest_resolved_command"
            printf '%s\\n' '\(commandEndMarker)'
            [ -n "$__clawnest_resolved_command" ]
            """,
            startMarker: commandStartMarker,
            endMarker: commandEndMarker
        )
    }

    static func extractPayload(
        from output: String,
        startMarker: String,
        endMarker: String
    ) -> String? {
        guard let startRange = output.range(of: startMarker),
              let endRange = output.range(
                of: endMarker,
                range: startRange.upperBound ..< output.endIndex
              ) else {
            return nil
        }

        let payload = output[startRange.upperBound ..< endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return payload.isEmpty ? nil : payload
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
