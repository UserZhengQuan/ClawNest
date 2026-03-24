import Foundation
import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case claw

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        localized("Claw", "Claw", language: language)
    }

    func subtitle(in language: AppLanguage) -> String {
        localized("Local OpenClaw workbench", "本地 OpenClaw 工作台", language: language)
    }

    var systemImage: String {
        "pawprint.fill"
    }

    var sidebarTint: Color {
        Color(red: 0.84, green: 0.58, blue: 0.33)
    }
}

enum ClawWorkbenchSection: String, CaseIterable, Identifiable {
    case overview
    case dashboard
    case logs
    case settings

    var id: String { rawValue }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .overview:
            return localized("Overview", "概览", language: language)
        case .dashboard:
            return localized("Dashboard", "面板", language: language)
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
        case .dashboard:
            return "safari.fill"
        case .logs:
            return "text.page.fill"
        case .settings:
            return "slider.horizontal.3"
        }
    }
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
