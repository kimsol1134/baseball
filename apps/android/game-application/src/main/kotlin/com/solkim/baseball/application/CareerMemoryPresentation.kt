package com.solkim.baseball.application

public object CareerMemoryPresentation {
    private val kinds = setOf("starter_trial", "held_lead", "first_save", "best_outing")
    public fun featured(state: GameAggregateState, includePrevious: Boolean = false): List<PitchMemory> {
        val c = state.meta.companion ?: return emptyList()
        val id = PitcherCompanionRules.career(state)
        val related = setOfNotNull(id, state.pro?.careerId, state.highSchool?.run?.careerId)
        return c.memories.asReversed().filter { it.kind in kinds && (if (includePrevious) it.career in related else it.career == id) }.take(3)
    }
    public fun detail(memory: PitchMemory, copy: GameCopy): String = if (memory.outing.size == 3) copy.resolve("career.compact.game-line",
        GameCopyArgument.UserText("${memory.outing[0] / 3}.${memory.outing[0] % 3}"), GameCopyArgument.Whole(memory.outing[2].toLong()), GameCopyArgument.Whole(memory.outing[1].toLong())) else ""
    public fun conversationRecall(state: GameAggregateState, copy: GameCopy): String? = featured(state).firstOrNull()?.let {
        copy.resolve("memory.recall.${it.kind}")
    }
}
