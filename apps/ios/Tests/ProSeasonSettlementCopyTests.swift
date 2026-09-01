import XCTest
@testable import BaseballIOS

/// 시즌 결산 제목. 아크 문구는 완결 문장이라 시즌 번호를 넣으면 placeholder 불일치로
/// DEBUG에서 앱이 죽는다(2026-08-31 QA).
final class ProSeasonSettlementCopyTests: XCTestCase {
    private let resolver = GameCopyResolver(
        language: .korean,
        catalog: [
            .korean: [
                "pro.settlement.title": "%lld시즌 결산",
                "pro.settlement.arc.quiet": "조용한 한 시즌",
                "pro.settlement.arc.autumn-door-closed": "문턱에서 멈춘 가을",
            ],
        ],
        policy: .releaseSafe
    )

    func testDefaultTitleIncludesSeasonNumber() {
        XCTAssertEqual(
            ProSeasonSettlementCopy.title(arcTitleID: nil, season: 1, resolver: resolver),
            "1시즌 결산"
        )
        XCTAssertEqual(
            ProSeasonSettlementCopy.title(arcTitleID: "unknown.arc", season: 3, resolver: resolver),
            "3시즌 결산"
        )
    }

    func testArcTitleOmitsSeasonPlaceholder() {
        XCTAssertEqual(
            ProSeasonSettlementCopy.title(arcTitleID: "pro.arc.quiet", season: 1, resolver: resolver),
            "조용한 한 시즌"
        )
        XCTAssertEqual(
            ProSeasonSettlementCopy.title(arcTitleID: "pro.arc.autumn_door_closed", season: 1, resolver: resolver),
            "문턱에서 멈춘 가을"
        )
    }

    func testPassingSeasonIntoArcTemplateIsUnavailable() {
        let mismatched = resolver.resolve(.journeyArcQuiet, arguments: [.integer(1)])
        XCTAssertEqual(mismatched, GameCopyResolver.unavailableText)
    }
}
