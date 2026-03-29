import AppKit
import Foundation

@MainActor
protocol LocalSystemActionHandling {
    func copy(_ url: URL)
    func reveal(_ url: URL)
    func open(_ url: URL) -> Bool
}

@MainActor
struct DefaultLocalSystemActionHandler: LocalSystemActionHandling {
    func copy(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    func reveal(_ url: URL) {
        guard let revealURL = closestExistingURL(to: url) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([revealURL])
    }

    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    private func closestExistingURL(to url: URL) -> URL? {
        var candidate = url
        let fileManager = FileManager.default

        while !fileManager.fileExists(atPath: candidate.path) {
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                return nil
            }
            candidate = parent
        }

        return candidate
    }
}

@MainActor
final class StatusPanelViewModel: ObservableObject {
    @Published private(set) var snapshot: OpenClawStatusSnapshot
    @Published private(set) var isRefreshing = false
    @Published private(set) var commandOutput: CommandExecutionRecord?
    @Published private(set) var actionNote: String?

    private let statusService: any OpenClawStatusServing
    private let actionService: any OpenClawControlActionServing
    private let systemActions: any LocalSystemActionHandling
    private let pollIntervalSeconds: Double
    private let startOrRestartMaxAttempts: Int
    private let startOrRestartIntervalMilliseconds: UInt64
    private let stopMaxAttempts: Int
    private let stopIntervalMilliseconds: UInt64
    private var hasLoaded = false
    private var pollTask: Task<Void, Never>?

    init(
        statusService: any OpenClawStatusServing = OpenClawStatusService(),
        actionService: any OpenClawControlActionServing = OpenClawControlActionService(),
        systemActions: any LocalSystemActionHandling = DefaultLocalSystemActionHandler(),
        pollIntervalSeconds: Double = 45,
        startOrRestartMaxAttempts: Int = 20,
        startOrRestartIntervalMilliseconds: UInt64 = 1_000,
        stopMaxAttempts: Int = 12,
        stopIntervalMilliseconds: UInt64 = 500
    ) {
        let defaults = OpenClawDefaults.standard()
        self.snapshot = .placeholder(defaults: defaults)
        self.statusService = statusService
        self.actionService = actionService
        self.systemActions = systemActions
        self.pollIntervalSeconds = pollIntervalSeconds
        self.startOrRestartMaxAttempts = startOrRestartMaxAttempts
        self.startOrRestartIntervalMilliseconds = startOrRestartIntervalMilliseconds
        self.stopMaxAttempts = stopMaxAttempts
        self.stopIntervalMilliseconds = stopIntervalMilliseconds
    }

    deinit {
        pollTask?.cancel()
    }

    var lastCheckedText: String {
        guard let lastCheckedAt = snapshot.lastCheckedAt else {
            return "Not checked yet"
        }

        return lastCheckedAt.formatted(date: .abbreviated, time: .standard)
    }

    var isCommandRunning: Bool {
        commandOutput?.status == .running
    }

    var menuBarIndicatorState: MenuBarIndicatorState {
        snapshot.menuBarIndicatorState
    }

    var rootPathText: String {
        snapshot.rootPath?.path ?? OpenClawDefaults.standard().paths[0].url.path
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
        startPolling()
    }

    func refreshNow() {
        Task {
            await refresh()
        }
    }

    func copy(_ url: URL) {
        systemActions.copy(url)
    }

    func reveal(_ url: URL) {
        systemActions.reveal(url)
    }

    func perform(_ action: OpenClawControlAction) {
        switch action {
        case .refresh:
            actionNote = nil
            refreshNow()
        case .openChat:
            openChat()
        case .start, .restart, .stop, .repair:
            guard !isCommandRunning else { return }
            actionNote = nil
            Task {
                await runCommandAction(action)
            }
        }
    }

    func commandPreview(for action: OpenClawControlAction) -> String? {
        actionService.descriptor(for: action)?.renderedCommand
    }

    func isRunning(action: OpenClawControlAction) -> Bool {
        commandOutput?.action == action && commandOutput?.status == .running
    }

    private func refresh() async {
        isRefreshing = true
        snapshot = await statusService.refresh()
        isRefreshing = false
    }

    private func startPolling() {
        pollTask?.cancel()
        let interval = max(15, pollIntervalSeconds)

        pollTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }

                if self.isCommandRunning {
                    continue
                }

                await self.refresh()
            }
        }
    }

    private func openChat() {
        let gatewayURL = snapshot.gateway.url
        let didOpen = systemActions.open(gatewayURL)

        if !didOpen {
            actionNote = "Could not open the default gateway URL."
            return
        }

        if snapshot.runtimeStatus != .running {
            actionNote = "OpenClaw is not confirmed running. Opening the default gateway URL anyway."
        } else {
            actionNote = nil
        }
    }

    private func runCommandAction(_ action: OpenClawControlAction) async {
        guard let stream = actionService.execute(action) else { return }

        for await event in stream {
            switch event {
            case let .started(command, startedAt):
                commandOutput = .running(action: action, command: command, startedAt: startedAt)
            case let .stepStarted(command):
                guard let current = commandOutput,
                      current.action == action,
                      current.status == .running else {
                    continue
                }
                commandOutput = current.appendingCommand(command)
            case let .output(chunk):
                guard let current = commandOutput,
                      current.action == action,
                      current.status == .running else {
                    continue
                }
                commandOutput = current.appending(chunk)
            case let .finished(result):
                commandOutput = .finished(action: action, result: result)
            }
        }

        await refreshAfterCommand(action)
        await reconcileCommandOutcome(after: action)
    }

    private func refreshAfterCommand(_ action: OpenClawControlAction) async {
        switch action {
        case .start, .restart:
            await refreshUntil(
                maxAttempts: startOrRestartMaxAttempts,
                intervalMilliseconds: startOrRestartIntervalMilliseconds
            ) { $0 == .running }
        case .stop:
            await refreshUntil(
                maxAttempts: stopMaxAttempts,
                intervalMilliseconds: stopIntervalMilliseconds
            ) { $0 != .running }
        case .refresh, .openChat, .repair:
            await refresh()
        }
    }

    private func refreshUntil(
        maxAttempts: Int,
        intervalMilliseconds: UInt64,
        _ isSatisfied: (OpenClawRuntimeStatus) -> Bool
    ) async {
        for attempt in 0 ..< maxAttempts {
            await refresh()
            if isSatisfied(snapshot.runtimeStatus) {
                return
            }

            guard attempt < maxAttempts - 1 else { return }
            try? await Task.sleep(for: .milliseconds(intervalMilliseconds))
        }
    }

    private func reconcileCommandOutcome(after action: OpenClawControlAction) async {
        guard let commandOutput else { return }

        switch action {
        case .start, .restart:
            if snapshot.runtimeStatus == .running {
                self.commandOutput = commandOutput.overridingStatus(.success)
            } else if commandOutput.status == .success {
                let diagnostic = await statusService.diagnosticStatus()
                self.commandOutput = commandOutput
                    .appendingOutput(
                        stdout: renderedDiagnosticStdout(from: diagnostic),
                        stderr: renderedDiagnosticStderr(from: diagnostic)
                    )
                    .overridingStatus(
                        .failed,
                        appendingStderr: "OpenClaw did not report Running within the startup window."
                    )
            } else {
                let diagnostic = await statusService.diagnosticStatus()
                self.commandOutput = commandOutput
                    .appendingOutput(
                        stdout: renderedDiagnosticStdout(from: diagnostic),
                        stderr: renderedDiagnosticStderr(from: diagnostic)
                    )
                    .overridingStatus(
                        .failed,
                        appendingStderr: "OpenClaw did not report Running within the startup window."
                    )
            }
        case .stop:
            guard snapshot.runtimeStatus == .running else { return }
            self.commandOutput = commandOutput.overridingStatus(
                .failed,
                appendingStderr: "OpenClaw still reported Running after the stop command completed."
            )
        case .refresh, .openChat, .repair:
            break
        }
    }

    private func renderedDiagnosticStdout(from result: CommandResult) -> String {
        var sections: [String] = []
        sections.append("\n$ \(result.renderedCommand)\n")

        let trimmedStdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStdout.isEmpty {
            sections.append(trimmedStdout + "\n")
        }

        return sections.joined()
    }

    private func renderedDiagnosticStderr(from result: CommandResult) -> String {
        let errorText = [result.stderr, result.launchError ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !errorText.isEmpty else {
            return ""
        }

        return "\n" + errorText + "\n"
    }
}
