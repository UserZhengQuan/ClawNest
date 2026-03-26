import AppKit
import Foundation

@MainActor
protocol PathActionHandling {
    func copy(_ url: URL)
    func reveal(_ url: URL)
}

@MainActor
struct DefaultPathActionHandler: PathActionHandling {
    func copy(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    func reveal(_ url: URL) {
        guard let revealURL = closestExistingURL(to: url) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([revealURL])
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

    private let service: any OpenClawStatusServing
    private let pathActions: any PathActionHandling
    private var hasLoaded = false

    init(
        service: any OpenClawStatusServing = OpenClawStatusService(),
        pathActions: any PathActionHandling = DefaultPathActionHandler()
    ) {
        let defaults = OpenClawDefaults.standard()
        self.snapshot = .placeholder(defaults: defaults)
        self.service = service
        self.pathActions = pathActions
    }

    var lastCheckedText: String {
        guard let lastCheckedAt = snapshot.lastCheckedAt else {
            return "Not checked yet"
        }

        return lastCheckedAt.formatted(date: .abbreviated, time: .standard)
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await refresh()
    }

    func refreshNow() {
        Task {
            await refresh()
        }
    }

    func copy(_ url: URL) {
        pathActions.copy(url)
    }

    func reveal(_ url: URL) {
        pathActions.reveal(url)
    }

    private func refresh() async {
        isRefreshing = true
        snapshot = await service.refresh()
        isRefreshing = false
    }
}
