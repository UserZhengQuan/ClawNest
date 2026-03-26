import Foundation

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

    init(
        defaults: OpenClawDefaults = .standard(),
        runner: CommandRunning = ProcessCommandRunner()
    ) {
        self.defaults = defaults
        self.runner = runner
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
            continuation.yield(.started(command: descriptor.renderedCommand, startedAt: .now))

            Task {
                let result = await runner.run(
                    command: descriptor.command,
                    arguments: descriptor.arguments,
                    outputHandler: { chunk in
                        continuation.yield(.output(chunk))
                    }
                )
                continuation.yield(.finished(result))
                continuation.finish()
            }
        }
    }
}
