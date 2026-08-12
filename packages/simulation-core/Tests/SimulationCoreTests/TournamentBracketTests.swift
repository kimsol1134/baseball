import XCTest
@testable import SimulationCore

final class TournamentBracketTests: XCTestCase {
    func testFieldIsDeterministicUniqueAndContainsMySchool() {
        let a = TournamentBracket.field(careerID: "t", chapterNumber: 4, playerSchool: "서울덕성고")
        XCTAssertEqual(a, TournamentBracket.field(careerID: "t", chapterNumber: 4, playerSchool: "서울덕성고"))
        XCTAssertEqual(a.schools.count, 8)
        XCTAssertEqual(Set(a.schools).count, 8, "같은 학교가 두 자리에 있으면 대진이 아니다.")
        XCTAssertTrue(a.schools.contains("서울덕성고"))
        // 다른 회차는 다른 대진 — 같은 벽지를 두 번 보게 하지 않는다.
        XCTAssertNotEqual(a.schools, TournamentBracket.field(careerID: "t2", chapterNumber: 4, playerSchool: "서울덕성고").schools)
    }

    func testStageDeepensWithTheYears() {
        XCTAssertEqual(TournamentBracket.field(careerID: "t", chapterNumber: 2, playerSchool: "s").playerRound, "8강")
        XCTAssertEqual(TournamentBracket.field(careerID: "t", chapterNumber: 6, playerSchool: "s").playerRound, "준결승")
        XCTAssertEqual(TournamentBracket.field(careerID: "t", chapterNumber: 8, playerSchool: "s").playerRound, "결승")
        XCTAssertTrue([2, 4, 6, 8].allSatisfy(TournamentBracket.isTournamentChapter))
        XCTAssertFalse(TournamentBracket.isTournamentChapter(3))
    }

    func testRelevantChapterFieldsStayRawAndPresentationInventoryCoversEveryEmittedOpponent() {
        var emittedOpponents = Set<String>()
        for careerID in (0..<128).map(String.init) {
            for chapter in [2, 4, 6, 8] {
                let field = TournamentBracket.field(
                    careerID: careerID,
                    chapterNumber: chapter,
                    playerSchool: "서울덕성고"
                )
                XCTAssertEqual(field.schools.count, 8)
                XCTAssertEqual(Set(field.schools).count, 8)
                XCTAssertTrue(field.schools.contains("서울덕성고"))
                XCTAssertEqual(
                    field.playerRound,
                    chapter >= 8 ? "결승" : chapter >= 6 ? "준결승" : "8강"
                )
                emittedOpponents.formUnion(field.schools.filter { $0 != "서울덕성고" })
                XCTAssertNotNil(TournamentPresentationCatalog.tournamentNameDescriptor(for: chapter))
                XCTAssertNotNil(TournamentPresentationCatalog.roundDescriptor(for: field.playerRound))
            }
        }

        XCTAssertEqual(
            emittedOpponents,
            Set(TournamentPresentationCatalog.opponentSchoolDescriptors.map(\.rawSchoolName))
        )
        for rawSchool in emittedOpponents {
            XCTAssertNotNil(TournamentPresentationCatalog.opponentSchoolDescriptor(for: rawSchool))
        }
    }
}
