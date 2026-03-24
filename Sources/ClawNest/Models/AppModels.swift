import Foundation

enum GatewayStatusLevel: String, CaseIterable, Sendable {
    case healthy
    case recovering
    case degraded
    case offline
    case missingCLI

    var label: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .recovering:
            return "Recovering"
        case .degraded:
            return "Needs Attention"
        case .offline:
            return "Offline"
        case .missingCLI:
            return "Setup Required"
        }
    }

    var iconName: String {
        switch self {
        case .healthy:
            return "checkmark.shield.fill"
        case .recovering:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .offline:
            return "bolt.horizontal.circle.fill"
        case .missingCLI:
            return "shippingbox.fill"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .healthy:
            return "bolt.circle.fill"
        case .recovering:
            return "bolt.badge.clock.fill"
        case .degraded:
            return "bolt.trianglebadge.exclamationmark.fill"
        case .offline:
            return "bolt.slash.circle.fill"
        case .missingCLI:
            return "questionmark.circle.fill"
        }
    }
}

struct StatusMetric: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.id = label
        self.label = label
        self.value = value
    }
}

enum RuntimeAction: String, CaseIterable, Identifiable, Sendable {
    case install
    case repair
    case start
    case restart
    case openDashboard
    case revealLogs
    case refreshStatus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .install:
            return "Install OpenClaw CLI"
        case .repair:
            return "Run Repair"
        case .start:
            return "Start OpenClaw"
        case .restart:
            return "Restart OpenClaw"
        case .openDashboard:
            return "Open Dashboard"
        case .revealLogs:
            return "Reveal Logs"
        case .refreshStatus:
            return "Refresh Status"
        }
    }

    var subtitle: String {
        switch self {
        case .install:
            return "Install or reuse the official OpenClaw CLI."
        case .repair:
            return "Run `openclaw doctor --repair --non-interactive`."
        case .start:
            return "Kick the current launchd job to bring the local runtime up."
        case .restart:
            return "Restart the local OpenClaw runtime through launchd."
        case .openDashboard:
            return "Open the dashboard surface in your browser."
        case .revealLogs:
            return "Open the latest local OpenClaw logs."
        case .refreshStatus:
            return "Probe the local runtime again and refresh the dashboard surface."
        }
    }

    var systemImage: String {
        switch self {
        case .install:
            return "square.and.arrow.down"
        case .repair:
            return "wrench.and.screwdriver"
        case .start:
            return "play.circle"
        case .restart:
            return "arrow.clockwise.circle"
        case .openDashboard:
            return "safari"
        case .revealLogs:
            return "text.page"
        case .refreshStatus:
            return "arrow.clockwise"
        }
    }

    var allowsConcurrentUse: Bool {
        switch self {
        case .openDashboard, .revealLogs:
            return true
        case .install, .repair, .start, .restart, .refreshStatus:
            return false
        }
    }
}

struct RuntimeActionModel: Equatable, Sendable {
    let actions: [RuntimeAction]

    var overlayActions: [RuntimeAction] {
        Array(actions.prefix(2))
    }
}

struct RuntimeActionResolver {
    func resolve(snapshot: GatewaySnapshot, cliInstalled: Bool) -> RuntimeActionModel {
        var actions: [RuntimeAction] = [.refreshStatus]

        switch snapshot.level {
        case .healthy:
            actions.append(contentsOf: [.openDashboard, .revealLogs, .restart])
        case .recovering:
            actions.append(contentsOf: [.openDashboard, .restart, .revealLogs])
        case .degraded:
            actions.append(contentsOf: [.repair, .restart, .openDashboard, .revealLogs])
        case .offline:
            actions.append(contentsOf: [.start, .repair, .revealLogs])
        case .missingCLI:
            if !cliInstalled {
                actions.insert(.install, at: 0)
            }
            actions.append(.revealLogs)
        }

        return RuntimeActionModel(actions: deduplicated(actions))
    }

    private func deduplicated(_ actions: [RuntimeAction]) -> [RuntimeAction] {
        var seen: Set<RuntimeAction> = []
        return actions.filter { seen.insert($0).inserted }
    }
}

struct LogSummary: Equatable, Sendable {
    let path: String
    let excerpt: String
}

struct GatewaySnapshot: Equatable, Sendable {
    var level: GatewayStatusLevel
    var headline: String
    var detail: String
    var lastCheck: Date
    var lastHealthy: Date?
    var dashboardURL: URL
    var metrics: [StatusMetric]
    var rawProbe: String
    var logSummary: LogSummary?

    static func placeholder(configuration: ClawNestConfiguration) -> GatewaySnapshot {
        GatewaySnapshot(
            level: .recovering,
            headline: "Waiting for the first health probe",
            detail: "ClawNest will probe the gateway as soon as the app boots.",
            lastCheck: .now,
            lastHealthy: nil,
            dashboardURL: configuration.dashboardURL,
            metrics: [
                StatusMetric("Dashboard", value: configuration.dashboardURL.absoluteString),
                StatusMetric("LaunchAgent", value: configuration.launchAgentLabel)
            ],
            rawProbe: "",
            logSummary: nil
        )
    }
}

struct ClawNestConfiguration: Equatable, Sendable {
    var openClawCommand: String
    var dashboardURLString: String
    var launchAgentLabel: String
    var probeIntervalSeconds: Double
    var autoRestartEnabled: Bool

    var dashboardURL: URL {
        URL(string: dashboardURLString) ?? URL(string: "http://127.0.0.1:18789/")!
    }

    static let standard = ClawNestConfiguration(
        openClawCommand: "openclaw",
        dashboardURLString: "http://127.0.0.1:18789/",
        launchAgentLabel: "ai.openclaw.gateway",
        probeIntervalSeconds: 45,
        autoRestartEnabled: false
    )
}

enum DiagnosticLevel: String, Sendable {
    case success
    case info
    case warning
    case error
}

struct DiagnosticEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: DiagnosticLevel
    let title: String
    let message: String
    let command: String?
}

struct MonitorResult: Sendable {
    let snapshot: GatewaySnapshot
    let entries: [DiagnosticEntry]
}

enum MonitorTrigger: Sendable {
    case manual
    case automaticPoll
    case postAction(RuntimeAction)

    var allowsAutoRecovery: Bool {
        switch self {
        case .automaticPoll:
            return true
        case .manual, .postAction:
            return false
        }
    }
}
