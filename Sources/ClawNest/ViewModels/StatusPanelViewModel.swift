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
    private var hasLoaded = false
    private var pollTask: Task<Void, Never>?

    init(
        statusService: any OpenClawStatusServing = OpenClawStatusService(),
        actionService: any OpenClawControlActionServing = OpenClawControlActionService(),
        systemActions: any LocalSystemActionHandling = DefaultLocalSystemActionHandler(),
        pollIntervalSeconds: Double = 45
    ) {
        let defaults = OpenClawDefaults.standard()
        self.snapshot = .placeholder(defaults: defaults)
        self.statusService = statusService
        self.actionService = actionService
        self.systemActions = systemActions
        self.pollIntervalSeconds = pollIntervalSeconds
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

        await refresh()
    }
}
