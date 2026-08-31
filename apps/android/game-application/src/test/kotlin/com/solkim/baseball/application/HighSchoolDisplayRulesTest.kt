package com.solkim.baseball.application

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HighSchoolDisplayRulesTest {
    @Test
    fun catalogAndWindAreVisibleWithoutCallingCoreFromUI() {
        assertTrue(HighSchoolDisplayRules.regions.isNotEmpty())
        assertTrue(HighSchoolDisplayRules.presets.isNotEmpty())
        assertEquals(2, HighSchoolDisplayRules.windRulesVersion)
        assertTrue(HighSchoolDisplayRules.windIdFor("career-1").isNotBlank())
    }
}