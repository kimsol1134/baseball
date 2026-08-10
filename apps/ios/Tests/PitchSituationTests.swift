import XCTest
import SimulationCore
@testable import BaseballIOS

/// 승부 화면이 "지금 어떤 상황인가"를 말하는 두 규칙 — 상황 한 마디와 긴장도.
@MainActor
final class PitchSituationTests: XCTestCase {
    private func runners(_ first: Bool, _ second: Bool, _ third: Bool) -> BaserunnerStateSnapshot {
        BaserunnerStateSnapshot(
            firstOccupied: first, secondOccupied: second, thirdOccupied: third, leadRunnerSpeed: 52
        )
    }

    func testSituationLineUsesTheWordsBaseballFansUse() {
        XCTAssertEqual(
            ScoreboardBar.situationLine(outs: 0, runners: runners(false, false, false)),
            "0사 주자 없음"
        )
        XCTAssertEqual(
            ScoreboardBar.situationLine(outs: 2, runners: runners(true, true, true)),
            "2사 만루"
        )
        XCTAssertEqual(
            ScoreboardBar.situationLine(outs: 1, runners: runners(true, false, true)),
            "1사 1루·3루"
        )
        XCTAssertEqual(
            ScoreboardBar.situationLine(outs: 1, runners: runners(false, true, false)),
            "1사 2루"
        )
    }

    /// 3아웃은 이닝이 끝난 상태라 화면에 뜨지 않지만, 값이 새더라도 "3사"라는 말을
    /// 만들어 내면 안 된다.
    func testSituationLineClampsOuts() {
        XCTAssertEqual(
            ScoreboardBar.situationLine(outs: 3, runners: runners(false, false, false)),
            "2사 주자 없음"
        )
    }

    /// 조여 오지 않는 이닝에서는 진동이 아예 걸리지 않아야 한다 — 상시 진동은 신호가
    /// 아니라 배경 소음이고, 정작 승부처에서 손이 알아채지 못한다.
    func testLowLeverageInningsNeverBuzz() {
        XCTAssertEqual(
            PitchView.tension(leverage: 500, runners: runners(true, true, true),
                              balls: 3, strikes: 2, outs: 2),
            0
        )
        XCTAssertEqual(
            PitchView.tension(leverage: 619, runners: runners(false, false, false),
                              balls: 0, strikes: 0, outs: 0),
            0
        )
    }

    /// 무게·주자·볼카운트가 겹칠수록 세진다. 순서가 뒤집히면 진동이 상황을 거꾸로 말한다.
    func testTensionRisesWithStakesRunnersAndCount() {
        let calm = PitchView.tension(leverage: 700, runners: runners(false, false, false),
                                     balls: 0, strikes: 0, outs: 0)
        let withRunner = PitchView.tension(leverage: 700, runners: runners(false, false, true),
                                           balls: 0, strikes: 0, outs: 0)
        let fullCount = PitchView.tension(leverage: 700, runners: runners(false, false, true),
                                          balls: 3, strikes: 2, outs: 0)
        let walkOff = PitchView.tension(leverage: 1_000, runners: runners(true, true, true),
                                        balls: 3, strikes: 2, outs: 2)
        XCTAssertGreaterThan(calm, 0)
        XCTAssertGreaterThan(withRunner, calm)
        XCTAssertGreaterThan(fullCount, withRunner)
        XCTAssertGreaterThan(walkOff, fullCount)
        XCTAssertLessThanOrEqual(walkOff, 1)
    }

    /// 중요도 배지는 레버리지 밴드를 그대로 옮긴다. 등급이 흔들리면 같은 이닝이 화면마다
    /// 다른 무게로 보인다.
    func testStakesBadgeMatchesTheLeverageBands() {
        XCTAssertEqual(StakesBadge.level(500), 0)
        XCTAssertEqual(StakesBadge.level(700), 1)
        XCTAssertEqual(StakesBadge.level(800), 2)
        XCTAssertEqual(StakesBadge.level(950), 3)
        XCTAssertEqual(StakesBadge.label(950), "여기서 끝난다")
    }

    /// 훈련 영수증의 첫 줄. **오르지 않은 훈련에도 문장이 있어야 한다** — 아무것도 안 뜨면
    /// 사용자는 버튼이 먹지 않은 것으로 읽는다.
    func testTrainingHeadlineAlwaysSaysSomething() {
        XCTAssertEqual(
            HighSchoolCareerStore.gainHeadline([
                .init(label: "구위", before: 44, after: 46),
                .init(label: "체력", before: 50, after: 51),
            ]),
            "구위 +2 · 체력 +1"
        )
        XCTAssertEqual(HighSchoolCareerStore.gainHeadline([]), "능력 변화 없음")
        XCTAssertEqual(
            HighSchoolCareerStore.gainHeadline([.init(label: "제구", before: 52, after: 52)]),
            "능력 변화 없음"
        )
    }
}
