import Foundation

protocol ConfigurationStoring {
    func load() -> ClawNestConfiguration
    func save(_ configuration: ClawNestConfiguration)
}

protocol LanguagePreferenceStoring {
    func load() -> AppLanguage
    func save(_ language: AppLanguage)
}

struct UserDefaultsConfigurationStore: ConfigurationStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ClawNestConfiguration {
        let fallback = ClawNestConfiguration.standard

        return ClawNestConfiguration(
            openClawCommand: stringValue(newKey: Keys.openClawCommand, legacyKey: LegacyKeys.openClawCommand) ?? fallback.openClawCommand,
            dashboardURLString: stringValue(newKey: Keys.dashboardURLString, legacyKey: LegacyKeys.dashboardURLString) ?? fallback.dashboardURLString,
            launchAgentLabel: stringValue(newKey: Keys.launchAgentLabel, legacyKey: LegacyKeys.launchAgentLabel) ?? fallback.launchAgentLabel,
            probeIntervalSeconds: doubleValue(newKey: Keys.probeIntervalSeconds, legacyKey: LegacyKeys.probeIntervalSeconds) ?? fallback.probeIntervalSeconds,
            autoRestartEnabled: boolValue(newKey: Keys.autoRestartEnabled, legacyKey: LegacyKeys.autoRestartEnabled) ?? fallback.autoRestartEnabled
        )
    }

    func save(_ configuration: ClawNestConfiguration) {
        defaults.set(configuration.openClawCommand, forKey: Keys.openClawCommand)
        defaults.set(configuration.dashboardURLString, forKey: Keys.dashboardURLString)
        defaults.set(configuration.launchAgentLabel, forKey: Keys.launchAgentLabel)
        defaults.set(configuration.probeIntervalSeconds, forKey: Keys.probeIntervalSeconds)
        defaults.set(configuration.autoRestartEnabled, forKey: Keys.autoRestartEnabled)
    }

    private func stringValue(newKey: String, legacyKey: String) -> String? {
        defaults.string(forKey: newKey) ?? defaults.string(forKey: legacyKey)
    }

    private func doubleValue(newKey: String, legacyKey: String) -> Double? {
        (defaults.object(forKey: newKey) as? Double) ?? (defaults.object(forKey: legacyKey) as? Double)
    }

    private func boolValue(newKey: String, legacyKey: String) -> Bool? {
        (defaults.object(forKey: newKey) as? Bool) ?? (defaults.object(forKey: legacyKey) as? Bool)
    }
}

struct UserDefaultsLanguagePreferenceStore: LanguagePreferenceStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppLanguage {
        guard let rawValue = defaults.string(forKey: Keys.appLanguage),
              let language = AppLanguage(rawValue: rawValue) else {
            return .english
        }

        return language
    }

    func save(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Keys.appLanguage)
    }
}

private enum Keys {
    static let openClawCommand = "clawnest.openClawCommand"
    static let dashboardURLString = "clawnest.dashboardURLString"
    static let launchAgentLabel = "clawnest.launchAgentLabel"
    static let probeIntervalSeconds = "clawnest.probeIntervalSeconds"
    static let autoRestartEnabled = "clawnest.autoRestartEnabled"
    static let appLanguage = "clawnest.appLanguage"
}

private enum LegacyKeys {
    static let openClawCommand = "clawdesk.openClawCommand"
    static let dashboardURLString = "clawdesk.dashboardURLString"
    static let launchAgentLabel = "clawdesk.launchAgentLabel"
    static let probeIntervalSeconds = "clawdesk.probeIntervalSeconds"
    static let autoRestartEnabled = "clawdesk.autoRestartEnabled"
}
