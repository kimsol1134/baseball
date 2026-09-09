package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import kotlin.test.*

class PlayerAlbumTest {
    @Test fun seasonTransitionPreservesEveryOutingAndBackupRoundTrips() {
        val k = ProKernel()
        val p = k.planWeek(k.startDirect(ProStartDirectRequest("918220", "power_prospect", "앨범투수")).state, "99881", ProWeekPlan.DEVELOP_STUFF).state
        val before = GameAggregateState.initial("album").copy(stage = GameStage.PRO, pro = p).committed()
        val next = before.copy(pro = p.copy(season = 2, currentStats = ProSeasonStats(season = 2, teamId = p.team.id), careerStats = listOf(p.currentStats), currentGameLines = emptyList()))
        val pages = PlayerAlbum.capture(before, next)
        val season1 = pages.single { it.scope.id.endsWith(":1") }
        assertEquals(p.currentGameLines.size, season1.rows.size)
        val archived = next.copy(meta = next.meta.copy(album = pages))
        assertEquals(p.currentGameLines.size, CareerRecordPresentation.resolve(archived, season1.scope.id)!!.rows.size)
        assertFalse(CareerRecordPresentation.resolve(archived, season1.scope.id)!!.incomplete)
        assertEquals(pages, PlayerAlbumCodec.decode(PlayerAlbumCodec.encode(pages)))
        val valid = before.copy(meta = before.meta.copy(album = pages)).committed()
        assertEquals(valid, GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(valid)))
        assertEquals(pages, PlayerAlbum.capture(archived, archived))
    }
    @Test fun recordedTrajectorySurvivesPresentationCleanupWithoutDuplicates() {
        val p = ProKernel().startDirect(ProStartDirectRequest("918220", "power_prospect", "투수")).state
        val before = GameAggregateState.initial("replay").copy(stage = GameStage.PRO, pro = p)
        val trajectory = (0..24).flatMap { listOf(it, it*3, 18000-it*700, 1500-it*20) }
        val snapshot = com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot(com.solkim.baseball.core.pitch.PitchKind.FOUR_SEAM, "12345", 400, 70, 1000, 1480, trajectory)
        val after = before.copy(pro = p.copy(lastPresentation = snapshot))
        val pages = PlayerAlbum.capture(before, after)
        assertEquals(trajectory, pages.single().pitches.single().trajectory)
        val saved = after.copy(meta = after.meta.copy(album = pages))
        val cleared = saved.copy(pro = p)
        assertEquals(pages, PlayerAlbum.capture(saved, cleared))
        assertEquals(pages, PlayerAlbumCodec.decode(PlayerAlbumCodec.encode(pages)))
        assertEquals(snapshot, after.pro!!.lastPresentation)
    }
    @Test fun oldSaveEncodingIsUnchangedAndAlbumTamperingIsRejected() {
        val old = GameAggregateState.initial("album")
        assertEquals(old, GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(old)))
        assertFalse(GameAggregateCodec.encodePayload(old).toString().contains("album="))
        val page = PlayerAlbumPage(RecordScope("hs:first", "고교", "선수"), 0, 0, 0, 0, true, emptyList())
        assertFails { old.copy(meta = old.meta.copy(album = listOf(page))).validate() }
        val saved = old.copy(meta = old.meta.copy(album = listOf(page))).committed()
        assertEquals(saved, GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(saved)))
    }
}
