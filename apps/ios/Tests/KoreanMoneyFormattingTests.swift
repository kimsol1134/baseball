import XCTest
@testable import BaseballIOS

/// 한국어 원화 표기의 단일 정답. `GameFormatters.krw`와 `KoreanCopy.money`가 어긋나면
/// 계약 화면과 드래프트 호명이 다른 금액을 보여 준다.
final class KoreanMoneyFormattingTests: XCTestCase {
    func testKoreanWonUsesEokManNotation() {
        let cases: [(Int, String)] = [
            (0, "0원"),
            (8_000, "8,000원"),
            (60_000_000, "6,000만 원"),
            (90_000_000, "9,000만 원"),
            (120_000_000, "1억 2,000만 원"),
            (200_000_000, "2억 원"),
            (210_000_000, "2억 1,000만 원"),
        ]
        for (amount, expected) in cases {
            XCTAssertEqual(KoreanCopy.money(won: amount), expected, "KoreanCopy \(amount)")
            XCTAssertEqual(GameFormatters.krw(amount, language: .korean), expected, "krw \(amount)")
        }
    }

    func testEnglishAndJapaneseKeepStoredAmountWithoutConversion() {
        XCTAssertEqual(GameFormatters.krw(120_000_000, language: .english), "KRW 120,000,000")
        XCTAssertEqual(GameFormatters.krw(120_000_000, language: .japanese), "120,000,000ウォン")
    }
}
