package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pro.*
import kotlin.test.*

class RulesVersionMigrationTest {
    @Test fun currentCommandsUpgradeTheRulesWithoutRecreatingThePitcherOrSchedule() {
        val reference = HighSchoolKernel(balanceRulesVersion = 4)
        val legacy = reference.start(HighSchoolKernel.StartRequest("918220", "power_prospect"))
        val bytes = HighSchoolStateCodec.encode(legacy.snapshot)
        val next = HighSchoolKernel().completePrologue(HighSchoolKernel.AdvanceRequest(legacy.nextSeed, legacy.snapshot)).snapshot
        assertEquals(5, next.balanceVersion)
        assertEquals(legacy.snapshot.pitcher, next.pitcher)
        assertEquals(legacy.snapshot.careerId, next.careerId)
        assertEquals(legacy.snapshot.schedule, next.schedule)
        assertContentEquals(bytes, HighSchoolStateCodec.encode(legacy.snapshot))
        assertEquals(next, HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(next)))
        assertFailsWith<IllegalArgumentException> { reference.chooseSchool(HighSchoolKernel.ChooseSchoolRequest("99881", next, HighSchoolSchoolId.HAEDONG_POWER)) }
    }
    @Test fun version10ProUpgradesOnACommittedWeekWhileHistoricalReplayRemainsVersion10() {
        val reference = ProKernel(gameplayRulesVersion = 10)
        val old = reference.startDirect(ProStartDirectRequest("918220", "power_prospect", "버전투수")).state
        val bytes = ProStateCodec.encode(old)
        val replay = reference.planWeek(old, "99881", ProWeekPlan.DEVELOP_STUFF).state
        assertEquals(10, replay.proRulesVersion)
        val next = ProKernel().planWeek(old, "99881", ProWeekPlan.DEVELOP_STUFF).state
        assertEquals(11, next.proRulesVersion)
        assertEquals(old.identityName, next.identityName); assertEquals(old.careerId, next.careerId); assertEquals(old.team, next.team)
        assertContentEquals(bytes, ProStateCodec.encode(old))
        assertEquals(next, ProStateCodec.decode(ProStateCodec.encode(next)))
    }
}
