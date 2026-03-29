import Foundation

enum CommandOutputStream: Sendable {
    case stdout
    case stderr
}

struct CommandOutputChunk: Sendable {
    let stream: CommandOutputStream
    let text: String
}

enum CommandResultStatusHint: Sendable {
    case success
    case failed
}

struct CommandResult: Sendable {
    let command: String
    let arguments: [String]
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let launchError: String?
    let statusHint: CommandResultStatusHint?
    let startedAt: Date
    let finishedAt: Date

    init(
        command: String,
        arguments: [String],
        exitCode: Int32,
        stdout: String,
        stderr: String,
        launchError: String?,
        statusHint: CommandResultStatusHint? = nil,
        startedAt: Date = .now,
        finishedAt: Date? = nil
    ) {
        self.command = command
        self.arguments = arguments
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.launchError = launchError
        self.statusHint = statusHint
        self.startedAt = startedAt
        self.finishedAt = finishedAt ?? startedAt
    }

    var renderedCommand: String {
        ([command] + arguments).joined(separator: " ")
    }

    var combinedOutput: String {
        [stdout, stderr, launchError ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }
}

protocol CommandRunning: Sendable {
    func run(
        command: String,
        arguments: [String],
        environment: [String: String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult
}

extension CommandRunning {
    func run(
        command: String,
        arguments: [String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)? = nil
    ) async -> CommandResult {
        await run(
            command: command,
            arguments: arguments,
            environment: [:],
            outputHandler: outputHandler
        )
    }

    func run(
        command: String,
        arguments: [String],
        environment: [String: String]
    ) async -> CommandResult {
        await run(
            command: command,
            arguments: arguments,
            environment: environment,
            outputHandler: nil
        )
    }

    func run(command: String, arguments: [String]) async -> CommandResult {
        await run(command: command, arguments: arguments, environment: [:], outputHandler: nil)
    }
}

final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    func run(
        command: String,
        arguments: [String],
        environment: [String: String] = [:],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)? = nil
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdoutAccumulator = DataAccumulator()
            let stderrAccumulator = DataAccumulator()
            let startedAt = Date()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                stdoutAccumulator.append(chunk)
                Self.forward(chunk: chunk, stream: .stdout, outputHandler: outputHandler)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                stderrAccumulator.append(chunk)
                Self.forward(chunk: chunk, stream: .stderr, outputHandler: outputHandler)
            }

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            if !environment.isEmpty {
                var mergedEnvironment = ProcessInfo.processInfo.environment
                environment.forEach { key, value in
                    mergedEnvironment[key] = value
                }
                process.environment = mergedEnvironment
            }
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.terminationHandler = { process in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                stdoutAccumulator.append(remainingStdout)
                stderrAccumulator.append(remainingStderr)
                Self.forward(chunk: remainingStdout, stream: .stdout, outputHandler: outputHandler)
                Self.forward(chunk: remainingStderr, stream: .stderr, outputHandler: outputHandler)

                continuation.resume(returning: CommandResult(
                    command: command,
                    arguments: arguments,
                    exitCode: process.terminationStatus,
                    stdout: stdoutAccumulator.stringValue,
                    stderr: stderrAccumulator.stringValue,
                    launchError: nil,
                    startedAt: startedAt,
                    finishedAt: Date()
                ))
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                continuation.resume(returning: CommandResult(
                    command: command,
                    arguments: arguments,
                    exitCode: -1,
                    stdout: "",
                    stderr: "",
                    launchError: error.localizedDescription,
                    startedAt: startedAt,
                    finishedAt: Date()
                ))
            }
        }
    }

    private static func forward(
        chunk: Data,
        stream: CommandOutputStream,
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) {
        guard !chunk.isEmpty else { return }
        let text = String(decoding: chunk, as: UTF8.self)
        guard !text.isEmpty else { return }
        outputHandler?(CommandOutputChunk(stream: stream, text: text))
    }
}

private final class DataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var stringValue: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
