package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pitch.AbilityMasterySnapshot
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class AbilityHistoryTest {
    private fun state(): GameAggregateState {
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "ability", "2026-W37", "2026-09-09")).state
        return GameAggregateState.initial("ability").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
    }
    @Test fun actualChangesAndMasteryAreRecordedOnceWithoutInventingOlderHistory() {
        val before = state()
        val hs = before.highSchool!!
        val after = before.copy(highSchool = hs.copy(run = hs.run.copy(pitcher = hs.run.pitcher.copy(command = hs.run.pitcher.command + 2))))
        val points = AbilityHistory.transition(before, after, "train-one")
        assertEquals(2, points.size)
        assertEquals("observed", points.first().source)
        assertEquals(before.highSchool!!.run.pitcher.command, points.first().ratings[1])
        assertEquals(after.highSchool!!.run.pitcher.command, points.last().ratings[1])
        val saved = after.copy(meta = after.meta.copy(abilityHistory = points))
        assertEquals(points, AbilityHistory.transition(saved, saved, "view"))
        val mastered = saved.copy(highSchool = after.highSchool!!.copy(run = after.highSchool!!.run.copy(
            pitcher = after.highSchool!!.run.pitcher.copy(mastery = AbilityMasterySnapshot(command = 1)))))
        val history = AbilityHistory.transition(saved, mastered, "mastery")
        assertEquals(3, history.size)
        assertEquals(history[1].ratings, history[2].ratings)
        assertEquals(1, history[2].mastery[1])
        assertEquals(history, AbilityHistory.decode(AbilityHistory.encode(history)))
    }
    @Test fun newLifePreservesEarlierPointsAndStartsANewSeries() {
        val first = state()
        val old = AbilityHistory.transition(GameAggregateState.initial("ability"), first, "start")
        val before = first.copy(meta = first.meta.copy(abilityHistory = old))
        val second = first.copy(highSchool = first.highSchool!!.copy(run = first.highSchool!!.run.copy(careerId = "second-life", lifeNumber = 2)))
        val points = AbilityHistory.transition(before, second, "rebirth")
        assertEquals(old, points.take(old.size))
        assertEquals("second-life", points.last().career)
        assertEquals("start", points.last().source)
        assertEquals(emptyList(), AbilityHistory.decode(null))
    }
    @Test fun nativeTrainingBackupRestartAndDuplicateCommandsKeepTheHistory() = runBlocking {
        val directory = Files.createTempDirectory("ability-history-test")
        val repo = CSharpLegacyGameStoreRepository(directory, "history-native")
        var store = KotlinGameStore.open("history-native", repo, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val controller = ScreenController(store)
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            controller.execute(ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(ScreenId.P003_PROLOGUE, "completeTutorial")
            controller.execute(ScreenId.P005_SCHOOL_SELECTION, "chooseSchool:haedong_power")
            val phase = store.current.highSchool!!
            val envelope = GameCommandEnvelope("history-training", CareerWire.highSchoolSession(store.current), store.current.revision,
                GameCommand.HighSchool(HighSchoolPhase4Command.Training("99881", HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)))
            store.dispatch(envelope)
            val history = store.current.meta.abilityHistory
            assertTrue(history.size >= 2)
            assertEquals(store.current.highSchool!!.run.pitcher.command, history.last().ratings[1])
            assertFailsWith<GameCommandException> { store.dispatch(envelope) }
            assertEquals(history, store.current.meta.abilityHistory)
            val backup = store.exportCareerBackup()
            assertEquals(history, CareerBackup.preview(backup).meta.abilityHistory)
            store.close(); store = KotlinGameStore.open("history-native", repo, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(history, store.current.meta.abilityHistory)
            val restored = KotlinGameStore.open("history-restored", CSharpLegacyGameStoreRepository(directory.resolve("restored"), "history-restored"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try { restored.importCareerBackup(backup, restored.current.revision); assertEquals(history, restored.current.meta.abilityHistory) } finally { restored.close() }
            assertTrue(store.current.highSchool!!.run.totalTrainingsCompleted > phase.run.totalTrainingsCompleted)
        } finally {
            store.close()
            directory.toFile().deleteRecursively()
        }
    }
}
