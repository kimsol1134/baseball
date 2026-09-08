package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchDelivery
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Phase 4 saves written by the shipped schema-9 build must still open. The fixtures come from that
 * build's own encoder, so this covers the update path for a player who is mid-career.
 */
class HighSchoolLegacySaveCompatibilityTest {
    private fun fixture(name: String): ByteArray {
        val file = File("src/test/resources/legacy/$name")
        assertTrue(file.exists(), "missing fixture: ${file.absolutePath}")
        return file.readBytes()
    }

    @Test fun schemaNineSavesOpenAndKeepTheirRecords() {
        val finished = HighSchoolPhase4StateCodec.decode(fixture("high-school-phase4-v9-finished.bin"))
        assertEquals(11, HighSchoolPhase4StateCodec.SCHEMA_VERSION, "schema 9 fixtures must survive the assignment extension")
        assertTrue(finished.seasonLog.isNotEmpty(), "the recorded outing survives")
        assertEquals(1, finished.run.performance.importantGamesCompleted)
        // Fields added after schema 9 read as their defaults instead of failing the load.
        assertEquals(0, finished.run.performance.perfectReleases)
        assertEquals(false, finished.run.chapterGameClaimed)
        assertTrue(finished.seasonLog.none { it.regular })
        assertTrue(finished.seasonLog.all { it.perfectReleases == 0 })
        assertTrue(finished.archive.all { it.perfectReleases == 0 })

        val midGame = HighSchoolPhase4StateCodec.decode(fixture("high-school-phase4-v9-midgame.bin"))
        val session = assertNotNull(midGame.activePitch, "an unfinished outing survives")
        assertTrue(session.pitches > 0)
        assertEquals(0, session.perfectReleases)
        kotlin.test.assertNull(session.assignment)
        kotlin.test.assertNull(midGame.run.development)
    }

    @Test fun aSchemaNineSaveReEncodesUnderTheCurrentSchema() {
        val loaded = HighSchoolPhase4StateCodec.decode(fixture("high-school-phase4-v9-finished.bin"))
        val reEncoded = HighSchoolPhase4StateCodec.encode(loaded)
        assertEquals(loaded, HighSchoolPhase4StateCodec.decode(reEncoded), "a migrated save round-trips at the new schema")
    }
}

/** Opening an old save is half the job; the player then keeps playing and saves again. */
class HighSchoolLegacyMigrationSoakTest {
    private val kernel = HighSchoolPhase4Kernel()

    private fun fixture(): HighSchoolPhase4State =
        HighSchoolPhase4StateCodec.decode(File("src/test/resources/legacy/high-school-phase4-v9-finished.bin").readBytes())

    @Test fun anOldSaveKeepsPlayingAndSavingWithoutDrift() {
        var state = fixture()
        val startingGames = state.run.performance.importantGamesCompleted
        var moves = 0
        while (moves < 25 && state.run.phase != HighSchoolPhase.DRAFT && state.run.phase != HighSchoolPhase.COMPLETED) {
            state = when (state.run.phase) {
                HighSchoolPhase.TRAINING -> kernel.commitTraining("918220", state, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD).state
                HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship("918220", state, HighSchoolRelationshipResponse.LISTEN).state
                HighSchoolPhase.AWAKENING -> kernel.chooseAwakening("918220", state, state.run.awakeningOptions.first()).state
                HighSchoolPhase.CHAPTER_REVIEW -> kernel.advanceChapter("918220", state).state
                HighSchoolPhase.IMPORTANT_GAME -> {
                    var game = kernel.reserveImportantGame("918220", state)
                    var preparation = game.preparation ?: error("preparation missing")
                    var guard = 0
                    while (game.state.activePitch?.ended != true && guard++ < 80) {
                        game = kernel.submitPitch(game.state, game.state.activePitch!!.sessionId, preparation.primaryRecommendation.call, PitchDelivery(1_000, 900))
                        preparation = game.preparation ?: break
                    }
                    kernel.finishImportantGame(game.state).state
                }
                else -> error("phase=${state.run.phase}")
            }
            // Every step must survive the round trip the store performs after each command.
            val reloaded = HighSchoolPhase4StateCodec.decode(HighSchoolPhase4StateCodec.encode(state))
            assertEquals(state, reloaded, "step $moves at ${state.run.phase} must round-trip")
            moves += 1
        }
        assertTrue(moves > 0, "the old save must be playable")
        assertTrue(state.run.performance.importantGamesCompleted >= startingGames)
        assertTrue(state.run.performance.perfectReleases > 0, "new counters start filling on an old save")
    }
}
