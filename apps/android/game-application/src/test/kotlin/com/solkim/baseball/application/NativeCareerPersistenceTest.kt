package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class NativeCareerPersistenceTest {
    @Test fun nativeHighSchoolPreservesTheWholeCareerAcrossEveryReopen() = runBlocking {
        val directory = Files.createTempDirectory("baseball-native-career-")
        val id = "native-career-persistence"
        var store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            var index = 0
            suspend fun dispatch(command: GameCommand) {
                store.dispatch(GameCommandEnvelope("native-step-${index++}", "native-life", store.current.revision, command))
                val before = store.current.highSchool
                store.close()
                store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                assertEquals(before, store.current.highSchool, "all HS fields must survive a production-writer restart")
            }
            dispatch(GameCommand.EnterSetup)
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.Start(HighSchoolPhase4StartRequest(
                seed = "98761", presetId = "power_prospect", stableUserId = id,
                weekKey = "2026-W36", dayKey = "2026-09-05", inheritedSoulPoints = 180,
                inheritedSoulTotal = 60, inheritedSoulDomain = HighSchoolSoulDomain.TECHNIQUE,
            ))))
            val startingPitcher = store.current.highSchool!!.startingPitcher
            assertEquals(180, store.current.highSchool!!.inheritance.soulPoints)
            assertEquals(60, store.current.highSchool!!.inheritance.automaticSoulEarned)
            assertEquals("2026-W36", store.current.highSchool!!.weekly.weekKey)
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial))
            assertTrue(store.current.highSchool!!.tutorial.started)
            assertFalse(store.current.highSchool!!.tutorial.completed)
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("98762")))
            val school = store.current.highSchool!!.run.schoolOptions.first().id
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("98763", school)))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.Training("98764", HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)))
            assertEquals(startingPitcher, store.current.highSchool!!.startingPitcher)
            assertTrue(store.current.highSchool!!.trainingEvidence.isNotEmpty())
        } finally {
            store.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }

    @Test fun nativeProUsesTheEncodedAlphabetAndKeepsTheRealSnapshot() = runBlocking {
        val directory = Files.createTempDirectory("baseball-native-pro-")
        val id = "native-pro-persistence"
        var store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            store.dispatch(GameCommandEnvelope("native-pro-start", "native-pro", store.current.revision,
                GameCommand.Pro(ProCommand.StartDirect(ProStartDirectRequest("917649", "breaking_ball_artist", "민서준")))))
            assertNotNull(store.current.pro)
            val before = store.current.pro!!
            store.close()
            store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(before, store.current.pro)
            store.dispatch(GameCommandEnvelope("native-pro-week", "native-pro", store.current.revision,
                GameCommand.Pro(ProCommand.PlanWeek(before.seed, ProWeekPlan.EARN_TRUST))))
            assertEquals(1, store.current.pro!!.week)
            val after = store.current.pro
            store.close()
            store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(after, store.current.pro)
        } finally {
            store.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
