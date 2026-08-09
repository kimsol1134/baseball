import Foundation
import SimulationCore
import XCTest
@testable import BaseballIOS

@MainActor
final class RunPledgeTests: XCTestCase {
    private let legacyIDs: Set<String> = [
        "get_drafted", "strikeout_master", "clean_games", "iron_control",
    ]

    func testPoolKeepsLegacyIDsAndDefinesTwelveStableRewards() {
        XCTAssertEqual(RunPledge.all.count, 12)
        XCTAssertTrue(legacyIDs.isSubset(of: Set(RunPledge.all.map(\.id))))
        XCTAssertEqual(Set(RunPledge.all.map(\.id)).count, 12)
        for pledge in RunPledge.all {
            XCTAssertEqual(pledge.rewardPermille, pledge.tier.rewardPermille)
        }
        XCTAssertEqual(RunPledgeTier.safe.rewardPermille, 100)
        XCTAssertEqual(RunPledgeTier.bold.rewardPermille, 200)
        XCTAssertEqual(RunPledgeTier.legendary.rewardPermille, 350)
    }

    func testLegacyV1FourContractsKeepTheirShippedBoundariesCopyAndReward() throws {
        let legacy = Dictionary(uniqueKeysWithValues: RunPledge.legacyV1.map { ($0.id, $0) })
        XCTAssertEqual(Set(legacy.keys), legacyIDs)
        XCTAssertTrue(legacy.values.allSatisfy { $0.rewardPermille == 150 })
        XCTAssertEqual(legacy["strikeout_master"]?.title, "시즌 40탈삼진")
        XCTAssertEqual(legacy["clean_games"]?.title, "무실점 등판 2회")
        XCTAssertEqual(legacy["get_drafted"]?.title, "지명받는다")
        XCTAssertEqual(legacy["iron_control"]?.title, "볼넷 8개 이하")

        let drafted = try XCTUnwrap(legacy["get_drafted"])
        XCTAssertFalse(drafted.progress(in: try pledgeContext(drafted: false)).achieved)
        XCTAssertTrue(drafted.progress(in: try pledgeContext(drafted: true)).achieved)

        let strikeouts = try XCTUnwrap(legacy["strikeout_master"])
        XCTAssertFalse(strikeouts.progress(in: try pledgeContext(strikeouts: 39)).achieved)
        XCTAssertTrue(strikeouts.progress(in: try pledgeContext(strikeouts: 40)).achieved)

        let clean = try XCTUnwrap(legacy["clean_games"])
        XCTAssertFalse(clean.progress(in: try pledgeContext(cleanGames: 1)).achieved)
        let cleanAtTarget = clean.progress(in: try pledgeContext(cleanGames: 2))
        XCTAssertTrue(cleanAtTarget.achieved)

        let control = try XCTUnwrap(legacy["iron_control"])
        XCTAssertFalse(control.progress(in: try pledgeContext(games: 3, walks: 8)).achieved)
        XCTAssertFalse(control.progress(in: try pledgeContext(games: 4, walks: 9)).achieved)
        XCTAssertTrue(control.progress(in: try pledgeContext(games: 4, walks: 8)).achieved)

        let context = try pledgeContext(cleanGames: 2)
        let archived = HighSchoolCareerStore.lifeRecord(
            from: context.state, memories: [], previous: .firstLife,
            pledgeBonusPermille: clean.rewardPermille,
            pledge: clean, pledgeProgress: cleanAtTarget
        )
        XCTAssertEqual(archived.pledgeTitle, "무실점 등판 2회")
        XCTAssertEqual(archived.pledgeTier, clean.tier.rawValue)
        XCTAssertEqual(archived.pledgeRewardPermille, 150)
    }

    func testLegacyRetryReasonDoesNotLeakOldThresholdIntoCurrentCatalogCard() throws {
        let old = try XCTUnwrap(RunPledge.pledge(
            id: "strikeout_master", rulesVersion: RunPledge.legacyRulesVersion
        ))
        let current = try XCTUnwrap(RunPledge.pledge(
            id: "strikeout_master", rulesVersion: RunPledge.currentRulesVersion
        ))
        XCTAssertEqual(old.progress(in: try pledgeContext(strikeouts: 10)).line, "탈삼진 10/40")
        XCTAssertEqual(current.title, "시즌 5탈삼진")
        XCTAssertEqual(RunPledge.retryIntentReason, "지난 고교 3년에서 아쉽게 놓친 목표입니다.")
        XCTAssertFalse(RunPledge.retryIntentReason.contains("40"))
    }

    func testOneThousandCareerIDsAlwaysOfferThreeUniqueNonLegendaryChoicesInFirstLife() throws {
        let state = try startedState(lifeNumber: 1)
        let buildAligned = RunPledge.buildAlignedIDs(state: state)

        for index in 0..<1_000 {
            let careerID = "pledge-fixture-\(index)"
            let first = RunPledge.options(careerID: careerID, state: state)
            let second = RunPledge.options(careerID: careerID, state: state)
            XCTAssertEqual(first.map(\.id), second.map(\.id), "\(careerID) must be deterministic")
            XCTAssertEqual(first.count, 3, careerID)
            XCTAssertEqual(Set(first.map(\.id)).count, 3, careerID)
            XCTAssertFalse(first.contains { $0.tier == .legendary }, careerID)
            XCTAssertTrue(first.contains { $0.tier == .safe }, careerID)
            XCTAssertTrue(first.contains { buildAligned.contains($0.id) }, careerID)
            XCTAssertTrue(first.contains { $0.tier == .bold }, careerID)
        }
    }

    func testValidIntentIsFirstButNeverAutomaticallySelected() throws {
        let state = try startedState(lifeNumber: 2)
        let intent = NextRunIntent(
            pledgeID: "evaluation_seventy_five", sourceLifeNumber: 1,
            reason: "평가 67점까지 다섯 점이 남았습니다."
        )
        let choices = RunPledge.options(careerID: state.careerID, state: state, intent: intent)

        XCTAssertEqual(choices.first?.id, intent.pledgeID)
        XCTAssertEqual(choices.count, 3)
        XCTAssertEqual(Set(choices.map(\.id)).count, 3)
    }

    func testCompoundPledgeLargeWalkMissIsNotReportedAsNearMiss() throws {
        let state = try state(
            startedState(lifeNumber: 2),
            performance: .init(importantGamesCompleted: 4, pitches: 80, strikeouts: 32,
                               walks: 9, runsAllowed: 4, expectedDamage: 900, actualDamage: 850)
        )
        let pledge = try XCTUnwrap(RunPledge.pledge(id: "iron_control"))
        let progress = pledge.progress(in: .init(state: state, rivalLedger: .init()))

        XCTAssertGreaterThanOrEqual(progress.current, progress.target)
        XCTAssertFalse(progress.achieved)
        XCTAssertEqual(progress.ratioPermille, 100)
        XCTAssertLessThan(progress.ratioPermille, 800)
        XCTAssertEqual(progress.ratio, 0.1, accuracy: 0.000_001)
        XCTAssertTrue(pledge.accessibilityLabel(progress: progress).contains("볼넷 9/0"))
    }

    func testAllTwelvePledgePredicatesHonorBelowAndAtTargetBoundaries() throws {
        try assertBoundary(
            "get_drafted",
            below: [pledgeContext(drafted: false)],
            at: pledgeContext(drafted: true)
        )
        try assertBoundary(
            "strikeout_master",
            below: [pledgeContext(strikeouts: 4)],
            at: pledgeContext(strikeouts: 5)
        )
        try assertBoundary(
            "clean_games",
            below: [pledgeContext(cleanGames: 3)],
            at: pledgeContext(cleanGames: 4)
        )
        try assertBoundary(
            "iron_control",
            below: [
                pledgeContext(games: 3, strikeouts: 4, walks: 0),
                pledgeContext(games: 4, strikeouts: 4, walks: 1),
                pledgeContext(games: 4, strikeouts: 3, walks: 0),
            ],
            at: pledgeContext(games: 4, strikeouts: 4, walks: 0)
        )
        try assertBoundary(
            "healthy_finish",
            below: [
                pledgeContext(games: 3, fatigue: 78, armRisk: 54),
                pledgeContext(games: 4, fatigue: 79, armRisk: 54),
                pledgeContext(games: 4, fatigue: 78, armRisk: 55),
                pledgeContext(games: 4, fatigue: 78, armRisk: 54, recovery: 1),
            ],
            at: pledgeContext(games: 4, fatigue: 78, armRisk: 54)
        )
        try assertBoundary(
            "awakening_three",
            below: [
                pledgeContext(awakeningIDs: [.explosiveFastball, .pinpointEdge]),
                pledgeContext(awakeningIDs: [.explosiveFastball, .risingFourSeam, .ironArm]),
            ],
            at: pledgeContext(awakeningIDs: [.explosiveFastball, .pinpointEdge, .disappearingBreaker])
        )
        try assertBoundary(
            "fan_sixty",
            below: [pledgeContext(fanInterest: 24)],
            at: pledgeContext(fanInterest: 25)
        )
        try assertBoundary(
            "evaluation_sixty_five",
            below: [pledgeContext(evaluation: 63)],
            at: pledgeContext(evaluation: 64)
        )
        try assertBoundary(
            "evaluation_seventy_five",
            below: [pledgeContext(evaluation: 66)],
            at: pledgeContext(evaluation: 67)
        )
        try assertBoundary(
            "iron_control_five",
            below: [
                pledgeContext(games: 3, strikeouts: 6, walks: 0),
                pledgeContext(games: 4, strikeouts: 6, walks: 1),
                pledgeContext(games: 4, strikeouts: 5, walks: 0),
            ],
            at: pledgeContext(games: 4, strikeouts: 6, walks: 0)
        )
        try assertBoundary(
            "rival_three_strikeouts",
            below: [pledgeContext(rivalStrikeouts: 2)],
            at: pledgeContext(rivalStrikeouts: 3)
        )
        try assertBoundary(
            "relationship_sixty_five",
            below: [pledgeContext(maxTrust: 68)],
            at: pledgeContext(maxTrust: 69)
        )
    }

    func testCompoundProgressUsesWeakestConditionAndArchiveKeepsItsAccessibleLine() throws {
        let control = try XCTUnwrap(RunPledge.pledge(id: "iron_control"))
        let controlProgress = control.progress(in: try pledgeContext(
            games: 4, strikeouts: 4, walks: 3
        ))
        XCTAssertEqual(controlProgress.ratioPermille, 250)
        XCTAssertFalse(controlProgress.achieved)
        XCTAssertTrue(control.accessibilityLabel(progress: controlProgress).contains(controlProgress.line))

        let unhealthy = try XCTUnwrap(RunPledge.pledge(id: "healthy_finish")).progress(
            in: try pledgeContext(games: 4, fatigue: 99, armRisk: 100)
        )
        XCTAssertEqual(unhealthy.ratioPermille, 0)
        XCTAssertLessThan(unhealthy.ratioPermille, 800)

        let awakeningMiss = try XCTUnwrap(RunPledge.pledge(id: "awakening_three")).progress(
            in: try pledgeContext(
                awakeningIDs: [.explosiveFastball, .risingFourSeam, .ironArm]
            )
        )
        XCTAssertEqual(awakeningMiss.ratioPermille, 333)
        XCTAssertTrue(awakeningMiss.line.contains("전략 계열 1/3"))

        let context = try pledgeContext(games: 4, strikeouts: 4, walks: 3)
        let record = HighSchoolCareerStore.lifeRecord(
            from: context.state,
            memories: [],
            previous: .firstLife,
            pledge: control,
            pledgeProgress: controlProgress
        )
        XCTAssertEqual(record.pledgeProgressLine, controlProgress.line)
        XCTAssertEqual(record.pledgeProgressRatioPermille, 250)
        XCTAssertEqual(record.pledgeTitle, control.title)
        XCTAssertEqual(record.pledgeTier, control.tier.rawValue)
        XCTAssertEqual(record.pledgeRewardPermille, control.rewardPermille)

        // Archive presentation is frozen metadata, not a reinterpretation through the current
        // mutable catalog. It must still render if that ID no longer exists in a future catalog.
        var frozen = record
        frozen.pledgeID = "retired-pledge-id"
        frozen.pledgeTitle = "그때의 약속"
        frozen.pledgeTier = RunPledgeTier.safe.rawValue
        frozen.pledgeRewardPermille = 125
        let archived = try XCTUnwrap(ArchivedPledgePresentation.resolve(frozen))
        XCTAssertEqual(archived.title, "그때의 약속")
        XCTAssertEqual(archived.tier, .safe)
        XCTAssertEqual(archived.rewardPermille, 125)
        XCTAssertTrue(archived.accessibilityLabel(
            progressLine: controlProgress.line, status: "미완"
        ).contains("그때의 약속"))
    }

    func testCurrentPledgeAndRivalLedgerFollowSaveSyncToANewDevice() throws {
        let sync = SaveSync(key: "run-pledge-sync-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "run-pledge-sync-weekly-\(UUID().uuidString).json")
        sync.clear()
        weeklySync.clear()
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "run-pledge-sync")
        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        store.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "동기화 테스트",
            seedOverride: "20260809991"
        )
        let careerID = try XCTUnwrap(store.state?.careerID)
        let pledgeKey = "baseball.pledge.\(careerID)"
        let versionKey = "baseball.pledgeRulesVersion.\(careerID)"
        let rivalKey = "baseball.rivalLedger.\(careerID)"
        defer {
            sync.clear()
            weeklySync.clear()
            UserDefaults.standard.removeObject(forKey: pledgeKey)
            UserDefaults.standard.removeObject(forKey: versionKey)
            UserDefaults.standard.removeObject(forKey: rivalKey)
        }
        store.choosePledge("get_drafted")
        var ledger = HighSchoolCareerStore.RivalLedger()
        ledger.plateAppearances = 3
        ledger.strikeouts = 2
        ledger.walks = 1
        UserDefaults.standard.set(try JSONEncoder().encode(ledger), forKey: rivalKey)
        store.save()

        let encoded = try XCTUnwrap(sync.read { data in
            (try? JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: data))?.effectiveRevision
        })
        let saved = try JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: encoded)
        XCTAssertEqual(saved.currentCareerRetention?.careerID, careerID)
        XCTAssertEqual(saved.currentCareerRetention?.pledgeID, "get_drafted")
        XCTAssertEqual(saved.currentCareerRetention?.pledgeRulesVersion, 2)
        XCTAssertEqual(saved.currentCareerRetention?.rivalLedger, ledger)

        // Simulate a new device: SaveSync remains, process-local UserDefaults mirrors do not.
        UserDefaults.standard.removeObject(forKey: pledgeKey)
        UserDefaults.standard.removeObject(forKey: versionKey)
        UserDefaults.standard.removeObject(forKey: rivalKey)
        let reloaded = HighSchoolCareerStore(sync: sync, weekly: weekly)
        reloaded.restoreOrCreate()

        XCTAssertEqual(reloaded.state?.careerID, careerID)
        XCTAssertEqual(reloaded.pledge?.id, "get_drafted")
        XCTAssertEqual(reloaded.pledge?.rewardPermille, 100, "새 선택은 v2 규칙으로 복원됩니다.")
        XCTAssertTrue(reloaded.pledgeDecided)
        XCTAssertEqual(reloaded.rivalLedger, ledger)

        reloaded.choosePledge(nil)
        UserDefaults.standard.removeObject(forKey: pledgeKey)
        UserDefaults.standard.removeObject(forKey: versionKey)
        UserDefaults.standard.removeObject(forKey: rivalKey)
        let skippedReload = HighSchoolCareerStore(sync: sync, weekly: weekly)
        skippedReload.restoreOrCreate()
        XCTAssertNil(skippedReload.pledge)
        XCTAssertTrue(skippedReload.pledgeDecided, "명시적으로 건너뛴 결정도 새 기기에서 다시 묻지 않습니다.")
        XCTAssertEqual(skippedReload.rivalLedger, ledger)
    }

    func testMissingVersionMigratesAnActiveLocalPledgeAsV1ThroughSaveSync() throws {
        let sync = SaveSync(key: "run-pledge-v1-migration-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "run-pledge-v1-migration-weekly-\(UUID().uuidString).json")
        sync.clear()
        weeklySync.clear()
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "run-pledge-v1")
        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        store.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "이전 목표 테스트",
            seedOverride: "20260809992"
        )
        let careerID = try XCTUnwrap(store.state?.careerID)
        let pledgeKey = "baseball.pledge.\(careerID)"
        let versionKey = "baseball.pledgeRulesVersion.\(careerID)"
        defer {
            sync.clear()
            weeklySync.clear()
            UserDefaults.standard.removeObject(forKey: pledgeKey)
            UserDefaults.standard.removeObject(forKey: versionKey)
        }

        // Shipped saves had only this ID in UserDefaults and no rules-version field/envelope.
        UserDefaults.standard.set("strikeout_master", forKey: pledgeKey)
        UserDefaults.standard.removeObject(forKey: versionKey)
        XCTAssertEqual(store.pledge?.title, "시즌 40탈삼진")
        XCTAssertEqual(store.pledge?.rewardPermille, 150)
        store.save()

        let encoded = try XCTUnwrap(sync.read { data in
            (try? JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: data))?.effectiveRevision
        })
        let saved = try JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: encoded)
        XCTAssertEqual(saved.currentCareerRetention?.pledgeRulesVersion, 1)

        UserDefaults.standard.removeObject(forKey: pledgeKey)
        UserDefaults.standard.removeObject(forKey: versionKey)
        let reloaded = HighSchoolCareerStore(sync: sync, weekly: weekly)
        reloaded.restoreOrCreate()
        XCTAssertEqual(reloaded.pledge?.title, "시즌 40탈삼진")
        XCTAssertEqual(reloaded.pledge?.rewardPermille, 150)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: versionKey), 1)
    }

    func testChallengeCannotConsumeCanonicalRetryIntentOrEmitAppliedAnalytics() throws {
        let sync = SaveSync(key: "run-pledge-challenge-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "run-pledge-challenge-weekly-\(UUID().uuidString).json")
        sync.clear()
        weeklySync.clear()
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "run-pledge-challenge")
        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        let intent = NextRunIntent(
            pledgeID: "get_drafted", sourceLifeNumber: 1,
            reason: RunPledge.retryIntentReason
        )
        defer {
            sync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        store.saveNextRunIntent(intent)
        store.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "도전 테스트",
            seedOverride: "20260809993", challengeLifeNumber: 2
        )
        let careerID = try XCTUnwrap(store.state?.careerID)
        let pledgeKey = "baseball.pledge.\(careerID)"
        let versionKey = "baseball.pledgeRulesVersion.\(careerID)"
        defer {
            UserDefaults.standard.removeObject(forKey: pledgeKey)
            UserDefaults.standard.removeObject(forKey: versionKey)
        }
        XCTAssertTrue(store.isChallengeRun)
        XCTAssertFalse(store.countsTowardWeeklyProgram)
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        store.finishTutorialPitch()
        store.choosePledge(intent.pledgeID)

        XCTAssertEqual(store.nextRunIntent, intent)
        XCTAssertFalse(store.pledgeDecided)
        XCTAssertTrue(events.isEmpty, "기록 없는 도전의 phase/first-pitch/목표 이벤트는 canonical funnel에 섞이지 않습니다.")
        XCTAssertFalse(events.contains(.nextRunIntentApplied))
        XCTAssertFalse(events.contains(.runPledgeSelected))
        XCTAssertEqual(weekly.program?.completedCount ?? 0, 0)
    }

    func testEveryAwakeningHasOneVisibleStrategyFamily() {
        let grouped = Dictionary(grouping: AwakeningID.allCases, by: RunPledge.awakeningFamily(for:))

        XCTAssertEqual(Set(grouped.keys), Set(RunPledgeAwakeningFamily.allCases))
        XCTAssertEqual(grouped[.body]?.count, 4)
        XCTAssertEqual(grouped[.command]?.count, 5)
        XCTAssertEqual(grouped[.breaking]?.count, 5)
        XCTAssertEqual(grouped[.game]?.count, 4)
        XCTAssertEqual(grouped.values.flatMap { $0 }.count, AwakeningID.allCases.count)
    }

    func testAlignmentReasonDoesNotClaimCommandStrengthForAStretchOffer() throws {
        let powerState = try startedState(lifeNumber: 2)
        let control = try XCTUnwrap(RunPledge.pledge(id: "iron_control"))
        XCTAssertFalse(RunPledge.buildAlignedIDs(state: powerState).contains(control.id))
        XCTAssertEqual(
            control.alignmentReason(state: powerState),
            "현재 강점과 다른 방향까지 넓혀 보는 도전 목표입니다."
        )
    }

    func testFailedPledgeNeverRemovesAlreadyEarnedSoul() throws {
        let state = try startedState(lifeNumber: 2)
        let previous = HighSchoolCareerStore.Inheritance(
            lifeNumber: 2, memories: [], soulPoints: 73, karmas: []
        )
        let withoutBonus = HighSchoolCareerStore.nextInheritance(
            from: state, memories: [], previous: previous, pledgeBonusPermille: 0
        )

        XCTAssertGreaterThanOrEqual(withoutBonus.soulPoints, previous.soulPoints)
        XCTAssertEqual(
            withoutBonus,
            HighSchoolCareerStore.nextInheritance(from: state, memories: [], previous: previous)
        )
    }

    func testIntentSurvivesUntilAnExplicitDecisionThenIsConsumedOrDiscarded() throws {
        let sync = SaveSync(key: "run-pledge-career-\(UUID().uuidString).json")
        let weeklySync = SaveSync(key: "run-pledge-weekly-\(UUID().uuidString).json")
        sync.clear()
        weeklySync.clear()
        defer {
            sync.clear()
            weeklySync.clear()
        }
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "run-pledge-test")
        let store = HighSchoolCareerStore(sync: sync, weekly: weekly)
        store.startCareer(
            preset: PitcherPresetCatalog.all[0], playerName: "약속 테스트",
            seedOverride: "2026080912345"
        )
        let state = try XCTUnwrap(store.result?.snapshot)
        let pledgeDefaultsKey = "baseball.pledge.\(state.careerID)"
        UserDefaults.standard.removeObject(forKey: pledgeDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: pledgeDefaultsKey) }
        let intent = NextRunIntent(
            pledgeID: "get_drafted", sourceLifeNumber: 1,
            reason: "지난 회차에 이름이 불리지 않았습니다."
        )

        store.saveNextRunIntent(intent)
        store.completePrologue()
        XCTAssertEqual(store.nextRunIntent, intent, "phase changes must not consume a recommendation")
        XCTAssertFalse(store.pledgeDecided, "a recommendation must not make the choice for the player")

        let other = try XCTUnwrap(
            RunPledge.options(careerID: state.careerID, state: state, intent: intent)
                .first(where: { $0.id != intent.pledgeID })
        )
        store.choosePledge(other.id)
        XCTAssertNil(store.nextRunIntent, "choosing another pledge explicitly discards the intent")

        store.saveNextRunIntent(intent)
        store.choosePledge(intent.pledgeID)
        XCTAssertNil(store.nextRunIntent, "choosing the recommended pledge consumes the intent")

        store.saveNextRunIntent(intent)
        store.choosePledge(nil)
        XCTAssertNil(store.nextRunIntent, "skipping pledges explicitly discards the intent")
    }

    private func startedState(lifeNumber: Int) throws -> HighSchoolCareerSnapshot {
        try HighSchoolCareerEngine().start(.init(
            seed: "20260809", presetID: "power_prospect", lifeNumber: lifeNumber
        )).snapshot
    }

    private func assertBoundary(
        _ id: String,
        below: [RunPledgeContext],
        at: RunPledgeContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let pledge = try XCTUnwrap(RunPledge.pledge(id: id), file: file, line: line)
        for context in below {
            XCTAssertFalse(
                pledge.progress(in: context).achieved,
                "\(id)의 하한 미만/보조 조건 실패가 완료됐습니다.",
                file: file,
                line: line
            )
        }
        let progress = pledge.progress(in: at)
        XCTAssertTrue(progress.achieved, "\(id)의 경계값이 완료되지 않았습니다.", file: file, line: line)
        XCTAssertEqual(progress.ratioPermille, 1_000, file: file, line: line)
    }

    private func pledgeContext(
        games: Int = 0,
        strikeouts: Int = 0,
        walks: Int = 0,
        cleanGames: Int = 0,
        awakenings: Int = 0,
        fatigue: Int = 0,
        armRisk: Int = 0,
        recovery: Int = 0,
        fanInterest: Int = 0,
        evaluation: Int = 0,
        drafted: Bool = false,
        maxTrust: Int = 0,
        rivalStrikeouts: Int = 0,
        awakeningIDs: [AwakeningID]? = nil
    ) throws -> RunPledgeContext {
        let source = try startedState(lifeNumber: 2)
        let performance = CareerPerformanceSnapshot(
            importantGamesCompleted: games,
            pitches: games * 18,
            strikeouts: strikeouts,
            walks: walks,
            runsAllowed: 0,
            expectedDamage: 0,
            actualDamage: 0
        )
        let seasonLog = (0..<cleanGames).map { index in
            ProGameLine(
                season: 1, week: index + 1, outingNumber: index + 1,
                started: false, outs: 3, strikeouts: 1, walks: 0,
                runsAllowed: 0, pitches: 12, teamRuns: 1, opponentRuns: 0,
                decision: .noDecision, played: true
            )
        }
        let draft = DraftResultSnapshot(
            outcome: drafted ? .drafted : .undrafted,
            evaluationScore: evaluation,
            projectedRange: "테스트",
            team: nil,
            round: nil,
            overallPick: nil,
            signingBonus: nil,
            firstSeasonGoal: nil,
            summary: "테스트"
        )
        let state = try mutatedState(source) { object in
            object["performance"] = try jsonObject(performance)
            object["seasonLog"] = try jsonObject(seasonLog)
            object["selectedAwakenings"] = try jsonObject(
                awakeningIDs ?? Array(AwakeningID.allCases.prefix(awakenings))
            )
            object["fatigue"] = fatigue
            object["armRisk"] = armRisk
            object["injuryRecovery"] = recovery
            object["fanInterest"] = fanInterest
            object["managerTrust"] = maxTrust
            object["catcherTrust"] = maxTrust
            object["rivalTrust"] = maxTrust
            object["relationshipTrust"] = maxTrust
            object["draftResult"] = try jsonObject(draft)
        }
        var ledger = HighSchoolCareerStore.RivalLedger()
        ledger.strikeouts = rivalStrikeouts
        return RunPledgeContext(state: state, rivalLedger: ledger)
    }

    private func mutatedState(
        _ source: HighSchoolCareerSnapshot,
        mutate: (inout [String: Any]) throws -> Void
    ) throws -> HighSchoolCareerSnapshot {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any]
        )
        try mutate(&object)
        return try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    /// Copy a snapshot through its Codable representation so the fixture stays compatible
    /// when optional, commitment-excluded save fields are appended to the core model.
    private func state(
        _ source: HighSchoolCareerSnapshot,
        performance: CareerPerformanceSnapshot
    ) throws -> HighSchoolCareerSnapshot {
        let encoder = JSONEncoder()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(source)) as? [String: Any]
        )
        object["performance"] = try JSONSerialization.jsonObject(with: encoder.encode(performance))
        return try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }
}
