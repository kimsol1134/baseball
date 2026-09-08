package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.core.highschool.*
import kotlin.test.*

class CareerMemoryTest {
    @Test fun realClosingOutingCreatesOneLeadAndSaveMemoryThatSurvivesTheNextLife() {
        val k = ProKernel()
        val start = k.startDirect(ProStartDirectRequest("918220", "power_prospect", "기억투수")).state
        val ready = start.copy(phase = ProCareerPhase.IMPORTANT_GAME, role = ProRole.CLOSER,
            week = 1, seasonSegment = ProCatalog.segment(1), seasonTrigger = ProSeasonTrigger.STANDINGS_RACE).let { it.copy(commitment = k.commitment(it)) }
        val successful = (1..30).firstNotNullOf { seed ->
            var result = k.reserveImportantGame(ready, seed.toString())
            var state = GameAggregateState.initial("memory-game").copy(stage = GameStage.PRO, pro = result.state)
            fun advance(pro: ProState) { val next = state.copy(pro = pro); state = next.copy(meta = next.meta.copy(companion = PitcherCompanionRules.transition(state, next))) }
            var pitches = 0
            while (!result.state.activePitch!!.ended && pitches++ < 90) {
                result = k.submitPitch(result.state, result.state.activePitch!!.sessionId, result.preparation!!.primaryRecommendation.call, PitchDelivery(1000, 1000))
                advance(result.state)
            }
            advance(k.finishImportantGame(result.state).state)
            state.takeIf { it.meta.companion?.memories?.any { m -> m.kind == "first_save" } == true }
        }
        val c = successful.meta.companion!!
        assertEquals(1, c.memories.count { it.kind == "held_lead" })
        assertEquals(1, c.memories.count { it.kind == "first_save" })
        assertEquals(1, c.memories.count { it.kind == "best_outing" })
        assertEquals(c, PitcherCompanionRules.transition(successful, successful))
        assertEquals(c, PitcherCompanionCodec.decode(PitcherCompanionCodec.encode(c)))
        assertTrue(CareerMemoryPresentation.featured(successful).all { CareerMemoryPresentation.detail(it, GameCopy(GameLanguage.ENGLISH)).isNotBlank() })
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "new-life", "2026-W37", "2026-09-08")).state
        val reborn = successful.copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
        val next = PitcherCompanionRules.transition(successful, reborn)!!
        assertEquals(c.memories, next.memories)
        assertEquals(next, PitcherCompanionCodec.decode(PitcherCompanionCodec.encode(next)))
    }
    @Test fun oldMemoriesKeepTheirOriginalWireShapeAndNoInventedGameLine() {
        val old = PitcherCompanion(memories = listOf(PitchMemory("old", "old-career", 1, "first_strikeout", amount = 1)))
        val encoded = PitcherCompanionCodec.encode(old)
        val roundtrip = PitcherCompanionCodec.decode(encoded)!!
        assertEquals(old, roundtrip)
        assertFalse(com.solkim.baseball.model.StrictJson.canonical(encoded).contains("source"))
        assertEquals("", CareerMemoryPresentation.detail(roundtrip.memories.single(), GameCopy(GameLanguage.KOREAN)))
    }
}
