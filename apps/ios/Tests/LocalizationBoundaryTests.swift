import XCTest
import SimulationCore
@testable import BaseballIOS

final class LocalizationBoundaryTests: XCTestCase {
    func testCoreTokenResolvesThroughSemanticKeyAndTypedValues() {
        let token = SimulationCore.CopyToken(
            key: "content.relationship.evt-coach-role.quote.high",
            arguments: [.userText("Player")]
        )
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .english: [token.key: "%@, close out the late innings."],
                .korean: [token.key: "민서준, 경기 후반을 맡아 줘."],
            ]
        )

        XCTAssertEqual(resolver.resolve(token), "Player, close out the late innings.")
        XCTAssertFalse(resolver.resolve(token).contains("민서준"))
    }

    func testCoreTokenBridgeRejectsSourceSentencesAndDoesNotUseKoreanFallback() {
        let token = SimulationCore.CopyToken(key: "선발은 아직 이르다")
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: [token.key: "선발은 아직 이르다"],
            ],
            policy: .releaseSafe
        )

        XCTAssertEqual(resolver.resolve(token), GameCopyResolver.unavailableText)
    }

    func testCoreTokenDynamicCatalogKeysUseGameContentTable() {
        let token = SimulationCore.CopyToken.highSchoolEventTitle(
            eventID: "evt-catcher-sign"
        )
        let key = try! XCTUnwrap(GameCopyKey(coreToken: token))
        XCTAssertEqual(key.rawValue, token.key)
        XCTAssertEqual(key.table, .gameContent)
        XCTAssertTrue(GameCopyKey.isSemanticID(key.rawValue))
    }

    func testBoundedCardsHaveExplicitSemanticSourceBoundaries() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/HighSchoolRelationshipViews.swift")
        let router = try IOSSourceScan.read("apps/ios/Sources/HighSchoolCareerView.swift")

        let importantStart = try XCTUnwrap(source.range(of: "struct ImportantGameCard"))
        let importantEnd = try XCTUnwrap(
            source.range(of: "/// 각성 스킬트리.", range: importantStart.upperBound..<source.endIndex)
        )
        let importantBlock = String(source[importantStart.lowerBound..<importantEnd.lowerBound])
        for forbidden in [
            "scenario.title", "scenario.narrative", "state.rival.name",
            "state.rival.archetype", "state.rival.signatureRecord", "summaryLine",
            "숙적 — 마지막 승부", "고교 3년 상대 전적", "마운드에 오르기",
            "ImportantGamePresentationCatalog", "CopyToken.importantGame", "content.important-game",
        ] {
            XCTAssertFalse(importantBlock.contains(forbidden), forbidden)
        }
        XCTAssertFalse(router.contains("ImportantGameCard(state: state, rivalLine:"))
        XCTAssertTrue(importantBlock.contains("HighSchoolPresentation.localizedImportantGameScenarioTitle"))
        XCTAssertTrue(importantBlock.contains("localizedImportantGameScenarioTitle"))
        XCTAssertTrue(importantBlock.contains("localizedImportantGameScenarioNarrative"))
        XCTAssertTrue(importantBlock.contains("localizedImportantGameRivalAccessibility"))
        XCTAssertTrue(importantBlock.contains("Text(verbatim:"))

        let presentationSource = try IOSSourceScan.read("apps/ios/Sources/HighSchoolPresentation.swift")
        for key in [
            "AppCopyKey.importantGameOpponentTitle",
            "AppCopyKey.importantGameFinalShowdownTitle",
            "AppCopyKey.importantGameFinalShowdownBody",
            "AppCopyKey.importantGameSituationZero",
            "AppCopyKey.importantGameSituationOne",
            "AppCopyKey.importantGameSituationMany",
            "AppCopyKey.importantGameCareerMatchup",
            "AppCopyKey.importantGameStartAction",
            "AppCopyKey.importantGameScenarioAccessibility",
            "AppCopyKey.importantGameRivalAccessibility",
            "AppCopyKey.importantGameRivalAccessibilitySignature",
        ] {
            XCTAssertTrue(presentationSource.contains(key), key)
        }
        XCTAssertFalse(presentationSource.contains("CopyToken.importantGame"))

        let reminderSource = try IOSSourceScan.read("apps/ios/Sources/HighSchoolTrainingResultViews.swift")
        let reminderStart = try XCTUnwrap(reminderSource.range(of: "struct ReminderNudgeCard"))
        let reminderEnd = reminderSource.endIndex
        let reminderBlock = String(reminderSource[reminderStart.lowerBound..<reminderEnd])
        for forbidden in ["내일도 이어 던지기", "알림 켜기", "괜찮습니다", "매일 저녁 7시 30분"] {
            XCTAssertFalse(reminderBlock.contains(forbidden), forbidden)
        }
        XCTAssertTrue(reminderBlock.contains("AppCopyKey.reminderNudgeTitle"))
        XCTAssertTrue(reminderBlock.contains("AppCopyKey.reminderNudgeAccessibility"))
        XCTAssertTrue(reminderBlock.contains("GameAnalytics.logOnce(.reminderOfferShown, [\"source\": \"after_first_game\"])") )

        let challengeSource = try IOSSourceScan.read("apps/ios/Sources/HighSchoolChallengeViews.swift")
        let challengeStart = try XCTUnwrap(challengeSource.range(of: "struct ChallengeEndCard"))
        let challengeBlock = String(challengeSource[challengeStart.lowerBound...])
        for forbidden in [
            "기록 없는 도전 결과", "스카우트 평가", "탈삼진", "볼넷", "실점",
            "도전을 닫는다", "이 도전은 선수 기록이나 다음 회차 보상",
        ] {
            XCTAssertFalse(challengeBlock.contains(forbidden), forbidden)
        }
        XCTAssertTrue(challengeBlock.contains("localizedChallengeOutcome"))
        XCTAssertTrue(challengeBlock.contains("AppCopyKey.challengeEndAccessibility"))
        XCTAssertTrue(challengeBlock.contains("AppCopyKey.challengeEndCloseHint"))
        XCTAssertTrue(challengeBlock.contains("Text(verbatim:"))
    }

    func testAwakeningSkillTreeSurfaceUsesTypedResolvedCopyBoundary() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/HighSchoolAwakeningViews.swift")
        let start = try XCTUnwrap(source.range(of: "struct AwakeningCard"))
        let block = String(source[start.lowerBound...])

        for forbidden in [
            "HighSchoolPresentation.awakening(",
            "AwakeningTree.branch(",
            "아직 찍은 스킬이 없습니다.",
            "체크는 현재 보유",
            "몸이 하나를 기억합니다",
            "시즌의 호투가 몸을 완전히 깨웠습니다",
            "전조가 부족합니다",
            "이걸로 각성한다",
            "다시 고른다",
            "한 번 고르면 고교 3년 동안 바꿀 수 없습니다.",
            "건너뛰기",
            "스킬트리 ·",
            "내 스킬트리",
            "완료",
        ] {
            XCTAssertFalse(block.contains(forbidden), forbidden)
        }
        let rawContentFieldPattern = try NSRegularExpression(pattern: #"\b(?:branch|copy|node)\.(?:title|detail)\b"#)
        let blockRange = NSRange(block.startIndex..<block.endIndex, in: block)
        XCTAssertNil(
            rawContentFieldPattern.firstMatch(in: block, range: blockRange),
            "raw content title/detail field access"
        )

        XCTAssertTrue(block.contains("@Environment(\\.gameCopyResolver)"))
        XCTAssertTrue(block.contains("HighSchoolPresentation.localizedAwakening"))
        XCTAssertTrue(block.contains("AppCopyKey.awakening"))
        XCTAssertEqual(
            block.components(separatedBy: "Text(").count,
            block.components(separatedBy: "Text(verbatim:").count
        )
        for required in [
            "Text(verbatim:",
            "hs.skillTree.progress",
            "hs.awakening.counter",
            "hs.awakening.confirm",
            "hs.awakening.",
            "hs.skillTree.open",
        ] {
            XCTAssertTrue(block.contains(required), required)
        }
    }

    func testNextThreeHighSchoolCardsRejectOnlyBoundedRawDisplayPaths() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/HighSchoolChapterReviewViews.swift")

        func block(from startMarker: String, to endMarker: String) throws -> String {
            let start = try XCTUnwrap(source.range(of: startMarker), startMarker)
            let end = try XCTUnwrap(source.range(of: endMarker, range: start.upperBound..<source.endIndex), endMarker)
            return String(source[start.lowerBound..<end.lowerBound])
        }

        // The assertions operate on code with comments removed, so prose/comments cannot satisfy
        // or evade the source boundary contract. The ranges stop at the next scoped card and do
        // not inspect later, intentionally out-of-scope views.
        func withoutComments(_ value: String) -> String {
            value.replacingOccurrences(
                of: #"/\*[\s\S]*?\*/|//[^\n]*"#,
                with: "",
                options: .regularExpression
            )
        }

        let review = withoutComments(try block(
            from: "struct ChapterReviewCard",
            to: "/// 대회 대진"
        ))
        let tournament = withoutComments(try block(
            from: "struct TournamentCard",
            to: "/// 이번 챕터의 숙제"
        ))
        let goal = withoutComments(try block(
            from: "struct ChapterGoalCard",
            to: "/// 어딘가의 게시판"
        ))
        let rawDisplayPattern = try NSRegularExpression(
            pattern: #"\b(?:Text|Label|Button|BaseballCard)\s*\([^)]*(?:state\.chapter\.title|state\.rival\.(?:name|archetype|signatureRecord)|field\.(?:tournamentName|playerRound|schools)|goal\.(?:title|detail))"#
        )

        for (name, card, required) in [
            ("ChapterReviewCard", review, "HighSchoolPresentation.localizedChapterReview"),
            ("TournamentCard", tournament, "HighSchoolPresentation.localizedTournament"),
            ("ChapterGoalCard", goal, "HighSchoolPresentation.localizedChapterGoal"),
        ] {
            XCTAssertNil(
                rawDisplayPattern.firstMatch(
                    in: card,
                    range: NSRange(location: 0, length: card.utf16.count)
                ),
                "raw display path in \(name)"
            )
            XCTAssertTrue(card.contains(required), "missing typed boundary in \(name)")
            XCTAssertTrue(card.contains("Text(verbatim:"), "resolved text boundary in \(name)")
        }

        XCTAssertTrue(review.contains("CareerChapterPresentationCatalog") || review.contains("localizedChapterReviewTitle"))
        XCTAssertTrue(review.contains("localizedChapterReviewRivalLine"))
        XCTAssertTrue(tournament.contains("CopyToken.schoolSelection"))
        XCTAssertTrue(tournament.contains("localizedTournamentOpponentSchool"))
        XCTAssertTrue(goal.contains("ChapterGoalPresentationCatalog") || goal.contains("localizedChapterGoalTitle"))
        XCTAssertTrue(goal.contains("localizedChapterGoalDetail"))
    }

    func testScopedEnglishReauthoringUsesTypedCommunityRankingAndForecastBoundaries() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let recordSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("apps/ios/Sources/RecordView.swift"),
            encoding: .utf8
        )
        let recordStart = try XCTUnwrap(recordSource.range(of: "private struct ProspectRankingCard"))
        let recordEnd = try XCTUnwrap(
            recordSource.range(of: "/// 업적으로 가는 문", range: recordStart.upperBound..<recordSource.endIndex)
        )
        let record = String(recordSource[recordStart.lowerBound..<recordEnd.lowerBound])
        XCTAssertTrue(record.contains("ProspectRankingPresentation.board"))
        XCTAssertTrue(record.contains("Text(verbatim: entry.identityLine)"))
        XCTAssertTrue(record.contains("Text(verbatim: entry.tag)"))
        XCTAssertFalse(record.contains("ProspectRanking.board("))
        XCTAssertFalse(record.contains("forecast.band"))
        XCTAssertFalse(record.contains("forecast.interestedTeam"))
        XCTAssertFalse(record.contains("Text(entry.name)"))
        XCTAssertFalse(record.contains("Text(entry.school)"))

        let appShellSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("apps/ios/Sources/AppShell.swift"),
            encoding: .utf8
        )
        let appShellStart = try XCTUnwrap(appShellSource.range(of: "private struct ProLockedView"))
        let appShellEnd = try XCTUnwrap(
            appShellSource.range(of: "/// 프로 커리어 안의 오늘/이번 주 두 화면.", range: appShellStart.upperBound..<appShellSource.endIndex)
        )
        let appShell = String(appShellSource[appShellStart.lowerBound..<appShellEnd.lowerBound])
        XCTAssertTrue(appShell.contains("ProspectRankingPresentation.localizedForecastBand"))
        XCTAssertTrue(appShell.contains("ProspectRankingPresentation.localizedForecastTeam"))
        XCTAssertFalse(appShell.contains("forecast.band"))
        XCTAssertFalse(appShell.contains("forecast.interestedTeam"))
        XCTAssertFalse(appShell.contains(".userText(forecast.interestedTeam)"))

        let highSchoolSource = try IOSSourceScan.read("apps/ios/Sources/HighSchoolChapterReviewViews.swift")
        let buzzStart = try XCTUnwrap(highSchoolSource.range(of: "struct CommunityBuzzCard"))
        let buzzEnd = try XCTUnwrap(
            highSchoolSource.range(of: "/// 이 회차가 살아온 순간들.", range: buzzStart.upperBound..<highSchoolSource.endIndex)
        )
        let buzz = String(highSchoolSource[buzzStart.lowerBound..<buzzEnd.lowerBound])
        XCTAssertTrue(buzz.contains("CommunityBuzzPresentation.localizedReaction"))
        XCTAssertTrue(buzz.contains("CommunityBuzzPresentation.localizedNews"))
        XCTAssertTrue(buzz.contains("Text(verbatim:"))
        XCTAssertFalse(buzz.contains("Text(line)"))
        XCTAssertFalse(buzz.contains("var title = \"그라운드 밖의 목소리\""))
        XCTAssertFalse(buzz.contains("var footnote = \"익명 야구 게시판의 반응입니다.\""))
    }
}
