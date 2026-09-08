package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public object ConversationPresentation {
    private fun category(run: HighSchoolState): String = run.currentRelationshipCategory ?: run.currentRelationshipTarget?.wire ?: "coach"
    public fun line(run: HighSchoolState): String {
        if (run.currentRelationshipEvent?.id == "evt-arm-care") return RelationshipNarrative.line(run)
        return when (category(run)) {
            "coach" -> when {
                run.development?.trialOutcome == "achieved" -> "지난 테스트, 잘 던졌어. 선발 기회를 더 줄게. 오늘은 무엇을 준비할까?"
                run.development?.starterTrialPending == true -> "다음 등판은 선발 테스트야. 그 전에 무엇을 준비할까?"
                else -> "네 공을 더 키워보자. 훈련을 도와줄까, 선발 기회에 도전해 볼래?"
            }
            "catcher", "game", "awakening" -> "다음 등판 전에 하나만 같이 맞춰보자. 배합, 코스, 결정구 중에 뭐부터 할까?"
            else -> RelationshipNarrative.line(run)
        }
    }
    public fun title(run: HighSchoolState, response: HighSchoolRelationshipResponse): String? {
        if (run.currentRelationshipEvent?.id == "evt-arm-care") return RelationshipNarrative.choice(run, response)?.title
        return when (category(run)) {
            "coach" -> when (response) { HighSchoolRelationshipResponse.LISTEN -> "훈련을 도와주세요"; HighSchoolRelationshipResponse.EXPLAIN -> "회복하고 싶어요"; HighSchoolRelationshipResponse.CHALLENGE -> "선발 기회에 도전할게요" }
            "catcher", "game", "awakening" -> when (response) { HighSchoolRelationshipResponse.LISTEN -> "배합을 같이 복기하자"; HighSchoolRelationshipResponse.EXPLAIN -> "코스를 같이 점검하자"; HighSchoolRelationshipResponse.CHALLENGE -> "결정구를 같이 연습하자" }
            else -> RelationshipNarrative.choice(run, response)?.title
        }
    }
    public fun effects(before: HighSchoolState, after: HighSchoolState): List<String> {
        val result = after.lastRelationship ?: return emptyList()
        val lines = mutableListOf<String>()
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
    public fun preview(run: HighSchoolState, seed: String, response: HighSchoolRelationshipResponse): String {
        if (run.phase != HighSchoolPhase.RELATIONSHIP) return RelationshipNarrative.choice(run, response)?.detail.orEmpty()
        val kernel = HighSchoolKernel()
        return effects(run, kernel.resolveRelationship(HighSchoolKernel.RelationshipRequest(seed, kernel.resignShadowState(run), response)).snapshot).take(2).joinToString(" · ")
    }
    private fun signed(n: Int): String = if (n > 0) "+$n" else "$n"
}
