import XCTest
@testable import BaseballIOS

final class EnglishFormattingTests: XCTestCase {
    func testVelocityUsesDisplayOnlyMphConversion() {
        XCTAssertEqual(GameFormatters.mph(fromTenthsKPH: 1_490), "92.6 mph")
        XCTAssertEqual(GameFormatters.velocity(tenthsKPH: 1_490, language: .korean), "149.0 km/h")
    }

    func testEnglishInningsUseBaseballFractions() {
        XCTAssertEqual(GameFormatters.innings(outs: 18, language: .english), "6 IP")
        XCTAssertEqual(GameFormatters.innings(outs: 19, language: .english), "6⅓ IP")
        XCTAssertEqual(GameFormatters.innings(outs: 20, language: .english), "6⅔ IP")
    }

    func testInningLabelsUseKoreanAndEnglishOrdinalForms() {
        XCTAssertEqual(GameFormatters.inningLabel(inning: 3, language: .korean), "3회")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 1, language: .english), "1st inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 2, language: .english), "2nd inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 3, language: .english), "3rd inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 4, language: .english), "4th inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 11, language: .english), "11th inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 12, language: .english), "12th inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 13, language: .english), "13th inning")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 21, language: .english), "21st inning")
    }

    func testEnglishRa9AvgAndWhip() {
        XCTAssertEqual(GameFormatters.ra9(runsAllowed: 17, outs: 162, language: .english), "2.83 RA9")
        XCTAssertEqual(GameFormatters.avg(hits: 28, atBats: 98, language: .english), ".286 AVG")
        XCTAssertEqual(GameFormatters.whip(hits: 7, walks: 2, outs: 27, language: .english), "1.00 WHIP")
    }

    func testUnknownRatesAreExplicitlyUnavailable() {
        XCTAssertEqual(GameFormatters.ra9(runsAllowed: 0, outs: 0, language: .english), "— RA9")
        XCTAssertEqual(GameFormatters.avg(hits: 0, atBats: 0, language: .english), "— AVG")
        XCTAssertEqual(GameFormatters.whip(hits: 0, walks: 0, outs: 0, language: .english), "— WHIP")
    }

    func testKrwNeverConvertsTheStoredAmount() {
        XCTAssertEqual(GameFormatters.krw(120_000_000, language: .english), "KRW 120,000,000")
        XCTAssertEqual(GameFormatters.krw(120_000_000, language: .korean), "120,000,000원")
    }
}
