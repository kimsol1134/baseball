import Foundation
import XCTest
@testable import SimulationCore

final class HighSchoolCareerEngineTests: XCTestCase {
    func testVerticalSliceContentMinimumsUseStableUniqueIDs() {
        XCTAssertEqual(HighSchoolContentCatalog.events.count, 36)
        XCTAssertEqual(Set(HighSchoolContentCatalog.events.map(\.id)).count, 36)
        XCTAssertEqual(HighSchoolContentCatalog.scenarios.count, 12)
        XCTAssertEqual(Set(HighSchoolContentCatalog.scenarios.map(\.id)).count, 12)
        XCTAssertEqual(AwakeningID.allCases.count, 18)
        XCTAssertEqual(MemoryCardID.allCases.count, 18)
    }

    func testDifficultyAndKarmaChangeRulesWithoutChangingContentOrder() throws {
        let engine = HighSchoolCareerEngine()
        let relaxed = try engine.start(
            StartHighSchoolCareerParams(
                seed: "301",
                presetID: "power_prospect",
                difficulty: CareerDifficultySnapshot(
                    careerHarshness: .relaxed,
                    informationClarity: .relaxed,
                    simulationDifficulty: .relaxed,
                    interventionAssist: .full
                )
            )
        )
        let cursed = try engine.start(
            StartHighSchoolCareerParams(
                seed: "301",
                presetID: "power_prospect",
                difficulty: CareerDifficultySnapshot(
                    careerHarshness: .challenging,
                    informationClarity: .challenging,
                    simulationDifficulty: .challenging,
                    interventionAssist: .minimal
                ),
                karmas: [.geniusGeneration, .erasedMemory]
            )
        )

        XCTAssertEqual(relaxed.snapshot.schoolOptions.map(\.id), cursed.snapshot.schoolOptions.map(\.id))
        XCTAssertGreaterThan(cursed.snapshot.rival.contact, relaxed.snapshot.rival.contact)
        XCTAssertEqual(cursed.snapshot.memorySlots, 2)
        XCTAssertEqual(cursed.snapshot.legacyRewardPermille, 1_500)
        XCTAssertNotEqual(relaxed.snapshot.stateCommitment, cursed.snapshot.stateCommitment)
    }

    func testCareerCompletesEightChaptersAndDraftsDirectionalBuild() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(
            StartHighSchoolCareerParams(seed: "20260723", presetID: "power_prospect")
        )
        XCTAssertEqual(result.snapshot.phase, .prologue)
        result = try engine.completePrologue(
            AdvanceCareerChapterParams(seed: result.nextSeed, state: result.snapshot)
        )
        XCTAssertEqual(result.snapshot.schoolOptions.count, 4)
        XCTAssertEqual(HighSchoolCareerEngine.teams.count, 10)

        result = try engine.chooseSchool(
            ChooseSchoolParams(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower)
        )
        result = try completeCareer(engine, from: result, strongGames: true)

        XCTAssertEqual(result.snapshot.phase, .completed)
        XCTAssertEqual(result.snapshot.chapter.number, 8)
        XCTAssertEqual(result.snapshot.totalTrainingsCompleted, 16)
        XCTAssertEqual(result.snapshot.relationshipsCompleted, 5)
        XCTAssertEqual(result.snapshot.performance.importantGamesCompleted, 5)
        XCTAssertEqual(result.snapshot.selectedAwakenings.count, 3)
        XCTAssertEqual(result.snapshot.draftResult?.outcome, .drafted)
        XCTAssertNotNil(result.snapshot.draftResult?.team)
        XCTAssertNotNil(result.snapshot.draftResult?.firstSeasonGoal)
    }

    func testPoorResultsReachUndraftedLegacyAndSelectThreeMemories() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(
            StartHighSchoolCareerParams(seed: "17", presetID: "precision_commander")
        )
        result = try engine.completePrologue(
            AdvanceCareerChapterParams(seed: result.nextSeed, state: result.snapshot)
        )
        result = try engine.chooseSchool(
            ChooseSchoolParams(seed: result.nextSeed, state: result.snapshot, schoolID: .miraeAnalytics)
        )
        result = try completeCareer(engine, from: result, strongGames: false)

        XCTAssertEqual(result.snapshot.draftResult?.outcome, .undrafted)
        XCTAssertEqual(result.snapshot.phase, .legacy)
        XCTAssertEqual(result.snapshot.legacyOptions.count, 5)
        result = try engine.selectLegacy(
            SelectCareerLegacyParams(
                seed: result.nextSeed,
                state: result.snapshot,
                memoryCards: Array(result.snapshot.legacyOptions.prefix(3))
            )
        )
        XCTAssertEqual(result.snapshot.phase, .completed)
        XCTAssertEqual(result.snapshot.selectedMemories.count, 3)
    }

    func testSameSeedAndSchoolProduceSameCareerState() throws {
        let engine = HighSchoolCareerEngine()
        let first = try engine.start(StartHighSchoolCareerParams(seed: "44", presetID: "innings_eater"))
        let second = try engine.start(StartHighSchoolCareerParams(seed: "44", presetID: "innings_eater"))
        XCTAssertEqual(first, second)

        let firstPrologue = try engine.completePrologue(
            AdvanceCareerChapterParams(seed: first.nextSeed, state: first.snapshot)
        )
        let secondPrologue = try engine.completePrologue(
            AdvanceCareerChapterParams(seed: second.nextSeed, state: second.snapshot)
        )

        let firstSchool = try engine.chooseSchool(
            ChooseSchoolParams(seed: firstPrologue.nextSeed, state: firstPrologue.snapshot, schoolID: .hanbitTraditional)
        )
        let secondSchool = try engine.chooseSchool(
            ChooseSchoolParams(seed: secondPrologue.nextSeed, state: secondPrologue.snapshot, schoolID: .hanbitTraditional)
        )
        XCTAssertEqual(firstSchool, secondSchool)
    }

    func testRelationshipPhaseCarriesAConcreteScene() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(StartHighSchoolCareerParams(seed: "808", presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .miraeAnalytics))
        for _ in 0..<2 { result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .gamePlanning, intensity: .standard)) }
        XCTAssertEqual(result.snapshot.phase, .relationship)
        XCTAssertEqual(result.snapshot.currentRelationshipEvent?.category, "coach")
        XCTAssertFalse(result.snapshot.currentRelationshipEvent?.summary.isEmpty ?? true)

        result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
        let headline = try XCTUnwrap(result.snapshot.news.first)
        XCTAssertTrue(headline.contains("염경윤 감독"))
        XCTAssertTrue(headline.contains("감독이 본 문제"))
        XCTAssertFalse(headline.contains("listen"))
        XCTAssertFalse(headline.contains("이야기를 나눴습니다"))
    }

    func testRelationshipResponseDependsOnPersonnelInsteadOfAlwaysRewardingListening() throws {
        let engine = HighSchoolCareerEngine()
        let scene = try reachFirstRelationship(engine, schoolID: .haedongPower)

        let listened = try engine.resolveRelationship(.init(seed: scene.nextSeed, state: scene.snapshot, response: .listen))
        let challenged = try engine.resolveRelationship(.init(seed: scene.nextSeed, state: scene.snapshot, response: .challenge))

        XCTAssertGreaterThan(challenged.snapshot.relationshipTrust, listened.snapshot.relationshipTrust)
        XCTAssertGreaterThan(challenged.snapshot.fanInterest, listened.snapshot.fanInterest)
        XCTAssertGreaterThan(challenged.snapshot.fatigue, listened.snapshot.fatigue)
        XCTAssertTrue(challenged.snapshot.news.first?.contains("공개 불펜") == true)
    }

    func testAwakeningCandidatesFollowTrainingAndCreateARealTradeoff() throws {
        let engine = HighSchoolCareerEngine()
        let awakening = try reachFirstAwakening(engine, focus: .velocity)
        XCTAssertEqual(awakening.snapshot.awakeningOptions.count, 3)
        let chosen = try XCTUnwrap(awakening.snapshot.awakeningOptions.first { [.explosiveFastball, .risingFourSeam].contains($0) })
        let before = awakening.snapshot.pitcher
        let after = try engine.chooseAwakening(.init(seed: awakening.nextSeed, state: awakening.snapshot, awakening: chosen)).snapshot.pitcher
        let beforeFastball = try XCTUnwrap(before.pitchProfiles?.first { $0.pitchType == .fourSeam })
        let afterFastball = try XCTUnwrap(after.pitchProfiles?.first { $0.pitchType == .fourSeam })

        XCTAssertGreaterThan(after.stuff, before.stuff)
        XCTAssertGreaterThan(afterFastball.whiff, beforeFastball.whiff)
        XCTAssertTrue(after.command < before.command || after.movement < before.movement)
    }

    func testInheritedMemoryChangesBothRatingAndPitchShape() throws {
        let engine = HighSchoolCareerEngine()
        let baseline = try engine.start(.init(seed: "919", presetID: "power_prospect"))
        let inherited = try engine.start(.init(seed: "919", presetID: "power_prospect", inheritedMemories: [.velocityBlueprint]))
        let baseFastball = try XCTUnwrap(baseline.snapshot.pitcher.pitchProfiles?.first { $0.pitchType == .fourSeam })
        let inheritedFastball = try XCTUnwrap(inherited.snapshot.pitcher.pitchProfiles?.first { $0.pitchType == .fourSeam })

        XCTAssertEqual(inherited.snapshot.pitcher.stuff, baseline.snapshot.pitcher.stuff + 2)
        XCTAssertEqual(inherited.snapshot.pitcher.command, baseline.snapshot.pitcher.command - 1)
        XCTAssertEqual(inheritedFastball.velocityTenthsKPH, baseFastball.velocityTenthsKPH + 10)
        XCTAssertGreaterThan(inheritedFastball.whiff, baseFastball.whiff)
    }

    func testCareerCommitmentRejectsChangedRatings() throws {
        let engine = HighSchoolCareerEngine()
        let start = try engine.start(StartHighSchoolCareerParams(seed: "55", presetID: "innings_eater"))
        let data = try JSONEncoder().encode(start.snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var pitcher = try XCTUnwrap(object["pitcher"] as? [String: Any])
        pitcher["stamina"] = 80
        object["pitcher"] = pitcher
        let changed = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertThrowsError(
            try engine.completePrologue(
                AdvanceCareerChapterParams(seed: start.nextSeed, state: changed)
            )
        )
    }

    private func completeCareer(
        _ engine: HighSchoolCareerEngine,
        from initial: HighSchoolCareerResult,
        strongGames: Bool
    ) throws -> HighSchoolCareerResult {
        var result = initial
        for _ in 0..<80 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(
                    CommitCareerTrainingParams(
                        seed: result.nextSeed,
                        state: result.snapshot,
                        focus: result.snapshot.school?.strength ?? .command,
                        intensity: strongGames ? .intensive : .light
                    )
                )
            case .relationship:
                result = try engine.resolveRelationship(
                    ResolveCareerRelationshipParams(
                        seed: result.nextSeed,
                        state: result.snapshot,
                        response: strongGames ? .listen : .challenge
                    )
                )
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(
                    RecordCareerGameParams(
                        seed: result.nextSeed,
                        state: result.snapshot,
                        report: ImportantInningReport(
                            scenarioNumber: number,
                            pitches: 18,
                            strikeouts: strongGames ? 4 : 0,
                            walks: strongGames ? 0 : 5,
                            runsAllowed: strongGames ? 0 : 7,
                            expectedDamage: strongGames ? 380 : 1_200,
                            actualDamage: strongGames ? 120 : 4_500,
                            recommendationAccepted: strongGames ? 10 : 0
                        )
                    )
                )
            case .awakening:
                result = try engine.chooseAwakening(
                    ChooseCareerAwakeningParams(
                        seed: result.nextSeed,
                        state: result.snapshot,
                        awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                    )
                )
            case .chapterReview:
                result = try engine.advanceChapter(
                    AdvanceCareerChapterParams(seed: result.nextSeed, state: result.snapshot)
                )
            case .draft:
                return try engine.resolveDraft(
                    ResolveDraftParams(seed: result.nextSeed, state: result.snapshot)
                )
            case .legacy, .completed:
                return result
            case .prologue, .schoolSelection:
                XCTFail("School should already be selected")
                return result
            }
        }
        XCTFail("Career did not finish within the expected number of decisions")
        return result
    }

    private func reachFirstRelationship(_ engine: HighSchoolCareerEngine, schoolID: SchoolID) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: "808", presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: schoolID))
        for _ in 0..<2 {
            result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .velocity, intensity: .standard))
        }
        return result
    }

    private func reachFirstAwakening(_ engine: HighSchoolCareerEngine, focus: TrainingFocus) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: "1212", presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
        for _ in 0..<30 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: focus, intensity: .standard))
            case .relationship:
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .challenge))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: number, pitches: 16, strikeouts: 3, walks: 0, runsAllowed: 0, expectedDamage: 400, actualDamage: 180, recommendationAccepted: 10)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .awakening: return result
            default: break
            }
        }
        XCTFail("각성 단계에 도달하지 못했습니다.")
        return result
    }
}
