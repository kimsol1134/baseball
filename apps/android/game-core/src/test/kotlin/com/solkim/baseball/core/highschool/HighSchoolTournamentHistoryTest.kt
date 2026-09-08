package com.solkim.baseball.core.highschool

import kotlin.test.*

class HighSchoolTournamentHistoryTest {
    @Test fun recurringConversationRemainsAValidRecentHistory() {
        val kernel = HighSchoolPhase4Kernel()
        val state = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "history", "2026-W37", "2026-09-08")).state
        val event = HighSchoolContentCatalog.relationshipEvents.first().id
        val run = HighSchoolKernel().resignShadowState(state.run.copy(recentRelationshipEventIds = listOf(event, event)))
        val repeated = kernel.commitShadowState(state.copy(run = run))
        assertEquals(repeated, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(repeated)))
    }
    @Test fun sameChapterInDifferentLivesIsValidButAnExactDuplicateIsRejected() {
        val kernel = HighSchoolPhase4Kernel()
        val state = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "history", "2026-W37", "2026-09-08")).state
        val first = HighSchoolTournamentRules.snapshot("previous-life", 2, "북쪽별고")!!
        val second = HighSchoolTournamentRules.snapshot(state.run.careerId, 2, "남쪽별고")!!
        assertTrue(HighSchoolTournamentRules.belongsTo(second, state.run.careerId))
        assertFalse(HighSchoolTournamentRules.belongsTo(first, state.run.careerId))
        val history = kernel.commitShadowState(state.copy(tournaments = listOf(first, second)))
        assertEquals(history, HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(history)))
        assertFailsWith<IllegalArgumentException> { kernel.validateSavedState(kernel.commitShadowState(state.copy(tournaments = listOf(first, first)))) }
    }
}
