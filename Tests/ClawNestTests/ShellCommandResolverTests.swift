import Foundation
import XCTest
@testable import ClawNest

final class ShellCommandResolverTests: XCTestCase {
    func testResolveReturnsAbsolutePathFromInteractiveLoginShellLookup() async {
        let shell = UserShell(executablePath: "/bin/zsh")
        let request = ShellProbeScript.commandLookup("openclaw")
        let runner = ResolverCommandRunner(
            responses: [
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactiveLogin): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactiveLogin),
                    exitCode: 0,
                    stdout: """
                    shell noise
                    \(request.startMarker)
                    /opt/homebrew/bin/openclaw
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let resolver = ShellCommandResolver(
            runner: runner,
            shellProvider: StubUserShellProvider(shell: shell)
        )

        let resolved = await resolver.resolve("openclaw")

        XCTAssertEqual(resolved, "/opt/homebrew/bin/openclaw")
    }

    func testResolveFallsBackToInteractiveShellLookup() async {
        let shell = UserShell(executablePath: "/bin/zsh")
        let request = ShellProbeScript.commandLookup("openclaw")
        let runner = ResolverCommandRunner(
            responses: [
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactiveLogin): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactiveLogin),
                    exitCode: 1,
                    stdout: "",
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .login): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .login),
                    exitCode: 1,
                    stdout: "",
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactive): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactive),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /Users/tester/.local/bin/openclaw
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let resolver = ShellCommandResolver(
            runner: runner,
            shellProvider: StubUserShellProvider(shell: shell)
        )

        let resolved = await resolver.resolve("openclaw")

        XCTAssertEqual(resolved, "/Users/tester/.local/bin/openclaw")
    }

    func testResolveCachesPreviousLookups() async {
        let shell = UserShell(executablePath: "/bin/zsh")
        let request = ShellProbeScript.commandLookup("openclaw")
        let runner = ResolverCommandRunner(
            responses: [
                ["/bin/zsh"] + shell.arguments(for: request.script, mode: .interactiveLogin): CommandResult(
                    command: "/bin/zsh",
                    arguments: shell.arguments(for: request.script, mode: .interactiveLogin),
                    exitCode: 0,
                    stdout: """
                    \(request.startMarker)
                    /opt/homebrew/bin/openclaw
                    \(request.endMarker)
                    """,
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let resolver = ShellCommandResolver(
            runner: runner,
            shellProvider: StubUserShellProvider(shell: shell)
        )

        _ = await resolver.resolve("openclaw")
        _ = await resolver.resolve("openclaw")

        let commands = await runner.recordedCommands()
        let expectedCommand = ([shell.executablePath] + shell.arguments(for: request.script, mode: .interactiveLogin))
            .joined(separator: " ")
        XCTAssertEqual(commands, [expectedCommand])
    }
}

private actor ResolverCommandRunner: CommandRunning {
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
            exitCode: 127,
            stdout: "",
            stderr: "command not mocked",
            launchError: nil
        )
    }

    func recordedCommands() -> [String] {
        commands
    }
}

private struct StubUserShellProvider: UserShellProviding {
    let shell: UserShell

    func currentShell() -> UserShell {
        shell
    }
}
