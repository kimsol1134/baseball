package com.solkim.baseball.android

import android.util.Log
import androidx.test.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.solkim.baseball.application.GameCommand
import com.solkim.baseball.application.GameCommandEnvelope
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Phase 10's one real production-package Kotlin write.  The test is skipped by the debug
 * `.compose.dev` fixture and only runs against the signed nativeAuthoritative variant.
 */
@RunWith(AndroidJUnit4::class)
class Phase10NativeAuthoritativeCommandTest {
    @Test
    fun settingsCommandPublishesOnlyAfterAtomicReadback() {
        assumeTrue("nativeAuthoritative release only", BuildConfig.PHASE10_PRODUCTION_BUILD)
        assertEquals("nativeAuthoritative", BuildConfig.NATIVE_AUTHORITY_MODE)

        val context = InstrumentationRegistry.getTargetContext()
        val application = context.applicationContext as BaseballApplication
        val store = application.gameStore
        val saveDirectory = requireNotNull(application.getExternalFilesDir(null)).resolve("save")
        val canonical = File(saveDirectory, "save.json")
        val backup = File(saveDirectory, "save.bak.1")
        val temporary = File(saveDirectory, "save.tmp")
        val beforeText = canonical.readText(Charsets.UTF_8)
        val beforeRevision = store.current.revision
        val beforeRevisionMarker = "\"revision\":\"$beforeRevision\""
        assertTrue("canonical revision must match the live Kotlin state", beforeText.contains(beforeRevisionMarker))

        val nextSettings = store.current.settings.copy(
            highContrastEnabled = !store.current.settings.highContrastEnabled,
            reducedMotionEnabled = !store.current.settings.reducedMotionEnabled,
        )
        val command = GameCommandEnvelope(
            commandId = "phase10-kotlin-settings-$beforeRevision",
            sessionId = "phase10-instrumentation",
            expectedRevision = beforeRevision,
            command = GameCommand.UpdateSettings(nextSettings),
        )

        val result = runBlocking { store.dispatch(command) }
        val afterRevision = beforeRevision + 1UL
        val afterText = canonical.readText(Charsets.UTF_8)

        assertFalse("atomic temporary file must not remain", temporary.exists())
        assertTrue("backup must be published with the canonical candidate", backup.isFile)
        assertEquals(afterRevision, result.state.revision)
        assertEquals(afterRevision, store.current.revision)
        assertEquals(nextSettings, store.current.settings)
        assertTrue(afterText.contains("\"revision\":\"$afterRevision\""))
        assertTrue(afterText.contains("\"revision\":$afterRevision"))
        assertTrue(afterText.contains("\"highContrastEnabled\":${nextSettings.highContrastEnabled}"))
        assertTrue(afterText.contains("\"reducedMotionEnabled\":${nextSettings.reducedMotionEnabled}"))
        assertTrue(afterText.contains(command.commandId))

        Log.i(
            "BASEBALL_PHASE10",
            "PHASE10_NATIVE_COMMAND status=passed command=settings revision=$afterRevision " +
                "atomicReadback=true backupPresent=true typedWriter=forbidden",
        )
    }
}
