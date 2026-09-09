package com.solkim.baseball.application

import com.solkim.baseball.application.fixtures.prepareNaturalHighFatigueInput
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.model.*
import com.solkim.baseball.persistence.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class Round6PitchRecoveryTest {
    @Test fun nativeFailuresKeepThePitchAndIdentifyTheExactFailedCommand() = runBlocking {
        for (failOnWrite in listOf(1, 2)) {
            val dir = Files.createTempDirectory("round6-recovery-")
            var remaining = 0
            val repo = CSharpLegacyGameStoreRepository(dir, "r6", faults = SaveFaultInjector { point ->
                if (point == SaveFaultPoint.BEFORE_CANONICAL_SWAP && remaining > 0 && --remaining == 0) throw java.io.IOException("round6.injected_write")
            })
            var store = KotlinGameStore.open("r6", repo, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                Phase8Controller(store).execute(Phase8ScreenId.P001_OPENING, "startDirect")
                val root = StrictJson.parseUtf8(Files.readAllBytes(dir.resolve("save.json"))) as JsonValue.Obj
                val launch = prepareNaturalHighFatigueInput(store, root["payload"] as JsonValue.Obj)
                assertNull(store.current.pro!!.lastPresentation)
                assertNull(store.current.pro!!.lastBattedBall)
                assertNull(store.current.pro!!.lastFielding)
                assertFalse(Phase7VerticalController(store).shouldRecoverPlayingPresentation(store.current, launch.sessionId))
                assertEquals(80, PitchHudProjection.fatigue(store.current))
                assertEquals(18, store.current.pro!!.activePitch!!.pitches)
                var controller = Phase7VerticalController(store)
                remaining = 1
                val beforeSubmit = store.current.pro
                assertFails { controller.submitPitch(launch.sessionId, PitchHudSelection.Primary, PitchDelivery(1000,1000)) }
                assertEquals(beforeSubmit, store.current.pro)
                assertFalse(PitchFailureRecovery.hasSavedResult(store.reconcilePersistedRevision().state, launch.sessionId, "not-saved"))
                val saved = controller.submitPitch(launch.sessionId, PitchHudSelection.Primary, PitchDelivery(1000,1000))
                val pro = store.current.pro
                remaining = failOnWrite
                val error = assertFails { controller.consumePresentation(launch.sessionId, saved) }
                val context = assertNotNull(GameCommandFailureContext.from(error))
                assertEquals(if (failOnWrite == 1) "consumePitch" else "terminalPitch", context.operation)
                assertTrue(context.commandId.startsWith("revision:"))
                assertEquals(saved.pitchId, context.pitchId)
                val reconciled = store.reconcilePersistedRevision()
                assertTrue(reconciled.durableStateVerified)
                assertTrue(PitchFailureRecovery.hasSavedResult(reconciled.state, launch.sessionId, saved.pitchId))
                assertEquals(if (failOnWrite == 1) PitchBoundary.COMMITTED else PitchBoundary.CONSUMED, store.current.pitch!!.boundary)
                store.close()
                store = KotlinGameStore.open("r6", CSharpLegacyGameStoreRepository(dir,"r6"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                controller = Phase7VerticalController(store)
                assertFails { controller.consumePresentation("stale-session", saved) }
                assertFails { controller.consumePresentation(launch.sessionId, saved.copy(pitchId="stale-pitch")) }
                controller.consumePresentation(launch.sessionId, saved)
                val revision = store.current.revision
                controller.consumePresentation(launch.sessionId, saved)
                assertEquals(revision, store.current.revision)
                assertEquals(pro, store.current.pro)
                assertEquals(PitchBoundary.TERMINAL, store.current.pitch!!.boundary)
            } finally { store.close(); dir.toFile().deleteRecursively() }
        }
    }

    @Test fun missingSaveIsNotDurableVerification() = runBlocking {
        val dir = Files.createTempDirectory("round6-empty-")
        val store = KotlinGameStore.open("r6", CSharpLegacyGameStoreRepository(dir,"r6"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try { assertFalse(store.reconcilePersistedRevision().durableStateVerified) }
        finally { store.close(); dir.toFile().deleteRecursively() }
    }
}
