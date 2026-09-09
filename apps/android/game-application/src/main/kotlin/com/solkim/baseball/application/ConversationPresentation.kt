package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public object ConversationPresentation {
    private fun category(run: HighSchoolState): String = run.currentRelationshipCategory ?: run.currentRelationshipTarget?.wire ?: "coach"
    public fun line(run: HighSchoolState): String = compactLineKey(run)?.let {
        GameCopy(GameLanguage.KOREAN).resolve(it)
    } ?: RelationshipNarrative.line(run)

    /** Authored short beats, never a substring cut through a sentence or a gameplay promise. */
    public fun compactLineKey(run: HighSchoolState): String? {
        val event = run.currentRelationshipEvent?.id
        val beat = when (event) {
            "evt-coach-role" -> if (run.development?.starterTrialPending == true) "coach-trial" else "coach-role"
            "evt-coach-last-advice" -> "coach-last"
            "evt-catcher-sign", "evt-catcher-doubt" -> "catcher-sign"
            "evt-battery-dinner" -> "catcher-dinner"
            "evt-new-catcher" -> "catcher-new"
            "evt-rival-video" -> "rival-video"
            "evt-rival-final" -> "rival-final"
            "evt-rival-message" -> "rival-message"
            "evt-arm-care" -> "arm-care"
            else -> when (category(run)) {
                "coach" -> if (run.development?.starterTrialPending == true) "coach-trial" else "coach"
                "catcher", "game" -> "catcher"
                "awakening" -> "catcher-awakening"
                "rival" -> "rival-message"
                else -> return null
            }
        }
        val trust = when (RelationshipNarrative.speakerRole(run)) {
            "coach" -> run.managerTrust; "catcher" -> run.catcherTrust; "rival" -> run.rivalTrust
            else -> 50
        }
        return "conversation.beat.$beat.${if (trust < 45) "guarded" else if (trust >= 65) "close" else "open"}"
    }

    public fun reactionKey(before: HighSchoolState, after: HighSchoolState): String {
        val result = after.lastRelationship ?: return "conversation.reaction.done"
        if (after.injuryRecovery > before.injuryRecovery) return "conversation.reaction.injury"
        val offer = after.development?.takeIf { it.lastConversation == after.relationshipsCompleted }?.lastOffer
        if (offer == "starter_trial") return "conversation.reaction.trial"
        if (offer == "recovery") return "conversation.reaction.rest"
        val role = RelationshipNarrative.speakerRole(before)
        if (result.trustAfter < result.trustBefore) return "conversation.reaction.$role.disagree".takeIf { role in setOf("coach", "catcher", "rival") } ?: "conversation.reaction.done"
        return "conversation.reaction.$role".takeIf { role in setOf("coach", "catcher", "rival") } ?: "conversation.reaction.done"
    }
    public fun title(run: HighSchoolState, response: HighSchoolRelationshipResponse): String? {
        if (run.currentRelationshipEvent?.id == "evt-arm-care") return GameCopy(GameLanguage.KOREAN).resolve("conversation.choice.arm.${response.wire}")
        if (category(run) == "rival") return GameCopy(GameLanguage.KOREAN).resolve("conversation.choice.rival.${response.wire}")
        return when (category(run)) {
            "coach" -> when (response) { HighSchoolRelationshipResponse.LISTEN -> "훈련을 도와주세요"; HighSchoolRelationshipResponse.EXPLAIN -> "회복하고 싶어요"; HighSchoolRelationshipResponse.CHALLENGE -> "선발 기회에 도전할게요" }
            "catcher", "game", "awakening" -> when (response) { HighSchoolRelationshipResponse.LISTEN -> "배합을 같이 복기하자"; HighSchoolRelationshipResponse.EXPLAIN -> "코스를 같이 점검하자"; HighSchoolRelationshipResponse.CHALLENGE -> "결정구를 같이 연습하자" }
            else -> RelationshipNarrative.choice(run, response)?.title
        }
    }
    public fun effects(before: HighSchoolState, after: HighSchoolState): List<String> {
        val result = after.lastRelationship ?: return emptyList()
        val lines = mutableListOf<String>()
        if (after.injuryRecovery > before.injuryRecovery) lines += "부상 · 재활 필요"
        val d = after.development?.takeIf { it.lastConversation == after.relationshipsCompleted }
        when (d?.lastOffer) {
            "starter_trial" -> lines += "다음 등판: 선발 테스트"
            "training" -> d.supportFocus?.let { lines += "다음 ${TrainingPresentation.title(it)} 지원" }
        }
        val labels = listOf("구위", "제구", "무브먼트", "체력")
        val old = before.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        val next = after.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
        old.indices.forEach { i -> val delta = AbilityDisplayScale.delta(old[i], next[i]); if (delta != 0) lines += "${labels[i]} ${signed(delta)}" }
        if (after.fatigue != before.fatigue) lines += "피로 ${signed(after.fatigue - before.fatigue)}"
        if (after.armRisk != before.armRisk) lines += "팔 부담 ${signed(after.armRisk - before.armRisk)}"
        if (result.trustAfter != result.trustBefore) lines += "신뢰 ${signed(result.trustAfter - result.trustBefore)}"
        if (after.fanInterest != before.fanInterest) lines += "관심도 ${signed(after.fanInterest - before.fanInterest)}"
        if (lines.isEmpty()) lines += "대화를 마쳤어요. 다음 일정을 준비해요."
        return lines
    }
    public fun effectItems(before: HighSchoolState, after: HighSchoolState): List<ChoiceEffect> = effects(before, after).map(ChoiceEffect::fromSource)
    public fun previewEffects(run: HighSchoolState, seed: String, response: HighSchoolRelationshipResponse): List<ChoiceEffect> {
        if (run.phase != HighSchoolPhase.RELATIONSHIP) return emptyList()
        val kernel = HighSchoolKernel()
        return effectItems(run, kernel.resolveRelationship(HighSchoolKernel.RelationshipRequest(seed, kernel.resignShadowState(run), response)).snapshot)
    }
    public fun preview(run: HighSchoolState, seed: String, response: HighSchoolRelationshipResponse): String =
        ChoiceEffect.summary(previewEffects(run, seed, response))
    private fun signed(n: Int): String = if (n > 0) "+$n" else "$n"
}
