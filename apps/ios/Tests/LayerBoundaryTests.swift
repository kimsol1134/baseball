import XCTest
import BaseballIOSDomain

final class LayerBoundaryTests: XCTestCase {
    func testPersistenceDoesNotMentionApplicationStores() throws {
        let source = try IOSSourceScan.readAll(try files(under: "packages/ios-layers/Sources/BaseballIOSPersistence", suffix: ".swift"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore"), "Persistence must not reference HighSchoolCareerStore")
        XCTAssertFalse(source.contains("MobileCareerStore"), "Persistence must not reference MobileCareerStore")
    }

    func testDomainDoesNotMentionStoresOrPersistence() throws {
        let source = try IOSSourceScan.readAll(try files(under: "packages/ios-layers/Sources/BaseballIOSDomain", suffix: ".swift"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore"))
        XCTAssertFalse(source.contains("MobileCareerStore"))
        XCTAssertFalse(source.contains("HighSchoolCareerPersistence"))
        XCTAssertFalse(source.contains("ProCareerPersistence"))
        XCTAssertFalse(source.contains("SaveSync"))
    }

    func testFeatureViewsDoNotCallJourneyRuleEngines() throws {
        let source = try IOSSourceScan.readAll(try files(under: "apps/ios/Sources/Features", suffix: ".swift"))
        XCTAssertFalse(source.contains("ProTeamLegacyRules."), "views must use MobileCareerStore projections")
        XCTAssertFalse(source.contains("ProCareerGoalRules."), "views must use MobileCareerStore projections")
        XCTAssertFalse(source.contains("ProCareerGoalBoardRules."), "views must use MobileCareerStore projections")
        XCTAssertFalse(source.contains("ProCareerMilestoneRules."), "views must use MobileCareerStore projections")
        XCTAssertFalse(source.contains("ProRetirementRules."), "views must use MobileCareerStore projections")
        XCTAssertFalse(source.contains("PitchLearningRules."), "views must use CareerDisplayRules")
        XCTAssertFalse(source.contains("PitcherBuildRules."), "views must use CareerDisplayRules")
        XCTAssertFalse(source.contains("ProFinanceRules."), "views must use CareerDisplayRules")
        XCTAssertFalse(source.contains("NicknameRules."), "views must use CareerDisplayRules")
        XCTAssertFalse(source.contains("MasteryEffectRules."), "views must use CareerDisplayRules")
        XCTAssertFalse(source.contains("PitchAbilityRules."), "views must use CareerDisplayRules")
        XCTAssertFalse(source.contains("HighSchoolCareerEngine("))
        XCTAssertFalse(source.contains("HighSchoolCareerEngine."))
        XCTAssertFalse(source.contains("ProCareerEngine."))
        XCTAssertFalse(source.contains("import BaseballIOSPersistence"), "views must not import Persistence")
        XCTAssertFalse(
            source.replacingOccurrences(of: "CareerSaveSync.", with: "").contains("SaveSync."),
            "views must use CareerSaveSync"
        )
        XCTAssertFalse(source.contains("GameAnalytics."), "views must use CareerTelemetry")
        XCTAssertFalse(
            source.replacingOccurrences(of: "CareerReviewPrompt.", with: "").contains("ReviewPrompt."),
            "views must use CareerReviewPrompt"
        )
        XCTAssertFalse(source.contains("HighSchoolCareerStore.PlayerBondMemory"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.InheritedStartComparison"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.LoadState"))
    }

    func testPresentationDoesNotCreateCareerEngines() throws {
        let source = try IOSSourceScan.readAll(try files(under: "apps/ios/Sources/Presentation", suffix: ".swift"))
        XCTAssertFalse(source.contains("HighSchoolCareerEngine("))
        XCTAssertFalse(source.contains("HighSchoolCareerEngine."))
        XCTAssertFalse(source.contains("ProCareerEngine."))
        XCTAssertFalse(source.contains("PitchLearningRules."))
        XCTAssertFalse(source.contains("PitcherBuildRules."))
        XCTAssertFalse(source.contains("ProFinanceRules."))
        XCTAssertFalse(source.contains("NicknameRules."))
        XCTAssertFalse(source.contains("MasteryEffectRules."))
        XCTAssertFalse(source.contains("PitchAbilityRules."))
        XCTAssertFalse(source.contains("ProCareerGoalBoardRules."))
        XCTAssertFalse(source.contains("ProCareerMilestoneRules."))
        XCTAssertFalse(source.contains("ProRetirementRules."))
        XCTAssertFalse(source.contains("import BaseballIOSPersistence"))
    }

    func testApplicationStoresDoNotCallPlatformAnalyticsDirectly() throws {
        let paths = try files(under: "apps/ios/Sources/Application", suffix: ".swift")
            .filter {
                !$0.hasSuffix("CareerTelemetry.swift")
                    && !$0.hasSuffix("CareerSaveSync.swift")
                    && !$0.hasSuffix("CareerDisplayRules.swift")
            }
        let source = try IOSSourceScan.readAll(paths)
        XCTAssertFalse(source.contains("GameAnalytics."), "stores must use CareerTelemetry")
        XCTAssertFalse(
            source.replacingOccurrences(of: "CareerReviewPrompt.", with: "").contains("ReviewPrompt."),
            "stores must use CareerReviewPrompt"
        )
        XCTAssertFalse(source.contains("DailyStreak."), "stores must use CareerPlayClock")
        XCTAssertFalse(source.contains("SaveSync."), "stores must use CareerSaveSync")
    }

    func testPresentationDoesNotOwnStoreSessionTypes() throws {
        let source = try IOSSourceScan.readAll(try files(under: "apps/ios/Sources/Presentation", suffix: ".swift"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.TrainingReceipt"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.Bloom"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.LifeRecord"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.RivalLedger"))
        XCTAssertFalse(source.contains("HighSchoolCareerStore.ChronicleEntry"))
        XCTAssertFalse(source.contains("MobileCareerStore.FeedbackCue"))
        XCTAssertFalse(source.contains("MobileCareerStore.AbilityGain"))
    }

    private func files(under relativeDirectory: String, suffix: String) throws -> [String] {
        let root = IOSSourceScan.repositoryRoot().appendingPathComponent(relativeDirectory)
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var paths: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.path.hasSuffix(suffix) {
                paths.append(url.path.replacingOccurrences(
                    of: IOSSourceScan.repositoryRoot().path + "/",
                    with: ""
                ))
            }
        }
        XCTAssertFalse(paths.isEmpty, relativeDirectory)
        return paths.sorted()
    }
}
