import Foundation

struct CommandResult: Sendable {
    let command: String
    let arguments: [String]
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let launchError: String?

    var renderedCommand: String {
        ([command] + arguments).joined(separator: " ")
    }

    var combinedOutput: String {
        [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

protocol CommandRunning: Sendable {
    func run(command: String, arguments: [String], environment: [String: String]) async -> CommandResult
}

extension CommandRunning {
    func run(command: String, arguments: [String]) async -> CommandResult {
        await run(command: command, arguments: arguments, environment: [:])
    }
}

final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    func run(command: String, arguments: [String], environment: [String: String] = [:]) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let stdoutAccumulator = DataAccumulator()
            let stderrAccumulator = DataAccumulator()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                stdoutAccumulator.append(chunk)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                stderrAccumulator.append(chunk)
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

                stdoutAccumulator.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                stderrAccumulator.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                continuation.resume(returning: CommandResult(
                    command: command,
                    arguments: arguments,
                    exitCode: process.terminationStatus,
                    stdout: stdoutAccumulator.stringValue,
                    stderr: stderrAccumulator.stringValue,
                    launchError: nil
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
                    launchError: error.localizedDescription
                ))
            }
        }
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
