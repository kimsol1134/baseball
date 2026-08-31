package com.solkim.baseball.core.pitch

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class MasteryEffectRulesTest {
    @Test
    fun diminishingReturnFixedPointsMatchSharedContract() {
        assertEquals(0, MasteryEffectRules.bonusPermille(0))
        assertEquals(20, MasteryEffectRules.bonusPermille(5))
        assertEquals(35, MasteryEffectRules.bonusPermille(10))
        assertEquals(61, MasteryEffectRules.bonusPermille(25))
        assertEquals(81, MasteryEffectRules.bonusPermille(50))
        assertEquals(96, MasteryEffectRules.bonusPermille(100))
        assertTrue(MasteryEffectRules.bonusPermille(Int.MAX_VALUE) <= 120)
    }

    @Test
    fun masteryAddsSaturateAtSignedIntBoundary() {
        val full = AbilityMasterySnapshot(stuff = Int.MAX_VALUE, command = -1, movement = 1, stamina = 2)
        assertEquals(Int.MAX_VALUE, full.stuff)
        assertEquals(0, full.command)
        assertEquals(Int.MAX_VALUE, full.add(PitchAbilityKind.POWER, 9).stuff)
        assertEquals(3, full.add(PitchAbilityKind.STAMINA, 1).stamina)
    }
}
