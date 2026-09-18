package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlin.test.*

class AwakeningTreePresentationTest {
    private fun fixture(owned: List<HighSchoolAwakening> = emptyList(), sparks: Int = 0): GameAggregateState {
        val kernel = HighSchoolKernel()
        val school = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "tree", "2026-W36", "2026-09-05")).state
        var run = school.run.copy(phase = HighSchoolPhase.AWAKENING, selectedAwakenings = owned, awakeningSparks = sparks)
        run = run.copy(awakeningOptions = kernel.availableAwakenings(run))
        return GameAggregateState.initial("tree").copy(highSchool = school.copy(run = run))
    }
    @Test fun everyNodeKeepsItsRealParentsAndBranchLayout() {
        val nodes = AwakeningTreePresentation.nodes(fixture())
        assertEquals(18, nodes.size)
        for (spec in HighSchoolContentCatalog.awakeningNodes) {
            val node = nodes.single { it.choice.id == spec.id.wire }
            assertEquals(spec.parents.map { it.wire }, node.parents)
            assertEquals(spec.branch, node.branch)
            assertTrue(node.column in 0.25f..0.75f)
            if (spec.tier == 3) assertEquals(nodes.single { it.choice.id == node.parents.single() }.column, node.column)
        }
    }
    @Test fun advancedSkillsWaitForRebirthAndExistingThirdSkillIsPreserved() {
        val owned = listOf(HighSchoolAwakening.PINPOINT_EDGE)
        val locked = AwakeningTreePresentation.nodes(fixture(owned)).single { it.choice.id == "calm_under_pressure" }
        assertFalse(locked.choice.available)
        val leap = AwakeningTreePresentation.nodes(fixture(owned, 3)).single { it.choice.id == "calm_under_pressure" }
        assertFalse(leap.choice.available, "First-life sparks cannot skip the advanced-skill gate")
        val full = fixture(listOf(HighSchoolAwakening.PINPOINT_EDGE, HighSchoolAwakening.EXPLOSIVE_FASTBALL, HighSchoolAwakening.BATTERY_SYNC), 3)
        assertTrue(AwakeningTreePresentation.nodes(full).none { it.choice.available })
        assertEquals(3, AwakeningTreePresentation.nodes(full).count { it.choice.owned })
    }
    @Test fun summaryShowsRealTradeoffsAndDoesNotApplyOwnedSkillsTwice() {
        val state = fixture()
        val node = AwakeningTreePresentation.nodes(state).single { it.choice.id == "explosive_fastball" }
        for (language in GameLanguage.entries) {
            val summary = AwakeningTreePresentation.summary(state, node, GameCopy(language))
            assertTrue(summary.benefit.contains("1.5 km/h"))
            assertNotNull(summary.cost)
        }
        val owned = fixture(listOf(HighSchoolAwakening.EXPLOSIVE_FASTBALL))
        val ownedNode = AwakeningTreePresentation.nodes(owned).single { it.choice.id == node.choice.id }
        val summary = AwakeningTreePresentation.summary(owned, ownedNode, GameCopy(GameLanguage.KOREAN))
        assertFalse(summary.benefit.contains("+"))
        assertNull(summary.cost)
    }    @Test fun cappedRatingsDoNotAdvertiseGainsThatCannotApply() {
        val state = fixture()
        val school = state.highSchool!!
        val pitcher = school.run.pitcher.copy(stuff = 80, command = 80, movement = 80, stamina = 80,
            pitchProfiles = school.run.pitcher.pitchProfiles.map { it.copy(command = 80, control = 80, movement = 80, whiff = 80, weakContact = 80) })
        val capped = state.copy(highSchool = school.copy(run = school.run.copy(pitcher = pitcher)))
        val node = AwakeningTreePresentation.nodes(capped).single { it.choice.id == "battery_sync" }
        val copy = GameCopy(GameLanguage.KOREAN)
        assertEquals(copy.resolve("awakening.tree.no-gain"), AwakeningTreePresentation.summary(capped, node, copy).benefit)
    }

    @Test fun risingMovementAndPassiveStabilityAreShownWithoutUnrelatedCosts() {
        val state = fixture()
        val nodes = AwakeningTreePresentation.nodes(state)
        val copy = GameCopy(GameLanguage.KOREAN)
        val rising = AwakeningTreePresentation.summary(state, nodes.single { it.choice.id == "rising_four_seam" }, copy)
        assertTrue(rising.benefit.contains("포심"))
        assertTrue(rising.benefit.contains("움직임"))
        assertNull(rising.cost)
        val calm = AwakeningTreePresentation.summary(state, nodes.single { it.choice.id == "calm_under_pressure" }, copy)
        assertTrue(calm.benefit.contains("흔들림"))
    }

}
