package com.solkim.baseball.platform

import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

public class Phase9PlatformContractTest {
    @Test
    public fun analyticsSchemaAcceptsMatrixEventsAndRejectsPrivacyOrRetiredPayloads() {
        assertTrue(Phase9AnalyticsSchema.eventNames.contains("game_finished"))
        val properties = Phase9AnalyticsSchema.validate(
            "game_finished",
            mapOf(
                "mode" to PlatformProperty.Text("high_school"),
                "drafted" to PlatformProperty.Flag(true).also { /* deliberate type mismatch below is not used */ },
                "strikeouts" to PlatformProperty.Whole(3),
            ).filterKeys { it != "drafted" },
        )
        assertEquals(2, properties.size)
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.validate("game_finished", mapOf("player_name" to PlatformProperty.Text("민수")))
        }
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.validate("daily_inning_opened", emptyMap())
        }
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.validate("screen_view", emptyMap())
        }
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.validate(
                "reminder_changed",
                mapOf("enabled" to PlatformProperty.Text("true"), "source" to PlatformProperty.Text("system")),
            )
        }
        Phase9AnalyticsSchema.intentionalZeroCallerEventNames.forEach { eventName ->
            assertThrows("zero-caller event must stay native-silent: $eventName", IllegalArgumentException::class.java) {
                Phase9AnalyticsSchema.validate(eventName, emptyMap())
            }
        }
    }

    @Test
    public fun analyticsBoundaryWalksEveryNonZeroMatrixEventAndRejectsUnknownCallers() {
        val activeEvents = Phase9AnalyticsSchema.eventNames -
            Phase9AnalyticsSchema.retiredEventNames -
            Phase9AnalyticsSchema.intentionalZeroCallerEventNames
        assertTrue(activeEvents.isNotEmpty())
        activeEvents.forEach { eventName ->
            assertEquals(emptyMap<String, PlatformProperty>(), Phase9AnalyticsSchema.validate(eventName, emptyMap()))
            assertEquals(eventName, Phase9AnalyticsSchema.fromStrings("matrix-$eventName", eventName, emptyList()).eventName)
        }
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.fromStrings("unknown-caller", "unknown_matrix_event", emptyList())
        }
    }

    @Test
    public fun analyticsStringBoundaryUsesEventKeyKindsAndExactTextDomains() {
        val event = Phase9AnalyticsSchema.fromStrings(
            receiptId = "schema-roundtrip",
            eventName = "run_pledge_selected",
            properties = listOf("pledge_id" to "true", "recommended" to "true", "life_number" to "123"),
        )
        assertTrue(event.properties.getValue("pledge_id") is PlatformProperty.Text)
        assertEquals("true", (event.properties.getValue("pledge_id") as PlatformProperty.Text).value)
        assertTrue(event.properties.getValue("recommended") is PlatformProperty.Flag)
        assertTrue(event.properties.getValue("life_number") is PlatformProperty.Whole)

        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.fromStrings("bad-flag", "run_pledge_selected", listOf("recommended" to "True"))
        }
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.fromStrings("bad-whole", "run_pledge_selected", listOf("life_number" to "1.0"))
        }
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.fromStrings("bad-enum", "reminder_changed", listOf("enabled" to "true", "source" to "permission_result"))
        }
        val opened = Phase9AnalyticsSchema.fromStrings(
            "notification-open",
            "reminder_opened",
            listOf("destination" to "high-school", "reason" to "return_plan", "plan_receipt" to "plan-1"),
        )
        assertEquals("high-school", (opened.properties.getValue("destination") as PlatformProperty.Text).value)
        assertThrows(IllegalArgumentException::class.java) {
            Phase9AnalyticsSchema.fromStrings("bad-destination", "reminder_opened", listOf("destination" to "high_school"))
        }
    }

    @Test
    public fun platformStateCodecIsCanonicalAndRejectsUnknownOrTamperedFields() {
        val state = Phase9PlatformState(
            scopedEpoch = 2,
            analyticsOnceReceiptIds = listOf("r1"),
            scheduledReminderTokenHashes = listOf("scheduled-token"),
            notificationAnalyticsTokenHashes = listOf("a"),
            reminderOfferDeclined = true,
            reviewAttempts = listOf(ReviewAttempt("good-recap", 100L)),
        )
        val bytes = Phase9PlatformStateCodec.encode(state)
        assertEquals(state, Phase9PlatformStateCodec.decode(bytes))
        assertThrows(IllegalArgumentException::class.java) {
            Phase9PlatformStateCodec.decode(bytes + byteArrayOf(0x20))
        }
        val unknown = String(bytes, Charsets.UTF_8).replace("\"shareCacheEpoch\":0", "\"unexpected\":1,\"shareCacheEpoch\":0")
        assertThrows(IllegalArgumentException::class.java) { Phase9PlatformStateCodec.decode(unknown.toByteArray()) }
    }

    @Test
    public fun fileStateSurvivesRestartAndResetClearsEachScopedDomain() {
        val directory = Files.createTempDirectory("phase9-platform-state")
        try {
            val first = FilePlatformStateStore(directory)
            first.update { it.copy(analyticsOnceReceiptIds = listOf("receipt"), notificationAnalyticsTokenHashes = listOf("token"), reminderOfferDeclined = true, reviewAttempts = listOf(ReviewAttempt("third-life", 7L))) }
            val reopened = FilePlatformStateStore(directory)
            assertEquals(listOf("receipt"), reopened.read().analyticsOnceReceiptIds)
            assertTrue(reopened.read().reminderOfferDeclined)
            reopened.clearAnalytics()
            reopened.clearReview()
            reopened.clearReminders()
            reopened.clearScopedEpoch()
            reopened.clearShareCache()
            val cleared = reopened.read()
            assertTrue(cleared.analyticsOnceReceiptIds.isEmpty())
            assertTrue(cleared.analyticsOutbox.isEmpty())
            assertTrue(cleared.reviewAttempts.isEmpty())
            assertTrue(cleared.scheduledReminderTokenHashes.isEmpty())
            assertTrue(cleared.notificationAnalyticsTokenHashes.isEmpty())
            assertFalse(cleared.reminderOfferDeclined)
            assertEquals(1L, cleared.scopedEpoch)
            assertEquals(1L, cleared.shareCacheEpoch)
        } finally {
            directory.toFile().deleteRecursively()
        }
    }

    @Test
    public fun installIdentityIsDurableValidatedAndScopedWithoutRawIdKeys() {
        val directory = Files.createTempDirectory("phase9-install")
        try {
            val first = FileInstallIdentity(directory) { "0123456789abcdef0123456789abcdef" }
            val id = first.getOrCreate()
            assertEquals("0123456789abcdef0123456789abcdef", id)
            assertEquals(id, FileInstallIdentity(directory) { "ffffffffffffffffffffffffffffffff" }.getOrCreate())
            assertNotEquals(InstallIdentityContract.scopeHash(id, 0L, "analytics"), InstallIdentityContract.scopeHash(id, 1L, "analytics"))
            assertFalse(InstallIdentityContract.scopeHash(id, 0L, "analytics").contains(id))
            assertThrows(IllegalArgumentException::class.java) { InstallIdentityContract.validate("not-an-id") }
        } finally {
            directory.toFile().deleteRecursively()
        }
    }

    @Test
    public fun analyticsOutboxRetriesAfterDestinationFailureAndDoesNotDuplicate() {
        val store = InMemoryPlatformStateStore()
        val failing = RecordingDestination("firebase", fail = true)
        val working = RecordingDestination("amplitude", fail = false)
        val service = NativeAnalyticsService(store, listOf(failing, working), AnalyticsContext("development", "phase9", "settings"))
        val event = NativeAnalyticsEvent("receipt-1", "reminder_changed", mapOf("enabled" to PlatformProperty.Flag(true), "source" to PlatformProperty.Text("settings")))
        service.publish(listOf(event))
        assertEquals(1, working.events.size)
        assertTrue(service.pendingOutbox().single().deliveredDestinations.contains("amplitude"))
        failing.fail = false
        service.retryOutbox()
        service.retryOutbox()
        assertEquals(1, failing.events.size)
        assertTrue(store.read().analyticsOutbox.isEmpty())
        assertEquals(listOf("receipt-1"), store.read().analyticsOnceReceiptIds)
    }

    @Test
    public fun analyticsPlatformStoreWriteFailureLeavesReceiptRetryableUntilStoreRecovers() {
        val store = FaultingPlatformStateStore()
        val destination = RecordingDestination("firebase", fail = false)
        val service = NativeAnalyticsService(store, listOf(destination), AnalyticsContext("development", "phase9", "settings"))
        val event = NativeAnalyticsEvent(
            "write-failure-receipt",
            "reminder_changed",
            mapOf("enabled" to PlatformProperty.Flag(true), "source" to PlatformProperty.Text("system")),
        )

        assertThrows(RuntimeException::class.java) { service.publish(listOf(event)) }
        assertTrue(store.delegate.read().analyticsOutbox.isEmpty())
        store.failWrites = false
        service.publish(listOf(event))
        assertEquals(listOf("write-failure-receipt"), destination.events)
        assertEquals(listOf("write-failure-receipt"), store.delegate.read().analyticsOnceReceiptIds)
    }

    @Test
    public fun disabledExternalSdkModeKeepsReceiptsLocalAndRetryable() {
        assertFalse(Phase9NativeSdkConfiguration().externalSdkEnabled)
        assertThrows(IllegalArgumentException::class.java) {
            Phase9NativeSdkConfiguration(externalSdkEnabled = true)
        }
        val store = InMemoryPlatformStateStore()
        val service = NativeAnalyticsService(store, emptyList(), AnalyticsContext("development", "phase9", "settings"))
        val event = NativeAnalyticsEvent("local-receipt", "reminder_changed", mapOf("enabled" to PlatformProperty.Flag(false), "source" to PlatformProperty.Text("settings")))
        service.publish(listOf(event, event))
        assertEquals(listOf("local-receipt"), service.pendingOutbox().map { it.event.receiptId })
        NativeAnalyticsService(store, emptyList(), AnalyticsContext("development", "phase9", "restart")).retryOutbox()
        assertEquals(listOf("local-receipt"), store.read().analyticsOutbox.map { it.event.receiptId })
    }

    @Test
    public fun aggregateBaselinePreventsHistoricReceiptReplayAfterRestart() {
        val store = InMemoryPlatformStateStore()
        val destination = RecordingDestination("firebase", fail = false)
        val service = NativeAnalyticsService(store, listOf(destination), AnalyticsContext("development", "phase9", "settings"))
        service.establishAggregateBaseline(listOf("historic"))
        service.publish(
            listOf(
                NativeAnalyticsEvent(
                    "historic",
                    "reminder_changed",
                    mapOf("enabled" to PlatformProperty.Flag(true), "source" to PlatformProperty.Text("settings")),
                ),
            ),
        )
        assertTrue(destination.events.isEmpty())
        assertTrue(service.pendingOutbox().isEmpty())
        assertTrue(store.read().knownAggregateReceiptIds.contains("historic"))
    }

    @Test
    public fun notificationOpenReceiptSeparatesAnalyticsFromNavigationAcrossRestart() {
        val directory = Files.createTempDirectory("phase9-notification")
        try {
            val store = FilePlatformStateStore(directory)
            val normalized = NotificationIntentNormalizer.normalize(
                NotificationIntentNormalizer.ACTION_OPEN_REMINDER,
                "raw-plan-token",
                "daily_inning",
                "return_plan",
                "plan-1",
            ) ?: error("normalization failed")
            assertEquals(NotificationDestination.HIGH_SCHOOL, normalized.destination)
            store.update { it.copy(scheduledReminderTokenHashes = listOf(normalized.tokenHash)) }
            val first = NotificationOpenCoordinator(store).inspect(normalized)
            assertTrue(first.shouldEmitAnalytics)
            assertTrue(first.shouldNavigate)
            // The aggregate reminder_opened receipt is saved before the token is acknowledged.
            NotificationOpenCoordinator(store).markAnalyticsReceipt(normalized.tokenHash)
            val reopenedStore = FilePlatformStateStore(directory)
            val reopened = NotificationOpenCoordinator(reopenedStore).inspect(normalized)
            assertFalse(reopened.shouldEmitAnalytics)
            assertTrue(reopened.shouldNavigate)
            NotificationOpenCoordinator(reopenedStore).markNavigationCompleted(normalized.tokenHash)
            val completed = NotificationOpenCoordinator(FilePlatformStateStore(directory)).inspect(normalized)
            assertFalse(completed.shouldEmitAnalytics)
            assertFalse(completed.shouldNavigate)
            assertEquals(null, NotificationIntentNormalizer.normalize("android.intent.action.VIEW", "token", "p-023", null, null))
            assertEquals(
                NotificationDestination.HIGH_SCHOOL,
                NotificationIntentNormalizer.normalize(NotificationIntentNormalizer.ACTION_OPEN_REMINDER, "legacy-token", "p-023", null, null)?.destination,
            )
            assertEquals(null, NotificationIntentNormalizer.normalize(NotificationIntentNormalizer.ACTION_OPEN_REMINDER, "unknown-token", "unknown-destination", null, null))
        } finally {
            directory.toFile().deleteRecursively()
        }
    }

    @Test
    public fun resetInvalidatesPendingReminderDeliveryBeforeAlarmRuns() {
        val store = InMemoryPlatformStateStore()
        val token = "return-plan-token"
        val tokenHash = StableNotificationToken.hash(token)
        store.update { it.copy(scheduledReminderTokenHashes = listOf(tokenHash)) }
        assertTrue(ReminderDeliveryPolicy.shouldDeliver(store, token))
        store.clearReminders()
        assertFalse(ReminderDeliveryPolicy.shouldDeliver(store, token))
    }

    @Test
    public fun reviewGateEnforcesReasonLifetimeAndTwentyFourHourWindow() {
        val store = InMemoryPlatformStateStore()
        var now = 1_000L
        val gate = ReviewGate(store) { now }
        assertTrue(gate.reserve(ReviewReason.GOOD_RECAP).eligible)
        assertFalse(gate.canRequest(ReviewReason.GOOD_RECAP).eligible)
        assertFalse(gate.canRequest(ReviewReason.THIRD_LIFE).eligible)
        now += 24L * 60L * 60L * 1000L
        assertTrue(gate.canRequest(ReviewReason.THIRD_LIFE).eligible)
        assertTrue(gate.reserve(ReviewReason.THIRD_LIFE).eligible)
    }

    @Test
    public fun exactPlatformActionPayloadRoundTripsAndFutureActionFailsClosed() {
        val payload = PlatformActionPayload("settings", PlatformAction.OPEN_NOTIFICATION_SETTINGS, 7UL, "0123456789abcdef", PlatformActionCodec.parameterHash(emptyMap()))
        assertEquals(payload, PlatformActionCodec.decode(PlatformActionCodec.encode(payload)))
        assertThrows(RuntimeException::class.java) { PlatformActionCodec.decode(PlatformActionCodec.encode(payload).replace("open-notification-settings", "future-action")) }
        assertThrows(RuntimeException::class.java) { PlatformActionCodec.decode(PlatformActionCodec.encode(payload).replace("\"screen\":\"settings\"", "\"screen\":\"settings\",\"future\":1")) }
    }

    @Test
    public fun audioHapticPolicyHonorsReducedMotionAndSystemSetting() {
        val enabled = NativePlaybackSettings(soundEnabled = true, musicEnabled = true, hapticsEnabled = true, reducedMotionEnabled = false)
        assertTrue(HapticPolicy.shouldVibrate(enabled, true))
        assertFalse(HapticPolicy.shouldVibrate(enabled.copy(reducedMotionEnabled = true), true))
        assertFalse(HapticPolicy.shouldVibrate(enabled, false))
        assertFalse(HapticPolicy.shouldVibrate(enabled.copy(hapticsEnabled = false), true))
    }

    @Test
    public fun heartbeatHapticIsTwoPartLubDub() {
        assertEquals(160L, HeartbeatHaptic.SECONDARY_DELAY_MS)
        assertEquals(255, HeartbeatHaptic.amplitude(1.0))
        assertEquals((0.62 * 255).toInt(), HeartbeatHaptic.amplitude(1.0, 0.62))
        assertEquals(0, HeartbeatHaptic.amplitude(0.0))
    }

    @Test
    public fun freshNotificationPermissionIsRequestableAndAskedStateIsDurableTruth() {
        assertEquals(NotificationPermissionTruth.REQUESTABLE, NotificationPermissionPolicy.classify(true, false, true, false))
        assertEquals(NotificationPermissionTruth.DENIED, NotificationPermissionPolicy.classify(true, false, true, true))
        assertEquals(NotificationPermissionTruth.REQUESTABLE, NotificationPermissionPolicy.classify(true, false, false, false))
        assertEquals(NotificationPermissionTruth.BLOCKED, NotificationPermissionPolicy.classify(true, false, false, true))
        assertEquals(NotificationPermissionTruth.ALLOWED, NotificationPermissionPolicy.classify(true, true, true, true))
        assertTrue(NotificationPermissionPolicy.shouldRequest(NotificationPermissionTruth.REQUESTABLE))
        assertFalse(NotificationPermissionPolicy.shouldRequest(NotificationPermissionTruth.DENIED))
    }

    @Test
    public fun notificationTruthRecordsFirstDenialAndDeduplicatesRestartedResumeChecks() {
        val firstDenial = NotificationTruthUpdatePolicy.decide(
            currentAggregateEnabled = false,
            truth = NotificationPermissionTruth.DENIED,
            source = "system",
            receiptAlreadyPresent = false,
        ) ?: error("denial must be concrete OS truth")
        assertFalse(firstDenial.enabled)
        assertFalse(firstDenial.shouldPersistAggregate)
        assertTrue(firstDenial.shouldRecordAnalytics)
        assertEquals("notification-settings:system:blocked", firstDenial.receiptScope)

        val afterRestart = NotificationTruthUpdatePolicy.decide(
            currentAggregateEnabled = false,
            truth = NotificationPermissionTruth.DENIED,
            source = "system",
            receiptAlreadyPresent = true,
        ) ?: error("denial remains concrete OS truth")
        assertFalse(afterRestart.shouldRecordAnalytics)

        val externalGrant = NotificationTruthUpdatePolicy.decide(
            currentAggregateEnabled = false,
            truth = NotificationPermissionTruth.ALLOWED,
            source = "system",
            receiptAlreadyPresent = false,
        ) ?: error("grant must be concrete OS truth")
        assertTrue(externalGrant.enabled)
        assertTrue(externalGrant.shouldPersistAggregate)
        assertTrue(externalGrant.shouldRecordAnalytics)

        assertEquals(
            null,
            NotificationTruthUpdatePolicy.decide(false, NotificationPermissionTruth.REQUESTABLE, "system", false),
        )
        assertEquals(
            null,
            NotificationTruthUpdatePolicy.decide(false, NotificationPermissionTruth.UNAVAILABLE, "settings", false),
        )
        listOf("after_first_game", "settings", "system").forEach { source ->
            assertEquals(
                "notification-settings:$source:allowed",
                NotificationTruthUpdatePolicy.decide(false, NotificationPermissionTruth.ALLOWED, source, false)?.receiptScope,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            NotificationTruthUpdatePolicy.decide(false, NotificationPermissionTruth.ALLOWED, "permission_result", false)
        }
    }

    @Test
    public fun reminderOfferRequiresFirstGameRequestableUnaskedAndUndeclinedTruth() {
        assertTrue(
            ReminderOfferPolicy.shouldShow(
                completedGameCount = 1UL,
                truth = NotificationPermissionTruth.REQUESTABLE,
                permissionAsked = false,
                offerDeclined = false,
                aggregateEnabled = false,
            ),
        )
        assertFalse(ReminderOfferPolicy.shouldShow(0UL, NotificationPermissionTruth.REQUESTABLE, false, false, false))
        assertFalse(ReminderOfferPolicy.shouldShow(1UL, NotificationPermissionTruth.ALLOWED, false, false, false))
        assertFalse(ReminderOfferPolicy.shouldShow(1UL, NotificationPermissionTruth.DENIED, false, false, false))
        assertFalse(ReminderOfferPolicy.shouldShow(1UL, NotificationPermissionTruth.BLOCKED, false, false, false))
        assertFalse(ReminderOfferPolicy.shouldShow(1UL, NotificationPermissionTruth.REQUESTABLE, true, false, false))
        assertFalse(ReminderOfferPolicy.shouldShow(1UL, NotificationPermissionTruth.REQUESTABLE, false, true, false))
        assertFalse(ReminderOfferPolicy.shouldShow(1UL, NotificationPermissionTruth.REQUESTABLE, false, false, true))
    }

    @Test
    public fun lifeCardShareReceiptScopeStaysBoundToSelectedFrozenRecordAcrossChooserRaceAndRestart() {
        val first = LifeCardSharePayload(
            title = "card",
            text = "first",
            lines = listOf("first"),
            careerId = "career-one",
            lifeNumber = 1,
        )
        val second = first.copy(text = "second", lines = listOf("second"), careerId = "career-two", lifeNumber = 2)
        assertNotEquals(LifeCardShareReceiptScope.forPayload(first), LifeCardShareReceiptScope.forPayload(second))
        assertEquals("archive:career-one:share", LifeCardShareReceiptScope.forPayload(first))
        assertEquals("archive:career-two:share", LifeCardShareReceiptScope.forPayload(second))

        val directory = Files.createTempDirectory("phase9-share-race")
        try {
            val store = FilePlatformStateStore(directory)
            store.update { it.copy(shareCacheEpoch = 4L) }
            val restarted = FilePlatformStateStore(directory)
            assertEquals(4L, restarted.read().shareCacheEpoch)
            assertEquals("archive:career-one:share", LifeCardShareReceiptScope.forPayload(first))
            assertEquals("archive:career-two:share", LifeCardShareReceiptScope.forPayload(second))
        } finally {
            directory.toFile().deleteRecursively()
        }
    }

    @Test
    public fun notificationPermissionAskedSurvivesRestartAndResetClearsOnlyOnReset() {
        val directory = Files.createTempDirectory("phase9-notification-permission")
        try {
            val first = FilePlatformStateStore(directory)
            first.update { it.copy(notificationPermissionAsked = true) }
            assertTrue(FilePlatformStateStore(directory).read().notificationPermissionAsked)
            first.update { it.copy(reminderOfferDeclined = true) }
            assertTrue(FilePlatformStateStore(directory).read().reminderOfferDeclined)
            FilePlatformStateStore(directory).clearReminders()
            assertFalse(FilePlatformStateStore(directory).read().notificationPermissionAsked)
            assertFalse(FilePlatformStateStore(directory).read().reminderOfferDeclined)
        } finally {
            directory.toFile().deleteRecursively()
        }
    }

    @Test
    public fun externalRevokeClearsOnlyPendingSchedulesAndPreservesAskedAndOpenReceipts() {
        val store = InMemoryPlatformStateStore(
            Phase9PlatformState(
                scheduledReminderTokenHashes = listOf("scheduled"),
                notificationPermissionAsked = true,
                notificationAnalyticsTokenHashes = listOf("analytics"),
                notificationNavigationTokenHashes = listOf("navigation"),
            ),
        )
        store.update { it.copy(scheduledReminderTokenHashes = emptyList()) }
        val state = store.read()
        assertTrue(state.notificationPermissionAsked)
        assertEquals(listOf("analytics"), state.notificationAnalyticsTokenHashes)
        assertEquals(listOf("navigation"), state.notificationNavigationTokenHashes)
        assertTrue(state.scheduledReminderTokenHashes.isEmpty())
    }

    @Test
    public fun crashContextIsAllowlistedAndDynamicFieldsAreValidated() {
        val initial = CrashContext("development", "phase9", "opening", 0, "high", false, false)
        assertEquals(false, initial.unityLoaded)
        assertEquals(true, initial.copy(phase = "high_school", life = 3, qualityTier = "low", unityLoaded = true, stageReady = true).stageReady)
        assertThrows(IllegalArgumentException::class.java) { initial.copy(qualityTier = "ultra") }
        assertThrows(IllegalArgumentException::class.java) { initial.copy(life = -1) }
    }

    @Test
    public fun canonicalRootIdentityAndHashedEpochNamespaceSurviveRestartAndReplacement() {
        val root = Files.createTempDirectory("phase9-canonical-root")
        try {
            val identity = FileInstallIdentity(root) { "0123456789abcdef0123456789abcdef" }
            val installId = identity.getOrCreate()
            val first = InstallScopedPlatformStateStore(root, installId)
            first.update { it.copy(analyticsOnceReceiptIds = listOf("receipt"), scheduledReminderTokenHashes = listOf("token"), shareCacheEpoch = 4L) }
            val namespaceBefore = first.namespacePath()
            val reopened = InstallScopedPlatformStateStore(root, FileInstallIdentity(root) { "ffffffffffffffffffffffffffffffff" }.getOrCreate())
            assertEquals(listOf("receipt"), reopened.read().analyticsOnceReceiptIds)
            assertEquals(4L, reopened.read().shareCacheEpoch)
            reopened.clearScopedEpoch()
            assertNotEquals(namespaceBefore, reopened.namespacePath())
            assertTrue(reopened.read().analyticsOnceReceiptIds.isEmpty())
            assertEquals(installId, FileInstallIdentity(root) { "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" }.getOrCreate())
            assertTrue(root.resolve("anonymous-install-id-v1").toFile().isFile)
        } finally {
            root.toFile().deleteRecursively()
        }
    }

    @Test
    public fun lifeCardRendererBoundsFullContentMemoryAndUsesUniformScale() {
        val plan = NativeLifeCardRenderPolicy.plan(256)
        assertTrue(plan.outputWidth.toLong() * plan.outputHeight.toLong() <= NativeLifeCardRenderPolicy.MAX_OUTPUT_PIXELS)
        assertTrue(plan.outputHeight <= NativeLifeCardRenderPolicy.MAX_OUTPUT_HEIGHT)
        assertTrue(plan.uniformScale > 0f && plan.uniformScale <= 1f)
        assertEquals(NativeLifeCardRenderPolicy.TILE_HEIGHT, plan.tileHeight)
    }

    private class RecordingDestination(
        override val id: String,
        var fail: Boolean,
    ) : AnalyticsDestination {
        override val available: Boolean = true
        val events = mutableListOf<String>()
        override fun enqueue(event: NativeAnalyticsEvent, context: AnalyticsContext) {
            if (fail) error("destination.failure")
            events += event.receiptId
        }
        override fun flush() = Unit
        override fun clear() = Unit
    }

    private class FaultingPlatformStateStore : PlatformStateStore {
        val delegate = InMemoryPlatformStateStore()
        var failWrites: Boolean = true

        override fun read(): Phase9PlatformState = delegate.read()
        override fun write(state: Phase9PlatformState) {
            if (failWrites) error("platform.write.failed")
            delegate.write(state)
        }
        override fun update(transform: (Phase9PlatformState) -> Phase9PlatformState): Phase9PlatformState {
            if (failWrites) error("platform.update.failed")
            return delegate.update(transform)
        }
        override fun clearAnalytics() { update { it.copy(analyticsOnceReceiptIds = emptyList(), analyticsOutbox = emptyList(), knownAggregateReceiptIds = emptyList()) } }
        override fun clearReview() { update { it.copy(reviewAttempts = emptyList()) } }
        override fun clearReminders() {
            update {
                it.copy(
                    scheduledReminderTokenHashes = emptyList(),
                    notificationAnalyticsTokenHashes = emptyList(),
                    notificationNavigationTokenHashes = emptyList(),
                    notificationPermissionAsked = false,
                )
            }
        }
        override fun clearScopedEpoch() { update { it.copy(scopedEpoch = it.scopedEpoch + 1L) } }
        override fun clearShareCache() { update { it.copy(shareCacheEpoch = it.shareCacheEpoch + 1L) } }
    }
}
