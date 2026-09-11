package com.solkim.baseball.application

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CareerUiRulesTest {
    @Test
    fun emptyAggregateHasNoCareerChrome() {
        val state = GameAggregateState.initial("career-ui-empty")
        assertFalse(CareerUiRules.hasCareer(state))
        assertFalse(CareerUiRules.hasPro(state))
        assertFalse(CareerUiRules.challengeActive(state))
        assertFalse(CareerUiRules.hasLiveOuting(state))
        assertFalse(CareerUiRules.hasPendingSeasonDecision(state))
        assertFalse(CareerUiRules.hasUnacknowledgedAchievements(state))
        assertNull(CareerUiRules.playerName(state))
        assertNull(CareerUiRules.portraitSeed(state))
        assertNull(CareerUiRules.highSchoolCareerId(state))
        assertNull(CareerUiRules.lastTrainingMarker(state))
        assertEquals(0, CareerUiRules.archiveSize(state))
        assertEquals(0, CareerUiRules.lastTrainingNumber(state))
        assertEquals(0UL, CareerUiRules.completedGameCount(state))
        assertEquals(1, CareerUiRules.schoolYear(state))
        assertTrue(CareerUiRules.archive(state).isEmpty())
    }
}
