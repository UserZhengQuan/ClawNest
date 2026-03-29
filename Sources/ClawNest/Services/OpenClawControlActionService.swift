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
    case stepStarted(command: String)
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
                let startedAt = Date()
                continuation.yield(.started(
                    command: OpenClawCommandDescriptor(
                        command: resolvedCommand,
                        arguments: descriptor.arguments
                    ).renderedCommand,
                    startedAt: startedAt
                ))

                let result = await runExecutionPlan(
                    for: action,
                    command: resolvedCommand,
                    initialArguments: descriptor.arguments,
                    environment: executionEnvironment,
                    startedAt: startedAt,
                    stepHandler: { command in
                        continuation.yield(.stepStarted(command: command))
                    },
                    outputHandler: { chunk in
                        continuation.yield(.output(chunk))
                    }
                )
                continuation.yield(.finished(result))
                continuation.finish()
            }
        }
    }

    private func runExecutionPlan(
        for action: OpenClawControlAction,
        command: String,
        initialArguments: [String],
        environment: [String: String],
        startedAt: Date,
        stepHandler: @escaping @Sendable (String) -> Void,
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        let initialDescriptor = OpenClawCommandDescriptor(command: command, arguments: initialArguments)
        var executionPlan = [initialDescriptor]
        var aggregatedResults: [CommandResult] = []
        var stdout = ""
        var stderr = ""
        var launchErrors: [String] = []
        var exitCode: Int32 = 0
        var finishedAt = startedAt

        let initialResult = await runStep(
            initialDescriptor,
            shouldShowBanner: true,
            environment: environment,
            outputHandler: outputHandler
        )
        aggregatedResults.append(initialResult)

        if action == .start, requiresGatewayInstall(after: initialResult) {
            let installDescriptor = OpenClawCommandDescriptor(command: command, arguments: ["gateway", "install"])
            executionPlan.append(installDescriptor)
            let installResult = await runStep(
                installDescriptor,
                shouldShowBanner: true,
                environment: environment,
                stepHandler: stepHandler,
                outputHandler: outputHandler
            )
            aggregatedResults.append(installResult)

            if installResult.exitCode == 0, installResult.launchError == nil {
                executionPlan.append(initialDescriptor)
                let retryResult = await runStep(
                    initialDescriptor,
                    shouldShowBanner: true,
                    environment: environment,
                    stepHandler: stepHandler,
                    outputHandler: outputHandler
                )
                aggregatedResults.append(retryResult)
            }
        }

        for result in aggregatedResults {
            stdout += result.stdout
            stderr += result.stderr
            if let launchError = result.launchError,
               !launchError.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                launchErrors.append(launchError)
            }
            exitCode = result.exitCode
            finishedAt = result.finishedAt
        }

        return CommandResult(
            command: executionPlan
                .map(\.renderedCommand)
                .joined(separator: "\n"),
            arguments: [],
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr,
            launchError: launchErrors.isEmpty ? nil : launchErrors.joined(separator: "\n"),
            statusHint: executionStatusHint(for: action, results: aggregatedResults),
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    private func runStep(
        _ descriptor: OpenClawCommandDescriptor,
        shouldShowBanner: Bool,
        environment: [String: String],
        stepHandler: (@Sendable (String) -> Void)? = nil,
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        let banner = shouldShowBanner ? "$ \(descriptor.renderedCommand)\n" : ""
        if shouldShowBanner {
            stepHandler?(descriptor.renderedCommand)
            outputHandler?(CommandOutputChunk(stream: .stdout, text: banner))
        }

        let result = await runner.run(
            command: descriptor.command,
            arguments: descriptor.arguments,
            environment: environment,
            outputHandler: outputHandler
        )

        guard !banner.isEmpty else { return result }
        return CommandResult(
            command: result.command,
            arguments: result.arguments,
            exitCode: result.exitCode,
            stdout: banner + result.stdout,
            stderr: result.stderr,
            launchError: result.launchError,
            startedAt: result.startedAt,
            finishedAt: result.finishedAt
        )
    }

    private func requiresGatewayInstall(after result: CommandResult) -> Bool {
        hasUnresolvedGatewayInstallInstruction(in: result)
    }

    private func executionStatusHint(
        for action: OpenClawControlAction,
        results: [CommandResult]
    ) -> CommandResultStatusHint? {
        guard let finalResult = results.last else {
            return nil
        }

        if finalResult.exitCode != 0 || finalResult.launchError != nil {
            return .failed
        }

        switch action {
        case .start, .restart:
            return hasUnresolvedGatewayInstallInstruction(in: finalResult) ? .failed : .success
        case .stop, .repair:
            return .success
        case .refresh, .openChat:
            return nil
        }
    }

    private func hasUnresolvedGatewayInstallInstruction(in result: CommandResult) -> Bool {
        let text = [result.stdout, result.stderr, result.launchError ?? ""]
            .joined(separator: "\n")
            .lowercased()

        return text.contains("gateway service not loaded")
            && text.contains("start with: openclaw gateway install")
    }
}
