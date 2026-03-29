import Foundation
import Darwin

struct OpenClawCommandDescriptor: Equatable, Sendable {
    let command: String
    let arguments: [String]

    var renderedCommand: String {
        ([command] + arguments).joined(separator: " ")
    }
}

enum CommandExecutionEvent: Sendable {
    case started(command: String, startedAt: Date)
    case output(CommandOutputChunk)
    case finished(CommandResult)
}

protocol OpenClawControlActionServing: Sendable {
    func descriptor(for action: OpenClawControlAction) -> OpenClawCommandDescriptor?
    func execute(_ action: OpenClawControlAction) -> AsyncStream<CommandExecutionEvent>?
}

struct OpenClawControlActionService: OpenClawControlActionServing {
    private let defaults: OpenClawDefaults
    private let runner: CommandRunning
    private let commandResolver: any CommandResolving
    private let environmentProvider: any CommandEnvironmentProviding

    init(
        defaults: OpenClawDefaults = .standard(),
        runner: CommandRunning = ProcessCommandRunner(),
        commandResolver: (any CommandResolving)? = nil,
        environmentProvider: (any CommandEnvironmentProviding)? = nil
    ) {
        self.defaults = defaults
        self.runner = runner
        self.commandResolver = commandResolver ?? ShellCommandResolver(runner: runner)
        self.environmentProvider = environmentProvider ?? ShellCommandEnvironmentProvider(runner: runner)
    }

    func descriptor(for action: OpenClawControlAction) -> OpenClawCommandDescriptor? {
        switch action {
        case .refresh, .openChat:
            return nil
        case .start:
            return OpenClawCommandDescriptor(command: defaults.openClawCommand, arguments: ["gateway", "start"])
        case .restart:
            return OpenClawCommandDescriptor(command: defaults.openClawCommand, arguments: ["gateway", "restart"])
        case .stop:
            return OpenClawCommandDescriptor(command: defaults.openClawCommand, arguments: ["gateway", "stop"])
        case .repair:
            return OpenClawCommandDescriptor(command: defaults.openClawCommand, arguments: ["doctor", "--fix"])
        }
    }

    func execute(_ action: OpenClawControlAction) -> AsyncStream<CommandExecutionEvent>? {
        guard let descriptor = descriptor(for: action) else { return nil }

        return AsyncStream { continuation in
            Task {
                let resolvedCommand = await commandResolver.resolve(descriptor.command) ?? descriptor.command
                let executionEnvironment = await environmentProvider.executionEnvironment()
                let executionPlan = await resolvedExecutionPlan(
                    for: action,
                    fallbackDescriptor: OpenClawCommandDescriptor(
                        command: resolvedCommand,
                        arguments: descriptor.arguments
                    ),
                    executionEnvironment: executionEnvironment
                )
                let startedAt = Date()
                continuation.yield(.started(
                    command: executionPlan.map(\.renderedCommand).joined(separator: " && "),
                    startedAt: startedAt
                ))

                let result = await runExecutionPlan(
                    executionPlan,
                    environment: executionEnvironment,
                    startedAt: startedAt,
                    outputHandler: { chunk in
                        continuation.yield(.output(chunk))
                    }
                )
                continuation.yield(.finished(result))
                continuation.finish()
            }
        }
    }

    private func resolvedExecutionPlan(
        for action: OpenClawControlAction,
        fallbackDescriptor: OpenClawCommandDescriptor,
        executionEnvironment: [String: String]
    ) async -> [OpenClawCommandDescriptor] {
        guard action == .start else {
            return [fallbackDescriptor]
        }

        let launchctlLabel = "gui/\(getuid())/ai.openclaw.gateway"
        let launchctlStatus = await runner.run(
            command: "/bin/launchctl",
            arguments: ["print", launchctlLabel],
            environment: executionEnvironment
        )

        if launchctlStatus.exitCode == 0 {
            return [fallbackDescriptor]
        }

        let installDescriptor = OpenClawCommandDescriptor(
            command: fallbackDescriptor.command,
            arguments: ["gateway", "install"]
        )

        return [installDescriptor, fallbackDescriptor]
    }

    private func runExecutionPlan(
        _ executionPlan: [OpenClawCommandDescriptor],
        environment: [String: String],
        startedAt: Date,
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        let renderedCommand = executionPlan.map(\.renderedCommand).joined(separator: " && ")
        var stdout = ""
        var stderr = ""
        var launchErrors: [String] = []
        var exitCode: Int32 = 0
        var finishedAt = startedAt

        for descriptor in executionPlan {
            if executionPlan.count > 1 {
                let banner = "$ \(descriptor.renderedCommand)\n"
                outputHandler?(CommandOutputChunk(stream: .stdout, text: banner))
                stdout += banner
            }

            let result = await runner.run(
                command: descriptor.command,
                arguments: descriptor.arguments,
                environment: environment,
                outputHandler: outputHandler
            )

            stdout += result.stdout
            stderr += result.stderr
            if let launchError = result.launchError,
               !launchError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                launchErrors.append(launchError)
            }
            exitCode = result.exitCode
            finishedAt = result.finishedAt

            if result.exitCode != 0 || result.launchError != nil {
                break
            }
        }

        return CommandResult(
            command: renderedCommand,
            arguments: [],
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            launchError: launchErrors.isEmpty ? nil : launchErrors.joined(separator: "\n"),
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}
