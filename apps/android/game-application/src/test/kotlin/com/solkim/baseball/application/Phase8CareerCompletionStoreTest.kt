package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProCommand
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
    fun newDirectCareerUsesRulesVersion11AndReviewSeasonRoundTripsOnFileStore() = runBlocking {
        withTempDirectory { directory ->
            var session = openFileSession("phase8-v10-direct-review", directory)
            session.executeFirst(Phase8ScreenId.P016_PRO_CONTRACT, "startDirect")
            assertEquals(11, session.store.current.pro?.proRulesVersion)
            assertEquals(ProCatalog.RULES_VERSION, session.store.current.pro?.proRulesVersion)
            assertFalse(session.store.current.settings.autoReleaseEnabled)
            session.advanceProUntil(ProCareerPhase.SEASON_REVIEW)
            session.executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
            session.finishSettlementIfOpen()
            session.finishNationalTeamIfOpen()
            session = session.reopenAndAssert(ProCareerPhase.OFFSEASON_DECISION, "v10-direct-review")
            assertEquals(11, session.store.current.pro?.proRulesVersion)
            assertEquals(ProCareerPhase.OFFSEASON_DECISION, session.store.current.pro?.phase)
            session.store.close()
        }
    }

    @Test
    fun reviewSeasonOnFileStoreReloadsOffseasonTwice() = runBlocking {
        withTempDirectory { directory ->
            var session = openFileSession("phase8-review-save", directory)
            session.completeHighSchoolAndEnterPro()
            assertEquals(11, session.store.current.pro?.proRulesVersion)
            assertEquals(ProCatalog.RULES_VERSION, session.store.current.pro?.proRulesVersion)
            repeat(2) { index ->
                session.advanceProUntil(ProCareerPhase.SEASON_REVIEW)
                assertEquals(index + 1, session.store.current.pro?.season)
                session.executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                session.finishSettlementIfOpen()
                session.finishNationalTeamIfOpen()
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
                    session.finishInvestmentIfOpen()
                }
            }
            assertFalse(session.store.current.settings.autoReleaseEnabled)
            session.store.close()
        }
    }

    @Test
    fun nativeFileStoreWalksLinkedCareerToSeasonTwentyRetirement() = runBlocking {
        withTempDirectory { directory ->
            var session = openFileSession("phase8-twenty-season", directory, native = true)
            session.completeHighSchoolAndEnterPro()
            while (true) {
                val season = requireNotNull(session.store.current.pro).season
                session.advanceProUntil(ProCareerPhase.SEASON_REVIEW)
                session.executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                session.finishSettlementIfOpen()
                session.finishNationalTeamIfOpen()
                val expectedPhase = if (season >= ProCatalog.MAXIMUM_CAREER_SEASONS) {
                    ProCareerPhase.RETIREMENT_DECISION
                } else {
                    ProCareerPhase.OFFSEASON_DECISION
                }
                assertEquals(expectedPhase, session.store.current.pro?.phase, "season $season review")
                session = session.reopenAndAssert(expectedPhase, "season-$season")
                if (expectedPhase == ProCareerPhase.RETIREMENT_DECISION) break
                session.executeFirst(Phase8ScreenId.P020_OFFSEASON, "offseason:continue")
                session.finishInvestmentIfOpen()
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
            val retired = requireNotNull(session.store.current.pro)
            val archived = session.store.current.meta.retiredProCareers.single()
            assertEquals(retired, archived.copy(commandReceipts = retired.commandReceipts, commitment = retired.commitment))
            val oldLife = requireNotNull(session.store.current.highSchool).run.lifeNumber
            val beforePreview = session.store.current
            val quick = session.controller.projection(Phase8ScreenId.P015_REBIRTH).actions.single { it.id == "quickRebirth" }
            val preview = assertNotNull(RebirthStartPreview.resolve(beforePreview, quick))
            assertEquals(preview, RebirthStartPreview.resolve(beforePreview, quick))
            assertEquals(beforePreview, session.store.current, "Preview must not spend soul or advance the saved RNG")
            session.controller.execute(Phase8ScreenId.P015_REBIRTH, quick.id, quick.payloads)
            val reborn = requireNotNull(session.store.current.highSchool).startingPitcher
            assertEquals(preview.next, listOf(reborn.stuff, reborn.command, reborn.movement, reborn.stamina))
            assertEquals(preview.nextLife, session.store.current.highSchool?.run?.lifeNumber)
            assertEquals(oldLife + 1, session.store.current.highSchool?.run?.lifeNumber)
            assertEquals(Phase8ScreenId.P003_PROLOGUE, Phase8ScreenProjection.preferredScreen(session.store.current))
            session = session.reopenAndAssert(ProCareerPhase.COMPLETED, "reborn-after-pro")
            assertTrue(session.controller.projection(Phase8ScreenId.P016_PRO_CONTRACT).actions.none { it.id == "startDirect" },
                "A reborn high-school player must not jump into an unrelated new pro career")
            assertEquals(ProCareerPhase.COMPLETED, session.store.current.pro?.phase)
            assertEquals(retired.careerId, session.store.current.pro?.careerId)
            assertEquals(archived, session.store.current.meta.retiredProCareers.single())
            session.store.close()
        }
    }

    @Test fun returningPlayerCanStartImmediatelyOrPracticeOnceWithoutCareerRewards() = runBlocking {
        for (practice in listOf(false, true)) withTempDirectory { directory ->
            val id = "return-ready-$practice"
            val session = openFileSession(id, directory, native = true)
            try {
                session.completeHighSchoolAndEnterPro(enterPro = false)
                session.executeFirst(Phase8ScreenId.P015_REBIRTH, "quickRebirth")
                val before = session.store.current
                val hs = requireNotNull(before.highSchool)
                assertEquals(2, hs.run.lifeNumber)
                assertFalse(before.settings.autoReleaseEnabled)
                val actions = session.controller.projection(Phase8ScreenId.P003_PROLOGUE).actions
                assertTrue(actions.single { it.id == "completeTutorial" }.enabled)
                assertTrue(actions.single { it.id == "openTutorialPitch" }.enabled)
                if (practice) {
                    val launch = session.controller.execute(Phase8ScreenId.P003_PROLOGUE, "openTutorialPitch")
                    assertNotNull(launch.launch)
                    assertEquals(hs.run.pitcher.command, PitchHudProjection.pitcher(session.store.current).command)
                    assertEquals(0, PitchHudProjection.fatigue(session.store.current))
                    assertTrue(PitchHudProjection.scenarioDetail(session.store.current).contains("기록에 안 남는"))
                    session.finishTutorialPitch()
                    assertEquals(hs.run.pitcher, session.store.current.highSchool?.run?.pitcher)
                    assertEquals(hs.run.performance, session.store.current.highSchool?.run?.performance)
                    assertEquals(before.meta.completedGameCount, session.store.current.meta.completedGameCount)
                }
                session.executeFirst(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
                val after = session.store.current
                assertEquals(HighSchoolPhase.SCHOOL_SELECTION, after.highSchool?.run?.phase)
                assertEquals(hs.run.pitcher, after.highSchool?.run?.pitcher)
                assertEquals(hs.archive, after.highSchool?.archive)
                assertEquals(hs.inheritance, after.highSchool?.inheritance)
                val reopened = KotlinGameStore.open(id, session.repository, session.mode)
                try { assertEquals(after, reopened.current) } finally { reopened.close() }
            } finally { session.store.close() }
        }
    }

    private suspend fun openFileSession(installId: String, directory: Path, native: Boolean = false): CareerSession {
        val repository: GameStoreRepository = if (native) CSharpLegacyGameStoreRepository(directory, installId) else FileShadowFixtureGameStoreRepository(directory)
        val mode = if (native) NativeAuthorityMode.NATIVE_AUTHORITATIVE else NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY
        val store = KotlinGameStore.open(installId, repository, mode)
        return CareerSession(
            installId = installId,
            repository = repository,
            store = store,
            controller = Phase8Controller(store, context),
            phase7 = Phase7VerticalController(store, "phase8-ui"),
            mode = mode,
        )
    }

    private inner class CareerSession(
        val installId: String,
        val repository: GameStoreRepository,
        var store: KotlinGameStore,
        var controller: Phase8Controller,
        var phase7: Phase7VerticalController,
        val mode: NativeAuthorityMode,
    ) {
        suspend fun completeHighSchoolAndEnterPro(enterPro: Boolean = true) {
            assertFalse(store.current.settings.autoReleaseEnabled)
            executeFirst(Phase8ScreenId.P001_OPENING)
            // Persistence coverage uses a supported relaxed commander build to earn the draft;
            // an undrafted player must never be promoted by an unconditional link shortcut.
            val setup = Phase8Payloads.startHighSchool(store.current, "민서준", "서울", "precision_commander", context,
                difficulty = com.solkim.baseball.core.highschool.HighSchoolDifficulty(careerHarshness = "relaxed"),
                primaryPitch = PitchKind.FOUR_SEAM, learningPitch = PitchKind.CHANGEUP)
            val creation = setup as GameCommand.HighSchool
            val configured = creation.command as com.solkim.baseball.core.highschool.HighSchoolPhase4Command.StartConfigured
            val seeded = creation.copy(command = configured.copy(request = configured.request.copy(seed = "1161071901006642942")))
            store.dispatch(GameCommandEnvelope("drafted-fixture-start", "phase8-ui", store.current.revision, seeded))
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
            val earnedSchool = requireNotNull(store.current.highSchool)
            val earnedDraft = requireNotNull(earnedSchool.run.draftResult)
            assertEquals("drafted", earnedDraft.outcome.wire)
            if (!enterPro) return
            executeFirst(Phase8ScreenId.P015_REBIRTH, "startLinked")
            val linked = requireNotNull(store.current.pro)
            assertEquals(earnedDraft.teamId, linked.team.id)
            val rookie = requireNotNull(linked.journeyState?.pendingContractMarket).offers.single()
            assertEquals(earnedDraft.signingBonus?.toLong(), rookie.signingBonus)
            assertEquals(earnedSchool.startingPitcher.command, linked.highSchoolLegacyContext?.startingPitcher?.command)
            assertEquals(earnedSchool.run.pitcher.effectiveMastery.command, linked.pitcher.effectiveMastery.command)
            executeFirst(Phase8ScreenId.P016_PRO_CONTRACT) { it.id.startsWith("acceptOffer:") || it.id == "signContract" }
            assertEquals(Phase8ScreenId.P017_PRO_WEEK, controller.preferredScreen())
            assertEquals(ProCareerPhase.WEEKLY_PLAN, store.current.pro?.phase)
            assertFalse(store.current.settings.autoReleaseEnabled)
        }

        suspend fun finishSettlementIfOpen() {
            if (store.current.pro?.phase != ProCareerPhase.SEASON_SETTLEMENT) return
            executeFirst(Phase8ScreenId.P019_PRO_SEASON, "acknowledgeSettlement")
        }

        suspend fun finishInvestmentIfOpen() {
            if (store.current.pro?.phase != ProCareerPhase.OFFSEASON_INVESTMENT) return
            executeFirst(Phase8ScreenId.P020_OFFSEASON, "investment:none")
        }

        suspend fun finishNationalTeamIfOpen() {
            var guard = 0
            while (true) {
                assertTrue(++guard < 8, "national team did not drain; phase=${store.current.pro?.phase}")
                when (store.current.pro?.phase) {
                    ProCareerPhase.NATIONAL_TEAM_CALL -> executeFirst(Phase8ScreenId.P019_PRO_SEASON, "nationalTeam:accept")
                    ProCareerPhase.NATIONAL_TOURNAMENT -> {
                        val tournament = store.current.pro?.nationalTournament
                        if (tournament?.result != null) {
                            executeFirst(Phase8ScreenId.P019_PRO_SEASON, "nationalTeam:acknowledge")
                        } else {
                            resolveNationalFinalAutomatically()
                        }
                    }
                    else -> return
                }
            }
        }

        suspend fun resolveNationalFinalAutomatically() {
            val seed = context.seed(store.current, "national-team:auto-final")
            store.dispatch(
                GameCommandEnvelope(
                    commandId = "national-auto-final-${store.current.revision}",
                    sessionId = "phase8-ui",
                    expectedRevision = store.current.revision,
                    command = GameCommand.Pro(ProCommand.ResolveNationalFinalAutomatically(seed)),
                ),
            )
        }

        suspend fun advanceProUntil(target: ProCareerPhase) {
            var guard = 0
            while (store.current.pro?.phase != target) {
                assertTrue(
                    ++guard < 8_000,
                    "pro walk did not reach $target; phase=${store.current.pro?.phase} season=${store.current.pro?.season} week=${store.current.pro?.week}",
                )
                when (store.current.pro?.phase) {
                    ProCareerPhase.CONTRACT_OFFER -> {
                        val model = controller.projection(Phase8ScreenId.P016_PRO_CONTRACT)
                        val accept = model.actions.firstOrNull { it.id.startsWith("acceptOffer:") && it.enabled }
                        if (accept != null) executeFirst(Phase8ScreenId.P016_PRO_CONTRACT, accept.id)
                        else executeFirst(Phase8ScreenId.P016_PRO_CONTRACT, "signContract")
                    }
                    ProCareerPhase.WEEKLY_PLAN -> executeFirst(Phase8ScreenId.P017_PRO_WEEK, "proAdvanceSegment")
                    ProCareerPhase.SEASON_DECISION -> executeFirst(Phase8ScreenId.P019_PRO_SEASON) { it.id.startsWith("seasonDecision:") }
                    ProCareerPhase.SEASON_SETTLEMENT -> executeFirst(Phase8ScreenId.P019_PRO_SEASON, "acknowledgeSettlement")
                    ProCareerPhase.NATIONAL_TEAM_CALL -> executeFirst(Phase8ScreenId.P019_PRO_SEASON, "nationalTeam:accept")
                    ProCareerPhase.NATIONAL_TOURNAMENT -> {
                        val tournament = store.current.pro?.nationalTournament
                        if (tournament?.result != null) {
                            executeFirst(Phase8ScreenId.P019_PRO_SEASON, "nationalTeam:acknowledge")
                        } else {
                            resolveNationalFinalAutomatically()
                        }
                    }
                    ProCareerPhase.IMPORTANT_GAME -> finishProImportantGame()
                    ProCareerPhase.SEASON_REVIEW -> if (target == ProCareerPhase.SEASON_REVIEW) return else executeFirst(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                    ProCareerPhase.OFFSEASON_DECISION -> executeFirst(Phase8ScreenId.P020_OFFSEASON, "offseason:continue")
                    ProCareerPhase.OFFSEASON_INVESTMENT -> executeFirst(Phase8ScreenId.P020_OFFSEASON, "investment:none")
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
            if (mode == NativeAuthorityMode.NATIVE_AUTHORITATIVE) {
                // Native payloads carry the C# receipt/signature format, not the shadow
                // aggregate receipt chain. The production repository validates that wire.
                assertEquals(store.current, payload, "$label native save must preserve the complete projection")
            } else assertCodecRoundTrip(payload, "loaded-$label")
            store.close()
            val next = KotlinGameStore.open(installId, repository, mode)
            assertEquals(payload, next.current, "$label reopen must preserve the entire state")
            assertEquals(expectedPhase, next.current.pro?.phase, "$label reopened phase")
            assertFalse(next.current.settings.autoReleaseEnabled)
            return CareerSession(installId, repository, next, Phase8Controller(next, context), Phase7VerticalController(next, "phase8-ui"), mode)
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
                        "hs=${store.current.highSchool?.run?.phase} draft=${store.current.highSchool?.run?.draftResult?.outcome}/${store.current.highSchool?.run?.draftResult?.evaluationScore} season=${store.current.pro?.season} " +
                        "actions=${model.actions.map { "${it.id}:${it.enabled}" }}",
                )
            try {
                controller.execute(screen, action.id, action.payloads)
            } catch (error: Exception) {
                diagnoseFailedAction(action, error)
            }
        }

        private fun diagnoseFailedAction(action: Phase8ActionModel, error: Exception): Nothing {
            if (mode == NativeAuthorityMode.NATIVE_AUTHORITATIVE) {
                throw AssertionError("Native action ${action.id} failed at season=${store.current.pro?.season}, phase=${store.current.pro?.phase}", error)
            }
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

        suspend fun finishTutorialPitch() {
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
            val completedBefore = store.current.meta.completedGameCount
            var firstPitch = true
            var pitchCount = 0
            while (firstPitch || store.current.highSchool?.activePitch != null) {
                val boundary = store.current.pitch?.boundary
                if (boundary == null || boundary == PitchBoundary.COMPLETED || boundary == PitchBoundary.ABANDONED) {
                    executeFirst(Phase8ScreenId.P008_IMPORTANT_GAME, if (firstPitch) "openImportantGame" else "nextImportantPitch")
                    firstPitch = false
                }
                val pitch = requireNotNull(store.current.pitch)
                val request = phase7.submitPitch(pitch.sessionId, PitchHudSelection.Primary, PitchDelivery(1_000, 1_000))
                phase7.consumePresentation(pitch.sessionId, request)
                phase7.completePitchAndPostgame(pitch.sessionId)
                pitchCount += 1
                assertTrue(pitchCount < 80, "important game fixture did not terminate")
            }
            assertEquals(completedBefore + 1UL, store.current.meta.completedGameCount, "One HS game counts once, including after a pro career")
        }

        private suspend fun finishProImportantGame() {
            val completedBefore = store.current.meta.completedGameCount
            var completedGames = 0UL
            var pitchCount = 0
            while (store.current.pro?.phase == ProCareerPhase.IMPORTANT_GAME) {
                assertTrue(++pitchCount < 200, "pro important game did not terminate")
                val model = controller.projection(Phase8ScreenId.P018_PRO_IMPORTANT_GAME)
                when {
                    model.actions.any { it.id == "openProImportantGame" && it.enabled } ->
                        executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "openProImportantGame")
                    model.actions.any { it.id == "nextProPitch" && it.enabled } ->
                        executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "nextProPitch")
                    model.actions.any { it.id == "finishProGame" && it.enabled } && store.current.pro?.activePitch?.ended == true -> {
                        executeFirst(Phase8ScreenId.P018_PRO_IMPORTANT_GAME, "finishProGame")
                        completedGames += 1UL
                    }
                    store.current.pitch?.boundary == PitchBoundary.PLAYING -> throwCurrentPitch()
                    else -> error(
                        "stuck pro important game boundary=${store.current.pitch?.boundary} ended=${store.current.pro?.activePitch?.ended} " +
                            "actions=${model.actions.map { "${it.id}:${it.enabled}" }}",
                    )
                }
                assertEquals(completedBefore + completedGames, store.current.meta.completedGameCount, "Only completed games count; a postseason win can immediately open another important game")
            }
            assertTrue(completedGames > 0UL)
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
