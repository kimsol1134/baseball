import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain
import BaseballIOSPersistence

@MainActor
final class ProCareerGoalBoardSurfaceTests: XCTestCase {
    func testRecordAndWeeklySurfacesExposeGoalBoardOnlyForProCareer() throws {
        let record = try IOSSourceScan.read("apps/ios/Sources/Features/Shell/RecordView.swift")
        let recordBoard = try IOSSourceScan.typeBody(
            "RecordBoard",
            in: "apps/ios/Sources/Features/Shell/RecordView.swift"
        )
        let highSchool = try IOSSourceScan.typeBody(
            "HighSchoolRecordBoard",
            in: "apps/ios/Sources/Features/Shell/RecordView.swift"
        )
        XCTAssertTrue(record.contains("struct ProGoalBoardCard"))
        XCTAssertTrue(recordBoard.contains("ProGoalBoardCard(state: state)"))
        XCTAssertTrue(record.contains("pro.goalBoard.row.\\(row.id)"))
        XCTAssertTrue(record.contains("MobileCareerStore.goalBoard(state: state)"))
        XCTAssertFalse(recordBoard.contains("ProCareerGoalBoardRules."))
        XCTAssertFalse(highSchool.contains("ProGoalBoardCard"))
        XCTAssertFalse(highSchool.contains("pro.goalBoard"))
        XCTAssertFalse(highSchool.contains("goalBoard"))

        let weekly = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift")
        XCTAssertTrue(weekly.contains("pro.weekly.goalBoard"))
        XCTAssertTrue(weekly.contains("MobileCareerStore.goalBoard(state: state)"))
        XCTAssertTrue(weekly.contains("appTabSelection?.wrappedValue = .records"))
        XCTAssertTrue(weekly.contains("CopyDensity"))
        XCTAssertFalse(weekly.contains("ProCareerGoalBoardRules."))

        let settlement = try IOSSourceScan.typeBody(
            "ProCareerGoalMetricsView",
            in: "apps/ios/Sources/Presentation/ProCareerPresentation.swift"
        )
        XCTAssertTrue(settlement.contains("GoalPermilleBar("))
        XCTAssertTrue(settlement.contains("CareerDisplayRules.goalPermille("))
    }

    func testStoreProjectionMatchesDisplayRulesAndAnalyticsName() throws {
        let sync = SaveSync(key: "goal-board-proj-\(UUID().uuidString).json")
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(
            sync: sync,
            saveWriter: { _ in true },
            configuration: .journeyV1Tests
        )
        XCTAssertTrue(store.startNewCareer(preset: PitcherPresetCatalog.all[0], playerName: "목표판"))
        XCTAssertTrue(store.acceptContract(ambition: .franchiseIcon))
        let state = try XCTUnwrap(store.state)
        XCTAssertEqual(
            MobileCareerStore.goalBoard(state: state),
            CareerDisplayRules.goalBoard(for: state)
        )
        XCTAssertEqual(GameAnalytics.Event.proGoalBoardViewed.rawValue, "pro_goal_board_viewed")
        XCTAssertEqual(
            MobileCareerStore.goalPermilleBand(500),
            CareerDisplayRules.goalPermilleBand(500)
        )
        let rowID = try XCTUnwrap(MobileCareerStore.goalBoard(state: state).nearest?.id)
        XCTAssertFalse(rowID.isEmpty)
    }

    func testProRecordAndWeeklyGoalBoardRenderWithoutCallingRuleEngines() throws {
        let sync = SaveSync(key: "goal-board-\(UUID().uuidString).json")
        sync.clear()
        defer { sync.clear() }
        let career = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        XCTAssertTrue(career.startNewCareer(preset: PitcherPresetCatalog.all[0], playerName: "목표판"))
        XCTAssertTrue(career.acceptContract(ambition: .recordBook))
        let state = try XCTUnwrap(career.state)
        let highSchool = HighSchoolCareerStore(sync: SaveSync(key: "goal-board-hs-\(UUID().uuidString).json"))

        let recordRenderer = ImageRenderer(content:
            RecordView(highSchool: highSchool, career: career)
                .frame(width: 390, height: 1400)
        )
        recordRenderer.scale = 2
        let recordImage = recordRenderer.uiImage
        XCTAssertGreaterThan(try XCTUnwrap(recordImage?.pngData()).count, 4_000)

        let weeklyRenderer = ImageRenderer(content:
            ScrollView {
                WeeklyPlanView(career: career, state: state)
                    .padding()
            }
            .frame(width: 390, height: 920)
        )
        weeklyRenderer.scale = 2
        let weeklyImage = weeklyRenderer.uiImage
        XCTAssertGreaterThan(try XCTUnwrap(weeklyImage?.pngData()).count, 4_000)
    }

    func testHighSchoolRecordViewDoesNotRenderGoalBoardCard() throws {
        let highSchoolSource = try IOSSourceScan.typeBody(
            "HighSchoolRecordBoard",
            in: "apps/ios/Sources/RecordView.swift"
        )
        XCTAssertFalse(highSchoolSource.contains("accessibilityIdentifier(\"pro.goalBoard\")"))
        XCTAssertFalse(highSchoolSource.contains("ProGoalBoardCard"))
        XCTAssertTrue(
            try IOSSourceScan.typeBody(
                "RecordView",
                in: "apps/ios/Sources/RecordView.swift"
            ).contains("HighSchoolRecordBoard(")
        )
    }
}
