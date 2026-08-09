import XCTest
@testable import BaseballIOS

final class CareerPacingTests: XCTestCase {
    func testEightInternalChaptersReadAsFourPlayerFacingActs() {
        XCTAssertEqual(
            (1...8).map { HighSchoolPresentation.actNumber(chapter: $0) },
            [1, 1, 2, 2, 3, 3, 4, 4]
        )
        XCTAssertEqual(HighSchoolPresentation.actTitle(chapter: 1), "1장 · 자리를 얻다")
        XCTAssertEqual(HighSchoolPresentation.actTitle(chapter: 8), "4장 · 이름을 남기다")
    }

    func testImportantMomentsMixShortStandardAndLongResponsibilities() {
        XCTAssertEqual(
            PitchScenario.highSchoolMaximumBatters(outs: 2, leverage: 1_000, chapter: 8),
            2,
            "2사 승부는 중요도가 높아도 짧고 날카로워야 합니다."
        )
        XCTAssertEqual(
            PitchScenario.highSchoolMaximumBatters(outs: 0, leverage: 600, chapter: 2),
            4
        )
        XCTAssertEqual(
            PitchScenario.highSchoolMaximumBatters(outs: 0, leverage: 700, chapter: 6),
            5
        )
        XCTAssertEqual(
            PitchScenario.highSchoolMaximumBatters(outs: 0, leverage: 950, chapter: 4),
            6,
            "무사 고비는 긴 승부가 될 여지를 남겨야 합니다."
        )
    }

    func testPreV4CareerKeepsItsFourBatterImportantGameContract() {
        XCTAssertEqual(
            PitchScenario.highSchoolMaximumBatters(
                outs: 2,
                leverage: 1_000,
                chapter: 8,
                balanceVersion: 3
            ),
            4
        )
        XCTAssertEqual(
            PitchScenario.highSchoolMaximumBatters(
                outs: 0,
                leverage: 950,
                chapter: 8,
                balanceVersion: nil
            ),
            4
        )
    }

    func testLongMomentLineupIsDeterministicUniqueAndCapped() {
        let first = HighSchoolPresentation.followUpBatters(seedText: "career-42", count: 5)
        let replay = HighSchoolPresentation.followUpBatters(seedText: "career-42", count: 5)
        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.count, 5)
        XCTAssertEqual(Set(first.map(\.id)).count, first.count)
        XCTAssertEqual(
            HighSchoolPresentation.followUpBatters(seedText: "career-42", count: 99).count,
            6
        )
    }
}
