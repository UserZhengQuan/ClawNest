import Foundation
import XCTest
@testable import ClawNest

final class ShellCommandEnvironmentProviderTests: XCTestCase {
    func testExecutionEnvironmentMergesShellPathsAndCurrentPath() async {
        let shell = UserShell(executablePath: "/bin/zsh")
        let request = ShellProbeScript.pathProbe()
        let runner = EnvironmentProviderRunner(
            responses: [
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactiveLogin): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactiveLogin),
                    exitCode: 0,
                    stdout: """
                    banner
                    \(request.startMarker)
                    /opt/homebrew/bin:/usr/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .login): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .login),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /Users/tester/.local/bin:/usr/bin:/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactive): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactive),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /Users/tester/.nvm/versions/node/bin:/opt/homebrew/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .plain): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .plain),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /usr/bin:/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let provider = ShellCommandEnvironmentProvider(
            runner: runner,
            shellProvider: StubEnvironmentShellProvider(shell: shell),
            currentEnvironment: ["PATH": "/usr/bin:/bin:/usr/sbin"]
        )

        let environment = await provider.executionEnvironment()

        XCTAssertEqual(
            environment["PATH"],
            "/opt/homebrew/bin:/usr/bin:/Users/tester/.local/bin:/bin:/Users/tester/.nvm/versions/node/bin:/usr/sbin"
        )
    }

    func testExecutionEnvironmentCachesResolvedPath() async {
        let shell = UserShell(executablePath: "/bin/zsh")
        let request = ShellProbeScript.pathProbe()
        let runner = EnvironmentProviderRunner(
            responses: [
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactiveLogin): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactiveLogin),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /opt/homebrew/bin:/usr/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .login): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .login),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /usr/local/bin:/usr/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactive): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactive),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /Users/tester/.nvm/bin:/usr/local/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .plain): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .plain),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /usr/bin:/bin
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let provider = ShellCommandEnvironmentProvider(
            runner: runner,
            shellProvider: StubEnvironmentShellProvider(shell: shell)
        )

        _ = await provider.executionEnvironment()
        _ = await provider.executionEnvironment()

        let commands = await runner.recordedCommands()
        let interactiveLoginCommand = ([shell.executablePath] + shell.arguments(for: request.script, mode: .interactiveLogin))
            .joined(separator: " ")
        let loginCommand = ([shell.executablePath] + shell.arguments(for: request.script, mode: .login))
            .joined(separator: " ")
        let interactiveCommand = ([shell.executablePath] + shell.arguments(for: request.script, mode: .interactive))
            .joined(separator: " ")
        let plainCommand = ([shell.executablePath] + shell.arguments(for: request.script, mode: .plain))
            .joined(separator: " ")
        let expectedCommands = [
            interactiveLoginCommand,
            loginCommand,
            interactiveCommand,
            plainCommand
        ]
        XCTAssertEqual(commands, expectedCommands)
    }
}

private actor EnvironmentProviderRunner: CommandRunning {
    private let responses: [[String]: CommandResult]
    private var commands: [String] = []

    init(responses: [[String]: CommandResult]) {
        self.responses = responses
    }

    func run(
        command: String,
        arguments: [String],
        environment: [String : String],
        outputHandler: (@Sendable (CommandOutputChunk) -> Void)?
    ) async -> CommandResult {
        let key = [command] + arguments
        commands.append(key.joined(separator: " "))
        return responses[key] ?? CommandResult(
            command: command,
            arguments: arguments,
            exitCode: 1,
            stdout: "",
            stderr: "not mocked",
            launchError: nil
        )
    }

    func recordedCommands() -> [String] {
        commands
    }
}

private struct StubEnvironmentShellProvider: UserShellProviding {
    let shell: UserShell

    func currentShell() -> UserShell {
        shell
    }
}
