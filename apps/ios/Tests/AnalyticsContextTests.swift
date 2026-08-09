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
}
