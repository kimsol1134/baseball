package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue

/** Immutable career evidence travels in the same transactional save and backup as the player. */
public data class AlbumPitch(val id: String, val kind: String, val velocity: Int, val trajectory: List<Int>)
public data class PlayerAlbumPage(
    val scope: RecordScope, val games: Int, val outs: Int, val runs: Int, val strikeouts: Int,
    val inningsKnown: Boolean, val rows: List<CareerGameView>, val pitches: List<AlbumPitch> = emptyList(),
)
public object PlayerAlbum {
    public fun validate(pages: List<PlayerAlbumPage>) {
        require(pages.map { it.scope.id }.distinct().size == pages.size)
        pages.forEach { p ->
            require(p.scope.id.isNotBlank() && p.games >= 0 && p.outs >= 0 && p.runs >= 0 && p.strikeouts >= 0)
            require(p.rows.map { it.id }.distinct().size == p.rows.size)
            require(p.rows.all { it.outs >= 0 && it.strikeouts >= 0 && it.runs >= 0 })
            require(p.pitches.map { it.id }.distinct().size == p.pitches.size)
            require(p.pitches.all { it.id.isNotBlank() && it.trajectory.size % 4 == 0 && it.trajectory.size <= 4096 })
        }
    }
    public fun capture(before: GameAggregateState, after: GameAggregateState): List<PlayerAlbumPage> {
        // Challenge careers have their own sandbox and must not become a player's career evidence.
        if (before.meta.seedChallenge != null || after.meta.seedChallenge != null) return before.meta.album
        val pages = before.meta.album.associateBy { it.scope.id }.toMutableMap()
        for (state in listOf(before, after)) {
            for (scope in CareerRecordPresentation.scopes(state)) {
                if (scope.id.startsWith("pro:") && scope.id.endsWith(":all")) continue
                val record = CareerRecordPresentation.resolve(state, scope.id) ?: continue
                val old = pages[scope.id]
                val rows = (old?.rows.orEmpty() + record.rows).associateBy { it.id }.values.toList()
                pages[scope.id] = PlayerAlbumPage(scope, record.games, record.outs, record.runs, record.strikeouts,
                    record.inningsKnown, rows, old?.pitches.orEmpty())
            }
            val pro = state.pro
            val hs = state.highSchool
            val snapshot = if (state.stage == GameStage.PRO) pro?.lastPresentation else hs?.lastPresentation?.snapshot
            val scopeId = if (state.stage == GameStage.PRO) pro?.let { "pro:${it.careerId}:${it.currentStats.season}" }
                else hs?.run?.let { "hs:${it.careerId}" }
            val page = pages[scopeId]
            if (snapshot != null && page != null) {
                val pitch = AlbumPitch(snapshot.presentationSeed, snapshot.pitchType.wire, snapshot.velocityTenthsKph, snapshot.trajectorySeries)
                pages[page.scope.id] = page.copy(pitches = (page.pitches + pitch).distinctBy { it.id })
            }
        }
        return pages.values.toList()
    }
    public fun pages(state: GameAggregateState): List<PlayerAlbumPage> = capture(state, state)
}

/** Optional additive field: old saves retain their exact wire format and commitment. */
internal object PlayerAlbumCodec {
    private fun s(v: String): JsonValue = JsonValue.Str(v)
    private fun n(v: Int): JsonValue = JsonValue.Num(v.toString())
    private fun a(v: List<JsonValue>): JsonValue = JsonValue.Arr(v)
    fun encode(pages: List<PlayerAlbumPage>): JsonValue = a(pages.map { p -> a(listOf(
        s(p.scope.id), s(p.scope.title), s(p.scope.player), n(p.games), n(p.outs), n(p.runs), n(p.strikeouts), JsonValue.Bool(p.inningsKnown),
        a(p.rows.map { r -> a(listOf(s(r.id), s(r.label), n(r.outs), n(r.strikeouts), n(r.runs), n(r.walks), n(r.hits), n(r.perfect), n(r.team), n(r.opponent), JsonValue.Bool(r.manual))) }),
        a(p.pitches.map { r -> a(listOf(s(r.id), s(r.kind), n(r.velocity), a(r.trajectory.map(::n)))) })
    )) })
    fun decode(value: JsonValue?): List<PlayerAlbumPage> {
        if (value == null) return emptyList()
        fun JsonValue.items() = (this as JsonValue.Arr).values
        fun JsonValue.text() = (this as JsonValue.Str).value
        fun JsonValue.int() = (this as JsonValue.Num).raw.toInt()
        fun JsonValue.bool() = (this as JsonValue.Bool).value
        return value.items().map { item ->
            val p = item.items(); require(p.size == 10)
            PlayerAlbumPage(RecordScope(p[0].text(), p[1].text(), p[2].text()), p[3].int(), p[4].int(), p[5].int(), p[6].int(), p[7].bool(),
                p[8].items().map { itemRow -> val r = itemRow.items(); require(r.size == 11)
                    CareerGameView(r[0].text(), r[1].text(), r[2].int(), r[3].int(), r[4].int(), r[5].int(), r[6].int(), r[7].int(), r[8].int(), r[9].int(), r[10].bool()) },
                p[9].items().map { itemPitch -> val r = itemPitch.items(); require(r.size == 4)
                    AlbumPitch(r[0].text(), r[1].text(), r[2].int(), r[3].items().map { it.int() }) })
        }.also(PlayerAlbum::validate)
    }
}
