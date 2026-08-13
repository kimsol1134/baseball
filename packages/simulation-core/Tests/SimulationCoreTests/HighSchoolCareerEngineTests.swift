import Foundation
import XCTest
@testable import SimulationCore

final class HighSchoolCareerEngineTests: XCTestCase {
    func testAppearanceSeedIsStablePerLifeAndOldIdentityFallsBackToName() throws {
        let first = PlayerAppearanceSeed.make(careerSeed: "424242", lifeNumber: 3)
        XCTAssertEqual(first, PlayerAppearanceSeed.make(careerSeed: "424242", lifeNumber: 3))
        XCTAssertNotEqual(first, PlayerAppearanceSeed.make(careerSeed: "424242", lifeNumber: 4))
        XCTAssertNotEqual(first, PlayerAppearanceSeed.make(careerSeed: "424243", lifeNumber: 3))

        let identity = PlayerIdentitySnapshot(
            name: "김하늘",
            throwingHand: .left,
            bodyType: .balanced,
            region: "광주",
            appearanceSeed: first
        )
        XCTAssertEqual(identity.portraitSeed, first)
        XCTAssertEqual(try JSONDecoder().decode(
            PlayerIdentitySnapshot.self,
            from: JSONEncoder().encode(identity)
        ), identity)

        let oldJSON = Data(#"{"name":"김하늘","throwingHand":"left","bodyType":"balanced","region":"광주"}"#.utf8)
        let restored = try JSONDecoder().decode(PlayerIdentitySnapshot.self, from: oldJSON)
        XCTAssertNil(restored.appearanceSeed)
        XCTAssertEqual(restored.portraitSeed, "김하늘")
    }

    func testVerticalSliceContentMinimumsUseStableUniqueIDs() {
        XCTAssertEqual(HighSchoolContentCatalog.events.count, 36)
        XCTAssertEqual(Set(HighSchoolContentCatalog.events.map(\.id)).count, 36)
        XCTAssertEqual(HighSchoolContentCatalog.scenarios.count, 30)
        XCTAssertEqual(Set(HighSchoolContentCatalog.scenarios.map(\.id)).count, 30)
        XCTAssertEqual(AwakeningID.allCases.count, 18)
        XCTAssertEqual(MemoryCardID.allCases.count, 18)
    }

    func testSequenceMasteryRewardsManagerAndCatcherTrustWithThreePointCap() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "332211", presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)
        ))

        for _ in 0..<60 where result.snapshot.phase != .importantGame {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: result.snapshot.school?.strength ?? .command,
                    intensity: .light
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    response: .listen
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
                break
            }
        }

        XCTAssertEqual(result.snapshot.phase, .importantGame)
        let before = result.snapshot
        let number = before.performance.importantGamesCompleted + 1
        let report = ImportantInningReport(
            scenarioNumber: number,
            pitches: 15,
            strikeouts: 3,
            walks: 1,
            runsAllowed: 0,
            expectedDamage: 400,
            actualDamage: 250,
            recommendationAccepted: 8,
            sequenceMasteryCount: 99
        )
        let settled = try engine.recordImportantGame(.init(
            seed: result.nextSeed,
            state: before,
            report: report
        )).snapshot

        let managerBefore = before.managerTrust ?? before.relationshipTrust
        let catcherBefore = before.catcherTrust ?? before.relationshipTrust
        XCTAssertEqual(settled.managerTrust, min(100, managerBefore + 3))
        XCTAssertEqual(settled.catcherTrust, min(100, catcherBefore + 3))
        XCTAssertEqual(settled.rivalTrust, before.rivalTrust)
        XCTAssertTrue(settled.news.contains { $0.contains("수싸움 적중 99회") && $0.contains("+3") })
    }

    /// 야구혼 계승은 회차당 상한까지만 스며들고, 이번 회차의 재능 벽을 넘지 않는다.
    ///
    /// 예전에는 누적 야구혼 전액이 한 능력(분야 미선택이면 제구)에 들어가 첫 환생 한 번에
    /// 제구가 80에 닿았고, 2회차와 30회차의 시작 선수가 완전히 같아졌다 — 환생 루프가
    /// 한 번 돌고 수학적으로 멈추는 구조였다.
    func testSoulInheritanceCapsSpreadsAndRespectsTalentWalls() throws {
        let engine = HighSchoolCareerEngine()
        let base = try engine.start(.init(seed: "20260728", presetID: "power_prospect", lifeNumber: 2))
        let inherited = try engine.start(
            .init(seed: "20260728", presetID: "power_prospect", lifeNumber: 2, inheritedSoulPoints: 600)
        )

        func total(_ pitcher: PitcherSnapshot) -> Int {
            pitcher.stuff + pitcher.command + pitcher.movement + pitcher.stamina
        }
        let gain = total(inherited.snapshot.pitcher) - total(base.snapshot.pitcher)
        XCTAssertGreaterThan(gain, 0)
        XCTAssertLessThanOrEqual(gain, 20)

        // 한 능력 몰빵 금지: 야구혼 600으로도 제구가 혼자 80으로 튀지 않는다.
        XCTAssertLessThan(inherited.snapshot.pitcher.command, 80)

        // 재능 벽 존중: 계승이 벽을 넘으면 그 능력의 만개가 영원히 사라진다.
        let talent = try XCTUnwrap(inherited.snapshot.talent)
        let pitcher = inherited.snapshot.pitcher
        XCTAssertLessThanOrEqual(pitcher.stuff, min(80, talent.ceiling(.stuff)))
        XCTAssertLessThanOrEqual(pitcher.command, min(80, talent.ceiling(.command)))
        XCTAssertLessThanOrEqual(pitcher.movement, min(80, talent.ceiling(.movement)))
        XCTAssertLessThanOrEqual(pitcher.stamina, min(80, talent.ceiling(.stamina)))

        // 총량이 쌓이면 스며드는 상한도 천천히 자라고(8→20), 그 뒤로는 멈춘다.
        XCTAssertEqual(HighSchoolCareerEngine.inheritancePointCap(for: 48), 8)
        XCTAssertEqual(HighSchoolCareerEngine.inheritancePointCap(for: 300), 13)
        XCTAssertEqual(HighSchoolCareerEngine.inheritancePointCap(for: 100_000), 20)
    }

    /// 지역 목록은 학교 이름 사전과 정확히 일치해야 하고, 76개 이름은 전부 달라야 한다.
    /// 이 목록이 iOS 지역 선택 화면의 데이터 소스다.
    func testRegionListCoversEveryRegionalSchoolName() {
        XCTAssertEqual(HighSchoolCareerEngine.regions.count, 19)
        XCTAssertEqual(Set(HighSchoolCareerEngine.regions).count, 19)
        let allNames = HighSchoolCareerEngine.regions.flatMap { HighSchoolCareerEngine.schools(for: $0).map(\.name) }
        XCTAssertEqual(allNames.count, 76)
        XCTAssertEqual(Set(allNames).count, 76, "지역별 학교 이름이 겹칩니다.")
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

        XCTAssertEqual(incheon.snapshot.schoolOptions.map(\.name), ["인천해문결고", "인천동림고", "인천항성고", "인천송해고"])
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
        // 회차 바람이 라이벌을 ±5까지 움직인다(괴물 세대 +5 · 무명의 해 −3).
        XCTAssertLessThanOrEqual(ratings.max() ?? 0, 55)
        XCTAssertGreaterThanOrEqual(ratings.min() ?? 0, 34)
        XCTAssertLessThan(Double(ratings.reduce(0, +)) / Double(ratings.count), 47)

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
        legacyObject.removeValue(forKey: "armRisk")
        legacyObject.removeValue(forKey: "injuryRecovery")
        legacyObject.removeValue(forKey: "schedule")
        legacyObject.removeValue(forKey: "worldRulesVersion")
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
        XCTAssertEqual(normalized.balanceVersion, 3)
        XCTAssertEqual(normalized.pitcher.stuff, 42)
        XCTAssertEqual(normalized.pitcher.profile(for: .fourSeam)?.velocityTenthsKPH, 1_410)

        let normalizedAgain = try engine.normalizeRegionalSchools(.init(seed: started.nextSeed, state: normalized))
        XCTAssertEqual(normalizedAgain.snapshot.pitcher, normalized.pitcher)
        XCTAssertEqual(normalized.relationshipTrust, started.snapshot.relationshipTrust)
    }

    func testV2BalanceMigrationPreservesEveryEarnedPoint() throws {
        let v2 = try XCTUnwrap(PitcherPresetCatalog.balanceV2.first { $0.id == "power_prospect" }?.pitcher)
        let earnedProfiles = v2.pitchProfiles?.map { profile in
            PitchProfileSnapshot(
                pitchType: profile.pitchType, role: profile.role,
                velocityTenthsKPH: profile.velocityTenthsKPH + (profile.pitchType == .fourSeam ? 20 : 0),
                control: profile.control, command: profile.command, movement: profile.movement,
                whiff: profile.whiff, weakContact: profile.weakContact, fatigueCost: profile.fatigueCost
            )
        }
        let earned = PitcherSnapshot(
            id: v2.id, name: "이어 하는 선수", stuff: v2.stuff + 5, command: v2.command + 2,
            movement: v2.movement + 1, stamina: v2.stamina + 3, pitchProfiles: earnedProfiles
        )

        XCTAssertEqual(PitcherPresetCatalog.inferredLegacyVersion(for: earned), 2)
        let migrated = try XCTUnwrap(PitcherPresetCatalog.migrate(earned, fromVersion: 2)?.pitcher)
        let v3 = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "power_prospect" }?.pitcher)
        XCTAssertEqual(migrated.name, "이어 하는 선수")
        XCTAssertEqual(migrated.stuff, v3.stuff + 5)
        XCTAssertEqual(migrated.command, v3.command + 2)
        XCTAssertEqual(migrated.movement, v3.movement + 1)
        XCTAssertEqual(migrated.stamina, v3.stamina + 3)
        XCTAssertEqual(migrated.profile(for: .fourSeam)?.velocityTenthsKPH,
            try XCTUnwrap(v3.profile(for: .fourSeam)?.velocityTenthsKPH) + 20)
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
        XCTAssertEqual(
            cursed.snapshot.legacyRewardPermille,
            1_500 + CareerWind.wind(careerID: cursed.snapshot.careerID, rulesVersion: .v2).rewardBonusPermille
        )
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

        // 지명된 회차는 아직 끝나지 않았다. 프로 커리어가 남아 있으므로 완료 화면에서 멈추고,
        // 기억은 "이 회차를 접겠다"고 결정할 때(`openLegacy`) 고른다. 성공한 순간에 유언을
        // 받는 것처럼 보이던 흐름을 바로잡은 것이다.
        XCTAssertEqual(result.snapshot.phase, .completed)
        XCTAssertEqual(result.snapshot.draftResult?.outcome, .drafted)
        XCTAssertFalse(result.snapshot.legacyOptions.isEmpty, "접을 때 고를 기억은 이미 준비돼 있어야 한다")
        result = try engine.openLegacy(.init(seed: result.nextSeed, state: result.snapshot))
        XCTAssertEqual(result.snapshot.phase, .legacy)
        result = try engine.selectLegacy(
            SelectCareerLegacyParams(
                seed: result.nextSeed,
                state: result.snapshot,
                memoryCards: Array(result.snapshot.legacyOptions.prefix(result.snapshot.memorySlots))
            )
        )

        XCTAssertEqual(result.snapshot.phase, .completed)
        XCTAssertEqual(result.snapshot.chapter.number, 8)
        // 뼈대가 시드별로 가변(훈련 12–16 / 관계 4–6 / 경기 4–6 / 각성 3)이므로, 완주한 카운트는
        // 이 회차의 스케줄 총량과 정확히 일치해야 한다.
        let schedule = try XCTUnwrap(result.snapshot.schedule)
        XCTAssertEqual(result.snapshot.totalTrainingsCompleted, schedule.trainingTotal)
        XCTAssertEqual(result.snapshot.relationshipsCompleted, schedule.relationshipTotal)
        XCTAssertEqual(result.snapshot.performance.importantGamesCompleted, schedule.importantGameTotal)
        XCTAssertTrue((12...16).contains(schedule.trainingTotal))
        XCTAssertTrue((4...6).contains(schedule.relationshipTotal))
        XCTAssertTrue((4...6).contains(schedule.importantGameTotal))
        XCTAssertEqual(result.snapshot.selectedAwakenings.count, 3)
        XCTAssertEqual(result.snapshot.selectedMemories.count, result.snapshot.memorySlots)
        XCTAssertEqual(result.snapshot.draftResult?.outcome, .drafted)
        XCTAssertNotNil(result.snapshot.draftResult?.team)
        XCTAssertNotNil(result.snapshot.draftResult?.firstSeasonGoal)
    }

    /// 첫 선수의 첫 정상 훈련은 분산 때문에 0이 되지 않아야 한다. 이후의 보상 폭은
    /// 그대로 두어, 첫 버튼에서만 게임의 성장 약속을 보장한다.
    func testFirstLifeFirstNonRehabTrainingAlwaysGrows() throws {
        let engine = HighSchoolCareerEngine()
        for seed in ["1", "17", "20260723", "44771", "8675309"] {
            var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
            result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseSchool(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)
            ))
            let focus = result.snapshot.school?.strength ?? .command
            let trained = try engine.commitTraining(.init(
                seed: result.nextSeed, state: result.snapshot,
                focus: focus, intensity: .light
            ))

            XCTAssertEqual(trained.snapshot.lastTraining?.number, 1, seed)
            XCTAssertNotEqual(trained.snapshot.lastTraining?.focus, .recovery, seed)
            XCTAssertGreaterThanOrEqual(
                trained.snapshot.lastTraining?.growth ?? 0, 1,
                "첫 회차 첫 정상 훈련은 최소 1 성장이어야 합니다: seed=\(seed)"
            )
        }
    }

    /// 첫 훈련의 보장은 첫 선수의 첫 버튼에만 적용된다. 두 번째 훈련과 다음 회차에는
    /// 0 성장도 남아 있어야 훈련 강도·재능·시드가 실제 선택으로 느껴진다.
    func testSecondTrainingAndNextLifeMayHaveZeroGrowth() throws {
        let engine = HighSchoolCareerEngine()
        var sawSecondTrainingZero = false
        var sawNextLifeZero = false

        for seedNumber in 1...500 where !sawSecondTrainingZero || !sawNextLifeZero {
            let seed = String(seedNumber)
            var first = try engine.start(.init(seed: seed, presetID: "power_prospect"))
            first = try engine.completePrologue(.init(seed: first.nextSeed, state: first.snapshot))
            first = try engine.chooseSchool(.init(
                seed: first.nextSeed,
                state: first.snapshot,
                schoolID: try XCTUnwrap(first.snapshot.schoolOptions.first?.id)
            ))
            let focus = first.snapshot.school?.strength ?? .command

            if first.snapshot.schedule?.trainingsByChapter.first ?? 0 >= 2 {
                let firstTraining = try engine.commitTraining(.init(
                    seed: first.nextSeed, state: first.snapshot,
                    focus: focus, intensity: .light
                ))
                if firstTraining.snapshot.phase == .training {
                    let secondTraining = try engine.commitTraining(.init(
                        seed: firstTraining.nextSeed, state: firstTraining.snapshot,
                        focus: focus, intensity: .light
                    ))
                    sawSecondTrainingZero = sawSecondTrainingZero
                        || secondTraining.snapshot.lastTraining?.growth == 0
                }
            }

            var nextLife = try engine.start(.init(
                seed: seed, presetID: "power_prospect", lifeNumber: 2
            ))
            nextLife = try engine.completePrologue(.init(
                seed: nextLife.nextSeed, state: nextLife.snapshot
            ))
            nextLife = try engine.chooseSchool(.init(
                seed: nextLife.nextSeed,
                state: nextLife.snapshot,
                schoolID: try XCTUnwrap(nextLife.snapshot.schoolOptions.first?.id)
            ))
            let nextTraining = try engine.commitTraining(.init(
                seed: nextLife.nextSeed, state: nextLife.snapshot,
                focus: nextLife.snapshot.school?.strength ?? .command,
                intensity: .light
            ))
            sawNextLifeZero = sawNextLifeZero || nextTraining.snapshot.lastTraining?.growth == 0
        }

        XCTAssertTrue(sawSecondTrainingZero, "두 번째 훈련에도 0 성장이 가능한 시드가 있어야 합니다")
        XCTAssertTrue(sawNextLifeZero, "다음 회차 첫 훈련에는 0 성장이 가능한 시드가 있어야 합니다")
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

    func testRelationshipSlotsExposeNonCoreCategoriesInOneRun() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "20260723", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))

        var categories: [String] = []
        for _ in 0..<80 {
            switch result.snapshot.phase {
            case .relationship:
                categories.append(try XCTUnwrap(result.snapshot.currentRelationshipEvent?.category))
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
            case .training:
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: result.snapshot.school?.strength ?? .command, intensity: .light))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: number, pitches: 18, strikeouts: 4, walks: 0, runsAllowed: 0, expectedDamage: 380, actualDamage: 120, recommendationAccepted: 10)))
            case .awakening:
                result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            default:
                break
            }
            if [.draft, .legacy, .completed].contains(result.snapshot.phase) { break }
        }

        // 관계 슬롯 수는 이 회차의 가변 스케줄(4–6)을 따른다.
        let relationshipTotal = try XCTUnwrap(result.snapshot.schedule).relationshipTotal
        XCTAssertEqual(categories.count, relationshipTotal)
        // 핵심 3인은 매 회차 처음 세 슬롯에서 반드시 만난다. **순서는 회차마다 섞이므로**
        // 집합으로 확인한다 — 순서가 고정이면 회차를 반복할수록 첫 세 장면이 똑같이 지나간다.
        XCTAssertEqual(Set(categories.prefix(3)), ["coach", "catcher", "rival"])
        let core: Set<String> = ["coach", "catcher", "rival"]
        let extended = categories.filter { !core.contains($0) }
        XCTAssertFalse(extended.isEmpty, "later slots must surface non-core event categories")
        XCTAssertEqual(Set(extended).count, extended.count, "extended slots must draw distinct categories")
        XCTAssertEqual(Set(categories).count, relationshipTotal, "a single run should span one distinct category per relationship slot")
    }

    /// 2회차부터는 회차 자각(환생) 사건을 한 회차에 최소 한 번 반드시 만난다.
    ///
    /// 슬롯마다 1/3 확률만 걸었을 때는 2회차의 절반 가까이가 환생 사건을 한 번도 못 만났다.
    /// 회차 자각은 2회차의 간판이라 "가끔 나오는 보너스"가 아니라 "반드시 오는 장면"이어야 한다.
    /// 같은 회차 안에서 중요 경기 시나리오가 반복되지 않는 것도 여기서 함께 지킨다.
    func testSecondLifeAlwaysMeetsARebirthEventAndScenariosNeverRepeat() throws {
        let rebirthIDs = Set(HighSchoolContentCatalog.rebirthEvents.map(\.id))
        for seed in ["11", "22", "33", "44", "55", "66", "77", "88", "99", "110"] {
            let engine = HighSchoolCareerEngine()
            var result = try engine.start(.init(seed: seed, presetID: "power_prospect", lifeNumber: 2))
            result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))

            var sawRebirth = false
            var scenarioIDs: [String] = []
            for _ in 0..<80 {
                if result.snapshot.phase == .relationship,
                   let event = result.snapshot.currentRelationshipEvent, rebirthIDs.contains(event.id) {
                    sawRebirth = true
                }
                if result.snapshot.phase == .importantGame,
                   let scenario = result.snapshot.currentGameScenario {
                    scenarioIDs.append(scenario.id)
                }
                result = try advanceOneStep(engine, result)
                if [.draft, .legacy, .completed].contains(result.snapshot.phase) { break }
            }
            XCTAssertTrue(sawRebirth, "seed \(seed): 2회차가 환생 사건을 한 번도 만나지 못했습니다.")
            XCTAssertEqual(Set(scenarioIDs).count, scenarioIDs.count,
                           "seed \(seed): 같은 회차 안에서 중요 경기 시나리오가 반복됐습니다.")
        }
    }

    func testEveryImportantGameScenarioIsWellFormed() {
        // 신규 8종을 포함한 20종 시나리오 전부가 경기 상황으로 성립하는지 검증한다. 이닝 1–10,
        // 아웃 0–2, 레버리지 1–1000, 리드 주자 스피드 범위, 제목·서사 비어 있지 않음, id 고유.
        let scenarios = HighSchoolContentCatalog.scenarios
        XCTAssertEqual(scenarios.count, 30)
        XCTAssertEqual(Set(scenarios.map(\.id)).count, 30, "scenario ids must be unique")
        // (이닝, 아웃, 주자 배치) 조합도 서로 겹치지 않아 30종이 실제로 다른 상황을 만든다.
        let situations = scenarios.map { "\($0.inning)-\($0.outs)-\($0.runners.firstOccupied)-\($0.runners.secondOccupied)-\($0.runners.thirdOccupied)" }
        XCTAssertEqual(Set(situations).count, 30, "each scenario must be a distinct (inning, outs, runners) situation")
        for scenario in scenarios {
            XCTAssertTrue((1...10).contains(scenario.inning), "\(scenario.id): inning out of range")
            XCTAssertTrue((0...2).contains(scenario.outs), "\(scenario.id): outs out of range")
            XCTAssertTrue((1...1_000).contains(scenario.leverage), "\(scenario.id): leverage out of range")
            XCTAssertTrue((30...90).contains(scenario.runners.leadRunnerSpeed), "\(scenario.id): lead runner speed out of range")
            XCTAssertFalse(scenario.title.isEmpty, "\(scenario.id): empty title")
            XCTAssertFalse(scenario.narrative.isEmpty, "\(scenario.id): empty narrative")
        }
    }

    func testCareerImportantGamesDrawDistinctScenariosFromExpandedPool() throws {
        // 한 커리어의 중요 경기들이 서로 다른 시나리오를 쓰는지 확인한다. 경기 수는 시드에
        // 따라 다르고(런 뼈대 가변화, HighSchoolCareer 소유) 각 경기는 nextSeed 체인의 서로
        // 다른 시드로 시나리오를 고르므로, 20종으로 넓힌 풀에서 한 커리어가 중복 없이 전 경기를
        // 다른 장면으로 만나는 것이 가능함을 대표 시드들로 검증한다. 아울러 모든 커리어가 카탈로그
        // 안의 시나리오만 쓰고 신설 8종이 실제로 도달 가능한지 확인한다.
        let engine = HighSchoolCareerEngine()
        let catalogIDs = Set(HighSchoolContentCatalog.scenarios.map(\.id))
        let newScenarioIDs: Set<String> = ["game-walkoff-defense", "game-extra-tiebreak", "game-ace-duel",
            "game-damage-control", "game-rain-grip", "game-doubleheader", "game-scout-showcase", "game-rival-away"]
        var sawFullyDistinctCareer = false
        var scenariosSeenAcrossSample: Set<String> = []
        for seed in 1...16 {
            var result = try engine.start(.init(seed: String(seed), presetID: "power_prospect"))
            result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
            var scenarioIDs: [String] = []
            for _ in 0..<120 {
                switch result.snapshot.phase {
                case .relationship:
                    result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
                case .training:
                    result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: result.snapshot.school?.strength ?? .command, intensity: .light))
                case .importantGame:
                    scenarioIDs.append(try XCTUnwrap(result.snapshot.currentGameScenario?.id))
                    let number = result.snapshot.performance.importantGamesCompleted + 1
                    result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                        report: .init(scenarioNumber: number, pitches: 18, strikeouts: 4, walks: 0, runsAllowed: 0, expectedDamage: 380, actualDamage: 120, recommendationAccepted: 10)))
                case .awakening:
                    result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
                case .chapterReview:
                    result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
                default: break
                }
                if [.draft, .legacy, .completed].contains(result.snapshot.phase) { break }
            }
            XCTAssertGreaterThanOrEqual(scenarioIDs.count, 3, "seed \(seed): a career should surface several important games")
            XCTAssertTrue(scenarioIDs.allSatisfy { catalogIDs.contains($0) }, "seed \(seed): every scenario must come from the catalog: \(scenarioIDs)")
            scenariosSeenAcrossSample.formUnion(scenarioIDs)
            if Set(scenarioIDs).count == scenarioIDs.count { sawFullyDistinctCareer = true }
        }
        // 20종으로 넓힌 풀에서 한 커리어의 전 중요 경기가 서로 다른 장면인 경우가 실제로 존재해야 한다.
        XCTAssertTrue(sawFullyDistinctCareer, "expanding to 20 scenarios should let a career surface fully distinct important games")
        // 표본 전체가 풀을 넓게 사용하고, 신설 8종도 실제로 도달 가능해야 한다.
        XCTAssertGreaterThanOrEqual(scenariosSeenAcrossSample.count, 12, "the sample should exercise a wide slice of the 20-scenario pool: \(scenariosSeenAcrossSample.count)")
        XCTAssertFalse(scenariosSeenAcrossSample.isDisjoint(with: newScenarioIDs), "the newly added scenarios must be reachable in play")
    }

    func testDraftedCareerBanksMemoriesForNextLife() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "20260723", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
        result = try completeCareer(engine, from: result, strongGames: true)

        XCTAssertEqual(result.snapshot.draftResult?.outcome, .drafted)
        // 지명은 회차의 끝이 아니다 — 완료 화면에서 멈춘다.
        XCTAssertEqual(result.snapshot.phase, .completed)
        XCTAssertEqual(result.snapshot.legacyOptions.count, 5)

        result = try engine.openLegacy(.init(seed: result.nextSeed, state: result.snapshot))
        let selected = try engine.selectLegacy(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            memoryCards: Array(result.snapshot.legacyOptions.prefix(result.snapshot.memorySlots))
        ))
        XCTAssertEqual(selected.snapshot.phase, .completed)
        XCTAssertEqual(selected.snapshot.selectedMemories.count, result.snapshot.memorySlots)
        // Pro unlock stays reachable: the run is still marked drafted after banking memories.
        XCTAssertEqual(selected.snapshot.draftResult?.outcome, .drafted)
        XCTAssertNotNil(selected.snapshot.draftResult?.team)
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
        // 가변 뼈대에서도 첫 관계 국면까지 진행한다(첫 슬롯은 항상 코어 '감독').
        var result = try reachFirstRelationship(engine, schoolID: .miraeAnalytics)
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
        XCTAssertTrue(training.feedback.contains("\(training.growth)"))
        XCTAssertFalse(training.feedback.contains("능력치가"))
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

    /// 각 인물과의 대화는 **자기 신뢰만** 움직인다.
    ///
    /// 핵심 3인이 나오는 **순서는 회차마다 섞이므로**, 특정 순서를 가정하지 않고 처음 세
    /// 관계 장면을 그대로 걸어가며 그때그때 확인한다. 예전에는 감독 → 포수 → 라이벌 순서를
    /// 가정해 하나씩 찾아갔는데, 순서를 섞자 이미 지나간 슬롯을 다시 찾다가 회차 끝에서 멈췄다.
    func testCoachCatcherAndRivalRelationshipsChangeOnlyTheirOwnTrust() throws {
        let engine = HighSchoolCareerEngine()
        var result = try reachFirstRelationship(engine, schoolID: .haedongPower)
        var seen: Set<String> = []

        for _ in 0..<80 {
            if result.snapshot.phase == .relationship,
               let category = result.snapshot.currentRelationshipEvent?.category,
               ["coach", "catcher", "rival"].contains(category) {
                let before = result.snapshot
                result = try engine.resolveRelationship(
                    .init(seed: result.nextSeed, state: result.snapshot, response: category == "coach" ? .challenge : .listen)
                )
                let after = result.snapshot
                switch category {
                case "coach":
                    XCTAssertGreaterThan(try XCTUnwrap(after.managerTrust), try XCTUnwrap(before.managerTrust))
                    XCTAssertEqual(after.catcherTrust, before.catcherTrust)
                    XCTAssertEqual(after.rivalTrust, before.rivalTrust)
                case "catcher":
                    XCTAssertGreaterThan(try XCTUnwrap(after.catcherTrust), try XCTUnwrap(before.catcherTrust))
                    XCTAssertEqual(after.managerTrust, before.managerTrust)
                    XCTAssertEqual(after.rivalTrust, before.rivalTrust)
                default:
                    XCTAssertGreaterThan(try XCTUnwrap(after.rivalTrust), try XCTUnwrap(before.rivalTrust))
                    XCTAssertEqual(after.managerTrust, before.managerTrust)
                    XCTAssertEqual(after.catcherTrust, before.catcherTrust)
                }
                XCTAssertEqual(after.relationshipTrust, relationshipAverage(after))
                seen.insert(category)
                if seen.count == 3 { return }
                continue
            }
            result = try advanceOneStep(engine, result)
            if [.draft, .legacy, .completed].contains(result.snapshot.phase) { break }
        }
        XCTFail("핵심 3인 관계 장면을 모두 만나지 못했습니다: \(seen.sorted())")
    }

    /// 관계 외의 국면을 한 칸 넘긴다. 순서를 가정하지 않는 테스트들이 함께 쓴다.
    private func advanceOneStep(
        _ engine: HighSchoolCareerEngine,
        _ result: HighSchoolCareerResult
    ) throws -> HighSchoolCareerResult {
        switch result.snapshot.phase {
        case .training:
            return try engine.commitTraining(
                .init(seed: result.nextSeed, state: result.snapshot, focus: .command, intensity: .standard)
            )
        case .relationship:
            return try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
        case .importantGame:
            let number = result.snapshot.performance.importantGamesCompleted + 1
            return try engine.recordImportantGame(.init(
                seed: result.nextSeed, state: result.snapshot,
                report: .init(scenarioNumber: number, pitches: 16, strikeouts: 3, walks: 0,
                              runsAllowed: 0, expectedDamage: 400, actualDamage: 180, recommendationAccepted: 10)
            ))
        case .awakening:
            return try engine.chooseAwakening(.init(
                seed: result.nextSeed, state: result.snapshot,
                awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
            ))
        case .chapterReview:
            return try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
        default:
            return result
        }
    }

    /// 피로가 낮으면 "오늘은 회복이 최고의 훈련이다"라고 말하지 않는다. 기회는 지금 몸이
    /// 하는 말이어야 하고, 몸과 무관한 조언은 화면의 모든 조언을 장식으로 만든다.
    func testRestIsNeverTheOpportunityWhileFresh() {
        for index in 0..<200 {
            let fresh = HighSchoolCareerEngine.trainingOpportunity(
                careerID: "rest-\(index)", index: index, fatigue: 5, injuryRecovery: 0
            )
            XCTAssertNotEqual(fresh.focus, .recovery, "피로 5인데 휴식이 기회로 나왔습니다(index \(index))")
        }
    }

    /// 반대로, 지쳤거나 재활 중이면 회복이 기회로 나올 수 있어야 한다 — 아예 못 나오면
    /// 회복 훈련이 기회 보너스를 영영 못 받는 반쪽 선택지가 된다.
    func testRestStillAppearsWhenTiredOrRehabbing() {
        let tired = (0..<200).contains {
            HighSchoolCareerEngine.trainingOpportunity(
                careerID: "rest-\($0)", index: $0, fatigue: 80, injuryRecovery: 0
            ).focus == .recovery
        }
        XCTAssertTrue(tired, "피로가 높은데도 휴식이 한 번도 기회로 나오지 않습니다")

        let rehabbing = (0..<200).contains {
            HighSchoolCareerEngine.trainingOpportunity(
                careerID: "rest-\($0)", index: $0, fatigue: 0, injuryRecovery: 2
            ).focus == .recovery
        }
        XCTAssertTrue(rehabbing, "재활 중인데도 휴식이 한 번도 기회로 나오지 않습니다")
    }

    /// 같은 입력이면 같은 기회. 게이트를 넣으면서 결정론이 깨지면 시드 공유가 무너진다.
    func testTrainingOpportunityStaysDeterministic() {
        for index in 0..<50 {
            let first = HighSchoolCareerEngine.trainingOpportunity(
                careerID: "seed-42", index: index, fatigue: 30, injuryRecovery: 0
            )
            let second = HighSchoolCareerEngine.trainingOpportunity(
                careerID: "seed-42", index: index, fatigue: 30, injuryRecovery: 0
            )
            XCTAssertEqual(first, second)
        }
    }

    func testAwakeningCandidatesFollowTrainingAndCreateARealTradeoff() throws {
        let engine = HighSchoolCareerEngine()
        let awakening = try reachFirstAwakening(engine, focus: .velocity)
        // 첫 각성에서는 네 갈래의 뿌리만 열려 있다 — 트리는 뿌리부터 내려간다.
        XCTAssertEqual(Set(awakening.snapshot.awakeningOptions), Set(
            AwakeningTree.nodes.filter { $0.parents.isEmpty }.map(\.id)
        ))
        let chosen = try XCTUnwrap(awakening.snapshot.awakeningOptions.first { $0 == .explosiveFastball })
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

    // MARK: - Draft outcome balance (Phase 1-4: "드래프트 실패 복원")

    // Synthetic canned-report playthroughs used only as a fast draft smoke test below.
    // These reports bypass PitchKernel and therefore are not evidence for the product balance
    // bands; the deterministic 1,000-run audit owns those measurements. `ordinary` spreads
    // training across six focuses, `focused` uses deliberately dominant reports, and `neglect`
    // uses deliberately poor reports.
    private enum DraftPlayPolicy { case focused, ordinary, neglect }

    private func runCareerToDraft(
        _ engine: HighSchoolCareerEngine,
        seed: String,
        policy: DraftPlayPolicy,
        difficulty: CareerDifficultySnapshot = .standard,
        presetID: String = "power_prospect",
        schoolID: SchoolID = .haedongPower
    ) throws -> DraftResultSnapshot {
        var result = try engine.start(.init(seed: seed, presetID: presetID, difficulty: difficulty))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: schoolID))
        for _ in 0..<160 {
            switch result.snapshot.phase {
            case .training:
                let focus: TrainingFocus
                let intensity: TrainingIntensity
                switch policy {
                case .focused:
                    focus = result.snapshot.school?.strength ?? .command
                    intensity = .intensive
                case .ordinary:
                    focus = TrainingFocus.allCases[result.snapshot.totalTrainingsCompleted % TrainingFocus.allCases.count]
                    intensity = .standard
                case .neglect:
                    focus = result.snapshot.school?.strength ?? .command
                    intensity = .light
                }
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: focus, intensity: intensity))
            case .relationship:
                let response: RelationshipResponse = policy == .neglect ? .challenge : .listen
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: response))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                let report: ImportantInningReport
                switch policy {
                case .focused:
                    report = .init(scenarioNumber: number, pitches: 18, strikeouts: 4, walks: 0, runsAllowed: 0, expectedDamage: 380, actualDamage: 120, recommendationAccepted: 10)
                case .ordinary:
                    report = .init(scenarioNumber: number, pitches: 18, strikeouts: 3, walks: 2, runsAllowed: 2, expectedDamage: 720, actualDamage: 700, recommendationAccepted: 6)
                case .neglect:
                    report = .init(scenarioNumber: number, pitches: 18, strikeouts: 0, walks: 5, runsAllowed: 7, expectedDamage: 1_200, actualDamage: 4_500, recommendationAccepted: 0)
                }
                result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
            case .awakening:
                result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft:
                result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
                return try XCTUnwrap(result.snapshot.draftResult)
            case .legacy, .completed:
                return try XCTUnwrap(result.snapshot.draftResult)
            case .prologue, .schoolSelection:
                XCTFail("school should already be selected for seed \(seed)")
                return try XCTUnwrap(result.snapshot.draftResult)
            }
        }
        XCTFail("career did not reach the draft for seed \(seed)")
        return try XCTUnwrap(result.snapshot.draftResult)
    }

    private func draftOutcomes(
        _ engine: HighSchoolCareerEngine,
        seeds: [String],
        policy: DraftPlayPolicy,
        difficulty: CareerDifficultySnapshot = .standard
    ) throws -> (rate: Double, drafted: Int, scores: [Int]) {
        var drafted = 0
        var scores: [Int] = []
        for seed in seeds {
            let draft = try runCareerToDraft(engine, seed: seed, policy: policy, difficulty: difficulty)
            scores.append(draft.evaluationScore)
            if draft.outcome == .drafted { drafted += 1 }
        }
        return (Double(drafted) / Double(seeds.count), drafted, scores)
    }

    private static let draftBalanceSeeds = (1...40).map(String.init)

    // This broad 40-seed check only catches catastrophic formula movement. It is intentionally
    // not named or asserted as the real-player acceptance band because its game lines are canned.
    func testCannedSpreadPolicyReachesDraftAndReportsBoundedScores() throws {
        let engine = HighSchoolCareerEngine()
        let seeds = Self.draftBalanceSeeds
        let (rate, drafted, scores) = try draftOutcomes(engine, seeds: seeds, policy: .ordinary)
        let sorted = scores.sorted()
        // V4 public thresholds are 59/63/67. The same synthetic score sample makes a compact
        // monotonicity diagnostic; exact threshold and weighted-variance contracts have separate
        // pure regression assertions.
        func rateAtOrAbove(_ threshold: Int) -> Int {
            Int((Double(scores.filter { $0 >= threshold }.count) / Double(scores.count) * 100).rounded())
        }
        print("[draft-balance] ordinary/standard rate=\(Int((rate * 100).rounded()))% (\(drafted)/\(seeds.count)) "
            + "score min=\(sorted.first ?? 0) p25=\(sorted[sorted.count / 4]) median=\(sorted[sorted.count / 2]) "
            + "p75=\(sorted[min(sorted.count - 1, sorted.count * 3 / 4)]) max=\(sorted.last ?? 0) "
            + "| v4-thresholds relaxed(≥59)=\(rateAtOrAbove(59))% standard(≥63)=\(rateAtOrAbove(63))% challenging(≥67)=\(rateAtOrAbove(67))%")
        XCTAssertEqual(scores.count, seeds.count)
        XCTAssertTrue(scores.allSatisfy { (0...100).contains($0) })
    }

    // A focused, high-performing run must stay reliably draftable; a neglected run must
    // reliably fail. This is the "성공은 계속 성공, 방치는 확실히 실패" guard the spec asks for.
    func testFocusedRunsStayDraftedAndNeglectRunsFail() throws {
        let engine = HighSchoolCareerEngine()
        let seeds = Self.draftBalanceSeeds
        let focused = try draftOutcomes(engine, seeds: seeds, policy: .focused)
        let neglect = try draftOutcomes(engine, seeds: seeds, policy: .neglect)
        print("[draft-balance] focused rate=\(Int((focused.rate * 100).rounded()))% (\(focused.drafted)/\(seeds.count)) "
            + "neglect rate=\(Int((neglect.rate * 100).rounded()))% (\(neglect.drafted)/\(seeds.count))")
        XCTAssertGreaterThanOrEqual(focused.rate, 0.9, "a focused, dominant run must remain reliably draftable")
        XCTAssertLessThanOrEqual(neglect.rate, 0.1, "a neglected, thrown run must reliably miss the draft")
    }

    // Career-harshness axis stays monotone: an easier setting never drafts less often than a
    // harder one for the same play policy. Only the threshold changes across these three, so
    // the score distribution is shared and the ordering is a clean smoke test.
    func testDraftRateIsMonotonicAcrossCareerHarshness() throws {
        let engine = HighSchoolCareerEngine()
        let seeds = (1...15).map(String.init)
        let relaxed = try draftOutcomes(engine, seeds: seeds, policy: .ordinary, difficulty: .init(careerHarshness: .relaxed)).rate
        let standard = try draftOutcomes(engine, seeds: seeds, policy: .ordinary, difficulty: .init(careerHarshness: .standard)).rate
        let challenging = try draftOutcomes(engine, seeds: seeds, policy: .ordinary, difficulty: .init(careerHarshness: .challenging)).rate
        print("[draft-balance] harshness relaxed=\(Int((relaxed * 100).rounded()))% "
            + "standard=\(Int((standard * 100).rounded()))% challenging=\(Int((challenging * 100).rounded()))%")
        XCTAssertGreaterThanOrEqual(relaxed, standard, "relaxed harshness must draft at least as often as standard")
        XCTAssertGreaterThanOrEqual(standard, challenging, "standard harshness must draft at least as often as challenging")
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
        // 뼈대가 가변이라 챕터 1이 관계로 시작하지 않을 수 있다. 첫 관계 국면까지 훈련·경기·각성을
        // 소화하며 진행한다(첫 관계 슬롯은 항상 코어 '감독').
        for _ in 0..<40 {
            switch result.snapshot.phase {
            case .relationship:
                return result
            case .training:
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .velocity, intensity: .standard))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: number, pitches: 16, strikeouts: 3, walks: 0, runsAllowed: 0, expectedDamage: 400, actualDamage: 180, recommendationAccepted: 10)))
            case .awakening:
                result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            default:
                XCTFail("첫 관계 장면 전에 커리어가 끝났습니다")
                return result
            }
        }
        XCTFail("첫 관계 장면에 도달하지 못했습니다")
        return result
    }

    private func reachFirstAwakening(_ engine: HighSchoolCareerEngine, focus: TrainingFocus) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: "1212", presetID: "precision_commander"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
        // 가변 뼈대에서 첫 각성은 후반 챕터에 놓일 수 있어 넉넉한 상한으로 끝까지 몰고 간다.
        for _ in 0..<80 {
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
        // Mirror the real commitment's conditional blocks so a "pre-arm-feature" save that still
        // carries newer fields (rivalTrust, balanceVersion) hashes correctly. Arm fields are the
        // one thing a legacy save lacks, so they are intentionally omitted here.
        if state.rivalTrust != nil {
            canonical.append("relationships:\(state.managerTrust ?? state.relationshipTrust):\(state.catcherTrust ?? state.relationshipTrust):\(state.rivalTrust ?? state.relationshipTrust)")
        } else if state.managerTrust != nil || state.catcherTrust != nil {
            canonical.append("staff:\(state.managerTrust ?? state.relationshipTrust):\(state.catcherTrust ?? state.relationshipTrust)")
        }
        if let balanceVersion = state.balanceVersion {
            canonical.append("balance_version:\(balanceVersion)")
        }
        return StableHash.fnv1a64(canonical.joined(separator: "|"))
    }
}

extension HighSchoolCareerEngineTests {
    struct ArmRunOutcome { let injured: Bool; let rehabbed: Bool; let draft: DraftResultSnapshot?; let maxRisk: Int; let sawWarning: Bool }

    // Drives a full career with a chosen arm-care response and a per-game pitch load. Used both by
    // the balance measurement and the behavioural arm tests below.
    func runArmCareer(
        _ engine: HighSchoolCareerEngine,
        seed: String,
        pitchesForGame: (Int) -> Int,
        armResponse: RelationshipResponse,
        useRecovery: Bool,
        presetID: String = "power_prospect",
        schoolID: SchoolID = .haedongPower
    ) throws -> ArmRunOutcome {
        var result = try engine.start(.init(seed: seed, presetID: presetID))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: schoolID))
        var injured = false
        var rehabbed = false
        var maxRisk = 0
        var sawWarning = false
        for _ in 0..<200 {
            maxRisk = max(maxRisk, result.snapshot.armRisk ?? 0)
            if HighSchoolCareerEngine.armHealthState(armRisk: result.snapshot.armRisk, injuryRecovery: result.snapshot.injuryRecovery) == .warning { sawWarning = true }
            switch result.snapshot.phase {
            case .training:
                let idx = result.snapshot.totalTrainingsCompleted
                let focus: TrainingFocus = useRecovery && idx % 3 == 2 ? .recovery
                    : TrainingFocus.allCases[idx % TrainingFocus.allCases.count]
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: focus, intensity: .standard))
            case .relationship:
                let isArm = result.snapshot.currentRelationshipEvent?.id == HighSchoolCareerEngine.armCareEventID
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: isArm ? armResponse : .listen))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                let pitches = pitchesForGame(number)
                result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: number, pitches: pitches, strikeouts: 4, walks: 1, runsAllowed: 1, expectedDamage: 500, actualDamage: 400, recommendationAccepted: pitches / 2)))
            case .awakening:
                result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft:
                result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
                return ArmRunOutcome(injured: injured, rehabbed: rehabbed, draft: result.snapshot.draftResult, maxRisk: maxRisk, sawWarning: sawWarning)
            case .legacy, .completed:
                return ArmRunOutcome(injured: injured, rehabbed: rehabbed, draft: result.snapshot.draftResult, maxRisk: maxRisk, sawWarning: sawWarning)
            case .prologue, .schoolSelection:
                XCTFail("school should already be selected"); return ArmRunOutcome(injured: injured, rehabbed: rehabbed, draft: nil, maxRisk: maxRisk, sawWarning: sawWarning)
            }
            if result.events.contains(where: { $0.eventType == "career_arm_injury" }) { injured = true }
            if result.events.contains(where: { $0.eventType == "career_training_rehab" }) { rehabbed = true }
        }
        XCTFail("career did not finish for seed \(seed)")
        return ArmRunOutcome(injured: injured, rehabbed: rehabbed, draft: nil, maxRisk: maxRisk, sawWarning: sawWarning)
    }

    // 평범한 중요-이닝 투구 수(24–49, 시드마다 다름)를 시드가 지정한다. 회복 훈련은 돌리되 경고에서
    // "참고 던진다"를 고르는 표준 정책. 실측 부상률은 15–35% 목표 안에 들어야 한다.
    private func ordinaryPitches(_ seed: Int, _ game: Int) -> Int { 24 + (seed % 26) }

    // ⑤ 평범 정책(회복 훈련 + 경고에서 강행) 40시드 부상률이 스펙 목표 15~35% 안에 든다.
    func testOrdinaryPushThroughInjuryRateLandsInSpecBand() throws {
        let engine = HighSchoolCareerEngine()
        let seeds = (1...40).map(String.init)
        var injured = 0, drafted = 0, warned = 0
        for seed in seeds {
            let s = Int(seed)!
            let out = try runArmCareer(engine, seed: seed, pitchesForGame: { self.ordinaryPitches(s, $0) }, armResponse: .challenge, useRecovery: true)
            if out.injured { injured += 1 }
            if out.sawWarning { warned += 1 }
            if out.draft?.outcome == .drafted { drafted += 1 }
        }
        let rate = Double(injured) / Double(seeds.count)
        print("[arm-balance] ordinary push-through injuryRate=\(Int((rate * 100).rounded()))% (\(injured)/40) warned=\(warned)/40 drafted=\(drafted)/40")
        XCTAssertGreaterThanOrEqual(rate, 0.15, "혹사를 강행하는 평범 정책의 부상이 너무 드뭅니다 — 위험 곡선이 약합니다")
        XCTAssertLessThanOrEqual(rate, 0.35, "평범 정책이 너무 자주 다칩니다 — 무리한 등판의 여지가 없습니다")
    }

    // ⑥ 같은 투구 부하라도 짧은 휴식/정밀 검진으로 관리하면 아무도 다치지 않는다.
    func testManagingTheWarningAvoidsInjuryEntirely() throws {
        let engine = HighSchoolCareerEngine()
        let seeds = (1...40).map(String.init)
        for response in [RelationshipResponse.listen, .explain] {
            var injured = 0
            for seed in seeds {
                let s = Int(seed)!
                let out = try runArmCareer(engine, seed: seed, pitchesForGame: { self.ordinaryPitches(s, $0) }, armResponse: response, useRecovery: true)
                if out.injured { injured += 1 }
            }
            XCTAssertEqual(injured, 0, "\(response.rawValue)로 경고를 관리하면 부상이 없어야 합니다")
        }
    }

    // ① 고피로 + 다투구 등판은 결정론적으로 경고 신호를 띄운다.
    func testHeavyOutingWhileFatiguedRaisesArmWarning() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "555", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
        // 강훈련으로 피로를 쌓다가, 팔이 아직 정상인데 피로가 바닥을 넘긴 중요 경기에 이르면 멈춘다.
        // 가변 뼈대에서 첫 경기가 이른 챕터에 올 수 있으므로, 아직 지치지 않은 경기는 가벼운 등판
        // (위험 0)으로 넘기고 계속 강훈련한다.
        var reachedFatiguedGame = false
        for _ in 0..<80 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .velocity, intensity: .intensive))
            case .relationship:
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
            case .awakening:
                result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .importantGame:
                if result.snapshot.fatigue >= HighSchoolCareerEngine.armFatigueFloor
                    && HighSchoolCareerEngine.armHealthState(armRisk: result.snapshot.armRisk, injuryRecovery: result.snapshot.injuryRecovery) == .normal {
                    reachedFatiguedGame = true
                } else {
                    let number = result.snapshot.performance.importantGamesCompleted + 1
                    result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                        report: .init(scenarioNumber: number, pitches: 18, strikeouts: 4, walks: 1, runsAllowed: 1, expectedDamage: 500, actualDamage: 400, recommendationAccepted: 9)))
                }
            default: break
            }
            if reachedFatiguedGame { break }
        }
        XCTAssertTrue(reachedFatiguedGame, "지친 상태(피로 ≥ 바닥)에서 시작하는 중요 경기에 도달해야 합니다")
        XCTAssertEqual(HighSchoolCareerEngine.armHealthState(armRisk: result.snapshot.armRisk, injuryRecovery: result.snapshot.injuryRecovery), .normal)
        let fatigueBeforeGame = result.snapshot.fatigue
        XCTAssertGreaterThanOrEqual(fatigueBeforeGame, HighSchoolCareerEngine.armFatigueFloor, "이 경기는 이미 지친 상태에서 시작해야 합니다")
        let number = result.snapshot.performance.importantGamesCompleted + 1
        result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
            report: .init(scenarioNumber: number, pitches: 70, strikeouts: 4, walks: 1, runsAllowed: 1, expectedDamage: 500, actualDamage: 400, recommendationAccepted: 30)))
        XCTAssertGreaterThanOrEqual(result.snapshot.armRisk ?? 0, HighSchoolCareerEngine.armWarningThreshold)
        XCTAssertEqual(HighSchoolCareerEngine.armHealthState(armRisk: result.snapshot.armRisk, injuryRecovery: result.snapshot.injuryRecovery), .warning)
        XCTAssertTrue(result.snapshot.news.contains { $0.contains("무리한 투구") }, "경고가 뉴스에 반영돼야 합니다")
    }

    // ② 무거운 투구 부하에서 "참고 던진다"를 반복하면 결정론적으로 부상 → 재활이 강제된다.
    func testRepeatedPushThroughDeterministicallyInjuresAndForcesRehab() throws {
        let engine = HighSchoolCareerEngine()
        let heavy: (Int) -> Int = { _ in 45 }
        let first = try runArmCareer(engine, seed: "31", pitchesForGame: heavy, armResponse: .challenge, useRecovery: true)
        XCTAssertTrue(first.injured, "무거운 부하에서 강행을 반복하면 부상이 나야 합니다")
        XCTAssertTrue(first.rehabbed, "부상 뒤에는 재활 훈련이 강제돼야 합니다")
        // 결정론: 같은 시드는 같은 결과를 낸다.
        let second = try runArmCareer(engine, seed: "31", pitchesForGame: heavy, armResponse: .challenge, useRecovery: true)
        XCTAssertEqual(first.injured, second.injured)
        XCTAssertEqual(first.maxRisk, second.maxRisk)
        XCTAssertEqual(first.draft?.evaluationScore, second.draft?.evaluationScore)
    }

    // ② 보강: 부상 시 재활 훈련은 성장 없이 지나가고 회복 카운트가 강제된다(단일 시드 세부 검증).
    func testInjuryForcesGrowthlessRehabTrainings() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "31", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
        var sawInjury = false
        var sawGrowthlessRehab = false
        for _ in 0..<200 {
            switch result.snapshot.phase {
            case .training:
                let injuredNow = (result.snapshot.injuryRecovery ?? 0) > 0
                result = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: .velocity, intensity: .standard))
                if injuredNow {
                    XCTAssertEqual(result.snapshot.lastTraining?.growth, 0, "재활 훈련은 능력이 오르지 않습니다")
                    XCTAssertEqual(result.snapshot.lastTraining?.focus, .recovery, "재활은 회복 훈련으로 표시됩니다")
                    sawGrowthlessRehab = true
                }
            case .relationship:
                let wasArm = result.snapshot.currentRelationshipEvent?.id == HighSchoolCareerEngine.armCareEventID
                result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .challenge))
                if wasArm && result.events.contains(where: { $0.eventType == "career_arm_injury" }) {
                    sawInjury = true
                    XCTAssertGreaterThan(result.snapshot.injuryRecovery ?? 0, 0, "부상 직후 회복 카운트가 잡혀야 합니다")
                }
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: number, pitches: 45, strikeouts: 4, walks: 1, runsAllowed: 1, expectedDamage: 500, actualDamage: 400, recommendationAccepted: 20)))
            case .awakening:
                result = try engine.chooseAwakening(.init(seed: result.nextSeed, state: result.snapshot, awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft, .legacy, .completed: break
            case .prologue, .schoolSelection: XCTFail("unexpected phase")
            }
            if [.draft, .legacy, .completed].contains(result.snapshot.phase) { break }
        }
        XCTAssertTrue(sawInjury, "이 시드/정책은 부상에 도달해야 합니다")
        XCTAssertTrue(sawGrowthlessRehab, "부상 뒤 재활 훈련이 관찰돼야 합니다")
    }

    // ③ 같은 무거운 부하라도 "짧은 휴식"으로 관리하면 부상이 없다.
    func testRestingUnderHeavyLoadAvoidsInjury() throws {
        let engine = HighSchoolCareerEngine()
        let heavy: (Int) -> Int = { _ in 45 }
        let out = try runArmCareer(engine, seed: "31", pitchesForGame: heavy, armResponse: .listen, useRecovery: true)
        XCTAssertFalse(out.injured, "휴식을 선택하면 같은 부하에서도 다치지 않아야 합니다")
        XCTAssertFalse(out.rehabbed, "부상이 없으니 재활도 없어야 합니다")
    }

    // ④ 옛 저장본(팔 필드 없음)이 그대로 디코드·검증되고, 이후 팔 시스템이 활성화된다.
    func testLegacySaveWithoutArmFieldsDecodesAndValidates() throws {
        let engine = HighSchoolCareerEngine()
        let started = try engine.start(.init(seed: "20260726", presetID: "power_prospect"))
        let encoded = try JSONEncoder().encode(started.snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        // 이 기능 이전 저장본은 팔 필드도, 회차 스케줄 필드도 없다.
        object.removeValue(forKey: "armRisk")
        object.removeValue(forKey: "injuryRecovery")
        object.removeValue(forKey: "schedule")
        object.removeValue(forKey: "worldRulesVersion")
        object["stateCommitment"] = ""
        let unsignedData = try JSONSerialization.data(withJSONObject: object)
        let unsigned = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: unsignedData)
        XCTAssertNil(unsigned.armRisk)
        XCTAssertNil(unsigned.injuryRecovery)
        object["stateCommitment"] = legacyCommitment(for: unsigned)
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacy = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: legacyData)
        // 옛 커밋먼트로도 검증을 통과해 다음 단계가 진행된다.
        let advanced = try engine.completePrologue(.init(seed: started.nextSeed, state: legacy))
        XCTAssertEqual(advanced.snapshot.phase, .schoolSelection)
        XCTAssertEqual(HighSchoolCareerEngine.armHealthState(armRisk: legacy.armRisk, injuryRecovery: legacy.injuryRecovery), .normal)
    }

    func testPrologueAcknowledgesLaterLivesWithoutChangingFirstLife() throws {
        let identity = PlayerIdentitySnapshot.defaultPitcher
        let firstLife = HighSchoolCareerEngine.prologueNews(identity: identity, lifeNumber: 1, inheritedMemoryCount: 0)
        XCTAssertEqual(firstLife, ["서울 중학교 마지막 대회에서 보여준 공이 같은 지역 네 고교의 관심을 끌었습니다."])

        let secondLife = HighSchoolCareerEngine.prologueNews(identity: identity, lifeNumber: 2, inheritedMemoryCount: 2)
        XCTAssertNotEqual(secondLife.first, firstLife.first)
        XCTAssertEqual(secondLife.count, 2)
        XCTAssertTrue(secondLife[1].contains("설명하기 어려운 감각"))

        let thirdLife = HighSchoolCareerEngine.prologueNews(identity: identity, lifeNumber: 3, inheritedMemoryCount: 0)
        XCTAssertEqual(thirdLife.count, 1)
        XCTAssertNotEqual(thirdLife.first, secondLife.first)
    }
}

extension HighSchoolCareerEngineTests {
    func testTrainingOpportunityIsDeterministicAndRotates() throws {
        let first = HighSchoolCareerEngine.trainingOpportunity(careerID: "career-9-life-1", index: 0)
        let firstAgain = HighSchoolCareerEngine.trainingOpportunity(careerID: "career-9-life-1", index: 0)
        XCTAssertEqual(first, firstAgain)
        XCTAssertFalse(first.reason.isEmpty)
        var distinct = Set<TrainingFocus>()
        for index in 0..<8 { distinct.insert(HighSchoolCareerEngine.trainingOpportunity(careerID: "career-9-life-1", index: index).focus) }
        XCTAssertGreaterThanOrEqual(distinct.count, 3, "기회가 회전하지 않으면 매일 같은 추천이 된다")
        for index in 1..<8 {
            XCTAssertNotEqual(
                HighSchoolCareerEngine.trainingOpportunity(careerID: "career-9-life-1", index: index).focus,
                HighSchoolCareerEngine.trainingOpportunity(careerID: "career-9-life-1", index: index - 1).focus,
                "연속 훈련에서 같은 기회가 반복되면 안 된다")
        }
    }

    func testMatchingTheOpportunityRaisesTheGrowthSignal() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "515", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: result.snapshot.schoolOptions[0].id))
        let opportunity = try XCTUnwrap(result.snapshot.trainingOpportunity)
        let offFocus = TrainingFocus.allCases.first { $0 != opportunity.focus && $0 != .recovery } ?? .command
        let hit = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: opportunity.focus, intensity: .standard))
        let miss = try engine.commitTraining(.init(seed: result.nextSeed, state: result.snapshot, focus: offFocus, intensity: .standard))
        XCTAssertEqual(hit.snapshot.lastTraining?.opportunityHit, true)
        XCTAssertNotEqual(miss.snapshot.lastTraining?.opportunityHit, true)
    }

    /// 상시 시나리오 풀 크기는 보폭 7과 서로소여야 무중복 순환이 산다.
    /// 시나리오를 추가·게이트할 때 이 검사가 어긋나면 보폭도 함께 바꿔야 한다.
    func testAlwaysAvailableScenarioPoolStaysCoprimeWithStride() {
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        // 챕터가 오를 때마다 게이트가 열려 풀 크기가 변한다 — **모든 챕터의 풀**이
        // 보폭 7과 서로소여야 순환이 살아 있다(챕터 하나만 배수여도 그 챕터의
        // 시나리오 다양성이 1/7로 무너진다).
        for chapter in 1...9 {
            let pool = HighSchoolContentCatalog.scenarios.filter { $0.minChapter <= chapter }
            XCTAssertEqual(gcd(7, pool.count), 1, "챕터 \(chapter) 풀 \(pool.count)개가 보폭 7과 서로소가 아닙니다.")
        }
        // 시기 고정 장면 5 — 결승·마지막 이닝·한여름·선배들의 마지막·퍼펙트.
        let always = HighSchoolContentCatalog.scenarios.filter { $0.minChapter <= 1 }
        XCTAssertEqual(HighSchoolContentCatalog.scenarios.count - always.count, 5)
    }
}
