import Foundation
import XCTest
@testable import ClawNest

final class ShellCommandResolverTests: XCTestCase {
    func testResolveReturnsAbsolutePathFromLoginShellLookup() async {
        let runner = ResolverCommandRunner(
            responses: [
                ["/bin/zsh", "-lc", "command -v 'openclaw'"]: CommandResult(
                    command: "/bin/zsh",
                    arguments: ["-lc", "command -v 'openclaw'"],
                    exitCode: 0,
                    stdout: "/opt/homebrew/bin/openclaw\n",
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let resolver = ShellCommandResolver(runner: runner)

        let resolved = await resolver.resolve("openclaw")

        XCTAssertEqual(resolved, "/opt/homebrew/bin/openclaw")
    }

    func testResolveFallsBackToInteractiveShellLookup() async {
        let runner = ResolverCommandRunner(
            responses: [
                ["/bin/zsh", "-lc", "command -v 'openclaw'"]: CommandResult(
                    command: "/bin/zsh",
                    arguments: ["-lc", "command -v 'openclaw'"],
                    exitCode: 1,
                    stdout: "",
                    stderr: "",
                    launchError: nil
                ),
                ["/bin/zsh", "-ic", "command -v 'openclaw'"]: CommandResult(
                    command: "/bin/zsh",
                    arguments: ["-ic", "command -v 'openclaw'"],
                    exitCode: 0,
                    stdout: "/Users/tester/.local/bin/openclaw\n",
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let resolver = ShellCommandResolver(runner: runner)

        let resolved = await resolver.resolve("openclaw")

        XCTAssertEqual(resolved, "/Users/tester/.local/bin/openclaw")
    }

    func testResolveCachesPreviousLookups() async {
        let runner = ResolverCommandRunner(
            responses: [
                ["/bin/zsh", "-lc", "command -v 'openclaw'"]: CommandResult(
                    command: "/bin/zsh",
                    arguments: ["-lc", "command -v 'openclaw'"],
                    exitCode: 0,
                    stdout: "/opt/homebrew/bin/openclaw\n",
                    stderr: "",
                    launchError: nil
                )
            ]
        )
        let resolver = ShellCommandResolver(runner: runner)

        _ = await resolver.resolve("openclaw")
        _ = await resolver.resolve("openclaw")

        let commands = await runner.recordedCommands()
        XCTAssertEqual(commands, ["/bin/zsh -lc command -v 'openclaw'"])
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
