package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.highschool.HighSchoolPerformance
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProEntitlement
import com.solkim.baseball.core.pro.ProHighSchoolLegacyContext
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProLegacyCandidate
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.persistence.SaveFailureCode
import com.solkim.baseball.persistence.SaveLoadResult
import com.solkim.baseball.persistence.SaveRepositoryException
import com.solkim.baseball.persistence.SaveWriteResult
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/** Executable audit for the aggregate half of the frozen native analytics matrix. */
class Phase9AnalyticsProjectorTest {
    @Test
    fun everyNonZeroMatrixEventHasAContractSourceAndRetiredEventsHaveNoSource() {
        val expectedNonZeroMatrixEvents = setOf(
            "onboarding_started", "onboarding_completed", "first_pitch", "activation_first_game", "game_finished",
            "chapter_advanced", "draft_resolved", "rebirth_started", "life_card_share_tapped",
            "run_pledge_selected", "run_pledge_resolved", "career_wind_seen", "next_run_intent_saved",
            "next_run_intent_applied", "weekly_program_opened", "weekly_program_completed",
            "pro_season_decision_selected", "pro_legacy_recorded", "player_legacy_seen", "player_heartline_seen",
            "recap_continue_tapped", "signature_legacy_options_seen", "signature_legacy_selected",
            "signature_legacy_equipped", "life_completed", "career_training_completed", "game_growth_applied",
            "phase_entered", "game_abandoned", "pro_career_started", "reminder_changed", "reminder_offer_shown",
            "reminder_opened", "return_plan_shown", "return_plan_tapped", "return_plan_dismissed",
            "return_plan_eligible", "return_plan_cold_start", "return_plan_next_day_open", "session_ended",
        )
        assertEquals(emptySet(), Phase9AnalyticsContract.retiredEvents intersect Phase9AnalyticsContract.semanticSources.keys)
        assertEquals(emptySet(), Phase9AnalyticsContract.intentionalZeroCallerEvents intersect Phase9AnalyticsContract.semanticSources.keys)
        assertEquals(expectedNonZeroMatrixEvents, Phase9AnalyticsContract.semanticSources.keys)
        assertTrue(Phase9AnalyticsContract.semanticSources.keys.all { it in Phase9AnalyticsContract.allowedProperties })
        assertTrue(Phase9AnalyticsContract.semanticSources.values.all(String::isNotBlank))
        assertEquals(setOf("life_card_shared", "life_card_share_completed", "daily_inning_opened", "daily_inning_rewarded"), Phase9AnalyticsContract.intentionalZeroCallerEvents)
    }

    @Test
    fun typedBoundaryCoversEveryFrozenPropertyAndKeepsTextIdsText() {
        assertEquals(Phase9AnalyticsContract.semanticSources.keys, Phase9AnalyticsContract.allowedProperties.keys)
        Phase9AnalyticsContract.propertyKinds.forEach { (eventName, kinds) ->
            assertTrue(eventName in Phase9AnalyticsContract.allowedProperties)
            assertTrue(kinds.keys.all { it in Phase9AnalyticsContract.allowedProperties.getValue(eventName) })
        }
        Phase9AnalyticsContract.allowedTextValues.forEach { (eventName, domains) ->
            domains.forEach { (key, values) ->
                assertTrue(key in Phase9AnalyticsContract.allowedProperties.getValue(eventName))
                assertTrue(key !in Phase9AnalyticsContract.propertyKinds[eventName].orEmpty())
                assertTrue(values.isNotEmpty())
            }
        }
        Phase9AnalyticsContract.validateManual(
            "run_pledge_selected",
            listOf("pledge_id" to "123", "recommended" to "true", "life_number" to "123"),
        )
        assertFailsWith<IllegalArgumentException> {
            Phase9AnalyticsContract.validateManual(
                "run_pledge_selected",
                listOf("pledge_id" to "safe", "recommended" to "TRUE", "life_number" to "1"),
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Phase9AnalyticsContract.validateManual(
                "run_pledge_selected",
                listOf("pledge_id" to "safe", "recommended" to "false", "life_number" to "1.0"),
            )
        }
        assertFailsWith<IllegalArgumentException> {
            Phase9AnalyticsContract.validateManual(
                "reminder_changed",
                listOf("enabled" to "false", "source" to "permission_result"),
            )
        }
        Phase9AnalyticsContract.allowedTextValues.forEach { (eventName, domains) ->
            domains.forEach { (key, values) ->
                Phase9AnalyticsContract.validateManual(eventName, listOf(key to values.first()))
                assertFailsWith<IllegalArgumentException> {
                    Phase9AnalyticsContract.validateManual(eventName, listOf(key to "__unknown_enum__"))
                }
            }
        }
        Phase9AnalyticsContract.propertyKinds.forEach { (eventName, kinds) ->
            kinds.forEach { (key, kind) ->
                val valid = when (kind) {
                    Phase9AnalyticsPropertyKind.TEXT -> "text"
                    Phase9AnalyticsPropertyKind.FLAG -> "true"
                    Phase9AnalyticsPropertyKind.WHOLE -> "1"
                    Phase9AnalyticsPropertyKind.DECIMAL -> "1.0"
                }
                Phase9AnalyticsContract.validateManual(eventName, listOf(key to valid))
            }
        }
        assertFailsWith<IllegalArgumentException> {
            Phase9AnalyticsProjector.toReceipt(
                Phase9ProjectedAnalyticsEvent(
                    eventName = "reminder_changed",
                    scope = "typed-boundary",
                    properties = mapOf(
                        "enabled" to Phase9AnalyticsValue.Flag(true),
                        "source" to Phase9AnalyticsValue.Text("permission_result"),
                    ),
                ),
                GameAggregateState.initial("phase9-typed-boundary"),
            )
        }
    }

    @Test
    fun firstPitchIsOnlyTheNonChallengeTutorialCompletionAndNotGenericPitchCompletion() {
        val state = GameAggregateState.initial("phase9-first-pitch")
        val completion = GameCommandEnvelope(
            commandId = "generic-complete-pitch",
            sessionId = "phase9-first-pitch-session",
            expectedRevision = 0UL,
            command = GameCommand.CompletePitch("session"),
        )
        assertTrue(Phase9AnalyticsProjector.project(state, state, completion).none { it.eventName == "first_pitch" })
    }

    @Test
    fun proLegacyRecordedOmitsSoulBonusWhenNoAuthoritativeSoulEvidenceExists() {
        val kernel = ProKernel()
        val pitcher = ProCatalog.pitcherForPreset("power_prospect", "프로 투수")
        val linked = kernel.startLinked(
            ProStartLinkedRequest(
                seed = "918220",
                highSchoolCareerId = "hs-phase9-pro",
                identityName = "프로 투수",
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
            ProLegacyCandidate("power_imprint", "힘의 흔적", "구위", "마운드에 남은 힘", 90),
            ProLegacyCandidate("battery_memory", "배터리의 기억", "호흡", "서로의 사인을 남김", 86),
            ProLegacyCandidate("late_inning_calm", "후반의 침착함", "침착함", "마지막 이닝의 고요", 82),
        )
        val candidate = candidates.first()
        val pro = signed.copy(
            phase = ProCareerPhase.LEGACY_SELECTION,
            legacyCandidates = candidates,
            commitment = "",
        ).let { it.copy(commitment = kernel.commitment(it)) }
        val before = GameAggregateState.initial("phase9-pro").copy(
            stage = GameStage.LEGACY,
            pro = pro,
            meta = GameMetaState(activeHighSchoolCareerId = null),
        ).committed()
        val reduced = GameStateReducer.dispatch(
            before,
            GameCommandEnvelope(
                commandId = "pro-select-legacy",
                sessionId = "phase9-pro-session",
                expectedRevision = 0UL,
                command = GameCommand.Pro(ProCommand.SelectLegacy(candidate.id)),
            ),
        ).state
        val receipt = reduced.analytics.receipts.last { it.eventName == "pro_legacy_recorded" }
        assertTrue(receipt.properties.none { it.first == "soul_bonus" })
    }

    @Test
    fun trainingBlockProjectsOneReceiptPerCommittedEvidenceInOrderAndSurvivesRestart() {
        val kernel = HighSchoolPhase4Kernel()
        var training = kernel.start(
            HighSchoolPhase4StartRequest("918220", "power_prospect", "phase9-training", "2026-W33", "2026-08-14"),
        ).state
        training = kernel.completePrologue("918220", kernel.beginTutorial(training).state).state
        training = kernel.chooseSchool("918220", training, HighSchoolSchoolId.HAEDONG_POWER).state
        training = kernel.commitShadowState(training.copy(revision = training.run.revision))
        val before = GameAggregateState.initial("phase9-training").copy(
            stage = GameStage.HIGH_SCHOOL,
            highSchool = training,
            meta = GameMetaState(activeHighSchoolCareerId = training.run.careerId),
        ).committed()
        val envelope = GameCommandEnvelope(
            commandId = "training-block",
            sessionId = "phase9-training-session",
            expectedRevision = 0UL,
            command = GameCommand.HighSchool(
                HighSchoolPhase4Command.TrainingBlock(
                    "918220",
                    List(3) { index ->
                        if (index % 2 == 0) {
                            HighSchoolTrainingFocus.COMMAND to HighSchoolTrainingIntensity.LIGHT
                        } else {
                            HighSchoolTrainingFocus.STAMINA to HighSchoolTrainingIntensity.STANDARD
                        }
                    },
                ),
            ),
        )
        val reduced = GameStateReducer.dispatch(before, envelope).state
        val expected = requireNotNull(reduced.highSchool).trainingEvidence.size
        val trainingReceipts = reduced.analytics.receipts.filter { it.eventName == "career_training_completed" }
        assertEquals(expected, trainingReceipts.size)
        val expectedReceiptIds = (1..expected).map {
            Phase9AnalyticsProjector.receiptId(
                "phase9-training",
                "career_training_completed",
                "training:${training.run.careerId}:$it",
            )
        }
        assertEquals(
            expectedReceiptIds,
            trainingReceipts.map { it.receiptId },
        )
        val restarted = GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(reduced))
        assertEquals(reduced.highSchool?.trainingEvidence, restarted.highSchool?.trainingEvidence)
        assertEquals(
            trainingReceipts.map { it.receiptId },
            restarted.analytics.receipts.filter { it.eventName == "career_training_completed" }.map { it.receiptId },
        )
    }

    @Test
    fun trainingBlockSaveFailureLeavesEvidenceAndAnalyticsUncommitted() = runBlocking {
        val kernel = HighSchoolPhase4Kernel()
        var training = kernel.start(
            HighSchoolPhase4StartRequest("918221", "power_prospect", "phase9-training-save-failure", "2026-W33", "2026-08-14"),
        ).state
        training = kernel.completePrologue("918221", kernel.beginTutorial(training).state).state
        training = kernel.chooseSchool("918221", training, HighSchoolSchoolId.HAEDONG_POWER).state
        training = kernel.commitShadowState(training.copy(revision = training.run.revision))
        val before = GameAggregateState.initial("phase9-training-save-failure").copy(
            stage = GameStage.HIGH_SCHOOL,
            highSchool = training,
            meta = GameMetaState(activeHighSchoolCareerId = training.run.careerId),
        ).committed()
        val store = KotlinGameStore.fromState(
            before,
            authorityMode = NativeAuthorityMode.NATIVE_AUTHORITATIVE,
            ioRepository = FailingStoreRepository(),
        )
        val command = GameCommandEnvelope(
            commandId = "training-save-failure",
            sessionId = "phase9-training-save-failure-session",
            expectedRevision = before.revision,
            command = GameCommand.HighSchool(
                HighSchoolPhase4Command.TrainingBlock(
                    "918221",
                    listOf(HighSchoolTrainingFocus.COMMAND to HighSchoolTrainingIntensity.STANDARD),
                ),
            ),
        )
        assertFailsWith<SaveRepositoryException> { store.dispatch(command) }
        assertEquals(before, store.current)
        assertTrue(store.current.highSchool?.trainingEvidence.isNullOrEmpty())
        assertTrue(store.current.analytics.receipts.none { it.eventName == "career_training_completed" })
    }

    @Test
    fun manualMatrixInteractionRejectsInventedPropertyAndRetiredOrZeroCaller() {
        val state = GameAggregateState.initial("phase9-matrix-contract")
        val valid = GameCommandEnvelope(
            commandId = "valid-reminder",
            sessionId = "phase9-test",
            expectedRevision = 0UL,
            command = GameCommand.RecordAnalytics(
                receiptId = "reminder-receipt",
                eventName = "reminder_changed",
                properties = listOf("enabled" to "true", "source" to "system"),
            ),
        )
        assertEquals(1UL, GameStateReducer.dispatch(state, valid).state.revision)
        assertFailsWith<GameCommandException> {
            GameStateReducer.dispatch(
                state,
                valid.copy(
                    commandId = "invented-property",
                    command = GameCommand.RecordAnalytics(
                        receiptId = "invented-receipt",
                        eventName = "reminder_changed",
                        properties = listOf("enabled" to "true", "player_name" to "민서준"),
                    ),
                ),
            )
        }
        assertFailsWith<GameCommandException> {
            GameStateReducer.dispatch(
                state,
                valid.copy(
                    commandId = "wrong-wire-type",
                    command = GameCommand.RecordAnalytics(
                        receiptId = "wrong-wire-type-receipt",
                        eventName = "reminder_changed",
                        properties = listOf("enabled" to "True", "source" to "system"),
                    ),
                ),
            )
        }
        assertFailsWith<GameCommandException> {
            GameStateReducer.dispatch(
                state,
                valid.copy(
                    commandId = "retired-event",
                    command = GameCommand.RecordAnalytics("retired-receipt", "daily_inning_opened"),
                ),
            )
        }
        assertFailsWith<GameCommandException> {
            GameStateReducer.dispatch(
                state,
                valid.copy(
                    commandId = "zero-caller",
                    command = GameCommand.RecordAnalytics("share-completed", "life_card_share_completed", listOf("life_number" to "1")),
                ),
            )
        }
    }

    @Test
    fun aggregateTransitionProjectionUsesOnlyKnownMatrixProperties() = runBlocking {
        val initial = GameAggregateState.initial("phase9-projector")
        val repository = InMemoryShadowFixtureGameStoreRepository(initial)
        val store = KotlinGameStore.fromShadowFixture(initial, repository)
        assertEquals(GameStage.OPENING, store.current.stage)
        assertTrue(Phase9AnalyticsContract.nonRetiredEvents.contains("onboarding_started"))
        val enter = GameCommandEnvelope("enter-setup", "phase9", 0UL, GameCommand.EnterSetup)
        val reduced = GameStateReducer.dispatch(initial, enter)
        assertEquals(GameStage.SETUP, reduced.state.stage)
        assertTrue(reduced.state.analytics.receipts.any { it.eventName == "onboarding_started" }, reduced.state.analytics.receipts.joinToString { it.eventName })
        store.dispatch(enter)
        assertTrue(store.current.analytics.receipts.any { it.eventName == "onboarding_started" }, store.current.analytics.receipts.joinToString { it.eventName })
        val state = store.current
        val payload = Phase8Payloads.analytics(
            state,
            Phase8ScreenId.P027_SETTINGS,
            "reminder",
            "reminder_changed",
            "settings:phase9",
            listOf("enabled" to "false", "source" to "system"),
        )
        val result = store.dispatch(payload.envelope)
        val receipt = result.state.analytics.receipts.last { it.eventName == "reminder_changed" }
        assertTrue(receipt.properties.map { it.first }.all { it in Phase9AnalyticsContract.allowedProperties.getValue("reminder_changed") })
        assertTrue(result.state.analytics.receipts.none { it.eventName in Phase9AnalyticsContract.intentionalZeroCallerEvents })
    }

    @Test
    fun durableNativeHandoffFailureCannotReplayHistoricReceiptAfterRestart() = runBlocking {
        val initial = GameAggregateState.initial("phase9-handoff")
        val repository = InMemoryShadowFixtureGameStoreRepository(initial)
        val durableNativeIds = linkedSetOf<String>()
        var failAfterDurableHandoff = true
        val published = mutableListOf<String>()
        val projection = AnalyticsReceiptProjection(
            sink = AnalyticsReceiptSink { receipts ->
                durableNativeIds += receipts.map { it.receiptId }
                if (failAfterDurableHandoff) error("observer.failed.after.native-write")
                published += receipts.map { it.receiptId }
            },
            durableReceiptIds = { durableNativeIds.toSet() },
        )
        val store = KotlinGameStore.fromShadowFixture(initial, repository, projection)
        val payload = Phase8Payloads.analytics(
            store.current,
            Phase8ScreenId.P027_SETTINGS,
            "reminder",
            "reminder_changed",
            "settings:handoff",
            listOf("enabled" to "true", "source" to "system"),
        )
        store.dispatch(payload.envelope)
        val receiptId = payload.envelope.command.let { command ->
            require(command is GameCommand.RecordAnalytics)
            command.receiptId
        }
        assertTrue(receiptId in durableNativeIds)
        assertTrue(projection.pending(store.current).isEmpty())

        failAfterDurableHandoff = false
        val restartedPublished = mutableListOf<String>()
        val restartedProjection = AnalyticsReceiptProjection(
            sink = AnalyticsReceiptSink { receipts -> restartedPublished += receipts.map { it.receiptId } },
            durableReceiptIds = { durableNativeIds.toSet() },
        )
        val restarted = KotlinGameStore.open("phase9-handoff", repository, NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY, restartedProjection)
        restartedProjection.retryPending(restarted.current)
        assertTrue(receiptId !in restartedPublished)
        assertTrue(receiptId in restarted.current.analytics.receipts.map { it.receiptId })
        assertTrue(published.isEmpty())
    }

    @Test
    fun observerFailureAfterSaveIsRetryableAndDoesNotHideCommittedReceipt() = runBlocking {
        val initial = GameAggregateState.initial("phase9-observer-retry")
        val repository = InMemoryShadowFixtureGameStoreRepository(initial)
        var fail = true
        val published = mutableListOf<String>()
        val projection = AnalyticsReceiptProjection(
            sink = AnalyticsReceiptSink { receipts ->
                if (fail) error("observer.failed")
                published += receipts.map { it.receiptId }
            },
        )
        val store = KotlinGameStore.fromShadowFixture(initial, repository, projection)
        val payload = Phase8Payloads.analytics(
            store.current,
            Phase8ScreenId.P027_SETTINGS,
            "reminder",
            "reminder_changed",
            "settings:observer-retry",
            listOf("enabled" to "true", "source" to "system"),
        )
        val committed = store.dispatch(payload.envelope)
        val receiptId = requireNotNull(committed.state.analytics.receipts.lastOrNull()).receiptId
        assertTrue(receiptId in committed.state.analytics.receipts.map { it.receiptId })
        assertTrue(projection.pending(store.current).any { it.receiptId == receiptId })

        fail = false
        store.retryAnalyticsHandoff()
        assertTrue(receiptId in published)
        assertTrue(projection.pending(store.current).none { it.receiptId == receiptId })
    }

    @Test
    fun durableLedgerObserverFailureCannotMakeDispatchFail() = runBlocking {
        val initial = GameAggregateState.initial("phase9-ledger-failure")
        val repository = InMemoryShadowFixtureGameStoreRepository(initial)
        val published = mutableListOf<String>()
        val projection = AnalyticsReceiptProjection(
            sink = AnalyticsReceiptSink { receipts -> published += receipts.map { it.receiptId } },
            durableReceiptIds = { error("ledger.read.failed") },
        )
        val store = KotlinGameStore.fromShadowFixture(initial, repository, projection)
        val payload = Phase8Payloads.analytics(
            store.current,
            Phase8ScreenId.P027_SETTINGS,
            "reminder",
            "reminder_changed",
            "settings:ledger-failure",
            listOf("enabled" to "false", "source" to "system"),
        )
        val result = store.dispatch(payload.envelope)
        assertEquals(1UL, result.state.revision)
        assertTrue(published.isNotEmpty())
    }

    private class FailingStoreRepository : GameStoreRepository {
        override suspend fun save(value: GameAggregateState, revision: ULong): SaveWriteResult<GameAggregateState> =
            throw SaveRepositoryException(SaveFailureCode.IO_FAILED, "phase9.training_save_failure")

        override suspend fun load(): SaveLoadResult<GameAggregateState> = error("not used")
        override suspend fun reset(): Unit = error("not used")
    }
}
