import XCTest
@testable import SimulationCore

final class AbilityGrowthHistoryTests: XCTestCase {
    /// 능력이 새겨진 시즌만 점이 된다.
    func testOnlySeasonsThatRecordedAbilitiesBecomePoints() {
        let points = AbilityGrowthHistoryRules.points(
            seasons: [
                season(1, abilities: nil),
                season(2, abilities: [40, 41, 36, 38]),
                season(3, abilities: [46, 52, 36, 40]),
            ],
            current: nil,
            pitcher: nil
        )
        XCTAssertEqual(points.map(\.season), [2, 3], "능력이 없는 시즌이 점으로 지어졌습니다")
        XCTAssertEqual(points.first?.stuff, 40)
        XCTAssertEqual(points.last?.command, 52)
    }

    /// **진행 중인 시즌이 끝점이다.** 지난 시즌에서 끊기면 이번 성장이 화면에 안 보인다.
    func testTheSeasonInProgressBecomesTheFinalPoint() {
        let points = AbilityGrowthHistoryRules.points(
            seasons: [season(1, abilities: [40, 40, 40, 40])],
            current: season(2, abilities: nil),
            pitcher: .init(id: "p", name: "t", stuff: 55, command: 60, movement: 45, stamina: 50)
        )
        XCTAssertEqual(points.map(\.season), [1, 2])
        XCTAssertEqual(points.last?.stuff, 55)
        XCTAssertEqual(points.last?.stamina, 50)
    }

    /// 이미 기록으로 넘어간 시즌을 현재 능력으로 덮어쓰지 않는다.
    func testAnArchivedSeasonIsNotOverwrittenByTheCurrentPitcher() {
        let points = AbilityGrowthHistoryRules.points(
            seasons: [season(1, abilities: [40, 40, 40, 40])],
            current: season(1, abilities: [40, 40, 40, 40]),
            pitcher: .init(id: "p", name: "t", stuff: 80, command: 80, movement: 80, stamina: 80)
        )
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.stuff, 40)
    }

    func testChangeNeedsTwoPoints() {
        let single = AbilityGrowthHistoryRules.points(
            seasons: [season(1, abilities: [40, 40, 40, 40])], current: nil, pitcher: nil
        )
        XCTAssertNil(AbilityGrowthHistoryRules.change(single, axis: .stuff))
        let pair = AbilityGrowthHistoryRules.points(
            seasons: [season(1, abilities: [40, 40, 40, 40]), season(2, abilities: [52, 38, 40, 44])],
            current: nil, pitcher: nil
        )
        XCTAssertEqual(AbilityGrowthHistoryRules.change(pair, axis: .stuff), 12)
        // 내려간 축은 음수로 남는다. 노화를 0으로 감추지 않는다.
        XCTAssertEqual(AbilityGrowthHistoryRules.change(pair, axis: .command), -2)
    }

    /// **시즌을 넘기면 그 시점의 능력이 실제로 새겨진다**(규칙 12 이상).
    func testSeasonReviewStampsTheAbilitiesOfThatSeason() throws {
        let engine = ProCareerEngine()
        var result = try engine.start(.init(
            seed: "6001", identity: .defaultPitcher, pitcher: PitcherPresetCatalog.all[0].pitcher,
            draftResult: .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드",
                               team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18,
                               signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명"),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22")
        ))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        while result.snapshot.phase != .seasonReview {
            switch result.snapshot.phase {
            case .importantGame:
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: 1, pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0,
                                  expectedDamage: 380, actualDamage: 240, recommendationAccepted: 12)))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                let choice = try XCTUnwrap(decision.choices.first)
                result = try engine.applySeasonDecision(.init(seed: result.nextSeed, state: result.snapshot,
                                                              decisionID: decision.id, choiceID: choice.id))
            default:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .refineCommand))
            }
        }
        result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
        let archived = try XCTUnwrap(result.snapshot.careerStats.first)
        let abilities = try XCTUnwrap(archived.abilities, "시즌을 넘겼는데 능력이 새겨지지 않았습니다")
        XCTAssertEqual(abilities.count, 4)
        XCTAssertFalse(AbilityGrowthHistoryRules.history(state: result.snapshot).isEmpty)
    }

    /// 새 필드가 있어도 옛 저장은 그대로 열린다.
    func testASeasonRowWithoutAbilitiesStillDecodes() throws {
        let legacy = Data(#"{"season":3,"teamID":"t","games":20}"#.utf8)
        let decoded = try JSONDecoder().decode(ProSeasonStats.self, from: legacy)
        XCTAssertEqual(decoded.season, 3)
        XCTAssertNil(decoded.abilities)
        XCTAssertEqual(
            try JSONDecoder().decode(ProSeasonStats.self, from: JSONEncoder().encode(decoded)),
            decoded
        )
    }

    private func season(_ number: Int, abilities: [Int]?) -> ProSeasonStats {
        ProSeasonStats(
            season: number, teamID: "t", games: 20, inningsOuts: 300,
            strikeouts: 80, abilities: abilities
        )
    }
}
