import XCTest
@testable import SimulationCore

final class PersonalityTests: XCTestCase {
    /// 두어 번의 대화로 사람을 규정하면 점괘다 — 5번 전에는 성격이 없다.
    func testNoPersonalityBeforeThreshold() {
        XCTAssertNil(PersonalityRules.personality(listen: 2, explain: 2, challenge: 0))
        XCTAssertNotNil(PersonalityRules.personality(listen: 2, explain: 2, challenge: 1))
    }

    /// 한 축이 45% 이상 기울면 그쪽 성격, 아니면 균형형.
    func testDominanceDecidesTheType() {
        XCTAssertEqual(PersonalityRules.personality(listen: 1, explain: 1, challenge: 4)?.title, "불같은 승부사")
        XCTAssertEqual(PersonalityRules.personality(listen: 4, explain: 1, challenge: 1)?.title, "조용한 버팀목")
        XCTAssertEqual(PersonalityRules.personality(listen: 1, explain: 4, challenge: 1)?.title, "차가운 분석가")
        XCTAssertEqual(PersonalityRules.personality(listen: 2, explain: 2, challenge: 2)?.title, "유연한 중심")
    }

    /// 계속 다른 선택을 하면 성격도 바뀐다 — 사람은 고정된 값이 아니다.
    func testPersonalityCanShift() {
        let early = PersonalityRules.personality(listen: 4, explain: 1, challenge: 0)
        let later = PersonalityRules.personality(listen: 4, explain: 1, challenge: 8)
        XCTAssertNotEqual(early?.title, later?.title)
        XCTAssertEqual(later?.title, "불같은 승부사")
    }
}
