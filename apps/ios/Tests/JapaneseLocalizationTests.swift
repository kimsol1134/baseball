import Foundation
import XCTest
@testable import BaseballIOS

final class JapaneseLocalizationTests: XCTestCase {
    private struct Entry {
        let key: String
        let korean: String
        let english: String
        let japanese: String
    }

    func testEveryStringCatalogEntryHasReleaseReadyJapaneseCopy() throws {
        let entries = try catalogEntries()
        XCTAssertGreaterThan(entries.count, 3_000)

        let hangul = try NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]")
        let forbidden = try NSRegularExpression(
            pattern: "(?:NPB|KBO|日本野球機構|甲子園|読売|阪神|ヤクルト|DeNA|オリックス|ソフトバンク|楽天|西武|ロッテ|日本ハム|中日|広島東洋|ジャイアンツ|タイガース|スワローズ|ベイスターズ|カープ|ドラゴンズ|ファイターズ|イーグルス|ライオンズ|マリーンズ|バファローズ|ホークス|死亡|死ぬ|事故死|死後|あの世|異世界転生)",
            options: [.caseInsensitive]
        )

        for entry in entries {
            XCTAssertFalse(entry.japanese.isEmpty, entry.key)
            XCTAssertNil(match(hangul, in: entry.japanese), entry.key)
            XCTAssertNil(match(forbidden, in: entry.japanese), entry.key)
            XCTAssertFalse(entry.japanese.contains("ZXQ"), entry.key)
            XCTAssertFalse(entry.japanese.unicodeScalars.contains { (0xE000...0xF8FF).contains($0.value) }, entry.key)
            XCTAssertFalse(entry.japanese.contains("％"), entry.key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.japanese),
                entry.key
            )
            if entry.english.count > 8,
               entry.english.range(of: "[A-Za-z]{4}", options: .regularExpression) != nil {
                XCTAssertNotEqual(entry.japanese, entry.english, entry.key)
            }
        }
    }

    func testJapaneseResolverUsesJapaneseCatalogWithoutKoreanFallback() throws {
        let catalog = Dictionary(uniqueKeysWithValues: try catalogEntries().map { ($0.key, $0.japanese) })
        let resolver = GameCopyResolver(
            language: .japanese,
            catalog: [.japanese: catalog],
            policy: .releaseSafe
        )

        XCTAssertEqual(resolver.resolve(.actionNext), "次へ")
        XCTAssertEqual(resolver.resolve(.notificationReturnTitle), "マウンドに戻る")
        XCTAssertEqual(
            resolver.resolve(.accessibilityStatLine, arguments: [
                .integer(12), .userText("6⅔回"), .userText("7K"), .userText("2.84"),
            ]),
            "週 12、6⅔回、7K、2.84"
        )
    }

    func testJapaneseBaseballFormattersUseJapaneseUnits() {
        XCTAssertEqual(GameFormatters.velocity(tenthsKPH: 1_450, language: .japanese), "145.0 km/h")
        XCTAssertEqual(GameFormatters.distance(tenthsMeters: 1_200, language: .japanese), "120m")
        XCTAssertEqual(GameFormatters.innings(outs: 20, language: .japanese), "6⅔回")
        XCTAssertEqual(GameFormatters.inningLabel(inning: 9, language: .japanese), "9回")
        XCTAssertEqual(GameFormatters.krw(120_000_000, language: .japanese), "120,000,000ウォン")
    }

    func testJapaneseInfoPlistAndLaunchScreenResourcesExist() throws {
        let root = repositoryRoot()
        let info = root.appendingPathComponent("apps/ios/Sources/Localization/ja.lproj/InfoPlist.strings")
        let launch = root.appendingPathComponent("apps/ios/Sources/ja.lproj/LaunchScreen.storyboard")
        XCTAssertTrue(FileManager.default.fileExists(atPath: info.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: launch.path))
        XCTAssertTrue(try String(contentsOf: info, encoding: .utf8).contains("野球がダメならまた転生"))
        XCTAssertTrue(try String(contentsOf: launch, encoding: .utf8).contains("野球がダメなら"))
    }

    private func catalogEntries() throws -> [Entry] {
        let root = repositoryRoot()
        let paths = [
            "apps/ios/Sources/Localization/Localizable.xcstrings",
            "apps/ios/Sources/Localization/GameContent.xcstrings",
        ]
        var entries: [Entry] = []
        for path in paths {
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(path)))
            let catalog = try XCTUnwrap(object as? [String: Any])
            let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
            for (key, rawEntry) in strings {
                let entry = try XCTUnwrap(rawEntry as? [String: Any], key)
                let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
                entries.append(Entry(
                    key: key,
                    korean: try localizedValue("ko", from: localizations, key: key),
                    english: try localizedValue("en", from: localizations, key: key),
                    japanese: try localizedValue("ja", from: localizations, key: key)
                ))
            }
        }
        return entries
    }

    private func localizedValue(
        _ language: String,
        from localizations: [String: Any],
        key: String
    ) throws -> String {
        let localization = try XCTUnwrap(localizations[language] as? [String: Any], "\(key): \(language)")
        let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], "\(key): \(language)")
        XCTAssertEqual(unit["state"] as? String, "translated", "\(key): \(language)")
        return try XCTUnwrap(unit["value"] as? String, "\(key): \(language)")
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func match(_ regex: NSRegularExpression, in value: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value))
    }
}
