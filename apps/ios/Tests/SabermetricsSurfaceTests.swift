import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain

@MainActor
final class SabermetricsSurfaceTests: XCTestCase {
    func testPopulatedFixtureReconcilesTwoCompletedSeasonsAndLivePitchAlbum() throws {
        let fixture = try MobileCareerStore.populatedProFixture()
        let state = fixture.result.snapshot
        XCTAssertEqual(state.season, 3)
        XCTAssertEqual(state.phase, .seasonReview)
        XCTAssertEqual(state.careerStats.map(\.season), [1, 2])
        XCTAssertTrue(state.careerStats.allSatisfy { $0.games > 0 && $0.earnedRuns != nil })
        let lines = try XCTUnwrap(state.gameLines)
        XCTAssertFalse(lines.isEmpty)
        XCTAssertEqual(lines.reduce(0) { $0 + $1.outs }, state.currentStats.inningsOuts)
        XCTAssertEqual(lines.reduce(0) { $0 + $1.runsAllowed }, state.currentStats.runsAllowed)
        XCTAssertGreaterThan(CareerDisplayRules.abilityHistory(for: state).count, 2)
        XCTAssertFalse(fixture.replays.isEmpty)
        XCTAssertTrue(fixture.replays.allSatisfy { $0.trajectory.count >= 8 && $0.trajectory.count % 4 == 0 })
        let reviewed = try ProCareerEngine().reviewSeason(.init(seed: fixture.result.nextSeed, state: state))
        XCTAssertEqual(reviewed.snapshot.careerStats.count, 3)
        XCTAssertNotNil(MobileCareerStore.seasonComparison(state: reviewed.snapshot))
        let era = ProCareerPresentation.eraText(seasons: ProCareerPresentation.recordedSeasons(state))
        XCTAssertNotEqual(era, "—")
        XCTAssertEqual(ProCareerPresentation.recordedSeasons(reviewed.snapshot).count, 3)
    }

    func testERAStaysUnknownForMissingLedgersAndUsesOutWeightedTotals() {
        let first = ProSeasonStats(season: 1, teamID: "seoul_comets", inningsOuts: 27, runsAllowed: 5, earnedRuns: 3)
        let second = ProSeasonStats(season: 2, teamID: "seoul_comets", inningsOuts: 54, runsAllowed: 2, earnedRuns: 1)
        XCTAssertEqual(ProCareerPresentation.eraText(seasons: [first, second]), "1.33")
        XCTAssertEqual(ProCareerPresentation.eraText(seasons: []), "—")
        XCTAssertEqual(ProCareerPresentation.eraText(seasons: [first, .init(season: 2, teamID: "seoul_comets", inningsOuts: 27)]), "—")
        XCTAssertEqual(ProCareerPresentation.eraText(seasons: [.init(season: 1, teamID: "seoul_comets", earnedRuns: 0)]), "—")
    }

    func testRecordsSettlementRetirementAndShareStayDisplayOnly() throws {
        let record = try IOSSourceScan.read("apps/ios/Sources/Features/Shell/RecordView.swift")
        let recordBoard = try IOSSourceScan.typeBody(
            "RecordBoard",
            in: "apps/ios/Sources/Features/Shell/RecordView.swift"
        )
        let highSchool = try IOSSourceScan.typeBody(
            "HighSchoolRecordBoard",
            in: "apps/ios/Sources/Features/Shell/RecordView.swift"
        )
        XCTAssertTrue(record.contains("struct SaberMetricsCard"))
        XCTAssertTrue(recordBoard.contains("SaberMetricsCard(board:"))
        XCTAssertTrue(record.contains("record.saber.row.\\(line.id)"))
        XCTAssertTrue(record.contains("MobileCareerStore.saberBoard(state: state)"))
        XCTAssertFalse(recordBoard.contains("SabermetricsRules."))
        XCTAssertFalse(highSchool.contains("SaberMetricsCard"))
        XCTAssertFalse(highSchool.contains("record.saber"))

        let settlement = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/ProSeasonSettlementView.swift")
        XCTAssertTrue(settlement.contains("ProSeasonSettlementCopy.saber("))
        XCTAssertTrue(settlement.contains("pro.settlement.saber"))
        XCTAssertFalse(settlement.contains("arguments:"))

        let retirement = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/ProRetirementViews.swift")
        XCTAssertTrue(retirement.contains("totalsWAR"))
        XCTAssertTrue(retirement.contains("pro.retirement.career.war"))
        XCTAssertFalse(retirement.contains("SabermetricsRules."))

        let share = try IOSSourceScan.read("apps/ios/Sources/Presentation/CareerSharePresentation.swift")
        XCTAssertTrue(share.contains("ShareUICopyKey.retirementSeasonsWARLabel"))
        XCTAssertTrue(share.contains("CareerShareCardLayout.maxStats") || share.contains("stats: ["))
    }

    func testStoreProjectionMatchesDisplayRules() throws {
        let result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "세이버",
            seed: 202_609_03
        )
        XCTAssertEqual(
            MobileCareerStore.saberBoard(state: result.snapshot),
            CareerDisplayRules.saberBoard(for: result.snapshot)
        )
    }

    func testSaberSectionRendersAndWritesScreenshot() throws {
        let board = SabermetricsRules.board(
            completed: [
                ProSeasonStats(
                    season: 1,
                    teamID: "daegu-forge",
                    games: 32,
                    starts: 32,
                    inningsOuts: 600,
                    strikeouts: 200,
                    walks: 50,
                    runsAllowed: 80,
                    hits: 180,
                    homeRuns: 15,
                    wins: 14,
                    losses: 8
                ),
                ProSeasonStats(
                    season: 2,
                    teamID: "daegu-forge",
                    games: 30,
                    starts: 30,
                    inningsOuts: 540,
                    strikeouts: 160,
                    walks: 55,
                    runsAllowed: 90,
                    hits: 170,
                    homeRuns: 18,
                    wins: 11,
                    losses: 10
                ),
            ],
            current: ProSeasonStats(
                season: 3,
                teamID: "daegu-forge",
                games: 12,
                starts: 12,
                inningsOuts: 210,
                strikeouts: 70,
                walks: 18,
                runsAllowed: 28,
                hits: 60,
                homeRuns: 6,
                wins: 5,
                losses: 3
            )
        )
        let renderer = ImageRenderer(content:
            SaberMetricsCard(board: board)
                .frame(width: 390)
                .padding(16)
                .background(BaseballTheme.canvas)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 4_000)

        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("releases/qa-1.2.9/saber")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("records-saber.png")
        try data.write(to: url)
        print("SABER_SECTION \(url.path) px=\(image.size.width * image.scale)x\(image.size.height * image.scale)")
    }

    func testRetirementShareKeepsFiveStatsAndMergesSeasonWAR() throws {
        let result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "민서준",
            seed: 202_607_23
        )
        let resolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
        let model = CareerSharePresentation.retirement(
            state: result.snapshot,
            stamp: CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 1),
            resolver: resolver
        )
        XCTAssertLessThanOrEqual(model.stats.count, CareerShareCardLayout.maxStats)
        XCTAssertEqual(model.stats.count, 5)
        XCTAssertEqual(
            model.stats[4].label,
            resolver.resolve(ShareUICopyKey.retirementSeasonsWARLabel)
        )
        XCTAssertTrue(model.stats[4].value.contains("·"))
    }
}
