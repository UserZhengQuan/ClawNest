import Foundation
import SwiftUI

enum MenuBarIndicatorState: Equatable, Sendable {
    case neutral
    case healthy
    case unhealthy
}

enum OpenClawControlAction: String, CaseIterable, Identifiable, Sendable {
    case refresh
    case openChat
    case start
    case restart
    case stop
    case repair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .refresh:
            return "Refresh"
        case .openChat:
            return "Open Chat"
        case .start:
            return "Start"
        case .restart:
            return "Restart"
        case .stop:
            return "Stop"
        case .repair:
            return "Repair"
        }
    }

    var subtitle: String {
        switch self {
        case .refresh:
            return "Re-read local OpenClaw status"
        case .openChat:
            return "Open OpenClaw Web UI"
        case .start, .restart, .stop:
            return "Run official OpenClaw command"
        case .repair:
            return "Runs official command: openclaw doctor --fix"
        }
    }

    var systemImage: String {
        switch self {
        case .refresh:
            return "arrow.clockwise"
        case .openChat:
            return "bubble.left.and.text.bubble.right"
        case .start:
            return "play.fill"
        case .restart:
            return "arrow.triangle.2.circlepath"
        case .stop:
            return "stop.fill"
        case .repair:
            return "wrench.and.screwdriver"
        }
    }

    var usesOfficialCommand: Bool {
        switch self {
        case .start, .restart, .stop, .repair:
            return true
        case .refresh, .openChat:
            return false
        }
    }
}

enum CommandExecutionStatus: Equatable, Sendable {
    case running
    case success
    case failed

    var label: String {
        switch self {
        case .running:
            return "Running"
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        }
    }

    var color: Color {
        switch self {
        case .running:
            return Color(red: 0.17, green: 0.46, blue: 0.84)
        case .success:
            return Color(red: 0.18, green: 0.56, blue: 0.29)
        case .failed:
            return Color(red: 0.78, green: 0.25, blue: 0.22)
        }
    }

    var symbolName: String {
        switch self {
        case .running:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}

struct CommandExecutionRecord: Equatable, Sendable {
    let action: OpenClawControlAction
    let command: String
    let status: CommandExecutionStatus
    let startedAt: Date
    let finishedAt: Date?
    let exitCode: Int32?
    let stdout: String
    let stderr: String
    let launchError: String?

    static func running(
        action: OpenClawControlAction,
        command: String,
        startedAt: Date = .now
    ) -> CommandExecutionRecord {
        CommandExecutionRecord(
            action: action,
            command: command,
            status: .running,
            startedAt: startedAt,
            finishedAt: nil,
            exitCode: nil,
            stdout: "",
            stderr: "",
            launchError: nil
        )
    }

    static func finished(
        action: OpenClawControlAction,
        result: CommandResult
    ) -> CommandExecutionRecord {
        CommandExecutionRecord(
            action: action,
            command: result.renderedCommand,
            status: executionStatus(action: action, result: result),
            startedAt: result.startedAt,
            finishedAt: result.finishedAt,
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            launchError: result.launchError
        )
    }

    func appending(_ chunk: CommandOutputChunk) -> CommandExecutionRecord {
        switch chunk.stream {
        case .stdout:
            return CommandExecutionRecord(
                action: action,
                command: command,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                exitCode: exitCode,
                stdout: stdout + chunk.text,
                stderr: stderr,
                launchError: launchError
            )
        case .stderr:
            return CommandExecutionRecord(
                action: action,
                command: command,
                status: status,
                startedAt: startedAt,
                finishedAt: finishedAt,
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr + chunk.text,
                launchError: launchError
            )
        }
    }

    func appendingCommand(_ command: String) -> CommandExecutionRecord {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return self }

        let existingCommands = self.command
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        guard existingCommands.last != trimmedCommand else {
            return self
        }

        let updatedCommand = ([self.command] + [trimmedCommand])
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        return CommandExecutionRecord(
            action: action,
            command: updatedCommand,
            status: status,
            startedAt: startedAt,
            finishedAt: finishedAt,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            launchError: launchError
        )
    }

    var duration: TimeInterval? {
        guard let finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    var stderrWithLaunchError: String {
        [stderr, launchError ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    func overridingStatus(
        _ status: CommandExecutionStatus,
        appendingStderr note: String? = nil
    ) -> CommandExecutionRecord {
        let appendedStderr: String
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appendedStderr = [stderr, note]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: stderr.isEmpty ? "" : "\n")
        } else {
            appendedStderr = stderr
        }

        return CommandExecutionRecord(
            action: action,
            command: command,
            status: status,
            startedAt: startedAt,
            finishedAt: finishedAt,
            exitCode: exitCode,
            stdout: stdout,
            stderr: appendedStderr,
            launchError: launchError
        )
    }

    private static func executionStatus(
        action: OpenClawControlAction,
        result: CommandResult
    ) -> CommandExecutionStatus {
        if let statusHint = result.statusHint {
            switch statusHint {
            case .success:
                return .success
            case .failed:
                return .failed
            }
        }

        guard result.exitCode == 0, result.launchError == nil else {
            return .failed
        }

        let combinedOutput = [result.stdout, result.stderr]
            .joined(separator: "\n")
            .lowercased()

        switch action {
        case .start, .restart:
            if combinedOutput.contains("gateway service not loaded")
                || combinedOutput.contains("start with: openclaw gateway install")
                || combinedOutput.contains("start with: launchctl bootstrap")
                || combinedOutput.contains("not installed") {
                return .failed
            }
        case .refresh, .openChat, .stop, .repair:
            break
        }

        return .success
    }
}
