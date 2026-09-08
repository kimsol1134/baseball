package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.pitch.PitchDelivery
import kotlinx.coroutines.runBlocking
import kotlin.test.*

class InitialPracticeEntryTest {
    @Test fun playerSetupReservesPracticeWithoutThrowingAndResultLeadsToSchool() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("direct-practice"))
        try {
            val controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            val execution = controller.executePlayerAction(Phase8ScreenId.P002_SETUP, "startHighSchool")
            val launch = assertNotNull(execution.launch)
            assertEquals(PitchCareerKind.TUTORIAL, store.current.pitch!!.careerKind)
            assertEquals(PitchBoundary.PLAYING, store.current.pitch!!.boundary)
            assertEquals(HighSchoolPhase.PROLOGUE, store.current.highSchool!!.run.phase)
            assertNull(store.current.highSchool!!.lastPresentation)
            assertEquals(0UL, store.current.meta.completedGameCount)
            val phase7 = Phase7VerticalController(store)
            val request = phase7.submitPitch(launch.sessionId, PitchHudSelection.Primary, PitchDelivery(800, 800))
            phase7.consumePresentation(launch.sessionId, request)
            val again = assertNotNull(controller.finishPractice(launch.sessionId, repeat = true).launch)
            assertNotNull(store.current.highSchool!!.lastPresentation, "Repeating practice retains the first result so guidance is not shown again")
            val second = phase7.submitPitch(again.sessionId, PitchHudSelection.Primary, PitchDelivery(800, 800))
            phase7.consumePresentation(again.sessionId, second)
            val after = controller.finishPractice(again.sessionId, repeat = false)
            assertNull(after.launch)
            assertEquals(Phase8ScreenId.P005_SCHOOL_SELECTION, controller.preferredScreen())
            assertEquals(0UL, store.current.meta.completedGameCount)
        } finally { store.close() }
    }
    @Test fun oldReservedPracticeCanReopenWithoutReservingOrThrowingAgain() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("reserved-practice"))
        try {
            val controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.executePlayerAction(Phase8ScreenId.P002_SETUP, "startHighSchool")
            val before = store.current
            val result = controller.execute(Phase8ScreenId.P004_PITCH_TUTORIAL, "openTutorialPitch")
            assertEquals(before.pitch!!.sessionId, result.launch!!.sessionId)
            assertEquals(before, store.current)
        } finally { store.close() }
    }
}
