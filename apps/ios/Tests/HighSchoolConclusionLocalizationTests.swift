import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOS

final class HighSchoolConclusionLocalizationTests: XCTestCase {
    private struct CatalogEntry {
        let korean: String
        let english: String
    }

    func testConclusionCatalogHasCompleteKoEnCoverageAndPlaceholderParity() throws {
        let localizable = try entries(named: "Localizable")
        let gameContent = try entries(named: "GameContent")

        for key in AppCopyKey.highSchoolConclusionKeys {
            let entry = try XCTUnwrap(localizable[key.rawValue], key.rawValue)
            assertNoHangul(entry.english, key.rawValue)
            XCTAssertFalse(entry.korean.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
        }

        for descriptor in DraftConclusionPresentationCatalog.fieldDescriptors {
            try assertComplete(gameContent, key: descriptor.token.key)
        }
        for descriptor in DraftConclusionPresentationCatalog.teamFieldDescriptors {
            let entry = try assertComplete(gameContent, key: descriptor.token.key)
            XCTAssertEqual(entry.korean, descriptor.rawValue, descriptor.token.key)
        }
        for descriptor in DraftConclusionPresentationCatalog.personalityDescriptors {
            let title = try assertComplete(gameContent, key: descriptor.titleToken.key)
            let scoutLine = try assertComplete(gameContent, key: descriptor.scoutLineToken.key)
            XCTAssertEqual(title.korean, descriptor.rawTitle, descriptor.titleToken.key)
            XCTAssertEqual(scoutLine.korean, descriptor.rawScoutLine, descriptor.scoutLineToken.key)
        }
        for descriptor in DraftConclusionPresentationCatalog.memoryDescriptors {
            let raw = HighSchoolPresentation.memory(descriptor.id)
            XCTAssertEqual(
                try assertComplete(gameContent, key: descriptor.titleToken.key).korean,
                raw.title,
                descriptor.titleToken.key
            )
            XCTAssertEqual(
                try assertComplete(gameContent, key: descriptor.detailToken.key).korean,
                raw.detail,
                descriptor.detailToken.key
            )
        }
        for descriptor in DraftConclusionPresentationCatalog.signatureLegacyDescriptors {
            let raw = CareerSignatureLegacy.definition(for: descriptor.id)
            XCTAssertEqual(
                try assertComplete(gameContent, key: descriptor.titleToken.key).korean,
                raw.title,
                descriptor.titleToken.key
            )
            XCTAssertEqual(
                try assertComplete(gameContent, key: descriptor.detailToken.key).korean,
                raw.detail,
                descriptor.detailToken.key
            )
            XCTAssertEqual(
                try assertComplete(gameContent, key: descriptor.evidenceToken.key).korean,
                "이 대표 유산의 고정 시작 효과입니다.",
                descriptor.evidenceToken.key
            )
        }
        for descriptor in DraftConclusionPresentationCatalog.chronicleProducerDescriptors {
            try assertComplete(gameContent, key: descriptor.token.key)
        }

        let allKeys = AppCopyKey.highSchoolConclusionKeys.map(\.rawValue)
            + DraftConclusionPresentationCatalog.semanticKeys
        XCTAssertEqual(Set(allKeys).count, allKeys.count)
    }

    func testKoreanConclusionBranchesPreserveRawDraftTeamMemorySignatureAndWindValues() throws {
        let resolver = try resolver(language: .korean)
        let team = HighSchoolCareerEngine.teams[0]
        let draft = DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: 74,
            projectedRange: "2~3라운드",
            team: team,
            round: 2,
            overallPick: 18,
            signingBonus: 210_000_000,
            firstSeasonGoal: "퓨처스 선발 10경기와 볼넷률 8% 이하",
            evaluationBreakdown: ["능력 26", "고교 공식 경기 +7", "팔 상태 -2"],
            summary: "지명 구단 · 서울 코메츠. 구위와 고교 경기 기록에서 높은 평가를 받았습니다."
        )

        XCTAssertEqual(HighSchoolConclusionPresentation.localizedDraftProjectedRange("1라운드", resolver: resolver), "1라운드")
        XCTAssertEqual(HighSchoolConclusionPresentation.localizedDraftProjectedRange("2~3라운드", resolver: resolver), "2~3라운드")
        XCTAssertEqual(HighSchoolConclusionPresentation.localizedDraftSummary(draft, resolver: resolver), draft.summary)
        XCTAssertEqual(HighSchoolConclusionPresentation.localizedFirstSeasonGoal(draft.firstSeasonGoal, resolver: resolver), draft.firstSeasonGoal)
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedEvaluationBreakdown(draft.evaluationBreakdown, resolver: resolver),
            draft.evaluationBreakdown
        )

        for field in DraftTeamConclusionFieldID.allCases {
            XCTAssertEqual(
                HighSchoolConclusionPresentation.localizedTeamField(team, field: field, resolver: resolver),
                rawTeamField(team, field: field),
                field.rawValue
            )
        }
        for descriptor in DraftConclusionPresentationCatalog.personalityDescriptors {
            let personality = PersonalityRules.personality(listen: 0, explain: 0, challenge: 5)!
            if descriptor.trait == personality.trait {
                XCTAssertEqual(HighSchoolConclusionPresentation.localizedPersonalityTitle(personality, resolver: resolver), personality.title)
                XCTAssertEqual(HighSchoolConclusionPresentation.localizedPersonalityScoutLine(personality, resolver: resolver), personality.scoutLine)
            }
        }
        for id in MemoryCardID.allCases {
            let raw = HighSchoolPresentation.memory(id)
            let copy = HighSchoolConclusionPresentation.localizedMemory(id, resolver: resolver)
            XCTAssertEqual(copy.title, raw.title, id.rawValue)
            XCTAssertEqual(copy.detail, raw.detail, id.rawValue)
        }
        for id in CareerSignatureLegacyID.allCases {
            let raw = CareerSignatureLegacy.definition(for: id)
            let copy = HighSchoolConclusionPresentation.localizedSignature(raw, resolver: resolver)
            XCTAssertEqual(copy.title, raw.title, id.rawValue)
            XCTAssertEqual(copy.detail, raw.detail, id.rawValue)
            XCTAssertEqual(copy.evidence, raw.evidence.summary, id.rawValue)
        }
        for wind in CareerWindPresentationCatalog.v1Winds + CareerWindPresentationCatalog.v2Winds {
            let copy = HighSchoolConclusionPresentation.localizedWind(wind, resolver: resolver)
            XCTAssertEqual(copy.title, wind.title, wind.id)
            XCTAssertEqual(copy.detail, wind.detail, wind.id)
        }
    }

    func testKnownChronicleProducersResolveThroughSemanticProjection() throws {
        let korean = try resolver(language: .korean)
        let english = try resolver(language: .english)
        let school = try XCTUnwrap(HighSchoolCareerEngine.schools(for: "서울").first)
        let personality = PersonalityRules.personality(listen: 0, explain: 0, challenge: 5)!
        let awakeningID = AwakeningID.allCases[0]
        let awakening = HighSchoolPresentation.awakening(awakeningID)
        let nickname = Nickname(id: "zero", title: "제로", reason: "3경기째 무실점 — 아직 한 점도 내주지 않았습니다.")
        let pledge = try XCTUnwrap(RunPledge.all.first)
        let grade = TalentGrade.allCases[0]
        let samples: [(ChronicleProducerID, String)] = [
            (.schoolAdmission, "\(school.name) 입학. 3년이 시작됩니다."),
            (.personalityCrystallized, "성격이 자리 잡았습니다 — '\(personality.title)'. \(personality.scoutLine)"),
            (.personalityChanged, "성격이 달라졌습니다 — '\(personality.title)'. 사람은 고정된 값이 아닙니다."),
            (.awakening, "‘\(awakening.title)’을 익혔습니다. \(awakening.detail)"),
            (.nickname, "'\(nickname.title)'이라는 별명을 얻었습니다. \(nickname.reason)"),
            (.importantGame, "첫 공식 등판 — 18구 · 4탈삼진 · 0볼넷 · 0실점"),
            (.gameGrowth, "무실점 호투 — 18구 · 4탈삼진 · 0볼넷 · 0실점 · 경기 기반 성장 · 구위 +2"),
            (.chapterGoal, "감독의 숙제 완수 — 이번 이야기 탈삼진 5개."),
            (.draft, "드래프트 2라운드 \(HighSchoolCareerEngine.teams[0].name) 지명. 3년이 응답받았습니다."),
            (.pledge, "고교 3년 목표 — \(pledge.title)."),
            (.bloom, "만개 — 막혀 있던 구위 재능이 \(grade.label)까지 열렸습니다."),
            (.proStart, "프로 유니폼을 입었습니다."),
        ]

        for (producer, rawText) in samples {
            let projected = HighSchoolConclusionPresentation.localizedChronicleText(rawText, resolver: english)
            XCTAssertNotEqual(projected, GameCopyResolver.unavailableText, producer.rawValue)
            assertNoHangul(projected, producer.rawValue)
            XCTAssertEqual(
                HighSchoolConclusionPresentation.localizedChronicleText(rawText, resolver: korean),
                rawText,
                producer.rawValue
            )
        }

        for rawStage in ["1학년 봄", "2학년 여름", "3학년 겨울"] {
            XCTAssertEqual(
                HighSchoolConclusionPresentation.localizedChronicleStage(rawStage, resolver: korean),
                rawStage
            )
            assertNoHangul(
                HighSchoolConclusionPresentation.localizedChronicleStage(rawStage, resolver: english),
                rawStage
            )
        }
    }

    func testEnglishConclusionHasNeutralUnknownBoundaryAndKeepsUserNamesVerbatim() throws {
        let english = try resolver(language: .english)
        let korean = try resolver(language: .korean)

        let unknownText = "미래 버전에서 추가된 연대기 문장"
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedChronicleText(unknownText, resolver: english),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedChronicleText(unknownText, resolver: korean),
            unknownText
        )
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedChronicleStage("9학년 봄", resolver: english),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedChronicleLine("9학년 봄 — \(unknownText)", resolver: english),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedDraftProjectedRange("미래-구간", resolver: english),
            GameCopyResolver.unavailableText
        )

        let unknownTeam = DraftTeamSnapshot(
            id: "future-team", name: "미래 구단", need: .command, demand: 50,
            developmentPlan: "미래 육성 계획", positionCompetitor: "미래 선수", proCoach: "미래 코치",
            competitorProfile: "미래 프로필", competitorRecord: "미래 기록",
            coachProfile: "미래 지도", coachRecord: "미래 이력"
        )
        XCTAssertEqual(
            HighSchoolConclusionPresentation.localizedTeamName(unknownTeam, resolver: english),
            GameCopyResolver.unavailableText
        )

        let playerName = "김솔"
        let displayed = HighSchoolConclusionPresentation.localizedDisplayName(
            baseName: playerName,
            nicknames: [Nickname(id: "zero", title: "제로", reason: "")],
            resolver: english
        )
        XCTAssertEqual(displayed, "'Zero' 김솔")
        XCTAssertTrue(displayed.contains(playerName), "User-authored names must remain verbatim")
    }

    func testLegacyRelationshipSummaryFormatsEveryTypedArgument() throws {
        let english = try resolver(language: .english)
        let ability = english.resolve(
            .highSchoolSummaryRelationshipAbility,
            arguments: [.userText("Command"), .integer(2)]
        )
        XCTAssertEqual(ability, " · Command +2")

        let summary = english.resolve(
            .highSchoolSummaryRelationship,
            arguments: [
                .userText("Hear the catcher out."),
                .integer(3),
                .integer(-1),
                .integer(2),
                .userText(ability),
            ]
        )
        XCTAssertEqual(
            summary,
            "Hear the catcher out. Outcome: trust +3 · fatigue -1 · fan interest +2 · Command +2"
        )
        assertNoHangul(summary, LegacyUICopyKey.highSchoolSummaryRelationship.rawValue)
    }

    func testEnglishSeasonRA9IncludesTheMetricLabelExactlyOnce() throws {
        let english = try resolver(language: .english)
        let lines = [
            ProGameLine(
                season: 1,
                week: 1,
                outingNumber: 1,
                started: true,
                outs: 27,
                strikeouts: 8,
                walks: 2,
                runsAllowed: 3,
                pitches: 103,
                teamRuns: 4,
                opponentRuns: 3,
                decision: .win,
                played: true,
                hits: 6
            ),
        ]

        let copy = HighSchoolConclusionPresentation.localizedSeasonRA9(
            lines: lines,
            resolver: english
        )

        XCTAssertEqual(copy, "3.00 RA9")
        XCTAssertEqual(copy.components(separatedBy: "RA9").count - 1, 1)
    }

    private func resolver(language: AppLanguage) throws -> GameCopyResolver {
        let all = try allEntries()
        let korean = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0.value.korean) })
        let english = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0.value.english) })
        return GameCopyResolver(
            language: language,
            catalog: [.korean: korean, .english: english],
            policy: .releaseSafe
        )
    }

    private func assertComplete(
        _ entries: [String: CatalogEntry],
        key: String
    ) throws -> CatalogEntry {
        let entry = try XCTUnwrap(entries[key], key)
        XCTAssertFalse(entry.korean.isEmpty, key)
        XCTAssertFalse(entry.english.isEmpty, key)
        assertNoHangul(entry.english, key)
        XCTAssertEqual(
            GameCopyResolver.placeholderKinds(in: entry.korean),
            GameCopyResolver.placeholderKinds(in: entry.english),
            key
        )
        return entry
    }

    private func allEntries() throws -> [String: CatalogEntry] {
        var result = try entries(named: "GameContent")
        for (key, value) in try entries(named: "Localizable") {
            result[key] = value
        }
        return result
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

    private func rawTeamField(_ team: DraftTeamSnapshot, field: DraftTeamConclusionFieldID) -> String? {
        switch field {
        case .name: team.name
        case .developmentPlan: team.developmentPlan
        case .positionCompetitor: team.positionCompetitor
        case .proCoach: team.proCoach
        case .competitorProfile: team.competitorProfile
        case .competitorRecord: team.competitorRecord
        case .coachProfile: team.coachProfile
        case .coachRecord: team.coachRecord
        }
    }

    private func assertNoHangul(_ value: String, _ label: String) {
        XCTAssertFalse(value.unicodeScalars.contains { scalar in
            (0xAC00...0xD7A3).contains(scalar.value)
                || (0x1100...0x11FF).contains(scalar.value)
                || (0x3130...0x318F).contains(scalar.value)
        }, label)
    }
}
