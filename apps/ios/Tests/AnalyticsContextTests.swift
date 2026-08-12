import XCTest
@testable import BaseballIOS

final class AnalyticsContextTests: XCTestCase {
    func testDebugBuildIsDevelopment() {
        let context = AnalyticsContext.resolve(
            appVersion: "1.0.2", build: "42", isDebug: true,
            receiptURL: URL(fileURLWithPath: "/receipt")
        )
        XCTAssertEqual(context.distribution, .debug)
        XCTAssertEqual(context.environment, .development)
        XCTAssertEqual(context.properties["platform"] as? String, "ios")
        XCTAssertEqual(context.properties["app_language"] as? String, "ko")
        XCTAssertEqual(context.properties["copy_schema_version"] as? Int, GameCopySchema.currentVersion)
    }

    func testSandboxReceiptIsTestFlightDevelopment() {
        let context = AnalyticsContext.resolve(
            appVersion: "1.0.2", build: "42", isDebug: false,
            receiptURL: URL(fileURLWithPath: "/StoreKit/sandboxReceipt")
        )
        XCTAssertEqual(context.distribution, .testflight)
        XCTAssertEqual(context.environment, .development)
    }

    func testProductionReceiptIsAppStoreProduction() {
        let context = AnalyticsContext.resolve(
            appVersion: "1.0.2", build: "42", isDebug: false,
            receiptURL: URL(fileURLWithPath: "/StoreKit/receipt")
        )
        XCTAssertEqual(context.distribution, .appStore)
        XCTAssertEqual(context.environment, .production)
        XCTAssertEqual(context.properties["app_version"] as? String, "1.0.2")
        XCTAssertEqual(context.properties["build"] as? String, "42")
    }

    @MainActor
    func testLanguageAndCopySchemaAreCommonContextOnly() {
        let context = AnalyticsContext.resolve(
            appVersion: "1.0.2", build: "42", isDebug: false,
            receiptURL: URL(fileURLWithPath: "/StoreKit/receipt"),
            appLanguage: .english,
            copySchemaVersion: 7
        )
        let payloads = GameAnalytics.payloads(
            for: ["screen": "career"], context: context
        )

        XCTAssertEqual(payloads.firebase["app_language"] as? String, "en")
        XCTAssertEqual(payloads.firebase["copy_schema_version"] as? Int, 7)
        XCTAssertEqual(payloads.amplitude["app_language"] as? String, "en")
        XCTAssertEqual(payloads.amplitude["copy_schema_version"] as? Int, 7)
        XCTAssertNil(payloads.firebase["player_name"])
        XCTAssertNil(payloads.firebase["copy"])
        XCTAssertNil(payloads.amplitude["player_name"])
        XCTAssertNil(payloads.amplitude["copy"])
    }

    func testReleaseBuildWithoutReceiptNeverEntersProductionCohort() {
        let context = AnalyticsContext.resolve(
            appVersion: "1.0.2", build: "42", isDebug: false,
            receiptURL: nil
        )
        XCTAssertEqual(context.distribution, .unknown)
        XCTAssertEqual(context.environment, .development)
        XCTAssertEqual(context.properties["distribution"] as? String, "unknown")
        XCTAssertEqual(context.properties["environment"] as? String, "development")
    }

    func testUITestArgumentsAreRecognized() {
        XCTAssertTrue(GameAnalytics.isUITest(arguments: ["app", "-uiTestResetCareer"]))
        XCTAssertTrue(GameAnalytics.isUITest(arguments: ["app", "-uiTestPromoCapture"]))
        XCTAssertFalse(GameAnalytics.isUITest(arguments: ["app"]))
    }

    @MainActor
    func testUITestResetClearsCompletedGameCount() {
        let suite = "AnalyticsContextTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        GameAnalytics.recordCompletedGame(defaults: defaults)
        XCTAssertEqual(GameAnalytics.completedGameCount(defaults: defaults), 1)

        GameAnalytics.resetCompletedGameCountForUITesting(defaults: defaults)
        XCTAssertEqual(GameAnalytics.completedGameCount(defaults: defaults), 0)
    }

    func testProCareerStartedRequiresAReadyNewCareerIdentity() {
        XCTAssertFalse(AppShell.proCareerCreationSucceeded(
            previousCareerID: nil, currentCareerID: nil, isReady: false
        ))
        XCTAssertFalse(AppShell.proCareerCreationSucceeded(
            previousCareerID: "pro-a", currentCareerID: "pro-b", isReady: false
        ))
        XCTAssertFalse(AppShell.proCareerCreationSucceeded(
            previousCareerID: "pro-a", currentCareerID: "pro-a", isReady: true
        ))
        XCTAssertTrue(AppShell.proCareerCreationSucceeded(
            previousCareerID: "pro-a", currentCareerID: "pro-b", isReady: true
        ))
        XCTAssertTrue(AppShell.proCareerCreationSucceeded(
            previousCareerID: nil, currentCareerID: "pro-b", isReady: true
        ))
    }

    @MainActor
    func testHighSchoolPitchSessionsHideTheParentTabBar() {
        XCTAssertFalse(AppShell.shouldHideHighSchoolTabBar(
            isOnboarding: false, hasPitchSession: false, hasTutorialSession: false
        ))
        XCTAssertTrue(AppShell.shouldHideHighSchoolTabBar(
            isOnboarding: true, hasPitchSession: false, hasTutorialSession: false
        ))
        XCTAssertTrue(AppShell.shouldHideHighSchoolTabBar(
            isOnboarding: false, hasPitchSession: true, hasTutorialSession: false
        ))
        XCTAssertTrue(AppShell.shouldHideHighSchoolTabBar(
            isOnboarding: false, hasPitchSession: false, hasTutorialSession: true
        ))
    }

    func testNewFunnelEventNamesAreStable() {
        XCTAssertEqual(GameAnalytics.Event.playerHeartlineSeen.rawValue, "player_heartline_seen")
        XCTAssertEqual(GameAnalytics.Event.recapContinueTapped.rawValue, "recap_continue_tapped")
        XCTAssertEqual(GameAnalytics.Event.proCareerStarted.rawValue, "pro_career_started")
        XCTAssertEqual(GameAnalytics.Event.proLegacyRecorded.rawValue, "pro_legacy_recorded")
        XCTAssertEqual(GameAnalytics.Event.signatureLegacyOptionsSeen.rawValue, "signature_legacy_options_seen")
        XCTAssertEqual(GameAnalytics.Event.signatureLegacySelected.rawValue, "signature_legacy_selected")
        XCTAssertEqual(GameAnalytics.Event.signatureLegacyEquipped.rawValue, "signature_legacy_equipped")
        XCTAssertEqual(GameAnalytics.Event.lifeCompleted.rawValue, "life_completed")
        XCTAssertEqual(GameAnalytics.Event.careerTrainingCompleted.rawValue, "career_training_completed")
        XCTAssertEqual(GameAnalytics.Event.gameGrowthApplied.rawValue, "game_growth_applied")
        XCTAssertEqual(GameAnalytics.Event.reminderOfferShown.rawValue, "reminder_offer_shown")
        XCTAssertEqual(GameAnalytics.Event.reminderOpened.rawValue, "reminder_opened")
        XCTAssertEqual(GameAnalytics.Event.returnPlanShown.rawValue, "return_plan_shown")
        XCTAssertEqual(GameAnalytics.Event.returnPlanTapped.rawValue, "return_plan_tapped")
        XCTAssertEqual(GameAnalytics.Event.returnPlanDismissed.rawValue, "return_plan_dismissed")
        XCTAssertEqual(GameAnalytics.Event.returnPlanEligible.rawValue, "return_plan_eligible")
        XCTAssertEqual(GameAnalytics.Event.returnPlanColdStart.rawValue, "return_plan_cold_start")
        XCTAssertEqual(GameAnalytics.Event.returnPlanNextDayOpen.rawValue, "return_plan_next_day_open")
    }

    @MainActor
    func testAmplitudeDirectPayloadAddsOnlyAmplitudeIngestionMarkers() {
        let context = AnalyticsContext.resolve(
            appVersion: "1.0.2", build: "42", isDebug: false,
            receiptURL: URL(fileURLWithPath: "/StoreKit/receipt")
        )
        let payloads = GameAnalytics.payloads(
            for: ["screen": "career"], context: context
        )

        XCTAssertEqual(payloads.firebase["screen"] as? String, "career")
        XCTAssertNil(payloads.firebase["ingestion_origin"])
        XCTAssertNil(payloads.firebase["event_schema_version"])
        XCTAssertEqual(payloads.amplitude["ingestion_origin"] as? String, "ios_sdk_direct")
        XCTAssertEqual(payloads.amplitude["event_schema_version"] as? Int, 2)
        XCTAssertEqual(payloads.amplitude["distribution"] as? String, "app_store")
        XCTAssertEqual(payloads.amplitude["environment"] as? String, "production")
        XCTAssertEqual(payloads.firebase["app_language"] as? String, "ko")
        XCTAssertEqual(payloads.firebase["copy_schema_version"] as? Int, GameCopySchema.currentVersion)
        XCTAssertEqual(payloads.amplitude["app_language"] as? String, "ko")
        XCTAssertEqual(payloads.amplitude["copy_schema_version"] as? Int, GameCopySchema.currentVersion)
    }

    @MainActor
    func testScopedOnceEventIsOncePerScopeWithoutSendingTheScope() {
        let name = "AnalyticsContextTests.scoped.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertTrue(GameAnalytics.logOnce(.careerWindSeen, scope: "career-a", defaults: defaults))
        XCTAssertFalse(GameAnalytics.logOnce(.careerWindSeen, scope: "career-a", defaults: defaults))
        XCTAssertTrue(GameAnalytics.logOnce(.careerWindSeen, scope: "career-b", defaults: defaults))
    }

    @MainActor
    func testCompletedGameCounterTracksSessionDeltaWithoutAnalyticsSDK() {
        let name = "AnalyticsContextTests.games.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }

        XCTAssertEqual(GameAnalytics.completedGameCount(defaults: defaults), 0)
        GameAnalytics.recordCompletedGame(defaults: defaults)
        GameAnalytics.recordCompletedGame(defaults: defaults)
        XCTAssertEqual(GameAnalytics.completedGameCount(defaults: defaults), 2)
    }
}
