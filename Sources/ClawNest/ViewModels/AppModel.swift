import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: GatewaySnapshot
    @Published private(set) var diagnostics: [DiagnosticEntry] = []
    @Published var configuration: ClawNestConfiguration
    @Published var language: AppLanguage
    @Published var installDraft: OpenClawInstallDraft
    @Published private(set) var installValidation: OpenClawInstallValidation
    @Published private(set) var knownOpenClawInstances: [InstalledOpenClawInstance] = []
    @Published var installStatusMessage: String?
    @Published var isInstallingOpenClaw = false
    @Published var dashboardWebError: String?
    @Published var isDashboardLoading = true
    @Published var dashboardReloadToken = UUID()
    @Published var isBusy = false

    private let configurationStore: ConfigurationStoring
    private let languageStore: LanguagePreferenceStoring
    private let supervisor: GatewaySupervisor
    private let openClawInstaller: OpenClawInstaller
    private var pollTask: Task<Void, Never>?

    init(
        configurationStore: ConfigurationStoring = UserDefaultsConfigurationStore(),
        languageStore: LanguagePreferenceStoring = UserDefaultsLanguagePreferenceStore(),
        runner: CommandRunning = ProcessCommandRunner(),
        logInspector: LogInspector = LogInspector()
    ) {
        let configuration = configurationStore.load()
        let language = languageStore.load()
        let installDraft = OpenClawInstallDraft.suggestedDefault()
        self.configurationStore = configurationStore
        self.languageStore = languageStore
        self.configuration = configuration
        self.language = language
        self.installDraft = installDraft
        self.installValidation = .idle
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

    func refreshNow() {
        Task {
            await refresh(trigger: .manual)
        }
    }

    func perform(_ action: RecoveryAction) {
        switch action {
        case .refresh:
            refreshNow()
        case .openDashboard:
            NSWorkspace.shared.open(snapshot.dashboardURL)
            reloadDashboard()
        case .revealLogs:
            revealLogs()
        case .openInstallGuide:
            openInstallGuide()
        case .restartGateway, .installLaunchAgent, .repairConfiguration:
            Task {
                isBusy = true
                defer { isBusy = false }

                let result = await supervisor.run(action: action)
                apply(result)
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

    func updateInstallDirectoryPath(_ path: String) {
        installDraft.installDirectoryPath = path
        Task {
            await refreshInstallSnapshot()
        }
    }

    func updateInstallPortText(_ text: String) {
        installDraft.gatewayPortText = text
        Task {
            await refreshInstallSnapshot()
        }
    }

    func chooseInstallDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let currentPath = NSString(string: installDraft.installDirectoryPath).expandingTildeInPath
        if !currentPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: currentPath, isDirectory: true)
        }

        if panel.runModal() == .OK, let url = panel.url {
            updateInstallDirectoryPath(url.path)
        }
    }

    func installOpenClaw() {
        Task {
            isInstallingOpenClaw = true
            installStatusMessage = nil
            defer { isInstallingOpenClaw = false }

            do {
                let result = try await openClawInstaller.install(draft: installDraft)
                installStatusMessage = result.summary
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .success,
                        title: "OpenClaw installed",
                        message: result.summary,
                        command: nil
                    )
                )
                saveConfiguration(result.suggestedConfiguration)
                await refreshInstallSnapshot()
            } catch {
                installStatusMessage = error.localizedDescription
                appendDiagnostic(
                    DiagnosticEntry(
                        timestamp: .now,
                        level: .error,
                        title: "OpenClaw install failed",
                        message: error.localizedDescription,
                        command: nil
                    )
                )
            }
        }
    }

    func installDeveloperTools() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--install"]

        do {
            try process.run()
            appendDiagnostic(
                DiagnosticEntry(
                    timestamp: .now,
                    level: .info,
                    title: "Requested Apple developer tools",
                    message: "macOS should now show the Command Line Tools installer. Finish that install, then retry OpenClaw.",
                    command: "xcode-select --install"
                )
            )
            installStatusMessage = "macOS should now show the Command Line Tools installer. Finish that install, then retry OpenClaw."
        } catch {
            installStatusMessage = "Could not start `xcode-select --install`: \(error.localizedDescription)"
            appendDiagnostic(
                DiagnosticEntry(
                    timestamp: .now,
                    level: .warning,
                    title: "Developer tools prompt failed",
                    message: error.localizedDescription,
                    command: "xcode-select --install"
                )
            )
        }
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

    private func refresh(trigger: MonitorTrigger) async {
        let result = await supervisor.refresh(trigger: trigger)
        apply(result)
    }

    private func refreshInstallSnapshot() async {
        let snapshot = await openClawInstaller.snapshot(for: installDraft)
        installValidation = snapshot.validation
        knownOpenClawInstances = snapshot.knownInstances
    }

    private func apply(_ result: MonitorResult) {
        snapshot = result.snapshot
        result.entries.forEach(appendDiagnostic)

        if result.snapshot.level == .healthy && dashboardWebError == nil {
            isDashboardLoading = false
        }
    }

    private func appendDiagnostic(_ entry: DiagnosticEntry) {
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

    private func openInstallGuide() {
        guard let url = URL(string: "https://docs.openclaw.ai/wizard") else { return }
        NSWorkspace.shared.open(url)
    }
}
