import XCTest
@testable import BaseballIOS

final class AppLanguageTests: XCTestCase {
    func testEnglishLanguageRegionsNormalizeToEnglish() {
        XCTAssertEqual(AppLanguage(localeIdentifier: "en"), .english)
        XCTAssertEqual(AppLanguage(localeIdentifier: "en-US"), .english)
        XCTAssertEqual(AppLanguage(localeIdentifier: "en_GB"), .english)
        XCTAssertEqual(AppLanguage(localeIdentifier: "en-AU"), .english)
        XCTAssertEqual(AppLanguage(localeIdentifier: "en-CA"), .english)
    }

    func testKoreanRegionNormalizesToKorean() {
        XCTAssertEqual(AppLanguage(localeIdentifier: "ko-KR"), .korean)
        XCTAssertEqual(AppLanguage(localeIdentifier: "ko_KR"), .korean)
    }

    func testJapaneseLanguageRegionsNormalizeToJapanese() {
        XCTAssertEqual(AppLanguage(localeIdentifier: "ja"), .japanese)
        XCTAssertEqual(AppLanguage(localeIdentifier: "ja-JP"), .japanese)
        XCTAssertEqual(AppLanguage(localeIdentifier: "ja_JP"), .japanese)
    }

    func testUnknownLocaleUsesTheKoreanDevelopmentLanguage() {
        XCTAssertEqual(AppLanguage(localeIdentifier: "fr-FR"), .korean)
        XCTAssertEqual(AppLanguage(localeIdentifier: "", developmentLanguage: .korean), .korean)
        XCTAssertEqual(AppLanguage.resolve(preferredLocalizations: ["de-DE", "fr-FR"]), .korean)
    }

    func testSupportedPreferenceWinsOverUnknownPreference() {
        XCTAssertEqual(
            AppLanguage.resolve(preferredLocalizations: ["fr-FR", "en-US"]),
            .english
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLocalizations: ["de-DE", "ko-KR"]),
            .korean
        )
        XCTAssertEqual(
            AppLanguage.resolve(preferredLocalizations: ["de-DE", "ja-JP"]),
            .japanese
        )
    }
}
