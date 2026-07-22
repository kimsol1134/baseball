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

    func testSchoolOffersStayInThePlayersSelectedRegion() throws {
        let engine = HighSchoolCareerEngine()
        let incheon = try engine.start(
            StartHighSchoolCareerParams(
                seed: "20260724",
                presetID: "power_prospect",
                identity: PlayerIdentitySnapshot(name: "민서준", throwingHand: .right, bodyType: .balanced, region: "인천")
            )
        )
        let busan = try engine.start(
            StartHighSchoolCareerParams(
                seed: "20260724",
                presetID: "power_prospect",
                identity: PlayerIdentitySnapshot(name: "민서준", throwingHand: .right, bodyType: .balanced, region: "부산")
            )
        )

        XCTAssertEqual(incheon.snapshot.schoolOptions.map(\.name), ["인천제문포고", "인천동림고", "인천항성고", "인천송해고"])
        XCTAssertTrue(incheon.snapshot.schoolOptions.allSatisfy { $0.name.hasPrefix("인천") })
        XCTAssertNotEqual(incheon.snapshot.schoolOptions.map(\.name), busan.snapshot.schoolOptions.map(\.name))
    }

    func testFictionalCharacterProfilesCarryPersonalityRecordsAndDistinctRatings() throws {
        let schools = HighSchoolCareerEngine.schools(for: "인천")
        XCTAssertTrue(schools.allSatisfy {
            !($0.coachPersonality ?? "").isEmpty && !($0.coachRecord ?? "").isEmpty
                && !($0.catcherPersonality ?? "").isEmpty && !($0.catcherRecord ?? "").isEmpty
        })
        XCTAssertEqual(Set(schools.map(\.coachName)).count, 4)
        XCTAssertEqual(Set(schools.map(\.catcherName)).count, 4)
        let youthStaffRecords = schools.flatMap { [$0.coachRecord, $0.catcherRecord].compactMap { $0 } }
        XCTAssertFalse(youthStaffRecords.contains { $0.contains("통산") || $0.contains("한국시리즈") })
        XCTAssertTrue(schools.compactMap(\.catcherRecord).allSatisfy { $0.contains("중학") })

        XCTAssertTrue(HighSchoolCareerEngine.teams.allSatisfy {
            !($0.competitorProfile ?? "").isEmpty && !($0.competitorRecord ?? "").isEmpty
                && !($0.coachProfile ?? "").isEmpty && !($0.coachRecord ?? "").isEmpty
        })
        let proRecords = HighSchoolCareerEngine.teams.flatMap {
            [$0.competitorRecord, $0.coachRecord].compactMap { $0 }
        }
        XCTAssertFalse(proRecords.contains { $0.contains("통산") || $0.contains("한국시리즈") })

        let rivals = try (1...64).map { seed in
            try HighSchoolCareerEngine().start(.init(seed: String(seed), presetID: "power_prospect")).snapshot.rival
        }
        XCTAssertEqual(Set(rivals.map(\.name)).count, 8)
        XCTAssertTrue(rivals.allSatisfy { !($0.personality ?? "").isEmpty && !($0.signatureRecord ?? "").isEmpty })
        XCTAssertFalse(rivals.compactMap(\.signatureRecord).contains { $0.contains("통산") || $0.contains("한국시리즈") })
        XCTAssertGreaterThan(Set(rivals.map { "\($0.contact)-\($0.discipline)-\($0.power)" }).count, 4)
        let ratings = rivals.flatMap { [$0.contact, $0.discipline, $0.power] }
        XCTAssertLessThanOrEqual(ratings.max() ?? 0, 76)
        XCTAssertGreaterThanOrEqual(ratings.min() ?? 0, 50)
        XCTAssertLessThan(Double(ratings.reduce(0, +)) / Double(ratings.count), 68)

        let hardestRivals = try (1...64).map { seed in
            try HighSchoolCareerEngine().start(.init(
                seed: String(seed),
                presetID: "power_prospect",
                difficulty: .init(simulationDifficulty: .challenging),
                karmas: [.geniusGeneration]
            )).snapshot.rival
        }
        XCTAssertTrue(hardestRivals.allSatisfy {
            [$0.contact, $0.discipline, $0.power].filter { $0 == 80 }.count <= 1
        })
    }

    func testNormalizationBackfillsProfilesForOlderCareerSaves() throws {
        let engine = HighSchoolCareerEngine()
        let started = try engine.start(.init(seed: "20260725", presetID: "power_prospect"))
        let encoded = try JSONEncoder().encode(started.snapshot)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var schoolOptions = try XCTUnwrap(legacyObject["schoolOptions"] as? [[String: Any]])
        for index in schoolOptions.indices {
            schoolOptions[index].removeValue(forKey: "coachPersonality")
            schoolOptions[index].removeValue(forKey: "coachRecord")
            schoolOptions[index].removeValue(forKey: "catcherPersonality")
            schoolOptions[index].removeValue(forKey: "catcherRecord")
        }
        legacyObject["schoolOptions"] = schoolOptions
        var rival = try XCTUnwrap(legacyObject["rival"] as? [String: Any])
        rival.removeValue(forKey: "personality")
        rival.removeValue(forKey: "signatureRecord")
        legacyObject["rival"] = rival
        legacyObject.removeValue(forKey: "managerTrust")
        legacyObject.removeValue(forKey: "catcherTrust")
        legacyObject.removeValue(forKey: "rivalTrust")
        legacyObject.removeValue(forKey: "balanceVersion")
        let legacyPower = try XCTUnwrap(PitcherPresetCatalog.balanceV1.first { $0.id == "power_prospect" })
        legacyObject["pitcher"] = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(legacyPower.pitcher)) as? [String: Any]
        )
        legacyObject["stateCommitment"] = ""
        let unsignedLegacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let unsignedLegacy = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: unsignedLegacyData)
        legacyObject["stateCommitment"] = legacyCommitment(for: unsignedLegacy)

        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacySnapshot = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: legacyData)
        let normalized = try engine.normalizeRegionalSchools(.init(seed: started.nextSeed, state: legacySnapshot)).snapshot

        XCTAssertTrue(normalized.schoolOptions.allSatisfy {
            !($0.coachPersonality ?? "").isEmpty && !($0.coachRecord ?? "").isEmpty
                && !($0.catcherPersonality ?? "").isEmpty && !($0.catcherRecord ?? "").isEmpty
        })
        XCTAssertFalse((normalized.rival.personality ?? "").isEmpty)
        XCTAssertFalse((normalized.rival.signatureRecord ?? "").isEmpty)
        XCTAssertEqual(normalized.managerTrust, started.snapshot.relationshipTrust)
        XCTAssertEqual(normalized.catcherTrust, started.snapshot.relationshipTrust)
        XCTAssertEqual(normalized.rivalTrust, started.snapshot.relationshipTrust)
        XCTAssertEqual(normalized.balanceVersion, PitcherPresetCatalog.balanceVersion)
        XCTAssertEqual(normalized.pitcher.stuff, 62)
        XCTAssertEqual(normalized.pitcher.profile(for: .fourSeam)?.velocityTenthsKPH, 1_430)

        let normalizedAgain = try engine.normalizeRegionalSchools(.init(seed: started.nextSeed, state: normalized))
        XCTAssertEqual(normalizedAgain.snapshot.pitcher, normalized.pitcher)
        XCTAssertEqual(normalized.relationshipTrust, started.snapshot.relationshipTrust)
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
        let coachName = try XCTUnwrap(result.snapshot.school?.coachName)

        result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
        let headline = try XCTUnwrap(result.snapshot.news.first)
        XCTAssertTrue(headline.contains("\(coachName) 감독"))
        XCTAssertTrue(headline.contains("감독이 본 문제"))
        XCTAssertFalse(headline.contains("listen"))
        XCTAssertFalse(headline.contains("이야기를 나눴습니다"))
    }

    func testTrainingResultRecordsTheExactBeforeAndAfterValues() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "2026072301", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
        let stuffBefore = result.snapshot.pitcher.stuff
        let fatigueBefore = result.snapshot.fatigue

        result = try engine.commitTraining(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            focus: .velocity,
            intensity: .standard
        ))

        let training = try XCTUnwrap(result.snapshot.lastTraining)
        XCTAssertEqual(training.metricBefore, stuffBefore)
        XCTAssertEqual(training.metricAfter, result.snapshot.pitcher.stuff)
        XCTAssertEqual(training.metricAfter! - training.metricBefore!, training.growth)
        XCTAssertEqual(training.fatigueBefore, fatigueBefore)
        XCTAssertEqual(training.fatigueAfter, result.snapshot.fatigue)
        XCTAssertEqual(training.fatigueAfter! - training.fatigueBefore!, training.fatigueChange)
        XCTAssertTrue(training.feedback.contains(training.growth > 0 ? "올랐습니다" : "오르지 않았습니다"))
    }

    func testRelationshipResponseDependsOnPersonnelInsteadOfAlwaysRewardingListening() throws {
        let engine = HighSchoolCareerEngine()
        let scene = try reachFirstRelationship(engine, schoolID: .haedongPower)

        let listened = try engine.resolveRelationship(.init(seed: scene.nextSeed, state: scene.snapshot, response: .listen))
        let challenged = try engine.resolveRelationship(.init(seed: scene.nextSeed, state: scene.snapshot, response: .challenge))

        XCTAssertGreaterThan(challenged.snapshot.relationshipTrust, listened.snapshot.relationshipTrust)
        XCTAssertGreaterThan(
            try XCTUnwrap(challenged.snapshot.managerTrust),
            try XCTUnwrap(listened.snapshot.managerTrust)
        )
        XCTAssertEqual(challenged.snapshot.catcherTrust, listened.snapshot.catcherTrust)
        XCTAssertGreaterThan(challenged.snapshot.fanInterest, listened.snapshot.fanInterest)
        XCTAssertGreaterThan(challenged.snapshot.fatigue, listened.snapshot.fatigue)
        XCTAssertTrue(challenged.snapshot.news.first?.contains("공개 불펜") == true)
        let relationshipResult = try XCTUnwrap(challenged.snapshot.lastRelationship)
        XCTAssertEqual(relationshipResult.category, "coach")
        XCTAssertEqual(relationshipResult.title, scene.snapshot.currentRelationshipEvent?.title)
        XCTAssertEqual(relationshipResult.response, .challenge)
        XCTAssertEqual(relationshipResult.trustBefore, scene.snapshot.managerTrust)
        XCTAssertEqual(relationshipResult.trustAfter, challenged.snapshot.managerTrust)
        XCTAssertEqual(relationshipResult.fatigueAfter, challenged.snapshot.fatigue)
        XCTAssertEqual(relationshipResult.fanInterestAfter, challenged.snapshot.fanInterest)
        XCTAssertFalse(relationshipResult.feedback.contains(relationshipResult.title))

        let encoded = try JSONEncoder().encode(challenged.snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var changedResult = try XCTUnwrap(object["lastRelationship"] as? [String: Any])
        changedResult["feedback"] = "변조된 대화 결과"
        object["lastRelationship"] = changedResult
        let changed = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertThrowsError(try engine.advanceChapter(.init(seed: challenged.nextSeed, state: changed)))
    }

    func testCoachCatcherAndRivalRelationshipsChangeOnlyTheirOwnTrust() throws {
        let engine = HighSchoolCareerEngine()
        var result = try reachFirstRelationship(engine, schoolID: .haedongPower)

        let coachBefore = result.snapshot
        result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .challenge))
        XCTAssertGreaterThan(try XCTUnwrap(result.snapshot.managerTrust), try XCTUnwrap(coachBefore.managerTrust))
        XCTAssertEqual(result.snapshot.catcherTrust, coachBefore.catcherTrust)
        XCTAssertEqual(result.snapshot.rivalTrust, coachBefore.rivalTrust)
        XCTAssertEqual(result.snapshot.relationshipTrust, relationshipAverage(result.snapshot))

        result = try reachRelationship("catcher", engine: engine, from: result)
        let catcherBefore = result.snapshot
        result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
        XCTAssertEqual(result.snapshot.managerTrust, catcherBefore.managerTrust)
        XCTAssertGreaterThan(try XCTUnwrap(result.snapshot.catcherTrust), try XCTUnwrap(catcherBefore.catcherTrust))
        XCTAssertEqual(result.snapshot.rivalTrust, catcherBefore.rivalTrust)
        XCTAssertEqual(result.snapshot.relationshipTrust, relationshipAverage(result.snapshot))

        result = try reachRelationship("rival", engine: engine, from: result)
        let rivalBefore = result.snapshot
        result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
        XCTAssertEqual(result.snapshot.managerTrust, rivalBefore.managerTrust)
        XCTAssertEqual(result.snapshot.catcherTrust, rivalBefore.catcherTrust)
        XCTAssertGreaterThan(try XCTUnwrap(result.snapshot.rivalTrust), try XCTUnwrap(rivalBefore.rivalTrust))
        XCTAssertEqual(result.snapshot.relationshipTrust, relationshipAverage(result.snapshot))
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

    private func reachRelationship(
        _ category: String,
        engine: HighSchoolCareerEngine,
        from initial: HighSchoolCareerResult
    ) throws -> HighSchoolCareerResult {
        var result = initial
        for _ in 0..<60 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: .command,
                    intensity: .standard
                ))
            case .relationship:
                if result.snapshot.currentRelationshipEvent?.category == category { return result }
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(scenarioNumber: number, pitches: 16, strikeouts: 3, walks: 0,
                        runsAllowed: 0, expectedDamage: 400, actualDamage: 180, recommendationAccepted: 10)
                ))
            case .awakening:
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            default:
                XCTFail("\(category) 관계 장면에 도달하기 전에 커리어가 끝났습니다.")
                return result
            }
        }
        XCTFail("\(category) 관계 장면에 도달하지 못했습니다.")
        return result
    }

    private func relationshipAverage(_ state: HighSchoolCareerSnapshot) -> Int {
        ((state.managerTrust ?? state.relationshipTrust)
            + (state.catcherTrust ?? state.relationshipTrust)
            + (state.rivalTrust ?? state.relationshipTrust)) / 3
    }

    private func legacyCommitment(for state: HighSchoolCareerSnapshot) -> String {
        let school = state.school?.id.rawValue ?? "none"
        let ratings = "\(state.pitcher.stuff):\(state.pitcher.command):\(state.pitcher.movement):\(state.pitcher.stamina)"
        let performance = "\(state.performance.importantGamesCompleted):\(state.performance.pitches):\(state.performance.strikeouts):\(state.performance.walks):\(state.performance.runsAllowed):\(state.performance.expectedDamage):\(state.performance.actualDamage)"
        let scenario = state.currentGameScenario?.id ?? "none"
        let draft = state.draftResult.map { "\($0.outcome.rawValue):\($0.evaluationScore):\($0.team?.id ?? "none")" } ?? "none"
        var canonical = [state.careerID, String(state.revision), state.phase.rawValue,
            state.identity.name, state.identity.throwingHand.rawValue, state.identity.bodyType.rawValue, state.identity.region, school,
            state.difficulty.careerHarshness.rawValue, state.difficulty.informationClarity.rawValue,
            state.difficulty.simulationDifficulty.rawValue, state.difficulty.interventionAssist.rawValue,
            state.karmas.map(\.rawValue).joined(separator: ","), String(state.legacyRewardPermille), String(state.memorySlots)]
        canonical += [
            String(state.chapter.number), String(state.chapterTrainingCount), String(state.totalTrainingsCompleted),
            String(state.milestoneIndex), String(state.relationshipsCompleted), String(state.relationshipTrust),
            state.selectedAwakenings.map(\.rawValue).joined(separator: ","), state.awakeningOptions.map(\.rawValue).joined(separator: ","),
            String(state.fatigue), ratings, performance, scenario, draft, state.legacyOptions.map(\.rawValue).joined(separator: ","),
            state.selectedMemories.map(\.rawValue).joined(separator: ",")]
        return StableHash.fnv1a64(canonical.joined(separator: "|"))
    }
}
