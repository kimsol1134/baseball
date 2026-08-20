package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProEntitlement
import com.solkim.baseball.core.pro.ProHighSchoolLegacyContext
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProLegacyCandidate
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.highschool.HighSchoolPerformance
import com.solkim.baseball.core.highschool.HighSchoolNextRunIntent
import com.solkim.baseball.core.highschool.HighSchoolPledgeRules
import kotlinx.coroutines.runBlocking
import java.time.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** Phase 8 coverage uses reachable, signed aggregate fixtures instead of an invalid matrix seed. */
class Phase8ScreenProjectionTest {
    private val context = Phase8CommandContext(Phase8KoreaClock { LocalDate.of(2026, 8, 14) })

    @Test
    fun productCoverageExcludesRetiredDailyAndFailsClosedForOffStateScreens() {
        val initial = GameAggregateState.initial("phase8-contract")
        assertEquals(29, Phase8ScreenId.ordered.size)
        assertFalse(Phase8ScreenId.ordered.any { it.wire == "P-023" })
        assertEquals(Phase8ScreenId.P001_OPENING, Phase8ScreenProjection.normalizeLegacyRoute("daily", initial))
        assertEquals(Phase8ScreenId.P001_OPENING, Phase8ScreenProjection.normalizeLegacyRoute("P-023", initial))
        assertEquals(Phase8ScreenId.P001_OPENING, Phase8ScreenProjection.normalizeLegacyRoute("daily_inning", initial))
        assertFailsWith<IllegalArgumentException> {
            Phase8ScreenProjection.project(initial, Phase8ScreenId.P005_SCHOOL_SELECTION, context)
        }
        assertEquals(Phase8ScreenId.P001_OPENING, Phase8ScreenProjection.preferredScreen(initial))
    }

    @Test
    fun realHighSchoolJourneyProjectsEveryHighSchoolAndMetaScreenWithCapturedCommands() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("phase8-high-school"))
        val controller = Phase8Controller(store, context)
        val covered = linkedMapOf<Phase8ScreenId, Phase8ScreenModel>()

        fun capture(id: Phase8ScreenId) {
            assertTrue(
                Phase8ScreenProjection.isReachable(store.current, id),
                "${id.wire} not reachable at phase=${store.current.highSchool?.run?.phase}, pitch=${store.current.pitch?.careerKind}/${store.current.pitch?.boundary}",
            )
            val model = controller.projection(id)
            Phase8AccessibilityContract.validate(model)
            assertEquals(
                model.viewPayload.envelope,
                GameCommandCodec.decode(model.viewPayload.encoded),
                "view payload must remain an exact typed command for ${id.wire}",
            )
            covered[id] = model
            model.actions.filter { it.enabled }.forEach { action ->
                assertTrue(action.payloads.isNotEmpty(), "enabled action has no captured payload: ${id.wire}/${action.id}")
                action.payloads.forEach { payload ->
                    assertEquals(payload.envelope, GameCommandCodec.decode(payload.encoded))
                }
            }
        }

        capture(Phase8ScreenId.P001_OPENING)
        executeFirst(controller, Phase8ScreenId.P001_OPENING)
        capture(Phase8ScreenId.P002_SETUP)
        executeFirst(controller, Phase8ScreenId.P002_SETUP)
        capture(Phase8ScreenId.P003_PROLOGUE)
        executeFirst(controller, Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
        capture(Phase8ScreenId.P004_PITCH_TUTORIAL)
        executeFirst(controller, Phase8ScreenId.P004_PITCH_TUTORIAL, "openTutorialPitch")
        finishTutorialPitch(store)
        executeFirst(controller, Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
        assertEquals(0UL, store.current.meta.completedGameCount, "non-challenge tutorial completion must not count as an official game")
        assertEquals(1, store.current.analytics.receipts.count { it.eventName == "first_pitch" })
        capture(Phase8ScreenId.P005_SCHOOL_SELECTION)
        executeFirst(controller, Phase8ScreenId.P005_SCHOOL_SELECTION)

        // The first meaningful aggregate state makes all read-only career/meta destinations
        // reachable; they are projected here before the vertical advances further.
        listOf(
            Phase8ScreenId.P011_HIGH_SCHOOL_CAREER,
            Phase8ScreenId.P012_TOURNAMENT_LEAGUE,
            Phase8ScreenId.P024_WEEKLY,
            Phase8ScreenId.P025_RECORDS_LEAGUE,
            Phase8ScreenId.P026_ACHIEVEMENTS,
            Phase8ScreenId.P027_SETTINGS,
            Phase8ScreenId.P028_LIFECARD,
            Phase8ScreenId.P029_RETURN_PLAN,
            Phase8ScreenId.P016_PRO_CONTRACT,
        ).forEach(::capture)

        val phase7 = Phase7VerticalController(store, "phase8-ui")
        capture(Phase8ScreenId.P006_TRAINING)
        while (store.current.highSchool?.run?.phase == HighSchoolPhase.TRAINING) {
            executeFirst(controller, Phase8ScreenId.P006_TRAINING)
        }
        capture(Phase8ScreenId.P007_RELATIONSHIP)
        executeFirst(controller, Phase8ScreenId.P007_RELATIONSHIP)
        advanceHighSchoolUntil(store, controller, phase7, HighSchoolPhase.AWAKENING) {
            capture(Phase8ScreenId.P008_IMPORTANT_GAME)
        }
        capture(Phase8ScreenId.P009_AWAKENING)
        executeFirst(controller, Phase8ScreenId.P009_AWAKENING)
        advanceHighSchoolUntil(store, controller, phase7, HighSchoolPhase.CHAPTER_REVIEW)
        capture(Phase8ScreenId.P010_CHAPTER)
        executeFirst(controller, Phase8ScreenId.P010_CHAPTER)
        advanceHighSchoolUntil(store, controller, phase7, HighSchoolPhase.DRAFT)

        capture(Phase8ScreenId.P013_DRAFT)
        executeFirst(controller, Phase8ScreenId.P013_DRAFT, "resolveDraft")
        assertNotNull(store.current.highSchool?.run?.draftResult)
        capture(Phase8ScreenId.P030_REVIEW)
        assertTrue(controller.projection(Phase8ScreenId.P030_REVIEW).actions.isEmpty())

        if (store.current.highSchool?.run?.phase == HighSchoolPhase.LEGACY || store.current.highSchool?.run?.phase == HighSchoolPhase.COMPLETED) {
            executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP, "prepareLegacy")
        }
        capture(Phase8ScreenId.P014_RUN_RECAP)
        // A draft result alone is not a review caller. The exact rendered confirmation CTA must
        // commit its durable moment receipt before P030 exposes a native review reason.
        assertEquals(null, Phase8ScreenProjection.reviewTrigger(store.current))
        val reviewModel = controller.projection(Phase8ScreenId.P014_RUN_RECAP)
        val reviewMoment = reviewModel.actions.firstOrNull { it.id == "confirmDraftResult" || it.id == "confirmRecap" }
        if (reviewMoment != null) {
            executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP, reviewMoment.id)
            val expectedReview = if (reviewMoment.id == "confirmDraftResult") "drafted-reveal-confirmed" else "good-recap"
            assertEquals(expectedReview, Phase8ScreenProjection.reviewTrigger(store.current))
        }
        executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP) { it.id.startsWith("selectLegacy:") }
        capture(Phase8ScreenId.P014_RUN_RECAP)
        executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP, "finalizeArchive")
        capture(Phase8ScreenId.P015_REBIRTH)
        val frozen = requireNotNull(Phase9LifeCardProjection.selected(store.current))
        val archived = requireNotNull(store.current.highSchool?.archive?.lastOrNull())
        assertTrue(frozen.lines.any { it.contains(archived.playerName) })
        assertTrue(frozen.lines.any { it.contains(archived.importantGames.toString()) })
        assertTrue(frozen.lines.any { it.contains(archived.pitches.toString()) })
        assertTrue(frozen.lines.any { it.contains(archived.selectedSignatureLegacyId ?: "선택 없음") })
        assertTrue(frozen.text.contains(archived.soulEarned.toString()))

        val expected = setOf(
            Phase8ScreenId.P001_OPENING,
            Phase8ScreenId.P002_SETUP,
            Phase8ScreenId.P003_PROLOGUE,
            Phase8ScreenId.P004_PITCH_TUTORIAL,
            Phase8ScreenId.P005_SCHOOL_SELECTION,
            Phase8ScreenId.P006_TRAINING,
            Phase8ScreenId.P007_RELATIONSHIP,
            Phase8ScreenId.P008_IMPORTANT_GAME,
            Phase8ScreenId.P009_AWAKENING,
            Phase8ScreenId.P010_CHAPTER,
            Phase8ScreenId.P011_HIGH_SCHOOL_CAREER,
            Phase8ScreenId.P012_TOURNAMENT_LEAGUE,
            Phase8ScreenId.P013_DRAFT,
            Phase8ScreenId.P014_RUN_RECAP,
            Phase8ScreenId.P015_REBIRTH,
            Phase8ScreenId.P016_PRO_CONTRACT,
            Phase8ScreenId.P024_WEEKLY,
            Phase8ScreenId.P025_RECORDS_LEAGUE,
            Phase8ScreenId.P026_ACHIEVEMENTS,
            Phase8ScreenId.P027_SETTINGS,
            Phase8ScreenId.P028_LIFECARD,
            Phase8ScreenId.P029_RETURN_PLAN,
            Phase8ScreenId.P030_REVIEW,
        )
        assertTrue(expected.all { it in covered }, "missing valid high-school coverage: ${expected - covered.keys}")
        assertTrue(store.current.meta.completedGameCount > 0UL, "the later official important game should count once")
    }

    @Test
    fun realProFixturesCoverContractWeekImportantSeasonOffseasonRetirementLegacyAndRecords() = runBlocking {
        val initialStore = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("phase8-pro-actions"))
        val controller = Phase8Controller(initialStore, context)
        val contract = controller.projection(Phase8ScreenId.P016_PRO_CONTRACT)
        assertTrue(contract.actions.single { it.id == "startDirect" }.payloads.isNotEmpty())
        controller.execute(Phase8ScreenId.P016_PRO_CONTRACT, "startDirect", contract.actions.single { it.id == "startDirect" }.payloads)
        assertEquals(Phase8ScreenId.P017_PRO_WEEK, controller.preferredScreen())
        val weekly = controller.projection(Phase8ScreenId.P017_PRO_WEEK)
        assertEquals(6, weekly.actions.count { it.id.startsWith("proPlan:") })
        weekly.actions.filter { it.enabled }.flatMap { it.payloads }.forEach { payload ->
            assertEquals(payload.envelope, GameCommandCodec.decode(payload.encoded))
        }

        val kernel = ProKernel()
        val base = requireNotNull(initialStore.current.pro)
        val fixtures = mapOf(
            Phase8ScreenId.P018_PRO_IMPORTANT_GAME to signedPro(kernel, base.copy(phase = ProCareerPhase.IMPORTANT_GAME)),
            Phase8ScreenId.P019_PRO_SEASON to signedPro(kernel, base.copy(phase = ProCareerPhase.SEASON_REVIEW)),
            Phase8ScreenId.P020_OFFSEASON to signedPro(kernel, base.copy(phase = ProCareerPhase.OFFSEASON_DECISION)),
            Phase8ScreenId.P021_PRO_RETIREMENT to signedPro(kernel, base.copy(phase = ProCareerPhase.RETIREMENT_DECISION)),
            Phase8ScreenId.P022_PRO_LEGACY to linkedLegacyFixture(kernel),
        )
        fixtures.forEach { (id, pro) ->
            val state = aggregateWithPro("fixture-${id.wire}", pro)
            assertTrue(Phase8ScreenProjection.isReachable(state, id), "${id.wire} fixture is unreachable")
            val model = Phase8ScreenProjection.project(state, id, context)
            Phase8AccessibilityContract.validate(model)
            model.actions.filter { it.enabled }.forEach { action ->
                assertTrue(action.payloads.isNotEmpty(), "enabled Pro action has no payload: ${id.wire}/${action.id}")
                action.payloads.forEach { payload ->
                    assertEquals(payload.envelope, GameCommandCodec.decode(payload.encoded))
                }
            }
        }

        val records = Phase8ScreenProjection.project(
            aggregateWithPro("fixture-records", signedPro(kernel, base.copy(phase = ProCareerPhase.COMPLETED))),
            Phase8ScreenId.P025_RECORDS_LEAGUE,
            context,
        )
        Phase8AccessibilityContract.validate(records)
    }

    @Test
    fun preferredRouteRestartDuplicateAndStaleBoundariesUseCommittedState() = runBlocking {
        val repository = InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("phase8-restart"))
        var store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("phase8-restart"), repository)
        var controller = Phase8Controller(store, context)
        val opening = controller.projection(Phase8ScreenId.P001_OPENING)
        val enter = opening.actions.single { it.id == "enterSetup" }
        val captured = enter.payloads
        controller.execute(Phase8ScreenId.P001_OPENING, enter.id, captured)
        assertEquals(Phase8ScreenId.P002_SETUP, controller.preferredScreen())

        store.close()
        store = KotlinGameStore.open("phase8-restart", repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        controller = Phase8Controller(store, context)
        assertEquals(Phase8ScreenId.P002_SETUP, controller.preferredScreen())
        val start = controller.projection(Phase8ScreenId.P002_SETUP).actions.single { it.id == "startHighSchool" }
        val startPayload = start.payloads.single()
        controller.execute(Phase8ScreenId.P002_SETUP, start.id, start.payloads)
        val duplicate = store.dispatch(startPayload.envelope)
        assertTrue(duplicate.duplicate)
        assertEquals(Phase8ScreenId.P003_PROLOGUE, controller.preferredScreen())
        assertFailsWith<GameCommandException> {
            store.dispatch(startPayload.envelope.copy(commandId = "stale-after-restart"))
        }
        assertEquals(2UL, store.current.revision)
    }

    @Test
    fun executableQuickAndCustomRebirthPathsUsePayloadAndActualInheritedState() = runBlocking {
        listOf("quickRebirth", "customizeRebirth").forEachIndexed { index, actionId ->
            val (store, controller) = completedHighSchoolFixture("phase8-rebirth-$index")
            val current = store.current
            val highSchool = requireNotNull(current.highSchool)
            val run = highSchool.run
            val intent = HighSchoolPledgeRules.options(
                highSchool.weekly.stableUserId,
                highSchool.weekly.weekKey,
                run.careerId,
                run,
            ).first().let {
                HighSchoolNextRunIntent(it.id, run.lifeNumber, "Phase 9 executable intent")
            }
            store.dispatch(
                GameCommandEnvelope(
                    commandId = "save-intent-$index",
                    sessionId = "phase8-ui",
                    expectedRevision = current.revision,
                    command = GameCommand.HighSchool(HighSchoolPhase4Command.SaveNextRunIntent(intent)),
                ),
            )

            val model = controller.projection(Phase8ScreenId.P015_REBIRTH)
            val action = model.actions.single { it.id == actionId }
            controller.execute(Phase8ScreenId.P015_REBIRTH, action.id, action.payloads)

            val after = store.current
            val rebirth = after.analytics.receipts.last { it.eventName == "rebirth_started" }
            assertEquals(
                if (actionId == "quickRebirth") "quick_rebirth" else "customize",
                rebirth.properties.first { it.first == "entry_point" }.second,
            )
            assertTrue(rebirth.properties.none { it.second == "recap" })
            assertEquals(
                after.highSchool?.inheritance?.selectedSignatureLegacyId,
                rebirth.properties.firstOrNull { it.first == "selected_legacy_id" }?.second,
            )
            val applied = after.analytics.receipts.lastOrNull { it.eventName == "next_run_intent_applied" }
            assertEquals(intent.pledgeId, applied?.properties?.firstOrNull { it.first == "pledge_id" }?.second)
            assertEquals(
                after.highSchool?.inheritance?.selectedSignatureLegacyId,
                after.analytics.receipts.lastOrNull { it.eventName == "signature_legacy_equipped" }
                    ?.properties?.firstOrNull { it.first == "legacy_id" }?.second,
            )
            val tapped = after.analytics.receipts.last { it.eventName == "recap_continue_tapped" }
            assertEquals(rebirth.properties.first { it.first == "entry_point" }.second, tapped.properties.first { it.first == "entry_path" }.second)
        }
    }

    @Test
    fun playerLegacyExposureUsesOnlyExactVisibleSurfaceRecordAndSurvivesRestart() = runBlocking {
        val (store, controller) = completedHighSchoolFixture("phase8-legacy-exposure")
        val current = store.current
        val currentRecord = requireNotNull(current.highSchool?.archive?.last())
        val recap = Phase9PlayerLegacyExposurePolicy.resolve(current, Phase9PlayerLegacyExposureSurface.RECAP)
        assertEquals("recap", recap?.source)
        assertEquals(currentRecord.careerId, recap?.scope?.removePrefix("recap:"))
        assertEquals(null, Phase9PlayerLegacyExposurePolicy.resolve(current, Phase9PlayerLegacyExposureSurface.NEXT_LIFE))
        val preArchiveRecap = current.copy(
            highSchool = requireNotNull(current.highSchool).copy(
                run = requireNotNull(current.highSchool).run.copy(phase = HighSchoolPhase.LEGACY),
            ),
        )
        assertEquals(null, Phase9PlayerLegacyExposurePolicy.resolve(preArchiveRecap, Phase9PlayerLegacyExposureSurface.RECAP))
        assertEquals(
            "archive",
            Phase9PlayerLegacyExposurePolicy.resolve(current, Phase9PlayerLegacyExposureSurface.ARCHIVE, currentRecord.careerId)?.source,
        )
        val otherRecord = currentRecord.copy(
            careerId = "${currentRecord.careerId}-older",
            playerName = "보관 선수",
        )
        val multipleArchive = com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel()
            .commitShadowState(requireNotNull(current.highSchool).copy(archive = listOf(otherRecord, currentRecord)))
        val multipleArchiveState = current.copy(highSchool = multipleArchive).committed()
        assertEquals(otherRecord.careerId, Phase9LifeCardProjection.selected(multipleArchiveState, otherRecord.careerId)?.careerId)
        assertEquals(currentRecord.careerId, Phase9LifeCardProjection.selected(multipleArchiveState, currentRecord.careerId)?.careerId)
        assertEquals(
            null,
            Phase9PlayerLegacyExposurePolicy.resolve(current, Phase9PlayerLegacyExposureSurface.ARCHIVE, "wrong-life"),
        )

        val restarted = GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(current))
        assertEquals(recap, Phase9PlayerLegacyExposurePolicy.resolve(restarted, Phase9PlayerLegacyExposureSurface.RECAP))

        val challenge = requireNotNull(current.highSchool).let { highSchool ->
            val challengeState = com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel().startChallenge(highSchool).state
            current.copy(
                highSchool = challengeState,
                stage = GameStage.HIGH_SCHOOL,
            ).committed()
        }
        assertEquals(null, Phase9PlayerLegacyExposurePolicy.resolve(challenge, Phase9PlayerLegacyExposureSurface.RECAP))
        assertEquals(null, Phase9PlayerLegacyExposurePolicy.resolve(challenge, Phase9PlayerLegacyExposureSurface.NEXT_LIFE))
        assertTrue(
            Phase9AnalyticsProjector.project(
                challenge,
                challenge,
                GameCommandEnvelope(
                    commandId = "challenge-tutorial",
                    sessionId = "phase8-ui",
                    expectedRevision = challenge.revision,
                    command = GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("challenge")),
                ),
            ).none { it.eventName == "first_pitch" },
        )

        val quick = controller.projection(Phase8ScreenId.P015_REBIRTH).actions.single { it.id == "quickRebirth" }
        controller.execute(Phase8ScreenId.P015_REBIRTH, quick.id, quick.payloads)
        val nextLife = store.current
        val nextLifeExposure = Phase9PlayerLegacyExposurePolicy.resolve(nextLife, Phase9PlayerLegacyExposureSurface.NEXT_LIFE)
        assertEquals("next_life", nextLifeExposure?.source)
        assertEquals(currentRecord.careerId, nextLifeExposure?.scope?.split(":")?.getOrNull(1))
        assertEquals(null, Phase9PlayerLegacyExposurePolicy.resolve(nextLife, Phase9PlayerLegacyExposureSurface.RECAP))
    }

    private suspend fun executeFirst(
        controller: Phase8Controller,
        screen: Phase8ScreenId,
        actionId: String? = null,
        predicate: ((Phase8ActionModel) -> Boolean)? = null,
    ) {
        val model = controller.projection(screen)
        val action = model.actions.first { it.enabled && (actionId == null || it.id == actionId) && (predicate?.invoke(it) ?: true) }
        controller.execute(screen, action.id, action.payloads)
    }

    private suspend fun completedHighSchoolFixture(installId: String): Pair<KotlinGameStore, Phase8Controller> {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial(installId))
        val controller = Phase8Controller(store, context)
        executeFirst(controller, Phase8ScreenId.P001_OPENING)
        executeFirst(controller, Phase8ScreenId.P002_SETUP)
        executeFirst(controller, Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
        executeFirst(controller, Phase8ScreenId.P004_PITCH_TUTORIAL, "openTutorialPitch")
        finishTutorialPitch(store)
        executeFirst(controller, Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
        executeFirst(controller, Phase8ScreenId.P005_SCHOOL_SELECTION)
        val phase7 = Phase7VerticalController(store, "phase8-ui")
        advanceHighSchoolUntil(store, controller, phase7, HighSchoolPhase.DRAFT)
        executeFirst(controller, Phase8ScreenId.P013_DRAFT, "resolveDraft")
        if (store.current.highSchool?.run?.phase == HighSchoolPhase.LEGACY || store.current.highSchool?.run?.phase == HighSchoolPhase.COMPLETED) {
            executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP, "prepareLegacy")
        }
        executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP) { it.id.startsWith("selectLegacy:") }
        executeFirst(controller, Phase8ScreenId.P014_RUN_RECAP, "finalizeArchive")
        return store to controller
    }

    private suspend fun finishTutorialPitch(store: KotlinGameStore) {
        val pitch = requireNotNull(store.current.pitch)
        val phase7 = Phase7VerticalController(store, "phase8-ui")
        val request = phase7.submitPitch(pitch.sessionId, 0, PitchKind.FOUR_SEAM, PitchZone(1, 1), PitchDelivery(1_000, 1_000))
        phase7.consumePresentation(pitch.sessionId, request)
        phase7.completePitchAndPostgame(pitch.sessionId)
        assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
    }

    private suspend fun advanceHighSchoolUntil(
        store: KotlinGameStore,
        controller: Phase8Controller,
        phase7: Phase7VerticalController,
        target: HighSchoolPhase,
        onImportantGame: suspend () -> Unit = {},
    ) {
        var guard = 0
        while (store.current.highSchool?.run?.phase != target) {
            assertTrue(++guard < 260, "high-school fixture did not reach $target; phase=${store.current.highSchool?.run?.phase}, chapter=${store.current.highSchool?.run?.chapter?.number}, pitch=${store.current.pitch?.boundary}")
            when (store.current.highSchool?.run?.phase) {
                HighSchoolPhase.SCHOOL_SELECTION -> executeFirst(controller, Phase8ScreenId.P005_SCHOOL_SELECTION)
                HighSchoolPhase.TRAINING -> executeFirst(controller, Phase8ScreenId.P006_TRAINING)
                HighSchoolPhase.RELATIONSHIP -> executeFirst(controller, Phase8ScreenId.P007_RELATIONSHIP)
                HighSchoolPhase.IMPORTANT_GAME -> {
                    onImportantGame()
                    finishImportantGame(store, controller, phase7)
                }
                HighSchoolPhase.AWAKENING -> executeFirst(controller, Phase8ScreenId.P009_AWAKENING)
                HighSchoolPhase.CHAPTER_REVIEW -> executeFirst(controller, Phase8ScreenId.P010_CHAPTER)
                HighSchoolPhase.PROLOGUE -> executeFirst(controller, Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
                else -> error("unexpected high-school fixture phase ${store.current.highSchool?.run?.phase}")
            }
        }
    }

    private suspend fun finishImportantGame(
        store: KotlinGameStore,
        controller: Phase8Controller,
        phase7: Phase7VerticalController,
    ) {
        var firstPitch = true
        var pitchCount = 0
        while (firstPitch || store.current.highSchool?.activePitch != null) {
            val boundary = store.current.pitch?.boundary
            if (boundary == null || boundary == PitchBoundary.COMPLETED || boundary == PitchBoundary.ABANDONED) {
                val id = if (firstPitch) "openImportantGame" else "nextImportantPitch"
                executeFirst(controller, Phase8ScreenId.P008_IMPORTANT_GAME, id)
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

    private fun signedPro(kernel: ProKernel, state: com.solkim.baseball.core.pro.ProState): com.solkim.baseball.core.pro.ProState =
        state.copy(commitment = kernel.commitment(state.copy(commitment = "")))

    private fun aggregateWithPro(installId: String, pro: com.solkim.baseball.core.pro.ProState): GameAggregateState {
        val stage = when (pro.phase) {
            ProCareerPhase.RETIREMENT_DECISION -> GameStage.RETIREMENT
            ProCareerPhase.LEGACY_SELECTION -> GameStage.LEGACY
            ProCareerPhase.COMPLETED -> GameStage.BETWEEN_LIVES
            else -> GameStage.PRO
        }
        val base = GameAggregateState.initial(installId).copy(
            stage = stage,
            pro = pro,
            meta = GameMetaState(activeHighSchoolCareerId = pro.sourceHighSchoolCareerId),
        )
        return base.copy(commitment = base.recomputeCommitment()).also { it.validate() }
    }

    private fun linkedLegacyFixture(kernel: ProKernel): com.solkim.baseball.core.pro.ProState {
        val pitcher = ProCatalog.pitcherForPreset("power_prospect", "연계투수")
        val linked = kernel.startLinked(
            ProStartLinkedRequest(
                seed = "918220",
                highSchoolCareerId = "hs-legacy-fixture",
                identityName = "연계투수",
                pitcher = pitcher,
                teamId = ProCatalog.teams.first().id,
                draftEvaluation = 88,
                entitlement = ProEntitlement(),
                activeHighSchoolPreserved = true,
                highSchoolLegacyContext = ProHighSchoolLegacyContext(
                    startingPitcher = pitcher,
                    highSchoolPitcher = pitcher,
                    performance = HighSchoolPerformance(5, 120, 20, 4, 7, 300, 210, 45, 12),
                    selectedAwakenings = listOf("explosive_fastball"),
                    managerTrust = 61,
                    catcherTrust = 58,
                    rivalTrust = 55,
                ),
            ),
        ).state
        val signed = kernel.signContract(linked, "918220").state
        val candidates = listOf(
            ProLegacyCandidate("power_imprint", "힘의 흔적", "결정적인 순간의 구위", "마운드에 남은 힘", 90),
            ProLegacyCandidate("battery_memory", "배터리의 기억", "함께 읽은 사인", "서로의 호흡을 남김", 86),
            ProLegacyCandidate("late_inning_calm", "후반의 침착함", "끝까지 흔들리지 않은 선택", "마지막 이닝의 고요", 82),
        )
        return signedPro(kernel, signed.copy(
            phase = ProCareerPhase.LEGACY_SELECTION,
            legacyCandidates = candidates,
            commitment = "",
        ))
    }
}
