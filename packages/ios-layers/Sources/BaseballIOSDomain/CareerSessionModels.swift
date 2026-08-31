import Foundation
import SimulationCore

/// 결과에 맞춘 햅틱/연출 신호. 화면은 이 값만 보고 반응한다.
public enum FeedbackCue: Equatable, Sendable {
    case neutral
    case success
    case growth
    case setback
}

/// 능력이 오른 항목. 성장 연출이 이 목록을 그대로 보여 준다.
public struct AbilityGain: Identifiable, Equatable, Sendable {
    public var id: String { ability.rawValue }
    public let ability: TalentAbility
    public let before: Int
    public let after: Int

    public init(ability: TalentAbility, before: Int, after: Int) {
        self.ability = ability
        self.before = before
        self.after = after
    }

    public init(label: String, before: Int, after: Int) {
        self.ability = switch label {
        case "구위": .stuff
        case "제구": .command
        case "변화구": .movement
        case "체력": .stamina
        default: .command
        }
        self.before = before
        self.after = after
    }

    public var label: String { ability.label }
}

public struct TalentBloom: Equatable, Sendable {
    public let ability: TalentAbility
    public let grade: TalentGrade

    public init(ability: TalentAbility, grade: TalentGrade) {
        self.ability = ability
        self.grade = grade
    }
}

/// 방금 끝난 훈련의 영수증. 저장하지 않고 화면이 읽고 닫는다.
public struct TrainingReceipt: Equatable, Sendable {
    public var focus: TrainingFocus
    public var headline: String
    public var detail: String
    public var gains: [AbilityGain]
    public var growth: Int
    public var repeatCount: Int?
    public var jackpot: Bool
    public var bloom: TalentBloom?
    public var fatigueAfter: Int
    public var fatigueChange: Int
    public var opportunityHit: Bool
    public var pitchLearning: PitchLearningReceiptSnapshot?

    public init(
        focus: TrainingFocus,
        headline: String,
        detail: String,
        gains: [AbilityGain],
        growth: Int = 0,
        repeatCount: Int? = nil,
        jackpot: Bool,
        bloom: TalentBloom?,
        fatigueAfter: Int,
        fatigueChange: Int,
        opportunityHit: Bool,
        pitchLearning: PitchLearningReceiptSnapshot? = nil
    ) {
        self.focus = focus
        self.headline = headline
        self.detail = detail
        self.gains = gains
        self.growth = growth
        self.repeatCount = repeatCount
        self.jackpot = jackpot
        self.bloom = bloom
        self.fatigueAfter = fatigueAfter
        self.fatigueChange = fatigueChange
        self.opportunityHit = opportunityHit
        self.pitchLearning = pitchLearning
    }
}
