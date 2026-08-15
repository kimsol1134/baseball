import XCTest
import SimulationCore
@testable import BaseballIOS

/// 제스처 → 투구 품질 변환. 이 앱의 최고 자산인데 자동 테스트가 하나도 없었다.
///
/// `delivery(meter:aim:aimRadius:)`는 순수 함수다 — 미터 값과 조준 이탈만 받아 릴리스·조준
/// 점수를 만든다. 여기서 계약이 깨지면 손맛 전체가 조용히 무너지는데, UI 테스트는 전부
/// `-uiTestAutoRelease`로 이 경로를 우회하므로 아무도 알아채지 못한다.
@MainActor
final class DeliveryControlTests: XCTestCase {
    private let radius: CGFloat = 46

    func testManualSliderIsTheRegisteredAppDefaultWithoutOverwritingUserChoice() {
        let suiteName = "DeliveryControlTests.\(#function)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.removePersistentDomain(forName: suiteName)

        PitchControlPreferences.registerDefaults(in: defaults)
        XCTAssertFalse(defaults.bool(forKey: PitchControlPreferences.autoReleaseKey))

        defaults.set(true, forKey: PitchControlPreferences.autoReleaseKey)
        PitchControlPreferences.registerDefaults(in: defaults)
        XCTAssertTrue(
            defaults.bool(forKey: PitchControlPreferences.autoReleaseKey),
            "사용자가 켠 접근성용 자동 릴리스는 앱 기본값 등록이 덮어쓰면 안 됩니다."
        )
    }

    func testPerfectFeedbackLivesPastItsAnimationAndSequencesTheAccentSound() {
        let animationNanoseconds = UInt64(
            PerfectReleaseFeedback.animationDuration * 1_000_000_000
        )
        XCTAssertGreaterThan(
            PerfectReleaseFeedback.standardLifetimeNanoseconds,
            animationNanoseconds,
            "축하 레이어가 페이드 완료 전에 제거되면 마지막 프레임이 다시 잘립니다."
        )
        XCTAssertGreaterThan(
            PerfectReleaseFeedback.accentSoundDelayNanoseconds,
            110_000_000,
            "퍼펙트 축하음은 짧은 릴리스 소리가 끝난 뒤 이어져야 합니다."
        )
        XCTAssertLessThan(
            PerfectReleaseFeedback.accentSoundDelayNanoseconds,
            PerfectReleaseFeedback.reduceMotionLifetimeNanoseconds
        )
    }

    func testPerfectHapticIsNotImmediatelyOverwrittenByOutcomeHaptic() {
        XCTAssertFalse(PerfectReleaseFeedback.shouldPlayOutcomeHaptic(after: PitchDelivery(
            releaseAccuracy: PitchDelivery.perfectReleaseThreshold,
            aimAccuracy: 1_000
        )))
        XCTAssertTrue(PerfectReleaseFeedback.shouldPlayOutcomeHaptic(after: PitchDelivery(
            releaseAccuracy: PitchDelivery.perfectReleaseThreshold - 1,
            aimAccuracy: 1_000
        )))
        XCTAssertTrue(PerfectReleaseFeedback.shouldPlayOutcomeHaptic(after: .neutral))
    }

    func testPitchFeedbackTimelineSeparatesReleaseResultAndNextHeartbeat() {
        let cases: [(reduceMotion: Bool, clutch: Bool)] = [
            (false, false),
            (false, true),
            (true, false),
            (true, true),
        ]

        for value in cases {
            let result = PitchFeedbackTimeline.resultHapticDelay(
                reduceMotion: value.reduceMotion,
                isClutch: value.clutch
            )
            let heartbeat = PitchFeedbackTimeline.heartbeatResumeDelay(
                reduceMotion: value.reduceMotion,
                isClutch: value.clutch
            )
            XCTAssertGreaterThanOrEqual(result, 0.28, "릴리스 패턴이 끝나기 전에 결과 햅틱이 끼면 안 됩니다.")
            XCTAssertGreaterThan(
                heartbeat - result,
                0.5,
                "결과와 다음 심박 사이에 장면을 읽을 수 있는 정적이 필요합니다."
            )
        }
    }

    func testPitchFeedbackTimelineTracksReplayTempo() {
        XCTAssertEqual(
            PitchFeedbackTimeline.resultHapticDelay(reduceMotion: false, isClutch: false),
            0.92,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            PitchFeedbackTimeline.resultHapticDelay(reduceMotion: false, isClutch: true),
            0.92 * PitchFeedbackTimeline.clutchTempo,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            PitchFeedbackTimeline.resultHapticDelay(reduceMotion: true, isClutch: true),
            PitchFeedbackTimeline.reducedMotionCueInterval,
            accuracy: 0.000_001
        )
        XCTAssertGreaterThan(
            PitchFeedbackTimeline.heartbeatResumeDelay(reduceMotion: false, isClutch: false),
            PitchFeedbackTimeline.standardReplayDuration
        )
        XCTAssertGreaterThan(
            PitchFeedbackTimeline.heartbeatResumeDelay(reduceMotion: false, isClutch: true),
            PitchFeedbackTimeline.standardReplayDuration * PitchFeedbackTimeline.clutchTempo
        )
    }

    func testPitchFeedbackNanosecondConversionIsDeterministic() {
        XCTAssertEqual(PitchFeedbackTimeline.nanoseconds(0.28), 280_000_000)
        XCTAssertEqual(PitchFeedbackTimeline.nanoseconds(0.92), 920_000_000)
        XCTAssertEqual(PitchFeedbackTimeline.nanoseconds(-1), 0)
    }

    // MARK: - 릴리스

    func testMeterCenterIsPerfectRelease() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: .zero, aimRadius: radius)
        XCTAssertEqual(delivery.releaseAccuracy, 1_000)
    }

    func testMeterEndsAreWorstRelease() {
        XCTAssertEqual(DeliveryControl.delivery(meter: 0, aim: .zero, aimRadius: radius).releaseAccuracy, 0)
        XCTAssertEqual(DeliveryControl.delivery(meter: 1, aim: .zero, aimRadius: radius).releaseAccuracy, 0)
    }

    /// 중심에서 멀어질수록 단조 감소해야 한다. 어느 구간에서 되레 올라가면 "가운데에서 뗀다"는
    /// 규칙 자체가 거짓이 된다.
    func testReleaseFallsMonotonicallyFromCenter() {
        var previous = 1_001
        for step in 0...10 {
            let meter = 0.5 + Double(step) * 0.05
            let score = DeliveryControl.delivery(meter: meter, aim: .zero, aimRadius: radius).releaseAccuracy
            XCTAssertLessThanOrEqual(score, previous, "미터 \(meter)에서 릴리스가 다시 올라갔습니다.")
            previous = score
        }
    }

    /// 중심을 기준으로 좌우 대칭이다. 한쪽이 유리하면 미터를 외워서 한 방향으로만 노린다.
    func testReleaseIsSymmetricAroundCenter() {
        for step in 1...9 {
            let offset = Double(step) * 0.05
            XCTAssertEqual(
                DeliveryControl.delivery(meter: 0.5 - offset, aim: .zero, aimRadius: radius).releaseAccuracy,
                DeliveryControl.delivery(meter: 0.5 + offset, aim: .zero, aimRadius: radius).releaseAccuracy
            )
        }
    }

    func testFasterPitchHasFasterReleaseMeter() {
        let fourSeam = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_470, fatigue: 20
        )
        let curveball = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_180, fatigue: 20
        )
        XCTAssertLessThan(fourSeam, curveball)
    }

    func testFatigueSpeedsUpReleaseMeter() {
        let fresh = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_350, fatigue: 0
        )
        let tired = DeliveryControl.sweepSeconds(
            velocityTenthsKPH: 1_350, fatigue: 100
        )
        XCTAssertLessThan(tired, fresh)
    }

    func testFatigueAlsoIncreasesAimSway() {
        let fresh = DeliveryControl.swayAmplitude(fatigue: 0)
        let tired = DeliveryControl.swayAmplitude(fatigue: 100)
        XCTAssertGreaterThan(tired, fresh)
    }

    func testReduceMotionSoftensAimSwayAndSlowsMeter() {
        XCTAssertLessThan(
            DeliveryControl.swayAmplitude(fatigue: 60, reduceMotion: true),
            DeliveryControl.swayAmplitude(fatigue: 60)
        )
        XCTAssertGreaterThan(
            DeliveryControl.sweepSeconds(
                velocityTenthsKPH: 1_350,
                fatigue: 60,
                reduceMotion: true
            ),
            DeliveryControl.sweepSeconds(velocityTenthsKPH: 1_350, fatigue: 60)
        )
    }

    // MARK: - 조준

    func testAimOnTargetIsPerfect() {
        XCTAssertEqual(DeliveryControl.delivery(meter: 0.5, aim: .zero, aimRadius: radius).aimAccuracy, 1_000)
    }

    func testAimAtRadiusIsZero() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: radius, height: 0), aimRadius: radius)
        XCTAssertEqual(delivery.aimAccuracy, 0)
    }

    /// 반경 밖으로 더 끌어도 0 아래로 내려가지 않는다(그리고 음수 점수가 커널에 새지 않는다).
    func testAimBeyondRadiusClampsToZero() {
        let delivery = DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: radius * 4, height: radius * 4), aimRadius: radius)
        XCTAssertEqual(delivery.aimAccuracy, 0)
    }

    /// 이탈은 방향이 아니라 거리로만 잰다. 대각선 이탈이 같은 거리의 수평 이탈과 같아야 한다.
    func testAimUsesDistanceNotAxis() {
        let diagonal = radius / CGFloat(2.0.squareRoot())
        XCTAssertEqual(
            DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: diagonal, height: diagonal), aimRadius: radius).aimAccuracy,
            DeliveryControl.delivery(meter: 0.5, aim: CGSize(width: radius, height: 0), aimRadius: radius).aimAccuracy,
            accuracy: 1
        )
    }

    // MARK: - 판정 문구

    func testVerdictBandsMatchScores() {
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 900, aimAccuracy: 900))?.text, "완벽한 릴리스")
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 700, aimAccuracy: 700))?.text, "좋은 릴리스")
        // 정확히 500/500은 자동 릴리스의 중립값이라 판정이 없다(아래 테스트). 손으로 만든
        // 무난한 공을 보려면 그 값을 피해야 한다.
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 520, aimAccuracy: 480))?.text, "무난한 릴리스")
        XCTAssertEqual(DeliveryControl.verdict(PitchDelivery(releaseAccuracy: 100, aimAccuracy: 100))?.text, "손에서 빠졌습니다")
    }

    /// 자동 릴리스(접근성 경로)로 던진 공은 판정을 내지 않는다. 손으로 만든 결과가 아니다.
    func testNeutralDeliveryHasNoVerdict() {
        XCTAssertNil(DeliveryControl.verdict(.neutral))
    }

    func testAutomaticReleaseDoesNotCountAsManualMastery() {
        XCTAssertNil(DeliveryControl.score(.neutral))
        XCTAssertEqual(
            DeliveryControl.score(PitchDelivery(releaseAccuracy: 900, aimAccuracy: 700)),
            800
        )
    }

    func testCoachingHintNamesTheWeakerManualAxis() {
        XCTAssertEqual(
            DeliveryControl.coachingHint(PitchDelivery(releaseAccuracy: 300, aimAccuracy: 800)),
            "미터를 크게 놓쳤습니다 — 초록 구간에서 떼세요"
        )
        XCTAssertEqual(
            DeliveryControl.coachingHint(PitchDelivery(releaseAccuracy: 800, aimAccuracy: 300)),
            "조준이 크게 흔들렸습니다 — 손가락을 과녁에 머무르게 하세요"
        )
    }
}

/// 코스 이름은 타자 기준이다. 좌타자에게는 몸쪽·바깥쪽이 뒤집힌다.
final class PitchCopyZoneTests: XCTestCase {
    func testRightHandedLabelsAreUnchanged() {
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 0, column: 0), batSide: .right), "높은 몸쪽")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 2, column: 2), batSide: .right), "낮은 바깥쪽")
    }

    func testLeftHandedLabelsMirrorColumns() {
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 0, column: 0), batSide: .left), "높은 바깥쪽")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 2, column: 2), batSide: .left), "낮은 몸쪽")
    }

    /// 가운데 열은 어느 쪽 타자에게도 가운데다.
    func testMiddleColumnIsSideIndependent() {
        for row in 0..<3 {
            XCTAssertEqual(
                PitchCopy.zone(PitchZone(row: row, column: 1), batSide: .left),
                PitchCopy.zone(PitchZone(row: row, column: 1), batSide: .right)
            )
        }
    }

    /// 아무것도 결정하지 않은 공에는 진동을 주지 않는다.
    func testNeutralOutcomesDoNotBuzz() {
        XCTAssertNil(PitchCopy.hapticSuccess(.ball))
        XCTAssertNil(PitchCopy.hapticSuccess(.foul))
        XCTAssertEqual(PitchCopy.hapticSuccess(.swingingStrike), true)
        XCTAssertEqual(PitchCopy.hapticSuccess(.homeRun), false)
    }
}
