import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOS

final class ScopedPresentationLocalizationTests: XCTestCase {
    private struct CatalogEntry {
        let korean: String
        let english: String
    }

    func testScopedCatalogInventoryHasExactTypedCoverageAndNaturalEnglish() throws {
        let entries = try allCatalogEntries()
        let descriptors = CommunityBuzzPresentationCatalog.reactionDescriptors.map { $0.token.key }
            + CommunityBuzzPresentationCatalog.rivalNewsDescriptors.map { $0.token.key }
            + NicknamePresentationCatalog.descriptors.map { $0.titleToken.key }
            + ProspectRankingPresentationCatalog.surnameDescriptors.map { $0.token.key }
            + ProspectRankingPresentationCatalog.givenNameDescriptors.map { $0.token.key }
            + ProspectRankingPresentationCatalog.schoolDescriptors.map { $0.token.key }
            + ProspectRankingPresentationCatalog.scoutTagDescriptors.map { $0.token.key }
            + DraftForecastPresentationCatalog.bandDescriptors.map { $0.token.key }
            + DraftTeamPresentationCatalog.descriptors.map { $0.token.key }

        XCTAssertEqual(Set(descriptors).count, descriptors.count)
        for key in descriptors {
            let entry = try XCTUnwrap(entries[key], key)
            XCTAssertFalse(entry.english.isEmpty, key)
            XCTAssertFalse(containsHangul(entry.english), key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key
            )
        }

        let korean = resolver(language: .korean, entries: entries)
        for descriptor in ProspectRankingPresentationCatalog.surnameDescriptors {
            XCTAssertEqual(korean.resolve(descriptor.token), descriptor.koreanValue, descriptor.token.key)
        }
        for descriptor in ProspectRankingPresentationCatalog.givenNameDescriptors {
            XCTAssertEqual(korean.resolve(descriptor.token), descriptor.koreanValue, descriptor.token.key)
        }
        for descriptor in ProspectRankingPresentationCatalog.schoolDescriptors {
            XCTAssertEqual(korean.resolve(descriptor.token), descriptor.rawSchoolName, descriptor.token.key)
        }
        for descriptor in ProspectRankingPresentationCatalog.scoutTagDescriptors {
            XCTAssertEqual(korean.resolve(descriptor.token), descriptor.koreanValue, descriptor.token.key)
        }
        for descriptor in DraftForecastPresentationCatalog.bandDescriptors {
            XCTAssertEqual(korean.resolve(descriptor.token), descriptor.koreanValue, descriptor.token.key)
        }
        for descriptor in DraftTeamPresentationCatalog.descriptors {
            XCTAssertEqual(korean.resolve(descriptor.token), descriptor.rawTeamName, descriptor.token.key)
        }
    }

    func testCommunityBuzzTypedLinesResolveExactKoreanAndFreshEnglish() throws {
        let entries = try allCatalogEntries()
        let korean = resolver(language: .korean, entries: entries)
        let english = resolver(language: .english, entries: entries)
        let nickname = Nickname(id: "zero", title: "제로", reason: "")

        let reactions = CommunityBuzz.reactionLines(
            careerID: "golden-c",
            gameNumber: 3,
            strikeouts: 2,
            walks: 0,
            runsAllowed: 1,
            newNickname: nickname
        )
        XCTAssertEqual(
            reactions.map { CommunityBuzzPresentation.localizedReaction($0, resolver: korean) },
            CommunityBuzz.reactions(
                careerID: "golden-c",
                gameNumber: 3,
                strikeouts: 2,
                walks: 0,
                runsAllowed: 1,
                newNickname: nickname.title
            )
        )
        let englishReactions = reactions.map {
            CommunityBuzzPresentation.localizedReaction($0, resolver: english)
        }
        XCTAssertTrue(englishReactions.joined(separator: " ").contains("Zero"))
        XCTAssertFalse(englishReactions.joined(separator: " ").contains("제로"))
        englishReactions.forEach { XCTAssertFalse(containsHangul($0), $0) }

        let news = CommunityBuzz.rivalNewsLines(careerID: "golden-c", chapterNumber: 4)
        XCTAssertEqual(
            news.map { CommunityBuzzPresentation.localizedNews($0, resolver: korean) },
            CommunityBuzz.rivalNews(careerID: "golden-c", chapterNumber: 4)
        )
        let englishNews = news.map {
            CommunityBuzzPresentation.localizedNews($0, resolver: english)
        }
        XCTAssertTrue(englishNews.joined(separator: " ").contains("Kwon"))
        XCTAssertTrue(englishNews.joined(separator: " ").contains("Kang"))
        XCTAssertTrue(englishNews.joined(separator: " ").contains("Northern Commerce High"))
        XCTAssertTrue(englishNews.joined(separator: " ").contains("Cheongam High"))
        englishNews.forEach { XCTAssertFalse(containsHangul($0), $0) }
        XCTAssertFalse(englishNews.joined(separator: " ").contains("권서준"))
        XCTAssertFalse(englishNews.joined(separator: " ").contains("청암고"))
    }

    func testProspectNameSchoolTagAndForecastBoundariesPreservePlayerVerbatim() throws {
        let entries = try allCatalogEntries()
        let korean = resolver(language: .korean, entries: entries)
        let english = resolver(language: .english, entries: entries)
        let performance = CareerPerformanceSnapshot(
            importantGamesCompleted: 4,
            pitches: 120,
            strikeouts: 24,
            walks: 2,
            runsAllowed: 2,
            expectedDamage: 0,
            actualDamage: 0
        )
        let board = ProspectRanking.presentationBoard(
            careerID: "c",
            playerName: "김솔",
            playerSchool: "서울고",
            playerSchoolID: .hanbitTraditional,
            playerRegion: .seoul,
            performance: performance
        )
        let rival = try XCTUnwrap(board.first(where: { !$0.isPlayer }))
        let englishRival = ProspectRankingPresentation.resolvedEntry(rival, resolver: english)
        XCTAssertFalse(containsHangul(englishRival.name))
        XCTAssertFalse(containsHangul(englishRival.school))
        XCTAssertFalse(containsHangul(englishRival.tag))
        XCTAssertFalse(containsHangul(englishRival.identityLine))
        XCTAssertTrue(englishRival.name.contains(" "), englishRival.name)

        let player = try XCTUnwrap(board.first(where: \.isPlayer))
        let englishPlayer = ProspectRankingPresentation.resolvedEntry(
            player,
            playerSchoolID: .hanbitTraditional,
            playerRegion: .seoul,
            rawPlayerSchool: "서울덕성고",
            resolver: english
        )
        XCTAssertEqual(englishPlayer.name, "김솔", "User-authored player names remain verbatim")
        XCTAssertEqual(englishPlayer.school, "Seoul Deokseong High")
        XCTAssertFalse(containsHangul(englishPlayer.school))
        XCTAssertFalse(containsHangul(englishPlayer.tag))
        XCTAssertTrue(englishPlayer.identityLine.contains("김솔"))
        XCTAssertFalse(containsHangul(englishPlayer.identityLine.replacingOccurrences(of: "김솔", with: "")))

        let koreanPlayer = ProspectRankingPresentation.resolvedEntry(
            player,
            playerSchoolID: .hanbitTraditional,
            playerRegion: .seoul,
            rawPlayerSchool: "서울덕성고",
            resolver: korean
        )
        XCTAssertEqual(koreanPlayer.name, "김솔")
        XCTAssertEqual(koreanPlayer.school, "서울덕성고")
        XCTAssertEqual(koreanPlayer.tag, "이 명단에서 유일하게 당신이 키우는 선수")

        let started = try HighSchoolCareerEngine().start(
            .init(seed: "20260730", presetID: "power_prospect")
        )
        let forecast = HighSchoolCareerEngine.draftForecast(state: started.snapshot)
        XCTAssertEqual(ProspectRankingPresentation.localizedForecastBand(forecast, resolver: korean), "미지명권 — 아직 명단 밖")
        XCTAssertEqual(ProspectRankingPresentation.localizedForecastTeam(forecast, resolver: korean), "대구 포지")
        XCTAssertEqual(ProspectRankingPresentation.localizedForecastBand(forecast, resolver: english), "Outside the Draft Picture — Not on the Board Yet")
        XCTAssertEqual(ProspectRankingPresentation.localizedForecastTeam(forecast, resolver: english), "Daegu Forge")
        XCTAssertFalse(containsHangul(ProspectRankingPresentation.localizedForecastBand(forecast, resolver: english)))
        XCTAssertFalse(containsHangul(ProspectRankingPresentation.localizedForecastTeam(forecast, resolver: english)))
        XCTAssertEqual(
            english.resolve(AppCopyKey.prospectRankingForecastDetail,
                            arguments: ProspectRankingPresentation.forecastDetailArguments(forecast, resolver: english)),
            "Evaluation 52 · Draft cutoff 66 · Daegu Forge is on the scouting radar"
        )
        XCTAssertEqual(
            korean.resolve(AppCopyKey.prospectRankingForecastDetail,
                           arguments: ProspectRankingPresentation.forecastDetailArguments(forecast, resolver: korean)),
            "평가 52점 · 당락선 66점 · 대구 포지가 주목"
        )
    }

    func testUnknownSystemForecastTeamUsesNeutralEnglishBoundary() {
        let forecast = HighSchoolCareerEngine.DraftForecastSnapshot(
            score: 52,
            threshold: 66,
            band: "미지명권 — 아직 명단 밖",
            interestedTeam: "대구 포지",
            presentation: .init(bandID: .outside, interestedTeamID: "future-team")
        )
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.english: [DraftForecastPresentationCatalog.descriptor(for: .outside).token.key: "Outside the Draft Picture — Not on the Board Yet"]],
            policy: .releaseSafe
        )
        XCTAssertEqual(ProspectRankingPresentation.localizedForecastTeam(forecast, resolver: resolver), GameCopyResolver.unavailableText)
        XCTAssertFalse(ProspectRankingPresentation.localizedForecastTeam(forecast, resolver: resolver).contains("대구"))
    }

    private func resolver(language: AppLanguage, entries: [String: CatalogEntry]) -> GameCopyResolver {
        let korean = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let english = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        return GameCopyResolver(
            language: language,
            catalog: [.korean: korean, .english: english],
            policy: .releaseSafe
        )
    }

    private func allCatalogEntries() throws -> [String: CatalogEntry] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var result: [String: CatalogEntry] = [:]
        for filename in ["GameContent.xcstrings", "Localizable.xcstrings"] {
            let url = root.appendingPathComponent("apps/ios/Sources/Localization/\(filename)")
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            let rootObject = try XCTUnwrap(object as? [String: Any])
            let strings = try XCTUnwrap(rootObject["strings"] as? [String: Any])
            for (key, rawValue) in strings {
                guard let value = rawValue as? [String: Any],
                      let localizations = value["localizations"] as? [String: Any],
                      let korean = Self.stringUnitValue(localizations["ko"]),
                      let english = Self.stringUnitValue(localizations["en"]) else { continue }
                result[key] = CatalogEntry(korean: korean, english: english)
            }
        }
        return result
    }

    private static func stringUnitValue(_ rawValue: Any?) -> String? {
        guard let localization = rawValue as? [String: Any],
              let unit = localization["stringUnit"] as? [String: Any] else { return nil }
        return unit["value"] as? String
    }

    private func containsHangul(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(Int(scalar.value))
                || (0x3131...0x318E).contains(Int(scalar.value))
                || (0x1100...0x11FF).contains(Int(scalar.value))
        }
    }
}
