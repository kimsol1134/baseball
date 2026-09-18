package com.solkim.baseball.core.pro

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Saves written by the shipped schema-3 build must still open. The fixtures were produced by that
 * build's own encoder, so this is the real update path for a player who is mid-career.
 */
class ProLegacySaveCompatibilityTest {
    private fun fixture(name: String): ByteArray {
        val file = File("src/test/resources/legacy/$name")
        assertTrue(file.exists(), "missing fixture: ${file.absolutePath}")
        return file.readBytes()
    }

    @Test fun schemaThreeSavesOpenAndReadTheirRecordsBack() {
        val finished = ProStateCodec.decode(fixture("pro-state-v3-finished.bin"))
        assertEquals(7, ProWire.STATE_SCHEMA_VERSION, "schema 3 fixtures must survive earned-run tracking")
        kotlin.test.assertNull(finished.currentStats.earnedRuns)
        assertEquals("민서준", finished.identityName)
        assertTrue(finished.currentGameLines.any { it.played }, "the archived outing survives")
        assertEquals(finished.currentGameLines.count { it.played }, finished.currentStats.games)
        // Fields added after schema 3 read as their defaults instead of failing the load.
        assertEquals(0, finished.currentStats.perfectReleases)
        assertTrue(finished.currentGameLines.all { it.perfectReleases == 0 })

        val midGame = ProStateCodec.decode(fixture("pro-state-v3-midgame.bin"))
        val session = assertNotNull(midGame.activePitch, "an unfinished outing survives")
        assertTrue(session.pitches > 0)
        assertEquals(0, session.perfectReleases)
        kotlin.test.assertNull(session.assignment)
    }

    @Test fun aSchemaThreeSaveStillReSignsAndReEncodesUnderTheCurrentSchema() {
        val loaded = ProStateCodec.decode(fixture("pro-state-v3-finished.bin"))
        val reEncoded = ProStateCodec.encode(loaded)
        assertEquals(loaded, ProStateCodec.decode(reEncoded), "a migrated save round-trips at the new schema")
    }
}

/** The same for a pro career: open the shipped save, keep playing, keep saving. */
class ProLegacyMigrationSoakTest {
    private val kernel = ProKernel()

    @Test fun anOldProSaveKeepsPlayingAndSavingWithoutDrift() {
        var state = ProStateCodec.decode(File("src/test/resources/legacy/pro-state-v3-finished.bin").readBytes())
        val startingWeek = state.week
        var seed = "4100"
        var moves = 0
        while (moves < 12 && state.phase == ProCareerPhase.WEEKLY_PLAN) {
            state = kernel.planWeek(state, seed, ProWeekPlan.RECOVER, null).state
            val reloaded = ProStateCodec.decode(ProStateCodec.encode(state))
            assertEquals(state, reloaded, "week ${state.week} must round-trip")
            seed = (seed.toLong() + 7).toString()
            moves += 1
        }
        assertTrue(moves > 0, "the old save must be playable")
        assertTrue(state.week > startingWeek, "the career moves forward")
        assertEquals(0, state.currentStats.perfectReleases, "an old save has no perfect history to invent")
    }
}
