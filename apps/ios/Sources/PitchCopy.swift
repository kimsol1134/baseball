import SwiftUI
import SimulationCore

enum PitchCopy {
    static let zoneLabels = [
        "높은 몸쪽", "높은 가운데", "높은 바깥쪽",
        "가운데 몸쪽", "가운데", "가운데 바깥쪽",
        "낮은 몸쪽", "낮은 가운데", "낮은 바깥쪽"
    ]

    /// 코스 이름. **몸쪽·바깥쪽은 타자 기준이라 좌타자에게는 뒤집힌다.**
    ///
    /// 라벨 표가 우타 기준으로 고정돼 있었다. 좌타자를 상대할 때 화면은 몸쪽을 바깥쪽이라
    /// 부르고 있었고, 이 게임에서 코스는 판정의 절반이라 그 표기가 틀리면 플레이어가
    /// 배우는 규칙 자체가 틀린다.
    static func zone(_ zone: PitchZone, batSide: BatSide = .right) -> String {
        let column = batSide == .left ? 2 - zone.column : zone.column
        let index = zone.row * 3 + column
        return zoneLabels.indices.contains(index) ? zoneLabels[index] : "알 수 없는 코스"
    }

    static func localized(_ zone: PitchZone, batSide: BatSide = .right, resolver: GameCopyResolver) -> String {
        PitchPresentation.zone(zone, batSide: batSide, resolver: resolver)
    }

    /// 타석에 선 쪽. 좌우 플래툰은 커널이 이미 계산하는데 화면에 표기가 없었다.
    static func batSide(_ side: BatSide) -> String {
        side == .left ? "좌타" : "우타"
    }

    static func localized(_ side: BatSide, resolver: GameCopyResolver) -> String {
        resolver.resolve(side.displayCopyToken)
    }

    static func pitch(_ type: PitchType) -> String {
        switch type {
        case .fourSeam: "포심"
        case .slider: "슬라이더"
        case .curveball: "커브"
        case .changeup: "체인지업"
        }
    }

    static func localized(_ type: PitchType, resolver: GameCopyResolver) -> String {
        resolver.resolve(type.displayCopyToken)
    }

    static func intent(_ intent: ZoneIntent) -> String {
        switch intent {
        case .strike: "존 안으로"
        case .edge: "존 경계"
        case .chase: "존 밖 유인"
        }
    }

    static func localized(_ intent: ZoneIntent, resolver: GameCopyResolver) -> String {
        resolver.resolve(intent.displayCopyToken)
    }

    /// 노림 설명은 코스에 따라 달라진다.
    ///
    /// "볼 유도"를 한복판에서 고르면 공은 낮은 쪽으로 빠진다 — 커널이 그렇게 던진다.
    /// 화면이 그 말을 안 하면 플레이어는 한복판에 볼을 던진다고 읽는다.
    static func intentDetail(_ intent: ZoneIntent, zone: PitchZone) -> String {
        switch intent {
        case .strike: "스트라이크 확률이 높고 맞을 위험도 함께 커집니다."
        case .edge: "경계를 노려 배트를 늦추지만 제구 난도가 높습니다."
        case .chase:
            ZoneIntent.options(for: zone).count == 2
                ? "한복판에서는 낮은 쪽으로 빼는 공이 됩니다. 헛스윙을 노리는 대신 볼이 될 확률이 큽니다."
                : "고른 코스 바깥으로 빼서 헛스윙을 노리는 대신 볼이 될 확률이 큽니다."
        }
    }

    static func localizedIntentDetail(
        _ intent: ZoneIntent,
        zone: PitchZone,
        resolver: GameCopyResolver
    ) -> String {
        PitchPresentation.intentDetail(intent, zone: zone, resolver: resolver)
    }

    static func intensity(_ intensity: PitchIntensity) -> String {
        switch intensity {
        case .controlled: "힘 빼고"
        case .normal: "보통"
        case .maxEffort: "전력"
        }
    }

    static func localized(_ intensity: PitchIntensity, resolver: GameCopyResolver) -> String {
        resolver.resolve(intensity.displayCopyToken)
    }

    static func outcome(_ outcome: PitchOutcome) -> String {
        switch outcome {
        case .ball: "볼"
        case .calledStrike: "루킹 스트라이크"
        case .swingingStrike: "헛스윙"
        case .foul: "파울"
        case .inPlayOut: "인플레이 아웃"
        case .single: "안타"
        case .double: "2루타"
        case .triple: "3루타"
        case .homeRun: "홈런"
        case .hitByPitch: "몸에 맞는 공"
        }
    }

    static func localized(
        _ outcome: PitchOutcome,
        battedBall: BattedBall? = nil,
        resolver: GameCopyResolver
    ) -> String {
        // The legacy Korean overload retains the more specific batted-ball wording. The closed
        // outcome token is the language-neutral fallback for English and other supported locales.
        if resolver.language == .korean {
            return Self.outcome(outcome, battedBall: battedBall)
        }
        return resolver.resolve(outcome.displayCopyToken)
    }

    /// 타구가 있으면 "인플레이 아웃" 대신 타구 종류로 말한다(QA P2-4).
    /// 엔진 용어는 정확하지만 야구 팬의 언어가 아니다.
    static func outcome(_ outcome: PitchOutcome, battedBall: BattedBall?) -> String {
        guard outcome == .inPlayOut, let ball = battedBall else { return Self.outcome(outcome) }
        if ball.launchAngleTenthsDegrees < 100 { return "땅볼 아웃" }
        if ball.launchAngleTenthsDegrees < 250 { return "직선타 아웃" }
        return "뜬공 아웃"
    }

    static func plateResult(_ result: PlateAppearanceResult) -> String {
        switch result {
        case .strikeout: "삼진"
        case .walk: "볼넷"
        case .inPlayOut: "아웃"
        case .hit: "피안타"
        }
    }

    /// 손으로 구분할 결과. `nil`이면 진동하지 않는다.
    ///
    /// 파울과 볼은 아무것도 결정하지 않은 공이다. 매 투구마다 울리면 진동은 신호가 아니라
    /// 소음이 되고, 정말 중요한 공(삼진·피안타)에서 손이 알아채지 못한다.
    static func hapticSuccess(_ outcome: PitchOutcome) -> Bool? {
        switch outcome {
        case .calledStrike, .swingingStrike, .inPlayOut: true
        case .single, .double, .triple, .homeRun, .hitByPitch: false
        case .ball, .foul: nil
        }
    }

    /// 타자가 내 투구를 얼마나 읽었는가. 이 게임의 전략적 정체성("같은 공을 반복하면
    /// 읽힌다")인데 iOS에는 이 값이 화면에 한 번도 나오지 않았다.
    static func adaptation(_ band: RivalAdaptationBand) -> String {
        switch band {
        case .noData: "아직 못 읽음"
        case .watching: "지켜보는 중"
        case .learning: "읽어 가는 중"
        case .lockedOn: "완전히 읽힘"
        }
    }

    static func localized(_ band: RivalAdaptationBand, resolver: GameCopyResolver) -> String {
        PitchPresentation.adaptation(band, resolver: resolver)
    }

    static func adaptationTone(_ band: RivalAdaptationBand) -> Color {
        switch band {
        case .noData, .watching: BaseballTheme.positive
        case .learning: BaseballTheme.warning
        case .lockedOn: BaseballTheme.negative
        }
    }

    static func confidence(_ band: AnalysisConfidenceBand) -> String {
        switch band {
        case .low: "표본이 적습니다"
        case .developing: "쌓이는 중"
        case .reliable: "믿을 만합니다"
        }
    }

    static func localized(_ band: AnalysisConfidenceBand, resolver: GameCopyResolver) -> String {
        PitchPresentation.confidence(band, resolver: resolver)
    }

    /// 천분율을 백분율 문구로. 코어는 전부 ‰로 준다.
    static func rate(_ permille: Int) -> String {
        String(format: "%.1f%%", Double(permille) / 10)
    }

    static func scoutBand(_ band: String) -> String {
        switch band {
        case "trusted": "확실한 분석"
        case "developing": "쌓이는 중"
        default: "아직 감"
        }
    }


    static func localizedScoutBand(_ band: String, resolver: GameCopyResolver) -> String {
        PitchPresentation.scoutBand(band, resolver: resolver)
    }
}

/// 현재 선수 능력과 구종 프로필이 실제 투구 판정에 들어가는 값의 번역.
/// 숫자는 `PitchAbilityRules`가 엔진 식에서 직접 주고, 화면은 야구 말로만 바꾼다.
enum PitchBuildCopy {
    static func velocity(_ tenthsKPH: Int) -> String {
        String(format: "%.1f", Double(tenthsKPH) / 10)
    }

    static func moment(_ kind: PitchAbilityKind, readout: PitchAbilityReadout) -> String {
        switch kind {
        case .power:
            "키운 구위가 살아난 공 · 구위 \(readout.stuffRating) · 헛스윙 \(readout.whiffRating)"
        case .command:
            "키운 제구가 살아난 공 · 코스 \(readout.commandRating)"
        case .movement:
            "키운 변화가 살아난 공 · 움직임 \(readout.movementRating) · 범타 \(readout.weakContactRating)"
        case .stamina:
            "키운 체력이 버틴 공 · 피로 \(readout.rawFatigue)→\(readout.effectiveFatigue)"
        }
    }

    static func localizedMoment(
        _ kind: PitchAbilityKind,
        readout: PitchAbilityReadout,
        resolver: GameCopyResolver
    ) -> String {
        PitchPresentation.abilityMoment(kind, readout: readout, resolver: resolver)
    }

    static func accessibilitySummary(_ readout: PitchAbilityReadout) -> String {
        "기준 구속 \(velocity(readout.nominalVelocityTenthsKPH))킬로미터, "
            + "코스 \(readout.commandRating), 움직임 \(readout.movementRating), "
            + "체력 \(readout.staminaRating), 피로 \(readout.rawFatigue)에서 체감 \(readout.effectiveFatigue), "
            + "한 구 팔 부담 \(readout.fatigueCost). \(synergy(readout))"
    }

    static func localizedAccessibilitySummary(_ readout: PitchAbilityReadout, resolver: GameCopyResolver) -> String {
        PitchPresentation.buildSummary(readout, resolver: resolver)
    }

    static func identity(_ readout: PitchAbilityReadout) -> PitcherBuildIdentity {
        PitchAbilityRules.identity(for: readout)
    }

    static func synergy(_ readout: PitchAbilityReadout) -> String {
        switch identity(readout) {
        case .power:
            readout.pitchType == .fourSeam
                ? "강속구형 시너지 · 포심 구속과 헛스윙을 살립니다."
                : "강속구형 보조구 · 포심과의 속도 차를 만듭니다."
        case .command: "정밀 제구형 시너지 · 노린 코스에 붙이는 공입니다."
        case .movement:
            readout.pitchType == .fourSeam
                ? "변화구형 연결구 · 결정구를 위한 포심입니다."
                : "변화구형 시너지 · 움직임과 범타를 살립니다."
        case .stamina: "이닝 소화형 시너지 · 누적 피로 \(readout.effectiveFatigue)로 억제 중입니다."
        }
    }

    static func localizedSynergy(_ readout: PitchAbilityReadout, resolver: GameCopyResolver) -> String {
        PitchPresentation.buildSynergy(readout, resolver: resolver)
    }
}

/// 퍼펙트 릴리스 피드백의 시간·감각 계약.
///
/// 시각 효과는 한 프레임이라도 실제로 그려진 뒤 사라져야 하고, 릴리스 소리 뒤에 축하음이
/// 이어져야 한다. 결과 햅틱을 같은 순간에 한 번 더 치면 고유한 퍼펙트 패턴이 뭉개진다.
enum PerfectReleaseFeedback {
    static let animationDuration: TimeInterval = 0.62
    static let standardLifetimeNanoseconds: UInt64 = 720_000_000
    static let reduceMotionLifetimeNanoseconds: UInt64 = 550_000_000
    /// 기본 릴리스 소리(약 0.11초)가 끝난 뒤 축하음이 이어지는 간격.
    static let accentSoundDelayNanoseconds: UInt64 = 120_000_000

    static func lifetimeNanoseconds(reduceMotion: Bool) -> UInt64 {
        reduceMotion ? reduceMotionLifetimeNanoseconds : standardLifetimeNanoseconds
    }

    static func shouldPlayOutcomeHaptic(after delivery: PitchDelivery?) -> Bool {
        delivery?.isPerfectRelease != true
    }
}

/// 릴리스 뒤 촉감의 순서. 화면·소리와 같은 야구 장면을 공유해야 손에서 사건의 원인이 읽힌다.
///
/// 릴리스는 손을 뗀 즉시, 결과는 공이 포수 미트나 배트에 닿을 때, 다음 심박은 장면이 끝나고
/// 다시 배합을 고르는 순간에 온다. 이 간격을 한곳에 두어 리플레이와 햅틱이 따로 drift하지 않는다.
enum PitchFeedbackTimeline {
    static let reducedMotionCueInterval: TimeInterval = 0.28
    static let standardContactDelay: TimeInterval = 0.92
    static let standardReplayDuration: TimeInterval = 1.6
    static let clutchTempo = 1.625
    static let reducedMotionDecisionDelay: TimeInterval = 1.2
    static let standardDecisionDelay: TimeInterval = 1.7
    static let clutchDecisionDelay: TimeInterval = 2.9

    static func tempo(isClutch: Bool) -> Double {
        isClutch ? clutchTempo : 1
    }

    static func resultHapticDelay(reduceMotion: Bool, isClutch: Bool) -> TimeInterval {
        reduceMotion ? reducedMotionCueInterval : standardContactDelay * tempo(isClutch: isClutch)
    }

    static func heartbeatResumeDelay(reduceMotion: Bool, isClutch: Bool) -> TimeInterval {
        if reduceMotion { return reducedMotionDecisionDelay }
        return isClutch ? clutchDecisionDelay : standardDecisionDelay
    }

    static func nanoseconds(_ interval: TimeInterval) -> UInt64 {
        UInt64((max(0, interval) * 1_000_000_000).rounded())
    }
}

