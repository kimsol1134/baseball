import Foundation
import SimulationCore
import XCTest
@testable import BaseballIOS

@MainActor
final class PlayerBondStoryTests: XCTestCase {
    func testHeartlineVisibilityWaitsForFirstGameAndMeaningfulMoment() {
        XCTAssertNil(PlayerBondStory.heartlinePresentation(
            for: context(phase: .awakening, armRisk: 80),
            importantGamesCompleted: 0
        ))
        XCTAssertNil(PlayerBondStory.heartlinePresentation(
            for: context(phase: .training, fanInterest: 100, catcherTrust: 100),
            importantGamesCompleted: 1
        ))
        XCTAssertNil(PlayerBondStory.heartlinePresentation(
            for: context(phase: .importantGame),
            importantGamesCompleted: 1
        ))
    }

    func testHeartlineVisibilityHasStableBranchesAndHealthPriority() {
        let phases: [(HighSchoolCareerPhase, PlayerHeartlineBranch)] = [
            (.chapterReview, .chapterReview),
            (.awakening, .awakening),
            (.draft, .draft),
            (.legacy, .legacy),
            (.completed, .completed),
        ]
        for (phase, expected) in phases {
            XCTAssertEqual(
                PlayerBondStory.heartlinePresentation(
                    for: context(phase: phase), importantGamesCompleted: 1
                )?.branch,
                expected
            )
        }

        XCTAssertEqual(PlayerBondStory.heartlinePresentation(
            for: context(phase: .draft, fatigue: 90, armRisk: 70, injuryRecovery: 1),
            importantGamesCompleted: 1
        )?.branch, .injuryRecovery)
        XCTAssertEqual(PlayerBondStory.heartlinePresentation(
            for: context(phase: .training, armRisk: 70), importantGamesCompleted: 1
        )?.branch, .armWarning)
        XCTAssertEqual(PlayerBondStory.heartlinePresentation(
            for: context(phase: .training, fatigue: 90), importantGamesCompleted: 1
        )?.branch, .fatigueWarning)
    }

    func testHeartlineAnalyticsUsesStableBranchWithoutPlayerCopy() {
        let scope = PlayerHeartCard.analyticsScope(
            careerID: "career-a", lifeNumber: 2, branch: .chapterReview
        )
        XCTAssertEqual(scope, "heartline:career-a:2:chapter_review")

        let properties = PlayerHeartCard.analyticsProperties(
            lifeNumber: 2, phase: .chapterReview, branch: .chapterReview
        )
        XCTAssertEqual(properties["branch_id"] as? String, "chapter_review")
        XCTAssertEqual(properties["life_number"] as? Int, 2)
        XCTAssertEqual(properties["phase"] as? String, HighSchoolCareerPhase.chapterReview.rawValue)
        XCTAssertEqual(Set(properties.keys), ["branch_id", "life_number", "phase"])
    }

    func testHeartlineRespondsToHealthBeforePersonality() {
        let recovering = PlayerBondStory.heartline(for: context(
            injuryRecovery: 1, personalityTitle: "불같은 승부사"
        ))
        XCTAssertEqual(recovering.mood, "다시 던지기 위해")
        XCTAssertTrue(recovering.words.contains("오래 던지고"))

        let warning = PlayerBondStory.heartline(for: context(
            armRisk: 55, personalityTitle: "차가운 분석가"
        ))
        XCTAssertEqual(warning.mood, "팔이 보내는 신호")

        let tired = PlayerBondStory.heartline(for: context(
            fatigue: 80, personalityTitle: "조용한 버팀목"
        ))
        XCTAssertEqual(tired.mood, "조금 지친 마음")
        XCTAssertTrue(tired.words.contains("쉬는 날"))
    }

    func testHeartlineRespondsToMomentRelationshipAndPersonality() {
        XCTAssertEqual(
            PlayerBondStory.heartline(for: context(phase: .importantGame)).mood,
            "큰 경기를 앞두고"
        )
        XCTAssertEqual(
            PlayerBondStory.heartline(for: context(phase: .awakening)).mood,
            "달라지기 직전"
        )
        XCTAssertTrue(PlayerBondStory.heartline(for: context(catcherTrust: 70)).words.contains("포수"))
        XCTAssertTrue(PlayerBondStory.heartline(for: context(
            personalityTitle: "차가운 분석가"
        )).words.contains("왜 이 공"))
    }

    func testFinishedPlayerDoesNotCallAnUndraftedLifeAFailure() {
        let line = PlayerBondStory.heartline(for: context(phase: .legacy, drafted: false))
        XCTAssertEqual(line.mood, "3년을 마치며")
        XCTAssertTrue(line.words.contains("실패로 부르지는"))
    }

    func testLegacyUsesActualStoryAndChosenMemories() {
        let record = life(
            drafted: false,
            memories: [.coachLetter],
            chronicle: [
                "1학년 봄 — 첫 등교.",
                "2학년 여름 — 제구 재능이 만개했습니다.",
                "3학년 여름 — 마지막 경기를 마쳤습니다.",
            ]
        )
        let legacy = PlayerBondStory.legacy(for: record)
        XCTAssertEqual(legacy.definingMoment, "2학년 여름 — 제구 재능이 만개했습니다.")
        XCTAssertTrue(legacy.farewell.contains("사라지는 건 아니죠"))
        XCTAssertTrue(legacy.farewell.contains("기억은 다음 선수"))
    }

    func testGeneratedLegacyIsFrozenAndRoundTrips() throws {
        var record = life(drafted: true, personality: "조용한 버팀목")
        record.playerLegacy = PlayerBondStory.legacy(for: record)
        let decoded = try JSONDecoder().decode(
            HighSchoolCareerStore.LifeRecord.self,
            from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.playerLegacy, record.playerLegacy)
        XCTAssertTrue(decoded.playerLegacy?.farewell.contains("말없이 오래") == true)
    }

    func testRecordFromBeforePlayerLettersStillOpensAndGetsFallbackStory() throws {
        let json = """
        {
          "lifeNumber":1,
          "playerName":"옛 선수",
          "drafted":false,
          "evaluationScore":52,
          "memories":[],
          "games":4,
          "strikeouts":12,
          "walks":7,
          "runsAllowed":8,
          "soulPoints":20
        }
        """
        let record = try JSONDecoder().decode(
            HighSchoolCareerStore.LifeRecord.self, from: Data(json.utf8)
        )
        XCTAssertNil(record.playerLegacy)
        let fallback = PlayerBondStory.legacy(for: record)
        XCTAssertFalse(fallback.farewell.isEmpty)
        XCTAssertTrue(fallback.definingMoment.contains("마지막 공"))
    }

    func testSameNameLetterCallsOutASeparateNextPlayer() {
        XCTAssertEqual(
            PreviousPlayerLetterCard.recipientLine(previousName: "김마루", currentName: "김마루"),
            "같은 이름을 이어받은 새 선수에게"
        )
        XCTAssertEqual(
            PreviousPlayerLetterCard.recipientLine(previousName: "김마루", currentName: "이하늘"),
            "새로 시작하는 이하늘에게"
        )
    }

    func testBondMemoryKeepsOnlyDefiningRelationshipChoices() {
        XCTAssertEqual(
            HighSchoolCareerStore.bondMemoryKind(
                eventCategory: "health",
                personalityChanged: false,
                trustBefore: 40,
                trustAfter: 35
            ),
            .healthChoice
        )
        XCTAssertEqual(
            HighSchoolCareerStore.bondMemoryKind(
                eventCategory: "coach",
                personalityChanged: true,
                trustBefore: 55,
                trustAfter: 60
            ),
            .personality
        )
        XCTAssertEqual(
            HighSchoolCareerStore.bondMemoryKind(
                eventCategory: "catcher",
                personalityChanged: false,
                trustBefore: 68,
                trustAfter: 74
            ),
            .trustMilestone
        )
        XCTAssertNil(HighSchoolCareerStore.bondMemoryKind(
            eventCategory: "media",
            personalityChanged: false,
            trustBefore: 52,
            trustAfter: 56
        ))
    }

    func testBondMemoryRoundTripsThroughLiveSaveAndLifeRecord() throws {
        let memory = HighSchoolCareerStore.PlayerBondMemory(
            kind: .trustMilestone,
            eventID: "evt-catcher-sign",
            eventCategory: "catcher",
            eventTitle: "사인 다툼",
            response: .listen,
            subjectName: "한결",
            chapterNumber: 4,
            trustBefore: 68,
            trustAfter: 74
        )
        let save = HighSchoolCareerStore.SaveRecord(
            result: nil,
            inheritance: .firstLife,
            archive: [],
            bondMemories: [memory],
            revision: 1
        )
        let restored = try JSONDecoder().decode(
            HighSchoolCareerStore.SaveRecord.self,
            from: JSONEncoder().encode(save)
        )
        XCTAssertEqual(restored.bondMemories, [memory])

        let state = try HighSchoolCareerEngine().start(.init(
            seed: "727272",
            presetID: "precision_commander"
        )).snapshot
        let record = HighSchoolCareerStore.lifeRecord(
            from: state,
            memories: [],
            previous: .firstLife,
            bondMemories: [memory]
        )
        XCTAssertEqual(record.bondMemories, [memory])
    }

    func testRebirthEchoUsesOnlyFactsThePreviousPlayerActuallyLived() {
        var record = life(
            drafted: false,
            memories: [.coachLetter],
            chronicle: ["3학년 여름 — 무너진 날 — 마지막 경기에서 실점했습니다."],
            playerName: "한마루"
        )
        record.nicknames = ["철완"]
        record.hadArmWarning = true

        let echo = HighSchoolCareerStore.rebirthEcho(from: record, inheritedMemoryCount: 1)
        XCTAssertEqual(echo.previousPlayerName, "한마루")
        XCTAssertEqual(echo.previousSchoolName, "서울덕성고")
        XCTAssertEqual(echo.previousNickname, "철완")
        XCTAssertEqual(echo.inheritedMemoryCount, 1)
        XCTAssertTrue(echo.hadArmWarning)
        XCTAssertTrue(echo.hadCollapseGame)
        XCTAssertTrue(echo.wasUndrafted)

        let clean = HighSchoolCareerStore.rebirthEcho(
            from: life(drafted: true, chronicle: ["3학년 여름 — 마지막 경기를 마쳤습니다."]),
            inheritedMemoryCount: 0
        )
        XCTAssertFalse(clean.hadArmWarning)
        XCTAssertFalse(clean.hadCollapseGame)
        XCTAssertFalse(clean.wasUndrafted)
        XCTAssertNil(clean.previousNickname)
    }

    func testLineageMasteryCountsOneSelectedLegacyPerLife() {
        var first = life(drafted: true, lifeNumber: 1, playerName: "첫 선수")
        first.signatureLegacy = CareerSignatureLegacy.definition(for: .powerImprint)
        var duplicate = first
        duplicate.signatureLegacy = CareerSignatureLegacy.definition(for: .powerImprint)
        var second = life(drafted: true, lifeNumber: 2, playerName: "둘째 선수")
        second.signatureLegacy = CareerSignatureLegacy.definition(for: .powerImprint)
        var third = life(drafted: false, lifeNumber: 3, playerName: "셋째 선수")
        third.signatureLegacy = CareerSignatureLegacy.definition(for: .powerImprint)

        let mastery = HighSchoolCareerStore.lineageMasteries(from: [first, duplicate, second, third])
            .first { $0.family == .power }
        XCTAssertEqual(mastery?.contributions, 3)
        XCTAssertEqual(mastery?.rank, 2)

        let loadout = HighSchoolCareerStore.lineageLoadout(
            equippedLegacyID: .powerImprint,
            archive: [first, duplicate, second, third]
        )
        XCTAssertEqual(loadout?.sourceLifeNumber, 3)
        XCTAssertEqual(loadout?.masteryRank, 2)
        XCTAssertEqual(loadout?.contributions, 3)
    }

    func testLineageRankUpOnlyAppearsAtDurableThreeAndSixContributions() {
        func powerLife(_ number: Int) -> HighSchoolCareerStore.LifeRecord {
            var record = life(drafted: true, lifeNumber: number, playerName: "\(number)번째 선수")
            record.signatureLegacy = CareerSignatureLegacy.definition(for: .powerImprint)
            return record
        }
        let first = powerLife(1)
        let second = powerLife(2)
        let third = powerLife(3)
        let fourth = powerLife(4)
        let fifth = powerLife(5)
        let sixth = powerLife(6)

        XCTAssertNil(HighSchoolCareerStore.lineageRankUp(
            family: .power, before: [first], after: [second, first]
        ))
        XCTAssertEqual(HighSchoolCareerStore.lineageRankUp(
            family: .power, before: [second, first], after: [third, second, first]
        )?.rank, 2)
        XCTAssertNil(HighSchoolCareerStore.lineageRankUp(
            family: .power,
            before: [fourth, third, second, first],
            after: [fifth, fourth, third, second, first]
        ))
        XCTAssertEqual(HighSchoolCareerStore.lineageRankUp(
            family: .power,
            before: [fifth, fourth, third, second, first],
            after: [sixth, fifth, fourth, third, second, first]
        )?.rank, 3)
    }

    func testArchiveLineageIsAlwaysNewestFirst() {
        let ordered = LifeArchiveOrdering.newestFirst([
            life(drafted: false, lifeNumber: 1, playerName: "첫 선수"),
            life(drafted: true, lifeNumber: 3, playerName: "셋째 선수"),
            life(drafted: false, lifeNumber: 2, playerName: "둘째 선수"),
        ])
        XCTAssertEqual(ordered.map(\.lifeNumber), [3, 2, 1])
        XCTAssertEqual(ordered.map(\.playerName), ["셋째 선수", "둘째 선수", "첫 선수"])
    }

    func testArchiveLineageRibbonRunsOldestToNewest() {
        let ordered = LifeArchiveOrdering.oldestFirst([
            life(drafted: true, lifeNumber: 3, playerName: "셋째 선수"),
            life(drafted: false, lifeNumber: 1, playerName: "첫 선수"),
            life(drafted: false, lifeNumber: 2, playerName: "둘째 선수"),
        ])
        XCTAssertEqual(ordered.map(\.lifeNumber), [1, 2, 3])
    }

    func testRecapLegacyLogsOnlyAtActualRevealAndOnlyOnce() {
        XCTAssertFalse(RunRecapView.legacyIsVisible(revealed: 2, stampCount: 3))
        XCTAssertFalse(RunRecapView.shouldLogLegacy(
            alreadyLogged: false, revealed: 2, stampCount: 3
        ))
        XCTAssertTrue(RunRecapView.shouldLogLegacy(
            alreadyLogged: false, revealed: 3, stampCount: 3
        ))
        XCTAssertFalse(RunRecapView.shouldLogLegacy(
            alreadyLogged: true, revealed: 3, stampCount: 3
        ))
    }

    func testRecapContinuePropertiesContainOnlyLowCardinalityFunnelFields() {
        let properties = RunRecapView.continueAnalyticsProperties(
            lifeNumber: 4,
            drafted: true,
            entryPath: "quick_rebirth",
            hasSuggestedIntent: true,
            intentSaved: false
        )
        XCTAssertEqual(properties["life_number"] as? Int, 4)
        XCTAssertEqual(properties["drafted"] as? Bool, true)
        XCTAssertEqual(properties["entry_path"] as? String, "quick_rebirth")
        XCTAssertEqual(properties["has_suggested_intent"] as? Bool, true)
        XCTAssertEqual(properties["intent_saved"] as? Bool, false)
        XCTAssertEqual(Set(properties.keys), [
            "life_number", "drafted", "entry_path", "has_suggested_intent", "intent_saved",
        ])
    }

    private func context(
        phase: SimulationCore.HighSchoolCareerPhase = .training,
        fatigue: Int = 0,
        armRisk: Int = 0,
        injuryRecovery: Int = 0,
        fanInterest: Int = 0,
        managerTrust: Int = 0,
        catcherTrust: Int = 0,
        rivalTrust: Int = 0,
        personalityTitle: String? = nil,
        drafted: Bool? = nil
    ) -> PlayerHeartContext {
        PlayerHeartContext(
            playerName: "테스트 선수",
            phase: phase,
            fatigue: fatigue,
            armRisk: armRisk,
            injuryRecovery: injuryRecovery,
            fanInterest: fanInterest,
            managerTrust: managerTrust,
            catcherTrust: catcherTrust,
            rivalTrust: rivalTrust,
            personalityTitle: personalityTitle,
            drafted: drafted
        )
    }

    private func life(
        drafted: Bool,
        memories: [SimulationCore.MemoryCardID] = [],
        chronicle: [String]? = nil,
        personality: String? = nil,
        lifeNumber: Int = 2,
        playerName: String = "김마루"
    ) -> HighSchoolCareerStore.LifeRecord {
        HighSchoolCareerStore.LifeRecord(
            lifeNumber: lifeNumber,
            playerName: playerName,
            schoolName: "서울덕성고",
            drafted: drafted,
            evaluationScore: drafted ? 72 : 58,
            teamName: drafted ? "서울 타이탄즈" : nil,
            memories: memories,
            games: 5,
            strikeouts: 24,
            walks: 5,
            runsAllowed: 6,
            soulPoints: 42,
            chronicle: chronicle,
            personality: personality
        )
    }
}
