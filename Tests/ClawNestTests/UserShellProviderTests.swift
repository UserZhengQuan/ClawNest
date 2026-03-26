import XCTest
@testable import ClawNest

final class UserShellProviderTests: XCTestCase {
    func testCurrentShellPrefersEnvironmentShellWhenExecutable() {
        let provider = SystemUserShellProvider(
            environment: ["SHELL": "/opt/homebrew/bin/fish"],
            fallbackShellPath: "/bin/zsh",
            preferredShellPath: { "/bin/bash" },
            isExecutableFile: { path in
                path == "/opt/homebrew/bin/fish" || path == "/bin/bash"
            }
        )

        XCTAssertEqual(provider.currentShell(), UserShell(executablePath: "/opt/homebrew/bin/fish"))
    }

    func testCurrentShellFallsBackToPasswordDatabaseShell() {
        let provider = SystemUserShellProvider(
            environment: [:],
            fallbackShellPath: "/bin/zsh",
            preferredShellPath: { "/bin/bash" },
            isExecutableFile: { path in
                path == "/bin/bash"
            }
        )

        XCTAssertEqual(provider.currentShell(), UserShell(executablePath: "/bin/bash"))
    }

    func testCurrentShellFallsBackToDefaultWhenNoCandidateIsExecutable() {
        let provider = SystemUserShellProvider(
            environment: ["SHELL": "/missing/fish"],
            fallbackShellPath: "/bin/zsh",
            preferredShellPath: { "/missing/bash" },
            isExecutableFile: { _ in false }
        )

        XCTAssertEqual(provider.currentShell(), UserShell(executablePath: "/bin/zsh"))
    }
}
