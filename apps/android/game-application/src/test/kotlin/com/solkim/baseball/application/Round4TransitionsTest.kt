package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class Round4TransitionsTest {
    private fun at(boundary: PitchBoundary): PitchDurableState {
        val committed = boundary in setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL, PitchBoundary.COMPLETED)
        val consumed = boundary in setOf(PitchBoundary.CONSUMED, PitchBoundary.TERMINAL, PitchBoundary.COMPLETED)
        return PitchDurableState("session", PitchCareerKind.PRO, "career", "game", "1", boundary,
            pitchIndex = if (committed) 1 else 0, committedPitchIds = if (committed) listOf("p1") else emptyList(),
            consumedPitchIds = if (consumed) listOf("p1") else emptyList(), resultHashes = if (committed) listOf("hash") else emptyList(),
            terminalPitchId = "p1".takeIf { boundary in setOf(PitchBoundary.TERMINAL, PitchBoundary.COMPLETED) },
            abandonedReason = "leave".takeIf { boundary == PitchBoundary.ABANDONED })
    }
    @Test fun transitionMatrixRejectsInvalidCommandsAndKeepsCommittedResults() {
        val ordinary = PitchBoundary.entries.filter { it != PitchBoundary.SUSPENDED }.map(::at)
        val suspended = ordinary.filter { it.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) }.map {
            it.copy(boundary = PitchBoundary.SUSPENDED, suspendedFrom = it.boundary, checkpoint = "saved")
        }
        for (state in ordinary + suspended) {
            state.validate()
            val before = state.copy()
            if (state.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED)) {
                val parked = PitchStateTransitions.suspend(state, "saved")
                parked.validate()
                val resumed = PitchStateTransitions.resume(parked)
                assertEquals(state.copy(checkpoint = "saved"), resumed)
            } else assertFails { PitchStateTransitions.suspend(state, "saved") }
            if (state.boundary == PitchBoundary.SUSPENDED) PitchStateTransitions.resume(state).validate()
            else assertFails { PitchStateTransitions.resume(state) }
            if (PitchStateTransitions.canAbandon(state)) {
                val left = PitchStateTransitions.abandon(state, "leave")
                left.validate(); assertNull(left.suspendedFrom); assertEquals(state.committedPitchIds, left.committedPitchIds)
            } else assertFails { PitchStateTransitions.abandon(state, "leave") }
            assertEquals(before, state)
        }
    }

    @Test fun actualSuspendedProSaveCanLeaveAndResumeAfterNativeRestart() = runBlocking {
        val dir = Files.createTempDirectory("round4-suspend-")
        try {
            Files.write(dir.resolve("save.json"), javaClass.getResourceAsStream("/regression/round3-linked-pro-return-stage.json")!!.use { it.readBytes() })
            var store = KotlinGameStore.open("round4", CSharpLegacyGameStoreRepository(dir, "round4", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                assertEquals(PitchBoundary.SUSPENDED, store.current.pitch!!.boundary)
                assertEquals(PitchBoundary.PLAYING, store.current.pitch!!.suspendedFrom)
                val pro = store.current.pro
                PitchSessionController(store).abandonPitch(store.current.pitch!!.sessionId)
                assertEquals(PitchBoundary.ABANDONED, store.current.pitch!!.boundary)
                assertNull(store.current.pitch!!.suspendedFrom)
                store.close()
                store = KotlinGameStore.open("round4", CSharpLegacyGameStoreRepository(dir, "round4"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                assertNotNull(PitchSessionController(store).continueOfficialPitch())
                assertEquals(pro, store.current.pro)
                assertEquals(PitchBoundary.PLAYING, store.current.pitch!!.boundary)
                val bytes = Files.readAllBytes(dir.resolve("save.json"))
                assertFails { store.dispatch(GameCommandEnvelope("bad-resume", store.current.pitch!!.sessionId, store.current.revision, GameCommand.ResumePitch(store.current.pitch!!.sessionId))) }
                assertContentEquals(bytes, Files.readAllBytes(dir.resolve("save.json")))
            } finally { store.close() }
        } finally { dir.toFile().deleteRecursively() }
    }

    @Test fun actualSchoolSaveCanSuspendLeaveAndResumeWithoutChangingRecords() = runBlocking {
        val dir = Files.createTempDirectory("round4-school-")
        try {
            Files.write(dir.resolve("save.json"), javaClass.getResourceAsStream("/regression/high-school-terminal-v42.json")!!.use { it.readBytes() })
            var store = KotlinGameStore.open("round4-school", CSharpLegacyGameStoreRepository(dir, "round4-school", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                var c = PitchSessionController(store)
                val id = store.current.pitch!!.sessionId
                c.consumePresentation(id, c.preparePresentation(id, 0)); c.completePitchAndPostgame(id)
                assertNotNull(c.continueOfficialPitch())
                val before = store.current.highSchool
                c.suspendPitch(id)
                c.abandonPitch(id)
                store.close()
                store = KotlinGameStore.open("round4-school", CSharpLegacyGameStoreRepository(dir, "round4-school"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                c = PitchSessionController(store)
                assertNotNull(c.continueOfficialPitch())
                assertEquals(before, store.current.highSchool)
            } finally { store.close() }
        } finally { dir.toFile().deleteRecursively() }
    }

    @Test fun reservedTutorialResumesAsInputWithoutRereserving() = runBlocking {
        val store=KotlinGameStore.fromShadowFixture(GameAggregateState.initial("r4-reserved"))
        try {
            val c=ScreenController(store)
            c.execute(ScreenId.P001_OPENING,"enterSetup")
            c.execute(ScreenId.P002_SETUP,"startHighSchool")
            c.execute(ScreenId.P003_PROLOGUE,"beginTutorial")
            val reserve=c.projection(ScreenId.P004_PITCH_TUTORIAL).actions.first {it.id=="openTutorialPitch"}.payloads
            store.dispatchBatch(reserve.filterNot {it.envelope.command is GameCommand.StartPitch}.map {it.envelope})
            assertEquals(PitchBoundary.RESERVED,store.current.pitch!!.boundary)
            val id=store.current.pitch!!.sessionId
            val pitch=PitchSessionController(store)
            pitch.suspendPitch(id); pitch.resumePitch(id)
            assertEquals(PitchBoundary.PLAYING,store.current.pitch!!.boundary)
            assertEquals(id,store.current.pitch!!.sessionId)
            assertTrue(store.current.pitch!!.committedPitchIds.isEmpty())
        } finally {store.close()}
    }

    @Test fun failureCopyDistinguishesInvariantAndTemporaryIo() {
        val shape = GameActionFailurePresentation.message(IllegalArgumentException("pitch.abandoned_shape"), "abandonPitch", false, true)
        assertFalse(shape.contains("한 번 더")); assertTrue(shape.contains("이어"))
        val io = GameActionFailurePresentation.message(java.io.IOException("disk full"), "abandonPitch", true, true)
        assertFalse(io.contains("저장 공간")); assertTrue(io.contains("기록 저장"))
    }

    @Test fun callUpBoundaryAndUiReadTheSameRequirements() {
        val base = ProSeasonStats(1, "team", games = 11, strikeouts = 39)
        assertFalse(ProCallUpRules.qualifies(60, 46, 1, base))
        assertTrue(ProCallUpRules.qualifies(60, 46, 2, base))
        assertTrue(ProCallUpRules.qualifies(60, 46, 1, base.copy(games = 12)))
        assertTrue(ProCallUpRules.qualifies(60, 46, 1, base.copy(strikeouts = 40)))
        assertFalse(ProCallUpRules.qualifies(59, 46, 2, base))
        assertFalse(ProCallUpRules.qualifies(60, 45, 2, base))
        assertEquals(43, AbilityDisplayScale.rating(ProCallUpRules.SKILL_REQUIRED))
    }
}
