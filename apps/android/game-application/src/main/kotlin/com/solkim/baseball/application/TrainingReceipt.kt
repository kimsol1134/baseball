package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.toPitcherSnapshot
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

public fun trainingReceipt(before: GameAggregateState, after: GameAggregateState): String? {
    val old = before.highSchool?.run ?: return null
    val next = after.highSchool?.run ?: return null
    if (old.careerId != next.careerId || next.totalTrainingsCompleted <= old.totalTrainingsCompleted) return null
    val last = next.lastTraining ?: return null
    fun ratings(state: GameAggregateState) = state.highSchool!!.run.pitcher.let { ReceiptArray(listOf(it.stuff, it.command, it.movement, it.stamina)) }
    val evidence = after.highSchool!!.trainingEvidence.filter { it.careerId == next.careerId && it.trainingNumber > old.totalTrainingsCompleted }
    val velocities = ReceiptArray()
    val oldPitcher = old.toPitcherSnapshot()
    val newPitcher = next.toPitcherSnapshot()
    newPitcher.pitchProfiles.orEmpty().forEach { profile ->
        if (oldPitcher.pitchProfiles.orEmpty().any { it.pitchType == profile.pitchType }) {
            val call = com.solkim.baseball.core.pitch.PitchCall(profile.pitchType, com.solkim.baseball.core.pitch.PitchZone(1, 1), com.solkim.baseball.core.pitch.ZoneIntent.STRIKE, com.solkim.baseball.core.pitch.PitchIntensity.NORMAL)
            val from = com.solkim.baseball.core.pitch.PitchAbilityRules.expectedVelocity(oldPitcher, call, old.fatigue)
            val to = com.solkim.baseball.core.pitch.PitchAbilityRules.expectedVelocity(newPitcher, call, next.fatigue)
            if (from != to) velocities.put(ReceiptObject().put("pitch", TrainingPresentation.pitchLabel(profile.pitchType)).put("before", from).put("after", to))
        }
    }
    val oldMastery = old.pitcher.effectiveMastery
    val newMastery = next.pitcher.effectiveMastery
    val mastery = listOf(newMastery.stuff, newMastery.command, newMastery.movement, newMastery.stamina).sumOf { it.toLong() } -
        listOf(oldMastery.stuff, oldMastery.command, oldMastery.movement, oldMastery.stamina).sumOf { it.toLong() }
    val forecast = if (next.totalTrainingsCompleted == old.totalTrainingsCompleted + 1 && old.phase == com.solkim.baseball.core.highschool.HighSchoolPhase.TRAINING)
        TrainingPresentation.preview(before, last.focus, last.intensity) else null
    return ReceiptObject().put("career", next.careerId).put("number", last.number)
        .put("count", next.totalTrainingsCompleted - old.totalTrainingsCompleted)
        .put("before", ratings(before)).put("after", ratings(after))
        .put("fatigueBefore", old.fatigue).put("fatigueAfter", next.fatigue)
        .put("armBefore", old.armRisk).put("armAfter", next.armRisk)
        .put("focus", last.focus.wire).put("intensity", last.intensity.wire).put("bloomed", last.bloomed)
        .put("experience", next.development?.experience?.get(com.solkim.baseball.core.highschool.HighSchoolDevelopment.index(last.focus)) ?: 0)
        .put("experienceEarned", next.development?.lastExperienceEarned ?: 0)
        .put("breakthrough", next.talent.pressure(last.focus))
        .put("breakthroughTarget", next.talent.grade(last.focus).bloomThreshold.takeIf { it != Int.MAX_VALUE } ?: 0)
        .put("supportApplied", next.development?.supportAppliedTraining == last.number)
        .put("extraGrowth", forecast != null && last.growth > forecast.maximumGrowth).put("atWall", forecast?.atTalentWall == true)
        .put("learningBefore", old.pitchLearningProject?.practiceCredits ?: 0).put("learningAfter", next.pitchLearningProject?.practiceCredits ?: 0)
        .put("mastery", mastery.coerceAtLeast(0)).put("velocities", velocities).put("rehab", next.injuryRecovery > 0)
        .put("targets", ReceiptArray(evidence.mapNotNull { it.targetPitch?.let(TrainingPresentation::pitchLabel) }.distinct())).toString()
}

private fun receiptValue(value: Any?): JsonValue = when (value) {
    null -> JsonValue.Null
    is ReceiptObject -> JsonValue.Obj(value.fields)
    is ReceiptArray -> JsonValue.Arr(value.items.map(::receiptValue))
    is String -> JsonValue.Str(value)
    is Boolean -> JsonValue.Bool(value)
    is Number -> JsonValue.Num(value.toString())
    else -> error("receipt.unsupported_value")
}
private class ReceiptObject {
    val fields = linkedMapOf<String, JsonValue>()
    fun put(key: String, value: Any?): ReceiptObject { fields[key] = receiptValue(value); return this }
    override fun toString(): String = StrictJson.canonical(JsonValue.Obj(fields))
}
private class ReceiptArray(values: List<Any?> = emptyList()) {
    val items = values.toMutableList()
    fun put(value: Any?): ReceiptArray { items.add(value); return this }
}
