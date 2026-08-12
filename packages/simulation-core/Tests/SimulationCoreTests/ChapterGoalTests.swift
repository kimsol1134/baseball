import XCTest
@testable import SimulationCore

final class ChapterGoalTests: XCTestCase {
    /// 같은 회차 같은 챕터 = 같은 숙제. 화면을 오갈 때마다 목표가 바뀌면 목표가 아니다.
    func testDeterministic() {
        XCTAssertEqual(ChapterGoal.goal(careerID: "c", chapterNumber: 2),
                       ChapterGoal.goal(careerID: "c", chapterNumber: 2))
        XCTAssertNotEqual(ChapterGoal.goal(careerID: "c", chapterNumber: 2),
                          ChapterGoal.goal(careerID: "c", chapterNumber: 3))
    }

    /// 챕터가 갈수록 숙제가 커지고, 목표는 늘 도달 가능한 범위에 있다.
    func testTargetsScaleAndStayReachable() {
        for chapter in 1...8 {
            let goal = ChapterGoal.goal(careerID: "scale", chapterNumber: chapter)
            XCTAssertGreaterThanOrEqual(goal.targetStrikeouts, 4)
            XCTAssertLessThanOrEqual(goal.targetStrikeouts, 10)
            XCTAssertFalse(goal.title.isEmpty)
            XCTAssertTrue(goal.detail.contains("\(goal.targetStrikeouts)"), "숙제 문장에 목표 숫자가 있어야 합니다.")
        }
        let early = ChapterGoal.goal(careerID: "s2", chapterNumber: 1).targetStrikeouts
        let late = ChapterGoal.goal(careerID: "s2", chapterNumber: 6).targetStrikeouts
        XCTAssertLessThanOrEqual(early, late + 2)
    }

    func testAllFourFramesRemainDeterministicAndExposeTypedPresentationIdentity() {
        var seen = Set<ChapterGoal.Frame>()
        for careerIndex in 0..<64 {
            for chapter in 1...8 {
                let careerID = "goal-frame-\(careerIndex)"
                let goal = ChapterGoal.goal(careerID: careerID, chapterNumber: chapter)
                XCTAssertEqual(
                    goal,
                    ChapterGoal.goal(careerID: careerID, chapterNumber: chapter),
                    "goal parity \(careerID):\(chapter)"
                )
                XCTAssertEqual(
                    ChapterGoalPresentationCatalog.descriptor(for: goal).frame,
                    goal.frame
                )
                seen.insert(goal.frame)
            }
        }
        XCTAssertEqual(seen, Set(ChapterGoal.Frame.allCases))
    }
}
