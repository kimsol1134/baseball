import XCTest
@testable import SimulationCore

/// 자책점 원장은 실제 야구의 재구성 규칙을 따른다. 여기서 검사하는 것은 숫자 하나가 아니라
/// "이 주자는 누구 책임인가"라는 질문에 원장이 매번 같은 답을 내는가다.
final class PitchRunLedgerTests: XCTestCase {

    /// 커널을 통과시키지 않고 결과만 지정한 한 투구. 원장은 커널이 보고한 결과·주자·아웃만
    /// 읽으므로, 투구 물리를 끼워 넣으면 검사하려는 규칙이 난수에 가려진다.
    private func play(
        outcome: PitchOutcome,
        result: PlateAppearanceResult?,
        after: BaserunnerStateSnapshot,
        runs: Int,
        outsRecorded: Int = 0,
        doublePlayCompleted: Bool = false,
        inningEnded: Bool = false,
        stealAttempt: StealAttemptSnapshot? = nil
    ) -> PlateAppearanceSnapshot {
        let inning = InningStateSnapshot(inning: 1, half: .top, outs: 0)
        return PlateAppearanceSnapshot(
            revision: 1, balls: 0, strikes: 0, pitchNumber: 1, ended: result != nil,
            result: result, outcome: outcome, selectionQuality: .good,
            recommendationAccepted: true, fatigueAfterPitch: 10,
            execution: PitchExecution(
                targetX: 0, targetY: 0, actualX: 0, actualY: 0,
                velocityTenthsKPH: 1_400, horizontalBreakTenthsCM: 0,
                verticalBreakTenthsCM: 0, executionQuality: 500
            ),
            battedBall: nil,
            runnersAfter: after,
            runsScored: runs,
            stealAttempt: stealAttempt,
            inningTransition: InningTransitionSnapshot(
                before: inning, after: inning, outsRecorded: outsRecorded,
                doublePlayCompleted: doublePlayCompleted, inningEnded: inningEnded,
                shortExplanation: ""
            ),
            reasonCodes: [], shortFeedback: "", detailFeedback: "", accessibilitySummary: ""
        )
    }

    /// 승계 주자가 먼저 홈을 밟는다. 앞선 투수의 실점이지 구원 투수의 실점이 아니다.
    func testInheritedRunnerScoresBeforeOwnedRunnerWithoutChargingReliever() throws {
        let entry = PitchRunLedger.entry(
            runners: BaserunnerStateSnapshot(
                firstOccupied: false, secondOccupied: true, thirdOccupied: false, leadRunnerSpeed: 50
            )
        )
        let single = try entry.advance(play(
            outcome: .single, result: .hit,
            after: BaserunnerStateSnapshot(
                firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 50
            ),
            runs: 1
        ))
        XCTAssertEqual(single.inheritedScored, 1)
        XCTAssertEqual(single.runs, 0)

        let homer = try single.advance(play(
            outcome: .homeRun, result: .hit, after: .empty, runs: 2
        ))
        XCTAssertEqual(homer.runs, 2)
        XCTAssertEqual(homer.earnedRuns, 2)
        XCTAssertEqual(homer.inheritedScored, 1)
        XCTAssertEqual(PitchRunLedger.decode(homer.token()), homer)
    }

    /// 밀어내기에서도 각 주자의 꼬리표가 한 베이스씩 같이 밀린다.
    func testWalkAndUnearnedRunnerRetainResponsibility() throws {
        let loaded = PitchRunLedger(bases: [1, 2, -1])
        let walk = try loaded.advance(play(
            outcome: .ball, result: .walk,
            after: BaserunnerStateSnapshot(
                firstOccupied: true, secondOccupied: true, thirdOccupied: true, leadRunnerSpeed: 50
            ),
            runs: 1
        ))
        XCTAssertEqual(walk.bases, [1, 1, 2])
        XCTAssertEqual(walk.inheritedScored, 1)

        let homer = try walk.advance(play(
            outcome: .homeRun, result: .hit, after: .empty, runs: 4
        ))
        XCTAssertEqual(homer.runs, 4)
        XCTAssertEqual(homer.earnedRuns, 3)
    }

    /// 실책으로 나간 주자가 도루하다 잡힌 것은 깨끗한 이닝에는 없던 아웃이다.
    func testCaughtStealingByAnErrorRunnerIsNotAnExtraCounterfactualOut() throws {
        let attempt = play(
            outcome: .ball, result: nil, after: .empty, runs: 0, outsRecorded: 1,
            stealAttempt: StealAttemptSnapshot(
                fromBase: 1, toBase: 2, runnerSpeed: 50, catcherArm: 50,
                succeeded: false, shortExplanation: ""
            )
        )
        let result = try PitchRunLedger(bases: [2, 0, 0], virtualOuts: 1).advance(attempt)
        XCTAssertEqual(result.virtualOuts, 1)
        XCTAssertEqual(result.bases, [0, 0, 0])
    }

    /// 2아웃 뒤 실책이면 깨끗한 이닝은 이미 끝났다. 그 뒤 홈런은 실점이되 자책점이 아니다.
    func testTwoOutErrorMakesTheFollowingHomeRunUnearned() throws {
        let error = play(
            outcome: .reachedOnError, result: .reachedOnError,
            after: BaserunnerStateSnapshot(
                firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 50
            ),
            runs: 0
        )
        let afterError = try PitchRunLedger(virtualOuts: 2).advance(error)
        XCTAssertEqual(afterError.bases, [2, 0, 0])

        let homer = try afterError.advance(play(
            outcome: .homeRun, result: .hit, after: .empty, runs: 2
        ))
        XCTAssertEqual(homer.runs, 2)
        XCTAssertEqual(homer.earnedRuns, 0)
        XCTAssertEqual(PitchRunLedger.decode(homer.token()), homer)
    }

    /// 병살은 1루 주자를 지우고, 세 번째 아웃은 남은 주자를 그대로 잔루로 남긴다.
    func testDoublePlayRemovesFirstRunnerAndThirdOutStrandsOthers() throws {
        let dp = try PitchRunLedger(bases: [1, -1, 2]).advance(play(
            outcome: .inPlayOut, result: .inPlayOut,
            after: BaserunnerStateSnapshot(
                firstOccupied: false, secondOccupied: true, thirdOccupied: true, leadRunnerSpeed: 50
            ),
            runs: 0, outsRecorded: 2, doublePlayCompleted: true
        ))
        XCTAssertEqual(dp.bases, [0, -1, 2])

        let ended = try dp.advance(play(
            outcome: .inPlayOut, result: .inPlayOut, after: .empty, runs: 0, inningEnded: true
        ))
        XCTAssertEqual(ended.bases, [0, 0, 0])
        XCTAssertEqual(ended.runs, 0)
    }

    /// 원장이 없던 시절의 토큰은 여섯 칸이다. 그대로 읽히고, 가상 아웃은 0으로 시작한다.
    func testLegacySixValueTokenDecodes() {
        XCTAssertEqual(
            PitchRunLedger.decode("1,0,-1,3,2,1"),
            PitchRunLedger(bases: [1, 0, -1], runs: 3, earnedRuns: 2, inheritedScored: 1)
        )
        XCTAssertNil(PitchRunLedger.decode("1,0,-1,3,2"))
        XCTAssertNil(PitchRunLedger.decode("9,0,0,0,0,0"))
        XCTAssertNil(PitchRunLedger.decode("1,0,0,1,2,0"))
    }
}
