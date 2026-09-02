import XCTest
@testable import SimulationCore

final class ProRoleRequestTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testStarterAcceptsWhenStaminaAndTrustMeetThresholds() throws {
        let state = try signedSpringCamp(stamina: 55, stuff: 50, managerTrust: 45, catcherTrust: 40)
        let evaluation = ProRoleRequestRules.evaluate(state: state, requested: .starter)
        XCTAssertEqual(evaluation.outcome, .accepted)
        XCTAssertEqual(evaluation.outlook, .likely)
        XCTAssertEqual(evaluation.reviewWeek, 0)
        XCTAssertNil(evaluation.rejectionNewsKey)
    }

    func testStarterConditionalWhenStaminaIsInReviewBand() throws {
        let state = try signedSpringCamp(
            stamina: 48, stuff: 50, managerTrust: 40, catcherTrust: 40, role: .closer
        )
        let evaluation = ProRoleRequestRules.evaluate(state: state, requested: .starter)
        XCTAssertEqual(evaluation.outcome, .conditional)
        XCTAssertEqual(evaluation.outlook, .conditional)
        XCTAssertEqual(evaluation.reviewWeek, 6)
    }

    func testStarterRejectsBelowConditionalStamina() throws {
        let state = try signedSpringCamp(
            stamina: 47, stuff: 50, managerTrust: 40, catcherTrust: 80, role: .closer
        )
        let evaluation = ProRoleRequestRules.evaluate(state: state, requested: .starter)
        XCTAssertEqual(evaluation.outcome, .rejected)
        XCTAssertEqual(evaluation.outlook, .difficult)
        XCTAssertEqual(evaluation.rejectionNewsKey, "content.pro-news.role-request.rejected.starter")
    }

    func testRequestingAlreadyAssignedRoleAlwaysAcceptsWithoutTrustChange() throws {
        let state = try signedSpringCamp(stamina: 40, stuff: 40, managerTrust: 42, catcherTrust: 40)
        XCTAssertEqual(state.role, .starter)
        XCTAssertLessThan(state.managerTrust, ProRoleRequestRules.starterAcceptTrust)
        let evaluation = ProRoleRequestRules.evaluate(state: state, requested: .starter)
        XCTAssertEqual(evaluation.outcome, .accepted)
        XCTAssertEqual(evaluation.outlook, .likely)
        XCTAssertTrue(ProRoleRequestRules.isAlreadyAssigned(.starter, state: state))

        var result = try signedCareer(seed: "920108", stamina: 40, stuff: 40, managerTrust: 42)
        XCTAssertEqual(result.snapshot.role, .starter)
        result = try engine.requestRole(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            requested: .starter
        ))
        XCTAssertEqual(result.snapshot.roleRequest?.outcome, .accepted)
        XCTAssertEqual(result.snapshot.managerTrust, 42)
        XCTAssertEqual(result.snapshot.rolePreference, .starter)
    }

    func testSeason1DropsTrustBarsButKeepsStuffAndStamina() throws {
        let starter = try signedSpringCamp(
            stamina: 55, stuff: 40, managerTrust: 42, catcherTrust: 20, role: .closer
        )
        XCTAssertEqual(starter.season, 1)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: starter, requested: .starter).outcome, .accepted)

        let closer = try signedSpringCamp(
            stamina: 40, stuff: 58, managerTrust: 40, catcherTrust: 20, role: .starter
        )
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: closer, requested: .closer).outcome, .accepted)

        let laterStarter = try signedSpringCamp(
            stamina: 55, stuff: 40, managerTrust: 42, catcherTrust: 20, role: .closer, season: 2
        )
        XCTAssertEqual(
            ProRoleRequestRules.evaluate(state: laterStarter, requested: .starter).outcome,
            .conditional
        )
        let laterCloser = try signedSpringCamp(
            stamina: 40, stuff: 58, managerTrust: 40, catcherTrust: 20, role: .starter, season: 2
        )
        XCTAssertEqual(
            ProRoleRequestRules.evaluate(state: laterCloser, requested: .closer).outcome,
            .conditional
        )
    }

    func testCloserAcceptsAndMiddleAlwaysAccepts() throws {
        let state = try signedSpringCamp(stamina: 40, stuff: 58, managerTrust: 40, catcherTrust: 45)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: state, requested: .closer).outcome, .accepted)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: state, requested: .longRelief).outcome, .accepted)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: state, requested: .setup).outcome, .accepted)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: state, requested: .setup).requested, .longRelief)
    }

    func testCloserConditionalAndRejectBands() throws {
        let conditional = try signedSpringCamp(stamina: 40, stuff: 52, managerTrust: 40, catcherTrust: 20)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: conditional, requested: .closer).outcome, .conditional)
        let rejected = try signedSpringCamp(stamina: 40, stuff: 51, managerTrust: 80, catcherTrust: 80)
        XCTAssertEqual(ProRoleRequestRules.evaluate(state: rejected, requested: .closer).outcome, .rejected)
        XCTAssertEqual(
            ProRoleRequestRules.evaluate(state: rejected, requested: .closer).rejectionNewsKey,
            "content.pro-news.role-request.rejected.closer"
        )
    }

    func testAcceptedStarterIsRoleOnFirstWeek() throws {
        var result = try signedCareer(seed: "920101", stamina: 60, stuff: 50, managerTrust: 50)
        XCTAssertTrue(ProRoleRequestRules.shouldOffer(result.snapshot))
        XCTAssertEqual(result.snapshot.proRulesVersion, 9)
        result = try engine.requestRole(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            requested: .starter
        ))
        XCTAssertEqual(result.snapshot.rolePreference, .starter)
        XCTAssertEqual(result.snapshot.roleRequest?.outcome, .accepted)
        XCTAssertEqual(result.snapshot.managerTrust, 50)
        XCTAssertTrue(result.events.contains("pro_role_requested"))
        XCTAssertFalse(ProRoleRequestRules.shouldOffer(result.snapshot))

        result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
        XCTAssertEqual(result.snapshot.role, .starter)
        XCTAssertEqual(result.snapshot.rolePreference, .starter)
    }

    func testRejectedRequestKeepsAssignedRoleAndDropsTrust() throws {
        var result = try signedCareer(seed: "920102", stamina: 40, stuff: 40, managerTrust: 42)
        let beforePreference = result.snapshot.rolePreference
        let seed = result.nextSeed
        result = try engine.requestRole(.init(seed: seed, state: result.snapshot, requested: .closer))
        XCTAssertEqual(result.nextSeed, seed)
        XCTAssertEqual(result.snapshot.rolePreference, beforePreference)
        XCTAssertEqual(result.snapshot.managerTrust, 41)
        XCTAssertEqual(result.snapshot.roleRequest?.outcome, .rejected)
        XCTAssertEqual(result.snapshot.news.first, "content.pro-news.role-request.rejected.closer")
    }

    func testConditionalReviewOpensRoleMeetingAtWeekSixAndKeepsSeasonCap() throws {
        var result = try signedCareer(seed: "920103", stamina: 50, stuff: 50, managerTrust: 40, role: .closer)
        result = try engine.requestRole(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            requested: .starter
        ))
        XCTAssertEqual(result.snapshot.roleRequest?.outcome, .conditional)
        XCTAssertEqual(result.snapshot.roleRequest?.reviewWeek, 6)
        XCTAssertEqual(result.snapshot.rolePreference, .starter)

        var opened: [(week: Int, type: ProSeasonDecisionType)] = []
        while result.snapshot.phase != .seasonReview {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                opened.append((decision.week, decision.type))
                result = try resolvePending(result, choiceIndex: 1)
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: report(result.snapshot.week)
                ))
            default:
                XCTFail("unexpected phase \(result.snapshot.phase)")
                return
            }
        }
        XCTAssertTrue(opened.contains { $0.week >= 6 && $0.type == .roleMeeting })
        XCTAssertLessThanOrEqual(opened.count, 7)
        XCTAssertEqual(Set(opened.map(\.week)).count, opened.count)
    }

    func testConditionalReviewDefersPastInjuryWeek() throws {
        var result = try signedCareer(seed: "920104", stamina: 50, stuff: 50, managerTrust: 40, role: .closer)
        result = try engine.requestRole(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            requested: .starter
        ))
        result = try injuredThrough(result, untilWeek: 6)
        XCTAssertGreaterThanOrEqual(result.snapshot.week, 6)
        if result.snapshot.phase == .seasonDecision {
            XCTAssertNotEqual(result.snapshot.pendingDecision?.week, 6)
        }
        var sawReview = false
        while result.snapshot.phase != .seasonReview {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                if decision.type == .roleMeeting, decision.week >= 6 {
                    sawReview = true
                }
                result = try resolvePending(result, choiceIndex: 1)
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: report(result.snapshot.week)
                ))
            default:
                XCTFail("unexpected phase \(result.snapshot.phase)")
                return
            }
        }
        XCTAssertTrue(sawReview)
    }

    func testOffseasonRolePromiseHidesTheOffer() throws {
        var result = try signedCareer(seed: "920105", stamina: 60, stuff: 60, managerTrust: 80)
        let contract = ProContractSnapshot(
            yearsRemaining: 2,
            annualSalary: 100_000_000,
            rolePromise: .starter,
            kind: .renewalLong
        )
        result = try stamped(result, contract: contract)
        XCTAssertFalse(ProRoleRequestRules.shouldOffer(result.snapshot))
        XCTAssertThrowsError(
            try engine.requestRole(.init(seed: result.nextSeed, state: result.snapshot, requested: .closer))
        )
    }

    func testV8SaveDoesNotOfferAndReplayBytesMatch() throws {
        var first = try engine.start(startParams(seed: "920106", proRulesVersion: 8))
        first = try engine.signContract(.init(seed: first.nextSeed, state: first.snapshot))
        XCTAssertEqual(first.snapshot.proRulesVersion, 8)
        XCTAssertFalse(ProRoleRequestRules.shouldOffer(first.snapshot))
        XCTAssertNil(first.snapshot.roleRequest)
        XCTAssertThrowsError(
            try engine.requestRole(.init(seed: first.nextSeed, state: first.snapshot, requested: .starter))
        )

        let played = try playSeason(first, plan: .recover)
        var second = try engine.start(startParams(seed: "920106", proRulesVersion: 8))
        second = try engine.signContract(.init(seed: second.nextSeed, state: second.snapshot))
        let replayed = try playSeason(second, plan: .recover)
        XCTAssertEqual(played.snapshot.commitment, replayed.snapshot.commitment)
        XCTAssertEqual(played.snapshot.currentStats, replayed.snapshot.currentStats)
        XCTAssertEqual(played.snapshot.decisionHistory, replayed.snapshot.decisionHistory)
        XCTAssertNil(played.snapshot.roleRequest)
        XCTAssertNil(replayed.snapshot.roleRequest)
    }

    func testRequestDoesNotConsumeTheWeeklySeed() throws {
        var result = try signedCareer(seed: "920107", stamina: 60, stuff: 60, managerTrust: 50)
        let seed = result.nextSeed
        result = try engine.requestRole(.init(seed: seed, state: result.snapshot, requested: .longRelief))
        XCTAssertEqual(result.nextSeed, seed)
        let again = try engine.requestRole(.init(seed: seed, state: try signedCareer(seed: "920107", stamina: 60, stuff: 60, managerTrust: 50).snapshot, requested: .longRelief))
        XCTAssertEqual(result.snapshot.commitment, again.snapshot.commitment)
    }

    private func signedCareer(
        seed: String,
        stamina: Int,
        stuff: Int,
        managerTrust: Int,
        catcherTrust: Int = 45,
        role: ProRole? = nil,
        season: Int? = nil
    ) throws -> ProCareerResult {
        var result = try engine.start(startParams(
            seed: seed,
            pitcher: pitcher(stuff: stuff, stamina: stamina)
        ))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        return try stamped(
            result,
            managerTrust: managerTrust,
            catcherTrust: catcherTrust,
            role: role,
            season: season
        )
    }

    private func signedSpringCamp(
        stamina: Int,
        stuff: Int,
        managerTrust: Int,
        catcherTrust: Int,
        role: ProRole? = nil,
        season: Int? = nil
    ) throws -> ProCareerSnapshot {
        try signedCareer(
            seed: "920199",
            stamina: stamina,
            stuff: stuff,
            managerTrust: managerTrust,
            catcherTrust: catcherTrust,
            role: role,
            season: season
        ).snapshot
    }

    private func stamped(
        _ result: ProCareerResult,
        managerTrust: Int? = nil,
        catcherTrust: Int? = nil,
        contract: ProContractSnapshot? = nil,
        role: ProRole? = nil,
        season: Int? = nil
    ) throws -> ProCareerResult {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        if let managerTrust { object["managerTrust"] = managerTrust }
        if let catcherTrust { object["catcherTrust"] = catcherTrust }
        if let role { object["role"] = role.rawValue }
        if let season { object["season"] = season }
        if let contract {
            object["contract"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(contract))
        }
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        let signed = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        return ProCareerResult(snapshot: signed, nextSeed: result.nextSeed, events: result.events)
    }

    private func playSeason(_ initial: ProCareerResult, plan: ProWeekPlan) throws -> ProCareerResult {
        var result = initial
        while result.snapshot.phase != .seasonReview {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
            case .seasonDecision:
                result = try resolvePending(result, choiceIndex: 1)
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: report(result.snapshot.week)
                ))
            default:
                throw SimulationError.invalidProCareer("unexpected phase \(result.snapshot.phase.rawValue)")
            }
        }
        return result
    }

    private func injuredThrough(_ initial: ProCareerResult, untilWeek: Int) throws -> ProCareerResult {
        var result = initial
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        object["injuryWeeks"] = max(1, untilWeek - result.snapshot.week + 1)
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
        result = ProCareerResult(snapshot: unsigned, nextSeed: result.nextSeed, events: result.events)
        while result.snapshot.week < untilWeek {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .seasonDecision:
                result = try resolvePending(result, choiceIndex: 1)
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: report(result.snapshot.week)
                ))
            default:
                break
            }
        }
        return result
    }

    private func resolvePending(_ result: ProCareerResult, choiceIndex: Int) throws -> ProCareerResult {
        let decision = try XCTUnwrap(result.snapshot.pendingDecision)
        let index = min(choiceIndex, decision.choices.count - 1)
        return try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            decisionID: decision.id,
            choiceID: decision.choices[index].id
        ))
    }

    private func report(_ number: Int) -> ImportantInningReport {
        .init(
            scenarioNumber: number,
            pitches: 18,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 380,
            actualDamage: 240,
            recommendationAccepted: 12
        )
    }

    private func startParams(seed: String, pitcher: PitcherSnapshot? = nil, proRulesVersion: Int? = nil) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: pitcher ?? self.pitcher(stuff: 58, stamina: 57),
            draftResult: drafted(),
            entitlement: activeEntitlement(),
            sourceFanInterest: nil,
            startingRepertoire: nil,
            repertoireRulesVersion: nil,
            pitchLearningProject: nil,
            proRulesVersion: proRulesVersion
        )
    }

    private func activeEntitlement() -> ProEntitlementSnapshot {
        .init(status: .active, source: .development, verifiedAt: "2026-09-02", offlineValidUntil: "2026-10-02")
    }

    private func pitcher(stuff: Int, stamina: Int) -> PitcherSnapshot {
        .init(id: "p-role-request", name: "테스트투수", stuff: stuff, command: 55, movement: 56, stamina: stamina)
    }

    private func drafted() -> DraftResultSnapshot {
        .init(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: ProCareerEngine.proTeams[0],
            round: 2,
            overallPick: 18,
            signingBonus: 120_000_000,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )
    }
}
