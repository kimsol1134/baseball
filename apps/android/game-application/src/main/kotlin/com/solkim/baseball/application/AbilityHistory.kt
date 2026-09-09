package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue

/** Actual committed observations only. Missing past observations are never interpolated into saves. */
public data class AbilityHistoryPoint(
    val id: String, val career: String, val life: Int, val pro: Boolean,
    val season: Int, val step: Int, val source: String,
    val ratings: List<Int>, val mastery: List<Int>,
) {
    public fun validate() {
        require(id.isNotBlank() && career.isNotBlank() && life > 0 && season >= 0 && step >= 0)
        require(source in setOf("start", "observed", "training", "game", "career"))
        require(ratings.size == 4 && ratings.all { it in 20..80 })
        require(mastery.size == 4 && mastery.all { it >= 0 })
    }
}

public object AbilityHistory {
    public fun current(state: GameAggregateState, id: String = "view", source: String = "observed"): AbilityHistoryPoint? {
        val pro = state.pro.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) }
        val hs = state.highSchool?.run
        val ratings = pro?.pitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
            ?: hs?.pitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) } ?: return null
        val mastery = pro?.pitcher?.effectiveMastery ?: hs!!.pitcher.effectiveMastery
        return AbilityHistoryPoint(id, pro?.careerId ?: hs!!.careerId, hs?.lifeNumber ?: 1, pro != null,
            pro?.season ?: hs!!.chapter.schoolYear, pro?.week ?: hs!!.totalTrainingsCompleted, source, ratings,
            listOf(mastery.stuff, mastery.command, mastery.movement, mastery.stamina))
    }
    public fun transition(before: GameAggregateState, after: GameAggregateState, commandId: String): List<AbilityHistoryPoint> {
        if (before.meta.seedChallenge != null || after.meta.seedChallenge != null || before.highSchool?.challenge?.active == true || after.highSchool?.challenge?.active == true)
            return before.meta.abilityHistory
        val points = before.meta.abilityHistory.toMutableList()
        val old = current(before)
        val now = current(after) ?: return points
        fun add(point: AbilityHistoryPoint) { if (points.none { it.id == point.id }) points += point }
        if (old?.career != now.career) {
            add(now.copy(id = "${now.career}:start", source = "start"))
        } else if (old.ratings != now.ratings || old.mastery != now.mastery) {
            if (points.none { it.career == now.career }) add(old.copy(id = "${now.career}:observed"))
            val training = before.highSchool?.run?.totalTrainingsCompleted != after.highSchool?.run?.totalTrainingsCompleted ||
                before.pro?.week != after.pro?.week
            val game = before.meta.completedGameCount != after.meta.completedGameCount
            add(now.copy(id = "${now.career}:$commandId", source = if (training) "training" else if (game) "game" else "career"))
        }
        return points
    }
    public fun encode(points: List<AbilityHistoryPoint>): JsonValue = JsonValue.Arr(points.map { p ->
        fun s(v: String) = JsonValue.Str(v)
        fun n(v: Int) = JsonValue.Num(v.toString())
        JsonValue.Arr(listOf(s(p.id), s(p.career), n(p.life), JsonValue.Bool(p.pro), n(p.season), n(p.step), s(p.source),
            JsonValue.Arr(p.ratings.map(::n)), JsonValue.Arr(p.mastery.map(::n))))
    })
    public fun decode(value: JsonValue?): List<AbilityHistoryPoint> {
        if (value == null || value == JsonValue.Null) return emptyList()
        return (value as JsonValue.Arr).values.map { item ->
            val v = (item as JsonValue.Arr).values
            require(v.size == 9)
            fun s(i: Int) = (v[i] as JsonValue.Str).value
            fun n(i: Int) = (v[i] as JsonValue.Num).raw.toInt()
            fun list(i: Int) = (v[i] as JsonValue.Arr).values.map { (it as JsonValue.Num).raw.toInt() }
            AbilityHistoryPoint(s(0), s(1), n(2), (v[3] as JsonValue.Bool).value, n(4), n(5), s(6), list(7), list(8)).also { it.validate() }
        }.also { require(it.map { p -> p.id }.distinct().size == it.size) }
    }
}
