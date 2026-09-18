import XCTest
@testable import BaseballIOSDomain

/// 7-E. 내보내기는 **원본을 그대로** 담고 아무것도 해석하지 않는다.
final class SaveExportBundleTests: XCTestCase {
    func testCarriesTheRawSaveBytesUnchanged() throws {
        let hs = Data("{\"a\":1}".utf8)
        let pro = Data("{\"b\":2}".utf8)
        let bundle = SaveExportBundle.make(highSchool: hs, pro: pro, appVersion: "1.3.0")
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(bundle.highSchool)), hs)
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(bundle.pro)), pro)
        XCTAssertFalse(bundle.isEmpty)
    }

    func testAnEmptyBundleKnowsItHasNothingToOffer() {
        XCTAssertTrue(SaveExportBundle.make(highSchool: nil, pro: nil, appVersion: "1.3.0").isEmpty)
        XCTAssertFalse(
            SaveExportBundle.make(highSchool: Data("x".utf8), pro: nil, appVersion: "1.3.0").isEmpty
        )
    }

    /// 같은 내용이면 같은 바이트다 — 사용자가 두 파일을 비교할 수 있어야 한다.
    func testEncodingIsStable() throws {
        let bundle = SaveExportBundle(
            exportedAt: "2026-09-11T00:00:00Z", appVersion: "1.3.0",
            highSchool: "aGk=", pro: nil
        )
        XCTAssertEqual(bundle.encoded(), bundle.encoded())
        let decoded = try JSONDecoder().decode(
            SaveExportBundle.self, from: try XCTUnwrap(bundle.encoded())
        )
        XCTAssertEqual(decoded, bundle)
    }

    func testFileNameIsSortableAndRecognisable() {
        let name = SaveExportBundle.fileName(date: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(name.hasPrefix("baseball-save-"))
        XCTAssertTrue(name.hasSuffix(".json"))
    }
}
