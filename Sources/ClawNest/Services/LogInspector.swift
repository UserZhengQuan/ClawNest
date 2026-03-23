import Foundation

struct LogInspector: Sendable {
    let directoryURL: URL

    init(directoryURL: URL = URL(fileURLWithPath: "/tmp/openclaw", isDirectory: true)) {
        self.directoryURL = directoryURL
    }

    func latestSummary(maxLines: Int = 40) -> LogSummary? {
        let manager = FileManager.default

        guard let files = try? manager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let logFiles = files.filter { $0.pathExtension == "log" || $0.lastPathComponent.contains("openclaw") }
        let sorted = logFiles.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        guard let latest = sorted.first,
              let text = try? String(contentsOf: latest, encoding: .utf8)
        else {
            return nil
        }

        let lines = text.split(whereSeparator: \.isNewline).suffix(maxLines).joined(separator: "\n")
        return LogSummary(path: latest.path, excerpt: lines)
    }
}
