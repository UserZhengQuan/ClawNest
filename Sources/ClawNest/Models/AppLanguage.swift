import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en_US"
        case .simplifiedChinese:
            return "zh-Hans_CN"
        }
    }
}

func localized(_ english: String, _ simplifiedChinese: String, language: AppLanguage) -> String {
    switch language {
    case .english:
        return english
    case .simplifiedChinese:
        return simplifiedChinese
    }
}

extension GatewayStatusLevel {
    func label(in language: AppLanguage) -> String {
        switch self {
        case .healthy:
            return localized("Healthy", "正常", language: language)
        case .recovering:
            return localized("Recovering", "恢复中", language: language)
        case .degraded:
            return localized("Needs Attention", "需要关注", language: language)
        case .offline:
            return localized("Offline", "离线", language: language)
        case .missingCLI:
            return localized("Setup Required", "需要安装", language: language)
        }
    }
}

extension RecoveryAction {
    func title(in language: AppLanguage) -> String {
        switch self {
        case .refresh:
            return localized("Refresh", "刷新", language: language)
        case .openDashboard:
            return localized("Open Dashboard", "打开面板", language: language)
        case .restartGateway:
            return localized("Restart Gateway", "重启网关", language: language)
        case .installLaunchAgent:
            return localized("Install Agent", "安装代理", language: language)
        case .repairConfiguration:
            return localized("Run Repair", "执行修复", language: language)
        case .revealLogs:
            return localized("Reveal Logs", "查看日志", language: language)
        case .openInstallGuide:
            return localized("Install Guide", "安装指南", language: language)
        }
    }

    func subtitle(in language: AppLanguage) -> String {
        switch self {
        case .refresh:
            return localized("Probe the gateway again.", "重新探测网关状态。", language: language)
        case .openDashboard:
            return localized("Open the dashboard surface in your browser.", "在浏览器中打开仪表盘。", language: language)
        case .restartGateway:
            return localized("Kick the launch agent without a terminal.", "无需终端即可重启 LaunchAgent。", language: language)
        case .installLaunchAgent:
            return localized("Install or refresh the per-user LaunchAgent.", "安装或刷新当前用户的 LaunchAgent。", language: language)
        case .repairConfiguration:
            return localized("Run `openclaw doctor --repair`.", "执行 `openclaw doctor --repair`。", language: language)
        case .revealLogs:
            return localized("Open the latest local OpenClaw logs.", "打开本地最新 OpenClaw 日志。", language: language)
        case .openInstallGuide:
            return localized("Open the official setup guide.", "打开官方安装指引。", language: language)
        }
    }
}

extension DiagnosticLevel {
    func momentLabel(in language: AppLanguage) -> String {
        switch self {
        case .success:
            return localized("Completed", "已完成", language: language)
        case .info:
            return localized("Update", "更新", language: language)
        case .warning:
            return localized("Heads Up", "提醒", language: language)
        case .error:
            return localized("Failed", "失败", language: language)
        }
    }
}
