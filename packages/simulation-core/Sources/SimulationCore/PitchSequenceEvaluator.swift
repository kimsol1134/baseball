import Foundation

/// A positive strategic pattern recognized after a pitch has resolved.
///
/// These tags describe the player's choices. They are deliberately downstream of
/// `PitchKernelEngine`, so recognizing one can never change pitch execution or outcome odds.
public enum PitchSequenceTag: String, Codable, CaseIterable, Sendable {
    case speedLadder = "speed_ladder"
    case eyeLevelChange = "eye_level_change"
    case insideOutside = "inside_outside"
    case expandAfterTwoStrikes = "expand_after_two_strikes"
    case stealStrike = "steal_strike"
    case counterRead = "counter_read"
}

/// The choice and result data needed to recognize a pitch sequence.
///
/// `expectedVelocityKPH` describes the called pitch, rather than the randomized measured
/// velocity. This keeps recognition tied to player intent and deterministic across presentation
/// layers.
public struct PitchSequencePitch: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let zone: PitchZone
    public let intent: ZoneIntent
    public let expectedVelocityKPH: Int
    public let outcome: PitchOutcome

    public init(
        pitchType: PitchType,
        zone: PitchZone,
        intent: ZoneIntent,
        expectedVelocityKPH: Int,
        outcome: PitchOutcome
    ) {
        self.pitchType = pitchType
        self.zone = zone
        self.intent = intent
        self.expectedVelocityKPH = expectedVelocityKPH
        self.outcome = outcome
    }
}

/// One player-facing mastery badge. The evaluator returns at most one moment per pitch.
public struct PitchSequenceMoment: Codable, Equatable, Sendable {
    public let pitchNumber: Int
    public let tag: PitchSequenceTag
    public let headline: String
    public let detail: String

    public init(
        pitchNumber: Int,
        tag: PitchSequenceTag,
        headline: String,
        detail: String
    ) {
        self.pitchNumber = pitchNumber
        self.tag = tag
        self.headline = headline
        self.detail = detail
    }
}

/// Pure, deterministic recognition layered on top of an already-resolved pitch.
public enum PitchSequenceEvaluator {
    /// A visible change of at least this size is large enough to call a deliberate speed ladder.
    public static let minimumSpeedDifferenceKPH = 12

    /// Evaluates `current` against up to the last three earlier pitches.
    ///
    /// - Important: `recent` must not contain `current`. `rivalMemory` is the memory visible before
    ///   `current` was thrown, so `counter_read` only celebrates reacting to an existing warning.
    /// - Returns: At most one moment. More situation-specific reads take priority over generic
    ///   vertical, horizontal, and velocity changes.
    public static func evaluate(
        recent: [PitchSequencePitch],
        context: PlateAppearanceContext,
        current: PitchSequencePitch,
        rivalMemory: RivalMemorySnapshot?
    ) -> PitchSequenceMoment? {
        guard isValid(current),
              (0...3).contains(context.balls),
              (0...2).contains(context.strikes),
              context.pitchNumber > 0 else {
            return nil
        }

        let recentWindow = recent.suffix(3)

        if recognizesCounterRead(
            context: context,
            current: current,
            rivalMemory: rivalMemory
        ) {
            return moment(
                context: context,
                tag: .counterRead,
                headline: "읽힘을 역이용했다",
                detail: "상대 벤치가 읽은 반복을 끊고 좋은 결과를 만들었습니다."
            )
        }

        if context.strikes == 2,
           current.intent == .chase,
           current.outcome == .swingingStrike {
            return moment(
                context: context,
                tag: .expandAfterTwoStrikes,
                headline: "결정구 유인 성공",
                detail: "2스트라이크 뒤 존 밖으로 유도해 헛스윙 삼진을 만들었습니다."
            )
        }

        if context.balls > context.strikes,
           context.strikes < 2,
           current.intent == .strike,
           addsStrike(current.outcome) {
            return moment(
                context: context,
                tag: .stealStrike,
                headline: "카운트를 되찾았다",
                detail: "타자 우세 카운트에서 스트라이크를 넣어 승부를 원점으로 돌렸습니다."
            )
        }

        guard let previous = recentWindow.last, isValid(previous) else { return nil }

        let velocityDifference = abs(current.expectedVelocityKPH - previous.expectedVelocityKPH)
        if velocityDifference >= minimumSpeedDifferenceKPH,
           disruptsTiming(current.outcome) {
            return moment(
                context: context,
                tag: .speedLadder,
                headline: "속도차 적중 · \(velocityDifference)km/h",
                detail: "앞선 공과 \(velocityDifference)km/h 차이를 만들어 타자의 타이밍을 무너뜨렸습니다."
            )
        }

        if usesOppositeExtremes(previous.zone.row, current.zone.row),
           disruptsTiming(current.outcome) {
            return moment(
                context: context,
                tag: .eyeLevelChange,
                headline: "눈높이를 바꿨다",
                detail: "높은 코스와 낮은 코스를 이어 타자의 시선을 흔들었습니다."
            )
        }

        if usesOppositeExtremes(previous.zone.column, current.zone.column),
           securesResult(current.outcome) {
            return moment(
                context: context,
                tag: .insideOutside,
                headline: "가로 폭을 썼다",
                detail: "몸쪽과 바깥쪽을 연달아 갈라 좋은 결과를 만들었습니다."
            )
        }

        return nil
    }

    private static func recognizesCounterRead(
        context: PlateAppearanceContext,
        current: PitchSequencePitch,
        rivalMemory: RivalMemorySnapshot?
    ) -> Bool {
        guard let rivalMemory, securesResult(current.outcome) else { return false }
        let adaptation = RivalMemoryEngine().analyze(rivalMemory, context: context)
        guard adaptation.detectedPitch != nil || adaptation.detectedZone != nil else {
            return false
        }
        let changedPitch = adaptation.detectedPitch.map { $0 != current.pitchType } ?? false
        let changedZone = adaptation.detectedZone.map { $0 != current.zone } ?? false
        return changedPitch || changedZone
    }

    private static func moment(
        context: PlateAppearanceContext,
        tag: PitchSequenceTag,
        headline: String,
        detail: String
    ) -> PitchSequenceMoment {
        PitchSequenceMoment(
            pitchNumber: context.pitchNumber,
            tag: tag,
            headline: headline,
            detail: detail
        )
    }

    private static func usesOppositeExtremes(_ lhs: Int, _ rhs: Int) -> Bool {
        (lhs == 0 && rhs == 2) || (lhs == 2 && rhs == 0)
    }

    private static func disruptsTiming(_ outcome: PitchOutcome) -> Bool {
        outcome == .swingingStrike || outcome == .inPlayOut
    }

    private static func securesResult(_ outcome: PitchOutcome) -> Bool {
        outcome == .calledStrike || disruptsTiming(outcome)
    }

    private static func addsStrike(_ outcome: PitchOutcome) -> Bool {
        outcome == .calledStrike || outcome == .swingingStrike || outcome == .foul
    }

    private static func isValid(_ pitch: PitchSequencePitch) -> Bool {
        (0...2).contains(pitch.zone.row)
            && (0...2).contains(pitch.zone.column)
            && pitch.expectedVelocityKPH > 0
    }
}

/// Shared economy rule for the non-probabilistic relationship reward.
public enum PitchSequenceMasteryRules {
    public static let maximumTrustReward = 3

    /// Each recognized moment is worth one trust point, with no penalty for absent/invalid data.
    public static func trustReward(for sequenceMasteryCount: Int?) -> Int {
        min(max(sequenceMasteryCount ?? 0, 0), maximumTrustReward)
    }
}
