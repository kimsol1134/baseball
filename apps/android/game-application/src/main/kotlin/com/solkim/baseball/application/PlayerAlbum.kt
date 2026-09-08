package com.solkim.baseball.application

import com.solkim.baseball.model.JsonValue

/** Immutable career evidence travels in the same transactional save and backup as the player. */
public data class AlbumPitch(val id: String, val kind: String, val velocity: Int, val trajectory: List<Int>,
    val session: String = "", val outcome: String = "", val context: List<Int> = emptyList(), val flight: List<Int> = emptyList())
public data class PlayerAlbumPage(
    val scope: RecordScope, val games: Int, val outs: Int, val runs: Int, val strikeouts: Int,
    val inningsKnown: Boolean, val rows: List<CareerGameView>, val pitches: List<AlbumPitch> = emptyList(),
    val portraitSeed: String = scope.player, val affiliation: String = "", val signature: String = "",
    val ratings: List<Int> = emptyList(), val life: Int = 1,
)
public object PlayerAlbum {
    public fun validate(pages: List<PlayerAlbumPage>) {
        require(pages.map { it.scope.id }.distinct().size == pages.size)
        pages.forEach { p ->
            require(p.scope.id.isNotBlank() && p.games >= 0 && p.outs >= 0 && p.runs >= 0 && p.strikeouts >= 0)
            require(p.life > 0 && (p.ratings.isEmpty() || p.ratings.size == 4))
            require(p.rows.map { it.id }.distinct().size == p.rows.size)
            require(p.rows.all { it.outs >= 0 && it.strikeouts >= 0 && it.runs >= 0 })
            require(p.pitches.map { it.id }.distinct().size == p.pitches.size)
            require(p.pitches.all { it.id.isNotBlank() && it.trajectory.size % 4 == 0 && it.trajectory.size <= 4096 && (it.flight.isEmpty() || it.flight.size == 3 && it.flight[0] > 0) &&
                (it.context.isEmpty() || it.context.size == 5 && it.context[0] > 0 && it.context[1] in 0..2 && it.context.drop(2).all { n -> n in 0..1 }) })
        }
    }
    public fun capture(before: GameAggregateState, after: GameAggregateState): List<PlayerAlbumPage> {
        // Challenge careers have their own sandbox and must not become a player's career evidence.
        if (before.meta.seedChallenge != null || after.meta.seedChallenge != null) return before.meta.album
        val pages = before.meta.album.associateBy { it.scope.id }.toMutableMap()
        for (state in listOf(before, after)) {
            for (scope in CareerRecordPresentation.scopes(state)) {
                if (scope.id.startsWith("pro:") && scope.id.endsWith(":all")) continue
                val activeScope = scope.id == state.pro?.let { "pro:${it.careerId}:${it.season}" } || scope.id == state.highSchool?.run?.let { "hs:${it.careerId}" }
                if (scope.id in pages && !activeScope) continue
                val record = CareerRecordPresentation.resolve(state, scope.id) ?: continue
                val old = pages[scope.id]
                val pending = state.pro?.takeIf { it.phase == com.solkim.baseball.core.pro.ProCareerPhase.IMPORTANT_GAME && scope.id == "pro:${it.careerId}:${it.season}" }?.let { pro ->
                    pro.currentGameLines.lastOrNull { !it.played && it.week == pro.week }
                }
                val pendingId = pending?.let { "pro:${state.pro!!.careerId}:${it.season}:${it.week}:${it.outingNumber}" }
                val rows = (old?.rows.orEmpty() + record.rows).filterNot { it.id == pendingId }.associateBy { it.id }.values.sortedBy { it.chronologicalKey }
                pages[scope.id] = PlayerAlbumPage(scope, (record.games - if (pending != null) 1 else 0).coerceAtLeast(0),
                    (record.outs - (pending?.outs ?: 0)).coerceAtLeast(0), (record.runs - (pending?.runsAllowed ?: 0)).coerceAtLeast(0), (record.strikeouts - (pending?.strikeouts ?: 0)).coerceAtLeast(0),
                    record.inningsKnown || old?.inningsKnown == true, rows, old?.pitches.orEmpty(),
                    old?.portraitSeed ?: scope.player, old?.affiliation.orEmpty(), old?.signature.orEmpty(), old?.ratings.orEmpty(), old?.life ?: 1)
                val activePro = state.pro?.takeIf { scope.id == "pro:${it.careerId}:${it.season}" }
                val activeHs = state.highSchool?.run?.takeIf { scope.id == "hs:${it.careerId}" }
                val archive = state.highSchool?.archive?.firstOrNull { scope.id == "hs:${it.careerId}" }
                val page = pages.getValue(scope.id)
                val companion = PitcherCompanionRules.current(state)
                if (activePro != null || activeHs != null) {
                    val r = activePro?.pitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
                        ?: activeHs!!.pitcher.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
                    val linked = activeHs != null || activePro?.sourceHighSchoolCareerId != null
                    pages[scope.id] = page.copy(portraitSeed = if (linked) state.highSchool?.archive?.firstOrNull()?.playerName ?: scope.player else scope.player,
                        affiliation = activePro?.team?.name ?: activeHs?.school?.name.orEmpty(),
                        signature = if (companion.career == activePro?.careerId || companion.career == activeHs?.careerId) companion.representative else page.signature,
                        ratings = r, life = activeHs?.lifeNumber ?: state.highSchool?.run?.lifeNumber ?: 1)
                } else if (old == null && archive != null) pages[scope.id] = page.copy(affiliation = archive.schoolName.orEmpty(), ratings = archive.ratings, life = archive.lifeNumber)
            }
            val pro = state.pro
            val hs = state.highSchool
            val snapshot = if (state.stage == GameStage.PRO) pro?.lastPresentation else hs?.lastPresentation?.snapshot
            val scopeId = if (state.stage == GameStage.PRO) pro?.let { "pro:${it.careerId}:${it.currentStats.season}" }
                else hs?.run?.let { "hs:${it.careerId}" }
            val page = pages[scopeId]
            if (snapshot != null && page != null) {
                val previousSnapshot = if (state.stage == GameStage.PRO) before.pro?.lastPresentation else before.highSchool?.lastPresentation?.snapshot
                val newPitch = state === after && snapshot != previousSnapshot
                val context = if (!newPitch) emptyList() else if (state.stage == GameStage.PRO) before.pro?.activePitch?.let { p ->
                    listOf(p.game.inningState?.inning ?: p.context.inning, p.game.inningState?.outs ?: p.context.outs,
                        if (p.game.runners.firstOccupied) 1 else 0, if (p.game.runners.secondOccupied) 1 else 0, if (p.game.runners.thirdOccupied) 1 else 0)
                }.orEmpty() else before.highSchool?.activePitch?.game?.let { g -> listOf(g.inning, g.outs, if (g.firstOccupied) 1 else 0, if (g.secondOccupied) 1 else 0, if (g.thirdOccupied) 1 else 0) }.orEmpty()
                val pitch = AlbumPitch(snapshot.presentationSeed, snapshot.pitchType.wire, snapshot.velocityTenthsKph, snapshot.trajectorySeries,
                    if (state.stage == GameStage.PRO) pro?.activePitch?.sessionId.orEmpty() else hs?.activePitch?.sessionId.orEmpty(),
                    if (state.stage == GameStage.PRO) pro?.activePitch?.log?.entries?.lastOrNull()?.outcome?.wire.orEmpty() else hs?.lastPresentation?.outcome.orEmpty(), context,
                    listOf(snapshot.flightDurationMilliseconds, snapshot.plateXMm, snapshot.plateYMm))
                pages[page.scope.id] = page.copy(pitches = (page.pitches + pitch).distinctBy { it.id })
            }
        }
        return pages.values.toList()
    }
    public fun replayRequest(pitch: AlbumPitch): com.solkim.baseball.model.PitchPresentationRequest? {
        if (pitch.trajectory.size < 4) return null
        val kind = com.solkim.baseball.core.pitch.PitchKind.entries.firstOrNull { it.wire == pitch.kind } ?: return null
        val outcome = com.solkim.baseball.core.pitch.PitchOutcome.entries.firstOrNull { it.wire == pitch.outcome } ?: com.solkim.baseball.core.pitch.PitchOutcome.CALLED_STRIKE
        val last = pitch.trajectory.takeLast(4)
        val snapshot = com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot(kind, pitch.id,
            pitch.flight.getOrNull(0) ?: 400, pitch.flight.getOrNull(1) ?: last[1], pitch.flight.getOrNull(2) ?: last[3], pitch.velocity, pitch.trajectory)
        return PitchPresentationFactory.fromTrajectoryPresentation("album-replay", 1, snapshot, outcome)
    }
    public fun pages(state: GameAggregateState): List<PlayerAlbumPage> = capture(state, state)
}

/** Optional additive field: old saves retain their exact wire format and commitment. */
internal object PlayerAlbumCodec {
    private fun s(v: String): JsonValue = JsonValue.Str(v)
    private fun n(v: Int): JsonValue = JsonValue.Num(v.toString())
    private fun a(v: List<JsonValue>): JsonValue = JsonValue.Arr(v)
    fun encode(pages: List<PlayerAlbumPage>): JsonValue = a(pages.map { p ->
        val rows = p.rows.map { r -> a(buildList {
            addAll(listOf(s(r.id), s(r.label), n(r.outs), n(r.strikeouts), n(r.runs), n(r.walks), n(r.hits), n(r.perfect), n(r.team), n(r.opponent), JsonValue.Bool(r.manual)))
            if (r.decision.isNotEmpty() || r.started) addAll(listOf(s(r.decision), JsonValue.Bool(r.started)))
        }) }
        val pitches = p.pitches.map { r -> a(buildList {
            addAll(listOf(s(r.id), s(r.kind), n(r.velocity), a(r.trajectory.map(::n))))
            if (r.session.isNotEmpty() || r.outcome.isNotEmpty() || r.context.isNotEmpty() || r.flight.isNotEmpty()) {
                addAll(listOf(s(r.session), s(r.outcome), a(r.context.map(::n))))
                if (r.flight.isNotEmpty()) add(a(r.flight.map(::n)))
            }
        }) }
        a(buildList {
            addAll(listOf(s(p.scope.id), s(p.scope.title), s(p.scope.player), n(p.games), n(p.outs), n(p.runs), n(p.strikeouts), JsonValue.Bool(p.inningsKnown), a(rows), a(pitches)))
            if (p.portraitSeed != p.scope.player || p.affiliation.isNotEmpty() || p.signature.isNotEmpty() || p.ratings.isNotEmpty() || p.life != 1)
                addAll(listOf(s(p.portraitSeed), s(p.affiliation), s(p.signature), a(p.ratings.map(::n)), n(p.life)))
        })
    })
    fun decode(value: JsonValue?): List<PlayerAlbumPage> {
        if (value == null) return emptyList()
        fun JsonValue.items() = (this as JsonValue.Arr).values
        fun JsonValue.text() = (this as JsonValue.Str).value
        fun JsonValue.int() = (this as JsonValue.Num).raw.toInt()
        fun JsonValue.bool() = (this as JsonValue.Bool).value
        return value.items().map { item ->
            val p = item.items(); require(p.size == 10 || p.size == 15)
            PlayerAlbumPage(RecordScope(p[0].text(), p[1].text(), p[2].text()), p[3].int(), p[4].int(), p[5].int(), p[6].int(), p[7].bool(),
                p[8].items().map { itemRow -> val r = itemRow.items(); require(r.size == 11 || r.size == 13)
                    CareerGameView(r[0].text(), r[1].text(), r[2].int(), r[3].int(), r[4].int(), r[5].int(), r[6].int(), r[7].int(), r[8].int(), r[9].int(), r[10].bool(), if (r.size == 13) r[11].text() else "", if (r.size == 13) r[12].bool() else false) },
                p[9].items().map { itemPitch -> val r = itemPitch.items(); require(r.size in setOf(4, 7, 8))
                    AlbumPitch(r[0].text(), r[1].text(), r[2].int(), r[3].items().map { it.int() },
                        if (r.size >= 7) r[4].text() else "", if (r.size >= 7) r[5].text() else "", if (r.size >= 7) r[6].items().map { it.int() } else emptyList(), if (r.size == 8) r[7].items().map { it.int() } else emptyList()) },
                if (p.size == 15) p[10].text() else p[2].text(),
                if (p.size == 15) p[11].text() else "", if (p.size == 15) p[12].text() else "",
                if (p.size == 15) p[13].items().map { it.int() } else emptyList(), if (p.size == 15) p[14].int() else 1)
        }.also(PlayerAlbum::validate)
    }
}
