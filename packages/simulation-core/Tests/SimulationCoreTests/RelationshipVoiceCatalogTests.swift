import XCTest
@testable import SimulationCore

final class RelationshipVoiceCatalogTests: XCTestCase {
    func testEveryRelationshipEventHasItsOwnAuthoredScene() throws {
        let events = HighSchoolContentCatalog.relationshipEvents
        XCTAssertEqual(events.count, 49)
        XCTAssertEqual(Set(events.map(\.id)).count, 49)
        XCTAssertEqual(Set(RelationshipVoiceCatalog.scenes.keys), Set(events.map(\.id)))

        for event in events {
            let authored = try XCTUnwrap(RelationshipVoiceCatalog.scenes[event.id], event.id)
            XCTAssertEqual(
                RelationshipVoiceCatalog.scene(eventID: event.id, category: "unknown-category"),
                authored,
                "\(event.id) must resolve by ID rather than a category fallback"
            )
            for band in [
                RelationshipVoiceCatalog.TrustBand.low,
                .mid,
                .high,
            ] {
                XCTAssertFalse(authored.quote(band).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(event.id) \(band)")
            }
        }
    }

    func testEveryAuthoredSceneHasStableConcreteChoices() throws {
        let prohibitedTitles: Set<String> = [
            "듣는다", "설명한다", "확인한다", "정리한다", "결과로 답한다",
            "먼저 듣는다", "내 생각을 말한다", "다음 승부로 증명한다",
        ]
        let boilerplateClusters = ["결과로 증명", "결과로 답", "생각을 설명", "말을 듣는다"]
        let expectedResponses = Set(RelationshipResponse.allCases)

        for event in HighSchoolContentCatalog.relationshipEvents {
            let scene = try XCTUnwrap(RelationshipVoiceCatalog.scenes[event.id])
            XCTAssertEqual(scene.choices.count, 3, event.id)
            XCTAssertEqual(Set(scene.choices.map(\.response)), expectedResponses, event.id)
            XCTAssertEqual(Set(scene.choices.map(\.title)).count, 3, event.id)

            for choice in scene.choices {
                let title = choice.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = choice.detail.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(title.isEmpty, event.id)
                XCTAssertFalse(detail.isEmpty, event.id)
                XCTAssertNotEqual(title, detail, event.id)
                XCTAssertFalse(prohibitedTitles.contains(title), "\(event.id): \(title)")
                XCTAssertFalse(boilerplateClusters.contains { title.contains($0) }, "\(event.id): \(title)")
            }
        }
    }

    func testEveryAuthoredSceneHasThreeDistinctEventSpecificAftermaths() throws {
        let events = HighSchoolContentCatalog.relationshipEvents
        XCTAssertEqual(RelationshipVoiceCatalog.aftermathEventIDs, Set(events.map(\.id)))

        for event in events {
            let scene = try XCTUnwrap(RelationshipVoiceCatalog.scenes[event.id])
            let aftermaths = RelationshipResponse.allCases.map {
                RelationshipVoiceCatalog.aftermath(
                    eventID: event.id,
                    speaker: scene.speaker,
                    response: $0,
                    trustChange: 0
                )
            }
            XCTAssertEqual(Set(aftermaths).count, 3, event.id)
            XCTAssertTrue(aftermaths.allSatisfy { !$0.isEmpty }, event.id)
            XCTAssertFalse(aftermaths.contains { $0.contains("관계는 이번 선택을 기억") }, event.id)
        }
    }

    func testRepresentativeAftermathsFollowTheChosenAction() {
        let coachListen = RelationshipVoiceCatalog.aftermath(
            eventID: "evt-coach-role", speaker: .coach, response: .listen, trustChange: -7
        )
        let coachChallenge = RelationshipVoiceCatalog.aftermath(
            eventID: "evt-coach-role", speaker: .coach, response: .challenge, trustChange: 7
        )
        XCTAssertTrue(coachListen.contains("이유") || coachListen.contains("부족"))
        XCTAssertTrue(coachChallenge.contains("등판") || coachChallenge.contains("선발"))

        let teammateListen = RelationshipVoiceCatalog.aftermath(
            eventID: "evt-lost-teammate", speaker: .named("옛 동료"), response: .listen, trustChange: 7
        )
        let teammateChallenge = RelationshipVoiceCatalog.aftermath(
            eventID: "evt-lost-teammate", speaker: .named("옛 동료"), response: .challenge, trustChange: -7
        )
        XCTAssertTrue(teammateListen.contains("말") || teammateListen.contains("그만"))
        XCTAssertTrue(teammateChallenge.contains("캐치볼"))

        let armRest = RelationshipVoiceCatalog.aftermath(
            eventID: "evt-arm-care", speaker: .named("트레이너"), response: .listen, trustChange: 0
        )
        let armExamination = RelationshipVoiceCatalog.aftermath(
            eventID: "evt-arm-care", speaker: .named("트레이너"), response: .explain, trustChange: 0
        )
        XCTAssertTrue(armRest.contains("휴식"))
        XCTAssertTrue(armExamination.contains("검진"))
    }

    func testUnknownAndLegacyIDsStillHaveFallbacks() {
        XCTAssertNotNil(RelationshipVoiceCatalog.scene(eventID: "legacy-growth", category: "growth"))
        XCTAssertNotNil(RelationshipVoiceCatalog.scene(eventID: "legacy-coach", category: "coach"))
        XCTAssertNil(RelationshipVoiceCatalog.scene(eventID: "legacy-unknown", category: "unknown"))
    }
}
