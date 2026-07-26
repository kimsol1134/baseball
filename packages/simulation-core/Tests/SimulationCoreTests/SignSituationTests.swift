import XCTest
@testable import SimulationCore

/// 포수 사인의 상황 정책. 순수 함수라 표 그대로 단정할 수 있다.
///
/// 이 검사가 없으면 "카운트에 따라 달라진다"가 말로만 남고, 실제로는 예전처럼 타석 내내 같은
/// 코스를 부르는 상태로 조용히 되돌아갈 수 있다.
final class SignSituationTests: XCTestCase {

    private func context(balls: Int, strikes: Int, outs: Int = 0) -> PlateAppearanceContext {
        PlateAppearanceContext(
            plateAppearanceID: "pa-1",
            revision: 1,
            inning: 5,
            outs: outs,
            balls: balls,
            strikes: strikes,
            pitchNumber: balls + strikes + 1,
            scoreDifferential: 0,
            leverage: 500,
            fatigue: 20
        )
    }

    private func state(first: Bool = false, second: Bool = false, third: Bool = false) -> GameStateSnapshot {
        GameStateSnapshot(
            defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
            park: ParkSnapshot(id: "park", name: "구장", hitFactor: 100, homeRunFactor: 100),
            runners: BaserunnerStateSnapshot(
                firstOccupied: first, secondOccupied: second, thirdOccupied: third, leadRunnerSpeed: 50
            ),
            runsAllowed: 0
        )
    }

    /// 3볼 노스트라이크에서는 볼넷을 주지 않는 것이 유일한 목표다. 한복판을 부른다.
    func testThreeBallsCallsTheMiddle() {
        let situation = SignSituation(context: context(balls: 3, strikes: 0), gameState: nil, lastPitch: nil)
        let zone = situation.shift(PitchZone(row: 0, column: 0))
        XCTAssertEqual(zone, PitchZone(row: 1, column: 1))
        XCTAssertEqual(situation.zoneIntent(protectZone: true, twoStrikes: false), .strike)
        XCTAssertTrue(situation.demandsControl)
        XCTAssertEqual(situation.countCode, "count.avoid_walk")
    }

    /// 투수가 앞서면 존 밖으로 뺀다.
    func testPitcherAheadChasesOutOfZone() {
        let situation = SignSituation(context: context(balls: 0, strikes: 2), gameState: nil, lastPitch: nil)
        XCTAssertEqual(situation.zoneIntent(protectZone: false, twoStrikes: true), .chase)
        // 낮은 쪽으로 한 칸 빠진다.
        XCTAssertEqual(situation.shift(PitchZone(row: 0, column: 1)).row, 1)
        XCTAssertEqual(situation.countCode, "count.pitcher_ahead")
    }

    /// 타자가 앞서면 존 안에서 승부한다. 가장자리를 노리다 볼이 되면 더 불리해진다.
    func testPitcherBehindComesIntoTheZone() {
        let situation = SignSituation(context: context(balls: 2, strikes: 0), gameState: nil, lastPitch: nil)
        XCTAssertEqual(situation.zoneIntent(protectZone: false, twoStrikes: false), .strike)
        XCTAssertEqual(situation.shift(PitchZone(row: 0, column: 2)), PitchZone(row: 1, column: 1))
        XCTAssertTrue(situation.demandsControl)
        XCTAssertEqual(situation.countCode, "count.pitcher_behind")
    }

    /// 초구는 카운트 선점. 가장자리를 노리되 코스를 옮기지 않는다.
    func testFirstPitchKeepsTheScoutedZone() {
        let situation = SignSituation(context: context(balls: 0, strikes: 0), gameState: nil, lastPitch: nil)
        XCTAssertEqual(situation.shift(PitchZone(row: 0, column: 2)), PitchZone(row: 0, column: 2))
        XCTAssertEqual(situation.zoneIntent(protectZone: false, twoStrikes: false), .edge)
        XCTAssertEqual(situation.countCode, "count.first_pitch")
    }

    /// 1루 주자·2아웃 미만이면 낮은 존으로 병살을 노린다.
    func testRunnerOnFirstSetsUpTheDoublePlay() {
        let situation = SignSituation(
            context: context(balls: 1, strikes: 1, outs: 1),
            gameState: state(first: true),
            lastPitch: nil
        )
        XCTAssertTrue(situation.doublePlayChance)
        XCTAssertGreaterThanOrEqual(situation.shift(PitchZone(row: 0, column: 1)).row, 1)
        XCTAssertTrue(situation.extraReasonCodes.contains("runners.double_play_setup"))
    }

    /// 2아웃이면 병살이 없다. 낮은 존을 강요하지 않는다.
    func testTwoOutsDropsTheDoublePlaySetup() {
        let situation = SignSituation(
            context: context(balls: 1, strikes: 1, outs: 2),
            gameState: state(first: true),
            lastPitch: nil
        )
        XCTAssertFalse(situation.doublePlayChance)
        XCTAssertEqual(situation.shift(PitchZone(row: 0, column: 1)), PitchZone(row: 0, column: 1))
    }

    /// 3루 주자가 있으면 높은 공을 피한다. 뜬공 하나에 점수가 난다.
    func testRunnerOnThirdAvoidsHighPitches() {
        let situation = SignSituation(
            context: context(balls: 1, strikes: 0, outs: 1),
            gameState: state(third: true),
            lastPitch: nil
        )
        XCTAssertTrue(situation.sacrificeFlyRisk)
        XCTAssertGreaterThanOrEqual(situation.shift(PitchZone(row: 0, column: 0)).row, 1)
        XCTAssertTrue(situation.extraReasonCodes.contains("runners.suppress_sacrifice_fly"))
    }

    /// 장타를 맞은 다음에는 같은 공을 또 주지 않는다.
    func testRepeatIsAvoidedAfterExtraBaseHit() {
        for outcome in [PitchOutcome.double, .triple, .homeRun, .single] {
            let situation = SignSituation(
                context: context(balls: 0, strikes: 0),
                gameState: nil,
                lastPitch: entry(outcome: outcome)
            )
            XCTAssertTrue(situation.avoidsRepeat, "\(outcome) 뒤에는 구종을 바꿔야 합니다.")
        }
    }

    /// 2스트라이크에서 파울로 커트당하면 타이밍이 맞아 가는 중이다. 구종을 바꾼다.
    func testFoulWithTwoStrikesChangesThePitch() {
        let cut = SignSituation(
            context: context(balls: 1, strikes: 2),
            gameState: nil,
            lastPitch: entry(outcome: .foul)
        )
        XCTAssertTrue(cut.avoidsRepeat)
        // 스트라이크가 하나뿐이면 아직 유인 중이라 굳이 바꾸지 않는다.
        let early = SignSituation(
            context: context(balls: 1, strikes: 1),
            gameState: nil,
            lastPitch: entry(outcome: .foul)
        )
        XCTAssertFalse(early.avoidsRepeat)
    }

    private func entry(outcome: PitchOutcome) -> PitchAnalysisEntry {
        PitchAnalysisEntry(
            pitchType: .fourSeam,
            wasInZone: true,
            batterSwung: true,
            outcome: outcome,
            selectionQuality: .good,
            executionQuality: 600,
            contactQuality: 500,
            expectedDamage: 100,
            actualDamage: 100,
            recommendationAccepted: true
        )
    }
}
