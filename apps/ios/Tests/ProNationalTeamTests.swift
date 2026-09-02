import Foundation
import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain
import BaseballIOSPersistence

@MainActor
final class ProNationalTeamSurfaceTests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

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

    func testCareerFlowRoutesCallAndTournamentPhases() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/CareerFlowView.swift")
        XCTAssertTrue(source.contains("case .nationalTeamCall:"))
        XCTAssertTrue(source.contains("ProNationalTeamCallView(career: career, state: state)"))
        XCTAssertTrue(source.contains("case .nationalTournament:"))
        XCTAssertTrue(source.contains("ProNationalTournamentView(career: career, state: state)"))
    }

    func testAdvanceSegmentAndBlockStopAtNationalTeamCall() throws {
        let call = try eligibleCall(seed: "940201", fanSupport: 70)
        XCTAssertEqual(call.snapshot.phase, .nationalTeamCall)

        let weeklySync = isolatedSync("national-call-weekly")
        weeklySync.clear()
        defer { weeklySync.clear() }
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "national-call")
        weekly.configure(eligibility: .init(
            hasHighSchoolCareer: false,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: true
        ))
        let careerSync = isolatedSync("national-call-stop")
        careerSync.clear()
        defer { careerSync.clear() }
        let store = MobileCareerStore(sync: careerSync, weekly: weekly)
        store.updatePersisted { $0.result = call }
        store.loadState = .ready
        store.selectedPlan = .earnTrust

        store.advanceSegment()
        XCTAssertEqual(store.state?.phase, .nationalTeamCall)
        XCTAssertEqual(store.state?.revision, call.snapshot.revision)
        XCTAssertEqual(store.result?.nextSeed, call.nextSeed)

        store.advanceBlock()
        XCTAssertEqual(store.state?.phase, .nationalTeamCall)
        XCTAssertEqual(store.state?.revision, call.snapshot.revision)
        XCTAssertEqual(store.result?.nextSeed, call.nextSeed)
    }

    private func eligibleCall(seed: String, fanSupport: Int) throws -> ProCareerResult {
        var result = try engine.start(startParams(seed: seed))
        let market = try XCTUnwrap(result.snapshot.journeyState?.pendingContractMarket)
        result = try engine.acceptContract(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            expectedRevision: result.snapshot.revision,
            marketID: market.id,
            offerID: market.offers[0].id,
            ambition: .recordBook
        ))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        object["phase"] = ProCareerPhase.seasonReview.rawValue
        object["season"] = 2
        object["age"] = 20
        object["proRulesVersion"] = 10
        object["week"] = 24
        object["currentStats"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(
                ProSeasonStats(
                    season: 2,
                    teamID: result.snapshot.team.id,
                    games: 20,
                    starts: 20,
                    inningsOuts: 360,
                    strikeouts: 80,
                    walks: 20,
                    runsAllowed: 30
                )
            )
        )
        var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
        var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
        reputation["fanSupport"] = fanSupport
        journey["reputation"] = reputation
        object["journeyState"] = journey
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let signed = engine.resignFixtureForTesting(unsigned)
        let reviewed = try engine.reviewSeason(.init(seed: result.nextSeed, state: signed))
        let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
        return try engine.acknowledgeSettlement(.init(
            seed: reviewed.nextSeed,
            state: reviewed.snapshot,
            expectedRevision: reviewed.snapshot.revision,
            settlementID: settlement.id
        ))
    }

    private func startParams(seed: String) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(
                id: "national-pitcher",
                name: "대표투수",
                stuff: 62,
                command: 60,
                movement: 58,
                stamina: 61
            ),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3라운드",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: "2군 선발",
                summary: "지명"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-09-02"),
            sourceFanInterest: nil,
            startingRepertoire: nil,
            repertoireRulesVersion: nil,
            pitchLearningProject: nil,
            proRulesVersion: 10
        )
    }

    private func isolatedSync(_ prefix: String) -> SaveSync {
        SaveSync(key: "\(prefix)-\(UUID().uuidString).json")
    }
}
