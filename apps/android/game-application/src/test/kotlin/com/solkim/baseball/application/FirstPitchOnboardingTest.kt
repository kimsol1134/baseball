package com.solkim.baseball.application

import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class FirstPitchOnboardingTest {
    @Test fun firstLifeOpensMoundButWaitsForExplicitDeliveryAndPracticeLeadsToSchool() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("onboarding-first"))
        try {
            val controller = ScreenController(store)
            controller.executePlayerAction(ScreenId.P001_OPENING, "enterSetup")
            val launch = assertNotNull(controller.executePlayerAction(ScreenId.P002_SETUP, "startHighSchool").launch)
            assertEquals(PitchBoundary.PLAYING, store.current.pitch?.boundary)
            assertEquals(null, store.current.highSchool?.lastPresentation)
            assertFalse(store.current.settings.autoReleaseEnabled)
            assertEquals(PitchCareerKind.TUTORIAL, store.current.pitch?.careerKind)
            assertTrue(store.current.highSchool!!.tutorial.started)
            throwPractice(store)
            assertEquals(null, controller.finishPractice(launch.sessionId, repeat = false).launch)
            assertEquals(ScreenId.P005_SCHOOL_SELECTION, controller.preferredScreen())
            assertEquals(0, store.current.highSchool!!.run.performance.pitches)
        } finally { store.close() }
    }

    @Test fun repeatPracticeAdvancesAndStopsOfferingMoreAfterThirdPitch() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("onboarding-repeat"))
        try {
            val controller = ScreenController(store)
            controller.executePlayerAction(ScreenId.P001_OPENING, "enterSetup")
            controller.executePlayerAction(ScreenId.P002_SETUP, "startHighSchool")
            repeat(3) { index ->
                val session = assertNotNull(store.current.pitch).sessionId
                throwPractice(store)
                assertEquals(index + 1, store.current.highSchool!!.lastPresentation!!.pitchNumber)
                if (index < 2) assertNotNull(controller.finishPractice(session, repeat = true).launch)
                else {
                    PitchSessionController(store).completePitchAndPostgame(session)
                    assertFalse(controller.projection(ScreenId.P003_PROLOGUE).actions.single { it.id == "openTutorialPitch" }.enabled)
                    controller.finishPractice(session, repeat = false)
                }
            }
            assertEquals(ScreenId.P005_SCHOOL_SELECTION, controller.preferredScreen())
            assertEquals(0, store.current.highSchool!!.run.performance.pitches)
        } finally { store.close() }
    }

    private suspend fun throwPractice(store: KotlinGameStore) {
        val pitchSession = PitchSessionController(store)
        val session = requireNotNull(store.current.pitch).sessionId
        val request = pitchSession.submitPitch(session, 0, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(900, 900))
        pitchSession.consumePresentation(session, request)
    }
}
