import Foundation

enum OpenClawInstallStage: Int, CaseIterable, Identifiable, Sendable {
    case checkingEnvironment
    case installingDeveloperTools
    case installingHomebrew
    case installingOpenClawCLI
    case finalizing

    var id: Int { rawValue }
}

enum OpenClawInstallStageState: String, Equatable, Sendable {
    case pending
    case active
    case completed
    case failed
    case skipped
}

struct OpenClawInstallStageProgress: Identifiable, Equatable, Sendable {
    let stage: OpenClawInstallStage
    var state: OpenClawInstallStageState

    var id: OpenClawInstallStage { stage }
}

struct OpenClawInstallFailure: Equatable, Sendable {
    let stage: OpenClawInstallStage
    let summary: String
    let recoverySuggestion: String
    let rawOutput: String?
}

struct OpenClawInstallProgress: Equatable, Sendable {
    var currentStage: OpenClawInstallStage?
    var stages: [OpenClawInstallStageProgress]
    var detail: String
    var failure: OpenClawInstallFailure?
    var isComplete: Bool

    static let idle = OpenClawInstallProgress(
        currentStage: nil,
        stages: OpenClawInstallStage.allCases.map {
            OpenClawInstallStageProgress(stage: $0, state: .pending)
        },
        detail: "ClawNest will explain each install phase before macOS prompts appear.",
        failure: nil,
        isComplete: false
    )

    var hasStarted: Bool {
        isComplete || failure != nil || currentStage != nil || stages.contains { $0.state != .pending }
    }

    mutating func apply(_ update: OpenClawInstallProgressUpdate) {
        switch update {
        case let .activate(stage, detail):
            currentStage = stage
            failure = nil
            isComplete = false
            updateStage(stage, to: .active)
            self.detail = detail
        case let .complete(stage, detail):
            updateStage(stage, to: .completed)
            if currentStage == stage {
                currentStage = nil
            }
            if let detail {
                self.detail = detail
            }
        case let .skip(stage, detail):
            updateStage(stage, to: .skipped)
            if currentStage == stage {
                currentStage = nil
            }
            self.detail = detail
        case let .fail(stage, summary, recoverySuggestion, rawOutput):
            currentStage = stage
            updateStage(stage, to: .failed)
            failure = OpenClawInstallFailure(
                stage: stage,
                summary: summary,
                recoverySuggestion: recoverySuggestion,
                rawOutput: rawOutput
            )
            isComplete = false
            detail = summary
        case let .finish(detail):
            if stageState(for: .finalizing) == .active {
                updateStage(.finalizing, to: .completed)
            } else if let currentStage {
                updateStage(currentStage, to: .completed)
            }
            self.detail = detail
            self.failure = nil
            self.currentStage = nil
            self.isComplete = true
        case let .setDetail(detail):
            self.detail = detail
        case .reset:
            self = .idle
        }
    }

    func stageState(for stage: OpenClawInstallStage) -> OpenClawInstallStageState {
        stages.first(where: { $0.stage == stage })?.state ?? .pending
    }

    private mutating func updateStage(_ stage: OpenClawInstallStage, to state: OpenClawInstallStageState) {
        guard let index = stages.firstIndex(where: { $0.stage == stage }) else { return }
        stages[index].state = state
    }
}

enum OpenClawInstallProgressUpdate: Equatable, Sendable {
    case activate(stage: OpenClawInstallStage, detail: String)
    case complete(stage: OpenClawInstallStage, detail: String? = nil)
    case skip(stage: OpenClawInstallStage, detail: String)
    case fail(stage: OpenClawInstallStage, summary: String, recoverySuggestion: String, rawOutput: String?)
    case finish(detail: String)
    case setDetail(String)
    case reset
}

final class OpenClawInstallProgressRelay: @unchecked Sendable {
    private let handler: @Sendable (OpenClawInstallProgressUpdate) -> Void

    init(handler: @escaping @Sendable (OpenClawInstallProgressUpdate) -> Void) {
        self.handler = handler
    }

    func send(_ update: OpenClawInstallProgressUpdate) {
        handler(update)
    }
}
