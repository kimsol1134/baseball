package com.solkim.baseball.core.pitch

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class MoundTensionTest {
    private fun runners(first: Boolean = false, second: Boolean = false, third: Boolean = false) =
        BaserunnerStateSnapshot(first, second, third, 52)

    private fun input(
        officialGame: Boolean = true,
        leverage: Int = 900,
        runners: BaserunnerStateSnapshot = BaserunnerStateSnapshot(false, false, false, 52),
        balls: Int = 0,
        strikes: Int = 0,
        outs: Int = 0,
        fatigue: Int = 0,
        batterThreat: Int = 50,
        recentAdverseEvent: Boolean = false,
        command: Int = 0,
        stamina: Int = 0,
        awakenings: List<String> = emptyList(),
        memories: List<String> = emptyList(),
    ) = MoundTensionInput(
        officialGame, leverage, runners, balls, strikes, outs, fatigue, batterThreat, recentAdverseEvent,
        MoundComposureInput(command, stamina, awakenings, memories),
    )

    @Test
    fun tensionRisesWithSituationPressure() {
        val tensions = listOf(620, 700, 780, 900, 1_000).map { MoundTensionModel.tension(input(leverage = it)) }
        tensions.zip(tensions.drop(1)).forEach { (a, b) -> assertTrue(a <= b) }
        val calm = MoundTensionModel.tension(input(leverage = 800))
        val stacked = MoundTensionModel.tension(
            input(leverage = 800, runners = runners(true, true, true), balls = 3, strikes = 2, outs = 2, fatigue = 80, batterThreat = 95, recentAdverseEvent = true),
        )
        assertTrue(stacked > calm)
        assertTrue(stacked <= 1.0)
    }

    @Test
    fun practiceHasNoTensionOrJitter() {
        val practice = input(officialGame = false, leverage = 1_000, runners = runners(true, true, true), balls = 3, strikes = 2, outs = 2, recentAdverseEvent = true)
        assertEquals(0.0, MoundTensionModel.tension(practice), 1e-9)
        assertEquals(0.0, MoundTensionModel.entryTension(0.8, false), 1e-9)
        assertTrue(MoundHeartbeatPattern.burst(0.0, 7UL).beats.isEmpty())
        assertEquals(
            0.0,
            MoundMeterDisturbance.offset(0.2, MoundTensionModel.tension(practice), listOf(0.0), true, false, 7UL),
            1e-9,
        )
    }

    @Test
    fun maximumComposureDampsAboutNinetyTwoPercent() {
        val situation = input(leverage = 1_000, runners = runners(true, true, true), balls = 3, strikes = 2, outs = 2, fatigue = 90, batterThreat = 100, recentAdverseEvent = true)
        val composed = input(
            leverage = 1_000, runners = runners(true, true, true), balls = 3, strikes = 2, outs = 2, fatigue = 90, batterThreat = 100, recentAdverseEvent = true,
            command = 100, stamina = 100,
            awakenings = listOf("calm_under_pressure", "scout_composure", "repeatable_release", "two_strike_plan", "traffic_controller", "late_inning_reserve"),
            memories = listOf("pressure_rehearsal", "two_strike_sequence", "bullpen_compass", "fatigue_diary", "coach_letter"),
        )
        assertEquals(1.0, MoundTensionModel.composure(composed.composure), 1e-6)
        assertEquals(0.08, MoundTensionModel.damping(1.0), 1e-6)
        assertTrue(MoundTensionModel.tension(composed) <= MoundTensionModel.tension(situation) * 0.08 + 1e-6)
    }

    @Test
    fun burstCadenceMatchesIosBands() {
        assertEquals(3, MoundHeartbeatPattern.entry(0.1).beats.size)
        assertEquals(0, MoundHeartbeatCadence.forTension(0.1).cycles)
        assertEquals(2, MoundHeartbeatCadence.forTension(0.45).cycles)
        assertEquals(3, MoundHeartbeatCadence.forTension(0.70).cycles)
        assertEquals(4, MoundHeartbeatCadence.forTension(0.90).cycles)
    }

    @Test
    fun jitterRespectsCapsAndReduceMotion() {
        val beats = listOf(0.0, 0.72)
        for (tension in listOf(0.10, 0.45, 0.70, 1.0)) {
            val peak = generateSequence(0.0) { it + 0.03 }.takeWhile { it <= 1.2 }.maxOf { time ->
                abs(MoundMeterDisturbance.offset(time, tension, beats, true, false, 123UL))
            }
            assertTrue(peak <= MoundTensionModel.jitterCap(tension) + 1e-6)
        }
        val full = MoundMeterDisturbance.offset(0.16, 0.90, listOf(0.0), true, false, 123UL)
        val reduced = MoundMeterDisturbance.offset(0.16, 0.90, listOf(0.0), true, true, 123UL)
        assertEquals(full * 0.5, reduced, 1e-6)
    }

    @Test
    fun disturbanceIsDeterministic() {
        val times = listOf(0.0, 0.017, 0.033, 0.083, 0.137, 0.251, 0.499, 0.812)
        val first = times.map { MoundMeterDisturbance.position(0.5, it, 0.70, listOf(0.0, 0.63), true, false, 991UL) }
        val second = times.map { MoundMeterDisturbance.position(0.5, it, 0.70, listOf(0.0, 0.63), true, false, 991UL) }
        assertEquals(first, second)
    }

    @Test
    fun hapticsOffRemovesTensionJitter() {
        assertEquals(0.0, MoundMeterDisturbance.offset(0.1, 1.0, listOf(0.0), false, false, 3UL), 1e-9)
    }
}
