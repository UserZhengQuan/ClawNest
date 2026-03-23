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

enum RecoveryAction: String, CaseIterable, Identifiable, Sendable {
    case refresh
    case openDashboard
    case restartGateway
    case installLaunchAgent
    case repairConfiguration
    case revealLogs
    case openInstallGuide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .refresh:
            return "Refresh"
        case .openDashboard:
            return "Open Dashboard"
        case .restartGateway:
            return "Restart Gateway"
        case .installLaunchAgent:
            return "Install Agent"
        case .repairConfiguration:
            return "Run Repair"
        case .revealLogs:
            return "Reveal Logs"
        case .openInstallGuide:
            return "Install Guide"
        }
    }

    var subtitle: String {
        switch self {
        case .refresh:
            return "Probe the gateway again."
        case .openDashboard:
            return "Open the dashboard surface in your browser."
        case .restartGateway:
            return "Kick the launch agent without a terminal."
        case .installLaunchAgent:
            return "Install or refresh the per-user LaunchAgent."
        case .repairConfiguration:
            return "Run `openclaw doctor --repair`."
        case .revealLogs:
            return "Open the latest local OpenClaw logs."
        case .openInstallGuide:
            return "Open the official setup guide."
        }
    }

    var systemImage: String {
        switch self {
        case .refresh:
            return "arrow.clockwise"
        case .openDashboard:
            return "safari"
        case .restartGateway:
            return "bolt.badge.clock"
        case .installLaunchAgent:
            return "square.and.arrow.down"
        case .repairConfiguration:
            return "wrench.and.screwdriver"
        case .revealLogs:
            return "text.page"
        case .openInstallGuide:
            return "book.closed"
        }
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
    var suggestedActions: [RecoveryAction]

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
            logSummary: nil,
            suggestedActions: [.refresh, .openDashboard]
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
    case postAction(RecoveryAction)

    var allowsAutoRecovery: Bool {
        switch self {
        case .automaticPoll:
            return true
        case .manual, .postAction:
            return false
        }
    }
}
