import Foundation
import XCTest
@testable import SimulationCore

final class ProCareerEngineTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testLockedOrUndraftedPlayerCannotStartProCareer() throws {
        let locked = startParams(seed: "1", entitlement: .init(status: .locked, source: .development, verifiedAt: "2026-07-22"))
        XCTAssertThrowsError(try engine.start(locked))
        let undrafted = DraftResultSnapshot(outcome: .undrafted, evaluationScore: 45, projectedRange: "미지명", team: nil, round: nil, overallPick: nil, signingBonus: nil, firstSeasonGoal: nil, summary: "")
        XCTAssertThrowsError(try engine.start(.init(seed: "1", identity: .defaultPitcher, pitcher: pitcher(), draftResult: undrafted, entitlement: activeEntitlement())))
    }

    func testThreeSeasonProDebutSlicePreservesStatsAndReachesMajorLeague() throws {
        var result = try engine.start(startParams(seed: "7"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 1...3 {
            result = try playSeason(result)
            XCTAssertEqual(result.snapshot.phase, .offseasonDecision)
            if result.snapshot.season < 3 {
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            }
        }
        XCTAssertEqual(result.snapshot.careerStats.count, 3)
        XCTAssertEqual(result.snapshot.level, .major)
        // 커널 통일 뒤 games는 팀 경기 수가 아니라 실제 등판 수다(주당 1~3회).
        let seasons = result.snapshot.careerStats
        let outs = seasons.reduce(0) { $0 + $1.inningsOuts }
        let strikeouts = seasons.reduce(0) { $0 + $1.strikeouts }
        let runs = seasons.reduce(0) { $0 + $1.runsAllowed }
        XCTAssertGreaterThan(seasons.reduce(0) { $0 + $1.games }, 45)
        XCTAssertGreaterThan(outs, 700, "3시즌 커리어면 80이닝/시즌은 넘어야 한다")
        XCTAssertGreaterThan(strikeouts, 0)
        XCTAssertGreaterThanOrEqual(runs, 0)
        XCTAssertFalse(result.snapshot.news.isEmpty)
    }

    func testTwentySeasonCareersCompleteForSeeds100Through104() throws {
        try assertCompletedCareers(in: 100..<105, replaySeed: 100)
    }

    func testTwentySeasonCareersCompleteForSeeds105Through109() throws {
        try assertCompletedCareers(in: 105..<110)
    }

    func testTwentySeasonCareersCompleteForSeeds110Through114() throws {
        try assertCompletedCareers(in: 110..<115)
    }

    func testTwentySeasonCareersCompleteForSeeds115Through119() throws {
        try assertCompletedCareers(in: 115..<120)
    }

    // Phase 3-2: 중요 경기는 더 이상 고정 주차 [3,7,12,18,23]가 아니라 상황 트리거로 발동한다.
    // 이 테스트는 갱신된 의도(동적 발동 + 라이벌/트리거/구간 노출 + 마일스톤 진행)를 검증한다.
    func testDynamicImportantGamesExposeRivalTriggerAndSegment() throws {
        var result = try engine.start(startParams(seed: "77"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        // 시즌 시작 시 "올해의 세 가지 긴장"이 결정론적으로 생성돼 노출된다.
        XCTAssertEqual(result.snapshot.seasonTensions?.count, 3)
        var importantWeeks: [Int] = []
        var seenTriggers: Set<ProSeasonTrigger> = []
        while result.snapshot.phase != .seasonReview {
            // 구간 라벨은 매 주차 스냅숏에 노출된다.
            XCTAssertNotNil(result.snapshot.seasonSegment)
            if result.snapshot.phase == .importantGame {
                importantWeeks.append(result.snapshot.week)
                let rival = try XCTUnwrap(result.snapshot.currentRival, "중요 경기에는 라이벌 타자가 있어야 한다")
                XCTAssertNotEqual(rival.teamID, result.snapshot.team.id, "라이벌은 상대 구단 소속이어야 한다")
                seenTriggers.insert(try XCTUnwrap(result.snapshot.seasonTrigger))
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
                // 경기 해소 뒤 라이벌/트리거는 정리된다.
                XCTAssertNil(result.snapshot.currentRival)
                XCTAssertNil(result.snapshot.seasonTrigger)
            } else if result.snapshot.phase == .seasonDecision {
                result = try resolvePendingDecision(result)
            } else {
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            }
        }
        // 옛 고정 주차 집합과 정확히 일치하지 않는다.
        XCTAssertNotEqual(Set(importantWeeks), Set([3, 7, 12, 18, 23]))
        // 시즌당 4~6회가 자연 발생한다.
        XCTAssertTrue((4...6).contains(importantWeeks.count), "시즌 중요 경기 \(importantWeeks.count)회는 4~6 범위를 벗어난다")
        XCTAssertGreaterThanOrEqual(seenTriggers.count, 2, "서로 다른 트리거가 섞여야 한다")
        XCTAssertTrue(result.snapshot.milestones.contains("프로 첫 공식 등판"))
        XCTAssertTrue(result.snapshot.milestones.contains("1군 콜업"))
    }

    func testImportantGameCountStaysWithinFourToSixAcrossSeasons() throws {
        var result = try engine.start(startParams(seed: "31"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for season in 1...5 {
            var count = 0
            while result.snapshot.phase != .seasonReview {
                if result.snapshot.phase == .importantGame {
                    count += 1
                    result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
                } else if result.snapshot.phase == .seasonDecision {
                    result = try resolvePendingDecision(result)
                } else {
                    let plan: ProWeekPlan = result.snapshot.fatigue > 72 ? .recover : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                    result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
                }
            }
            XCTAssertTrue((4...6).contains(count), "시즌 \(season) 중요 경기 \(count)회는 4~6 범위를 벗어난다")
            result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
        }
    }

    func testSameSeedProducesSameImportantWeeksAndRivals() throws {
        func trace(_ seed: String) throws -> [String] {
            var result = try engine.start(startParams(seed: seed))
            result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
            var log: [String] = []
            for _ in 1...2 {
                while result.snapshot.phase != .seasonReview {
                    if result.snapshot.phase == .importantGame {
                        let rival = result.snapshot.currentRival?.id ?? "-"
                        let trigger = result.snapshot.seasonTrigger?.rawValue ?? "-"
                        log.append("s\(result.snapshot.season)w\(result.snapshot.week):\(trigger):\(rival)")
                        result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
                    } else if result.snapshot.phase == .seasonDecision {
                        let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                        log.append("decision:s\(decision.season)w\(decision.week):\(decision.type.rawValue)")
                        result = try resolvePendingDecision(result)
                    } else {
                        result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
                    }
                }
                log.append("tensions:" + (result.snapshot.seasonTensions?.map(\.title).joined(separator: "|") ?? "-"))
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            }
            return log
        }
        let first = try trace("909")
        let second = try trace("909")
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.filter { $0.hasPrefix("s") }.isEmpty, "중요 경기가 최소 한 번은 있어야 한다")
        // 다른 시드는 다른 전개를 준다.
        XCTAssertNotEqual(try trace("909"), try trace("910"))
    }

    func testLegacySaveWithoutArcFieldsDecodesAndBackfills() throws {
        // 새 아크 필드가 없는 구세이브를 흉내낸다: 엔진이 만든 스냅숏 JSON에서 신규 키를 제거한다.
        var result = try engine.start(startParams(seed: "48"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
        while result.snapshot.phase != .weeklyPlan {
            result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
        }

        let encoded = try JSONEncoder().encode(result.snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["seasonSegment", "seasonTrigger", "currentRival", "seasonTensions", "seasonImportantGames", "pendingDecision", "decisionHistory"] {
            object.removeValue(forKey: key)
        }
        // 실제 구버전 저장의 서명에는 당시 존재하지 않던 필드가 들어가지 않았다.
        // 현재 스냅숏의 서명을 그대로 둔 채 키만 제거하면 존재할 수 없는 위조 데이터를 만든다.
        object["commitment"] = ""
        let unsignedLegacy = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        object["commitment"] = engine.commitment(unsignedLegacy)
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let legacy = try JSONDecoder().decode(ProCareerSnapshot.self, from: stripped)

        // 구세이브는 신규 필드가 nil로 디코드되고, commitment는 여전히 유효하다.
        XCTAssertNil(legacy.seasonSegment)
        XCTAssertNil(legacy.seasonTensions)
        XCTAssertNil(legacy.seasonImportantGames)
        XCTAssertNil(legacy.currentRival)
        XCTAssertNil(legacy.pendingDecision)
        XCTAssertNil(legacy.decisionHistory)

        // 크래시 없이 이어서 진행되고, 아크 필드가 결정론적으로 백필된다.
        let resumed = try engine.planWeek(.init(seed: result.nextSeed, state: legacy, plan: .refineCommand))
        XCTAssertNotNil(resumed.snapshot.seasonSegment)
        XCTAssertEqual(resumed.snapshot.seasonTensions?.count, 3)
        XCTAssertNotNil(resumed.snapshot.seasonImportantGames)
    }

    func testSeasonDecisionCatalogIsDeterministicAndAlwaysShowsThreeExactChoices() throws {
        var result = try engine.start(startParams(seed: "610"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))

        let first = ProCareerEngine.seasonDecisionWeeks.compactMap {
            engine.seasonDecision(for: result.snapshot, week: $0)
        }
        let second = ProCareerEngine.seasonDecisionWeeks.compactMap {
            engine.seasonDecision(for: result.snapshot, week: $0)
        }

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, ProCareerEngine.maximumSeasonDecisions)
        XCTAssertEqual(Set(first.map(\.type)), Set(ProSeasonDecisionType.allCases))
        for decision in first {
            XCTAssertEqual(decision.choices.count, 3)
            XCTAssertEqual(Set(decision.choices.map(\.id)).count, 3)
            XCTAssertTrue(decision.choices.allSatisfy { !$0.detail.isEmpty && !$0.effect.summary.isEmpty })
        }
    }

    func testScheduledDecisionStopsWeeklyAdvanceAndAppliesOnlyConfirmedChoice() throws {
        let pendingResult = try firstDecision(seed: "611")
        let pending = try XCTUnwrap(pendingResult.snapshot.pendingDecision)
        XCTAssertEqual(pendingResult.snapshot.phase, .seasonDecision)
        XCTAssertTrue(ProCareerEngine.seasonDecisionWeeks.contains(pendingResult.snapshot.week))
        XCTAssertEqual(pendingResult.snapshot.injuryWeeks, 0)
        XCTAssertNil(pendingResult.snapshot.seasonTrigger)
        XCTAssertNil(pendingResult.snapshot.currentRival)
        XCTAssertThrowsError(try engine.planWeek(.init(seed: pendingResult.nextSeed, state: pendingResult.snapshot, plan: .earnTrust)))

        let choice = pending.choices[0]
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: pendingResult.nextSeed,
            state: pendingResult.snapshot,
            decisionID: "stale-decision",
            choiceID: choice.id
        )))
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: pendingResult.nextSeed,
            state: pendingResult.snapshot,
            decisionID: pending.id,
            choiceID: "missing-choice"
        )))

        let before = pendingResult.snapshot
        let applied = try engine.applySeasonDecision(.init(
            seed: pendingResult.nextSeed,
            state: before,
            decisionID: pending.id,
            choiceID: choice.id
        ))
        XCTAssertEqual(applied.snapshot.phase, .weeklyPlan)
        XCTAssertNil(applied.snapshot.pendingDecision)
        XCTAssertEqual(applied.nextSeed, pendingResult.nextSeed, "수치 적용은 RNG를 소비하지 않는다")
        XCTAssertEqual(applied.snapshot.pitcher.stuff, clampedAbility(before.pitcher.stuff + choice.effect.stuffDelta))
        XCTAssertEqual(applied.snapshot.pitcher.command, clampedAbility(before.pitcher.command + choice.effect.commandDelta))
        XCTAssertEqual(applied.snapshot.pitcher.movement, clampedAbility(before.pitcher.movement + choice.effect.movementDelta))
        XCTAssertEqual(applied.snapshot.pitcher.stamina, clampedAbility(before.pitcher.stamina + choice.effect.staminaDelta))
        XCTAssertEqual(applied.snapshot.managerTrust, min(100, max(0, before.managerTrust + choice.effect.managerTrustDelta)))
        XCTAssertEqual(applied.snapshot.catcherTrust, min(100, max(0, before.catcherTrust + choice.effect.catcherTrustDelta)))
        XCTAssertEqual(applied.snapshot.fatigue, min(100, max(0, before.fatigue + choice.effect.fatigueDelta)))
        XCTAssertEqual(applied.snapshot.role, choice.effect.roleTarget ?? before.role)
        let record = try XCTUnwrap(applied.snapshot.decisionHistory?.last)
        XCTAssertEqual(record.decisionID, pending.id)
        XCTAssertEqual(record.choiceID, choice.id)
        XCTAssertEqual(record.effect, choice.effect)
    }

    func testPendingDecisionSaveResumeProducesIdenticalApplication() throws {
        let pendingResult = try firstDecision(seed: "612")
        let encoded = try JSONEncoder().encode(pendingResult.snapshot)
        let resumedState = try JSONDecoder().decode(ProCareerSnapshot.self, from: encoded)
        XCTAssertEqual(resumedState, pendingResult.snapshot)
        let decision = try XCTUnwrap(resumedState.pendingDecision)
        let choice = decision.choices[1]

        let uninterrupted = try engine.applySeasonDecision(.init(
            seed: pendingResult.nextSeed,
            state: pendingResult.snapshot,
            decisionID: decision.id,
            choiceID: choice.id
        ))
        let resumed = try engine.applySeasonDecision(.init(
            seed: pendingResult.nextSeed,
            state: resumedState,
            decisionID: decision.id,
            choiceID: choice.id
        ))
        XCTAssertEqual(uninterrupted, resumed)
    }

    func testDecisionPhaseRequiresPendingAndOtherPhasesRejectIt() throws {
        let result = try firstDecision(seed: "614")
        let decision = try XCTUnwrap(result.snapshot.pendingDecision)
        let choice = decision.choices[0]
        let encoded = try JSONEncoder().encode(result.snapshot)
        var missingObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        missingObject.removeValue(forKey: "pendingDecision")
        let missing = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: missingObject)
        )
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: missing,
            decisionID: decision.id,
            choiceID: choice.id
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("season decision phase and pending decision must match"))
        }

        var unexpectedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        unexpectedObject["phase"] = ProCareerPhase.weeklyPlan.rawValue
        let unexpected = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: unexpectedObject)
        )
        XCTAssertThrowsError(try engine.planWeek(.init(
            seed: result.nextSeed,
            state: unexpected,
            plan: .recover
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("season decision phase and pending decision must match"))
        }

        var offseasonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        offseasonObject["phase"] = ProCareerPhase.offseasonDecision.rawValue
        let unexpectedOffseason = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: offseasonObject)
        )
        XCTAssertThrowsError(try engine.chooseOffseason(.init(
            seed: result.nextSeed,
            state: unexpectedOffseason,
            decision: .continueCareer
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("season decision phase and pending decision must match"))
        }
    }

    func testPendingDecisionRejectsMismatchedWeekAndNonUniqueChoiceSet() throws {
        let result = try firstDecision(seed: "615")
        let decision = try XCTUnwrap(result.snapshot.pendingDecision)
        let choice = decision.choices[0]
        let encoded = try JSONEncoder().encode(result.snapshot)

        var weekObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var weekPending = try XCTUnwrap(weekObject["pendingDecision"] as? [String: Any])
        weekPending["week"] = decision.week + 3
        weekObject["pendingDecision"] = weekPending
        let wrongWeek = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: weekObject)
        )
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: wrongWeek,
            decisionID: decision.id,
            choiceID: choice.id
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("pending decision season or week mismatch"))
        }

        var shortObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var shortPending = try XCTUnwrap(shortObject["pendingDecision"] as? [String: Any])
        var shortChoices = try XCTUnwrap(shortPending["choices"] as? [[String: Any]])
        shortChoices.removeLast()
        shortPending["choices"] = shortChoices
        shortObject["pendingDecision"] = shortPending
        let shortChoiceSet = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: shortObject)
        )
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: shortChoiceSet,
            decisionID: decision.id,
            choiceID: choice.id
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("pending decision requires three unique choices"))
        }

        var choiceObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var choicePending = try XCTUnwrap(choiceObject["pendingDecision"] as? [String: Any])
        var choices = try XCTUnwrap(choicePending["choices"] as? [[String: Any]])
        choices[1] = choices[0]
        choicePending["choices"] = choices
        choiceObject["pendingDecision"] = choicePending
        let duplicateChoice = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: choiceObject)
        )
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: duplicateChoice,
            decisionID: decision.id,
            choiceID: choice.id
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("pending decision requires three unique choices"))
        }
    }

    func testDecisionHistoryTamperingFailsConditionalCommitment() throws {
        let pendingResult = try firstDecision(seed: "616")
        let decision = try XCTUnwrap(pendingResult.snapshot.pendingDecision)
        let applied = try engine.applySeasonDecision(.init(
            seed: pendingResult.nextSeed,
            state: pendingResult.snapshot,
            decisionID: decision.id,
            choiceID: decision.choices[0].id
        ))
        let encoded = try JSONEncoder().encode(applied.snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var history = try XCTUnwrap(object["decisionHistory"] as? [[String: Any]])
        history[0]["choiceTitle"] = "변조된 선택"
        object["decisionHistory"] = history
        let tampered = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertThrowsError(try engine.planWeek(.init(
            seed: applied.nextSeed,
            state: tampered,
            plan: .recover
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("state commitment mismatch"))
        }
    }

    func testCommitmentValidOlderCatalogDecisionAppliesPersistedCopyAndEffectOnce() throws {
        let result = try firstDecision(seed: "617")
        let current = try XCTUnwrap(result.snapshot.pendingDecision)
        let persistedEffect = ProDecisionEffect(
            stuffDelta: 2, commandDelta: -1,
            managerTrustDelta: 9, catcherTrustDelta: 2, fatigueDelta: -5
        )
        let persistedChoice = ProSeasonDecisionChoice(
            id: current.choices[0].id,
            title: "이전 버전의 선택",
            detail: "그때 화면에서 확인한 설명입니다.",
            effect: persistedEffect
        )
        let persisted = ProSeasonDecision(
            id: current.id,
            type: current.type,
            season: current.season,
            week: current.week,
            title: "이전 버전의 갈림길",
            detail: "카탈로그가 바뀌기 전에 저장된 결정입니다.",
            choices: [persistedChoice] + Array(current.choices.dropFirst())
        )

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        object["pendingDecision"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(persisted))
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: unsigned,
            decisionID: persisted.id,
            choiceID: persistedChoice.id
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("state commitment mismatch"))
        }

        object["commitment"] = engine.commitment(unsigned)
        let signedOlderSave = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
        let applied = try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: signedOlderSave,
            decisionID: persisted.id,
            choiceID: persistedChoice.id
        ))

        XCTAssertEqual(applied.nextSeed, result.nextSeed)
        XCTAssertEqual(applied.snapshot.pitcher.stuff, clampedAbility(signedOlderSave.pitcher.stuff + 2))
        XCTAssertEqual(applied.snapshot.pitcher.command, clampedAbility(signedOlderSave.pitcher.command - 1))
        XCTAssertEqual(applied.snapshot.managerTrust, min(100, signedOlderSave.managerTrust + 9))
        XCTAssertEqual(applied.snapshot.catcherTrust, min(100, signedOlderSave.catcherTrust + 2))
        XCTAssertEqual(applied.snapshot.fatigue, max(0, signedOlderSave.fatigue - 5))
        XCTAssertEqual(applied.snapshot.decisionHistory?.last?.choiceTitle, persistedChoice.title)
        XCTAssertEqual(applied.snapshot.decisionHistory?.last?.effect, persistedEffect)
        XCTAssertEqual(applied.snapshot.news.first, "\(persisted.title) · \(persistedChoice.title) — \(persistedEffect.summary)")
        XCTAssertNil(applied.snapshot.pendingDecision)
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: applied.nextSeed,
            state: applied.snapshot,
            decisionID: persisted.id,
            choiceID: persistedChoice.id
        )))
    }

    func testSignedPendingDecisionStillRejectsOutOfRangePersistedEffect() throws {
        let result = try firstDecision(seed: "618")
        let current = try XCTUnwrap(result.snapshot.pendingDecision)
        let invalidChoice = ProSeasonDecisionChoice(
            id: current.choices[0].id,
            title: current.choices[0].title,
            detail: current.choices[0].detail,
            effect: .init(stuffDelta: 5)
        )
        let invalid = ProSeasonDecision(
            id: current.id, type: current.type, season: current.season, week: current.week,
            title: current.title, detail: current.detail,
            choices: [invalidChoice] + Array(current.choices.dropFirst())
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        object["pendingDecision"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(invalid))
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
        object["commitment"] = engine.commitment(unsigned)
        let signed = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
        XCTAssertThrowsError(try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: signed,
            decisionID: invalid.id,
            choiceID: invalidChoice.id
        ))) { error in
            XCTAssertEqual(error as? SimulationError, .invalidProCareer("pending decision effect is out of range"))
        }
    }

    func testSeasonDecisionWeeksAreUniqueAndNeverExceedSevenPerSeason() throws {
        var result = try engine.start(startParams(seed: "613"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        var openedWeeks: [Int] = []
        while result.snapshot.phase != .seasonReview {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .seasonDecision:
                XCTAssertEqual(result.snapshot.injuryWeeks, 0)
                XCTAssertNil(result.snapshot.seasonTrigger)
                openedWeeks.append(result.snapshot.week)
                result = try resolvePendingDecision(result)
            case .importantGame:
                XCTAssertNil(result.snapshot.pendingDecision, "중요 경기와 시즌 결정은 같은 주에 열리지 않는다")
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
            default:
                XCTFail("시즌 진행 중 예상하지 않은 phase: \(result.snapshot.phase)")
                return
            }
        }
        XCTAssertLessThanOrEqual(openedWeeks.count, ProCareerEngine.maximumSeasonDecisions)
        XCTAssertEqual(Set(openedWeeks).count, openedWeeks.count)
        XCTAssertTrue(openedWeeks.allSatisfy { ProCareerEngine.seasonDecisionWeeks.contains($0) })
        XCTAssertEqual(result.snapshot.decisionHistory?.filter { $0.season == 1 }.count, openedWeeks.count)
        XCTAssertNil(result.snapshot.pendingDecision, "시즌 전환에는 pending 결정을 남기지 않는다")
    }

    func testNilSequenceMasteryKeepsLegacyTrustFormula() throws {
        let game = try firstImportantGame(seed: "701")
        let value = report(game.snapshot.week, sequenceMasteryCount: nil)
        let resolved = try engine.resolveImportantGame(.init(seed: game.nextSeed, state: game.snapshot, report: value))
        let soundProcess = value.actualDamage <= value.expectedDamage + 150
            || value.recommendationAccepted * 2 >= value.pitches
        let expectedManager = min(100, max(0,
            game.snapshot.managerTrust + value.strikeouts * 2 - value.walks * 2
                - value.runsAllowed * 3 + (soundProcess ? 2 : 0)
        ))
        let expectedCatcher = min(100, max(0, game.snapshot.catcherTrust + (soundProcess ? 2 : -1)))
        XCTAssertEqual(resolved.snapshot.managerTrust, expectedManager)
        XCTAssertEqual(resolved.snapshot.catcherTrust, expectedCatcher)
    }

    func testZeroSequenceMasteryIsExactIdentityWithLegacyNil() throws {
        let game = try firstImportantGame(seed: "702")
        let legacy = try engine.resolveImportantGame(.init(
            seed: game.nextSeed,
            state: game.snapshot,
            report: report(game.snapshot.week, sequenceMasteryCount: nil)
        ))
        let zero = try engine.resolveImportantGame(.init(
            seed: game.nextSeed,
            state: game.snapshot,
            report: report(game.snapshot.week, sequenceMasteryCount: 0)
        ))
        XCTAssertEqual(zero, legacy)
    }

    func testSequenceMasteryAboveThreeCapsBothTrustRewardsAtThree() throws {
        let game = try firstImportantGame(seed: "703")
        let baseline = try engine.resolveImportantGame(.init(
            seed: game.nextSeed,
            state: game.snapshot,
            report: report(game.snapshot.week, sequenceMasteryCount: nil)
        ))
        let three = try engine.resolveImportantGame(.init(
            seed: game.nextSeed,
            state: game.snapshot,
            report: report(game.snapshot.week, sequenceMasteryCount: 3)
        ))
        let aboveCap = try engine.resolveImportantGame(.init(
            seed: game.nextSeed,
            state: game.snapshot,
            report: report(game.snapshot.week, sequenceMasteryCount: 99)
        ))
        XCTAssertEqual(aboveCap, three)
        XCTAssertEqual(aboveCap.snapshot.managerTrust - baseline.snapshot.managerTrust, 3)
        XCTAssertEqual(aboveCap.snapshot.catcherTrust - baseline.snapshot.catcherTrust, 3)
    }

    func testProTeamsPreserveDistinctDraftDevelopmentPlans() {
        XCTAssertGreaterThan(Set(ProCareerEngine.proTeams.map(\.need)).count, 1)
        XCTAssertEqual(Set(ProCareerEngine.proTeams.map(\.developmentPlan)).count, ProCareerEngine.proTeams.count)
        XCTAssertEqual(Set(ProCareerEngine.proTeams.map(\.positionCompetitor)).count, ProCareerEngine.proTeams.count)
    }

    func testStartBackfillsTeamProfilesFromOlderDraftRecords() throws {
        let canonical = ProCareerEngine.proTeams[0]
        let legacyTeam = DraftTeamSnapshot(
            id: canonical.id,
            name: canonical.name,
            need: canonical.need,
            demand: canonical.demand,
            developmentPlan: canonical.developmentPlan,
            positionCompetitor: canonical.positionCompetitor,
            proCoach: canonical.proCoach
        )
        let legacyDraft = DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: legacyTeam,
            round: 2,
            overallPick: 18,
            signingBonus: 120_000_000,
            firstSeasonGoal: "2군 선발",
            summary: "지명"
        )

        let result = try engine.start(.init(
            seed: "24",
            identity: .defaultPitcher,
            pitcher: pitcher(),
            draftResult: legacyDraft,
            entitlement: activeEntitlement()
        ))

        XCTAssertEqual(result.snapshot.team, canonical)
        XCTAssertFalse((result.snapshot.team.competitorProfile ?? "").isEmpty)
        XCTAssertFalse((result.snapshot.team.coachProfile ?? "").isEmpty)
    }

    // 커널 통일 검증: 주간 자동 시뮬이 수동 커널과 같은 엔진에서 나와 현실 분포에 들어간다.
    func testKernelDrivenWeeklyStatsLandInRealisticBands() throws {
        for seedValue in ["11", "42", "300"] {
            var result = try engine.start(.init(seed: seedValue, identity: .defaultPitcher, pitcher: PitcherPresetCatalog.all[0].pitcher, draftResult: drafted(), entitlement: activeEntitlement()))
            result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
            result = try playSeason(result)
            let stats = result.snapshot.careerStats[0]
            let kPer9 = stats.strikeouts * 27 / max(1, stats.inningsOuts)
            let runsPer9 = stats.runsAllowed * 27 / max(1, stats.inningsOuts)
            XCTAssertGreaterThanOrEqual(stats.inningsOuts, 210, "시즌 70이닝 미만은 비정상 (시드 \(seedValue))")
            XCTAssertTrue((4...13).contains(kPer9), "K/9 \(kPer9)가 현실 밴드(4~13)를 벗어남 (시드 \(seedValue))")
            XCTAssertTrue((1...9).contains(runsPer9), "R/9 \(runsPer9)가 현실 밴드(1~9)를 벗어남 (시드 \(seedValue))")
        }
    }

    // 피로가 높을수록 등판 결과가 나빠지는 방향성(커널의 구속·커맨드 저하 반영).
    // 단일 시드는 커널 항 하나만 바뀌어도 RNG 경로가 밀려 뒤집힌다 — 시드 묶음의
    // 집계로 판정해야 "피로가 커널에 있는가"라는 원래 질문에 답한다.
    func testHigherFatigueWorsensOutingsInAggregate() throws {
        // 소수의 시드는 커널 튜닝에 따라 우연히 동률이 날 수 있다. 방향성 검증은 충분한
        // 결정론 표본을 집계해 단일 타석 RNG 변화에 흔들리지 않게 한다.
        let seeds = (1...64).map(UInt64.init)
        var freshBurden = 0, gassedBurden = 0
        for seed in seeds {
            let fresh = engine.simulateWeeklyOuting(pitcher: PitcherPresetCatalog.all[0].pitcher, startingFatigue: 5, outsTarget: 18, pitchCap: 96, baseSeed: seed)
            let gassed = engine.simulateWeeklyOuting(pitcher: PitcherPresetCatalog.all[0].pitcher, startingFatigue: 85, outsTarget: 18, pitchCap: 96, baseSeed: seed)
            freshBurden += fresh.runsAllowed * 2 + fresh.walks
            gassedBurden += gassed.runsAllowed * 2 + gassed.walks
        }
        XCTAssertGreaterThan(gassedBurden, freshBurden, "지친 등판 묶음(실점×2+볼넷 \(gassedBurden))이 싱싱한 묶음(\(freshBurden))보다 좋으면 피로가 커널에 반영되지 않는 것")
    }

    private func assertCompletedCareers(
        in seedValues: Range<Int>,
        replaySeed: Int? = nil
    ) throws {
        var replayResult: ProCareerResult?
        for seedValue in seedValues {
            let completed = try completeCareer(seed: String(seedValue))
            if seedValue == replaySeed { replayResult = completed }
            XCTAssertEqual(completed.snapshot.phase, .completed, "시드 \(seedValue)")
            XCTAssertEqual(
                completed.snapshot.careerStats.count,
                ProCareerEngine.maximumCareerSeasons,
                "시드 \(seedValue)"
            )
            XCTAssertNotNil(completed.snapshot.hallOfFameScore, "시드 \(seedValue)")
            XCTAssertGreaterThanOrEqual(completed.snapshot.fatigue, 0, "시드 \(seedValue)")
            XCTAssertTrue(
                completed.snapshot.careerStats.allSatisfy { $0.games >= 0 && $0.runsAllowed >= 0 },
                "시드 \(seedValue)"
            )
            let decisionsBySeason = Dictionary(
                grouping: completed.snapshot.decisionHistory ?? [],
                by: \.season
            )
            XCTAssertTrue(
                decisionsBySeason.values.allSatisfy {
                    $0.count <= ProCareerEngine.maximumSeasonDecisions
                },
                "시드 \(seedValue)"
            )
            XCTAssertTrue(
                (completed.snapshot.decisionHistory ?? []).allSatisfy {
                    ProCareerEngine.seasonDecisionWeeks.contains($0.week)
                },
                "시드 \(seedValue)"
            )
        }
        if let replaySeed {
            XCTAssertEqual(
                replayResult,
                try completeCareer(seed: String(replaySeed)),
                "완주 전체도 같은 시드와 선택이면 결정론적이어야 한다"
            )
        }
    }

    private func completeCareer(seed: String) throws -> ProCareerResult {
        var result = try engine.start(startParams(seed: seed))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 1...ProCareerEngine.maximumCareerSeasons {
            result = try playSeason(result)
            if result.snapshot.phase == .retirementDecision { break }
            result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
        }
        return try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .retire))
    }

    private func playSeason(_ initial: ProCareerResult) throws -> ProCareerResult {
        var result = initial
        while result.snapshot.phase != .seasonReview {
            if result.snapshot.phase == .importantGame {
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
            } else if result.snapshot.phase == .seasonDecision {
                result = try resolvePendingDecision(result)
            } else {
                let plan: ProWeekPlan = result.snapshot.fatigue > 72 ? .recover : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
            }
        }
        return try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
    }

    private func firstDecision(seed: String) throws -> ProCareerResult {
        var result = try engine.start(startParams(seed: seed))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 0..<120 {
            switch result.snapshot.phase {
            case .seasonDecision:
                return result
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report(result.snapshot.week)))
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            default:
                throw SimulationError.invalidProCareer("테스트에서 시즌 결정에 도달하지 못했습니다.")
            }
        }
        throw SimulationError.invalidProCareer("테스트에서 시즌 결정 탐색 한도를 넘었습니다.")
    }

    private func firstImportantGame(seed: String) throws -> ProCareerResult {
        var result = try engine.start(startParams(seed: seed))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 0..<120 {
            switch result.snapshot.phase {
            case .importantGame:
                return result
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            case .seasonDecision:
                result = try resolvePendingDecision(result)
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            default:
                throw SimulationError.invalidProCareer("테스트에서 중요 경기에 도달하지 못했습니다.")
            }
        }
        throw SimulationError.invalidProCareer("테스트에서 중요 경기 탐색 한도를 넘었습니다.")
    }

    /// 기존 장기 회귀는 갈림길에서 회복 부담이 가장 낮은 선택을 일관되게 고른다.
    private func resolvePendingDecision(_ result: ProCareerResult) throws -> ProCareerResult {
        let decision = try XCTUnwrap(result.snapshot.pendingDecision)
        let choice = try XCTUnwrap(decision.choices.min { lhs, rhs in
            if lhs.effect.fatigueDelta != rhs.effect.fatigueDelta {
                return lhs.effect.fatigueDelta < rhs.effect.fatigueDelta
            }
            return lhs.id < rhs.id
        })
        return try engine.applySeasonDecision(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            decisionID: decision.id,
            choiceID: choice.id
        ))
    }

    private func report(_ number: Int, sequenceMasteryCount: Int? = nil) -> ImportantInningReport {
        .init(scenarioNumber: number, pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0, expectedDamage: 380, actualDamage: 240, recommendationAccepted: 12, sequenceMasteryCount: sequenceMasteryCount)
    }

    private func clampedAbility(_ value: Int) -> Int { min(80, max(20, value)) }

    private func startParams(seed: String, entitlement: ProEntitlementSnapshot? = nil) -> StartProCareerParams {
        .init(seed: seed, identity: .defaultPitcher, pitcher: pitcher(), draftResult: drafted(), entitlement: entitlement ?? activeEntitlement())
    }
    private func activeEntitlement() -> ProEntitlementSnapshot { .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22") }
    private func pitcher() -> PitcherSnapshot { .init(id: "p-1", name: "테스트투수", stuff: 58, command: 55, movement: 56, stamina: 57) }
    private func drafted() -> DraftResultSnapshot {
        .init(outcome: .drafted, evaluationScore: 72, projectedRange: "2~3라운드", team: ProCareerEngine.proTeams[0], round: 2, overallPick: 18, signingBonus: 120_000_000, firstSeasonGoal: "2군 선발", summary: "지명")
    }

    /// **감독의 믿음은 내려가기도 한다.** 한 방향으로만 움직이는 값은 스테이크가 아니라
    /// 시간의 함수다 — 주차를 넘기기만 하면 언젠가 선발이 된다.
    func testBadOutingsCostManagerTrust() throws {
        var result = try engine.start(startParams(seed: "9091"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        var sawDrop = false
        var previous = result.snapshot.managerTrust
        for _ in 0..<60 {
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .developWeapon))
                if result.snapshot.managerTrust < previous { sawDrop = true }
                previous = result.snapshot.managerTrust
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    report: .init(scenarioNumber: 1, pitches: 20, strikeouts: 0, walks: 3,
                                  runsAllowed: 5, expectedDamage: 1_200, actualDamage: 3_000,
                                  recommendationAccepted: 0)
                ))
                previous = result.snapshot.managerTrust
            case .seasonDecision:
                result = try resolvePendingDecision(result)
                previous = result.snapshot.managerTrust
            default:
                sawDrop ? () : XCTFail("시즌이 끝날 때까지 감독의 믿음이 한 번도 내려가지 않았습니다.")
                return
            }
            if sawDrop { return }
        }
        XCTAssertTrue(sawDrop, "60주를 돌리는 동안 감독의 믿음이 한 번도 내려가지 않았습니다.")
    }

    /// **2군행이 존재한다.** 한번 올라가면 안 내려온다면 1군은 승급이 아니라 통과 지점이고,
    /// 그러면 남은 시즌에 걸린 것이 없어진다.
    ///
    /// 손으로 스냅숏을 짜지 않는다 — 커밋 해시를 통과시켜야 하고, 무엇보다 실제 경로에서
    /// 강등이 일어나는지가 알고 싶은 것이다.
    func testMajorLeagueDemotionIsPossible() throws {
        var result = try engine.start(startParams(seed: "4242"))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        var reachedMajor = false
        var demoted = false
        // 여러 시즌을 돌리며 1군에 올라간 뒤 계속 무너지는 등판을 넣는다.
        for _ in 0..<600 {
            switch result.snapshot.phase {
            case .weeklyPlan:
                if result.snapshot.level == .major { reachedMajor = true }
                if reachedMajor, result.snapshot.level == .minor { demoted = true }
                // 1군에 올라가기 전에는 믿음을 쌓고, 올라간 뒤에는 방치한다.
                let plan: ProWeekPlan = reachedMajor ? .developWeapon : .earnTrust
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
            case .importantGame:
                let report: ImportantInningReport = reachedMajor
                    ? .init(scenarioNumber: 1, pitches: 22, strikeouts: 0, walks: 4, runsAllowed: 6,
                            expectedDamage: 1_400, actualDamage: 3_600, recommendationAccepted: 0)
                    : .init(scenarioNumber: 1, pitches: 16, strikeouts: 4, walks: 0, runsAllowed: 0,
                            expectedDamage: 400, actualDamage: 150, recommendationAccepted: 10)
                result = try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
            case .seasonDecision:
                result = try resolvePendingDecision(result)
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(seed: result.nextSeed, state: result.snapshot, decision: .continueCareer))
            default:
                break
            }
            if demoted { break }
            if [.retirementDecision, .completed].contains(result.snapshot.phase) { break }
        }
        XCTAssertTrue(reachedMajor, "1군에 올라가지 못해 강등을 확인할 수 없었습니다.")
        XCTAssertTrue(demoted, "믿음이 바닥까지 떨어졌는데도 1군에서 내려오지 않았습니다.")
    }
}
