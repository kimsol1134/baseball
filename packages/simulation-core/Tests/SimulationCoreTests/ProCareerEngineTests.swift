import XCTest
@testable import SimulationCore

final class ProCareerEngineTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testLockedOrUndraftedPlayerCannotStartProCareer() throws {
        let locked = startParams(seed: "1", entitlement: .init(status: .locked, source: .development, verifiedAt: "2026-07-22"))
        XCTAssertThrowsError(try engine.start(locked))
        let undrafted = DraftResultSnapshot(outcome: .undrafted, evaluationScore: 45, projectedRange: "미지명", team: nil, round: nil, overallPick: nil, signingBonus: nil, firstSeasonGoal: nil, summary: "")
        XCTAssertThrowsError(try engine.start(.init(seed: "1", identity: .defaultPitcher, pitcher: pitcher(), draftResult: undrafted, entitlement: activeEntitlement())))
    }

    func testThreeSeasonProDebutSlicePreservesStatsAndReachesMajorLeague() throws {
        var result = try engine.start(startParams(seed: "7"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 1...3 {
            result = try playSeason(result)
            XCTAssertEqual(result.snapshot.phase, .offseasonDecision)
            if result.snapshot.season < 3 {
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            }
        }
        XCTAssertEqual(result.snapshot.careerStats.count, 3)
        XCTAssertEqual(result.snapshot.level, .major)
        XCTAssertGreaterThan(result.snapshot.careerStats.reduce(0) { $0 + $1.games }, 200)
        XCTAssertFalse(result.snapshot.news.isEmpty)
    }

    func testTwentyDeterministicCareersReachRetirementWithoutNegativeResources() throws {
        for seedValue in 100..<120 {
            var first = try engine.start(startParams(seed: String(seedValue)))
            first = try engine.signContract(.init(seed: first.nextSeed, state: first.snapshot))
            var second = try engine.start(startParams(seed: String(seedValue)))
            second = try engine.signContract(.init(seed: second.nextSeed, state: second.snapshot))
            for _ in 1...12 {
                first = try playSeason(first)
                second = try playSeason(second)
                XCTAssertEqual(first, second)
                if first.snapshot.phase == .retirementDecision { break }
                first = try engine.chooseOffseason(.init(seed: first.nextSeed, state: first.snapshot, decision: .continueCareer))
                second = try engine.chooseOffseason(.init(seed: second.nextSeed, state: second.snapshot, decision: .continueCareer))
            }
            first = try engine.chooseOffseason(.init(seed: first.nextSeed, state: first.snapshot, decision: .retire))
            XCTAssertEqual(first.snapshot.phase, .completed)
            XCTAssertNotNil(first.snapshot.hallOfFameScore)
            XCTAssertGreaterThanOrEqual(first.snapshot.fatigue, 0)
            XCTAssertTrue(first.snapshot.careerStats.allSatisfy { $0.games >= 0 && $0.runsAllowed >= 0 })
        }
    }

    func testImportantGamesFollowCareerArcsAndMilestonesSurfaceProgress() throws {
        var result = try engine.start(startParams(seed: "77"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        var importantWeeks: [Int] = []
        while result.snapshot.phase != .seasonReview {
            if result.snapshot.phase == .importantGame {
                importantWeeks.append(result.snapshot.week)
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
            } else {
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            }
        }

        XCTAssertEqual(importantWeeks.first, 3)
        XCTAssertTrue(importantWeeks.contains(7))
        XCTAssertFalse(importantWeeks.allSatisfy { $0.isMultiple(of: 4) })
        XCTAssertTrue(result.snapshot.milestones.contains("프로 첫 공식 등판"))
        XCTAssertTrue(result.snapshot.milestones.contains("1군 콜업"))
    }

    func testProTeamsPreserveDistinctDraftDevelopmentPlans() {
        XCTAssertGreaterThan(Set(ProCareerEngine.proTeams.map(\.need)).count, 1)
        XCTAssertEqual(Set(ProCareerEngine.proTeams.map(\.developmentPlan)).count, ProCareerEngine.proTeams.count)
        XCTAssertEqual(Set(ProCareerEngine.proTeams.map(\.positionCompetitor)).count, ProCareerEngine.proTeams.count)
    }

    func testStartBackfillsTeamProfilesFromOlderDraftRecords() throws {
        let canonical = ProCareerEngine.proTeams[0]
        let legacyTeam = DraftTeamSnapshot(
            id: canonical.id,
            name: canonical.name,
            need: canonical.need,
            demand: canonical.demand,
            developmentPlan: canonical.developmentPlan,
            positionCompetitor: canonical.positionCompetitor,
            proCoach: canonical.proCoach
        )
        let legacyDraft = DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: legacyTeam,
            round: 2,
            overallPick: 18,
            signingBonus: 120_000_000,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )

        let result = try engine.start(.init(
            seed: "24",
            identity: .defaultPitcher,
            pitcher: pitcher(),
            draftResult: legacyDraft,
            entitlement: activeEntitlement()
        ))

        XCTAssertEqual(result.snapshot.team, canonical)
        XCTAssertFalse((result.snapshot.team.competitorProfile ?? "").isEmpty)
        XCTAssertFalse((result.snapshot.team.coachProfile ?? "").isEmpty)
    }

    private func playSeason(_ initial: ProCareerResult) throws -> ProCareerResult {
        var result = initial
        while result.snapshot.phase != .seasonReview {
            if result.snapshot.phase == .importantGame {
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
            } else {
                let plan: ProWeekPlan = result.snapshot.fatigue > 72 ? .recover : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
            }
        }
        return try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
    }

    private func report(_ number: Int) -> ImportantInningReport {
        .init(scenarioNumber: number, pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0, expectedDamage: 380, actualDamage: 240, recommendationAccepted: 12)
    }

    private func startParams(seed: String, entitlement: ProEntitlementSnapshot? = nil) -> StartProCareerParams {
        .init(seed: seed, identity: .defaultPitcher, pitcher: pitcher(), draftResult: drafted(), entitlement: entitlement ?? activeEntitlement())
    }
    private func activeEntitlement() -> ProEntitlementSnapshot { .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22") }
    private func pitcher() -> PitcherSnapshot { .init(id: "p-1", name: "테스트투수", stuff: 58, command: 55, movement: 56, stamina: 57) }
    private func drafted() -> DraftResultSnapshot {
        .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명")
    }
}
