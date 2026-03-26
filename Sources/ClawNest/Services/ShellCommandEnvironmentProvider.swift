import Foundation

protocol CommandEnvironmentProviding: Sendable {
    func executionEnvironment() async -> [String: String]
}

actor ShellCommandEnvironmentProvider: CommandEnvironmentProviding {
    private let runner: CommandRunning
    private let shellProvider: any UserShellProviding
    private let currentEnvironment: [String: String]
    private var cachedEnvironment: [String: String]?

    init(
        runner: CommandRunning = ProcessCommandRunner(),
        shellProvider: any UserShellProviding = SystemUserShellProvider(),
        currentEnvironment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.runner = runner
        self.shellProvider = shellProvider
        self.currentEnvironment = currentEnvironment
    }

    func executionEnvironment() async -> [String: String] {
        if let cachedEnvironment {
            return cachedEnvironment
        }

        let shell = shellProvider.currentShell()
        var pathCandidates: [String?] = []
        pathCandidates.reserveCapacity(ShellInvocationMode.allCases.count + 1)

        for mode in ShellInvocationMode.allCases {
            pathCandidates.append(await resolvePath(shell: shell, mode: mode))
        }

        pathCandidates.append(currentEnvironment["PATH"])
        let mergedPath = mergedPath(from: pathCandidates)

        let environment: [String: String]
        if let mergedPath, !mergedPath.isEmpty {
            environment = ["PATH": mergedPath]
        } else {
            environment = [:]
        }

        cachedEnvironment = environment
        return environment
    }

    private func resolvePath(shell: UserShell, mode: ShellInvocationMode) async -> String? {
        let request = ShellProbeScript.pathProbe()
        let result = await runner.run(
            command: shell.executablePath,
            arguments: shell.arguments(for: request.script, mode: mode)
        )

        let path = ShellProbeScript.extractPayload(
            from: result.stdout,
            startMarker: request.startMarker,
            endMarker: request.endMarker
        ) ?? fallbackPath(from: result.stdout)

        guard let path else { return nil }
        return path.isEmpty ? nil : path
    }

    private func mergedPath(from values: [String?]) -> String? {
        var seen: Set<String> = []
        var orderedComponents: [String] = []

        for value in values {
            guard let value else { continue }

            for component in value.split(separator: ":").map(String.init) where !component.isEmpty {
                if seen.insert(component).inserted {
                    orderedComponents.append(component)
                }
            }
        }

        return orderedComponents.isEmpty ? nil : orderedComponents.joined(separator: ":")
    }

    private func fallbackPath(from stdout: String) -> String? {
        stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { line in
                !line.isEmpty && (line.contains(":") || line.contains("/"))
            }
    }
}
