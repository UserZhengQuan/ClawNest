import Foundation
import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case chat
    case claws
    case moments
    case mine

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .chat:
            return localized("Chat", "聊天", language: language)
        case .claws:
            return localized("Claws", "Claws", language: language)
        case .moments:
            return localized("Moments", "动态", language: language)
        case .mine:
            return localized("Mine", "我的", language: language)
        }
    }

    func subtitle(in language: AppLanguage) -> String {
        switch self {
        case .chat:
            return localized("Threads and agents", "线程与 agents", language: language)
        case .claws:
            return localized("Instances and controls", "实例与控制", language: language)
        case .moments:
            return localized("Timeline and stories", "时间流与动态", language: language)
        case .mine:
            return localized("Profile and preferences", "资料与偏好", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .chat:
            return "message.badge.waveform"
        case .claws:
            return "square.grid.2x2.fill"
        case .moments:
            return "sparkles.tv"
        case .mine:
            return "person.crop.circle.fill"
        }
    }

    var sidebarTint: Color {
        switch self {
        case .chat:
            return Color(red: 0.33, green: 0.60, blue: 0.86)
        case .claws:
            return Color(red: 0.84, green: 0.58, blue: 0.33)
        case .moments:
            return Color(red: 0.35, green: 0.67, blue: 0.52)
        case .mine:
            return Color(red: 0.44, green: 0.50, blue: 0.62)
        }
    }
}

struct ClawPalette {
    let primary: Color
    let secondary: Color

    static let defaults: [ClawPalette] = [
        ClawPalette(primary: Color(red: 0.98, green: 0.66, blue: 0.38), secondary: Color(red: 0.91, green: 0.38, blue: 0.33)),
        ClawPalette(primary: Color(red: 0.38, green: 0.78, blue: 0.84), secondary: Color(red: 0.16, green: 0.46, blue: 0.82)),
        ClawPalette(primary: Color(red: 0.77, green: 0.53, blue: 0.96), secondary: Color(red: 0.42, green: 0.30, blue: 0.82)),
        ClawPalette(primary: Color(red: 0.57, green: 0.89, blue: 0.46), secondary: Color(red: 0.18, green: 0.63, blue: 0.35))
    ]
}

struct ClawSummary: Identifiable {
    let id: String
    let name: String
    let avatarText: String
    let machineLabel: String
    let statusLabel: String
    let statusDescription: String
    let statusColor: Color
    let healthLabel: String
    let installDirectoryPath: String
    let launchAgentLabel: String
    let dashboardURLString: String
    let reservedPorts: [Int]
    let lastActiveAt: Date
    let isCurrent: Bool
    let isOnline: Bool
    let canStart: Bool
    let alertBadge: ClawAlertBadge?
    let primaryColor: Color
    let secondaryColor: Color
    let agents: [ClawAgentSummary]

    var portSummary: String {
        reservedPorts.sorted().map(String.init).joined(separator: ", ")
    }
}

struct ClawAlertBadge {
    let label: String
    let systemImage: String
    let tint: Color
}

struct ClawAgentSummary: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let status: String
    let actions: [AgentActionSummary]
}

struct AgentActionSummary: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let recoveryAction: RecoveryAction?
}

enum ChatThreadKind {
    case liveDashboard
    case caretaker
    case installer
    case placeholder
}

struct ChatThreadSummary: Identifiable {
    let id: String
    let title: String
    let preview: String
    let description: String
    let clawName: String
    let clawAvatar: String
    let agentName: String
    let machineLabel: String
    let timestampText: String
    let primaryColor: Color
    let secondaryColor: Color
    let kind: ChatThreadKind
}

struct MomentFeedItem: Identifiable {
    let id = UUID()
    let clawID: String
    let clawName: String
    let clawAvatar: String
    let primaryColor: Color
    let secondaryColor: Color
    let kindLabel: String
    let iconName: String
    let headline: String
    let body: String
    let timestamp: Date
    let command: String?
}

struct WorkspaceMomentFilter: Identifiable {
    static let allID = "all"

    let id: String
    let title: String
    let color: Color
}

enum ClawDetailSection: String, CaseIterable, Identifiable {
    case overview
    case agents
    case recentMoments
    case tasks
    case logs
    case settings

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .overview:
            return localized("Overview", "概览", language: language)
        case .agents:
            return localized("Agents", "Agents", language: language)
        case .recentMoments:
            return localized("Recent Moments", "最近动态", language: language)
        case .tasks:
            return localized("Tasks", "任务", language: language)
        case .logs:
            return localized("Logs", "日志", language: language)
        case .settings:
            return localized("Settings", "设置", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "square.grid.2x2.fill"
        case .agents:
            return "person.2.fill"
        case .recentMoments:
            return "sparkles.tv"
        case .tasks:
            return "checklist"
        case .logs:
            return "text.page.fill"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

struct ClawTaskSummary: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let statusLabel: String
    let systemImage: String
    let tint: Color
    let timestamp: Date
}

extension GatewayStatusLevel {
    var tintColor: Color {
        switch self {
        case .healthy:
            return Color(red: 0.29, green: 0.88, blue: 0.53)
        case .recovering:
            return Color(red: 0.34, green: 0.73, blue: 0.94)
        case .degraded:
            return Color(red: 0.95, green: 0.72, blue: 0.38)
        case .offline, .missingCLI:
            return Color(red: 0.92, green: 0.39, blue: 0.38)
        }
    }
}

extension DiagnosticLevel {
    var momentIcon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "sparkles"
        case .warning:
            return "exclamationmark.bubble.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}
