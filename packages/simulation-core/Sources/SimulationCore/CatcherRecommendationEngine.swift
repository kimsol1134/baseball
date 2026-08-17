import Foundation

public struct CatcherRecommendationEngine: Sendable {
    public init() {}

    /// `scouting` here is the *estimated* read, and `reliability` (0–100) is how much to trust it.
    /// A low reliability both feeds a possibly-wrong estimate and shaves the stated confidence, so
    /// a shaky report reads as a hedge, not a certainty. `reliability` defaults to fully trusted so
    /// direct callers are unchanged.
    public func recommend(
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        adaptation: RivalAdaptationSnapshot? = nil,
        reliability: Int = 100,
        gameState: GameStateSnapshot? = nil,
        lastPitch: PitchAnalysisEntry? = nil
    ) -> (primary: CatcherRecommendation, alternative: CatcherRecommendation) {
        let twoStrikes = context.strikes == 2
        let protectZone = context.balls == 3
        let situation = SignSituation(context: context, gameState: gameState, lastPitch: lastPitch)
        let desiredPitch = recommendedPrimaryPitch(
            pitcher: pitcher,
            desired: scouting.pitchWeakness,
            twoStrikes: twoStrikes,
            protectZone: protectZone,
            lastPitchType: lastPitch?.pitchType
        )
        let repetitionAvoided = (adaptation?.level ?? 0) >= 500
            && adaptation?.detectedPitch == desiredPitch
        // 라이벌이 패턴을 읽었거나, 상황상 같은 공을 되풀이하면 안 될 때 구종을 바꾼다.
        let mustChangePitch = repetitionAvoided
            || (situation.avoidsRepeat && lastPitch?.pitchType == desiredPitch)
        let primaryPitch = mustChangePitch
            ? recommendedAlternativePitch(
                pitcher: pitcher,
                excluding: desiredPitch,
                legacyDesired: desiredPitch == .fourSeam ? .slider : .fourSeam
            )
            : desiredPitch
        let primaryProfile = pitcher.profile(for: primaryPitch)
        // 약점 코스가 기준점이고, 상황이 그 위에서 한 칸씩 민다. 스카우팅의 가치는 그대로다.
        let primaryZone = situation.shift(scouting.coldZone)
        let primary = CatcherRecommendation(
            call: PitchCall(
                pitchType: primaryPitch,
                zone: primaryZone,
                // 밀린 코스가 한복판이면 "존 끝"은 뜻을 잃는다. 목표 좌표가 한복판 그대로라
                // 포수가 아무것도 요구하지 않는 사인을 내는 셈이었다.
                zoneIntent: ZoneIntent.clamped(
                    situation.zoneIntent(protectZone: protectZone, twoStrikes: twoStrikes),
                    for: primaryZone
                ),
                intensity: situation.demandsControl || protectZone || primaryProfile?.role == .development
                    ? .controlled
                    : .normal
            ),
            confidence: ScoutingEstimate.adjustedConfidence(
                clamp(
                    520
                        + (pitcher.command - 50) * 4
                        + ((primaryProfile?.command ?? 50) - 50) * 2
                        + (batter.discipline < 50 ? 45 : 0),
                    350,
                    850
                ),
                reliability: reliability
            ),
            reasonCodes: [
                repetitionAvoided
                    ? "rival.pattern_detected"
                    : mustChangePitch
                    ? "sequence.avoid_repeat"
                    : primaryPitch == scouting.pitchWeakness
                    ? "scouting.pitch_weakness"
                    : "arsenal.best_available",
                "scouting.cold_zone",
                situation.countCode,
                "build.\(PitcherBuildRules.identity(for: pitcher).rawValue)"
            ] + situation.extraReasonCodes
        )

        let alternativePitch = repetitionAvoided
            ? desiredPitch
            : recommendedAlternativePitch(
                pitcher: pitcher,
                excluding: primaryPitch,
                legacyDesired: scouting.pitchWeakness == .fourSeam ? .slider : .fourSeam
            )
        let mirroredZone = PitchZone(
            row: 2 - scouting.hotZone.row,
            column: 2 - scouting.hotZone.column
        )
        let alternativeZone = mirroredZone == scouting.hotZone
            ? PitchZone(row: 0, column: 2)
            : mirroredZone
        let alternative = CatcherRecommendation(
            call: PitchCall(
                pitchType: alternativePitch,
                zone: alternativeZone,
                zoneIntent: ZoneIntent.clamped(protectZone ? .strike : .edge, for: alternativeZone),
                intensity: context.fatigue >= 60 ? .controlled : .normal
            ),
            confidence: ScoutingEstimate.adjustedConfidence(
                clamp(430 + (pitcher.stuff - 50) * 3, 300, 760),
                reliability: reliability
            ),
            reasonCodes: [
                "scouting.avoid_hot_zone",
                "sequence.change_speed",
                protectZone ? "count.avoid_walk" : "count.alternative"
            ]
        )
        return (primary, alternative)
    }

    /// 무엇을 던질지 고른다. **타자의 약점과 투수가 실제로 던질 수 있는 공을 저울질한다.**
    ///
    /// 예전에는 약점 구종을 거의 무조건 요구했다 — 개발 중인 구종일 때만 피했다. 그래서
    /// 던질 줄도 모르는 체인지업이 약점이면 계속 체인지업을 요구했고, 포수가 투수를 안 보는
    /// 것처럼 보였다. 실제 포수는 "이 타자가 약한 공"과 "이 투수가 제일 잘 던지는 공" 사이에서
    /// 고른다. 약점을 노리는 값어치를 점수로 매겨 주무기와 비교한다.
    private func recommendedPrimaryPitch(
        pitcher: PitcherSnapshot,
        desired: PitchType,
        twoStrikes: Bool = false,
        protectZone: Bool = false,
        lastPitchType: PitchType? = nil
    ) -> PitchType {
        guard let profiles = pitcher.pitchProfiles, !profiles.isEmpty else { return desired }

        /// 약점을 찌를 때 얹어 주는 값. 이만큼 못 미치는 주무기라면 약점을 노린다.
        /// 90은 세 항목 합계(command+whiff+weakContact) 기준이라 항목당 30 차이에 해당한다.
        let weaknessBonus = 90
        /// 직전 공과 같은 구종에 무는 값. 최고 구종이라도 연속으로 부르면 배합이 아니라
        /// 반복이다 — 이 감점 때문에 주무기·세컨드 구종이 자연스럽게 회전한다.
        /// 90(약점 보너스)보다 작게 둬서, 약점 구종이 압도적이면 반복도 감수한다.
        let repeatPenalty = 70

        func value(_ profile: PitchProfileSnapshot) -> Int {
            var score = profileScore(profile, pitcher: pitcher)
            if profile.pitchType == desired { score += weaknessBonus }
            // 아직 만들고 있는 구종은 승부처에서 쓰지 않는다.
            if profile.role == .development { score -= 120 }
            if profile.pitchType == lastPitchType { score -= repeatPenalty }
            // 카운트가 기준을 바꾼다. 2스트라이크면 헛스윙을 뽑는 공,
            // 3볼이면 존에 꽂을 수 있는 공 — 실제 포수의 저울이다.
            if twoStrikes { score += profile.whiff - 50 }
            if protectZone { score += profile.command - 50 }
            return score
        }

        return profiles.max { value($0) < value($1) }?.pitchType ?? desired
    }

    private func recommendedAlternativePitch(
        pitcher: PitcherSnapshot,
        excluding primary: PitchType,
        legacyDesired: PitchType
    ) -> PitchType {
        guard let profiles = pitcher.pitchProfiles else { return legacyDesired }
        return profiles
            .filter { $0.pitchType != primary && $0.role != .development }
            .max { profileScore($0, pitcher: pitcher) < profileScore($1, pitcher: pitcher) }?
            .pitchType ?? legacyDesired
    }

    private func profileScore(_ profile: PitchProfileSnapshot, pitcher: PitcherSnapshot) -> Int {
        var score = profile.command + profile.whiff + profile.weakContact
        switch PitcherBuildRules.identity(for: pitcher) {
        case .power:
            if profile.pitchType == .fourSeam { score += 35 + (pitcher.stuff - 50) * 2 }
            score += (profile.velocityTenthsKPH - 1_300) / 12
        case .command:
            score += profile.control - 50
            score += (profile.command - 50) * 2
        case .movement:
            if profile.pitchType != .fourSeam { score += 28 + (pitcher.movement - 50) * 2 }
            score += (profile.movement - 50) * 2
        case .stamina:
            score += max(0, 4 - profile.fatigueCost) * 10
            score += profile.control - 50
        }
        return score
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
