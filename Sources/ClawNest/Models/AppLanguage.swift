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

extension RuntimeAction {
    func title(in language: AppLanguage) -> String {
        switch self {
        case .install:
            return localized("Install OpenClaw CLI", "安装 OpenClaw CLI", language: language)
        case .repair:
            return localized("Run Repair", "执行修复", language: language)
        case .start:
            return localized("Start OpenClaw", "启动 OpenClaw", language: language)
        case .restart:
            return localized("Restart OpenClaw", "重启 OpenClaw", language: language)
        case .openDashboard:
            return localized("Open Dashboard", "打开面板", language: language)
        case .revealLogs:
            return localized("Reveal Logs", "查看日志", language: language)
        case .refreshStatus:
            return localized("Refresh Status", "刷新状态", language: language)
        }
    }

    func subtitle(in language: AppLanguage) -> String {
        switch self {
        case .install:
            return localized("Install or reuse the official OpenClaw CLI.", "安装或复用官方 OpenClaw CLI。", language: language)
        case .repair:
            return localized("Run `openclaw doctor --repair --non-interactive`.", "执行 `openclaw doctor --repair --non-interactive`。", language: language)
        case .start:
            return localized("Kick the current launchd job to bring the local runtime up.", "通过当前 launchd 任务把本地 runtime 拉起。", language: language)
        case .restart:
            return localized("Restart the local OpenClaw runtime through launchd.", "通过 launchd 重启本地 OpenClaw runtime。", language: language)
        case .openDashboard:
            return localized("Open the dashboard surface in your browser.", "在浏览器中打开仪表盘。", language: language)
        case .revealLogs:
            return localized("Open the latest local OpenClaw logs.", "打开本地最新 OpenClaw 日志。", language: language)
        case .refreshStatus:
            return localized("Probe the local runtime again and refresh the dashboard surface.", "重新探测本地 runtime，并刷新 dashboard 界面。", language: language)
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
