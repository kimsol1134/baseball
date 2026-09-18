package com.solkim.baseball.core.highschool

import kotlin.test.*

class LineageRecoveryTest {
    private fun archive(life: Int) = HighSchoolArchiveRecord("life-$life", life, "민서준", null, null, false, 50, null,
        listOf(40, 40, 40, 40), 1, 12, 3, 0, 0, emptyList(), "command_map", null, false, 10, life.toULong())
    @Test fun oldSaveRecoveryIsAppliedOnceAtTheNextBirth() {
        val k = HighSchoolPhase4Kernel()
        val base = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "old-lineage", "2026-W37", "2026-09-08")).state
        val run = HighSchoolKernel().resignShadowState(base.run.copy(lifeNumber = 6, phase = HighSchoolPhase.COMPLETED,
            draftResult = HighSchoolDraftResult(HighSchoolDraftOutcome.UNDRAFTED, 50, "", null)))
        val records = (1..6).map { archive(it).let { row -> if (it == 6) row.copy(careerId = run.careerId) else row } }
        val old = HighSchoolInheritanceState(7, 60, 60, 60, selectedSignatureLegacyId = "command_map",
            lineageMasteries = HighSchoolLineageRules.masteries(listOf("command_map")), lineageLoadout = HighSchoolLineageLoadout(1, "command_map", 1, 1, 6))
        val saved = k.commitShadowState(base.copy(run = run, archive = records, inheritance = old,
            completedGameCounter = 6UL, completedGameReceipts = (1..6).map { "game-$it" }))
        val loaded = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(saved))
        assertEquals(saved.run.pitcher, loaded.run.pitcher)
        val next = k.beginRebirth(loaded, "918221").state
        assertEquals(7, next.run.lifeNumber)
        assertEquals(3, next.inheritance.lineageLoadout!!.masteryRank)
        val reopened = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(next))
        assertEquals(next.run.pitcher, reopened.run.pitcher)
        assertFailsWith<IllegalArgumentException> { k.beginRebirth(reopened, "918222") }
    }

    @Test fun repeatedLegacyChoicesRecoverThreeAndSixLifeRanksWithoutChangingLiveRatings() {
        val old = HighSchoolInheritanceState(7, 60, 60, 60, selectedSignatureLegacyId = "command_map",
            lineageMasteries = HighSchoolLineageRules.masteries(listOf("command_map")),
            lineageLoadout = HighSchoolLineageLoadout(1, "command_map", 1, 1, 6))
        val records = (1..6).map(::archive)
        val recovered = HighSchoolLineageRules.recovered(old, records)
        assertEquals(3, recovered.lineageLoadout!!.masteryRank)
        assertEquals(6, recovered.lineageLoadout!!.contributions)
        assertEquals(60, recovered.soulPoints)
        assertEquals(recovered, HighSchoolLineageRules.recovered(recovered, records))
        val three = HighSchoolLineageRules.recovered(old.copy(lineageLoadout = old.lineageLoadout!!.copy(sourceLifeNumber = 3)), records.take(3))
        assertEquals(2, three.lineageLoadout!!.masteryRank)
        val start = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "lineage-test", "2026-W37", "2026-09-08")).state
        val prior = HighSchoolLineageRules.apply(old.lineageLoadout, start.run.pitcher, start.run.talent)
        val next = HighSchoolLineageRules.apply(recovered.lineageLoadout, start.run.pitcher, start.run.talent)
        assertEquals(prior.pitcher.command + 1, next.pitcher.command)
        assertEquals(prior.pitcher.movement + 1, next.pitcher.movement)
        assertEquals(1, old.lineageLoadout!!.rulesVersion)
        assertEquals(2, recovered.lineageLoadout!!.rulesVersion)
    }
}
