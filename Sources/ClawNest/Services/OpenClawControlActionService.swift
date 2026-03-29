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
                let executionDescriptor = await resolvedDescriptor(
                    for: action,
                    fallbackDescriptor: OpenClawCommandDescriptor(
                        command: resolvedCommand,
                        arguments: descriptor.arguments
                    ),
                    executionEnvironment: executionEnvironment
                )
                let startedAt = Date()
                continuation.yield(.started(
                    command: executionDescriptor.renderedCommand,
                    startedAt: startedAt
                ))

                let result = await runner.run(
                    command: executionDescriptor.command,
                    arguments: executionDescriptor.arguments,
                    environment: executionEnvironment,
                    outputHandler: { chunk in
                        continuation.yield(.output(chunk))
                    }
                )
                continuation.yield(.finished(result))
                continuation.finish()
            }
        }
    }

    private func resolvedDescriptor(
        for action: OpenClawControlAction,
        fallbackDescriptor: OpenClawCommandDescriptor,
        executionEnvironment: [String: String]
    ) async -> OpenClawCommandDescriptor {
        guard action == .start else {
            return fallbackDescriptor
        }

        let launchctlLabel = "gui/\(getuid())/ai.openclaw.gateway"
        let launchctlStatus = await runner.run(
            command: "/bin/launchctl",
            arguments: ["print", launchctlLabel],
            environment: executionEnvironment
        )

        if launchctlStatus.exitCode == 0 {
            return fallbackDescriptor
        }

        return OpenClawCommandDescriptor(
            command: fallbackDescriptor.command,
            arguments: ["gateway", "install"]
        )
    }
}
