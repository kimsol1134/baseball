package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.core.highschool.HighSchoolPhase

public data class NextAppearanceCue(val trainings: Int, val choices: Int) {
    public companion object {
        public fun resolve(state: GameAggregateState): NextAppearanceCue? {
            if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) return null
            val run = state.highSchool?.run ?: return null
            if (run.school == null || run.phase in setOf(HighSchoolPhase.PROLOGUE, HighSchoolPhase.SCHOOL_SELECTION,
                    HighSchoolPhase.DRAFT, HighSchoolPhase.LEGACY, HighSchoolPhase.COMPLETED)) return null
            if (run.phase == HighSchoolPhase.IMPORTANT_GAME) return NextAppearanceCue(0, 0)
            val current = run.chapter.number - 1
            val schedule = run.schedule
            if (current !in schedule.trainingsByChapter.indices) return null
            var trainings = 0
            var choices = 0
            for (chapter in current until schedule.trainingsByChapter.size) {
                val milestones = schedule.milestonesByChapter[chapter]
                if (chapter > current) trainings += schedule.trainingsByChapter[chapter]
                else if (run.phase == HighSchoolPhase.TRAINING) trainings += (schedule.trainingsByChapter[chapter] - run.chapterTrainingCount).coerceAtLeast(0)
                val start = when {
                    chapter > current || run.phase == HighSchoolPhase.TRAINING -> 0
                    run.phase == HighSchoolPhase.CHAPTER_REVIEW -> milestones.size
                    else -> run.milestoneIndex
                }
                for (milestone in milestones.drop(start.coerceAtLeast(0))) {
                    if (milestone == HighSchoolPhase.IMPORTANT_GAME) return NextAppearanceCue(trainings, choices)
                    choices += 1
                }
                if (chapter + 1 < schedule.trainingsByChapter.size) choices += 1
            }
            return null
        }
    }
}

/** Display-only scale, identical to iOS. Never pass these values into a game command. */
public object AbilityDisplayScale {
    public fun rating(value: Int): Int = (((value.coerceIn(20, 80) - 20) * 100 + 30) / 60).coerceIn(1, 100)
    public fun delta(before: Int, after: Int): Int = rating(after) - rating(before)
}

/** One bounded receipt, saved with the transition that changed the player. */
public data class PlayerGrowthReceipt(
    val careerId: String,
    val commandId: String,
    val source: String,
    val before: List<Int>,
    val after: List<Int>,
) {
    public fun validate() {
        require(careerId.isNotBlank() && commandId.isNotBlank()) { "growth.identity" }
        require(source in setOf("training", "game", "career")) { "growth.source" }
        require(before.size == 4 && after.size == 4) { "growth.abilities" }
    }

    public companion object {
        private fun ratings(pitcher: PitcherSnapshot): List<Int> =
            listOf(pitcher.stuff, pitcher.command, pitcher.movement, pitcher.stamina)

        public fun transition(before: GameAggregateState, after: GameAggregateState, commandId: String): PlayerGrowthReceipt? {
            val pro = after.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)
            val careerId = if (pro) after.pro?.careerId else after.highSchool?.run?.careerId
            val previousId = if (pro) before.pro?.careerId else before.highSchool?.run?.careerId
            if (careerId == null || careerId != previousId) return null
            val from = if (pro) before.pro?.pitcher?.let(::ratings)
                else before.highSchool?.run?.pitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
            val to = if (pro) after.pro?.pitcher?.let(::ratings)
                else after.highSchool?.run?.pitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
            if (from == null || to == null) return null
            val training = !pro && before.highSchool?.run?.totalTrainingsCompleted != after.highSchool?.run?.totalTrainingsCompleted
            val game = before.meta.completedGameCount != after.meta.completedGameCount
            if (!training && !game && from == to) return before.meta.playerGrowth?.takeIf { it.careerId == careerId }
            return PlayerGrowthReceipt(careerId, commandId, if (training) "training" else if (game) "game" else "career", from, to)
        }

        public fun encode(value: PlayerGrowthReceipt): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
            "careerId" to JsonValue.Str(value.careerId), "commandId" to JsonValue.Str(value.commandId),
            "source" to JsonValue.Str(value.source),
            "before" to JsonValue.Arr(value.before.map { JsonValue.Num(it.toString()) }),
            "after" to JsonValue.Arr(value.after.map { JsonValue.Num(it.toString()) }),
        ))

        public fun decode(value: JsonValue?): PlayerGrowthReceipt? {
            if (value == null || value == JsonValue.Null) return null
            val fields = (value as JsonValue.Obj).entries
            fun text(key: String) = (fields.getValue(key) as JsonValue.Str).value
            fun values(key: String) = (fields.getValue(key) as JsonValue.Arr).values.map { (it as JsonValue.Num).raw.toInt() }
            return PlayerGrowthReceipt(text("careerId"), text("commandId"), text("source"), values("before"), values("after")).also { it.validate() }
        }
    }
}

/** Derived using the exact immutable quick-rebirth command that the button will submit.
 * The kernel works on copies: preview never grants rewards or advances the saved RNG. */
public data class RebirthStartPreview(
    val previous: List<Int>, val next: List<Int>,
    val previousLife: Int, val nextLife: Int, val previousStrikeouts: Int,
) {
    public companion object {
        public fun resolve(state: GameAggregateState, action: Phase8ActionModel?): RebirthStartPreview? {
            if (action?.id != "quickRebirth" || !action.enabled) return null
            val before = state.highSchool ?: return null
            val command = (action.payloads.singleOrNull()?.envelope?.command as? GameCommand.HighSchool)?.command
                as? com.solkim.baseball.core.highschool.HighSchoolPhase4Command.BeginRebirth ?: return null
            if (before.run.phase != HighSchoolPhase.COMPLETED || before.archive.none { it.careerId == before.run.careerId }) return null
            val next = com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel()
                .beginRebirth(before, command.seed, command.dayKey).state
            fun ratings(p: com.solkim.baseball.core.highschool.HighSchoolPitcher) = listOf(p.stuff, p.command, p.movement, p.stamina)
            return RebirthStartPreview(ratings(before.startingPitcher), ratings(next.startingPitcher),
                before.run.lifeNumber, next.run.lifeNumber, before.run.performance.strikeouts)
        }
    }
}

/** Resolve effect labels individually so Japanese never receives phrase-fragment translation. */
public object SignatureLegacyDisplay {
    public fun effect(id: String, copy: GameCopy): String? {
        val value = com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules.definitions.firstOrNull { it.id == id } ?: return null
        return listOf("구위" to value.stuff, "제구" to value.command, "무브먼트" to value.movement, "체력" to value.stamina)
            .filter { it.second != 0 }.joinToString(" · ") { (label, amount) -> "${copy.legacy(label)} ${if (amount > 0) "+" else ""}$amount" }
    }
}
