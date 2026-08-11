import Foundation
import XCTest
@testable import SimulationCore

final class CareerWindTests: XCTestCase {
    func testV1SelectorGoldenCompatibility() {
        let goldens: [(careerID: String, id: String, rival: Int, fans: Int, reward: Int)] = [
            ("career-1-life-1", "monster_generation", 5, 5, 150),
            ("career-2-life-1", "scout_frenzy", 0, 20, 0),
            ("career-3-life-1", "calm", 0, 5, 0),
            ("career-7-life-1", "calm", 0, 5, 0),
            ("career-42-life-1", "monster_generation", 5, 5, 150),
            ("career-100-life-2", "quiet_season", -3, 0, 80),
            ("career-999-life-9", "calm", 0, 5, 0),
            ("legacy-fixed-seed", "monster_generation", 5, 5, 150),
        ]

        XCTAssertEqual(CareerWind.all.map(\.id), [
            "calm", "calm", "monster_generation", "scout_frenzy", "quiet_season",
        ])
        for golden in goldens {
            let legacyEntryPoint = CareerWind.wind(careerID: golden.careerID)
            let explicitV1 = CareerWind.wind(careerID: golden.careerID, rulesVersion: .v1)
            let missingStoredVersion = CareerWind.wind(careerID: golden.careerID, worldRulesVersion: nil)
            XCTAssertEqual(legacyEntryPoint, explicitV1, golden.careerID)
            XCTAssertEqual(legacyEntryPoint, missingStoredVersion, golden.careerID)
            XCTAssertEqual(legacyEntryPoint.id, golden.id, golden.careerID)
            XCTAssertEqual(legacyEntryPoint.rivalBonus, golden.rival, golden.careerID)
            XCTAssertEqual(legacyEntryPoint.startingFanInterest, golden.fans, golden.careerID)
            XCTAssertEqual(legacyEntryPoint.rewardBonusPermille, golden.reward, golden.careerID)
            XCTAssertEqual(legacyEntryPoint.rulesVersion, .v1)
            XCTAssertEqual(legacyEntryPoint.rules, .neutral)
        }
    }

    func testV2PoolMatchesLaunchRulesAndGeneratedDescriptions() throws {
        XCTAssertEqual(CareerWind.v2All.count, 10)
        XCTAssertEqual(Set(CareerWind.v2All.map(\.id)).count, 10)

        let expectedDescriptions: [String: [String]] = [
            "calm": [],
            "monster_generation": ["팬 관심 획득 +3", "숙적 능력 +5", "계승 포인트 보정 +15%"],
            "scout_frenzy": ["시작 팬 관심 10"],
            "quiet_season": ["시작 팬 관심 0", "숙적 능력 -3", "계승 포인트 보정 +8%"],
            "heatwave": ["회복 효과 +4", "모든 훈련 피로 +2", "계승 포인트 보정 +12%"],
            "command_year": ["제구 훈련 성장 +1", "구위 훈련 피로 +1", "계승 포인트 보정 +5%"],
            "power_year": ["구위 훈련 성장 +1", "숙적 능력 +3", "계승 포인트 보정 +10%"],
            "battery_year": ["포수 믿음 변화 +2", "시작 팬 관심 2", "계승 포인트 보정 +5%"],
            "spotlight_year": ["팬 관심 획득 +2", "대화 실패 때 믿음 손실 +2", "계승 포인트 보정 +8%"],
            "underdog_year": ["드래프트 평가 +1", "시작 팬 관심 0", "숙적 능력 +2", "계승 포인트 보정 +12%"],
        ]

        for wind in CareerWind.v2All {
            XCTAssertEqual(wind.rulesVersion, .v2)
            XCTAssertFalse(wind.title.isEmpty)
            XCTAssertFalse(wind.detail.isEmpty)
            XCTAssertEqual(wind.effectDescriptions, expectedDescriptions[wind.id], wind.id)
            let roundTrip = try JSONDecoder().decode(
                CareerWindRules.self, from: JSONEncoder().encode(wind.rules)
            )
            XCTAssertEqual(roundTrip, wind.rules, wind.id)
        }

        let monster = try wind("monster_generation")
        XCTAssertEqual(monster.rules.adjustedFanInterestChange(4), 7)
        XCTAssertEqual(monster.rules.adjustedFanInterestChange(-2), -2)

        let scout = try wind("scout_frenzy")
        XCTAssertEqual(scout.rules.adjustedDraftEvaluation(60), 60)

        let heatwave = try wind("heatwave")
        XCTAssertEqual(heatwave.rules.trainingFatigueModifier(for: .command), 2)
        XCTAssertEqual(heatwave.rules.adjustedRecovery(18), 22)

        let command = try wind("command_year")
        XCTAssertEqual(command.rules.trainingGrowthBonus(for: .command), 1)
        XCTAssertEqual(command.rules.trainingGrowthBonus(for: .velocity), 0)
        XCTAssertEqual(command.rules.trainingFatigueModifier(for: .velocity), 1)
        XCTAssertEqual(command.rules.trainingFatigueModifier(for: .command), 0)

        let battery = try wind("battery_year")
        for category in ["catcher", "growth", "game", "awakening", "fan"] {
            XCTAssertEqual(HighSchoolCareerEngine.relationshipTarget(forEventCategory: category), .catcher)
        }
        for category in ["coach", "health", "team", "draft", "media", "life", "legacy", "unknown"] {
            XCTAssertEqual(HighSchoolCareerEngine.relationshipTarget(forEventCategory: category), .coach)
        }
        XCTAssertEqual(HighSchoolCareerEngine.relationshipTarget(forEventCategory: "rival"), .rival)
        XCTAssertEqual(battery.rules.adjustedRelationshipTrustChange(8, target: .catcher), 10)
        XCTAssertEqual(battery.rules.adjustedRelationshipTrustChange(8, target: .coach), 8)
        XCTAssertEqual(battery.rules.adjustedRelationshipTrustChange(-4, target: .catcher), -2)

        let spotlight = try wind("spotlight_year")
        XCTAssertEqual(spotlight.rules.adjustedRelationshipTrustChange(-4, target: .catcher), -6)
        XCTAssertEqual(spotlight.rules.adjustedRelationshipTrustChange(4, target: .catcher), 4)
        XCTAssertEqual(spotlight.rules.adjustedFanInterestChange(4), 6)
    }

    func testV2SelectionIsDeterministicAndMeetsDistributionGuardrails() {
        var counts: [String: Int] = [:]
        for index in 0..<10_000 {
            let careerID = "career-\(index)-life-1"
            let first = CareerWind.wind(careerID: careerID, rulesVersion: .v2)
            let second = CareerWind.wind(careerID: careerID, rulesVersion: .v2)
            XCTAssertEqual(first, second)
            counts[first.id, default: 0] += 1
        }

        XCTAssertEqual(Set(counts.keys), Set(CareerWind.v2All.map(\.id)))
        XCTAssertTrue((2_500...3_500).contains(counts["calm", default: 0]), "counts=\(counts)")
        for wind in CareerWind.v2All where wind.id != "calm" {
            XCTAssertGreaterThanOrEqual(counts[wind.id, default: 0], 500, "\(wind.id): \(counts)")
        }
    }

    func testNewCareerPersistsV2AndInitialWindEffects() throws {
        let engine = HighSchoolCareerEngine()
        let baseRivalRatings: Set<String> = [
            "47:44:39", "42:37:49", "46:45:37", "39:40:50",
            "44:40:43", "44:43:48", "41:44:50", "47:40:46",
        ]

        for expectedWind in CareerWind.v2All {
            let seed = try seed(for: expectedWind.id)
            let started = try engine.start(.init(seed: seed, presetID: "precision_commander"))
            let state = started.snapshot
            XCTAssertEqual(state.worldRulesVersion, CareerRulesVersion.v2.rawValue)
            XCTAssertEqual(state.effectiveWorldRulesVersion, .v2)
            XCTAssertEqual(state.careerWind, expectedWind)
            XCTAssertEqual(state.fanInterest, expectedWind.startingFanInterest, expectedWind.id)
            XCTAssertEqual(state.legacyRewardPermille, 1_000 + expectedWind.rewardBonusPermille, expectedWind.id)
            let rivalBase = "\(state.rival.contact - expectedWind.rivalBonus):"
                + "\(state.rival.discipline - expectedWind.rivalBonus):"
                + "\(state.rival.power - expectedWind.rivalBonus)"
            XCTAssertTrue(baseRivalRatings.contains(rivalBase), "\(expectedWind.id): \(rivalBase)")
            if expectedWind.id == "calm" {
                XCTAssertNil(expectedWind.newsLine)
            } else {
                XCTAssertTrue(state.news.first?.contains(expectedWind.title) == true)
            }
        }
    }

    func testSnapshotRoundTripLegacyFallbackTransitionPreservationAndTamperDetection() throws {
        let engine = HighSchoolCareerEngine()
        let started = try engine.start(.init(seed: "20260809", presetID: "precision_commander"))
        let encoded = try JSONEncoder().encode(started.snapshot)
        let decoded = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: encoded)
        XCTAssertEqual(decoded, started.snapshot)
        XCTAssertEqual(decoded.worldRulesVersion, 2)

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "worldRulesVersion")
        let legacy = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        XCTAssertNil(legacy.worldRulesVersion)
        XCTAssertEqual(legacy.effectiveWorldRulesVersion, .v1)
        XCTAssertEqual(legacy.careerWind, CareerWind.wind(careerID: legacy.careerID))

        let prologueComplete = try engine.completePrologue(.init(seed: started.nextSeed, state: started.snapshot))
        XCTAssertEqual(prologueComplete.snapshot.worldRulesVersion, 2)
        let schoolChosen = try engine.chooseSchool(.init(
            seed: prologueComplete.nextSeed, state: prologueComplete.snapshot, schoolID: .miraeAnalytics
        ))
        XCTAssertEqual(schoolChosen.snapshot.worldRulesVersion, 2)
        let trained = try engine.commitTraining(.init(
            seed: schoolChosen.nextSeed, state: schoolChosen.snapshot, focus: .command, intensity: .standard
        ))
        XCTAssertEqual(trained.snapshot.worldRulesVersion, 2)

        var tamperedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        tamperedObject["worldRulesVersion"] = CareerRulesVersion.v1.rawValue
        let tampered = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: tamperedObject)
        )
        XCTAssertThrowsError(
            try engine.completePrologue(.init(seed: started.nextSeed, state: tampered))
        )
    }

    func testTrainingRelationshipFanAndDraftEffectsReachEngineResults() throws {
        let engine = HighSchoolCareerEngine()

        let commandSeed = try seed(for: "command_year") { state in
            state.pitcher.command < (state.talent ?? .unlimited).ceiling(.command)
        }
        var command = try engine.start(.init(seed: commandSeed, presetID: "precision_commander"))
        command = try engine.completePrologue(.init(seed: command.nextSeed, state: command.snapshot))
        command = try engine.chooseSchool(.init(seed: command.nextSeed, state: command.snapshot, schoolID: .miraeAnalytics))
        XCTAssertNotEqual(engine.trainingOutlook(state: command.snapshot, focus: .command, intensity: .standard), .none)
        let commandTraining = try engine.commitTraining(.init(
            seed: command.nextSeed, state: command.snapshot, focus: .command, intensity: .standard
        ))
        XCTAssertGreaterThanOrEqual(commandTraining.snapshot.lastTraining?.growth ?? 0, 1)
        let velocityTraining = try engine.commitTraining(.init(
            seed: command.nextSeed, state: command.snapshot, focus: .velocity, intensity: .standard
        ))
        // 구위 표준 훈련 8 + 구위형 피로 1 + 코스의 해 불리 보정 1.
        XCTAssertEqual(velocityTraining.snapshot.lastTraining?.fatigueChange, 10)

        let heatSeed = try seed(for: "heatwave") { state in
            (state.schedule?.trainingsByChapter.first ?? 0) >= 2
        }
        var heat = try engine.start(.init(seed: heatSeed, presetID: "precision_commander"))
        heat = try engine.completePrologue(.init(seed: heat.nextSeed, state: heat.snapshot))
        heat = try engine.chooseSchool(.init(seed: heat.nextSeed, state: heat.snapshot, schoolID: .miraeAnalytics))
        heat = try engine.commitTraining(.init(
            seed: heat.nextSeed, state: heat.snapshot, focus: .velocity, intensity: .intensive
        ))
        // 구위 집중 훈련 15 + 구위형 피로 1 + 긴 여름 2.
        XCTAssertEqual(heat.snapshot.lastTraining?.fatigueChange, 18)
        heat = try engine.commitTraining(.init(
            seed: heat.nextSeed, state: heat.snapshot, focus: .recovery, intensity: .standard
        ))
        XCTAssertEqual(heat.snapshot.lastTraining?.fatigueChange, -12)

        let batterySeed = try seed(for: "battery_year")
        var battery = try preparedCareer(seed: batterySeed, schoolID: .hanbitTraditional)
        battery = try advance(battery, with: engine, untilRelationship: "catcher")
        let batteryResolved = try engine.resolveRelationship(.init(
            seed: battery.nextSeed, state: battery.snapshot, response: .listen
        ))
        let batteryResult = try XCTUnwrap(batteryResolved.snapshot.lastRelationship)
        XCTAssertEqual(batteryResult.trustAfter - batteryResult.trustBefore, 6)

        let spotlightSeed = try seed(for: "spotlight_year")
        var spotlight = try preparedCareer(seed: spotlightSeed, schoolID: .hanbitTraditional)
        spotlight = try advance(spotlight, with: engine, untilRelationship: "catcher")
        let spotlightResolved = try engine.resolveRelationship(.init(
            seed: spotlight.nextSeed, state: spotlight.snapshot, response: .challenge
        ))
        let spotlightResult = try XCTUnwrap(spotlightResolved.snapshot.lastRelationship)
        XCTAssertEqual(spotlightResult.trustAfter - spotlightResult.trustBefore, -6)

        let monsterSeed = try seed(for: "monster_generation")
        var monster = try preparedCareer(seed: monsterSeed, schoolID: .miraeAnalytics)
        monster = try advance(monster, with: engine, until: .importantGame)
        let fanBefore = monster.snapshot.fanInterest
        let game = try engine.recordImportantGame(.init(
            seed: monster.nextSeed, state: monster.snapshot,
            report: .init(
                scenarioNumber: monster.snapshot.performance.importantGamesCompleted + 1,
                pitches: 16, strikeouts: 3, walks: 0, runsAllowed: 1,
                expectedDamage: 500, actualDamage: 400, recommendationAccepted: 8
            )
        ))
        XCTAssertEqual(game.snapshot.fanInterest - fanBefore, 7)

        let scoutState = try engine.start(.init(
            seed: seed(for: "scout_frenzy"), presetID: "precision_commander"
        )).snapshot
        XCTAssertEqual(HighSchoolCareerEngine.draftEvaluationCore(state: scoutState).windDelta, 0)
        let underdogState = try engine.start(.init(
            seed: seed(for: "underdog_year"), presetID: "precision_commander"
        )).snapshot
        XCTAssertEqual(HighSchoolCareerEngine.draftEvaluationCore(state: underdogState).windDelta, 1)
    }

    /// Direct evaluation levers are tested on a dense boundary cohort. Nine equally represented
    /// scores around the standard threshold make one evaluation point worth 11.1%p and two worth
    /// 22.2%p, so this deterministic fixture catches the plan's >±12%p failure without putting a
    /// thousand multi-chapter careers into the unit-test hot path. Full-career effects remain in
    /// the release balance batch; this guard specifically prevents stacked initial-fan + explicit
    /// draft bonuses from recreating scout_frenzy's measured +21.4%p regression.
    func testPublishedDraftLeversStayWithinTwelvePointBoundaryGuardrail() {
        let boundaryScores = Array(57...65)
        let threshold = 61
        func rate(shift: Int) -> Double {
            Double(boundaryScores.filter { $0 + shift >= threshold }.count)
                / Double(boundaryScores.count)
        }
        func fanTerm(_ interest: Int) -> Int {
            min(3, max(-3, (interest - 40) / 15))
        }

        let baseline = rate(shift: 0)
        let calmFanTerm = fanTerm(5)
        for wind in CareerWind.v2All {
            let publishedShift = wind.rules.draftEvaluationDelta
                + fanTerm(wind.startingFanInterest) - calmFanTerm
            let deltaPoints = abs(rate(shift: publishedShift) - baseline) * 100
            XCTAssertLessThanOrEqual(
                deltaPoints, 12,
                "\(wind.id) moves the deterministic draft boundary by \(deltaPoints)%p"
            )
        }
    }

    func testLaunchRuleMagnitudesStayInsideBalanceGuardrails() {
        for wind in CareerWind.v2All {
            XCTAssertTrue((-3...5).contains(wind.rivalBonus), wind.id)
            XCTAssertTrue((0...20).contains(wind.startingFanInterest), wind.id)
            XCTAssertTrue((0...150).contains(wind.rewardBonusPermille), wind.id)
            XCTAssertTrue((0...1).contains(wind.rules.favoredTrainingBonus), wind.id)
            XCTAssertTrue((0...2).contains(wind.rules.trainingFatigueDelta), wind.id)
            XCTAssertTrue((0...1).contains(wind.rules.extraFatigueDelta), wind.id)
            XCTAssertTrue((0...4).contains(wind.rules.recoveryBonus), wind.id)
            XCTAssertTrue((0...2).contains(wind.rules.favoredRelationshipBonus), wind.id)
            XCTAssertTrue((0...2).contains(wind.rules.relationshipLossPenalty), wind.id)
            XCTAssertTrue((0...5).contains(wind.rules.fanInterestGainBonus), wind.id)
            XCTAssertTrue((0...2).contains(wind.rules.draftEvaluationDelta), wind.id)
        }
    }

    private func wind(_ id: String) throws -> CareerWind {
        try XCTUnwrap(CareerWind.v2All.first { $0.id == id })
    }

    private func seed(
        for windID: String,
        stateCondition: ((HighSchoolCareerSnapshot) -> Bool)? = nil
    ) throws -> String {
        let engine = HighSchoolCareerEngine()
        for value in 1...20_000 {
            let seed = String(value)
            let careerID = "career-\(seed)-life-1"
            guard CareerWind.wind(careerID: careerID, rulesVersion: .v2).id == windID else { continue }
            if let stateCondition {
                let state = try engine.start(.init(seed: seed, presetID: "precision_commander")).snapshot
                guard stateCondition(state) else { continue }
            }
            return seed
        }
        throw NSError(domain: "CareerWindTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "No seed for \(windID)"])
    }

    private func preparedCareer(seed: String, schoolID: SchoolID) throws -> HighSchoolCareerResult {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: seed, presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        return try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: schoolID))
    }

    private func advance(
        _ initial: HighSchoolCareerResult,
        with engine: HighSchoolCareerEngine,
        until targetPhase: HighSchoolCareerPhase? = nil,
        untilRelationship targetRelationship: String? = nil
    ) throws -> HighSchoolCareerResult {
        var result = initial
        for _ in 0..<100 {
            if let targetPhase, result.snapshot.phase == targetPhase { return result }
            if let targetRelationship,
               result.snapshot.phase == .relationship,
               result.snapshot.currentRelationshipEvent?.category == targetRelationship {
                return result
            }
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot, focus: .command, intensity: .standard
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    report: .init(
                        scenarioNumber: number, pitches: 16, strikeouts: 3, walks: 0,
                        runsAllowed: 0, expectedDamage: 400, actualDamage: 180,
                        recommendationAccepted: 8
                    )
                ))
            case .awakening:
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            default:
                break
            }
        }
        throw NSError(domain: "CareerWindTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Target phase was not reached"])
    }
}
