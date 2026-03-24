import Foundation
import Darwin

actor GatewaySupervisor {
    private var configuration: ClawNestConfiguration
    private let runner: CommandRunning
    private let interpreter = HealthProbeInterpreter()
    private let logInspector: LogInspector

    private var lastHealthyAt: Date?
    private var lastSnapshot: GatewaySnapshot
    private var consecutiveOfflineChecks = 0
    private var lastAutoRecoveryAt: Date?

    init(
        configuration: ClawNestConfiguration,
        runner: CommandRunning = ProcessCommandRunner(),
        logInspector: LogInspector = LogInspector()
    ) {
        self.configuration = configuration
        self.runner = runner
        self.logInspector = logInspector
        self.lastSnapshot = .placeholder(configuration: configuration)
    }

    func updateConfiguration(_ configuration: ClawNestConfiguration) {
        self.configuration = configuration
        lastSnapshot.dashboardURL = configuration.dashboardURL
    }

    func refresh(trigger: MonitorTrigger) async -> MonitorResult {
        let probeResult = await runner.run(command: configuration.openClawCommand, arguments: ["health", "--json"])
        var snapshot = interpreter.interpret(
            result: probeResult,
            configuration: configuration,
            lastHealthy: lastHealthyAt,
            logSummary: logInspector.latestSummary()
        )

        var entries = [
            diagnosticForProbe(result: probeResult, snapshot: snapshot, trigger: trigger)
        ]

        switch snapshot.level {
        case .healthy:
            consecutiveOfflineChecks = 0
            lastHealthyAt = snapshot.lastCheck
        case .offline:
            consecutiveOfflineChecks += 1
        case .recovering, .degraded, .missingCLI:
            consecutiveOfflineChecks = 0
        }

        if trigger.allowsAutoRecovery && shouldAutoRecover(snapshot: snapshot) {
            let restartResult = await execute(action: .restart)
            entries.append(diagnosticForAction(.restart, result: restartResult, automatic: true))
            lastAutoRecoveryAt = .now

            let postRestartProbe = await runner.run(command: configuration.openClawCommand, arguments: ["health", "--json"])
            snapshot = interpreter.interpret(
                result: postRestartProbe,
                configuration: configuration,
                lastHealthy: lastHealthyAt,
                logSummary: logInspector.latestSummary()
            )
            entries.append(diagnosticForProbe(result: postRestartProbe, snapshot: snapshot, trigger: .postAction(.restart)))

            if snapshot.level == .healthy {
                lastHealthyAt = snapshot.lastCheck
                consecutiveOfflineChecks = 0
            }
        }

        if snapshot.level != lastSnapshot.level || snapshot.headline != lastSnapshot.headline {
            entries.insert(
                DiagnosticEntry(
                    timestamp: .now,
                    level: snapshot.level == .healthy ? .success : .warning,
                    title: "State changed to \(snapshot.level.label)",
                    message: snapshot.detail,
                    command: nil
                ),
                at: 0
            )
        }

        lastSnapshot = snapshot
        return MonitorResult(snapshot: snapshot, entries: entries)
    }

    func run(action: RuntimeAction) async -> MonitorResult {
        switch action {
        case .refreshStatus, .openDashboard, .revealLogs, .install:
            return await refresh(trigger: .manual)
        case .start, .restart, .repair:
            let result = await execute(action: action)
            let entry = diagnosticForAction(action, result: result, automatic: false)
            let refreshed = await refresh(trigger: .postAction(action))
            return MonitorResult(snapshot: refreshed.snapshot, entries: [entry] + refreshed.entries)
        }
    }

    private func shouldAutoRecover(snapshot: GatewaySnapshot) -> Bool {
        guard configuration.autoRestartEnabled else { return false }
        guard snapshot.level == .offline else { return false }
        guard consecutiveOfflineChecks >= 2 else { return false }

        if let lastAutoRecoveryAt, Date().timeIntervalSince(lastAutoRecoveryAt) < 180 {
            return false
        }

        return true
    }

    private func execute(action: RuntimeAction) async -> CommandResult {
        switch action {
        case .start, .restart:
            let label = "gui/\(getuid())/\(configuration.launchAgentLabel)"
            return await runner.run(command: "launchctl", arguments: ["kickstart", "-k", label])
        case .repair:
            return await runner.run(command: configuration.openClawCommand, arguments: ["doctor", "--repair", "--non-interactive"])
        case .install, .openDashboard, .revealLogs, .refreshStatus:
            return await runner.run(command: "true", arguments: [])
        }
    }

    private func diagnosticForProbe(
        result: CommandResult,
        snapshot: GatewaySnapshot,
        trigger: MonitorTrigger
    ) -> DiagnosticEntry {
        let title: String
        switch trigger {
        case .manual:
            title = "Manual health probe"
        case .automaticPoll:
            title = "Scheduled health probe"
        case let .postAction(action):
            title = "Post-\(action.title) probe"
        }

        let level: DiagnosticLevel
        switch snapshot.level {
        case .healthy:
            level = .success
        case .recovering, .degraded:
            level = .warning
        case .offline, .missingCLI:
            level = .error
        }

        return DiagnosticEntry(
            timestamp: .now,
            level: level,
            title: title,
            message: snapshot.detail,
            command: result.renderedCommand
        )
    }

    private func diagnosticForAction(
        _ action: RuntimeAction,
        result: CommandResult,
        automatic: Bool
    ) -> DiagnosticEntry {
        let output = result.combinedOutput.isEmpty ? "No output returned." : result.combinedOutput
        let trimmedOutput = String(output.prefix(280))
        let titlePrefix = automatic ? "Automatic" : "Manual"
        let level: DiagnosticLevel = result.exitCode == 0 ? .success : .warning

        return DiagnosticEntry(
            timestamp: .now,
            level: level,
            title: "\(titlePrefix) \(action.title)",
            message: trimmedOutput,
            command: result.renderedCommand
        )
    }
}
