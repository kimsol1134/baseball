import XCTest
@testable import SimulationCore

final class ProNationalTeamTests: XCTestCase {
    private let engine = ProCareerEngine(journeyEnabled: true)

    func testEvenSeasonWithFanSupportOpensTheCallAndDeclineDropsFan() throws {
        var result = try eligibleCall(seed: "940101", fanSupport: 60)
        XCTAssertEqual(result.snapshot.phase, .nationalTeamCall)
        XCTAssertTrue(ProNationalTeamRules.shouldOfferCall(result.snapshot))
        let seed = result.nextSeed
        let fanBefore = result.snapshot.journeyState?.reputation.fanSupport ?? 0
        result = try engine.respondToNationalTeamCall(.init(
            seed: seed,
            state: result.snapshot,
            accepted: false
        ))
        XCTAssertEqual(result.nextSeed, seed)
        XCTAssertEqual(result.snapshot.phase, .offseasonDecision)
        XCTAssertEqual(result.snapshot.journeyState?.reputation.fanSupport, fanBefore - 2)
        XCTAssertEqual(result.snapshot.news.first, "content.pro-news.national-team.declined")
        XCTAssertTrue(result.events.contains("pro_national_team_called"))
        XCTAssertNil(result.snapshot.nationalTournament)
    }

    func testOddSeasonAndV9DoNotOpenTheCall() throws {
        let odd = try settledSeason(seed: "940102", season: 1, fanSupport: 80)
        XCTAssertEqual(odd.snapshot.phase, .offseasonDecision)
        XCTAssertFalse(ProNationalTeamRules.shouldOfferCall(odd.snapshot))

        let v9 = try settledSeason(seed: "940103", season: 2, fanSupport: 80, proRulesVersion: 9)
        XCTAssertEqual(v9.snapshot.phase, .offseasonDecision)
        XCTAssertFalse(ProCareerEngine.usesNationalTeamRules(v9.snapshot))
        XCTAssertFalse(ProNationalTeamRules.shouldOfferCall(v9.snapshot))
    }

    func testAcceptSimulatesThreeGroupGamesWithoutConsumingOffseasonSeed() throws {
        var result = try eligibleCall(seed: "940104", fanSupport: 70)
        let seed = result.nextSeed
        result = try engine.respondToNationalTeamCall(.init(
            seed: seed,
            state: result.snapshot,
            accepted: true
        ))
        XCTAssertEqual(result.nextSeed, seed)
        let tournament = try XCTUnwrap(result.snapshot.nationalTournament)
        XCTAssertEqual(tournament.groupGames.count, 3)
        XCTAssertEqual(tournament.resumeSeed, seed)
        XCTAssertEqual(result.snapshot.currentStats.games, result.snapshot.currentStats.games)
        if tournament.stage == .awaitingFinal {
            XCTAssertGreaterThanOrEqual(tournament.groupWins, 2)
            XCTAssertNil(tournament.result)
            XCTAssertEqual(result.snapshot.phase, .nationalTournament)
        } else {
            XCTAssertNotNil(tournament.result)
            XCTAssertEqual(tournament.stage, .result)
        }
    }

    func testGoldPathExemptsMilitaryAndAwardsRecognition() throws {
        var result = try eligibleCall(seed: "940105", fanSupport: 70)
        XCTAssertFalse(result.snapshot.militaryCompleted)
        let fanBefore = result.snapshot.journeyState?.reputation.fanSupport ?? 0
        result = try engine.respondToNationalTeamCall(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            accepted: true
        ))
        if result.snapshot.nationalTournament?.stage != .awaitingFinal {
            result = try forceAwaitingFinal(result)
        }
        result = try engine.startNationalFinal(.init(seed: result.nextSeed, state: result.snapshot))
        XCTAssertEqual(result.snapshot.phase, .importantGame)
        XCTAssertEqual(result.snapshot.seasonTrigger, .nationalFinal)
        let seed = result.nextSeed
        result = try engine.resolveImportantGame(.init(
            seed: seed,
            state: result.snapshot,
            report: ImportantInningReport(
                scenarioNumber: 1,
                pitches: 24,
                strikeouts: 3,
                walks: 0,
                runsAllowed: 0,
                expectedDamage: 400,
                actualDamage: 120,
                recommendationAccepted: 8,
                teamRuns: 4
            )
        ))
        XCTAssertEqual(result.nextSeed, seed)
        XCTAssertEqual(result.snapshot.phase, .nationalTournament)
        let tournament = try XCTUnwrap(result.snapshot.nationalTournament)
        XCTAssertEqual(tournament.result, .gold)
        XCTAssertTrue(tournament.exempted)
        XCTAssertTrue(result.snapshot.militaryCompleted)
        XCTAssertEqual(
            result.snapshot.journeyState?.reputation.fanSupport,
            min(100, fanBefore + ProNationalTeamRules.goldFanDelta)
        )
        XCTAssertTrue(
            result.snapshot.journeyState?.recognitions.contains {
                $0.contentID == "pro.award.national-gold"
            } == true
        )
        XCTAssertTrue(
            result.snapshot.journeyState?.recognitions.contains {
                $0.contentID == "pro.milestone.national.gold"
            } == true
        )
        XCTAssertEqual(result.snapshot.nationalTeamHistory?.last?.result, .gold)
        XCTAssertEqual(result.snapshot.journeyState?.reputation.overseasInterest, true)
        XCTAssertEqual(result.snapshot.nationalTeamCarry?.fatigue, ProNationalTeamRules.fatigueCarry)
        result = try engine.acknowledgeNationalTeamResult(.init(
            seed: result.nextSeed,
            state: result.snapshot
        ))
        XCTAssertEqual(result.snapshot.phase, .offseasonDecision)
        XCTAssertNil(result.snapshot.nationalTournament)
        XCTAssertEqual(result.nextSeed, seed)
    }

    func testAlreadyCompletedMilitaryGetsLargerFanBonus() throws {
        var result = try eligibleCall(seed: "940106", fanSupport: 60, militaryCompleted: true)
        let fanBefore = result.snapshot.journeyState?.reputation.fanSupport ?? 0
        result = try engine.respondToNationalTeamCall(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            accepted: true
        ))
        if result.snapshot.nationalTournament?.stage != .awaitingFinal {
            result = try forceAwaitingFinal(result)
        }
        result = try engine.startNationalFinal(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.resolveImportantGame(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            report: ImportantInningReport(
                scenarioNumber: 1,
                pitches: 90,
                strikeouts: 4,
                walks: 0,
                runsAllowed: 0,
                expectedDamage: 400,
                actualDamage: 100,
                recommendationAccepted: 10,
                teamRuns: 5
            )
        ))
        let tournament = try XCTUnwrap(result.snapshot.nationalTournament)
        XCTAssertEqual(tournament.result, .gold)
        XCTAssertFalse(tournament.exempted)
        XCTAssertTrue(result.snapshot.militaryCompleted)
        XCTAssertEqual(
            result.snapshot.journeyState?.reputation.fanSupport,
            min(100, fanBefore + ProNationalTeamRules.goldFanDeltaAlreadyCompleted)
        )
        XCTAssertEqual(result.snapshot.nationalTeamCarry?.fatigue, ProNationalTeamRules.fatigueCarryHeavy)
    }

    func testV9OffseasonReplayBytesMatch() throws {
        let first = try settledSeason(seed: "940107", season: 2, fanSupport: 40, proRulesVersion: 9)
        let second = try settledSeason(seed: "940107", season: 2, fanSupport: 40, proRulesVersion: 9)
        XCTAssertEqual(first.snapshot.phase, .offseasonDecision)
        XCTAssertEqual(first.snapshot.commitment, second.snapshot.commitment)
        XCTAssertEqual(first.nextSeed, second.nextSeed)
        let continued = try engine.chooseOffseason(.init(
            seed: first.nextSeed,
            state: first.snapshot,
            decision: .continueCareer,
            expectedRevision: first.snapshot.revision
        ))
        let replayed = try engine.chooseOffseason(.init(
            seed: second.nextSeed,
            state: second.snapshot,
            decision: .continueCareer,
            expectedRevision: second.snapshot.revision
        ))
        XCTAssertEqual(continued.snapshot.commitment, replayed.snapshot.commitment)
        XCTAssertEqual(continued.nextSeed, replayed.nextSeed)
        XCTAssertNil(continued.snapshot.nationalTournament)
    }

    func testFinalBatterOffsetMatchesAutumnChampionship() {
        XCTAssertEqual(
            ProNationalTeamRules.finalBatterOffset,
            ProPostseasonRules.extraOffset(for: .final)
        )
        XCTAssertEqual(ProNationalTeamRules.finalBatterOffset, 6)
    }

    private func eligibleCall(
        seed: String,
        fanSupport: Int,
        militaryCompleted: Bool = false
    ) throws -> ProCareerResult {
        try settledSeason(
            seed: seed,
            season: 2,
            fanSupport: fanSupport,
            militaryCompleted: militaryCompleted
        )
    }

    private func settledSeason(
        seed: String,
        season: Int,
        fanSupport: Int,
        militaryCompleted: Bool = false,
        proRulesVersion: Int = 10
    ) throws -> ProCareerResult {
        var result = try engine.start(startParams(seed: seed, proRulesVersion: proRulesVersion))
        let market = try XCTUnwrap(result.snapshot.journeyState?.pendingContractMarket)
        result = try engine.acceptContract(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            expectedRevision: result.snapshot.revision,
            marketID: market.id,
            offerID: market.offers[0].id,
            ambition: .recordBook
        ))
        let reviewReady = try unsignedSnapshot(result.snapshot) { object in
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["season"] = season
            object["age"] = 18 + season
            object["proRulesVersion"] = proRulesVersion
            object["militaryCompleted"] = militaryCompleted
            object["week"] = 24
            object["currentStats"] = try encoded(
                ProSeasonStats(
                    season: season,
                    teamID: result.snapshot.team.id,
                    games: 20,
                    starts: 20,
                    inningsOuts: 360,
                    strikeouts: 80,
                    walks: 20,
                    runsAllowed: 30
                )
            )
            var journey = try XCTUnwrap(object["journeyState"] as? [String: Any])
            var reputation = try XCTUnwrap(journey["reputation"] as? [String: Any])
            reputation["fanSupport"] = fanSupport
            journey["reputation"] = reputation
            object["journeyState"] = journey
        }
        let reviewed = try engine.reviewSeason(.init(seed: result.nextSeed, state: reviewReady))
        let settlement = try XCTUnwrap(reviewed.snapshot.journeyState?.lastSettlement)
        return try engine.acknowledgeSettlement(.init(
            seed: reviewed.nextSeed,
            state: reviewed.snapshot,
            expectedRevision: reviewed.snapshot.revision,
            settlementID: settlement.id
        ))
    }

    private func forceAwaitingFinal(_ result: ProCareerResult) throws -> ProCareerResult {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        var tournament = try XCTUnwrap(object["nationalTournament"] as? [String: Any])
        tournament["stage"] = ProNationalTournamentStage.awaitingFinal.rawValue
        tournament["result"] = NSNull()
        object["nationalTournament"] = tournament
        object["phase"] = ProCareerPhase.nationalTournament.rawValue
        object["commitment"] = ""
        var unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        return ProCareerResult(snapshot: unsigned, nextSeed: result.nextSeed, events: result.events)
    }

    private func startParams(seed: String, proRulesVersion: Int) -> StartProCareerParams {
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
            proRulesVersion: proRulesVersion
        )
    }

    private func unsignedSnapshot(
        _ snapshot: ProCareerSnapshot,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        try mutate(&object)
        object["commitment"] = ""
        var unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        return unsigned
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
}
