import Foundation
import XCTest
@testable import SimulationCore

final class CareerSignatureLegacyTests: XCTestCase {
    func testV4CoreListeningUsesOneSafeBudgetAcrossEverySchoolArchetype() throws {
        let engine = HighSchoolCareerEngine()
        let genericFeedback = "상대의 말을 끝까지 듣고 다음 준비 기준을 함께 확인했습니다."

        for (schoolIndex, schoolID) in SchoolID.allCases.enumerated() {
            for (categoryIndex, category) in ["coach", "catcher"].enumerated() {
                let scene = try relationshipScene(
                    category,
                    engine: engine,
                    seed: String(918_300 + schoolIndex * 10 + categoryIndex),
                    schoolID: schoolID
                )
                let target = HighSchoolCareerEngine.relationshipTarget(forEventCategory: category)
                let beforeTrust = target == .coach
                    ? try XCTUnwrap(scene.snapshot.managerTrust)
                    : try XCTUnwrap(scene.snapshot.catcherTrust)
                let expectedDelta = scene.snapshot.careerWind.rules
                    .adjustedRelationshipTrustChange(4, target: target)
                let resolved = try engine.resolveRelationship(.init(
                    seed: scene.nextSeed, state: scene.snapshot, response: .listen
                ))
                let afterTrust = target == .coach
                    ? try XCTUnwrap(resolved.snapshot.managerTrust)
                    : try XCTUnwrap(resolved.snapshot.catcherTrust)

                XCTAssertEqual(afterTrust - beforeTrust, expectedDelta, "\(schoolID).\(category)")
                XCTAssertEqual(resolved.snapshot.pitcher, scene.snapshot.pitcher)
                XCTAssertEqual(resolved.snapshot.fatigue, scene.snapshot.fatigue)
                XCTAssertEqual(resolved.snapshot.fanInterest, scene.snapshot.fanInterest)
                XCTAssertNil(resolved.snapshot.lastRelationship?.growthFocus)
                XCTAssertEqual(resolved.snapshot.lastRelationship?.feedback, genericFeedback)
            }
        }
    }

    func testV3CoreListeningKeepsTheExactLegacyArchetypeEffects() throws {
        let engine = HighSchoolCareerEngine()
        let expectedFeedback = [
            "coach": "지시는 받아들였지만 경쟁 구도는 바뀌지 않았습니다.",
            "catcher": "포수의 공격적인 의도는 확인했지만 승부 순서는 정하지 못했습니다.",
        ]

        for (index, category) in ["coach", "catcher"].enumerated() {
            let current = try relationshipScene(
                category,
                engine: engine,
                seed: String(918_390 + index),
                schoolID: .haedongPower
            )
            let legacy = try replacingBalanceVersion(3, in: current.snapshot)
            let target = HighSchoolCareerEngine.relationshipTarget(forEventCategory: category)
            let beforeTrust = target == .coach
                ? try XCTUnwrap(legacy.managerTrust)
                : try XCTUnwrap(legacy.catcherTrust)
            let expectedDelta = legacy.careerWind.rules
                .adjustedRelationshipTrustChange(2, target: target)
            let resolved = try engine.resolveRelationship(.init(
                seed: current.nextSeed, state: legacy, response: .listen
            ))
            let afterTrust = target == .coach
                ? try XCTUnwrap(resolved.snapshot.managerTrust)
                : try XCTUnwrap(resolved.snapshot.catcherTrust)

            XCTAssertEqual(resolved.snapshot.balanceVersion, 3)
            XCTAssertEqual(afterTrust - beforeTrust, expectedDelta)
            XCTAssertEqual(resolved.snapshot.pitcher, legacy.pitcher)
            XCTAssertEqual(resolved.snapshot.fatigue, legacy.fatigue)
            XCTAssertEqual(resolved.snapshot.fanInterest, legacy.fanInterest)
            XCTAssertNil(resolved.snapshot.lastRelationship?.growthFocus)
            XCTAssertEqual(resolved.snapshot.lastRelationship?.feedback, expectedFeedback[category])
        }
    }

    func testCandidatesAreDeterministicUniqueAndGroundedInCompletedCareer() throws {
        let completed = try commandFocusedCareer(seed: "918201")

        let first = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState
        )
        let second = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(Set(first.map(\.id)).count, 3)
        XCTAssertEqual(Set(first.map(\.family)).count, 3)
        XCTAssertEqual(Set(first.map(\.title)).count, 3)
        XCTAssertTrue(first.allSatisfy { $0.effect.totalRatingBonus == 4 })
        XCTAssertTrue(first.allSatisfy { !$0.evidence.summary.isEmpty })
        XCTAssertTrue(first.allSatisfy { $0.evidence.performance == completed.finalState.performance })
        XCTAssertTrue(first.allSatisfy { $0.evidence.selectedAwakenings == completed.finalState.selectedAwakenings })

        let commandGrowth = max(
            0,
            completed.finalState.pitcher.command - completed.startingPitcher.command
        )
        let command = try XCTUnwrap(first.first { $0.family == .command })
        XCTAssertEqual(command.evidence.ratingGrowth, commandGrowth)
        XCTAssertEqual(command.evidence.relationshipTarget, .coach)
        XCTAssertEqual(command.evidence.relationshipTrust, completed.finalState.managerTrust)
        XCTAssertEqual(first.first?.family, .command, "제구에 집중한 실제 성장 방향이 첫 대표 유산이어야 합니다.")

        let encoded = try JSONEncoder().encode(command)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let evidence = try XCTUnwrap(object["evidence"] as? [String: Any])
        XCTAssertNil(evidence["proPerformance"], "기존 고교 후보 payload에는 새 optional 키가 생기면 안 됩니다.")
        XCTAssertEqual(try JSONDecoder().decode(CareerSignatureLegacy.self, from: encoded), command)
    }

    func testCandidateRulesVersionFreezesV1AndFailsUnknownValuesClosed() throws {
        let completed = try commandFocusedCareer(seed: "918207")
        let legacyEntry = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState
        )
        let explicit = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState,
            rulesVersion: CareerSignatureLegacyRulesVersion.v1
        )
        let storedOne = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState,
            rulesVersion: 1
        )
        let storedNil = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState,
            rulesVersion: nil
        )
        let unsupported = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState,
            rulesVersion: 999
        )

        XCTAssertEqual(CareerSignatureLegacyRulesVersion.current.rawValue, 1)
        XCTAssertEqual(CareerSignatureLegacyRulesVersion.resolve(storedValue: nil), .v1)
        XCTAssertEqual(CareerSignatureLegacyRulesVersion.resolve(storedValue: 999), .v1)
        XCTAssertEqual(legacyEntry, explicit)
        XCTAssertEqual(legacyEntry, storedOne)
        XCTAssertEqual(legacyEntry, storedNil)
        XCTAssertEqual(legacyEntry, unsupported)
    }

    func testProCareerCandidatesAreDeterministicUniqueAndGroundedInRetirementRecord() throws {
        let completed = try commandFocusedCareer(seed: "918216")
        let highSchoolCandidates = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState
        )
        XCTAssertEqual(highSchoolCandidates.first?.family, .command)

        let highSchoolPitcher = completed.finalState.pitcher
        let proPitcher = PitcherSnapshot(
            id: highSchoolPitcher.id,
            name: highSchoolPitcher.name,
            stuff: highSchoolPitcher.stuff,
            command: highSchoolPitcher.command,
            movement: min(80, highSchoolPitcher.movement + 18),
            stamina: highSchoolPitcher.stamina,
            pitchProfiles: highSchoolPitcher.pitchProfiles,
            throwingHand: highSchoolPitcher.throwingHand
        )
        let teamID = HighSchoolCareerEngine.teams[0].id
        let seasons = (1...12).map { season in
            ProSeasonStats(
                season: season,
                teamID: teamID,
                games: 30,
                starts: 25,
                inningsOuts: 450,
                strikeouts: 160,
                walks: 20,
                runsAllowed: 48,
                wins: 12,
                losses: 6
            )
        }
        let proCareer = makeProCareer(
            highSchoolState: completed.finalState,
            pitcher: proPitcher,
            stats: seasons,
            awards: ["시즌 8 탈삼진상", "시즌 11 탈삼진상"]
        )

        let first = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            highSchoolState: completed.finalState,
            proCareer: proCareer,
            rulesVersion: 1
        )
        let second = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            highSchoolState: completed.finalState,
            proCareer: proCareer,
            rulesVersion: CareerSignatureLegacyRulesVersion.v1
        )
        let unsupported = CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            highSchoolState: completed.finalState,
            proCareer: proCareer,
            rulesVersion: 999
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, unsupported)
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(Set(first.map(\.id)).count, 3)
        XCTAssertEqual(Set(first.map(\.family)).count, 3)
        XCTAssertEqual(first.first?.family, .breaking)
        XCTAssertNotEqual(first.map(\.id), highSchoolCandidates.map(\.id))

        let breaking = try XCTUnwrap(first.first { $0.family == .breaking })
        let proEvidence = try XCTUnwrap(breaking.evidence.proPerformance)
        XCTAssertEqual(proEvidence.finalPitcher, proPitcher)
        XCTAssertEqual(proEvidence.seasons, 12)
        XCTAssertEqual(proEvidence.games, 360)
        XCTAssertEqual(proEvidence.starts, 300)
        XCTAssertEqual(proEvidence.inningsOuts, 5_400)
        XCTAssertEqual(proEvidence.strikeouts, 1_920)
        XCTAssertEqual(proEvidence.walks, 240)
        XCTAssertEqual(proEvidence.awards, ["시즌 8 탈삼진상", "시즌 11 탈삼진상"])
        XCTAssertEqual(
            breaking.evidence.ratingGrowth,
            max(0, proPitcher.movement - completed.startingPitcher.movement)
        )
        XCTAssertTrue(breaking.evidence.summary.contains("프로 통산 360경기 1800이닝"))
        XCTAssertTrue(breaking.evidence.summary.contains("1920탈삼진 240볼넷"))
        XCTAssertTrue(breaking.evidence.summary.contains("프로 최종 변화구 \(proPitcher.movement)"))
        XCTAssertTrue(breaking.evidence.summary.contains("수상 2회"))
    }

    func testProEvidenceCodableKeepsHighSchoolPayloadCompatible() throws {
        let completed = try commandFocusedCareer(seed: "918217")
        let legacy = try XCTUnwrap(CareerSignatureLegacy.candidates(
            startingPitcher: completed.startingPitcher,
            finalState: completed.finalState
        ).first)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let oldShape = try encoder.encode(legacy)
        let oldObject = try XCTUnwrap(JSONSerialization.jsonObject(with: oldShape) as? [String: Any])
        let oldEvidence = try XCTUnwrap(oldObject["evidence"] as? [String: Any])
        XCTAssertNil(oldEvidence["proPerformance"])

        let decoded = try JSONDecoder().decode(CareerSignatureLegacy.self, from: oldShape)
        XCTAssertEqual(decoded, legacy)
        XCTAssertNil(decoded.evidence.proPerformance)
    }

    func testSelectedLegacyAppliesOneFixedEffectWithoutReplacingMemoryCards() throws {
        let engine = HighSchoolCareerEngine()
        let plain = try engine.start(.init(
            seed: "918202", presetID: "power_prospect", lifeNumber: 2
        ))
        let memory = try engine.start(.init(
            seed: "918202", presetID: "power_prospect", lifeNumber: 2,
            inheritedMemories: [.catcherNotebook]
        ))
        let combined = try engine.start(.init(
            seed: "918202", presetID: "power_prospect", lifeNumber: 2,
            inheritedMemories: [.catcherNotebook], signatureLegacyID: .commandMap
        ))

        XCTAssertNotEqual(memory.snapshot.pitcher, plain.snapshot.pitcher, "기존 MemoryCard 효과가 먼저 보존되어야 합니다.")
        let expected = CareerSignatureLegacy.definition(for: .commandMap).effect
            .applying(to: memory.snapshot.pitcher)
        XCTAssertEqual(combined.snapshot.pitcher, expected)
        XCTAssertEqual(combined.snapshot.pitcher.stuff - memory.snapshot.pitcher.stuff, 0)
        XCTAssertEqual(combined.snapshot.pitcher.command - memory.snapshot.pitcher.command, 3)
        XCTAssertEqual(combined.snapshot.pitcher.movement - memory.snapshot.pitcher.movement, 1)
        XCTAssertEqual(combined.snapshot.pitcher.stamina - memory.snapshot.pitcher.stamina, 0)
        XCTAssertEqual(CareerSignatureLegacy.apply(nil, to: memory.snapshot.pitcher), memory.snapshot.pitcher)

        for id in CareerSignatureLegacyID.allCases {
            XCTAssertEqual(CareerSignatureLegacy.definition(for: id).effect.totalRatingBonus, 4)
        }
    }

    func testMissingSignatureLegacyJSONDecodesAsNilAndKeepsExactStartIdentity() throws {
        let legacyParams = StartHighSchoolCareerParams(
            seed: "918203",
            presetID: "precision_commander",
            lifeNumber: 2,
            inheritedSoulPoints: 17,
            inheritedMemories: [.coachLetter]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let oldData = try encoder.encode(legacyParams)
        let oldObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: oldData) as? [String: Any]
        )
        XCTAssertNil(oldObject["signatureLegacyID"])
        XCTAssertNil(oldObject["inheritanceRulesVersion"])

        let decoded = try JSONDecoder().decode(StartHighSchoolCareerParams.self, from: oldData)
        XCTAssertNil(decoded.signatureLegacyID)
        XCTAssertNil(decoded.inheritanceRulesVersion)
        XCTAssertEqual(decoded, legacyParams)

        let explicitNil = StartHighSchoolCareerParams(
            seed: "918203",
            presetID: "precision_commander",
            lifeNumber: 2,
            inheritedSoulPoints: 17,
            inheritedMemories: [.coachLetter],
            signatureLegacyID: nil
        )
        let engine = HighSchoolCareerEngine()
        XCTAssertEqual(try engine.start(decoded), try engine.start(explicitNil))
    }

    func testSoulInheritanceRulesVersionPreservesV1AndAppliesCalibratedV2Curve() throws {
        XCTAssertEqual(SoulInheritanceRulesVersion.current, .v2)
        XCTAssertEqual(SoulInheritanceRulesVersion.resolve(storedValue: nil), .v1)
        XCTAssertEqual(SoulInheritanceRulesVersion.resolve(storedValue: 1), .v1)
        XCTAssertEqual(SoulInheritanceRulesVersion.resolve(storedValue: 2), .v2)
        XCTAssertEqual(SoulInheritanceRulesVersion.resolve(storedValue: 999), .v1)

        XCTAssertEqual(HighSchoolCareerEngine.inheritancePointCap(for: 23), 8)
        XCTAssertEqual(
            HighSchoolCareerEngine.inheritancePointCap(for: 23, rulesVersion: .v1),
            8
        )
        XCTAssertEqual(
            HighSchoolCareerEngine.inheritancePointCap(for: 23, storedRulesVersion: nil),
            8
        )
        XCTAssertEqual(
            HighSchoolCareerEngine.inheritancePointCap(for: 23, storedRulesVersion: 999),
            8
        )
        XCTAssertEqual(HighSchoolCareerEngine.appliedInheritance(for: 23), 8)

        let v2Examples: [(points: Int, applied: Int)] = [
            (0, 0), (19, 1), (20, 1), (23, 1), (27, 1), (28, 2),
            (44, 6), (48, 7), (80, 15), (99, 19), (100, 20),
        ]
        for example in v2Examples {
            XCTAssertEqual(
                HighSchoolCareerEngine.appliedInheritance(
                    for: example.points,
                    rulesVersion: .v2
                ),
                example.applied,
                "points=\(example.points)"
            )
        }

        // 다음 계단 예고는 곡선을 그대로 따라가야 한다 — 화면이 "28혼이면 +2"라고
        // 약속했는데 실제로 28혼에서 +2가 아니면 그 문장이 거짓말이 된다.
        for example in v2Examples where example.applied < 20 {
            let step = HighSchoolCareerEngine.nextInheritanceStep(
                for: example.points, rulesVersion: .v2
            )
            guard let unwrapped = step else {
                XCTFail("다음 계단 예고가 없습니다. points=\(example.points)")
                continue
            }
            XCTAssertGreaterThan(unwrapped.applied, example.applied, "points=\(example.points)")
            XCTAssertEqual(
                HighSchoolCareerEngine.appliedInheritance(
                    for: unwrapped.soulPoints, rulesVersion: .v2
                ),
                unwrapped.applied,
                "예고한 지점의 실제 적용값이 다릅니다. points=\(example.points)"
            )
        }
        // 상한에 닿으면 예고할 다음이 없다.
        XCTAssertNil(HighSchoolCareerEngine.nextInheritanceStep(for: 100, rulesVersion: .v2))
        XCTAssertNil(HighSchoolCareerEngine.nextInheritanceStep(for: 5_000, rulesVersion: .v2))


        let engine = HighSchoolCareerEngine()
        let legacyMissingVersion = StartHighSchoolCareerParams(
            seed: "918215", presetID: "power_prospect", lifeNumber: 2,
            inheritedSoulPoints: 23, inheritedSoulTotal: 23
        )
        let explicitV1 = StartHighSchoolCareerParams(
            seed: "918215", presetID: "power_prospect", lifeNumber: 2,
            inheritedSoulPoints: 23, inheritedSoulTotal: 23,
            signatureLegacyID: nil, inheritanceRulesVersion: 1
        )
        let explicitV2 = StartHighSchoolCareerParams(
            seed: "918215", presetID: "power_prospect", lifeNumber: 2,
            inheritedSoulPoints: 23, inheritedSoulTotal: 23,
            signatureLegacyID: nil, inheritanceRulesVersion: 2
        )
        let legacyStart = try engine.start(legacyMissingVersion)
        let v1Start = try engine.start(explicitV1)
        let v2Start = try engine.start(explicitV2)
        XCTAssertEqual(legacyStart, v1Start, "nil must retain the exact pre-version start result")
        let v1Ratings = legacyStart.snapshot.pitcher.stuff + legacyStart.snapshot.pitcher.command
            + legacyStart.snapshot.pitcher.movement + legacyStart.snapshot.pitcher.stamina
        let v2Ratings = v2Start.snapshot.pitcher.stuff + v2Start.snapshot.pitcher.command
            + v2Start.snapshot.pitcher.movement + v2Start.snapshot.pitcher.stamina
        XCTAssertEqual(v1Ratings - v2Ratings, 7)

        let noBoost = try engine.start(.init(
            seed: "918216", presetID: "power_prospect", lifeNumber: 2,
            signatureLegacyID: nil,
            inheritanceRulesVersion: SoulInheritanceRulesVersion.v2.rawValue
        ))
        let headStart = try engine.start(.init(
            seed: "918216", presetID: "power_prospect", lifeNumber: 2,
            soulBoosts: [.headStart],
            signatureLegacyID: nil,
            inheritanceRulesVersion: SoulInheritanceRulesVersion.v2.rawValue
        ))
        func total(_ pitcher: PitcherSnapshot) -> Int {
            pitcher.stuff + pitcher.command + pitcher.movement + pitcher.stamina
        }
        XCTAssertEqual(total(headStart.snapshot.pitcher) - total(noBoost.snapshot.pitcher), 5)

        // 시작 시 적용된 값은 snapshot에 고정된다. 이후 decode/transition은 boost 규칙을
        // 다시 계산하지 않으므로 이미 시작한 회차의 투수와 다음 결과가 움직이지 않는다.
        let decodedStarted = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONEncoder().encode(headStart.snapshot)
        )
        XCTAssertEqual(decodedStarted.pitcher, headStart.snapshot.pitcher)
        XCTAssertEqual(
            try engine.completePrologue(.init(seed: headStart.nextSeed, state: decodedStarted)),
            try engine.completePrologue(.init(seed: headStart.nextSeed, state: headStart.snapshot))
        )
    }

    func testBalanceV4CatalogAndDraftRulesAreVersionedWithoutChangingV3Saves() throws {
        XCTAssertEqual(PitcherPresetCatalog.balanceVersion, 4)
        XCTAssertEqual(
            Set(PitcherPresetCatalog.all.map {
                $0.pitcher.stuff + $0.pitcher.command + $0.pitcher.movement + $0.pitcher.stamina
            }),
            [150]
        )
        // 영점은 그 시대의 실측 RA9다 — 판정식이 KBO 수준으로 옮겨가면서 함께 올렸다.
        // 유형별 **상대 순서**(제구형이 가장 낮고 파워형이 가장 높다)가 이 테스트의 뜻이다.
        let expectedBaselines = [
            "pitcher-power": 4_930,
            "pitcher-command": 1_900,
            "pitcher-artist": 2_700,
            "pitcher-stamina": 2_900,
        ]
        for preset in PitcherPresetCatalog.all {
            XCTAssertEqual(
                HighSchoolCareerEngine.highSchoolBaseline(
                    lifeNumber: 1,
                    pitcherID: preset.pitcher.id,
                    balanceVersion: 4
                ),
                expectedBaselines[preset.pitcher.id]
            )
        }

        let engine = HighSchoolCareerEngine()
        let current = try engine.start(.init(seed: "918220", presetID: "power_prospect")).snapshot
        // v4 문턱은 밸런스에 따라 움직인다(63 → 66: 중립 자동 진행 지명률 55%를 13%로).
        // 이 줄은 "지금 값이 얼마인가"를 적어 두는 기록이고, 아래 v3 단언이 진짜 계약이다 —
        // 진행 중인 옛 저장의 당락선은 어떤 밸런스 변경에도 움직이면 안 된다.
        XCTAssertEqual(HighSchoolCareerEngine.draftThreshold(state: current), 66)
        XCTAssertEqual(
            (0..<5).map { HighSchoolCareerEngine.draftVariance(balanceVersion: 4, roll: $0) },
            [-1, 0, 0, 0, 1]
        )
        XCTAssertEqual(
            (0..<11).map { HighSchoolCareerEngine.draftVariance(balanceVersion: 3, roll: $0) },
            Array(-5...5)
        )
        let v3 = try replacingBalanceVersion(3, in: current)
        XCTAssertEqual(HighSchoolCareerEngine.draftThreshold(state: v3), 61)
        XCTAssertEqual(
            HighSchoolCareerEngine.highSchoolBaseline(
                lifeNumber: 1, pitcherID: v3.pitcher.id, balanceVersion: v3.balanceVersion
            ),
            HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: 1)
        )
    }

    func testV4StaminaTrainingNeverWorsensZeroCostPitchWhileV3RemainsExact() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "918229", presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            schoolID: try XCTUnwrap(result.snapshot.schoolOptions.first?.id)
        ))
        XCTAssertEqual(result.snapshot.phase, .training)

        func zeroCostState(version: Int) throws -> HighSchoolCareerSnapshot {
            try rewritingState(result.snapshot) { object in
                object["balanceVersion"] = version
                var pitcher = try XCTUnwrap(object["pitcher"] as? [String: Any])
                var profiles = try XCTUnwrap(pitcher["pitchProfiles"] as? [[String: Any]])
                XCTAssertFalse(profiles.isEmpty)
                profiles[0]["fatigueCost"] = 0
                pitcher["pitchProfiles"] = profiles
                object["pitcher"] = pitcher
            }
        }

        let v3 = try zeroCostState(version: 3)
        let v4 = try zeroCostState(version: 4)
        var chosenSeed: String?
        var current: HighSchoolCareerResult?
        for value in 918_300..<918_400 {
            let seed = String(value)
            let candidate = try engine.commitTraining(.init(
                seed: seed, state: v4, focus: .stamina, intensity: .standard
            ))
            if (candidate.snapshot.lastTraining?.growth ?? 0) > 0 {
                chosenSeed = seed
                current = candidate
                break
            }
        }
        let seed = try XCTUnwrap(chosenSeed)
        let v4Result = try XCTUnwrap(current)
        let v3Result = try engine.commitTraining(.init(
            seed: seed, state: v3, focus: .stamina, intensity: .standard
        ))

        XCTAssertEqual(v4Result.snapshot.pitcher.pitchProfiles?.first?.fatigueCost, 0)
        XCTAssertEqual(
            v3Result.snapshot.pitcher.pitchProfiles?.first?.fatigueCost, 1,
            "이미 시작된 v3 회차의 역사적 0→1 결과는 저장 결정론을 위해 보존합니다"
        )
    }

    func testV1V2NormalizationTargetsV3AndV3MigrationIsAnIdentity() throws {
        let v2 = try XCTUnwrap(
            PitcherPresetCatalog.balanceV2.first { $0.id == "precision_commander" }?.pitcher
        )
        let earned = PitcherSnapshot(
            id: v2.id,
            name: "왼손 제구형",
            stuff: v2.stuff + 2,
            command: v2.command + 4,
            movement: v2.movement + 1,
            stamina: v2.stamina + 3,
            pitchProfiles: v2.pitchProfiles,
            throwingHand: .left
        )
        let migrated = try XCTUnwrap(PitcherPresetCatalog.migrate(
            earned, fromVersion: 2, targetVersion: 3
        )?.pitcher)
        let v3 = try XCTUnwrap(
            PitcherPresetCatalog.balanceV3.first { $0.id == "precision_commander" }?.pitcher
        )
        XCTAssertEqual(migrated.stuff, v3.stuff + 2)
        XCTAssertEqual(migrated.command, v3.command + 4)
        XCTAssertEqual(migrated.movement, v3.movement + 1)
        XCTAssertEqual(migrated.stamina, v3.stamina + 3)
        XCTAssertEqual(migrated.throwingHand, .left)
        XCTAssertNil(PitcherPresetCatalog.migrate(migrated, fromVersion: 3, targetVersion: 3))
    }

    func testV3LoadNormalizationPreservesDraftForecastAndExactResolution() throws {
        let engine = HighSchoolCareerEngine()
        let prepared = try careerBeforeDraft(engine: engine, seed: "918221")
        let v3 = try replacingBalanceVersion(3, in: prepared.snapshot)
        let beforeForecast = HighSchoolCareerEngine.draftForecast(state: v3)
        let beforeCore = HighSchoolCareerEngine.draftEvaluationCore(state: v3)
        let legacyAutoLines = (v3.seasonLog ?? []).filter { !$0.played }
        let legacyAutoOuts = legacyAutoLines.reduce(0) { $0 + $1.outs }
        let legacyAutoRuns = legacyAutoLines.reduce(0) { $0 + $1.runsAllowed }
        let expectedLegacySeasonTerm = legacyAutoOuts == 0 ? 0 : min(4, max(-4,
            (HighSchoolCareerEngine.highSchoolBaseline(lifeNumber: v3.lifeNumber)
                - legacyAutoRuns * 27_000 / legacyAutoOuts) * 4 / 1_000
        ))
        XCTAssertEqual(beforeCore.seasonTerm, expectedLegacySeasonTerm)

        let normalized = try engine.normalizeRegionalSchools(.init(
            seed: prepared.nextSeed, state: v3
        ))
        XCTAssertEqual(normalized.snapshot.balanceVersion, 3)
        XCTAssertEqual(normalized.snapshot.pitcher, v3.pitcher)
        XCTAssertEqual(HighSchoolCareerEngine.draftForecast(state: normalized.snapshot), beforeForecast)
        let afterCore = HighSchoolCareerEngine.draftEvaluationCore(state: normalized.snapshot)
        XCTAssertEqual(afterCore.total, beforeCore.total)
        XCTAssertEqual(afterCore.ratingScore, beforeCore.ratingScore)
        XCTAssertEqual(afterCore.performanceScore, beforeCore.performanceScore)
        XCTAssertEqual(afterCore.processBonus, beforeCore.processBonus)
        XCTAssertEqual(afterCore.seasonTerm, beforeCore.seasonTerm)

        let direct = try engine.resolveDraft(.init(seed: prepared.nextSeed, state: v3)).snapshot
        let afterLoad = try engine.resolveDraft(.init(
            seed: normalized.nextSeed, state: normalized.snapshot
        )).snapshot
        XCTAssertEqual(afterLoad.draftResult, direct.draftResult)

        var sawLegacyVarianceOutsideV4Range = false
        for seed in 1...64 {
            let resolved = try engine.resolveDraft(.init(seed: String(seed), state: v3)).snapshot
            let delta = try XCTUnwrap(resolved.draftResult).evaluationScore - beforeForecast.score
            var generator = SplitMix64(seed: UInt64(seed) ^ 0x4452_4146_5400)
            let expected = HighSchoolCareerEngine.draftVariance(
                balanceVersion: v3.balanceVersion,
                roll: generator.nextInt(upperBound: 11)
            )
            XCTAssertEqual(delta, expected)
            XCTAssertLessThanOrEqual(abs(delta), 5)
            sawLegacyVarianceOutsideV4Range = sawLegacyVarianceOutsideV4Range || abs(delta) > 2
        }
        XCTAssertTrue(sawLegacyVarianceOutsideV4Range)

        let currentForecast = HighSchoolCareerEngine.draftForecast(state: prepared.snapshot)
        var sawNegativeV4Variance = false
        var sawPositiveV4Variance = false
        for seed in 1...64 {
            let resolved = try engine.resolveDraft(.init(
                seed: String(seed), state: prepared.snapshot
            )).snapshot
            let draft = try XCTUnwrap(resolved.draftResult)
            let delta = draft.evaluationScore - currentForecast.score
            var generator = SplitMix64(seed: UInt64(seed) ^ 0x4452_4146_5400)
            let expected = HighSchoolCareerEngine.draftVariance(
                balanceVersion: prepared.snapshot.balanceVersion,
                roll: generator.nextInt(upperBound: 5)
            )
            XCTAssertEqual(delta, expected)
            XCTAssertLessThanOrEqual(abs(delta), 1)
            XCTAssertEqual(draft.outcome == .drafted, draft.evaluationScore >= currentForecast.threshold)
            sawNegativeV4Variance = sawNegativeV4Variance || delta == -1
            sawPositiveV4Variance = sawPositiveV4Variance || delta == 1
        }
        XCTAssertTrue(sawNegativeV4Variance)
        XCTAssertTrue(sawPositiveV4Variance)
    }

    func testV4ExtremeAutoRecordsRemainMonotonicWithinTheTwoPointSeasonCap() throws {
        let engine = HighSchoolCareerEngine()
        let prepared = try careerBeforeDraft(engine: engine, seed: "918223")
        let dominant = try rewritingState(prepared.snapshot) { object in
            var lines = try XCTUnwrap(object["seasonLog"] as? [[String: Any]])
            for index in lines.indices where lines[index]["played"] as? Bool == false {
                lines[index]["runsAllowed"] = 0
            }
            object["seasonLog"] = lines
        }
        let struggling = try rewritingState(prepared.snapshot) { object in
            var lines = try XCTUnwrap(object["seasonLog"] as? [[String: Any]])
            for index in lines.indices where lines[index]["played"] as? Bool == false {
                lines[index]["runsAllowed"] = 20
            }
            object["seasonLog"] = lines
        }

        let dominantTerm = HighSchoolCareerEngine.draftEvaluationCore(state: dominant).seasonTerm
        let neutralTerm = HighSchoolCareerEngine.draftEvaluationCore(state: prepared.snapshot).seasonTerm
        let strugglingTerm = HighSchoolCareerEngine.draftEvaluationCore(state: struggling).seasonTerm
        XCTAssertEqual(dominantTerm, 2)
        XCTAssertEqual(strugglingTerm, -2)
        XCTAssertGreaterThan(dominantTerm, neutralTerm)
        XCTAssertGreaterThan(neutralTerm, strugglingTerm)
    }

    func testV3ImportantGameDoesNotApplyV4GrowthOrSequenceTrust() throws {
        let engine = HighSchoolCareerEngine()
        let prepared = try firstImportantGame(engine: engine, seed: "918222")
        let v3 = try replacingBalanceVersion(3, in: prepared.snapshot)
        let report = ImportantInningReport(
            scenarioNumber: v3.performance.importantGamesCompleted + 1,
            pitches: 12,
            strikeouts: 3,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 600,
            actualDamage: 200,
            recommendationAccepted: 10,
            outs: 3,
            sequenceMasteryCount: 5
        )
        XCTAssertNil(CareerGameGrowth.evaluating(state: v3, report: report))
        let settled = try engine.recordImportantGame(.init(
            seed: prepared.nextSeed, state: v3, report: report
        ))
        XCTAssertEqual(settled.snapshot.pitcher, v3.pitcher)
        XCTAssertEqual(settled.snapshot.managerTrust, v3.managerTrust)
        XCTAssertEqual(settled.snapshot.catcherTrust, v3.catcherTrust)
        XCTAssertEqual(settled.snapshot.relationshipTrust, v3.relationshipTrust)
        XCTAssertFalse(settled.events.flatMap(\.reasonCodes).contains("pitch_sequence.mastery_trust"))
        XCTAssertFalse(settled.events.flatMap(\.reasonCodes).contains { $0.hasPrefix("game_growth.") })
        XCTAssertFalse(settled.snapshot.news.contains { $0.hasPrefix("수싸움 적중") })
    }

    func testSignatureLegacySelectionIsExclusiveAndLegacyParamsStayCompatible() throws {
        let engine = HighSchoolCareerEngine()
        let completed = try commandFocusedCareer(seed: "918209").finalState
        let legacyState: HighSchoolCareerSnapshot
        if completed.phase == .completed {
            legacyState = try engine.openLegacy(.init(seed: "918210", state: completed)).snapshot
        } else {
            XCTAssertEqual(completed.phase, .legacy)
            legacyState = completed
        }

        let oldCards = Array(legacyState.legacyOptions.prefix(legacyState.memorySlots))
        XCTAssertEqual(oldCards.count, legacyState.memorySlots)
        let oldParams = SelectCareerLegacyParams(
            seed: "918211", state: legacyState, memoryCards: oldCards
        )
        XCTAssertNil(oldParams.signatureLegacyID)
        let oldData = try JSONEncoder().encode(oldParams)
        let oldObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: oldData) as? [String: Any]
        )
        XCTAssertNil(oldObject["signatureLegacyID"])
        let decodedOld = try JSONDecoder().decode(SelectCareerLegacyParams.self, from: oldData)
        XCTAssertEqual(decodedOld, oldParams)

        let oldSelection = try engine.selectLegacy(decodedOld)
        XCTAssertEqual(oldSelection.snapshot.phase, .completed)
        XCTAssertEqual(Set(oldSelection.snapshot.selectedMemories), Set(oldCards))
        XCTAssertEqual(
            Set(oldSelection.events.flatMap(\.reasonCodes)),
            Set(oldCards.map { "memory.\($0.rawValue)" })
        )

        let signatureSelection = try engine.selectLegacy(.init(
            seed: "918212",
            state: legacyState,
            memoryCards: [],
            signatureLegacyID: .breakingTrace
        ))
        XCTAssertEqual(signatureSelection.snapshot.phase, .completed)
        XCTAssertTrue(signatureSelection.snapshot.legacyOptions.isEmpty)
        XCTAssertTrue(signatureSelection.snapshot.selectedMemories.isEmpty)
        XCTAssertEqual(
            signatureSelection.events.flatMap(\.reasonCodes),
            ["signature_legacy.breaking_trace"]
        )

        XCTAssertThrowsError(try engine.selectLegacy(.init(
            seed: "918213",
            state: legacyState,
            memoryCards: [try XCTUnwrap(oldCards.first)],
            signatureLegacyID: .breakingTrace
        )))
        XCTAssertThrowsError(try engine.selectLegacy(.init(
            seed: "918214", state: legacyState, memoryCards: []
        )), "nil signature keeps the exact legacy memory-slot validation")
    }

    func testGameGrowthUsesOneDeterministicPriorityAndEngineAppliesSameResult() throws {
        let engine = HighSchoolCareerEngine()
        let game = try firstImportantGame(engine: engine, seed: "918204")
        let state = game.snapshot
        let report = ImportantInningReport(
            scenarioNumber: state.performance.importantGamesCompleted + 1,
            pitches: 18,
            strikeouts: 4,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 480,
            actualDamage: 160,
            recommendationAccepted: 12,
            outs: 3,
            sequenceMasteryCount: 4
        )

        let first = try XCTUnwrap(CareerGameGrowth.evaluating(state: state, report: report))
        let second = CareerGameGrowth.evaluating(state: state, report: report)
        XCTAssertEqual(first, second)
        let expectedStrength: TalentAbility = state.pitcher.stuff >= state.pitcher.movement
            ? .stuff : .movement
        XCTAssertEqual(first.ability, expectedStrength, "삼진 호투는 긴 이닝·수싸움보다 먼저 적용되어야 합니다.")
        XCTAssertTrue([.strikeoutStuff, .strikeoutMovement].contains(first.reason))
        XCTAssertEqual(first.points, 1)
        XCTAssertLessThanOrEqual(first.points, 1)

        let settled = try engine.recordImportantGame(.init(
            seed: game.nextSeed, state: state, report: report
        ))
        XCTAssertEqual(settled.snapshot.pitcher, first.applying(to: state.pitcher))
        XCTAssertEqual(settled.snapshot.talent, first.resultingTalent)
        XCTAssertTrue(settled.events.flatMap(\.reasonCodes).contains(first.reasonCode))
        XCTAssertTrue(settled.snapshot.news.contains { $0.contains(first.title) })
    }

    func testGameGrowthBranchesUseActualStrengthAndOrdinaryLineGetsNoFreePoint() throws {
        let engine = HighSchoolCareerEngine()
        let game = try firstImportantGame(engine: engine, seed: "918205")
        let state = game.snapshot
        let number = state.performance.importantGamesCompleted + 1

        let ordinary = ImportantInningReport(
            scenarioNumber: number, pitches: 18, strikeouts: 3, walks: 2, runsAllowed: 2,
            expectedDamage: 720, actualDamage: 700, recommendationAccepted: 6
        )
        XCTAssertNil(
            CareerGameGrowth.evaluating(state: state, report: ordinary),
            "40-seed ordinary draft calibration policy must remain growth-neutral."
        )

        let automaticCall = ImportantInningReport(
            scenarioNumber: number, pitches: 8, strikeouts: 1, walks: 0, runsAllowed: 1,
            expectedDamage: 500, actualDamage: 250, recommendationAccepted: 8,
            outs: 2, sequenceMasteryCount: 3
        )
        XCTAssertNil(
            CareerGameGrowth.evaluating(state: state, report: automaticCall),
            "권장 사인 수행만으로 보상하거나 수싸움 경계를 낮추면 안 됩니다."
        )

        let sequence = ImportantInningReport(
            scenarioNumber: number, pitches: 8, strikeouts: 1, walks: 0, runsAllowed: 1,
            expectedDamage: 500, actualDamage: 250, recommendationAccepted: 8,
            outs: 2, sequenceMasteryCount: 4
        )
        let sequenceGrowth = try XCTUnwrap(CareerGameGrowth.evaluating(state: state, report: sequence))
        XCTAssertEqual(sequenceGrowth.ability, .command)
        XCTAssertEqual(sequenceGrowth.reason, .sequenceCommand)

        let shortCompleteInning = ImportantInningReport(
            scenarioNumber: number, pitches: 8, strikeouts: 1, walks: 1, runsAllowed: 1,
            expectedDamage: 600, actualDamage: 400, recommendationAccepted: 0, outs: 3
        )
        XCTAssertNil(CareerGameGrowth.evaluating(state: state, report: shortCompleteInning))

        // PitchSession은 이닝 종료 즉시 끝나므로 live 고교 등판의 outsRecorded 상한은 3이다.
        // 같은 완결 이닝이라도 9구 이상을 책임졌을 때만 긴 호흡으로 본다.
        let longOuting = ImportantInningReport(
            scenarioNumber: number, pitches: 9, strikeouts: 1, walks: 1, runsAllowed: 1,
            expectedDamage: 600, actualDamage: 400, recommendationAccepted: 0, outs: 3
        )
        let staminaGrowth = try XCTUnwrap(CareerGameGrowth.evaluating(state: state, report: longOuting))
        XCTAssertEqual(staminaGrowth.ability, .stamina)
        XCTAssertEqual(staminaGrowth.reason, .longOuting)
        XCTAssertLessThanOrEqual(staminaGrowth.points, 1)

        let breakingGame = try firstImportantGame(
            engine: engine,
            seed: "918208",
            presetID: "breaking_ball_artist",
            trainingFocus: .breakingBall
        )
        let breakingState = breakingGame.snapshot
        XCTAssertGreaterThan(breakingState.pitcher.movement, breakingState.pitcher.stuff)
        let breakingStrikeout = ImportantInningReport(
            scenarioNumber: breakingState.performance.importantGamesCompleted + 1,
            pitches: 9, strikeouts: 2, walks: 1, runsAllowed: 1,
            expectedDamage: 500, actualDamage: 250, recommendationAccepted: 0, outs: 2
        )
        let movementGrowth = try XCTUnwrap(
            CareerGameGrowth.evaluating(state: breakingState, report: breakingStrikeout)
        )
        XCTAssertEqual(movementGrowth.ability, .movement)
        XCTAssertEqual(movementGrowth.reason, .strikeoutMovement)
    }

    func testTalentlessLegacySaveKeepsPreGameGrowthIdentity() throws {
        let engine = HighSchoolCareerEngine()
        let game = try firstImportantGame(engine: engine, seed: "918206")
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(game.snapshot)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "talent")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacyState = try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: legacyData)
        XCTAssertNil(legacyState.talent)

        let report = ImportantInningReport(
            scenarioNumber: legacyState.performance.importantGamesCompleted + 1,
            pitches: 18,
            strikeouts: 4,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 480,
            actualDamage: 160,
            recommendationAccepted: 12,
            outs: 3,
            sequenceMasteryCount: 2
        )
        XCTAssertNil(CareerGameGrowth.evaluating(state: legacyState, report: report))
        let settled = try engine.recordImportantGame(.init(
            seed: game.nextSeed, state: legacyState, report: report
        ))
        XCTAssertEqual(settled.snapshot.pitcher, legacyState.pitcher)
        XCTAssertFalse(settled.events.flatMap(\.reasonCodes).contains { $0.hasPrefix("game_growth.") })
    }

    private func careerBeforeDraft(
        engine: HighSchoolCareerEngine,
        seed: String
    ) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower
        ))
        for _ in 0..<220 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: .velocity,
                    intensity: .standard
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 12,
                        strikeouts: 2,
                        walks: 0,
                        runsAllowed: 1,
                        expectedDamage: 500,
                        actualDamage: 400,
                        recommendationAccepted: 8,
                        outs: 3,
                        sequenceMasteryCount: 3
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
                XCTFail("드래프트 전 상태를 만들기 전에 예상하지 못한 단계에 도달했습니다.")
                return result
            }
        }
        XCTFail("드래프트 전 상태에 도달하지 못했습니다.")
        return result
    }

    private func relationshipScene(
        _ category: String,
        engine: HighSchoolCareerEngine,
        seed: String,
        schoolID: SchoolID
    ) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: seed, presetID: "power_prospect"))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot, schoolID: schoolID
        ))
        for _ in 0..<100 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: result.snapshot.trainingOpportunity?.focus ?? .command,
                    intensity: .standard
                ))
            case .relationship:
                if result.snapshot.currentRelationshipEvent?.category == category {
                    return result
                }
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 10,
                        strikeouts: 1,
                        walks: 0,
                        runsAllowed: 1,
                        expectedDamage: 400,
                        actualDamage: 400,
                        recommendationAccepted: 6,
                        outs: 3,
                        sequenceMasteryCount: 0
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
            case .draft, .legacy, .completed, .prologue, .schoolSelection:
                XCTFail("\(category) 관계 장면 전 예상하지 못한 단계에 도달했습니다.")
                return result
            }
        }
        XCTFail("\(category) 관계 장면에 도달하지 못했습니다.")
        return result
    }

    private func replacingBalanceVersion(
        _ balanceVersion: Int,
        in state: HighSchoolCareerSnapshot
    ) throws -> HighSchoolCareerSnapshot {
        try rewritingState(state) { object in
            object["balanceVersion"] = balanceVersion
        }
    }

    private func rewritingState(
        _ state: HighSchoolCareerSnapshot,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> HighSchoolCareerSnapshot {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(state)) as? [String: Any]
        )
        try mutate(&object)
        object["stateCommitment"] = ""
        let unsigned = try decoder.decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["stateCommitment"] = testCommitment(for: unsigned)
        return try decoder.decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func testCommitment(for state: HighSchoolCareerSnapshot) -> String {
        let school = state.school?.id.rawValue ?? "none"
        let ratings = "\(state.pitcher.stuff):\(state.pitcher.command):\(state.pitcher.movement):\(state.pitcher.stamina)"
        let performance = "\(state.performance.importantGamesCompleted):\(state.performance.pitches):\(state.performance.strikeouts):\(state.performance.walks):\(state.performance.runsAllowed):\(state.performance.expectedDamage):\(state.performance.actualDamage)"
        let scenario = state.currentGameScenario?.id ?? "none"
        let draft = state.draftResult.map { "\($0.outcome.rawValue):\($0.evaluationScore):\($0.team?.id ?? "none")" } ?? "none"
        var canonical: [String] = [
            state.careerID, String(state.revision), state.phase.rawValue,
            state.identity.name, state.identity.throwingHand.rawValue,
            state.identity.bodyType.rawValue, state.identity.region, school,
            state.difficulty.careerHarshness.rawValue,
            state.difficulty.informationClarity.rawValue,
            state.difficulty.simulationDifficulty.rawValue,
            state.difficulty.interventionAssist.rawValue,
            state.karmas.map(\.rawValue).joined(separator: ","),
            String(state.legacyRewardPermille), String(state.memorySlots),
            String(state.chapter.number), String(state.chapterTrainingCount),
            String(state.totalTrainingsCompleted), String(state.milestoneIndex),
            String(state.relationshipsCompleted), String(state.relationshipTrust),
            state.selectedAwakenings.map(\.rawValue).joined(separator: ","),
            state.awakeningOptions.map(\.rawValue).joined(separator: ","),
            String(state.fatigue), ratings, performance, scenario, draft,
            state.legacyOptions.map(\.rawValue).joined(separator: ","),
            state.selectedMemories.map(\.rawValue).joined(separator: ","),
        ]
        if state.rivalTrust != nil {
            canonical.append(
                "relationships:\(state.managerTrust ?? state.relationshipTrust):\(state.catcherTrust ?? state.relationshipTrust):\(state.rivalTrust ?? state.relationshipTrust)"
            )
        } else if state.managerTrust != nil || state.catcherTrust != nil {
            canonical.append(
                "staff:\(state.managerTrust ?? state.relationshipTrust):\(state.catcherTrust ?? state.relationshipTrust)"
            )
        }
        if let balanceVersion = state.balanceVersion {
            canonical.append("balance_version:\(balanceVersion)")
        }
        if let worldRulesVersion = state.worldRulesVersion {
            canonical.append("world_rules_version:\(worldRulesVersion)")
        }
        if let armRisk = state.armRisk { canonical.append("arm_risk:\(armRisk)") }
        if let injuryRecovery = state.injuryRecovery {
            canonical.append("injury_recovery:\(injuryRecovery)")
        }
        if let awakeningSparks = state.awakeningSparks {
            canonical.append("awakening_sparks:\(awakeningSparks)")
        }
        if let soulBoosts = state.soulBoosts, !soulBoosts.isEmpty {
            canonical.append("soul_boosts:\(soulBoosts.joined(separator: ","))")
        }
        if let schedule = state.schedule {
            canonical.append("schedule:\(schedule.commitmentToken)")
        }
        if let relationship = state.lastRelationship {
            let values: [String] = [
                "last_relationship", String(relationship.number), relationship.category,
                relationship.title, relationship.response.rawValue,
                String(relationship.trustBefore), String(relationship.trustAfter),
                String(relationship.fatigueBefore), String(relationship.fatigueAfter),
                String(relationship.fanInterestBefore), String(relationship.fanInterestAfter),
                relationship.growthFocus?.rawValue ?? "none",
                relationship.abilityBefore.map(String.init) ?? "none",
                relationship.abilityAfter.map(String.init) ?? "none",
                relationship.feedback, "current_fan_interest", String(state.fanInterest),
            ]
            canonical.append(values.joined(separator: ":"))
        }
        return StableHash.fnv1a64(canonical.joined(separator: "|"))
    }

    private func firstImportantGame(
        engine: HighSchoolCareerEngine,
        seed: String,
        presetID: String = "power_prospect",
        trainingFocus: TrainingFocus = .velocity
    ) throws -> HighSchoolCareerResult {
        var result = try engine.start(.init(seed: seed, presetID: presetID))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower
        ))
        for _ in 0..<100 where result.snapshot.phase != .importantGame {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot, focus: trainingFocus, intensity: .light
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
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
        return result
    }

    private func commandFocusedCareer(
        seed: String
    ) throws -> (startingPitcher: PitcherSnapshot, finalState: HighSchoolCareerSnapshot) {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: seed, presetID: "precision_commander"))
        let startingPitcher = result.snapshot.pitcher
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot, schoolID: .miraeAnalytics
        ))

        let commandAwakenings: [AwakeningID] = [
            .pinpointEdge, .repeatableRelease, .firstPitchStrike, .scoutComposure, .batterySync
        ]
        for _ in 0..<180 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    focus: .gamePlanning, intensity: .intensive
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number, pitches: 18, strikeouts: 4, walks: 0,
                        runsAllowed: 0, expectedDamage: 420, actualDamage: 160,
                        recommendationAccepted: 12, outs: 3
                    )
                ))
            case .awakening:
                let selected = commandAwakenings.first { result.snapshot.awakeningOptions.contains($0) }
                    ?? result.snapshot.awakeningOptions.first
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    awakening: try XCTUnwrap(selected)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft:
                result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
            case .legacy, .completed:
                return (startingPitcher, result.snapshot)
            case .prologue, .schoolSelection:
                XCTFail("학교 선택 뒤 되돌아가면 안 됩니다.")
                return (startingPitcher, result.snapshot)
            }
        }
        XCTFail("대표 유산 후보를 만들기 전에 회차가 끝나지 않았습니다.")
        return (startingPitcher, result.snapshot)
    }

    private func makeProCareer(
        highSchoolState: HighSchoolCareerSnapshot,
        pitcher: PitcherSnapshot,
        stats: [ProSeasonStats],
        awards: [String]
    ) -> ProCareerSnapshot {
        let team = HighSchoolCareerEngine.teams[0]
        return ProCareerSnapshot(
            proCareerID: "pro-signature-test",
            revision: 100,
            phase: .completed,
            identity: highSchoolState.identity,
            pitcher: pitcher,
            team: team,
            entitlement: .init(
                status: .active,
                source: .development,
                verifiedAt: "2026-08-09T00:00:00Z"
            ),
            age: 37,
            season: stats.last?.season ?? 1,
            week: 24,
            level: .major,
            role: .starter,
            managerTrust: 82,
            catcherTrust: 86,
            fatigue: 0,
            injuryWeeks: 0,
            serviceYears: stats.count,
            militaryCompleted: true,
            contract: nil,
            currentStats: stats.last ?? .init(season: 1, teamID: team.id),
            careerStats: stats,
            awards: awards,
            milestones: ["프로 은퇴"],
            news: [],
            hallOfFameScore: 75,
            commitment: "test"
        )
    }
}
