package com.solkim.baseball.core.pro

import kotlin.test.*

class ProWeeklyDecisionsTest {
    private val kernel = ProKernel()
    private fun signed(state: ProState): ProState = state.copy(commitment = kernel.commitment(state.copy(commitment = "")))
    private fun camp(): ProState = kernel.startDirect(ProStartDirectRequest("73191", "power_prospect", "민서준")).state
    private fun decision(type: ProSeasonDecisionType): ProState {
        val camp = camp()
        val state = camp.copy(week = 3, seasonSegment = ProCatalog.segment(3), phase = ProCareerPhase.SEASON_DECISION,
            role = ProRole.STARTER, rolePreference = ProRole.STARTER, fatigue = 0, injuryWeeks = 0,
            pitcher = camp.pitcher.copy(command = 60, stuff = 60, stamina = 70))
        val pending = ProSeasonDecision("season-1-week-3-${type.wire}", type, 1, 3,
            ProWeeklyDecisionRules.title(type), ProWeeklyDecisionRules.detail(type), ProWeeklyDecisionRules.choices(type, state))
        return signed(state.copy(pendingDecision = pending))
    }

    @Test fun campRequestSurvivesRestartConsumesNoSeedAndCannotRepeat() {
        val state = camp()
        assertTrue(ProRoleRequestRules.shouldOffer(state))
        val result = kernel.requestRole(state, state.seed, ProRole.LONG_RELIEF)
        assertEquals(state.seed, result.nextSeed)
        val restored = ProStateCodec.decode(ProStateCodec.encode(result.state))
        assertEquals(ProRoleRequestOutcome.ACCEPTED, restored.roleRequest?.outcome)
        assertEquals(ProRole.LONG_RELIEF, restored.rolePreference)
        assertFalse(ProRoleRequestRules.shouldOffer(restored))
        assertFails { kernel.requestRole(restored, result.nextSeed, ProRole.STARTER) }
        val command = ProCommandEnvelope(commandId = "request-role", sessionId = state.careerId, expectedRevision = state.revision, command = ProCommand.RequestRole(state.seed, ProRole.LONG_RELIEF))
        assertEquals(command, ProCommandCodec.decode(ProCommandCodec.encode(command)))
    }

    @Test fun conditionalReviewWaitsForWeekSixAndRejectionKeepsPreference() {
        val base = camp()
        val conditional = signed(base.copy(role = ProRole.LONG_RELIEF, rolePreference = null, managerTrust = 40, pitcher = base.pitcher.copy(stamina = 50)))
        val asked = kernel.requestRole(conditional, conditional.seed, ProRole.STARTER).state
        assertEquals(ProRoleRequestOutcome.CONDITIONAL, asked.roleRequest?.outcome)
        assertFalse(ProRoleRequestRules.pendingReview(asked, 5))
        assertTrue(ProRoleRequestRules.pendingReview(asked, 6))
        val weak = signed(conditional.copy(pitcher = conditional.pitcher.copy(stamina = 40)))
        val refused = kernel.requestRole(weak, weak.seed, ProRole.STARTER).state
        assertEquals(ProRoleRequestOutcome.REJECTED, refused.roleRequest?.outcome)
        assertEquals(weak.rolePreference, refused.rolePreference)
        assertEquals(weak.managerTrust - 1, refused.managerTrust)
    }

    @Test fun newPitchTrialRestoresCommandAfterThreeWeeksAcrossRestartOnlyOnce() {
        val initial = decision(ProSeasonDecisionType.NEW_PITCH_TRIAL)
        val pending = initial.pendingDecision!!
        var state = kernel.applySeasonDecision(initial, initial.seed, pending.id, pending.choices.first().id).state
        assertEquals(initial.pitcher.command - 3, state.pitcher.command)
        repeat(3) {
            state = ProStateCodec.decode(ProStateCodec.encode(state))
            state = kernel.planWeek(state, state.seed, ProWeekPlan.RECOVER).state
        }
        assertEquals(initial.pitcher.command, state.pitcher.command)
        assertTrue(state.activeDecisionModifiers.isNullOrEmpty())
        val card = state.resolvedFollowUps!!.single()
        assertEquals(6, card.week)
        assertEquals(3, card.commandRestored)
        if (state.phase == ProCareerPhase.SEASON_DECISION) state = kernel.applySeasonDecision(state, state.seed, state.pendingDecision!!.id, state.pendingDecision!!.choices.last().id).state
        if (state.phase == ProCareerPhase.WEEKLY_PLAN) {
            state = kernel.planWeek(state, state.seed, ProWeekPlan.RECOVER).state
            assertEquals(1, state.resolvedFollowUps!!.count { it.decisionId == pending.id })
        }
    }

    @Test fun shortRestGrantsOnlyOneExtraOutingAndPersistsGrant() {
        val initial = decision(ProSeasonDecisionType.ROTATION_PUSH)
        val pending = initial.pendingDecision!!
        val chosen = kernel.applySeasonDecision(initial, initial.seed, pending.id, pending.choices.first().id).state
        val first = kernel.planWeek(chosen, chosen.seed, ProWeekPlan.RECOVER).state
        assertEquals(2, first.currentStats.games - chosen.currentStats.games)
        assertEquals(2, first.currentStats.starts - chosen.currentStats.starts)
        val restored = ProStateCodec.decode(ProStateCodec.encode(first))
        assertEquals(1, restored.activeDecisionModifiers!!.single().extraOutingsGranted)
        if (restored.phase == ProCareerPhase.WEEKLY_PLAN) {
            val second = kernel.planWeek(restored, restored.seed, ProWeekPlan.RECOVER).state
            assertTrue(second.currentStats.games - restored.currentStats.games <= 1)
        }
    }

    @Test fun farmResetSuppressesOutingsThenReturnsWithDurableResult() {
        val initial = decision(ProSeasonDecisionType.FARM_RESET)
        val pending = initial.pendingDecision!!
        var state = kernel.applySeasonDecision(initial, initial.seed, pending.id, pending.choices.first().id).state
        repeat(3) {
            val previousGames = state.currentStats.games
            state = kernel.planWeek(ProStateCodec.decode(ProStateCodec.encode(state)), state.seed, ProWeekPlan.RECOVER).state
            assertEquals(previousGames, state.currentStats.games)
        }
        assertTrue(state.activeDecisionModifiers.isNullOrEmpty())
        assertEquals(4, state.resolvedFollowUps!!.single().managerTrustDelta)
    }

    @Test fun mentorPenaltyHasAnExpiryAndAllBinaryChoicesRoundTrip() {
        for (type in ProSeasonDecisionType.entries.filter { it.isWeeklyBinary }) {
            val state = decision(type)
            assertEquals(2, state.pendingDecision!!.choices.size)
            assertEquals(state, ProStateCodec.decode(ProStateCodec.encode(state)))
        }
        val initial = decision(ProSeasonDecisionType.VETERAN_MENTOR)
        val pending = initial.pendingDecision!!
        val chosen = kernel.applySeasonDecision(initial, initial.seed, pending.id, pending.choices.first().id).state
        assertEquals(800, chosen.activeDecisionModifiers!!.single().trainingEfficiencyPermille)
        assertEquals(6, chosen.activeDecisionModifiers!!.single().expiresWeek)
        assertEquals(initial.pitcher.movement + 1, chosen.pitcher.movement)
    }
}
