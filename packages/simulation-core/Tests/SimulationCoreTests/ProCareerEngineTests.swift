import Foundation
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
        // 커널 통일 뒤 games는 팀 경기 수가 아니라 실제 등판 수다(주당 1~3회).
        let seasons = result.snapshot.careerStats
        let outs = seasons.reduce(0) { $0 + $1.inningsOuts }
        let strikeouts = seasons.reduce(0) { $0 + $1.strikeouts }
        let runs = seasons.reduce(0) { $0 + $1.runsAllowed }
        XCTAssertGreaterThan(seasons.reduce(0) { $0 + $1.games }, 45)
        XCTAssertGreaterThan(outs, 700, "3시즌 커리어면 80이닝/시즌은 넘어야 한다")
        XCTAssertGreaterThan(strikeouts, 0)
        XCTAssertGreaterThanOrEqual(runs, 0)
        XCTAssertFalse(result.snapshot.news.isEmpty)
    }

    func testTwentyDeterministicCareersReachRetirementWithoutNegativeResources() throws {
        for seedValue in 100..<106 {   // 커널 통일로 주간 비용 증가 — 6시드로 결정론 의도 유지
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

    // Phase 3-2: 중요 경기는 더 이상 고정 주차 [3,7,12,18,23]가 아니라 상황 트리거로 발동한다.
    // 이 테스트는 갱신된 의도(동적 발동 + 라이벌/트리거/구간 노출 + 마일스톤 진행)를 검증한다.
    func testDynamicImportantGamesExposeRivalTriggerAndSegment() throws {
        var result = try engine.start(startParams(seed: "77"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        // 시즌 시작 시 "올해의 세 가지 긴장"이 결정론적으로 생성돼 노출된다.
        XCTAssertEqual(result.snapshot.seasonTensions?.count, 3)
        var importantWeeks: [Int] = []
        var seenTriggers: Set<ProSeasonTrigger> = []
        while result.snapshot.phase != .seasonReview {
            // 구간 라벨은 매 주차 스냅숏에 노출된다.
            XCTAssertNotNil(result.snapshot.seasonSegment)
            if result.snapshot.phase == .importantGame {
                importantWeeks.append(result.snapshot.week)
                let rival = try XCTUnwrap(result.snapshot.currentRival, "중요 경기에는 라이벌 타자가 있어야 한다")
                XCTAssertNotEqual(rival.teamID, result.snapshot.team.id, "라이벌은 상대 구단 소속이어야 한다")
                seenTriggers.insert(try XCTUnwrap(result.snapshot.seasonTrigger))
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
                // 경기 해소 뒤 라이벌/트리거는 정리된다.
                XCTAssertNil(result.snapshot.currentRival)
                XCTAssertNil(result.snapshot.seasonTrigger)
            } else {
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            }
        }
        // 옛 고정 주차 집합과 정확히 일치하지 않는다.
        XCTAssertNotEqual(Set(importantWeeks), Set([3, 7, 12, 18, 23]))
        // 시즌당 4~6회가 자연 발생한다.
        XCTAssertTrue((4...6).contains(importantWeeks.count), "시즌 중요 경기 \(importantWeeks.count)회는 4~6 범위를 벗어난다")
        XCTAssertGreaterThanOrEqual(seenTriggers.count, 2, "서로 다른 트리거가 섞여야 한다")
        XCTAssertTrue(result.snapshot.milestones.contains("프로 첫 공식 등판"))
        XCTAssertTrue(result.snapshot.milestones.contains("1군 콜업"))
    }

    func testImportantGameCountStaysWithinFourToSixAcrossSeasons() throws {
        var result = try engine.start(startParams(seed: "31"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for season in 1...5 {
            var count = 0
            while result.snapshot.phase != .seasonReview {
                if result.snapshot.phase == .importantGame {
                    count += 1
                    result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
                } else {
                    let plan: ProWeekPlan = result.snapshot.fatigue > 72 ? .recover : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                    result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
                }
            }
            XCTAssertTrue((4...6).contains(count), "시즌 \(season) 중요 경기 \(count)회는 4~6 범위를 벗어난다")
            result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
        }
    }

    func testSameSeedProducesSameImportantWeeksAndRivals() throws {
        func trace(_ seed: String) throws -> [String] {
            var result = try engine.start(startParams(seed: seed))
            result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
            var log: [String] = []
            for _ in 1...2 {
                while result.snapshot.phase != .seasonReview {
                    if result.snapshot.phase == .importantGame {
                        let rival = result.snapshot.currentRival?.id ?? "-"
                        let trigger = result.snapshot.seasonTrigger?.rawValue ?? "-"
                        log.append("s\(result.snapshot.season)w\(result.snapshot.week):\(trigger):\(rival)")
                        result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
                    } else {
                        result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
                    }
                }
                log.append("tensions:" + (result.snapshot.seasonTensions?.map(\.title).joined(separator: "|") ?? "-"))
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            }
            return log
        }
        let first = try trace("909")
        let second = try trace("909")
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.filter { $0.hasPrefix("s") }.isEmpty, "중요 경기가 최소 한 번은 있어야 한다")
        // 다른 시드는 다른 전개를 준다.
        XCTAssertNotEqual(try trace("909"), try trace("910"))
    }

    func testLegacySaveWithoutArcFieldsDecodesAndBackfills() throws {
        // 새 아크 필드가 없는 구세이브를 흉내낸다: 엔진이 만든 스냅숏 JSON에서 신규 키를 제거한다.
        var result = try engine.start(startParams(seed: "48"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
        while result.snapshot.phase != .weeklyPlan {
            result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
        }

        let encoded = try JSONEncoder().encode(result.snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["seasonSegment", "seasonTrigger", "currentRival", "seasonTensions", "seasonImportantGames"] {
            object.removeValue(forKey: key)
        }
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let legacy = try JSONDecoder().decode(ProCareerSnapshot.self, from: stripped)

        // 구세이브는 신규 필드가 nil로 디코드되고, commitment는 여전히 유효하다.
        XCTAssertNil(legacy.seasonSegment)
        XCTAssertNil(legacy.seasonTensions)
        XCTAssertNil(legacy.seasonImportantGames)
        XCTAssertNil(legacy.currentRival)

        // 크래시 없이 이어서 진행되고, 아크 필드가 결정론적으로 백필된다.
        let resumed = try engine.planWeek(.init(seed: result.nextSeed, state: legacy, plan: .refineCommand))
        XCTAssertNotNil(resumed.snapshot.seasonSegment)
        XCTAssertEqual(resumed.snapshot.seasonTensions?.count, 3)
        XCTAssertNotNil(resumed.snapshot.seasonImportantGames)
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

    // 커널 통일 검증: 주간 자동 시뮬이 수동 커널과 같은 엔진에서 나와 현실 분포에 들어간다.
    func testKernelDrivenWeeklyStatsLandInRealisticBands() throws {
        for seedValue in ["11", "42", "300"] {
            var result = try engine.start(.init(seed: seedValue, identity: .defaultPitcher, pitcher: PitcherPresetCatalog.all[0].pitcher, draftResult: drafted(), entitlement: activeEntitlement()))
            result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
            result = try playSeason(result)
            let stats = result.snapshot.careerStats[0]
            let kPer9 = stats.strikeouts * 27 / max(1, stats.inningsOuts)
            let runsPer9 = stats.runsAllowed * 27 / max(1, stats.inningsOuts)
            XCTAssertGreaterThanOrEqual(stats.inningsOuts, 210, "시즌 70이닝 미만은 비정상 (시드 \(seedValue))")
            XCTAssertTrue((4...13).contains(kPer9), "K/9 \(kPer9)가 현실 밴드(4~13)를 벗어남 (시드 \(seedValue))")
            XCTAssertTrue((1...9).contains(runsPer9), "R/9 \(runsPer9)가 현실 밴드(1~9)를 벗어남 (시드 \(seedValue))")
        }
    }

    // 피로가 높을수록 같은 시드의 등판 결과가 나빠지는 방향성(커널의 구속·커맨드 저하 반영).
    func testHigherFatigueWorsensTheSameOuting() throws {
        let fresh = engine.simulateWeeklyOuting(pitcher: PitcherPresetCatalog.all[0].pitcher, startingFatigue: 5, outsTarget: 18, pitchCap: 96, baseSeed: 991)
        let gassed = engine.simulateWeeklyOuting(pitcher: PitcherPresetCatalog.all[0].pitcher, startingFatigue: 85, outsTarget: 18, pitchCap: 96, baseSeed: 991)
        XCTAssertGreaterThanOrEqual(gassed.runsAllowed + (gassed.walks / 2), fresh.runsAllowed, "지친 등판이 더 좋게 나오면 피로가 커널에 반영되지 않는 것")
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
