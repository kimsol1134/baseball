import XCTest
@testable import SimulationCore

final class ProWeeklyDecisionHookTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testNewCareerUsesWeeklyDecisionRules() throws {
        let started = try engine.start(startParams(seed: "910201"))
        XCTAssertEqual(started.snapshot.proRulesVersion, ProCareerEngine.currentRulesVersion)
        XCTAssertTrue(ProCareerEngine.usesWeeklyDecisionRules(started.snapshot))
        XCTAssertEqual(ProCareerEngine.decisionWeeks(for: started.snapshot), [3, 6, 9, 12, 15, 18, 21])
        XCTAssertEqual(ProCareerEngine.maximumDecisions(for: started.snapshot), 7)
        XCTAssertEqual(ProCareerEngine.seasonDecisionWeeks, [6, 13, 20])
        XCTAssertEqual(ProCareerEngine.maximumSeasonDecisions, 3)
    }

    func testV9SeasonOpensWeeklyDecisionSlotsWithoutRepeatingTypes() throws {
        var result = try engine.start(startParams(seed: "910202"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        var opened: [(week: Int, type: ProSeasonDecisionType)] = []
        while result.snapshot.phase != .seasonReview {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                XCTAssertEqual(result.snapshot.injuryWeeks, 0)
                XCTAssertNil(result.snapshot.seasonTrigger)
                XCTAssertTrue(ProCareerEngine.weeklySeasonDecisionWeeks.contains(decision.week))
                opened.append((decision.week, decision.type))
                result = try resolvePending(result, choiceIndex: 1)
            case .importantGame:
                XCTAssertNil(result.snapshot.pendingDecision)
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
        XCTAssertFalse(opened.isEmpty)
        XCTAssertLessThanOrEqual(opened.count, 7)
        XCTAssertEqual(Set(opened.map(\.week)).count, opened.count)
        XCTAssertEqual(Set(opened.map(\.type)).count, opened.count)
        XCTAssertTrue(opened.allSatisfy { ProCareerEngine.weeklySeasonDecisionWeeks.contains($0.week) })
    }

    func testRotationPushFollowUpExpiresAfterThreeWeeksAndClearsModifier() throws {
        let pending = try forcedWeeklyDecision(seed: "910203", type: .rotationPush)
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        let accept = try XCTUnwrap(decision.choices.first { $0.id.hasSuffix(".accept_short_rest") })
        var result = try engine.applySeasonDecision(.init(
            seed: pending.nextSeed,
            state: pending.snapshot,
            decisionID: decision.id,
            choiceID: accept.id
        ))
        XCTAssertEqual(result.snapshot.decisionHistory?.last?.followUpResolvedWeek, decision.week + 3)
        XCTAssertEqual(result.snapshot.activeDecisionModifiers?.count, 1)
        XCTAssertEqual(result.snapshot.activeDecisionModifiers?.first?.extraOutingChance, 1)
        XCTAssertEqual(result.snapshot.activeDecisionModifiers?.first?.extraOutingsGranted ?? 0, 0)
        XCTAssertEqual(result.snapshot.activeDecisionModifiers?.first?.injuryPressureFloor, 80)
        XCTAssertTrue((result.snapshot.resolvedFollowUps ?? []).isEmpty)

        let expiresWeek = decision.week + 3
        var sawInjuryFloorThroughWindow = false
        while result.snapshot.week < expiresWeek {
            if let rotation = result.snapshot.activeDecisionModifiers?.first(where: { $0.type == .rotationPush }) {
                XCTAssertEqual(rotation.injuryPressureFloor, 80)
                XCTAssertEqual(rotation.extraOutingChance, 1)
                XCTAssertLessThanOrEqual(rotation.extraOutingsGranted ?? 0, 1)
                sawInjuryFloorThroughWindow = true
            }
            result = try advanceIgnoringDecisions(result)
        }
        XCTAssertTrue(sawInjuryFloorThroughWindow)
        XCTAssertGreaterThanOrEqual(result.snapshot.week, expiresWeek)
        XCTAssertTrue((result.snapshot.activeDecisionModifiers ?? []).isEmpty)
        XCTAssertEqual(result.snapshot.resolvedFollowUps?.count, 1)
        XCTAssertEqual(result.snapshot.resolvedFollowUps?.first?.type, .rotationPush)
        XCTAssertEqual(result.snapshot.resolvedFollowUps?.first?.decisionID, decision.id)
        XCTAssertTrue(result.events.contains("pro_weekly_decision_followup_resolved"))

        let windowLines = (result.snapshot.gameLines ?? []).filter { line in
            line.week > decision.week && line.week <= expiresWeek && !line.played
        }
        let extraOutings = windowLines.count - Set(windowLines.map(\.week)).count
        XCTAssertEqual(extraOutings, 1)
        XCTAssertEqual(result.snapshot.currentStats.starts, result.snapshot.currentStats.games)
    }

    func testWeeklyModifierExpiresEvenIfInjurySkipsOutings() throws {
        let pending = try forcedWeeklyDecision(seed: "910204", type: .rotationPush)
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        let accept = try XCTUnwrap(decision.choices.first { $0.id.hasSuffix(".accept_short_rest") })
        var result = try engine.applySeasonDecision(.init(
            seed: pending.nextSeed,
            state: pending.snapshot,
            decisionID: decision.id,
            choiceID: accept.id
        ))
        let expiresWeek = decision.week + 3
        result = try injuredThrough(result, untilWeek: expiresWeek)
        XCTAssertGreaterThanOrEqual(result.snapshot.week, expiresWeek)
        XCTAssertTrue((result.snapshot.activeDecisionModifiers ?? []).isEmpty)
        XCTAssertEqual(result.snapshot.resolvedFollowUps?.count, 1)
    }

    func testLegacyRulesVersionEightKeepsCompressedCadenceAndMatchingReplay() throws {
        var first = try engine.start(startParams(seed: "910205", proRulesVersion: 8))
        first = try engine.signContract(.init(seed: first.nextSeed, state: first.snapshot))
        XCTAssertEqual(first.snapshot.proRulesVersion, 8)
        XCTAssertFalse(ProCareerEngine.usesWeeklyDecisionRules(first.snapshot))
        XCTAssertEqual(ProCareerEngine.decisionWeeks(for: first.snapshot), [6, 13, 20])

        let played = try playSeason(first, plan: .recover)
        let weeks = (played.snapshot.decisionHistory ?? []).filter { $0.season == 1 }.map(\.week)
        XCTAssertTrue(weeks.allSatisfy { [6, 13, 20].contains($0) })
        XCTAssertLessThanOrEqual(weeks.count, 3)

        var second = try engine.start(startParams(seed: "910205", proRulesVersion: 8))
        second = try engine.signContract(.init(seed: second.nextSeed, state: second.snapshot))
        let replayed = try playSeason(second, plan: .recover)
        XCTAssertEqual(played.snapshot.commitment, replayed.snapshot.commitment)
        XCTAssertEqual(played.snapshot.decisionHistory, replayed.snapshot.decisionHistory)
        XCTAssertEqual(played.snapshot.currentStats, replayed.snapshot.currentStats)
    }

    func testSameSeedAndChoicesAreByteIdenticalOnV9() throws {
        func trace() throws -> ProCareerResult {
            var result = try engine.start(startParams(seed: "910206"))
            result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
            return try playSeason(result, plan: .earnTrust)
        }
        XCTAssertEqual(try trace(), try trace())
    }

    func testWeeklyBinaryDecisionsExposeTwoChoices() throws {
        let pending = try forcedWeeklyDecision(seed: "910207", type: .rotationPush)
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        XCTAssertEqual(decision.choices.count, 2)
        XCTAssertEqual(Set(decision.choices.map(\.id)).count, 2)
    }

    private func forcedWeeklyDecision(seed: String, type: ProSeasonDecisionType) throws -> ProCareerResult {
        var result = try engine.start(startParams(seed: seed, pitcher: pitcher()))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        let week = 3
        let used: [ProSeasonDecisionType] = [
            .extraBullpen, .catcherGamePlan, .roleMeeting,
            .recordChase, .rivalAnalysis, .seasonFinale,
        ]
        let history = zip(used, [6, 13, 20, 3, 9, 12]).map { usedType, usedWeek in
            ProDecisionRecord(
                decisionID: "season-1-week-\(usedWeek)-\(usedType.rawValue)",
                type: usedType,
                season: 1,
                week: usedWeek,
                choiceID: "\(usedType.rawValue).rest",
                choiceTitle: "rest",
                effect: .init()
            )
        }
        let decision = try XCTUnwrap(engine.seasonDecision(
            for: try stamped(
                result.snapshot,
                week: week,
                role: .starter,
                fatigue: 10,
                managerTrust: 50,
                history: history
            ),
            week: week
        ))
        XCTAssertEqual(decision.type, type)
        let pending = try stamped(
            result.snapshot,
            week: week,
            phase: .seasonDecision,
            role: .starter,
            rolePreference: .starter,
            fatigue: 10,
            managerTrust: 50,
            history: history,
            pending: decision
        )
        return ProCareerResult(snapshot: pending, nextSeed: result.nextSeed, events: result.events)
    }

    private func stamped(
        _ snapshot: ProCareerSnapshot,
        week: Int,
        phase: ProCareerPhase? = nil,
        role: ProRole,
        rolePreference: ProRole? = nil,
        fatigue: Int,
        managerTrust: Int,
        history: [ProDecisionRecord],
        pending: ProSeasonDecision? = nil
    ) throws -> ProCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        object["week"] = week
        if let phase { object["phase"] = phase.rawValue }
        object["role"] = role.rawValue
        if let rolePreference {
            object["rolePreference"] = rolePreference.rawValue
        }
        object["fatigue"] = fatigue
        object["managerTrust"] = managerTrust
        object["decisionHistory"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(history))
        if let pending {
            object["pendingDecision"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(pending))
        } else {
            object.removeValue(forKey: "pendingDecision")
        }
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsigned)
        return try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
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

    private func advanceIgnoringDecisions(_ initial: ProCareerResult) throws -> ProCareerResult {
        var result = initial
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
            result = try advanceIgnoringDecisions(result)
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

    private func startParams(
        seed: String,
        pitcher: PitcherSnapshot? = nil,
        proRulesVersion: Int? = nil
    ) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: pitcher ?? self.pitcher(),
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

    private func pitcher() -> PitcherSnapshot {
        .init(id: "p-weekly", name: "테스트투수", stuff: 58, command: 55, movement: 56, stamina: 57)
    }

    private func presetPitcher() -> PitcherSnapshot {
        PitcherPresetCatalog.all[0].pitcher
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
