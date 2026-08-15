package com.solkim.baseball.core.highschool

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue
import kotlin.test.assertFailsWith

class HighSchoolPhase4MetaRulesTest {
    @Test
    fun achievementLedgerRetainsFutureIdsAndAcknowledgesOnlyPendingEntry() {
        val first = HighSchoolAchievementRules.unlock(
            emptyList(), emptyList(), listOf(HighSchoolAchievementRules.FIRST_DRAFT, "future_achievement"),
        )
        val duplicate = HighSchoolAchievementRules.unlock(
            first.unlocked, first.unacknowledged, listOf(HighSchoolAchievementRules.FIRST_DRAFT),
        )
        val acknowledged = HighSchoolAchievementRules.acknowledge(
            duplicate.unlocked, duplicate.unacknowledged, HighSchoolAchievementRules.FIRST_DRAFT,
        )

        assertEquals(listOf("first_draft", "future_achievement"), first.unlocked)
        assertEquals(first, duplicate)
        assertEquals(listOf("future_achievement"), acknowledged.unacknowledged)
        assertEquals(first.unlocked, acknowledged.unlocked)
    }

    @Test
    fun weeklyBoardIsStableReceiptedTwoDayAwareAndStampedOnClaim() {
        val eligibility = HighSchoolWeeklyRules.Eligibility(
            hasHighSchoolCareer = true,
            remainingImportantGames = 4,
            remainingChapterAdvances = 5,
            canStartNextRun = true,
            canSelectPledge = true,
            canChooseDifferentSchool = true,
        )
        val first = HighSchoolWeeklyRules.make("2026-W33", "user-a", eligibility)!!
        val second = HighSchoolWeeklyRules.make("2026-W33", "user-a", eligibility)!!
        assertEquals(first.tasks.map { it.kind }, second.tasks.map { it.kind })
        assertEquals(3, first.tasks.size)
        assertEquals("played_on_two_days", first.tasks.first().kind)

        var current = HighSchoolWeeklyRules.configure(
            HighSchoolWeeklyState("user-a", "2026-W33", first.tasks),
            "user-a", "2026-W33", "2026-08-10", eligibility,
        )
        current = HighSchoolWeeklyRules.record(current, "played_on_two_days", receiptId = "r1", dayKey = "2026-08-11")
        val duplicate = HighSchoolWeeklyRules.record(current, "played_on_two_days", receiptId = "r1", dayKey = "2026-08-12")
        assertEquals(current, duplicate)
        current = HighSchoolWeeklyRules.record(current, "played_on_two_days", receiptId = "r2", dayKey = "2026-08-12")
        assertEquals(2, current.tasks.first { it.kind == "played_on_two_days" }.progress)

        val claimed = HighSchoolWeeklyRules.claim(current.copy(
            tasks = current.tasks.map { task ->
                if (task.kind == "played_on_two_days" || task == current.tasks[1]) {
                    task.copy(progress = task.target, completed = true)
                } else task
            },
        ), earnedAtUnixSeconds = 1234L)
        assertTrue(claimed.rewardClaimed)
        assertEquals(1, claimed.stamps.size)
        assertEquals("2026-W33", claimed.stamps.single().weekKey)
        assertEquals(claimed, HighSchoolWeeklyRules.configure(
            claimed, "user-a", "2026-W33", "2026-08-09", eligibility,
        ))
    }

    @Test
    fun returnPlanUsesStableSeoulDayReceiptAndRetiresDailyDestination() {
        val base = HighSchoolReturnPlan(
            destination = HighSchoolReturnDestination.HIGH_SCHOOL,
            reason = "high_school_phase",
            createdDayKey = "2026-08-09",
            receiptId = "legacy-receipt",
            title = "이번 선수 이어가기",
            body = "다음 경기가 기다립니다.",
            route = "high-school",
        )
        val first = HighSchoolReturnPlanRules.prepareForNextReturn(base, "stable-player", 4, "2026-08-09")
        val replay = HighSchoolReturnPlanRules.prepareForNextReturn(base, "stable-player", 4, "2026-08-09")
        val nextDay = HighSchoolReturnPlanRules.prepareForNextReturn(base, "stable-player", 4, "2026-08-10")
        assertEquals(first.receiptId, replay.receiptId)
        assertEquals("next_action_v2", first.experimentId)
        assertEquals("2026-08-09", first.savedDayKey)
        assertNotEquals(first.receiptId, nextDay.receiptId)
        assertEquals(1, HighSchoolReturnPlanRules.dayGap(first.savedDayKey, "2026-08-10"))
        assertTrue(HighSchoolReturnPlanRules.isValid(first))
        assertTrue(HighSchoolReturnPlanRules.isRetiredDailyPlan(
            base.copy(destination = HighSchoolReturnDestination.DAILY_INNING, route = "daily-inning"),
        ))
        assertFailsWith<IllegalArgumentException> {
            HighSchoolReturnPlanRules.prepareForNextReturn(base, "stable-player", 4, "2026-08-09T00:00:00")
        }

        val kernel = HighSchoolPhase4Kernel()
        val eligibleState = kernel.commitShadowState(
            kernel.start(
                HighSchoolPhase4StartRequest("918220", "power_prospect", "stable-player", "2026-W33", "2026-08-09"),
            ).state.copy(
                completedGameCounter = 1UL,
                completedGameReceipts = listOf("game-1"),
                returnPlan = base.copy(receiptId = "aabbccdd"),
            ),
        )
        val prepared = kernel.prepareReturnPlan(eligibleState, "2026-08-09", 4).state
        assertEquals(first.receiptId, prepared.returnPlan!!.receiptId)
        assertEquals(first.experimentVariant, prepared.returnPlan.experimentVariant)
    }

    @Test
    fun completedGameCounterRejectsNegativeAndOverflowAndIsMonotonic() {
        assertEquals(3UL, HighSchoolCompletedGameCounterRules.record(2UL))
        assertEquals(2UL, HighSchoolCompletedGameCounterRules.record(2UL, 0))
        assertFailsWith<IllegalArgumentException> { HighSchoolCompletedGameCounterRules.record(0UL, -1) }
        assertFailsWith<IllegalArgumentException> { HighSchoolCompletedGameCounterRules.record(ULong.MAX_VALUE) }
    }

    @Test
    fun richMetaStateAndCommandWiresRoundTripExactly() {
        val kernel = HighSchoolPhase4Kernel()
        val started = kernel.start(
            HighSchoolPhase4StartRequest("918220", "power_prospect", "meta-wire", "2026-W33", "2026-08-14"),
        ).state
        val weekly = started.weekly.copy(
            tasks = started.weekly.tasks.map { it.copy(kind = it.id) },
            stamps = listOf(HighSchoolWeeklyStamp("2026-W32", 3, true, 100L)),
            lastObservedWeekStartDayKey = "2026-08-10",
        )
        val plan = HighSchoolReturnPlan(
            HighSchoolReturnDestination.HIGH_SCHOOL,
            "high_school_phase",
            "2026-08-14",
            "aabbccdd",
            route = "high-school",
            title = "이번 선수 이어가기",
            body = "다음 경기가 기다립니다.",
            experimentId = "next_action_v2",
            savedDayKey = "2026-08-14",
            experimentVariant = "guided",
            developmentRulesVersion = 4,
        )
        val rich = kernel.commitShadowState(started.copy(
            achievements = listOf("first_draft", "future_achievement"),
            unacknowledgedAchievements = listOf("future_achievement"),
            weekly = weekly,
            returnPlan = plan,
        ))
        assertEquals(rich, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(rich)))

        val envelope = HighSchoolPhase4CommandEnvelope(
            commandId = "ack-wire",
            sessionId = "meta-wire",
            expectedRevision = rich.revision,
            command = HighSchoolPhase4Command.AcknowledgeAchievement("future_achievement"),
        )
        assertEquals(envelope, HighSchoolPhase4CommandCodec.decode(HighSchoolPhase4CommandCodec.encode(envelope)))
        val returnEnvelope = envelope.copy(
            commandId = "return-wire",
            command = HighSchoolPhase4Command.SaveReturnPlan(plan),
        )
        assertEquals(returnEnvelope, HighSchoolPhase4CommandCodec.decode(HighSchoolPhase4CommandCodec.encode(returnEnvelope)))
    }
}
