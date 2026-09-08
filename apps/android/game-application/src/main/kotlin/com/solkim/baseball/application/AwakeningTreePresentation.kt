package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public data class AwakeningTreeNode(val choice: AwakeningChoiceView, val branch: String, val parents: List<String>, val column: Float)
public data class AwakeningSummary(val benefit: String, val cost: String?)

public object AwakeningTreePresentation {
    public val branches: List<String> = listOf("power", "command", "breaking", "game")
    public fun nodes(state: GameAggregateState): List<AwakeningTreeNode> {
        val choices = CareerChoicePresentation.awakeningTree(state).associateBy { it.id }
        fun column(node: AwakeningNode): Float {
            if (node.tier == 1) return 0.5f
            if (node.tier == 2) return if (HighSchoolContentCatalog.awakeningNodes.filter { it.branch == node.branch && it.tier == 2 }.indexOf(node) == 0) 0.25f else 0.75f
            return column(HighSchoolContentCatalog.awakeningNodes.single { it.id == node.parents.first() })
        }
        return HighSchoolContentCatalog.awakeningNodes.map { node ->
            AwakeningTreeNode(choices.getValue(node.id.wire).let { it.copy(available = it.available && (state.highSchool?.run?.selectedAwakenings?.size ?: 0) < 3) }, node.branch, node.parents.map { it.wire }, column(node))
        }
    }
    public fun summary(state: GameAggregateState, node: AwakeningTreeNode, copy: GameCopy): AwakeningSummary {
        if (node.choice.owned) return AwakeningSummary(copy.resolve("awakening.tree.short.${node.choice.id}"), null)
        val before = requireNotNull(state.highSchool).run.pitcher
        val id = HighSchoolAwakening.entries.single { it.wire == node.choice.id }
        val after = HighSchoolKernel().previewAwakening(before, id)
        val labels = listOf("구위", "제구", "무브먼트", "체력")
        val from = listOf(before.stuff, before.command, before.movement, before.stamina)
        val to = listOf(after.stuff, after.command, after.movement, after.stamina)
        val positives = mutableListOf<String>()
        val negatives = mutableListOf<String>()
        after.pitchProfiles.forEach { profile ->
            val old = before.pitchProfiles.firstOrNull { it.pitchType == profile.pitchType } ?: return@forEach
            val velocity = profile.velocityTenthsKph - old.velocityTenthsKph
            if (velocity > 0) positives += "${copy.legacy(TrainingPresentation.pitchLabel(profile.pitchType))} +${velocity / 10}.${velocity % 10} km/h"
        }
        labels.indices.forEach { index ->
            val delta = AbilityDisplayScale.delta(from[index], to[index])
            val label = copy.legacy(labels[index])
            if (delta > 0) positives += "$label +$delta"
            if (delta < 0) negatives += when {
                index == 1 && id == HighSchoolAwakening.EXPLOSIVE_FASTBALL -> copy.resolve("awakening.tree.power-control-cost", GameCopyArgument.Whole(delta.toLong()))
                index == 1 && id in setOf(HighSchoolAwakening.DISAPPEARING_BREAKER, HighSchoolAwakening.SWEEPING_SLIDER) -> copy.resolve("awakening.tree.break-control-cost", GameCopyArgument.Whole(delta.toLong()))
                else -> "$label $delta"
            }
        }
        if (after.pitchProfiles.any { p -> p.fatigueCost > (before.pitchProfiles.firstOrNull { it.pitchType == p.pitchType }?.fatigueCost ?: p.fatigueCost) }) {
            negatives += copy.resolve("awakening.tree.more-fatigue")
        }
        if (after.pitchProfiles.any { p -> p.fatigueCost < (before.pitchProfiles.firstOrNull { it.pitchType == p.pitchType }?.fatigueCost ?: p.fatigueCost) }) {
            positives.add(0, copy.resolve("awakening.tree.less-fatigue"))
        }
        val pairs = after.pitchProfiles.mapNotNull { p -> before.pitchProfiles.firstOrNull { it.pitchType == p.pitchType }?.let { it to p } }
        val moving = pairs.filter { (old, new) -> new.movement > old.movement }
        if (moving.size == 1) positives.add(0, copy.resolve("awakening.tree.pitch-movement-up",
            GameCopyArgument.UserText(copy.legacy(TrainingPresentation.pitchLabel(moving.single().second.pitchType)))))
        if (pairs.any { (old, new) -> new.whiff > old.whiff }) positives += copy.resolve("awakening.tree.whiff-up")
        if (pairs.any { (old, new) -> new.control > old.control || new.command > old.command }) positives += copy.resolve("awakening.tree.control-up")
        if (pairs.any { (old, new) -> new.movement > old.movement }) positives += copy.resolve("awakening.tree.movement-up")
        if (pairs.any { (old, new) -> new.weakContact > old.weakContact }) positives += copy.resolve("awakening.tree.weak-contact-up")
        if (id in setOf(HighSchoolAwakening.CALM_UNDER_PRESSURE, HighSchoolAwakening.SCOUT_COMPOSURE,
                HighSchoolAwakening.REPEATABLE_RELEASE, HighSchoolAwakening.TWO_STRIKE_PLAN,
                HighSchoolAwakening.TRAFFIC_CONTROLLER, HighSchoolAwakening.LATE_INNING_RESERVE)) {
            val pressure = copy.resolve("awakening.tree.pressure-stability")
            if (id in setOf(HighSchoolAwakening.CALM_UNDER_PRESSURE, HighSchoolAwakening.SCOUT_COMPOSURE)) positives.add(0, pressure)
            else positives += pressure
        }
        return AwakeningSummary(positives.take(2).joinToString(" · ").ifBlank { copy.resolve("awakening.tree.no-gain") },
            negatives.joinToString(" · ").ifBlank { null })
    }
}
