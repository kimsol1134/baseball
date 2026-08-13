import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOS

final class PitchLocalizationTests: XCTestCase {
    private struct CatalogEntry {
        let korean: String
        let english: String
    }

    func testPitchCatalogHasCompleteKoEnCoverageAndPlaceholderParity() throws {
        let entries = try localizableEntries()

        XCTAssertEqual(Set(AppCopyKey.pitchKeys.map(\.rawValue)).count, AppCopyKey.pitchKeys.count)
        for key in AppCopyKey.pitchKeys {
            let entry = try XCTUnwrap(entries[key.rawValue], key.rawValue)
            XCTAssertFalse(entry.korean.isEmpty, key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            assertNoHangul(entry.english, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
        }
    }

    func testEnglishZonesRespectBatSideWithoutKoreanFallback() throws {
        let english = try resolver(language: .english)
        let korean = try resolver(language: .korean)
        let highLeft = PitchZone(row: 0, column: 0)

        XCTAssertEqual(PitchPresentation.zone(highLeft, batSide: .right, resolver: english), "Up and in")
        XCTAssertEqual(PitchPresentation.zone(highLeft, batSide: .left, resolver: english), "Up and away")
        XCTAssertEqual(PitchPresentation.zone(highLeft, batSide: .right, resolver: korean), "높은 몸쪽")
        XCTAssertEqual(PitchPresentation.zone(highLeft, batSide: .left, resolver: korean), "높은 바깥쪽")

        for side in BatSide.allCases {
            for row in 0..<3 {
                for column in 0..<3 {
                    assertNoHangul(
                        PitchPresentation.zone(PitchZone(row: row, column: column), batSide: side, resolver: english),
                        "\(side.rawValue)-\(row)-\(column)"
                    )
                }
            }
        }
    }

    func testEnglishPitchOutcomesSequencesTraitsAndFieldersAreSemantic() throws {
        let english = try resolver(language: .english)

        for outcome in PitchOutcome.allCases {
            let value = PitchPresentation.shortFeedback(
                outcome,
                legacy: "한국어 원문은 영어 화면에 나오면 안 됩니다",
                resolver: english
            )
            assertNoHangul(value, outcome.rawValue)
            XCTAssertFalse(value.isEmpty, outcome.rawValue)
        }

        for tag in PitchSequenceTag.allCases {
            assertNoHangul(PitchPresentation.sequenceTitle(tag, resolver: english), tag.rawValue)
            assertNoHangul(PitchPresentation.sequenceDetail(tag, resolver: english), tag.rawValue)
        }

        for trait in PersonalityTrait.allCases {
            assertNoHangul(PitchPresentation.trait(trait, resolver: english), trait.rawValue)
        }

        for fielder in FielderPosition.allCases {
            assertNoHangul(PitchPresentation.fielder(fielder, resolver: english), fielder.rawValue)
        }
    }

    func testEnglishDeliveryFeedbackNeverUsesLegacyKorean() throws {
        let english = try resolver(language: .english)
        let korean = try resolver(language: .korean)
        let samples = [
            PitchDelivery(releaseAccuracy: 1_000, aimAccuracy: 1_000),
            PitchDelivery(releaseAccuracy: 900, aimAccuracy: 850),
            PitchDelivery(releaseAccuracy: 700, aimAccuracy: 680),
            PitchDelivery(releaseAccuracy: 520, aimAccuracy: 430),
            PitchDelivery(releaseAccuracy: 250, aimAccuracy: 800),
            PitchDelivery(releaseAccuracy: 800, aimAccuracy: 250),
        ]

        for delivery in samples {
            if let verdict = DeliveryControl.localizedVerdict(delivery, resolver: english)?.text {
                assertNoHangul(verdict, "verdict")
            }
            if let hint = DeliveryControl.localizedCoachingHint(delivery, resolver: english) {
                assertNoHangul(hint, "hint")
            }
        }

        let missedRelease = PitchDelivery(releaseAccuracy: 250, aimAccuracy: 800)
        XCTAssertEqual(
            DeliveryControl.localizedCoachingHint(missedRelease, resolver: korean),
            DeliveryControl.coachingHint(missedRelease)
        )
        XCTAssertEqual(
            DeliveryControl.localizedVerdict(missedRelease, resolver: korean)?.text,
            DeliveryControl.verdict(missedRelease)?.text
        )
    }

    func testEnglishPitchUnitsUseMphAndFeetWhileKoreanUnitsStayStable() {
        XCTAssertEqual(GameFormatters.velocity(tenthsKPH: 1_609, language: .english), "100.0 mph")
        XCTAssertEqual(GameFormatters.velocity(tenthsKPH: 1_609, language: .korean), "160.9 km/h")
        XCTAssertEqual(GameFormatters.distance(tenthsMeters: 1_000, language: .english), "328 ft")
        XCTAssertEqual(GameFormatters.distance(tenthsMeters: 1_000, language: .korean), "100m")
    }

    func testEnglishCatcherReasonsAndBatterNamesRejectRawKoreanFallback() throws {
        let english = try resolver(language: .english)
        let korean = try resolver(language: .korean)
        let call = PitchCall(
            pitchType: .slider,
            zone: PitchZone(row: 2, column: 2),
            zoneIntent: .chase,
            intensity: .normal
        )
        let reasonCodes = [
            "rival.pattern_detected", "sequence.avoid_repeat", "scouting.pitch_weakness",
            "count.avoid_walk", "count.pitcher_behind", "count.pitcher_ahead",
            "count.first_pitch", "runners.double_play_setup",
            "runners.suppress_sacrifice_fly", "future.reason",
        ]

        for reasonCode in reasonCodes {
            let recommendation = CatcherRecommendationSnapshot(
                call: call,
                confidence: 72,
                reasonCodes: [reasonCode],
                shortReason: "한국어 포수 설명"
            )
            let englishReason = PitchPresentation.catcherReason(recommendation, resolver: english)
            assertNoHangul(englishReason, reasonCode)
            XCTAssertNotEqual(englishReason, recommendation.shortReason, reasonCode)
            XCTAssertEqual(
                PitchPresentation.catcherReason(recommendation, resolver: korean),
                recommendation.shortReason,
                reasonCode
            )
        }

        let frozen = BatterSnapshot(id: "shipped", name: "구본휘", contact: 50, discipline: 50, power: 50)
        let unknown = BatterSnapshot(id: "future", name: "미래 한국어 타자", contact: 50, discipline: 50, power: 50)
        XCTAssertEqual(PitchPresentation.batterName(frozen, resolver: english), "Gu Bon-hwi")
        XCTAssertEqual(PitchPresentation.batterName(unknown, resolver: english), "Opposing Hitter")
        XCTAssertEqual(PitchPresentation.batterName(unknown, resolver: korean), unknown.name)
        assertNoHangul(PitchPresentation.batterName(unknown, resolver: english), "unknown batter")
    }

    private func resolver(language: AppLanguage) throws -> GameCopyResolver {
        let all = try allEntries()
        return GameCopyResolver(
            language: language,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
    }

    private func allEntries() throws -> [String: CatalogEntry] {
        var result = try entries(named: "GameContent")
        for (key, value) in try localizableEntries() { result[key] = value }
        return result
    }

    private func localizableEntries() throws -> [String: CatalogEntry] {
        try entries(named: "Localizable")
    }

    private func entries(named name: String) throws -> [String: CatalogEntry] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("apps/ios/Sources/Localization/\(name).xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try XCTUnwrap(object as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        var result: [String: CatalogEntry] = [:]
        for (key, rawValue) in strings {
            guard let value = rawValue as? [String: Any],
                  let localizations = value["localizations"] as? [String: Any],
                  let korean = stringUnitValue(localizations["ko"]),
                  let english = stringUnitValue(localizations["en"]) else { continue }
            result[key] = CatalogEntry(korean: korean, english: english)
        }
        return result
    }

    private func stringUnitValue(_ rawValue: Any?) -> String? {
        guard let language = rawValue as? [String: Any],
              let unit = language["stringUnit"] as? [String: Any] else { return nil }
        return unit["value"] as? String
    }

    private func assertNoHangul(_ value: String, _ label: String) {
        XCTAssertFalse(value.unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(scalar.value)
                || (0x1100...0x11FF).contains(scalar.value)
                || (0x3130...0x318F).contains(scalar.value)
        }, "\(label): \(value)")
    }
}
