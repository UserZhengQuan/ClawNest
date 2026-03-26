import Foundation
import SwiftUI

enum OpenClawRuntimeStatus: String, Equatable, Sendable {
    case running
    case stopped
    case unknown

    var label: String {
        switch self {
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        case .unknown:
            return "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .running:
            return "checkmark.circle.fill"
        case .stopped:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .running:
            return Color(red: 0.18, green: 0.56, blue: 0.29)
        case .stopped:
            return Color(red: 0.78, green: 0.25, blue: 0.22)
        case .unknown:
            return Color(red: 0.52, green: 0.54, blue: 0.57)
        }
    }
}

enum GatewayHealthStatus: String, Equatable, Sendable {
    case healthy
    case unhealthy
    case unavailable

    var label: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .unhealthy:
            return "Unhealthy"
        case .unavailable:
            return "Unavailable"
        }
    }

    var symbolName: String {
        switch self {
        case .healthy:
            return "heart.text.square.fill"
        case .unhealthy:
            return "exclamationmark.triangle.fill"
        case .unavailable:
            return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .healthy:
            return Color(red: 0.18, green: 0.56, blue: 0.29)
        case .unhealthy:
            return Color(red: 0.78, green: 0.25, blue: 0.22)
        case .unavailable:
            return Color(red: 0.52, green: 0.54, blue: 0.57)
        }
    }
}

struct OpenClawPathItem: Identifiable, Equatable, Sendable {
    let title: String
    let url: URL

    var id: String { title }
}

struct GatewayStatusDetails: Equatable, Sendable {
    let url: URL
    let port: Int
    let health: GatewayHealthStatus
}

struct OpenClawStatusSnapshot: Equatable, Sendable {
    let runtimeStatus: OpenClawRuntimeStatus
    let lastCheckedAt: Date?
    let gateway: GatewayStatusDetails
    let paths: [OpenClawPathItem]

    static func placeholder(defaults: OpenClawDefaults = .standard()) -> OpenClawStatusSnapshot {
        OpenClawStatusSnapshot(
            runtimeStatus: .unknown,
            lastCheckedAt: nil,
            gateway: GatewayStatusDetails(
                url: defaults.gatewayURL,
                port: defaults.port,
                health: .unavailable
            ),
            paths: defaults.paths
        )
    }
}

struct OpenClawDefaults: Equatable, Sendable {
    let openClawCommand: String
    let gatewayURL: URL
    let paths: [OpenClawPathItem]

    var port: Int {
        gatewayURL.port ?? 18789
    }

    static func standard(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> OpenClawDefaults {
        let rootURL = homeDirectory.appendingPathComponent(".openclaw", isDirectory: true)

        return OpenClawDefaults(
            openClawCommand: "openclaw",
            gatewayURL: URL(string: "http://127.0.0.1:18789/")!,
            paths: [
                OpenClawPathItem(title: "OpenClaw root", url: rootURL),
                OpenClawPathItem(title: "Config", url: rootURL.appendingPathComponent("openclaw.json", isDirectory: false)),
                OpenClawPathItem(title: "Logs", url: URL(fileURLWithPath: "/tmp/openclaw", isDirectory: true))
            ]
        )
    }
}
