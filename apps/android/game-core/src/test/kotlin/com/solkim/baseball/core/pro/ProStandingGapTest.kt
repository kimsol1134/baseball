package com.solkim.baseball.core.pro

import kotlin.test.*

class ProStandingGapTest {
    @Test fun drawsCanMakeThePercentageLeaderHaveANegativeGapToAnotherTeam() {
        val k = ProKernel()
        val state = k.startDirect(ProStartDirectRequest("918220", "precision_commander", "승차검증투수")).state
        val table = ProCatalog.teams.mapIndexed { i, team ->
            val numbers = when (i) { 0 -> listOf(90,49,5); 1 -> listOf(93,51,0); 2 -> listOf(65,78,1); else -> listOf(67,77,0) }
            ProStanding(0, team.id, team.name, numbers[0], numbers[1], numbers[2], 0, team.id == state.team.id)
        }.sortedWith(compareByDescending<ProStanding> { it.wins.toDouble()/(it.wins+it.losses) }.thenByDescending { it.wins })
        val leader = table.first()
        val ranked = table.mapIndexed { i, r -> r.copy(rank = i+1, gamesBehindPermille = ((leader.wins-r.wins)+(r.losses-leader.losses))*500) }
        assertEquals(-500, ranked[1].gamesBehindPermille)
        val saved = state.copy(standings = ranked).let { it.copy(commitment = k.commitment(it)) }
        assertEquals(saved, ProStateCodec.decode(ProStateCodec.encode(saved)))
        val damaged = saved.copy(standings = ranked.mapIndexed { i, r -> if (i==1) r.copy(gamesBehindPermille = -777) else r })
            .let { it.copy(commitment = k.commitment(it)) }
        assertFailsWith<IllegalArgumentException> { k.validateSavedState(damaged) }
    }
}
