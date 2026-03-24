import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: GatewaySnapshot
    @Published private(set) var diagnostics: [DiagnosticEntry] = []
    @Published var configuration: ClawNestConfiguration
    @Published var language: AppLanguage
    @Published var installSnapshot: OpenClawInstallerSnapshot
    @Published var installProgress: OpenClawInstallProgress
    @Published var installStatusMessage: String?
    @Published var isInstallingOpenClaw = false
    @Published var dashboardWebError: String?
    @Published var isDashboardLoading = true
    @Published var dashboardReloadToken = UUID()
    @Published var isBusy = false

    private let configurationStore: ConfigurationStoring
    private let languageStore: LanguagePreferenceStoring
    private let supervisor: GatewaySupervisor
    private let actionResolver = RuntimeActionResolver()
    let openClawInstaller: OpenClawInstaller
    private var pollTask: Task<Void, Never>?

    init(
        configurationStore: ConfigurationStoring = UserDefaultsConfigurationStore(),
        languageStore: LanguagePreferenceStoring = UserDefaultsLanguagePreferenceStore(),
        runner: CommandRunning = ProcessCommandRunner(),
        logInspector: LogInspector = LogInspector()
    ) {
        let configuration = configurationStore.load()
        let language = languageStore.load()
        self.configurationStore = configurationStore
        self.languageStore = languageStore
        self.configuration = configuration
        self.language = language
        self.installSnapshot = OpenClawInstallerSnapshot(
            resolvedCommandPath: nil,
            message: "Checking whether OpenClaw CLI is available on this Mac.",
            nextStep: "If it is missing, install it here and continue with the official onboarding flow."
        )
        self.installProgress = .idle
        self.snapshot = .placeholder(configuration: configuration)
        self.supervisor = GatewaySupervisor(
            configuration: configuration,
            runner: runner,
            logInspector: logInspector
        )
        self.openClawInstaller = OpenClawInstaller(runner: runner)

        appendDiagnostic(
            DiagnosticEntry(
                timestamp: .now,
                level: .info,
                title: "ClawNest booted",
                message: "Native monitoring is ready in observe-only mode. The first probe is running now.",
                command: nil
            )
        )

        Task {
            await refresh(trigger: .manual)
            restartPolling()
            await refreshInstallSnapshot()
        }
    }

    deinit {
        pollTask?.cancel()
    }

    var runtimeActions: [RuntimeAction] {
        actionResolver.resolve(snapshot: snapshot, cliInstalled: installSnapshot.isInstalled).actions
    }

    var overlayRuntimeActions: [RuntimeAction] {
        actionResolver.resolve(snapshot: snapshot, cliInstalled: installSnapshot.isInstalled).overlayActions
    }

    var isPerformingMutation: Bool {
        isBusy || isInstallingOpenClaw
    }

    func isActionEnabled(_ action: RuntimeAction) -> Bool {
        !isPerformingMutation || action.allowsConcurrentUse
    }

    func refreshNow() {
        Task {
            await refresh(trigger: .manual)
            await refreshInstallSnapshot()
        }
    }

    func perform(_ action: RuntimeAction) {
        switch action {
        case .install:
            installOpenClaw()
        case .refreshStatus:
            if dashboardWebError != nil || isDashboardLoading {
                reloadDashboard()
            }
            refreshNow()
        case .openDashboard:
            NSWorkspace.shared.open(snapshot.dashboardURL)
            reloadDashboard()
        case .revealLogs:
            revealLogs()
        case .start, .restart, .repair:
            Task {
                isBusy = true
                defer { isBusy = false }

                let result = await supervisor.run(action: action)
                apply(result)
                await refreshInstallSnapshot()
            }
        }
    }

    func saveConfiguration(_ configuration: ClawNestConfiguration) {
        self.configuration = configuration
        configurationStore.save(configuration)
        appendDiagnostic(
            DiagnosticEntry(
                timestamp: .now,
                level: .info,
                title: "Configuration updated",
                message: "ClawNest will use the new command, dashboard URL, and LaunchAgent label on the next probe.",
                command: nil
            )
        )

        Task {
            await supervisor.updateConfiguration(configuration)
            await refresh(trigger: .manual)
            restartPolling()
            await refreshInstallSnapshot()
        }
    }

    func updateLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }

        self.language = language
        languageStore.save(language)
        appendDiagnostic(
            DiagnosticEntry(
                timestamp: .now,
                level: .info,
                title: "Language updated",
                message: "ClawNest UI language changed to \(language.displayName).",
                command: nil
            )
        )
    }

    func reloadDashboard() {
        dashboardReloadToken = UUID()
        dashboardWebError = nil
        isDashboardLoading = true
    }

    func dashboardDidStartLoading() {
        isDashboardLoading = true
    }

    func dashboardDidBecomeReady() {
        let hadError = dashboardWebError != nil
        dashboardWebError = nil
        isDashboardLoading = false

        if hadError {
            appendDiagnostic(
                DiagnosticEntry(
                    timestamp: .now,
                    level: .success,
                    title: "Dashboard reconnected",
                    message: "The embedded dashboard surface is responding again.",
                    command: nil
                )
            )
        }
    }

    func dashboardDidFail(_ description: String) {
        guard dashboardWebError != description else { return }
        dashboardWebError = description
        isDashboardLoading = false
        appendDiagnostic(
            DiagnosticEntry(
                timestamp: .now,
                level: .warning,
                title: "Dashboard surface failed",
                message: description,
                command: nil
            )
        )
    }

    func refresh(trigger: MonitorTrigger) async {
        let result = await supervisor.refresh(trigger: trigger)
        apply(result)
    }

    private func apply(_ result: MonitorResult) {
        snapshot = result.snapshot
        result.entries.forEach(appendDiagnostic)

        if result.snapshot.level == .healthy && dashboardWebError == nil {
            isDashboardLoading = false
        }
    }

    func appendDiagnostic(_ entry: DiagnosticEntry) {
        diagnostics.insert(entry, at: 0)
        if diagnostics.count > 60 {
            diagnostics = Array(diagnostics.prefix(60))
        }
    }

    private func restartPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }

            let interval = max(15, self.configuration.probeIntervalSeconds)
            try? await Task.sleep(for: .seconds(interval))

            while !Task.isCancelled {
                await self.refresh(trigger: .automaticPoll)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    private func revealLogs() {
        let logsURL = URL(fileURLWithPath: "/tmp/openclaw", isDirectory: true)
        if FileManager.default.fileExists(atPath: logsURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([logsURL])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp", isDirectory: true))
        }
    }
}
