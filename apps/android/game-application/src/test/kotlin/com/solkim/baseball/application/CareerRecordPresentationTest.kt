package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.highschool.*
import kotlin.test.*

class CareerRecordPresentationTest {
    @Test fun professionalOutingsAndSeasonTotalsSurviveScopeChangesAndArchive() {
        val k = ProKernel()
        val start = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "기록투수")).state
        val played = k.planWeek(start, "99881", ProWeekPlan.DEVELOP_STUFF).state
        val state = GameAggregateState.initial("record").copy(stage = GameStage.PRO, pro = played)
        val view = assertNotNull(CareerRecordPresentation.resolve(state))
        assertEquals(played.currentStats.games, view.games)
        assertTrue(view.games > 0)
        assertEquals(played.currentStats.inningsOuts, view.outs)
        assertEquals(view.outs, view.rows.sumOf { it.outs })
        val season2 = played.copy(season = 2, currentStats = played.currentStats.copy(season = 2, games = 0, inningsOuts = 0, runsAllowed = 0, strikeouts = 0),
            careerStats = listOf(played.currentStats), currentGameLines = emptyList())
        val next = state.copy(pro = season2)
        assertEquals(view.games, CareerRecordPresentation.resolve(next)!!.games)
        assertTrue(CareerRecordPresentation.resolve(next)!!.incomplete)
        assertEquals(0, CareerRecordPresentation.resolve(next, "pro:${played.careerId}:2")!!.games)
        val retired = next.copy(pro = null, stage = GameStage.LEGACY, meta = next.meta.copy(retiredProCareers = listOf(season2)))
        assertEquals(view.games, CareerRecordPresentation.resolve(retired)!!.games)
    }
    @Test fun directAndAutomaticPartsRemainOneGameAndOutsAreSummedAsBaseballInnings() {
        val k = HighSchoolPhase4Kernel()
        val base = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "mixed", "2026-W37", "2026-09-08")).state
        val direct = HighSchoolSeasonLine(base.run.careerId, 1, 1, 1, 30, 2, 0, 0, 0, 0, emptyList(), outs = 4, played = true)
        val automatic = direct.copy(outs = 2, played = false, strikeouts = 1)
        val hs = base.copy(seasonLog = listOf(automatic, direct), run = base.run.copy(performance = base.run.performance.copy(importantGamesCompleted = 1, outs = 4, strikeouts = 2), automaticOuts = 2))
        val state = GameAggregateState.initial("mixed").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
        val view = CareerRecordPresentation.resolve(state)!!
        assertEquals(1, view.games); assertEquals("2.0", view.innings); assertEquals(3, view.strikeouts)
        assertEquals(1, view.rows.size); assertTrue(view.rows.single().label.contains("직접+자동"))
        val signed = k.commitShadowState(hs.copy(run = HighSchoolKernel().resignShadowState(hs.run)))
        assertEquals(view, CareerRecordPresentation.resolve(state.copy(highSchool = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(signed)))))
    }
}
