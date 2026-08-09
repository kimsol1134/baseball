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

    func testUITestArgumentsAreRecognized() {
        XCTAssertTrue(GameAnalytics.isUITest(arguments: ["app", "-uiTestResetCareer"]))
        XCTAssertTrue(GameAnalytics.isUITest(arguments: ["app", "-uiTestPromoCapture"]))
        XCTAssertFalse(GameAnalytics.isUITest(arguments: ["app"]))
    }
}
