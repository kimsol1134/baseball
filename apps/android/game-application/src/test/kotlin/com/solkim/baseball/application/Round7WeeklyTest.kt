package com.solkim.baseball.application

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.model.*
import com.solkim.baseball.persistence.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class Round7WeeklyTest {
    private fun payload(file: String): JsonValue.Obj = (StrictJson.parseUtf8(javaClass.getResourceAsStream("/regression/$file.json")!!.readBytes()) as JsonValue.Obj)["payload"] as JsonValue.Obj
    private fun claim(state: GameAggregateState) = GameCommandEnvelope(CommandReceiptRetention.id(state.revision,"weekly"),"weekly",state.revision,GameCommand.HighSchool(HighSchoolPhase4Command.ClaimWeeklyReward))

    @Test fun zeroThroughThreeTasksMatchTheNativeKernelAndRewardsAreOnceOnly(): Unit = runBlocking {
        for (completed in 0..3) {
            val dir = Files.createTempDirectory("round7-weekly-")
            var store = KotlinGameStore.open("weekly",CSharpLegacyGameStoreRepository(dir,"weekly"),NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                store.importCareerBackup(portableCareerFixture(weeklyNoteFixture(payload("high-school-terminal-v42"),completed)),store.current.revision)
                val before = store.current
                val controller = Phase8Controller(store)
                val action = controller.projection(Phase8ScreenId.P024_WEEKLY).actions.single { it.id=="claimWeeklyReward" }
                assertEquals(completed>=2,action.enabled)
                assertEquals(completed>=2,WeeklyNotePolicy.canClaim(before))
                assertTrue(action.description.contains("2"))
                if (completed<2) {
                    assertTrue(action.payloads.isEmpty())
                    val bytes=Files.readAllBytes(dir.resolve("save.json"))
                    repeat(3) {
                        val error=assertFails { store.dispatch(claim(store.current)) }
                        assertEquals("weekly.incomplete",error.message)
                        assertEquals(GameActionFailurePresentation.Kind.RULE,GameActionFailurePresentation.classify(error).kind)
                    }
                    assertEquals(before,store.current)
                    assertContentEquals(bytes,Files.readAllBytes(dir.resolve("save.json")))
                } else {
                    controller.execute(Phase8ScreenId.P024_WEEKLY,"claimWeeklyReward",action.payloads)
                    assertEquals(before.highSchool!!.inheritance.soulPoints+HighSchoolWeeklyRules.REWARD_SOUL_POINTS,store.current.highSchool!!.inheritance.soulPoints)
                    assertTrue(store.current.highSchool!!.weekly.rewardClaimed)
                    assertEquals(1,store.current.highSchool!!.weekly.stamps.count { it.weekKey==before.highSchool!!.weekly.weekKey })
                    assertFalse(WeeklyNotePolicy.canClaim(store.current))
                    store.close()
                    store=KotlinGameStore.open("weekly",CSharpLegacyGameStoreRepository(dir,"weekly"),NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                    val claimed=store.current
                    repeat(3) { assertEquals("weekly.already_claimed",assertFails { store.dispatch(claim(store.current)) }.message) }
                    assertEquals(claimed,store.current)
                    assertEquals("weekly.challenge_locked",HighSchoolWeeklyRules.rewardRejection(before.highSchool!!.weekly,true))
                    val next=HighSchoolWeeklyRules.configure(claimed.highSchool!!.weekly,claimed.highSchool!!.weekly.stableUserId,"2099-W38","2099-09-14",
                        HighSchoolWeeklyRules.Eligibility(true,5,5))
                    assertFalse(next.rewardClaimed)
                    assertNotNull(HighSchoolWeeklyRules.rewardRejection(next))
                    assertEquals(claimed.highSchool!!.weekly.stamps,next.stamps)
                }
            } finally {store.close();dir.toFile().deleteRecursively()}
        }
    }

    @Test fun linkedProfessionalSaveCannotExposeOrClaimHighSchoolWeeklyRewards(): Unit = runBlocking {
        val dir=Files.createTempDirectory("round7-pro-")
        val store=KotlinGameStore.open("weekly",CSharpLegacyGameStoreRepository(dir,"weekly"),NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            store.importCareerBackup(portableCareerFixture(weeklyNoteFixture(payload("round4-pro-week"),3)),store.current.revision)
            val before=store.current
            assertEquals(GameStage.PRO,before.stage)
            assertFalse(Phase8ScreenProjection.isReachable(before,Phase8ScreenId.P024_WEEKLY))
            assertFalse(WeeklyNotePolicy.canClaim(before))
            assertEquals("weekly.career_unavailable",assertFails { store.dispatch(claim(before)) }.message)
            assertEquals("weekly.career_unavailable",assertFails { GameStateReducer.dispatch(before,claim(before)) }.message)
            assertEquals(before,store.current)
            assertFalse(WeeklyNotePolicy.isAvailable(before.copy(stage=GameStage.RETIREMENT)))
            assertTrue(WeeklyNotePolicy.isAvailable(before.copy(stage=GameStage.HIGH_SCHOOL,pro=null)))
        } finally {store.close();dir.toFile().deleteRecursively()}
    }

    @Test fun businessRejectionsNeverEscalateToStorageAdvice() {
        val tracker=GameActionFailurePresentation.Repetition()
        val ioFailure=GameActionFailurePresentation.classify(java.io.IOException())
        val ruleFailure=GameActionFailurePresentation.classify(GameCommandException("weekly.incomplete"))
        repeat(3) { assertFalse(tracker.record("claimWeeklyReward",ruleFailure,1UL)) }
        assertFalse(tracker.record("claimWeeklyReward",ioFailure,1UL))
        assertTrue(tracker.record("claimWeeklyReward",ioFailure,1UL))
        assertFalse(tracker.record("claimWeeklyReward",ruleFailure,1UL))
        assertFalse(tracker.record("claimWeeklyReward",ioFailure,1UL))
        assertFalse(tracker.record("claimWeeklyReward",ioFailure,2UL))
        tracker.clear()
        assertFalse(tracker.record("claimWeeklyReward",ioFailure,2UL))
        for (code in listOf("weekly.incomplete","weekly.already_claimed","weekly.challenge_locked","weekly.career_unavailable")) {
            val failure=GameActionFailurePresentation.classify(GameCommandException(code))
            assertFalse(failure.countsAsStorageFailure)
            for(repeated in listOf(false,true)) {
                val text=GameActionFailurePresentation.message(failure,"claimWeeklyReward",repeated,false)
                assertFalse(text.contains("저장"));assertFalse(text.contains("한 번 더"));assertFalse(text.contains(code))
            }
        }
        assertEquals(GameActionFailurePresentation.Kind.UNKNOWN,GameActionFailurePresentation.classify(GameCommandException("unrecognized")).kind)
        val io=java.io.IOException("disk full")
        assertFalse(GameActionFailurePresentation.message(io,"claimWeeklyReward",true,true).contains("저장 공간"))
        val space=GameActionFailurePresentation.classify(java.nio.file.FileSystemException("save",null,"ENOSPC"))
        assertEquals(GameActionFailurePresentation.Kind.STORAGE_FULL,space.kind)
        assertTrue(GameActionFailurePresentation.message(space,"claimWeeklyReward",false,false).contains("저장 공간"))
        for (code in SaveFailureCode.entries.filter { it!=SaveFailureCode.IO_FAILED }) {
            val failure=GameActionFailurePresentation.classify(SaveRepositoryException(code,"test",io))
            assertFalse(failure.countsAsStorageFailure)
            assertFalse(GameActionFailurePresentation.message(failure,"claimWeeklyReward",true,true).contains("저장 공간"))
        }
    }
}
