import Foundation
import SimulationCore

/// 프로 시즌 대화의 화자.
///
/// 안드로이드 `ProConversationPresentation.role()`의 이식이다. 라이벌 분석에 라이벌을
/// 세우지 않는 것이 의도다 — **상대를 살피는 일은 포수와 나누는 대화**이지, 없던 라이벌이
/// 갑자기 마운드 옆에 나타나는 장면이 아니다.
public enum ProConversationRole: String, Sendable, CaseIterable {
    case coach
    case catcher
    case staff
}

/// 선택을 확정하기 전에 **커널이 실제로 하는 일**을 그대로 옮긴 값.
///
/// 선언된 `ProDecisionEffect`를 읽는 것과 다르다. 능력은 20–80에서 clamp되고,
/// 신구종 실전은 구종 하나를 따로 다듬고, 주간 2지선다는 3주짜리 약속을 남긴다.
/// 선언값만 보면 이 중 어느 것도 보이지 않고, 80에 닿은 능력의 "+1"처럼 **일어나지 않는
/// 일이 이득으로 보인다.**
public struct ProConversationOutcome: Equatable, Sendable {
    public enum Ability: String, Sendable, CaseIterable {
        case stuff, command, movement, stamina
    }

    /// 3주 뒤에 돌아오는 후속까지 포함한, 선택이 만드는 약속.
    /// 전부 `ProDecisionModifier`의 필드에서 직접 읽는다.
    public enum Commitment: String, Sendable, CaseIterable {
        /// 등판이 한 번 더 잡힌다(`extraOutingChance`).
        case extraOuting
        /// 부상 압력 하한이 걸린 채로 던진다(`injuryPressureFloor`).
        case injuryPressure
        /// 창구 동안 1군 등판이 없다(`suppressOutings`).
        case noFirstTeamOutings
        /// 훈련 효율이 깎인다(`trainingEfficiencyPermille` < 1000).
        case reducedTraining
        /// 지금 내준 제구를 후속에서 돌려받는다(`commandDelta`).
        case commandReturnsLater
    }

    public struct AbilityChange: Equatable, Sendable {
        public let ability: Ability
        /// 화면 눈금(1–100) 기준 변화량. 저장·시뮬레이션의 20–80이 아니다.
        public let displayDelta: Int

        public init(ability: Ability, displayDelta: Int) {
            self.ability = ability
            self.displayDelta = displayDelta
        }
    }

    public let abilities: [AbilityChange]
    public let managerTrustDelta: Int
    public let catcherTrustDelta: Int
    public let fatigueDelta: Int
    /// 보직이 실제로 바뀔 때만 값이 있다. 선언에 `roleTarget`이 있어도 같은 보직이면 nil이다.
    public let role: ProRole?
    /// 신구종 실전이 다듬는 구종.
    public let sharpenedPitch: PitchType?
    public let commitments: [Commitment]
    /// 약속이 풀리는 주. `commitments`가 비어 있으면 nil이다.
    public let commitmentExpiresWeek: Int?
    public let incomeDelta: Int64
    public let fanDelta: Int
    public let communityDelta: Int
    /// 이번 시즌에 붙는 혜택(부진 탈출의 기후 안정 등).
    public let seasonBenefit: ProSeasonBenefitKind?
    /// 다음 오프시즌 하락을 덜어 주는 회복 연도.
    public let recoveryYear: Bool

    public var isEmpty: Bool {
        abilities.isEmpty && managerTrustDelta == 0 && catcherTrustDelta == 0 && fatigueDelta == 0
            && role == nil && sharpenedPitch == nil && commitments.isEmpty
            && incomeDelta == 0 && fanDelta == 0 && communityDelta == 0
            && seasonBenefit == nil && !recoveryYear
    }
}

public enum ProConversationPresentation {
    /// Scouting a rival is a conversation with the catcher, not an invented rival appearance.
    public static func role(for type: ProSeasonDecisionType?) -> ProConversationRole? {
        switch type {
        case .catcherGamePlan, .rivalAnalysis:
            return .catcher
        case .rotationPush, .newPitchTrial, .farmReset, .extraBullpen,
             .roleMeeting, .recordChase, .seasonFinale, .formCrisis:
            return .coach
        case nil:
            return nil
        case .mediaOpportunity, .agingCrossroads, .veteranMentor:
            return .staff
        }
    }

    /// 선택지 하나를 **실제 명령과 같은 시드로** 돌려 보고 전후를 비교한다.
    ///
    /// 반환 전에 결과를 버리므로 이 호출은 상태를 쓰지 않는다 — 명령 0회다.
    /// 커널이 거부하는 선택(자격 미달인 광고 촬영 등)은 nil이다.
    public static func preview(
        engine: ProCareerEngine,
        state: ProCareerSnapshot,
        seed: String,
        decisionID: String,
        choiceID: String
    ) -> ProConversationOutcome? {
        guard let applied = try? engine.applySeasonDecision(.init(
            seed: seed,
            state: state,
            decisionID: decisionID,
            choiceID: choiceID
        )) else { return nil }
        return outcome(before: state, after: applied.snapshot)
    }

    /// 두 스냅숏의 차이를 화면이 쓰는 낱알로 나눈다.
    public static func outcome(
        before: ProCareerSnapshot,
        after: ProCareerSnapshot
    ) -> ProConversationOutcome {
        var abilities: [ProConversationOutcome.AbilityChange] = []
        func ability(_ kind: ProConversationOutcome.Ability, _ from: Int, _ to: Int) {
            let delta = displayRating(to) - displayRating(from)
            guard delta != 0 else { return }
            abilities.append(.init(ability: kind, displayDelta: delta))
        }
        ability(.stuff, before.pitcher.stuff, after.pitcher.stuff)
        ability(.command, before.pitcher.command, after.pitcher.command)
        ability(.movement, before.pitcher.movement, after.pitcher.movement)
        ability(.stamina, before.pitcher.stamina, after.pitcher.stamina)

        let newModifiers = (after.activeDecisionModifiers ?? []).filter { added in
            !(before.activeDecisionModifiers ?? []).contains(added)
        }
        var commitments: [ProConversationOutcome.Commitment] = []
        for modifier in newModifiers {
            if modifier.extraOutingChance > 0 { commitments.append(.extraOuting) }
            if modifier.injuryPressureFloor != nil { commitments.append(.injuryPressure) }
            if modifier.suppressOutings { commitments.append(.noFirstTeamOutings) }
            if let efficiency = modifier.trainingEfficiencyPermille, efficiency < 1_000 {
                commitments.append(.reducedTraining)
            }
            if modifier.commandDelta != 0 { commitments.append(.commandReturnsLater) }
        }
        let ordered = ProConversationOutcome.Commitment.allCases.filter { commitments.contains($0) }

        return ProConversationOutcome(
            abilities: abilities,
            managerTrustDelta: after.managerTrust - before.managerTrust,
            catcherTrustDelta: after.catcherTrust - before.catcherTrust,
            fatigueDelta: after.fatigue - before.fatigue,
            role: after.role == before.role ? nil : after.role,
            sharpenedPitch: sharpenedPitch(before: before, after: after),
            commitments: ordered,
            commitmentExpiresWeek: newModifiers.map(\.expiresWeek).min(),
            incomeDelta: (after.journeyState?.finances.careerEarnings ?? 0)
                - (before.journeyState?.finances.careerEarnings ?? 0),
            fanDelta: (after.journeyState?.reputation.fanSupport ?? 0)
                - (before.journeyState?.reputation.fanSupport ?? 0),
            communityDelta: communityDelta(before: before, after: after),
            seasonBenefit: before.journeyState?.activeSeasonBenefit?.kind
                == after.journeyState?.activeSeasonBenefit?.kind
                ? nil
                : after.journeyState?.activeSeasonBenefit?.kind,
            recoveryYear: (after.journeyState?.recoveryYearPending ?? false)
                && !(before.journeyState?.recoveryYearPending ?? false)
        )
    }

    /// 화면이 쓰는 1–100 눈금. 저장·시뮬레이션은 20–80 그대로다. 앱 계층
    /// `AbilityDisplayScale`·안드로이드 `AbilityDisplayScale.rating()`과 같은 식이며,
    /// 미리보기가 앱 타깃에 기대지 않도록 여기에만 쓰는 사본을 둔다.
    private static func displayRating(_ internalRating: Int) -> Int {
        let clamped = min(80, max(20, internalRating))
        return max(1, min(100, ((clamped - 20) * 100 + 30) / 60))
    }

    /// 구종별 프로필이 실제로 좋아진 구종 하나. 신구종 실전이 남기는 흔적이다.
    private static func sharpenedPitch(
        before: ProCareerSnapshot,
        after: ProCareerSnapshot
    ) -> PitchType? {
        guard let source = before.pitcher.pitchProfiles, let next = after.pitcher.pitchProfiles else {
            return nil
        }
        for profile in next {
            guard let old = source.first(where: { $0.pitchType == profile.pitchType }) else { continue }
            if profile.control > old.control || profile.movement > old.movement || profile.whiff > old.whiff {
                return profile.pitchType
            }
        }
        return nil
    }

    /// 팬 활동 점수는 커널이 결정 안에서 표를 채운 뒤 더한다. 같은 채움을 이전 상태에도
    /// 적용해야 "표가 생긴 것"과 "점수가 오른 것"을 헷갈리지 않는다.
    private static func communityDelta(
        before: ProCareerSnapshot,
        after: ProCareerSnapshot
    ) -> Int {
        guard let beforeJourney = before.journeyState, let afterJourney = after.journeyState else {
            return 0
        }
        let baseline = ProTeamCareerRecordRules.backfill(
            careerStats: before.careerStats,
            recognitions: beforeJourney.recognitions,
            existing: beforeJourney.teamRecords
        )
        let from = baseline.first(where: { $0.teamID == before.team.id })?.communityPoints ?? 0
        let to = afterJourney.teamRecords.first(where: { $0.teamID == after.team.id })?.communityPoints ?? 0
        return to - from
    }
}
