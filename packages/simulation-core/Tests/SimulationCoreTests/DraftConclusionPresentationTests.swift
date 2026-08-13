import Foundation
import XCTest
@testable import SimulationCore

final class DraftConclusionPresentationTests: XCTestCase {
    func testConclusionDescriptorInventoriesAreCompleteAndCollisionFree() {
        XCTAssertEqual(
            DraftConclusionPresentationCatalog.fieldDescriptors.count,
            DraftConclusionFieldID.allCases.count
        )
        XCTAssertEqual(
            DraftConclusionPresentationCatalog.teamFieldDescriptors.count,
            HighSchoolCareerEngine.teams.count * DraftTeamConclusionFieldID.allCases.count
        )
        XCTAssertEqual(
            DraftConclusionPresentationCatalog.personalityDescriptors.count,
            PersonalityTrait.allCases.count
        )
        XCTAssertEqual(
            DraftConclusionPresentationCatalog.memoryDescriptors.count,
            MemoryCardID.allCases.count
        )
        XCTAssertEqual(
            DraftConclusionPresentationCatalog.signatureLegacyDescriptors.count,
            CareerSignatureLegacyID.allCases.count
        )
        XCTAssertEqual(
            DraftConclusionPresentationCatalog.chronicleProducerDescriptors.count,
            ChronicleProducerID.allCases.count
        )

        let keys = DraftConclusionPresentationCatalog.semanticKeys
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertTrue(keys.allSatisfy { !$0.isEmpty && !$0.contains(where: { $0.isWhitespace }) })
        XCTAssertTrue(keys.allSatisfy {
            $0.unicodeScalars.allSatisfy { !(0xAC00...0xD7A3).contains($0.value) }
        })
    }

    func testRawKoreanDraftFieldsAndRepresentativeTeamDataRemainExact() {
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

        XCTAssertEqual(draft.projectedRange, "2~3라운드")
        XCTAssertEqual(draft.firstSeasonGoal, "퓨처스 선발 10경기와 볼넷률 8% 이하")
        XCTAssertEqual(draft.evaluationBreakdown, ["능력 26", "고교 공식 경기 +7", "팔 상태 -2"])
        XCTAssertEqual(draft.summary, "지명 구단 · 서울 코메츠. 구위와 고교 경기 기록에서 높은 평가를 받았습니다.")
        XCTAssertEqual(team.id, "seoul_comets")
        XCTAssertEqual(team.name, "서울 코메츠")
        XCTAssertEqual(team.developmentPlan, "2군 선발로 뛰며 원하는 코스에 던지는 능력 향상")
        XCTAssertEqual(team.positionCompetitor, "차윤호")
        XCTAssertEqual(team.proCoach, "문재석")
        XCTAssertEqual(team.competitorProfile, "느린 커브와 타이밍 싸움으로 살아남은 베테랑 선발")
        XCTAssertEqual(team.competitorRecord, "최근 시즌 9승 · ERA 3.91")
        XCTAssertEqual(team.coachProfile, "선수와 대화부터 시작하는 수비 중심 지도자")
        XCTAssertEqual(team.coachRecord, "3년 연속 포스트시즌 진출")
    }

    func testPresentationLookupCannotChangeDraftPhaseSeedHashCommitmentOrJSON() throws {
        let engine = HighSchoolCareerEngine()
        let beforeDraft = try reachDraft(engine, seed: "20260723")
        let beforeJSON = try JSONEncoder().encode(beforeDraft.snapshot)

        _ = DraftConclusionPresentationCatalog.semanticKeys
        _ = DraftConclusionPresentationCatalog.teamFieldDescriptors.map(\.token)
        _ = DraftConclusionPresentationCatalog.memoryDescriptors.map(\.detailToken)
        _ = DraftConclusionPresentationCatalog.signatureLegacyDescriptors.map(\.evidenceToken)

        let first = try engine.resolveDraft(.init(seed: beforeDraft.nextSeed, state: beforeDraft.snapshot))
        let afterJSON = try JSONEncoder().encode(beforeDraft.snapshot)
        let second = try engine.resolveDraft(.init(seed: beforeDraft.nextSeed, state: beforeDraft.snapshot))

        XCTAssertEqual(beforeJSON, afterJSON)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.nextSeed, second.nextSeed)
        XCTAssertEqual(first.eventHash, second.eventHash)
        XCTAssertEqual(first.snapshot.stateCommitment, second.snapshot.stateCommitment)
        XCTAssertEqual(first.snapshot.phase, .completed, "This deterministic golden reaches the drafted conclusion.")
        XCTAssertEqual(first.events.map(\.eventType), ["career_draft_resolved"])
        XCTAssertEqual(first.events.map(\.reasonCodes), [["draft.drafted"]])

        let resultJSON = try JSONEncoder().encode(first.snapshot)
        let decoded = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: resultJSON)
        XCTAssertEqual(decoded, first.snapshot)
    }

    private func reachDraft(
        _ engine: HighSchoolCareerEngine,
        seed: String
    ) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)
        ))

        for _ in 0..<80 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: result.snapshot.school?.strength ?? .command,
                    intensity: .intensive
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 18,
                        strikeouts: 4,
                        walks: 0,
                        runsAllowed: 0,
                        expectedDamage: 380,
                        actualDamage: 120,
                        recommendationAccepted: 10
                    )
                ))
            case .awakening:
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft:
                return result
            case .prologue, .schoolSelection, .legacy, .completed:
                XCTFail("Unexpected phase while reaching draft: \(result.snapshot.phase)")
                return result
            }
        }
        XCTFail("Career did not reach the draft phase")
        return result
    }
}
