import Foundation

struct HealthProbeInterpreter {
    func interpret(
        result: CommandResult,
        configuration: ClawNestConfiguration,
        lastHealthy: Date?,
        logSummary: LogSummary?
    ) -> GatewaySnapshot {
        let now = Date()
        let parsedJSON = parseJSON(result.stdout)
        let rawProbe = parsedJSON.map(prettyPrinted) ?? nonEmpty(result.stdout, result.stderr, result.launchError) ?? ""

        if isMissingCLI(result) {
            return GatewaySnapshot(
                level: .missingCLI,
                headline: "OpenClaw CLI is not installed or not on PATH",
                detail: "ClawNest cannot manage the gateway until `openclaw` is available on the machine.",
                lastCheck: now,
                lastHealthy: lastHealthy,
                dashboardURL: configuration.dashboardURL,
                metrics: baseMetrics(
                    configuration: configuration,
                    status: "missing-cli",
                    extra: []
                ),
                rawProbe: rawProbe,
                logSummary: logSummary
            )
        }

        let statusText = firstString(in: parsedJSON, matching: ["status", "state", "phase", "gatewayStatus"])
        let reasonText = firstString(in: parsedJSON, matching: ["reason", "error", "message", "detail"])
        let okFlag = firstBool(in: parsedJSON, matching: ["ok", "healthy", "reachable"])
        let connectedTerms = "healthy ready connected online linked ok"
        let recoveringTerms = "starting booting connecting retry retrying recovering loading"
        let failureTerms = "offline unreachable unauthorized refused failed error crash"
        let combinedText = [statusText, reasonText, result.stderr, result.launchError]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        let level: GatewayStatusLevel
        if okFlag == true || containsAny(of: connectedTerms, in: combinedText) {
            level = .healthy
        } else if containsAny(of: recoveringTerms, in: combinedText) {
            level = .recovering
        } else if result.exitCode != 0 || containsAny(of: failureTerms, in: combinedText) {
            level = .offline
        } else if result.stdout.isEmpty && result.stderr.isEmpty {
            level = .degraded
        } else {
            level = .degraded
        }

        let headline: String
        let defaultDetail: String
        switch level {
        case .healthy:
            headline = "Gateway reachable and responding"
            defaultDetail = "The OpenClaw gateway passed the latest health probe."
        case .recovering:
            headline = "Gateway is still coming back"
            defaultDetail = "The gateway is responding, but it still looks like it is warming up."
        case .degraded:
            headline = "Gateway responded with an unclear state"
            defaultDetail = "The health probe completed, but the result did not look fully healthy."
        case .offline:
            headline = "Gateway is offline or refusing requests"
            defaultDetail = "ClawNest could not verify a healthy local gateway."
        case .missingCLI:
            headline = ""
            defaultDetail = ""
        }

        let detail = nonEmpty(reasonText, result.stderr, result.launchError) ?? defaultDetail
        let metrics = baseMetrics(
            configuration: configuration,
            status: statusText ?? level.rawValue,
            extra: extraMetrics(from: parsedJSON)
        )

        return GatewaySnapshot(
            level: level,
            headline: headline,
            detail: detail,
            lastCheck: now,
            lastHealthy: level == .healthy ? now : lastHealthy,
            dashboardURL: configuration.dashboardURL,
            metrics: metrics,
            rawProbe: rawProbe,
            logSummary: logSummary
        )
    }

    private func baseMetrics(
        configuration: ClawNestConfiguration,
        status: String,
        extra: [StatusMetric]
    ) -> [StatusMetric] {
        var metrics = [
            StatusMetric("Dashboard", value: configuration.dashboardURL.absoluteString),
            StatusMetric("LaunchAgent", value: configuration.launchAgentLabel),
            StatusMetric("Status", value: status)
        ]
        metrics.append(contentsOf: extra)
        return metrics
    }

    private func extraMetrics(from json: Any?) -> [StatusMetric] {
        var metrics: [StatusMetric] = []

        if let mode = firstString(in: json, matching: ["mode", "gatewayMode", "runtimeMode"]) {
            metrics.append(StatusMetric("Mode", value: mode))
        }

        if let sessionCount = firstNumber(in: json, matching: ["sessionCount", "sessions", "count"]) {
            metrics.append(StatusMetric("Sessions", value: String(Int(sessionCount))))
        }

        if let authAge = firstString(in: json, matching: ["authAge", "authAgeMinutes", "auth_age"]) {
            metrics.append(StatusMetric("Auth Age", value: authAge))
        }

        if let sessionPath = firstString(in: json, matching: ["sessionStorePath", "sessionPath", "stateDir", "sessionsPath"]) {
            metrics.append(StatusMetric("State Dir", value: sessionPath))
        }

        return metrics
    }

    private func parseJSON(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8), !data.isEmpty else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data)
    }

    private func prettyPrinted(_ json: Any) -> String {
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return text
    }

    private func isMissingCLI(_ result: CommandResult) -> Bool {
        if result.exitCode == 127 {
            return true
        }

        let errorText = [result.stderr.lowercased(), result.launchError?.lowercased() ?? ""].joined(separator: " ")
        return errorText.contains("not found") || errorText.contains("no such file")
    }

    private func containsAny(of needleList: String, in text: String) -> Bool {
        needleList
            .split(separator: " ")
            .contains { text.contains($0) }
    }

    private func nonEmpty(_ candidates: String?...) -> String? {
        candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func firstString(in json: Any?, matching keys: Set<String>) -> String? {
        firstValue(in: json, matching: keys) { value in
            switch value {
            case let string as String:
                return string
            case let number as NSNumber:
                return number.stringValue
            default:
                return nil
            }
        }
    }

    private func firstBool(in json: Any?, matching keys: Set<String>) -> Bool? {
        firstValue(in: json, matching: keys) { value in
            value as? Bool
        }
    }

    private func firstNumber(in json: Any?, matching keys: Set<String>) -> Double? {
        firstValue(in: json, matching: keys) { value in
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            return nil
        }
    }

    private func firstValue<T>(
        in json: Any?,
        matching keys: Set<String>,
        transform: (Any) -> T?
    ) -> T? {
        switch json {
        case let dictionary as [String: Any]:
            for (key, value) in dictionary {
                if keys.contains(key), let transformed = transform(value) {
                    return transformed
                }
                if let nested = firstValue(in: value, matching: keys, transform: transform) {
                    return nested
                }
            }
            return nil
        case let array as [Any]:
            for item in array {
                if let nested = firstValue(in: item, matching: keys, transform: transform) {
                    return nested
                }
            }
            return nil
        default:
            return nil
        }
    }
}
