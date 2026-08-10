import Foundation
import SimulationCore
import XCTest
@testable import BaseballIOS

@MainActor
final class WeeklyProgramTests: XCTestCase {
    private let fullEligibility = WeeklyProgramEligibility(
        hasHighSchoolCareer: true,
        remainingImportantGames: 6,
        remainingChapterAdvances: 7,
        dailyInningUnlocked: true,
        canStartNextRun: true,
        canSelectPledge: true,
        canChooseDifferentSchool: true,
        hasProCareer: true
    )

    func testSameUserWeekAndEligibilityAlwaysProduceSameThreeTasks() throws {
        let first = try XCTUnwrap(WeeklyProgramRules.make(
            weekKey: "2026-W32",
            stableUserID: "weekly-user",
            eligibility: fullEligibility
        ))
        for _ in 0..<100 {
            XCTAssertEqual(
                WeeklyProgramRules.make(
                    weekKey: "2026-W32",
                    stableUserID: "weekly-user",
                    eligibility: fullEligibility
                ),
                first
            )
        }
        XCTAssertEqual(first.tasks.count, 3)
        XCTAssertEqual(Set(first.tasks.map(\.kind)).count, 3)
        XCTAssertTrue(first.tasks.allSatisfy { $0.id.hasPrefix("2026-W32-") })
    }

    func testLockedAndRebirthTasksAreExcludedForFirstCareerUser() throws {
        let firstCareer = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 5,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let program = try XCTUnwrap(WeeklyProgramRules.make(
            weekKey: "2026-W32",
            stableUserID: "first-career",
            eligibility: firstCareer
        ))
        let allowed: Set<WeeklyTaskKind> = [
            .dailyInningCompleted,
            .importantGamesCompleted,
            .chaptersAdvanced,
            .sequenceMasteryTriggered,
            .playedOnTwoDays,
        ]
        XCTAssertTrue(Set(program.tasks.map(\.kind)).isSubset(of: allowed))
        XCTAssertFalse(program.tasks.contains { task in
            [.nextRunStarted, .pledgeSelected, .differentSchoolSelected, .proWeeksAdvanced]
                .contains(task.kind)
        })
    }

    func testTwoOfThreeTasksUnlockExactlyOneClaimAndThirdAddsPerfectBorder() throws {
        var program = try XCTUnwrap(WeeklyProgramRules.make(
            weekKey: "2026-W32",
            stableUserID: "claim-user",
            eligibility: fullEligibility
        ))
        program.record(program.tasks[0].kind, amount: program.tasks[0].target)
        XCTAssertFalse(program.isRewardReady)
        XCTAssertNotNil(program.nextRewardTask)
        program.record(program.tasks[1].kind, amount: program.tasks[1].target)
        XCTAssertTrue(program.isRewardReady)

        let now = date("2026-08-09T03:00:00Z")
        let stamp = try XCTUnwrap(program.claimStamp(now: now))
        XCTAssertEqual(stamp.completedTaskCount, 2)
        XCTAssertFalse(stamp.perfect)
        XCTAssertNil(program.claimStamp(now: now), "같은 주 보상은 두 번 받을 수 없습니다.")

        program.record(program.tasks[2].kind, amount: program.tasks[2].target)
        XCTAssertTrue(program.isPerfect)
        XCTAssertTrue(program.claimed)
    }

    func testStorePersistsProgressClaimAndStampsAcrossRestart() throws {
        let sync = isolatedSync("weekly-persistence")
        sync.clear()
        defer { sync.clear() }
        let calendar = calendar("Asia/Seoul")
        let now = date("2026-08-05T12:00:00Z")
        let store = WeeklyProgramStore(sync: sync, stableUserID: "persist-user")
        store.configure(eligibility: fullEligibility, now: now, calendar: calendar)
        let tasks = try XCTUnwrap(store.program?.tasks)
        store.record(tasks[0].kind, amount: tasks[0].target, eligibility: fullEligibility, now: now, calendar: calendar)
        store.record(tasks[1].kind, amount: tasks[1].target, eligibility: fullEligibility, now: now, calendar: calendar)
        store.markClaimed(now: now)
        store.record(tasks[2].kind, amount: tasks[2].target, eligibility: fullEligibility, now: now, calendar: calendar)

        let reloaded = WeeklyProgramStore(sync: sync, stableUserID: "persist-user")
        XCTAssertEqual(reloaded.program, store.program)
        XCTAssertEqual(reloaded.stamps, store.stamps)
        XCTAssertEqual(reloaded.lastObservedWeekStart, store.lastObservedWeekStart)
        XCTAssertTrue(reloaded.program?.claimed == true)
        XCTAssertEqual(reloaded.stamps.count, 1)
        XCTAssertTrue(reloaded.stamps.first?.perfect == true)
    }

    func testSameWeekModeChangeReplacesOnlyImpossibleIncompleteTasksDeterministically() throws {
        let sync = isolatedSync("weekly-mode-change")
        sync.clear()
        defer { sync.clear() }
        let now = date("2026-08-05T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        let highSchoolEligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 5,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let activeProEligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: false,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: true
        )
        let stableUserID = try XCTUnwrap((0..<100).lazy.map { "mode-change-\($0)" }.first { id in
            let kinds = Set(WeeklyProgramRules.make(
                weekKey: "2026-W32", stableUserID: id, eligibility: highSchoolEligibility
            )?.tasks.map(\.kind) ?? [])
            return kinds.contains(.importantGamesCompleted) && kinds.contains(.chaptersAdvanced)
        })
        let store = WeeklyProgramStore(sync: sync, stableUserID: stableUserID)
        store.configure(eligibility: highSchoolEligibility, now: now, calendar: calendar)
        let original = try XCTUnwrap(store.program)
        let completedHighSchool = try XCTUnwrap(
            original.tasks.first(where: { $0.kind == .importantGamesCompleted })
        )
        let impossibleIncomplete = try XCTUnwrap(
            original.tasks.first(where: { $0.kind == .chaptersAdvanced })
        )
        let other = try XCTUnwrap(original.tasks.first { task in
            task.id != completedHighSchool.id && task.id != impossibleIncomplete.id
        })

        store.record(
            .chaptersAdvanced, amount: 1, eligibility: highSchoolEligibility,
            now: now, calendar: calendar
        )
        store.record(
            completedHighSchool.kind, amount: completedHighSchool.target,
            eligibility: highSchoolEligibility, now: now, calendar: calendar
        )
        store.record(
            other.kind, amount: other.target, eligibility: highSchoolEligibility,
            now: now, calendar: calendar
        )
        store.markClaimed(now: now)
        let stampBefore = try XCTUnwrap(store.stamps.first)
        let preservedCompletedTasks = try XCTUnwrap(store.program).tasks.filter(\.isCompleted)

        store.configure(eligibility: activeProEligibility, now: now, calendar: calendar)
        let migrated = try XCTUnwrap(store.program)
        XCTAssertEqual(migrated.tasks.count, 3)
        XCTAssertEqual(Set(migrated.tasks.map(\.kind)).count, 3)
        XCTAssertTrue(migrated.claimed)
        XCTAssertEqual(migrated.completedCount, 2)
        XCTAssertEqual(store.stamps.first, stampBefore)
        for completedTask in preservedCompletedTasks {
            XCTAssertTrue(migrated.tasks.contains(completedTask))
        }
        XCTAssertFalse(migrated.tasks.contains { $0.id == impossibleIncomplete.id })
        XCTAssertTrue(migrated.tasks.filter { !$0.isCompleted }.allSatisfy {
            Set(WeeklyProgramRules.eligibleKinds(activeProEligibility)).contains($0.kind)
        })

        let reloaded = WeeklyProgramStore(sync: sync, stableUserID: stableUserID)
        reloaded.configure(eligibility: activeProEligibility, now: now, calendar: calendar)
        XCTAssertEqual(reloaded.program, migrated)
        XCTAssertEqual(reloaded.stamps, store.stamps)
    }

    func testExternalSoulRewardReceiptSurvivesRestartAndPaysOnlyOnce() {
        let sync = isolatedSync("weekly-soul")
        sync.clear()
        defer { sync.clear() }
        let reward = WeeklyProgramReward.reward(for: "2026-W32")
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        let before = store.inheritance.soulPoints

        XCTAssertTrue(store.acceptExternalSoulReward(id: reward.id, soulPoints: reward.soulPoints))
        XCTAssertTrue(store.acceptExternalSoulReward(id: reward.id, soulPoints: reward.soulPoints))
        XCTAssertEqual(store.inheritance.soulPoints, before + 15)
        XCTAssertEqual(store.inheritance.soulTotal, before + 15)
        XCTAssertEqual(store.inheritance.automaticSoulTotal, before + 15)
        XCTAssertEqual(store.creditedExternalRewardIDs, [reward.id])

        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertEqual(reloaded.inheritance.soulPoints, before + 15)
        XCTAssertEqual(reloaded.inheritance.automaticSoulTotal, before + 15)
        XCTAssertEqual(reloaded.creditedExternalRewardIDs, [reward.id])
        XCTAssertTrue(reloaded.acceptExternalSoulReward(id: reward.id, soulPoints: reward.soulPoints))
        XCTAssertEqual(reloaded.inheritance.soulPoints, before + 15)
    }

    func testHighSchoolRewardWriteFailureRollsBackSoulAndLeavesWeeklyRewardUnclaimed() throws {
        let highSchoolSync = isolatedSync("weekly-high-school-write-failure")
        let weeklySync = isolatedSync("weekly-high-school-write-failure-program")
        highSchoolSync.clear()
        weeklySync.clear()
        defer {
            highSchoolSync.clear()
            weeklySync.clear()
        }
        let now = date("2026-08-05T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "high-school-write-failure")
        weekly.configure(eligibility: fullEligibility, now: now, calendar: calendar)
        let tasks = try XCTUnwrap(weekly.program?.tasks)
        weekly.record(
            tasks[0].kind, amount: tasks[0].target,
            eligibility: fullEligibility, now: now, calendar: calendar
        )
        weekly.record(
            tasks[1].kind, amount: tasks[1].target,
            eligibility: fullEligibility, now: now, calendar: calendar
        )
        let reward = try XCTUnwrap(weekly.claimableReward)
        let highSchool = HighSchoolCareerStore(
            sync: highSchoolSync,
            saveWriter: { _ in false }
        )
        highSchool.restoreOrCreate()
        let inheritanceBefore = highSchool.inheritance
        let receiptsBefore = highSchool.creditedExternalRewardIDs

        let accepted = highSchool.acceptExternalSoulReward(
            id: reward.id, soulPoints: reward.soulPoints
        )
        if accepted { _ = weekly.markClaimed(now: now) }

        XCTAssertFalse(accepted)
        XCTAssertEqual(highSchool.inheritance, inheritanceBefore)
        XCTAssertEqual(highSchool.creditedExternalRewardIDs, receiptsBefore)
        XCTAssertFalse(try XCTUnwrap(weekly.program).claimed)
        XCTAssertNotNil(weekly.claimableReward)
        XCTAssertTrue(weekly.stamps.isEmpty)
    }

    func testWeeklyClaimWriteFailureKeepsDurableReceiptThenRetryClaimsExactlyOnce() throws {
        let highSchoolSync = isolatedSync("weekly-retry-receipt")
        let weeklySync = isolatedSync("weekly-retry-claim")
        highSchoolSync.clear()
        weeklySync.clear()
        defer {
            highSchoolSync.clear()
            weeklySync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        var weeklyWriteFails = false
        let weekly = WeeklyProgramStore(
            sync: weeklySync,
            stableUserID: "weekly-retry-claim",
            saveWriter: { data in
                weeklyWriteFails ? false : weeklySync.write(data)
            }
        )
        let now = date("2026-08-05T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        weekly.configure(eligibility: fullEligibility, now: now, calendar: calendar)
        let tasks = try XCTUnwrap(weekly.program?.tasks)
        weekly.record(
            tasks[0].kind, amount: tasks[0].target,
            eligibility: fullEligibility, now: now, calendar: calendar
        )
        weekly.record(
            tasks[1].kind, amount: tasks[1].target,
            eligibility: fullEligibility, now: now, calendar: calendar
        )
        let reward = try XCTUnwrap(weekly.claimableReward)
        let highSchool = HighSchoolCareerStore(sync: highSchoolSync)
        highSchool.restoreOrCreate()
        let soulBefore = highSchool.inheritance.soulPoints
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        XCTAssertTrue(highSchool.acceptExternalSoulReward(
            id: reward.id, soulPoints: reward.soulPoints
        ))
        weeklyWriteFails = true
        XCTAssertFalse(weekly.markClaimed(now: now))

        XCTAssertEqual(highSchool.inheritance.soulPoints, soulBefore + reward.soulPoints)
        XCTAssertEqual(highSchool.creditedExternalRewardIDs, [reward.id])
        XCTAssertFalse(try XCTUnwrap(weekly.program).claimed)
        XCTAssertTrue(weekly.stamps.isEmpty)
        XCTAssertEqual(events.filter { $0 == .weeklyProgramCompleted }.count, 0)
        let beforeRetry = WeeklyProgramStore(sync: weeklySync, stableUserID: "weekly-retry-claim")
        XCTAssertFalse(try XCTUnwrap(beforeRetry.program).claimed)

        weeklyWriteFails = false
        XCTAssertTrue(highSchool.acceptExternalSoulReward(
            id: reward.id, soulPoints: reward.soulPoints
        ))
        XCTAssertTrue(weekly.markClaimed(now: now))

        XCTAssertEqual(highSchool.inheritance.soulPoints, soulBefore + reward.soulPoints)
        XCTAssertTrue(try XCTUnwrap(weekly.program).claimed)
        XCTAssertEqual(weekly.stamps.count, 1)
        XCTAssertEqual(events.filter { $0 == .weeklyProgramCompleted }.count, 1)
        XCTAssertFalse(weekly.markClaimed(now: now))
        XCTAssertEqual(weekly.stamps.count, 1)
        XCTAssertEqual(events.filter { $0 == .weeklyProgramCompleted }.count, 1)
        let reloaded = WeeklyProgramStore(sync: weeklySync, stableUserID: "weekly-retry-claim")
        XCTAssertTrue(try XCTUnwrap(reloaded.program).claimed)
        XCTAssertEqual(reloaded.stamps.count, 1)
    }

    func testRecordWriteFailureReplaysDurableReceiptExactlyOnceAfterRestart() throws {
        let sync = isolatedSync("weekly-record-atomic")
        let outbox = isolatedSync("weekly-record-atomic-outbox")
        sync.clear()
        outbox.clear()
        defer {
            sync.clear()
            outbox.clear()
        }
        let now = date("2026-08-05T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        var mainWriteFails = false
        let store = WeeklyProgramStore(
            sync: sync,
            stableUserID: "weekly-record-atomic",
            saveWriter: { data in mainWriteFails ? false : sync.write(data) },
            outboxSync: outbox
        )
        XCTAssertTrue(store.configure(eligibility: fullEligibility, now: now, calendar: calendar))
        let task = try XCTUnwrap(store.program?.tasks.first)
        let before = store.program

        mainWriteFails = true
        XCTAssertFalse(store.record(
            task.kind, amount: 1, eligibility: fullEligibility, now: now, calendar: calendar
        ))
        XCTAssertEqual(store.program, before, "실패한 main save가 관찰 진행을 먼저 바꾸면 안 됩니다.")

        let recovered = WeeklyProgramStore(
            sync: sync, stableUserID: "weekly-record-atomic", outboxSync: outbox
        )
        XCTAssertTrue(recovered.configure(
            eligibility: fullEligibility, now: now, calendar: calendar
        ))
        XCTAssertEqual(
            recovered.program?.tasks.first(where: { $0.kind == task.kind })?.progress,
            1
        )

        let secondReload = WeeklyProgramStore(
            sync: sync, stableUserID: "weekly-record-atomic", outboxSync: outbox
        )
        XCTAssertTrue(secondReload.configure(
            eligibility: fullEligibility, now: now, calendar: calendar
        ))
        XCTAssertEqual(secondReload.program, recovered.program, "처리 원장이 재시작 중복을 막아야 합니다.")
    }

    func testOutboxWriteFailureFallsBackToMainRecordWithoutLosingProgress() throws {
        let sync = isolatedSync("weekly-outbox-fallback")
        let outbox = isolatedSync("weekly-outbox-fallback-file")
        sync.clear()
        outbox.clear()
        defer {
            sync.clear()
            outbox.clear()
        }
        let now = date("2026-08-05T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        var outboxWriteFails = true
        let store = WeeklyProgramStore(
            sync: sync,
            stableUserID: "weekly-outbox-fallback",
            outboxSync: outbox,
            outboxWriter: { data in outboxWriteFails ? false : outbox.write(data) }
        )
        XCTAssertTrue(store.configure(eligibility: fullEligibility, now: now, calendar: calendar))
        let task = try XCTUnwrap(store.program?.tasks.first)

        XCTAssertTrue(store.record(
            task.kind, amount: 1, eligibility: fullEligibility, now: now, calendar: calendar
        ))
        XCTAssertEqual(
            store.program?.tasks.first(where: { $0.kind == task.kind })?.progress,
            1
        )

        outboxWriteFails = false
        let recovered = WeeklyProgramStore(
            sync: sync, stableUserID: "weekly-outbox-fallback", outboxSync: outbox
        )
        XCTAssertTrue(recovered.configure(
            eligibility: fullEligibility, now: now, calendar: calendar
        ))
        XCTAssertEqual(
            recovered.program?.tasks.first(where: { $0.kind == task.kind })?.progress,
            1,
            "fallback receipt는 재시작 뒤 다시 더해지면 안 됩니다."
        )
    }

    func testRolloverWriteFailureKeepsOldWeekUntilDeterministicRetry() throws {
        let sync = isolatedSync("weekly-rollover-atomic")
        sync.clear()
        defer { sync.clear() }
        let first = date("2026-08-05T12:00:00Z")
        let next = date("2026-08-12T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        var writeFails = false
        let store = WeeklyProgramStore(
            sync: sync,
            stableUserID: "weekly-rollover-atomic",
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        XCTAssertTrue(store.configure(eligibility: fullEligibility, now: first, calendar: calendar))
        let oldProgram = store.program
        let oldMoment = store.lastObservedWeekStart

        writeFails = true
        XCTAssertFalse(store.configure(eligibility: fullEligibility, now: next, calendar: calendar))
        XCTAssertEqual(store.program, oldProgram)
        XCTAssertEqual(store.lastObservedWeekStart, oldMoment)

        writeFails = false
        XCTAssertTrue(store.configure(eligibility: fullEligibility, now: next, calendar: calendar))
        let retried = try XCTUnwrap(store.program)
        XCTAssertNotEqual(retried.weekKey, oldProgram?.weekKey)
        let reloaded = WeeklyProgramStore(sync: sync, stableUserID: "weekly-rollover-atomic")
        XCTAssertEqual(reloaded.program, retried)
    }

    func testReconciliationWriteFailureRollsBackEligibilityAndBoardUntilRetry() throws {
        let sync = isolatedSync("weekly-reconcile-atomic")
        sync.clear()
        defer { sync.clear() }
        let now = date("2026-08-05T12:00:00Z")
        let calendar = calendar("Asia/Seoul")
        let school = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 5,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let pro = WeeklyProgramEligibility(
            hasHighSchoolCareer: false,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: true
        )
        let stableID = try XCTUnwrap((0..<100).lazy.map { "reconcile-atomic-\($0)" }.first { id in
            WeeklyProgramRules.make(
                weekKey: "2026-W32", stableUserID: id, eligibility: school
            )?.tasks.contains(where: { $0.kind == .chaptersAdvanced }) == true
        })
        var writeFails = false
        let store = WeeklyProgramStore(
            sync: sync,
            stableUserID: stableID,
            saveWriter: { data in writeFails ? false : sync.write(data) }
        )
        XCTAssertTrue(store.configure(eligibility: school, now: now, calendar: calendar))
        let original = try XCTUnwrap(store.program)

        writeFails = true
        XCTAssertFalse(store.configure(eligibility: pro, now: now, calendar: calendar))
        XCTAssertEqual(store.program, original)
        XCTAssertEqual(store.currentEligibility, school)

        writeFails = false
        XCTAssertTrue(store.configure(eligibility: pro, now: now, calendar: calendar))
        XCTAssertFalse(try XCTUnwrap(store.program).tasks.contains {
            $0.kind == .chaptersAdvanced
        })
        XCTAssertEqual(store.currentEligibility, pro)
    }

    func testClockRollbackAndTimezoneRoundTripCannotCreateASecondWeeklyReward() throws {
        let sync = isolatedSync("weekly-rollback")
        sync.clear()
        defer { sync.clear() }
        let instant = date("2026-08-10T00:00:00Z")
        let futureZone = calendar("Pacific/Kiritimati")
        let pastZone = calendar("America/Adak")
        let store = WeeklyProgramStore(sync: sync, stableUserID: "rollback-user")
        store.configure(eligibility: fullEligibility, now: instant, calendar: futureZone)
        let futureKey = try XCTUnwrap(store.program?.weekKey)
        let tasks = try XCTUnwrap(store.program?.tasks)
        store.record(tasks[0].kind, amount: tasks[0].target, eligibility: fullEligibility, now: instant, calendar: futureZone)
        store.record(tasks[1].kind, amount: tasks[1].target, eligibility: fullEligibility, now: instant, calendar: futureZone)
        store.markClaimed(now: instant)

        store.configure(eligibility: fullEligibility, now: instant, calendar: pastZone)
        XCTAssertEqual(store.program?.weekKey, futureKey)
        XCTAssertTrue(store.program?.claimed == true)
        XCTAssertNil(store.claimableReward)
        XCTAssertEqual(store.stamps.count, 1)

        store.configure(eligibility: fullEligibility, now: instant, calendar: futureZone)
        XCTAssertEqual(store.program?.weekKey, futureKey)
        XCTAssertEqual(store.stamps.count, 1)
    }

    func testFourWeekEconomyGuardTunesInitialTwentyFivePointRewardDownToFifteen() throws {
        // Representative assumption: one ordinary completed high-school run and one 2/3 weekly
        // board per week for four weeks. The run finishes at 48/48/50/50 with 40 K, 8 BB,
        // and 8 runs; no pledge or karma multiplier is applied. The deterministic v2 career
        // wind's existing legacy multiplier remains part of the production formula. The ordinary
        // reward itself is calculated by `nextInheritance` rather than copied into this test.
        let state = try representativeCompletedRun()
        let previous = HighSchoolCareerStore.Inheritance.firstLife
        let next = HighSchoolCareerStore.nextInheritance(
            from: state, memories: [], previous: previous, pledgeBonusPermille: 0
        )
        let ordinarySoul = next.soulPoints - previous.soulPoints
        XCTAssertEqual(ordinarySoul, 41)

        let initial = WeeklyEconomyProjection(
            weeks: 4, ordinaryRunSoulPerWeek: ordinarySoul, weeklyReward: 25
        )
        XCTAssertEqual(initial.weeklySharePermille, 378)
        XCTAssertGreaterThan(initial.weeklySharePermille, 200, "최초 25점은 20% 경제 가드를 넘습니다.")

        let tunedReward = WeeklyProgramReward.reward(for: "2026-W32")
        XCTAssertEqual(tunedReward.soulPoints, 15)
        let tuned = WeeklyEconomyProjection(
            weeks: 4, ordinaryRunSoulPerWeek: ordinarySoul, weeklyReward: tunedReward.soulPoints
        )
        XCTAssertEqual(tuned.weeklySharePermille, 267)
        XCTAssertLessThan(tuned.weeklySharePermille, initial.weeklySharePermille)
    }

    func testIncompleteWeekExpiresSilentlyWithoutStampOrPenalty() throws {
        let sync = isolatedSync("weekly-expiry")
        sync.clear()
        defer { sync.clear() }
        let calendar = calendar("Asia/Seoul")
        let first = date("2026-08-05T12:00:00Z")
        let next = date("2026-08-12T12:00:00Z")
        let store = WeeklyProgramStore(sync: sync, stableUserID: "expiry-user")
        store.configure(eligibility: fullEligibility, now: first, calendar: calendar)
        let task = try XCTUnwrap(store.program?.tasks.first)
        store.record(task.kind, amount: task.target, eligibility: fullEligibility, now: first, calendar: calendar)
        let oldKey = store.program?.weekKey

        store.configure(eligibility: fullEligibility, now: next, calendar: calendar)
        XCTAssertNotEqual(store.program?.weekKey, oldKey)
        XCTAssertEqual(store.program?.completedCount, 0)
        XCTAssertTrue(store.stamps.isEmpty)
    }

    func testISOWeekUsesInjectedTimezoneAcrossDSTAndWeekBoundary() throws {
        let losAngeles = calendar("America/Los_Angeles")
        let sunday = try XCTUnwrap(WeeklyProgramMoment.resolve(
            date: date("2026-03-08T09:30:00Z"),
            calendar: losAngeles
        ))
        let monday = try XCTUnwrap(WeeklyProgramMoment.resolve(
            date: date("2026-03-09T08:30:00Z"),
            calendar: losAngeles
        ))
        XCTAssertEqual(sunday.weekKey, "2026-W10")
        XCTAssertEqual(monday.weekKey, "2026-W11")
        XCTAssertLessThan(sunday.weekStart, monday.weekStart)

        let sameInstant = date("2026-08-10T00:00:00Z")
        let east = try XCTUnwrap(WeeklyProgramMoment.resolve(
            date: sameInstant,
            calendar: calendar("Pacific/Kiritimati")
        ))
        let west = try XCTUnwrap(WeeklyProgramMoment.resolve(
            date: sameInstant,
            calendar: calendar("America/Adak")
        ))
        XCTAssertNotEqual(east.weekKey, west.weekKey, "주 키는 고정 KST가 아니라 사용자의 시간대를 따라야 합니다.")
    }

    func testOpenedAnalyticsContractIncludesWeekKeyAndSource() throws {
        let program = try XCTUnwrap(WeeklyProgramRules.make(
            weekKey: "2026-W32",
            stableUserID: "analytics-user",
            eligibility: fullEligibility
        ))
        let properties = WeeklyProgramView.openedProperties(program: program)
        XCTAssertEqual(properties["week_key"] as? String, "2026-W32")
        XCTAssertEqual(properties["source"] as? String, "records")
        XCTAssertEqual(properties["completed_tasks"] as? Int, 0)
    }

    func testPledgeTaskRemainsEligibleAcrossBothPledgeSelectionPhases() {
        for phase in [HighSchoolCareerPhase.prologue, .schoolSelection] {
            let eligibility = AppShell.weeklyEligibility(
                highSchoolPhase: phase,
                importantGamesCompleted: 0,
                remainingImportantGames: 5,
                remainingChapterAdvances: 7,
                isChallengeRun: false,
                hasArchive: false,
                hasPreviousSchool: false,
                pledgeDecided: false,
                proPhase: nil
            )
            XCTAssertTrue(eligibility.canSelectPledge, "\(phase.rawValue)에서 약속을 고를 수 있어야 합니다.")
        }

        XCTAssertFalse(AppShell.weeklyEligibility(
            highSchoolPhase: .training,
            importantGamesCompleted: 0,
            remainingImportantGames: 5,
            remainingChapterAdvances: 7,
            isChallengeRun: false,
            hasArchive: false,
            hasPreviousSchool: false,
            pledgeDecided: false,
            proPhase: nil
        ).canSelectPledge)
    }

    func testActiveProOffersOnlyCurrentlyPlayableDailySequenceAndProTasks() throws {
        let eligibility = AppShell.weeklyEligibility(
            highSchoolPhase: .completed,
            importantGamesCompleted: 6,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            isChallengeRun: false,
            hasArchive: true,
            hasPreviousSchool: true,
            pledgeDecided: true,
            proPhase: .weeklyPlan
        )
        XCTAssertEqual(
            Set(WeeklyProgramRules.eligibleKinds(eligibility)),
            [.dailyInningCompleted, .sequenceMasteryTriggered, .proWeeksAdvanced, .playedOnTwoDays]
        )

        let first = WeeklyProgramRules.make(
            weekKey: "2026-W32", stableUserID: "active-pro", eligibility: eligibility
        )
        let second = WeeklyProgramRules.make(
            weekKey: "2026-W32", stableUserID: "active-pro", eligibility: eligibility
        )
        XCTAssertEqual(first, second)
        // 후보가 넷이고 칸은 셋이다 — 이틀 목표는 반드시 들어가고 나머지 둘만 해시 순서다.
        XCTAssertTrue(first?.tasks.contains { $0.kind == .playedOnTwoDays } == true)
        XCTAssertTrue(Set(first?.tasks.map(\.kind) ?? [])
            .isSubset(of: Set(WeeklyProgramRules.eligibleKinds(eligibility))))
        // 오늘의 이닝 목표가 보드에 오른 사람에게는 그 자리에서 바로 열 수 있어야 한다.
        let dailyUser = try XCTUnwrap((0..<100).lazy.map { "active-pro-\($0)" }.first { id in
            WeeklyProgramRules.make(weekKey: "2026-W32", stableUserID: id, eligibility: eligibility)?
                .tasks.contains { $0.kind == .dailyInningCompleted } == true
        })
        XCTAssertTrue(WeeklyProgramView.showsDailyLaunch(program: try XCTUnwrap(
            WeeklyProgramRules.make(weekKey: "2026-W32", stableUserID: dailyUser, eligibility: eligibility)
        )))
    }

    func testCompletedAndRetirementProNeverOfferProOrHiddenHighSchoolProgress() {
        for phase in [ProCareerPhase.completed, .retirementDecision] {
            let eligibility = AppShell.weeklyEligibility(
                highSchoolPhase: .completed,
                importantGamesCompleted: 6,
                remainingImportantGames: 0,
                remainingChapterAdvances: 0,
                isChallengeRun: false,
                hasArchive: true,
                hasPreviousSchool: true,
                pledgeDecided: true,
                proPhase: phase
            )
            let kinds = Set(WeeklyProgramRules.eligibleKinds(eligibility))
            XCTAssertFalse(kinds.contains(.proWeeksAdvanced), "\(phase.rawValue)에서는 프로 주차를 진행할 수 없습니다.")
            XCTAssertFalse(kinds.contains(.importantGamesCompleted))
            XCTAssertFalse(kinds.contains(.chaptersAdvanced))
            XCTAssertEqual(eligibility.canStartNextRun, phase == .completed)
        }
    }

    func testCompletedHighSchoolWithoutProOffersNoFinishedCareerProgressTasks() {
        let eligibility = AppShell.weeklyEligibility(
            highSchoolPhase: .completed,
            importantGamesCompleted: 6,
            remainingImportantGames: 0,
            remainingChapterAdvances: 0,
            isChallengeRun: false,
            hasArchive: true,
            hasPreviousSchool: true,
            pledgeDecided: true,
            proPhase: nil
        )
        let kinds = Set(WeeklyProgramRules.eligibleKinds(eligibility))

        XCTAssertFalse(eligibility.hasHighSchoolCareer)
        XCTAssertFalse(kinds.contains(.importantGamesCompleted))
        XCTAssertFalse(kinds.contains(.chaptersAdvanced))
        XCTAssertTrue(kinds.contains(.nextRunStarted))
        XCTAssertTrue(kinds.contains(.dailyInningCompleted))
        XCTAssertTrue(kinds.contains(.sequenceMasteryTriggered))
    }

    func testChallengeNeverOffersCanonicalHighSchoolGoalsButKeepsDailyUnlock() {
        let eligibility = AppShell.weeklyEligibility(
            highSchoolPhase: .schoolSelection,
            importantGamesCompleted: 1,
            remainingImportantGames: 5,
            remainingChapterAdvances: 7,
            isChallengeRun: true,
            hasArchive: true,
            hasPreviousSchool: true,
            pledgeDecided: false,
            proPhase: nil
        )
        let kinds = Set(WeeklyProgramRules.eligibleKinds(eligibility))

        XCTAssertFalse(eligibility.hasHighSchoolCareer)
        XCTAssertFalse(eligibility.canSelectPledge)
        XCTAssertFalse(eligibility.canChooseDifferentSchool)
        XCTAssertFalse(eligibility.canStartNextRun)
        XCTAssertTrue(eligibility.dailyInningUnlocked)
        XCTAssertEqual(kinds, [.dailyInningCompleted, .sequenceMasteryTriggered, .playedOnTwoDays])
    }

    func testLateHighSchoolOnlyOffersTwoStepGoalsWhenEnoughScheduleRemains() {
        func kinds(games: Int, chapters: Int) -> Set<WeeklyTaskKind> {
            let eligibility = AppShell.weeklyEligibility(
                highSchoolPhase: .training,
                importantGamesCompleted: 3,
                remainingImportantGames: games,
                remainingChapterAdvances: chapters,
                isChallengeRun: false,
                hasArchive: false,
                hasPreviousSchool: false,
                pledgeDecided: true,
                proPhase: nil
            )
            return Set(WeeklyProgramRules.eligibleKinds(eligibility))
        }

        XCTAssertTrue(kinds(games: 2, chapters: 2).contains(.importantGamesCompleted))
        XCTAssertTrue(kinds(games: 2, chapters: 2).contains(.chaptersAdvanced), "6장에서는 두 장을 마칠 수 있습니다.")
        XCTAssertFalse(kinds(games: 1, chapters: 2).contains(.importantGamesCompleted))
        XCTAssertFalse(kinds(games: 2, chapters: 1).contains(.chaptersAdvanced), "7장에서는 한 장만 남습니다.")
    }

    func testTooFewLateSeasonCandidatesCreateNoBoardAndDoNotDamageExistingBoard() throws {
        let lateEligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 1,
            remainingChapterAdvances: 1,
            dailyInningUnlocked: false,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        XCTAssertEqual(
            WeeklyProgramRules.eligibleKinds(lateEligibility),
            [.sequenceMasteryTriggered, .playedOnTwoDays]
        )
        XCTAssertNil(WeeklyProgramRules.make(
            weekKey: "2026-W32", stableUserID: "late-season", eligibility: lateEligibility
        ))

        let existing = try XCTUnwrap(WeeklyProgramRules.make(
            weekKey: "2026-W32", stableUserID: "late-season", eligibility: fullEligibility
        ))
        XCTAssertEqual(
            WeeklyProgramRules.reconciling(
                existing, stableUserID: "late-season", eligibility: lateEligibility
            ),
            existing,
            "세 후보를 채우지 못하면 같은 주의 진행과 계약을 그대로 보존해야 합니다."
        )
    }

    func testReconciliationKeepsOneOfTwoWhenOneChanceRemainsButReplacesAtZero() {
        let weekKey = "2026-W32"
        let game = WeeklyTask(
            id: "\(weekKey)-\(WeeklyTaskKind.importantGamesCompleted.rawValue)",
            kind: .importantGamesCompleted, target: 2, progress: 1
        )
        let daily = WeeklyTask(
            id: "\(weekKey)-\(WeeklyTaskKind.dailyInningCompleted.rawValue)",
            kind: .dailyInningCompleted, target: 1, progress: 0
        )
        let sequence = WeeklyTask(
            id: "\(weekKey)-\(WeeklyTaskKind.sequenceMasteryTriggered.rawValue)",
            kind: .sequenceMasteryTriggered, target: 3, progress: 0
        )
        let existing = WeeklyProgram(
            weekKey: weekKey, tasks: [game, daily, sequence], completedTaskIDs: [], claimed: false
        )
        let oneGameLeft = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 1,
            remainingChapterAdvances: 2,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )

        XCTAssertEqual(
            WeeklyProgramRules.reconciling(
                existing, stableUserID: "late-progress", eligibility: oneGameLeft
            ).tasks.first,
            game,
            "1/2 진행과 남은 공식 경기 한 번이면 기존 목표를 마칠 수 있습니다."
        )

        let noGamesLeft = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 0,
            remainingChapterAdvances: 2,
            dailyInningUnlocked: true,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let replaced = WeeklyProgramRules.reconciling(
            existing, stableUserID: "late-progress", eligibility: noGamesLeft
        )
        XCTAssertFalse(replaced.tasks.contains { $0.kind == .importantGamesCompleted })
        XCTAssertEqual(replaced.tasks.count, 3)
    }

    func testFailedHighSchoolActionDoesNotAdvanceInjectedWeeklyProgram() throws {
        let weeklySync = isolatedSync("weekly-failed-action")
        weeklySync.clear()
        defer { weeklySync.clear() }
        let eligibility = WeeklyProgramEligibility(
            hasHighSchoolCareer: true,
            remainingImportantGames: 5,
            remainingChapterAdvances: 7,
            dailyInningUnlocked: false,
            canStartNextRun: false,
            canSelectPledge: false,
            canChooseDifferentSchool: false,
            hasProCareer: false
        )
        let weekly = WeeklyProgramStore(sync: weeklySync, stableUserID: "failed-action")
        weekly.configure(eligibility: eligibility, now: date("2026-08-09T03:00:00Z"), calendar: calendar("Asia/Seoul"))
        // 어떤 목표가 보드에 올라오는지는 안정 해시가 정한다(한 칸은 이틀 목표로 고정).
        // 이 테스트가 지키는 것은 "실패한 행동은 어떤 칸도 올리지 않는다"이므로 보드 전체를 본다.
        let boardBefore = try XCTUnwrap(weekly.program?.tasks)
        let careerSync = isolatedSync("high-school-failed-action")
        careerSync.clear()
        defer { careerSync.clear() }
        let career = HighSchoolCareerStore(sync: careerSync, weekly: weekly)

        career.advanceChapter()
        career.chooseSchool(.allCases[0])

        XCTAssertEqual(weekly.program?.tasks, boardBefore)
        XCTAssertEqual(weekly.program?.completedCount, 0)
    }

    func testLegacyHighSchoolSaveWithoutExternalReceiptFieldStillDecodes() throws {
        let legacy = Data(#"{"inheritance":{"lifeNumber":1,"memories":[],"soulPoints":0,"karmas":[]},"revision":1}"#.utf8)
        let record = try JSONDecoder().decode(HighSchoolCareerStore.SaveRecord.self, from: legacy)
        XCTAssertNil(record.creditedExternalRewardIDs)
    }

    private func isolatedSync(_ prefix: String) -> SaveSync {
        SaveSync(key: "\(prefix)-\(UUID().uuidString).json")
    }

    private func calendar(_ identifier: String) -> Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: identifier)!
        return value
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func representativeCompletedRun() throws -> HighSchoolCareerSnapshot {
        let source = try HighSchoolCareerEngine().start(.init(
            seed: "20260809", presetID: "power_prospect", lifeNumber: 1
        )).snapshot
        let pitcher = PitcherSnapshot(
            id: source.pitcher.id,
            name: source.pitcher.name,
            stuff: 48,
            command: 48,
            movement: 50,
            stamina: 50,
            pitchProfiles: source.pitcher.pitchProfiles,
            throwingHand: source.pitcher.throwingHand
        )
        let performance = CareerPerformanceSnapshot(
            importantGamesCompleted: 4,
            pitches: 320,
            strikeouts: 40,
            walks: 8,
            runsAllowed: 8,
            expectedDamage: 3_200,
            actualDamage: 3_000
        )
        let encoder = JSONEncoder()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(source)) as? [String: Any]
        )
        object["pitcher"] = try JSONSerialization.jsonObject(with: encoder.encode(pitcher))
        object["performance"] = try JSONSerialization.jsonObject(with: encoder.encode(performance))
        return try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }
}
