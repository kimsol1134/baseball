package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.persistence.SaveLoadStatus
import com.solkim.baseball.persistence.SaveRepositoryException
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import java.nio.file.Path
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** File-backed Phase 8 career completion: 고교 보관 → 프로 연결 → 시즌 결산 저장 → 20시즌 은퇴. */
class Phase8CareerCompletionStoreTest {
    private val context = Phase8CommandContext(Phase8KoreaClock { LocalDate.of(2026, 8, 14) })

    @Test
    fun linkedProPitchLiveResultIgnoresLeftoverHighSchoolPresentation() = runBlocking {
        withTempDirectory { directory ->
            val session = openFileSession("linked-pro-live", directory)
            session.completeHighSchoolAndEnterPro()
            assertNotNull(session.store.current.pro)
            val leftoverHsWire = requireNotNull(session.store.current.highSchool?.lastPresentation?.outcome)
            session.advanceProUntil(ProCareerPhase.IMPORTANT_GAME)
            session.executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "openProImportantGame")
            val pitch = requireNotNull(session.store.current.pitch)
            assertEquals(PitchCareerKind.PRO, pitch.careerKind)
            val request = session.phase7.submitPitch(pitch.sessionId, 0, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(1_000, 1_000))
            val proOutcome = requireNotNull(session.store.current.pro?.activePitch?.log?.entries?.lastOrNull()?.outcome)
            assertEquals(proOutcome, PitchLiveResult.outcome(session.store.current))
            assertEquals(session.store.current.pro?.lastBattedBall, PitchLiveResult.battedBall(session.store.current))
            assertEquals(session.store.current.pro?.lastFielding, PitchLiveResult.fielding(session.store.current))
            assertEquals(leftoverHsWire, session.store.current.highSchool?.lastPresentation?.outcome)
            session.phase7.consumePresentation(pitch.sessionId, request)
            if (session.store.current.pro?.activePitch?.ended != true) {
                session.phase7.completePitchAndPostgame(pitch.sessionId)
                assertNotNull(session.phase7.continueOfficialPitch())
                assertEquals(leftoverHsWire, session.store.current.highSchool?.lastPresentation?.outcome)
                assertEquals(null, session.store.current.pro?.lastPresentation)
                assertEquals(null, session.store.current.pro?.lastBattedBall)
                assertEquals(null, session.store.current.pro?.lastFielding)
                assertEquals(null, PitchLiveResult.outcome(session.store.current))
                assertEquals(null, PitchLiveResult.battedBall(session.store.current))
                assertEquals(null, PitchLiveResult.fielding(session.store.current))
            }
            session.store.close()
        }
    }

    @Test
    fun newGameDefaultPitchInputIsSliderNotAutoRelease() {
        val initial = GameAggregateState.initial("slider-default")
        assertFalse(initial.settings.autoReleaseEnabled)
        assertFalse(GameSettingsState().autoReleaseEnabled)
    }

    @Test
    fun reviewSeasonOnFileStoreReloadsOffseasonTwice() = runBlocking {
        withTempDirectory { directory ->
            var session = openFileSession("phase8-review-save", directory)
            session.completeHighSchoolAndEnterPro()
            repeat(2) { index ->
                session.advanceProUntil(ProCareerPhase.SEASON_REVIEW)
                assertEquals(index + 1, session.store.current.pro?.season)
                session.executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                assertCodecRoundTrip(session.store.current, "after-review-$index")
                val expectedPhase = if (index + 1 >= ProCatalog.MAXIMUM_CAREER_SEASONS) {
                    ProCareerPhase.RETIREMENT_DECISION
                } else {
                    ProCareerPhase.OFFSEASON_DECISION
                }
                assertEquals(expectedPhase, session.store.current.pro?.phase)
                session = session.reopenAndAssert(expectedPhase, "review-$index")
                if (expectedPhase == ProCareerPhase.OFFSEASON_DECISION) {
                    session.executeFirst(Phase8ScreenId.P020_OFFSEASON, "offseason:continue")
                }
            }
            assertFalse(session.store.current.settings.autoReleaseEnabled)
            session.store.close()
        }
    }

    @Test
    fun fileStoreWalksLinkedCareerToSeasonTwentyRetirement() = runBlocking {
        withTempDirectory { directory ->
            var session = openFileSession("phase8-twenty-season", directory)
            session.completeHighSchoolAndEnterPro()
            while (true) {
                val season = requireNotNull(session.store.current.pro).season
                session.advanceProUntil(ProCareerPhase.SEASON_REVIEW)
                session.executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                val expectedPhase = if (season >= ProCatalog.MAXIMUM_CAREER_SEASONS) {
                    ProCareerPhase.RETIREMENT_DECISION
                } else {
                    ProCareerPhase.OFFSEASON_DECISION
                }
                assertEquals(expectedPhase, session.store.current.pro?.phase, "season $season review")
                session = session.reopenAndAssert(expectedPhase, "season-$season")
                if (expectedPhase == ProCareerPhase.RETIREMENT_DECISION) break
                session.executeFirst(Phase8ScreenId.P020_OFFSEASON, "offseason:continue")
            }
            assertEquals(ProCatalog.MAXIMUM_CAREER_SEASONS, session.store.current.pro?.season)
            assertEquals(ProCareerPhase.RETIREMENT_DECISION, session.store.current.pro?.phase)
            session.executeFirst(Phase8ScreenId.P021_PRO_RETIREMENT, "retire")
            assertTrue(
                session.store.current.pro?.phase == ProCareerPhase.LEGACY_SELECTION ||
                    session.store.current.pro?.phase == ProCareerPhase.COMPLETED,
            )
            if (session.store.current.pro?.phase == ProCareerPhase.LEGACY_SELECTION) {
                session.executeFirst(Phase8ScreenId.P022_PRO_LEGACY) { it.id.startsWith("selectProLegacy:") }
            }
            session = session.reopenAndAssert(ProCareerPhase.COMPLETED, "retired")
            assertEquals(ProCareerPhase.COMPLETED, session.store.current.pro?.phase)
            assertEquals(ProCatalog.MAXIMUM_CAREER_SEASONS, session.store.current.pro?.careerStats?.size)
            assertFalse(session.store.current.settings.autoReleaseEnabled)
            session.store.close()
        }
    }

    private suspend fun openFileSession(installId: String, directory: Path): CareerSession {
        val repository = FileShadowFixtureGameStoreRepository(directory)
        val store = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        return CareerSession(
            installId = installId,
            repository = repository,
            store = store,
            controller = Phase8Controller(store, context),
            phase7 = Phase7VerticalController(store, "phase8-ui"),
        )
    }

    private inner class CareerSession(
        val installId: String,
        val repository: FileShadowFixtureGameStoreRepository,
        var store: KotlinGameStore,
        var controller: Phase8Controller,
        var phase7: Phase7VerticalController,
    ) {
        suspend fun completeHighSchoolAndEnterPro() {
            assertFalse(store.current.settings.autoReleaseEnabled)
            executeFirst(Phase8ScreenId.P001_OPENING)
            executeFirst(Phase8ScreenId.P002_SETUP)
            executeFirst(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            executeFirst(Phase8ScreenId.P004_PITCH_TUTORIAL, "openTutorialPitch")
            finishTutorialPitch()
            executeFirst(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            executeFirst(Phase8ScreenId.P005_SCHOOL_SELECTION)
            advanceHighSchoolUntil(HighSchoolPhase.DRAFT)
            executeFirst(Phase8ScreenId.P013_DRAFT, "resolveDraft")
            if (store.current.highSchool?.run?.phase == HighSchoolPhase.LEGACY || store.current.highSchool?.run?.phase == HighSchoolPhase.COMPLETED) {
                executeFirst(Phase8ScreenId.P014_RUN_RECAP, "prepareLegacy")
            }
            executeFirst(Phase8ScreenId.P014_RUN_RECAP) { it.id.startsWith("selectLegacy:") }
            assertEquals(Phase8ScreenId.P015_REBIRTH, controller.preferredScreen())
            executeFirst(Phase8ScreenId.P015_REBIRTH, "finalizeArchive")
            executeFirst(Phase8ScreenId.P015_REBIRTH, "startLinked")
            executeFirst(Phase8ScreenId.P016_PRO_CONTRACT, "signContract")
            assertEquals(Phase8ScreenId.P017_PRO_WEEK, controller.preferredScreen())
            assertEquals(ProCareerPhase.WEEKLY_PLAN, store.current.pro?.phase)
            assertFalse(store.current.settings.autoReleaseEnabled)
        }

        suspend fun advanceProUntil(target: ProCareerPhase) {
            var guard = 0
            while (store.current.pro?.phase != target) {
                assertTrue(
                    ++guard < 8_000,
                    "pro walk did not reach $target; phase=${store.current.pro?.phase} season=${store.current.pro?.season} week=${store.current.pro?.week}",
                )
                when (store.current.pro?.phase) {
                    ProCareerPhase.CONTRACT_OFFER -> executeFirst(Phase8ScreenId.P016_PRO_CONTRACT, "signContract")
                    ProCareerPhase.WEEKLY_PLAN -> executeFirst(Phase8ScreenId.P017_PRO_WEEK, "proAdvanceSegment")
                    ProCareerPhase.SEASON_DECISION -> executeFirst(Phase8ScreenId.P019_PRO_SEASON) { it.id.startsWith("seasonDecision:") }
                    ProCareerPhase.IMPORTANT_GAME -> finishProImportantGame()
                    ProCareerPhase.SEASON_REVIEW -> if (target == ProCareerPhase.SEASON_REVIEW) return else executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                    ProCareerPhase.OFFSEASON_DECISION -> executeFirst(Phase8ScreenId.P020_OFFSEASON, "offseason:continue")
                    ProCareerPhase.RETIREMENT_DECISION -> executeFirst(Phase8ScreenId.P021_PRO_RETIREMENT, "retire")
                    ProCareerPhase.LEGACY_SELECTION -> executeFirst(Phase8ScreenId.P022_PRO_LEGACY) { it.id.startsWith("selectProLegacy:") }
                    ProCareerPhase.COMPLETED -> return
                    null -> error("pro walk missing pro state")
                }
            }
        }

        suspend fun reopenAndAssert(expectedPhase: ProCareerPhase, label: String): CareerSession {
            val loaded = repository.load()
            assertEquals(SaveLoadStatus.LOADED_CANONICAL, loaded.status, "$label load status")
            val payload = requireNotNull(loaded.envelope).payload
            assertEquals(expectedPhase, payload.pro?.phase, "$label loaded phase")
            assertCodecRoundTrip(payload, "loaded-$label")
            store.close()
            val next = KotlinGameStore.open(installId, repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
            assertEquals(expectedPhase, next.current.pro?.phase, "$label reopened phase")
            assertFalse(next.current.settings.autoReleaseEnabled)
            return CareerSession(installId, repository, next, Phase8Controller(next, context), Phase7VerticalController(next, "phase8-ui"))
        }

        suspend fun executeFirst(
            screen: Phase8ScreenId,
            actionId: String? = null,
            predicate: ((Phase8ActionModel) -> Boolean)? = null,
        ) {
            val model = controller.projection(screen)
            val action = model.actions.firstOrNull { it.enabled && (actionId == null || it.id == actionId) && (predicate?.invoke(it) ?: true) }
                ?: error(
                    "no enabled action ${actionId ?: "*"} on ${screen.wire}; phase=${store.current.pro?.phase} " +
                        "hs=${store.current.highSchool?.run?.phase} season=${store.current.pro?.season} " +
                        "actions=${model.actions.map { "${it.id}:${it.enabled}" }}",
                )
            try {
                controller.execute(screen, action.id, action.payloads)
            } catch (error: Exception) {
                diagnoseFailedAction(action, error)
            }
        }

        private fun diagnoseFailedAction(action: Phase8ActionModel, error: Exception): Nothing {
            var state = store.current
            for (payload in action.payloads) {
                val reduced = try {
                    GameStateReducer.dispatch(state, payload.envelope)
                } catch (reduce: Exception) {
                    throw AssertionError(
                        "reduce ${action.id} failed before save at season=${state.pro?.season} phase=${state.pro?.phase}: ${reduce.message}; save=${error.message}",
                        reduce,
                    )
                }
                if (!reduced.duplicate) {
                    try {
                        GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(reduced.state))
                    } catch (codec: Exception) {
                        throw AssertionError(
                            "codec after ${action.id} failed season=${reduced.state.pro?.season} phase=${reduced.state.pro?.phase} week=${reduced.state.pro?.week}: ${codec.message}",
                            codec,
                        )
                    }
                    state = reduced.state
                }
            }
            val detail = (error as? SaveRepositoryException)?.message ?: error.message
            throw AssertionError(
                "save after ${action.id} failed season=${store.current.pro?.season} phase=${store.current.pro?.phase} week=${store.current.pro?.week}: $detail",
                error,
            )
        }

        private suspend fun finishTutorialPitch() {
            val pitch = requireNotNull(store.current.pitch)
            val request = phase7.submitPitch(pitch.sessionId, 0, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(1_000, 1_000))
            phase7.consumePresentation(pitch.sessionId, request)
            phase7.completePitchAndPostgame(pitch.sessionId)
            assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
        }

        private suspend fun advanceHighSchoolUntil(target: HighSchoolPhase) {
            var guard = 0
            while (store.current.highSchool?.run?.phase != target) {
                assertTrue(++guard < 260, "high-school fixture did not reach $target; phase=${store.current.highSchool?.run?.phase}")
                when (store.current.highSchool?.run?.phase) {
                    HighSchoolPhase.SCHOOL_SELECTION -> executeFirst(Phase8ScreenId.P005_SCHOOL_SELECTION)
                    HighSchoolPhase.TRAINING -> executeFirst(Phase8ScreenId.P006_TRAINING)
                    HighSchoolPhase.RELATIONSHIP -> executeFirst(Phase8ScreenId.P007_RELATIONSHIP)
                    HighSchoolPhase.IMPORTANT_GAME -> finishHighSchoolImportantGame()
                    HighSchoolPhase.AWAKENING -> executeFirst(Phase8ScreenId.P009_AWAKENING)
                    HighSchoolPhase.CHAPTER_REVIEW -> executeFirst(Phase8ScreenId.P010_CHAPTER)
                    HighSchoolPhase.PROLOGUE -> executeFirst(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
                    else -> error("unexpected high-school fixture phase ${store.current.highSchool?.run?.phase}")
                }
            }
        }

        private suspend fun finishHighSchoolImportantGame() {
            var firstPitch = true
            var pitchCount = 0
            while (firstPitch || store.current.highSchool?.activePitch != null) {
                val boundary = store.current.pitch?.boundary
                if (boundary == null || boundary == PitchBoundary.COMPLETED || boundary == PitchBoundary.ABANDONED) {
                    executeFirst(Phase8ScreenId.P008_IMPORTANT_GAME, if (firstPitch) "openImportantGame" else "nextImportantPitch")
                    firstPitch = false
                }
                val pitch = requireNotNull(store.current.pitch)
                val request = phase7.submitPitch(pitch.sessionId, pitchCount % 4, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(1_000, 1_000))
                phase7.consumePresentation(pitch.sessionId, request)
                phase7.completePitchAndPostgame(pitch.sessionId)
                pitchCount += 1
                assertTrue(pitchCount < 80, "important game fixture did not terminate")
            }
        }

        private suspend fun finishProImportantGame() {
            var pitchCount = 0
            while (store.current.pro?.phase == ProCareerPhase.IMPORTANT_GAME) {
                assertTrue(++pitchCount < 200, "pro important game did not terminate")
                val model = controller.projection(Phase8ScreenId.P018_PRO_IMPORTANT_GAME)
                when {
                    model.actions.any { it.id == "openProImportantGame" && it.enabled } ->
                        executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "openProImportantGame")
                    model.actions.any { it.id == "nextProPitch" && it.enabled } ->
                        executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "nextProPitch")
                    model.actions.any { it.id == "finishProGame" && it.enabled } && store.current.pro?.activePitch?.ended == true ->
                        executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "finishProGame")
                    store.current.pitch?.boundary == PitchBoundary.PLAYING -> throwCurrentPitch()
                    else -> error(
                        "stuck pro important game boundary=${store.current.pitch?.boundary} ended=${store.current.pro?.activePitch?.ended} " +
                            "actions=${model.actions.map { "${it.id}:${it.enabled}" }}",
                    )
                }
            }
        }

        private suspend fun throwCurrentPitch() {
            val pitch = requireNotNull(store.current.pitch)
            val request = phase7.submitPitch(pitch.sessionId, pitch.pitchIndex % 4, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(1_000, 1_000))
            phase7.consumePresentation(pitch.sessionId, request)
            if (store.current.pro?.activePitch?.ended != true) {
                phase7.completePitchAndPostgame(pitch.sessionId)
            }
        }
    }

    private fun assertCodecRoundTrip(state: GameAggregateState, label: String) {
        val decoded = try {
            GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(state))
        } catch (error: Exception) {
            throw AssertionError(
                "$label codec failed revision=${state.revision} season=${state.pro?.season} phase=${state.pro?.phase}: ${error.message}",
                error,
            )
        }
        assertEquals(state.commitment, decoded.commitment, "$label commitment")
        assertEquals(state.pro?.phase, decoded.pro?.phase, "$label phase")
        assertFalse(decoded.settings.autoReleaseEnabled, "$label auto-release")
    }

    private suspend fun withTempDirectory(block: suspend (Path) -> Unit) {
        val directory = Files.createTempDirectory("baseball-phase8-career-")
        try {
            block(directory)
        } finally {
            Files.walk(directory).use { stream ->
                stream.sorted(Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
            }
        }
    }
}
