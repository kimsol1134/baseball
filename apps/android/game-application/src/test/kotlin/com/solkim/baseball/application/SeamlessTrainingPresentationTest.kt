package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.persistence.SaveLoadStatus
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class SeamlessTrainingPresentationTest {
    @Test fun previewPreservesOptionalGameAndCommitsExactlyOneAdvanceAndChosenTrainingOnBothWriters() = runBlocking {
        for (native in listOf(false, true)) {
            val directory = Files.createTempDirectory("seamless-training-")
            try {
                val repository: GameStoreRepository = if (native) CSharpLegacyGameStoreRepository(directory, "seamless-test")
                    else FileShadowFixtureGameStoreRepository(directory)
                val store = KotlinGameStore.open("seamless-test", repository,
                    if (native) NativeAuthorityMode.NATIVE_AUTHORITATIVE else NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
                val controller = ScreenController(store)
                controller.execute(ScreenId.P001_OPENING, "enterSetup")
                controller.execute(ScreenId.P002_SETUP, "startHighSchool")
                controller.execute(ScreenId.P003_PROLOGUE, "beginTutorial")
                controller.execute(ScreenId.P003_PROLOGUE, "completeTutorial")
                val pitchSession = PitchSessionController(store)
                var guard = 0
                while (store.current.highSchool!!.run.phase != HighSchoolPhase.CHAPTER_REVIEW) {
                    assertTrue(++guard < 180)
                    val screen = controller.preferredScreen()
                    val action = if (screen == ScreenId.P008_IMPORTANT_GAME) {
                        val id = if (store.current.highSchool?.activePitch == null) "openImportantGame" else "nextImportantPitch"
                        controller.projection(screen).actions.single { it.id == id && it.enabled }
                    } else controller.projection(screen).actions.first { it.enabled }
                    controller.execute(screen, action.id)
                    if (screen == ScreenId.P008_IMPORTANT_GAME) {
                        val session = store.current.pitch!!.sessionId
                        val request = pitchSession.submitPitch(session, 0, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(1_000, 1_000))
                        pitchSession.consumePresentation(session, request)
                        pitchSession.completePitchAndPostgame(session)
                    }
                }
                val before = store.current
                val preview = assertNotNull(SeamlessTrainingPresentation.next(before, controller.context))
                assertEquals(before, store.current, "Preview must never write")
                assertTrue(controller.projection(ScreenId.P010_CHAPTER).actions.single { it.id == "claimChapterGame" }.enabled)
                assertEquals(before.highSchool!!.run.chapter.number + 1, preview.state.highSchool!!.run.chapter.number)
                val payloads = TrainingPresentation.payloads(preview.state, controller.context, TrainingFocus.COMMAND, TrainingIntensity.LIGHT, null, false)
                val batch = SeamlessTrainingPresentation.commit(before, preview, payloads)
                controller.execute(ScreenId.P010_CHAPTER, "advanceChapter", batch)
                val after = store.current
                assertEquals(before.highSchool!!.run.chapter.number + 1, after.highSchool!!.run.chapter.number)
                assertEquals(before.highSchool!!.run.totalTrainingsCompleted + 1, after.highSchool!!.run.totalTrainingsCompleted)
                assertEquals(TrainingFocus.COMMAND, after.highSchool!!.trainingEvidence.last().focus)
                assertEquals(TrainingIntensity.LIGHT, after.highSchool!!.trainingEvidence.last().intensity)
                assertEquals(1, after.highSchool!!.run.chapterTrainingCount)
                if (native) assertFailsWith<GameCommandException> { store.dispatchBatch(batch.map { it.envelope }) }
                else store.dispatchBatch(batch.map { it.envelope })
                assertEquals(after, store.current, "Retry must not repeat training or advancement")
                assertEquals(SaveLoadStatus.LOADED_CANONICAL, repository.load().status)
                assertEquals(after.highSchool, repository.load().envelope!!.payload.highSchool)
                store.close()
            } finally { directory.toFile().deleteRecursively() }
        }
    }
}
