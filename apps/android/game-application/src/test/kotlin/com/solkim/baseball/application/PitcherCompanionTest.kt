package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.model.StrictJson
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class PitcherCompanionTest {
    @Test fun configurationTrainingAndMemoriesSurviveBothWritersAndRestart() = runBlocking {
        for (native in listOf(false, true)) {
            val directory = Files.createTempDirectory("baseball-companion-test-")
            val id = "companion-$native"
            fun repo(): GameStoreRepository = if (native) CSharpLegacyGameStoreRepository(directory, id) else FileShadowFixtureGameStoreRepository(directory)
            val mode = if (native) NativeAuthorityMode.NATIVE_AUTHORITATIVE else NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY
            var store = KotlinGameStore.open(id, repo(), mode)
            try {
                var number = 0
                suspend fun send(command: GameCommand) = store.dispatch(GameCommandEnvelope("companion-test-${number++}", "test", store.current.revision, command))
                send(GameCommand.EnterSetup)
                send(GameCommand.HighSchool(HighSchoolPhase4Command.Start(HighSchoolPhase4StartRequest("918220", "power_prospect", id, "2026-W37", "2026-09-08"))))
                send(GameCommand.UpdateCompanion("jersey", "27"))
                send(GameCommand.UpdateCompanion("pitch", "four_seam"))
                send(GameCommand.UpdateCompanion("goal", "signature"))
                val before = store.current
                assertFailsWith<IllegalArgumentException> { send(GameCommand.UpdateCompanion("jersey", "0")) }
                assertEquals(before, store.current)
                send(GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial))
                send(GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("918220")))
                send(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("918220", HighSchoolSchoolId.HAEDONG_POWER)))
                send(GameCommand.HighSchool(HighSchoolPhase4Command.Training("918220", HighSchoolTrainingFocus.VELOCITY, HighSchoolTrainingIntensity.LIGHT)))
                val companion = store.current.meta.companion!!
                assertEquals(1, companion.experience.single { it.pitch == "four_seam" }.training)
                assertEquals(27, companion.jersey)
                assertEquals("signature", companion.goal)
                assertEquals(companion, PitcherCompanionCodec.decode(StrictJson.parseUtf8(StrictJson.canonical(PitcherCompanionCodec.encode(companion)).toByteArray())))
                store.close()
                store = KotlinGameStore.open(id, repo(), mode)
                assertEquals(companion, store.current.meta.companion)
            } finally { store.close(); directory.toFile().deleteRecursively() }
        }
    }
    @Test fun actualOfficialStrikeoutCompletesTheChosenGoalExactlyOnce() {
        val k = HighSchoolPhase4Kernel()
        var hs = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "actual-pitch", "2026-W37", "2026-09-08")).state
        hs = k.completePrologue("918220", k.beginTutorial(hs).state).state
        hs = k.chooseSchool("918220", hs, HighSchoolSchoolId.HAEDONG_POWER).state
        var guard = 0
        while (hs.run.phase != HighSchoolPhase.IMPORTANT_GAME && guard++ < 100) hs = when (hs.run.phase) {
            HighSchoolPhase.TRAINING -> k.commitTraining("918220", hs, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD).state
            HighSchoolPhase.RELATIONSHIP -> k.resolveRelationship("918220", hs, HighSchoolRelationshipResponse.LISTEN).state
            HighSchoolPhase.CHAPTER_REVIEW -> k.advanceChapter("918220", hs).state
            HighSchoolPhase.AWAKENING -> k.chooseAwakening("918220", hs, hs.run.awakeningOptions.first()).state
            else -> error("Unexpected phase")
        }
        val ready = hs
        var achieved = false
        for (seed in 918220..918240) {
            hs = k.reserveImportantGame(seed.toString(), ready).state
            var state = GameAggregateState.initial("actual-pitch").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
            state = state.copy(meta = state.meta.copy(companion = PitcherCompanionRules.apply(state, "goal", "signature")))
            repeat(40) {
                val session = state.highSchool!!.activePitch ?: return@repeat
                if (session.ended || achieved) return@repeat
                val before = state
                val call = k.prepareActivePitch(state.highSchool!!).primaryRecommendation.call.copy(pitchType = PitchKind.FOUR_SEAM)
                hs = k.submitPitch(state.highSchool!!, session.sessionId, call, com.solkim.baseball.core.pitch.PitchDelivery(1000, 1000)).state
                val after = state.copy(highSchool = hs)
                val companion = PitcherCompanionRules.transition(before, after)!!
                state = after.copy(meta = after.meta.copy(companion = companion))
                assertEquals(hs.activePitch!!.strikeouts, companion.experience.sumOf { it.strikeouts })
                assertEquals(companion, PitcherCompanionRules.transition(state, state))
                if (companion.goalCompleted) {
                    assertEquals(1, companion.memories.count { it.kind == "goal_signature" })
                    assertEquals(1, companion.memories.count { it.kind == "first_strikeout" })
                    assertTrue(companion.experience.single { it.pitch == "four_seam" }.rank >= 2)
                    achieved = true
                }
            }
            if (achieved) break
        }
        assertTrue(achieved)
    }

    @Test fun pinnedMemoriesAndRepresentativeProgressPersistAcrossLivesWithoutRewardFabrication() {
        val k = HighSchoolPhase4Kernel()
        val hs = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "companion", "2026-W37", "2026-09-08")).state
        val memory = PitchMemory("m1", hs.run.careerId, 1, "pitch_strikeout", "four_seam", 1)
        val saved = PitcherCompanion(career = hs.run.careerId, nickname = "나의 포심", pinned = "m1", jersey = 27,
            experience = listOf(SignatureExperience("four_seam", 3, 5, 1)), memories = listOf(memory), nicknames = mapOf("four_seam" to "나의 포심"))
        val before = GameAggregateState.initial("companion").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs, meta = GameMetaState(companion = saved))
        val after = before.copy(highSchool = hs.copy(run = hs.run.copy(careerId = "life-2", lifeNumber = 2)))
        val c = PitcherCompanionRules.transition(before, after)!!
        assertEquals(saved.memories, c.memories)
        assertEquals(saved.experience, c.experience)
        assertEquals(saved.nickname, c.nickname)
        assertEquals(saved.pinned, c.pinned)
        assertEquals(27, c.jersey)
        assertEquals(4, c.previousStart.size)
        assertEquals(0, c.careerStrikeouts)
        val changed = before.copy(meta = before.meta.copy(companion = PitcherCompanionRules.apply(before, "pitch", "slider")))
        assertEquals("나의 포심", PitcherCompanionRules.apply(changed, "pitch", "four_seam").nickname)
        assertFailsWith<IllegalArgumentException> { PitcherCompanionRules.apply(before, "pin", "unknown") }
        assertEquals(saved, PitcherCompanionRules.transition(before, before))
    }
}
