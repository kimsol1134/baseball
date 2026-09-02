import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain
import BaseballIOSPersistence

@MainActor
final class ProNationalTeamSurfaceTests: XCTestCase {
    func testCallAndTournamentAccessibilityIDsAreStable() {
        XCTAssertEqual(GameAnalytics.Event.proNationalTeamCalled.rawValue, "pro_national_team_called")
        XCTAssertEqual(GameAnalytics.Event.proNationalTeamResult.rawValue, "pro_national_team_result")
        XCTAssertTrue(CareerDisplayRules.nationalOpponentNameKey("east-coast").contains("east-coast"))
        XCTAssertEqual(CareerDisplayRules.nationalFinalBatterOffset(), 6)
    }

    func testKoreanEnglishJapaneseCopyForNationalTeamKeys() throws {
        let korean = GameCopyResolver(language: .korean, policy: .releaseSafe)
        let english = GameCopyResolver(language: .english, policy: .releaseSafe)
        let japanese = GameCopyResolver(language: .japanese, policy: .releaseSafe)
        let keys: [ProUICopyKey] = [
            .nationalTeamCallTitle,
            .nationalTeamCallAccept,
            .nationalTeamCallDecline,
            .nationalTournamentStartFinal,
            .nationalTeamResultTitle,
            .nationalResultGold,
            .retirementHonorNationalGold,
            .nationalRecordTitle,
        ]
        for key in keys {
            XCTAssertFalse(korean.resolve(key).isEmpty, key.rawValue)
            XCTAssertFalse(english.resolve(key).isEmpty, key.rawValue)
            XCTAssertFalse(japanese.resolve(key).isEmpty, key.rawValue)
            XCTAssertFalse(english.resolve(key).contains { $0.unicodeScalars.contains { 0xAC00...0xD7A3 ~= $0.value } }, key.rawValue)
        }
        XCTAssertEqual(korean.resolve(.gameContent("content.national-team.tournament.name")), "환태평양 초청 대회")
        XCTAssertEqual(GlossaryCatalog.term(id: "national-team-call")?.id, "national-team-call")
        XCTAssertEqual(GlossaryCatalog.term(id: "military-exemption")?.id, "military-exemption")
    }
}
