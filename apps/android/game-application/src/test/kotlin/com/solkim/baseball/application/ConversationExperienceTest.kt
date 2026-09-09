package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import kotlin.test.*

class ConversationExperienceTest {
    @Test fun oldSupportReceiptsExplainTheMatchingTrainingAndOneUseWithoutChangingItsLifetime() {
        val effect = ChoiceEffect.fromSource("다음 경기 운영 훈련 지원")
        assertEquals("배합 연습 성장량 ↑ · 1회", effect.localized(GameCopy(GameLanguage.KOREAN)))
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            assertNotNull(effect.explanation(copy))
            if (language != GameLanguage.KOREAN) assertFalse(Regex("[가-힣]").containsMatchIn(effect.localized(copy) + effect.explanation(copy)))
        }
        val support = HighSchoolDevelopment().supported(HighSchoolTrainingFocus.GAME_PLANNING)
        assertTrue(support.consume(HighSchoolTrainingFocus.COMMAND, 1).hasSupport(HighSchoolTrainingFocus.GAME_PLANNING))
        assertFalse(support.consume(HighSchoolTrainingFocus.GAME_PLANNING, 1).hasSupport(HighSchoolTrainingFocus.GAME_PLANNING))
    }
    private fun run(eventId: String, category: String): HighSchoolState {
        val k = HighSchoolPhase4Kernel()
        val start = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "conversation", "2026-W37", "2026-09-09")).state
        val school = k.chooseSchool("918220", k.completePrologue("918220", k.beginTutorial(start).state).state, HighSchoolSchoolId.HAEDONG_POWER).state
        return HighSchoolKernel().resignShadowState(school.run.copy(phase = HighSchoolPhase.RELATIONSHIP,
            currentRelationshipCategory = category, currentRelationshipTarget = HighSchoolRelationshipTarget.entries.first { it.wire == category },
            currentRelationshipEvent = HighSchoolContentCatalog.relationshipEvents.first { it.id == eventId }))
    }

    @Test fun compactScenesKeepEventAndRelationshipVoiceInAllLanguages() {
        val events = mapOf("evt-coach-role" to "coach", "evt-coach-last-advice" to "coach", "evt-catcher-sign" to "catcher",
            "evt-battery-dinner" to "catcher", "evt-new-catcher" to "catcher", "evt-rival-video" to "rival", "evt-rival-final" to "rival", "evt-rival-message" to "rival")
        for ((event, role) in events) {
            val base = run(event, role)
            val keys = listOf(20, 55, 80).map { trust ->
                val state = base.copy(managerTrust = trust, catcherTrust = trust, rivalTrust = trust)
                assertNotNull(ConversationPresentation.compactLineKey(state)).also { key ->
                    for (language in GameLanguage.entries) {
                        val line = GameCopy(language).resolve(key)
                        assertTrue(line.isNotBlank())
                        assertFalse(line.contains("{player}"))
                        if (language != GameLanguage.KOREAN) assertFalse(Regex("[가-힣]").containsMatchIn(line))
                        if (language == GameLanguage.KOREAN) assertTrue(line.length <= 45, line)
                    }
                }
            }
            assertEquals(3, keys.distinct().size)
        }
        assertNotEquals(ConversationPresentation.line(run("evt-coach-role", "coach")), ConversationPresentation.line(run("evt-coach-last-advice", "coach")))
    }

    @Test fun previewCannotHideAnInjuryBehindLowerArmRisk() {
        val k = HighSchoolKernel()
        val before = k.resignShadowState(run("evt-arm-care", "coach").copy(armRisk = 95))
        val after = k.resolveRelationship(HighSchoolKernel.RelationshipRequest("99881", before, HighSchoolRelationshipResponse.CHALLENGE)).snapshot
        val effects = ConversationPresentation.effectItems(before, after)
        assertTrue(after.injuryRecovery > before.injuryRecovery)
        assertTrue(ChoiceEffect.highlighted(effects).any { it.label == "부상 · 재활 필요" && !it.favorable })
        assertEquals("conversation.reaction.injury", ConversationPresentation.reactionKey(before, after))
        for (language in GameLanguage.entries) {
            assertTrue(GameCopy(language).legacy("부상 · 재활 필요").isNotBlank())
        }
    }

    @Test fun reactionAcknowledgesActualTrialAndDisagreementWithoutClaimingAnUnearnedReward() {
        val k = HighSchoolKernel()
        val before = run("evt-coach-role", "coach")
        val after = k.resolveRelationship(HighSchoolKernel.RelationshipRequest("99881", before, HighSchoolRelationshipResponse.CHALLENGE)).snapshot
        assertTrue(after.development!!.starterTrialPending)
        assertEquals("conversation.reaction.trial", ConversationPresentation.reactionKey(before, after))
        val rival = run("evt-rival-message", "rival")
        val resolved = k.resolveRelationship(HighSchoolKernel.RelationshipRequest("99881", rival, HighSchoolRelationshipResponse.CHALLENGE)).snapshot
        val last = requireNotNull(resolved.lastRelationship)
        val reduced = resolved.copy(lastRelationship = last.copy(trustAfter = last.trustBefore - 1))
        assertEquals("conversation.reaction.rival.disagree", ConversationPresentation.reactionKey(rival, reduced))
    }

    @Test fun proPreviewUsesClampedCommittedDeltasAndNeverMutatesTheCareer() {
        val k = ProKernel()
        val base = k.startDirect(ProStartDirectRequest("42", "power_prospect", "대화투수")).state
        val type = ProSeasonDecisionType.ROLE_MEETING
        val decision = ProSeasonDecision("season-${base.season}-week-${base.week}-${type.wire}", type, base.season, base.week,
            "보직 대화", "다음 보직을 정한다.", List(3) { index -> ProDecisionChoice("${type.wire}.$index", "선택 $index", "보직을 준비한다.",
                ProDecisionEffect(managerTrustDelta = 8, fatigueDelta = -12, roleTarget = ProRole.CLOSER)) })
        val unsigned = base.copy(phase = ProCareerPhase.SEASON_DECISION, pendingDecision = decision, managerTrust = 99, fatigue = 3, commitment = "")
        val before = unsigned.copy(commitment = k.commitment(unsigned))
        val commitment = before.commitment
        val preview = ProConversationPresentation.preview(before, "42", decision.choices.first().id)
        assertTrue(preview.any { it.label == "감독 신뢰" && it.delta == 1 })
        assertTrue(preview.any { it.label == "피로" && it.delta == -3 })
        val after = k.applySeasonDecision(before, "42", decision.id, decision.choices.first().id).state
        assertEquals(preview, ProConversationPresentation.effects(before, after))
        assertEquals(commitment, before.commitment)
        assertEquals(0, before.decisionHistory.size)
        assertEquals("catcher", ProConversationPresentation.role(ProSeasonDecisionType.RIVAL_ANALYSIS))
    }
}
