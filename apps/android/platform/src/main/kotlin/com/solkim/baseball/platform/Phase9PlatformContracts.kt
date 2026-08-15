package com.solkim.baseball.platform

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.LinkOption
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.nio.file.StandardOpenOption
import java.security.SecureRandom

public const val PHASE9_PLATFORM_SCHEMA: String = "baseball-platform-state-v1"
public const val PHASE9_PLATFORM_SCHEMA_VERSION: Int = 1
public const val PHASE9_ANALYTICS_SCHEMA_VERSION: Int = 1
public const val PHASE9_ANALYTICS_OUTBOX_LIMIT: Int = 128
private const val AGGREGATE_ANALYTICS_BASELINE_MARKER: String = "platform-baseline:aggregate-v1"

/** Product analytics property values are deliberately narrower than either SDK's API. */
public sealed interface PlatformProperty {
    public data class Text(public val value: String) : PlatformProperty
    public data class Flag(public val value: Boolean) : PlatformProperty
    public data class Whole(public val value: Long) : PlatformProperty
    public data class Decimal(public val value: Double) : PlatformProperty
}

public data class NativeAnalyticsEvent(
    public val receiptId: String,
    public val eventName: String,
    public val properties: Map<String, PlatformProperty>,
) {
    init {
        require(receiptId.isNotBlank() && receiptId.length <= 160) { "analytics.receipt_id" }
        require(eventName.isNotBlank() && eventName.length <= 96) { "analytics.event_name" }
    }
}

public data class AnalyticsContext(
    public val distribution: String,
    public val appSchema: String,
    public val phase: String,
    public val platform: String = "android",
    public val environment: String = "compose-dev",
) {
    init {
        require(distribution in setOf("editor", "development", "internal", "closed", "production")) { "analytics.distribution" }
        require(appSchema.isNotBlank() && appSchema.length <= 48) { "analytics.app_schema" }
        require(phase.isNotBlank() && phase.length <= 48) { "analytics.phase" }
        require(platform == "android") { "analytics.platform" }
        require(environment.isNotBlank() && environment.length <= 48) { "analytics.environment" }
    }

    public fun properties(ingestionOrigin: String): Map<String, PlatformProperty> = mapOf(
        "app_version" to PlatformProperty.Text(appSchema),
        "build" to PlatformProperty.Text(phase),
        "distribution" to PlatformProperty.Text(distribution),
        "environment" to PlatformProperty.Text(environment),
        "platform" to PlatformProperty.Text(platform),
        "event_schema_version" to PlatformProperty.Whole(PHASE9_ANALYTICS_SCHEMA_VERSION.toLong()),
        "ingestion_origin" to PlatformProperty.Text(ingestionOrigin),
    )
}

/**
 * The event/property contract copied from the current Android/iOS matrix. Unknown events and
 * properties fail closed; the two retired Daily events remain names-only compatibility records
 * and are never emitted by product callers.
 */
public object Phase9AnalyticsSchema {
    private enum class PropertyKind { TEXT, FLAG, WHOLE, DECIMAL }
    private val commonGameFinished = setOf(
        "mode", "sequence_mastery_count", "sequence_tags", "recommendation_acceptance_rate",
        "development_rules_version", "ability_moment_count", "ability_moment_types", "life_number",
        "act_number", "result", "strikeouts", "walks", "runs", "target_batters", "batters",
    )
    private val returnPlan = setOf(
        "destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key",
        "return_day_key", "day_gap", "development_rules_version",
    )
    private val allowed: Map<String, Set<String>> = mapOf(
        "onboarding_started" to emptySet(),
        "onboarding_completed" to emptySet(),
        "first_pitch" to emptySet(),
        "activation_first_game" to emptySet(),
        "game_finished" to commonGameFinished,
        "chapter_advanced" to setOf("chapter", "act_number"),
        "draft_resolved" to setOf("drafted", "score", "life_number", "act_number"),
        "rebirth_started" to setOf("life_number", "entry_point", "selected_legacy_id", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied"),
        "life_card_shared" to setOf("life_number"),
        "life_card_share_tapped" to setOf("life_number"),
        "life_card_share_completed" to setOf("life_number"),
        "run_pledge_selected" to setOf("pledge_id", "tier", "life_number", "recommended"),
        "run_pledge_resolved" to setOf("pledge_id", "achieved", "progress_ratio", "reward_permille"),
        "career_wind_seen" to setOf("wind_id", "rules_version"),
        "next_run_intent_saved" to setOf("pledge_id", "source_life_number"),
        "next_run_intent_applied" to setOf("pledge_id", "life_number"),
        "weekly_program_opened" to setOf("week_key", "source", "completed_tasks"),
        "weekly_program_completed" to setOf("week_key", "completed_tasks", "perfect"),
        "pro_season_decision_selected" to setOf("decision_id", "choice_id", "season", "week"),
        "pro_legacy_recorded" to setOf("life_number", "pro_seasons", "soul_bonus", "has_signature_candidates"),
        "player_legacy_seen" to setOf("source", "life_number", "drafted", "has_frozen_legacy"),
        "player_heartline_seen" to setOf("branch_id", "life_number", "phase"),
        "recap_continue_tapped" to setOf("life_number", "drafted", "entry_path", "has_suggested_intent", "intent_saved"),
        "signature_legacy_options_seen" to setOf("life_number", "drafted", "includes_pro_career", "option_ids"),
        "signature_legacy_selected" to setOf("legacy_id", "family", "life_number", "drafted", "rating_growth", "includes_pro_career", "pro_seasons"),
        "signature_legacy_equipped" to setOf("legacy_id", "family", "life_number", "total_rating_bonus", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied"),
        "life_completed" to setOf("life_number", "act_number", "drafted", "evaluation", "trainings", "important_games", "pitches", "legacy_id", "legacy_rules_version", "unlocked_legacy_count", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied"),
        "career_training_completed" to setOf("life_number", "act_number", "focus_id", "intensity_id", "target_pitch_id", "growth_points", "fatigue_delta"),
        "game_growth_applied" to setOf("life_number", "act_number", "reason_id", "growth_focus", "growth_points"),
        "phase_entered" to setOf("phase", "chapter", "act_number", "life_number"),
        "game_abandoned" to setOf("pitches", "chapter", "life_number", "act_number", "phase", "development_rules_version", "games_completed"),
        "daily_inning_opened" to emptySet(),
        "daily_inning_rewarded" to emptySet(),
        "pro_career_started" to setOf("round", "evaluation", "life_number", "source"),
        "reminder_changed" to setOf("enabled", "source"),
        "reminder_offer_shown" to setOf("source"),
        "reminder_opened" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "development_rules_version"),
        "return_plan_shown" to returnPlan,
        "return_plan_tapped" to returnPlan,
        "return_plan_dismissed" to returnPlan,
        "return_plan_eligible" to returnPlan,
        "return_plan_cold_start" to returnPlan + "launch_type",
        "return_plan_next_day_open" to returnPlan + "launch_type",
        "session_ended" to setOf("minutes", "life_number", "games", "important_games_total", "phase", "act_number", "lives_finished", "return_eligible", "return_destination", "return_reason", "plan_receipt", "experiment_id", "variant", "development_rules_version"),
    )

    private val kinds: Map<String, Map<String, PropertyKind>> = mapOf(
        "game_finished" to typedKinds(wholes = setOf("sequence_mastery_count", "development_rules_version", "ability_moment_count", "life_number", "act_number", "strikeouts", "walks", "runs", "target_batters", "batters"), decimals = setOf("recommendation_acceptance_rate")),
        "chapter_advanced" to typedKinds(wholes = setOf("chapter", "act_number")),
        "draft_resolved" to typedKinds(flags = setOf("drafted"), wholes = setOf("score", "life_number", "act_number")),
        "rebirth_started" to typedKinds(wholes = setOf("life_number", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied")),
        "life_card_share_tapped" to typedKinds(wholes = setOf("life_number")),
        "run_pledge_selected" to typedKinds(flags = setOf("recommended"), wholes = setOf("life_number")),
        "run_pledge_resolved" to typedKinds(flags = setOf("achieved"), wholes = setOf("reward_permille"), decimals = setOf("progress_ratio")),
        "career_wind_seen" to typedKinds(wholes = setOf("rules_version")),
        "next_run_intent_saved" to typedKinds(wholes = setOf("source_life_number")),
        "next_run_intent_applied" to typedKinds(wholes = setOf("life_number")),
        "weekly_program_opened" to typedKinds(wholes = setOf("completed_tasks")),
        "weekly_program_completed" to typedKinds(flags = setOf("perfect"), wholes = setOf("completed_tasks")),
        "pro_season_decision_selected" to typedKinds(wholes = setOf("season", "week")),
        "pro_legacy_recorded" to typedKinds(flags = setOf("has_signature_candidates"), wholes = setOf("life_number", "pro_seasons", "soul_bonus")),
        "player_legacy_seen" to typedKinds(flags = setOf("drafted", "has_frozen_legacy"), wholes = setOf("life_number")),
        "player_heartline_seen" to typedKinds(wholes = setOf("life_number")),
        "recap_continue_tapped" to typedKinds(flags = setOf("drafted", "has_suggested_intent", "intent_saved"), wholes = setOf("life_number")),
        "signature_legacy_options_seen" to typedKinds(flags = setOf("drafted", "includes_pro_career"), wholes = setOf("life_number")),
        "signature_legacy_selected" to typedKinds(flags = setOf("drafted", "includes_pro_career"), wholes = setOf("life_number", "rating_growth", "pro_seasons")),
        "signature_legacy_equipped" to typedKinds(wholes = setOf("life_number", "total_rating_bonus", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied")),
        "life_completed" to typedKinds(flags = setOf("drafted"), wholes = setOf("life_number", "act_number", "evaluation", "trainings", "important_games", "pitches", "legacy_rules_version", "unlocked_legacy_count", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied")),
        "career_training_completed" to typedKinds(wholes = setOf("life_number", "act_number", "growth_points", "fatigue_delta")),
        "game_growth_applied" to typedKinds(wholes = setOf("life_number", "act_number", "growth_points")),
        "phase_entered" to typedKinds(wholes = setOf("chapter", "act_number", "life_number")),
        "game_abandoned" to typedKinds(wholes = setOf("pitches", "chapter", "life_number", "act_number", "development_rules_version", "games_completed")),
        "pro_career_started" to typedKinds(wholes = setOf("round", "evaluation", "life_number")),
        "reminder_changed" to typedKinds(flags = setOf("enabled")),
        "reminder_opened" to typedKinds(wholes = setOf("development_rules_version")),
        "return_plan_shown" to returnPlanTypedKinds(),
        "return_plan_tapped" to returnPlanTypedKinds(),
        "return_plan_dismissed" to returnPlanTypedKinds(),
        "return_plan_eligible" to returnPlanTypedKinds(),
        "return_plan_cold_start" to returnPlanTypedKinds(),
        "return_plan_next_day_open" to returnPlanTypedKinds(),
        "session_ended" to typedKinds(flags = setOf("return_eligible"), wholes = setOf("minutes", "life_number", "games", "important_games_total", "act_number", "lives_finished")),
    )

    private val allowedTextValues: Map<String, Map<String, Set<String>>> = mapOf(
        "game_finished" to mapOf("mode" to setOf("high_school", "pro"), "result" to setOf("scoreless", "runs_allowed")),
        "rebirth_started" to mapOf("entry_point" to setOf("setup_flow", "quick_rebirth", "customize", "completion_flow")),
        "run_pledge_selected" to mapOf("tier" to setOf("safe", "bold", "legendary")),
        "weekly_program_opened" to mapOf("source" to setOf("records")),
        "player_legacy_seen" to mapOf("source" to setOf("recap", "archive", "next_life")),
        "recap_continue_tapped" to mapOf("entry_path" to setOf("quick_rebirth", "customize", "completion_flow")),
        "signature_legacy_selected" to mapOf("family" to setOf("power", "command", "breaking", "endurance", "gamecraft", "battery")),
        "signature_legacy_equipped" to mapOf("family" to setOf("power", "command", "breaking", "endurance", "gamecraft", "battery")),
        "career_training_completed" to mapOf(
            "focus_id" to setOf("velocity", "command", "breaking_ball", "stamina", "recovery", "game_planning"),
            "intensity_id" to setOf("light", "standard", "intensive"),
            "target_pitch_id" to setOf("four_seam", "slider", "curveball", "changeup"),
        ),
        "game_growth_applied" to mapOf("reason_id" to setOf("important_game"), "growth_focus" to setOf("velocity", "command", "breaking_ball", "stamina", "recovery", "game_planning")),
        "phase_entered" to mapOf("phase" to setOf("prologue", "school_selection", "training", "relationship", "important_game", "awakening", "chapter_review", "draft", "legacy", "completed")),
        "game_abandoned" to mapOf("phase" to setOf("prologue", "school_selection", "training", "relationship", "important_game", "awakening", "chapter_review", "draft", "legacy", "completed")),
        "pro_career_started" to mapOf("source" to setOf("high_school_draft", "direct_setup")),
        "reminder_changed" to mapOf("source" to setOf("after_first_game", "settings", "system")),
        "reminder_offer_shown" to mapOf("source" to setOf("after_first_game")),
        "reminder_opened" to mapOf("destination" to setOf("high-school", "pro", "records")),
        "return_plan_shown" to mapOf("destination" to setOf("high_school", "pro", "daily_inning"), "variant" to setOf("holdout", "guided")),
        "return_plan_tapped" to mapOf("destination" to setOf("high_school", "pro", "daily_inning"), "variant" to setOf("holdout", "guided")),
        "return_plan_dismissed" to mapOf("destination" to setOf("high_school", "pro", "daily_inning"), "variant" to setOf("holdout", "guided")),
        "return_plan_eligible" to mapOf("destination" to setOf("high_school", "pro", "daily_inning"), "variant" to setOf("holdout", "guided")),
        "return_plan_cold_start" to mapOf("destination" to setOf("high_school", "pro", "daily_inning"), "variant" to setOf("holdout", "guided"), "launch_type" to setOf("cold", "warm")),
        "return_plan_next_day_open" to mapOf("destination" to setOf("high_school", "pro", "daily_inning"), "variant" to setOf("holdout", "guided"), "launch_type" to setOf("cold", "warm")),
        "session_ended" to mapOf(
            "phase" to setOf(
                "opening", "setup", "highSchool", "draft", "pro", "retirement", "legacy", "betweenLives", "deleted",
                "prologue", "school_selection", "training", "relationship", "important_game", "awakening", "chapter_review", "completed",
            ),
            "return_destination" to setOf("high_school", "pro", "daily_inning", "none"),
        ),
    )

    public val eventNames: Set<String> get() = allowed.keys
    public val retiredEventNames: Set<String> = setOf("daily_inning_opened", "daily_inning_rewarded")
    /** Historical compatibility names kept in the schema but forbidden at the native boundary. */
    public val intentionalZeroCallerEventNames: Set<String> = setOf(
        "life_card_shared",
        "life_card_share_completed",
        "daily_inning_opened",
        "daily_inning_rewarded",
    )

    public fun validate(eventName: String, properties: Map<String, PlatformProperty>): Map<String, PlatformProperty> {
        require(eventName in allowed) { "analytics.event_unknown:$eventName" }
        require(eventName !in retiredEventNames) { "analytics.event_retired:$eventName" }
        require(eventName !in intentionalZeroCallerEventNames) { "analytics.zero_caller:$eventName" }
        require(properties.size <= 24) { "analytics.property_count" }
        val permitted = allowed.getValue(eventName)
        val result = linkedMapOf<String, PlatformProperty>()
        properties.toSortedMap().forEach { (key, value) ->
            require(key.matches(Regex("[a-z][a-z0-9_]{0,47}"))) { "analytics.property_key:$key" }
            require(key !in RESERVED_CONTEXT_KEYS) { "analytics.property_reserved:$key" }
            require(key !in FORBIDDEN_KEYS) { "analytics.property_forbidden:$key" }
            require(key in permitted) { "analytics.property_unexpected:$eventName:$key" }
            when (value) {
                is PlatformProperty.Text -> {
                    require(value.value.length <= 64) { "analytics.property_text_length:$key" }
                    allowedTextValues[eventName]?.get(key)?.let { allowed ->
                        require(value.value in allowed) { "analytics.property_text_value:$eventName:$key" }
                    }
                }
                is PlatformProperty.Flag -> Unit
                is PlatformProperty.Whole -> Unit
                is PlatformProperty.Decimal -> require(value.value.isFinite()) { "analytics.property_decimal:$key" }
            }
            when (kinds[eventName]?.get(key) ?: PropertyKind.TEXT) {
                PropertyKind.TEXT -> require(value is PlatformProperty.Text) { "analytics.property_type:$eventName:$key" }
                PropertyKind.FLAG -> require(value is PlatformProperty.Flag) { "analytics.property_type:$eventName:$key" }
                PropertyKind.WHOLE -> require(value is PlatformProperty.Whole) { "analytics.property_type:$eventName:$key" }
                PropertyKind.DECIMAL -> require(value is PlatformProperty.Decimal) { "analytics.property_type:$eventName:$key" }
            }
            result[key] = value
        }
        return result
    }

    public fun fromStrings(eventName: String, properties: List<Pair<String, String>>): NativeAnalyticsEvent =
        fromStrings("unbound", eventName, properties)

    /** Converts the aggregate's compatibility strings using the frozen event/key kind. */
    public fun fromStrings(receiptId: String, eventName: String, properties: List<Pair<String, String>>): NativeAnalyticsEvent {
        require(properties.map { it.first }.distinct().size == properties.size) { "analytics.properties_duplicate" }
        val parsed = properties.associate { (key, value) -> key to parseStringValue(eventName, key, value) }
        return NativeAnalyticsEvent(receiptId, eventName, validate(eventName, parsed))
    }

    private fun parseStringValue(eventName: String, key: String, value: String): PlatformProperty = when (kinds[eventName]?.get(key) ?: PropertyKind.TEXT) {
        PropertyKind.TEXT -> PlatformProperty.Text(value)
        PropertyKind.FLAG -> when (value) {
            "true" -> PlatformProperty.Flag(true)
            "false" -> PlatformProperty.Flag(false)
            else -> throw IllegalArgumentException("analytics.property_flag:$key")
        }
        PropertyKind.WHOLE -> value.takeIf { it.matches(Regex("-?[0-9]+")) }?.toLongOrNull()?.let(PlatformProperty::Whole)
            ?: throw IllegalArgumentException("analytics.property_whole:$key")
        PropertyKind.DECIMAL -> value.takeIf { it.matches(Regex("-?[0-9]+\\.[0-9]+")) }?.toDoubleOrNull()?.takeIf(Double::isFinite)?.let(PlatformProperty::Decimal)
            ?: throw IllegalArgumentException("analytics.property_decimal:$key")
    }

    private val RESERVED_CONTEXT_KEYS = setOf("app_version", "build", "distribution", "environment", "platform", "event_schema_version", "ingestion_origin")
    private val FORBIDDEN_KEYS = setOf("name", "player_name", "user_name", "seed", "raw_seed", "career_id", "save", "save_json", "free_text", "message", "file_name", "filename", "path", "email", "phone", "latitude", "longitude", "location", "android_id", "advertising_id", "ad_id", "idfa", "image", "share_image")

    private fun typedKinds(
        flags: Set<String> = emptySet(),
        wholes: Set<String> = emptySet(),
        decimals: Set<String> = emptySet(),
    ): Map<String, PropertyKind> = buildMap {
        flags.forEach { put(it, PropertyKind.FLAG) }
        wholes.forEach { put(it, PropertyKind.WHOLE) }
        decimals.forEach { put(it, PropertyKind.DECIMAL) }
    }

    private fun returnPlanTypedKinds(): Map<String, PropertyKind> = typedKinds(wholes = setOf("day_gap", "development_rules_version"))
}

public data class AnalyticsOutboxRecord(
    public val event: NativeAnalyticsEvent,
    public val deliveredDestinations: Set<String> = emptySet(),
) {
    init { require(event.receiptId.isNotBlank()) { "analytics.outbox_receipt" } }
}

public data class ReviewAttempt(
    public val reason: String,
    public val attemptedAtUtcMillis: Long,
)

public data class Phase9PlatformState(
    public val schema: String = PHASE9_PLATFORM_SCHEMA,
    public val schemaVersion: Int = PHASE9_PLATFORM_SCHEMA_VERSION,
    public val scopedEpoch: Long = 0L,
    public val analyticsOnceReceiptIds: List<String> = emptyList(),
    public val analyticsOutbox: List<AnalyticsOutboxRecord> = emptyList(),
    public val knownAggregateReceiptIds: List<String> = emptyList(),
    public val scheduledReminderTokenHashes: List<String> = emptyList(),
    public val notificationAnalyticsTokenHashes: List<String> = emptyList(),
    public val notificationNavigationTokenHashes: List<String> = emptyList(),
    /** API 33+ request has been shown at least once; OS truth is still read independently. */
    public val notificationPermissionAsked: Boolean = false,
    /** Durable product-offer dismissal; separate from OS permission truth. */
    public val reminderOfferDeclined: Boolean = false,
    public val reviewAttempts: List<ReviewAttempt> = emptyList(),
    public val shareCacheEpoch: Long = 0L,
) {
    public fun validate() {
        require(schema == PHASE9_PLATFORM_SCHEMA && schemaVersion == PHASE9_PLATFORM_SCHEMA_VERSION) { "platform.schema" }
        require(scopedEpoch >= 0L && shareCacheEpoch >= 0L) { "platform.epoch" }
        listOf(analyticsOnceReceiptIds, knownAggregateReceiptIds, scheduledReminderTokenHashes, notificationAnalyticsTokenHashes, notificationNavigationTokenHashes)
            .forEach { values -> require(values.distinct().size == values.size && values.all { it.isNotBlank() }) { "platform.receipts" } }
        require(analyticsOutbox.size <= PHASE9_ANALYTICS_OUTBOX_LIMIT) { "platform.outbox_limit" }
        require(analyticsOutbox.map { it.event.receiptId }.distinct().size == analyticsOutbox.size) { "platform.outbox_duplicate" }
        require(reviewAttempts.map { it.reason }.distinct().size == reviewAttempts.size) { "platform.review_duplicate" }
        require(reviewAttempts.all { it.reason.isNotBlank() && it.attemptedAtUtcMillis >= 0L }) { "platform.review_attempt" }
    }
}

public interface PlatformStateStore {
    public fun read(): Phase9PlatformState
    public fun write(state: Phase9PlatformState)
    public fun update(transform: (Phase9PlatformState) -> Phase9PlatformState): Phase9PlatformState
    public fun clearAnalytics()
    public fun clearReview()
    public fun clearReminders()
    public fun clearScopedEpoch()
    public fun clearShareCache()
}

public class InMemoryPlatformStateStore(initial: Phase9PlatformState = Phase9PlatformState()) : PlatformStateStore {
    private var current = initial.also { it.validate() }
    @Synchronized override fun read(): Phase9PlatformState = current
    @Synchronized override fun write(state: Phase9PlatformState) { state.validate(); current = state }
    @Synchronized override fun update(transform: (Phase9PlatformState) -> Phase9PlatformState): Phase9PlatformState {
        val next = transform(current).also { it.validate() }
        current = next
        return next
    }
    override fun clearAnalytics() { update { it.copy(analyticsOnceReceiptIds = emptyList(), analyticsOutbox = emptyList(), knownAggregateReceiptIds = emptyList()) } }
    override fun clearReview() { update { it.copy(reviewAttempts = emptyList()) } }
    override fun clearReminders() { update { it.copy(scheduledReminderTokenHashes = emptyList(), notificationAnalyticsTokenHashes = emptyList(), notificationNavigationTokenHashes = emptyList(), notificationPermissionAsked = false, reminderOfferDeclined = false) } }
    override fun clearScopedEpoch() { update { it.copy(scopedEpoch = it.scopedEpoch + 1L) } }
    override fun clearShareCache() { update { it.copy(shareCacheEpoch = it.shareCacheEpoch + 1L) } }
}

public object Phase9PlatformStateCodec {
    public fun encode(state: Phase9PlatformState): ByteArray {
        state.validate()
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(state.schema),
            "schemaVersion" to JsonValue.Num(state.schemaVersion.toString()),
            "scopedEpoch" to JsonValue.Num(state.scopedEpoch.toString()),
            "analyticsOnceReceiptIds" to JsonValue.Arr(state.analyticsOnceReceiptIds.map(JsonValue::Str)),
            "analyticsOutbox" to JsonValue.Arr(state.analyticsOutbox.map(::encodeOutbox)),
            "knownAggregateReceiptIds" to JsonValue.Arr(state.knownAggregateReceiptIds.map(JsonValue::Str)),
            "scheduledReminderTokenHashes" to JsonValue.Arr(state.scheduledReminderTokenHashes.map(JsonValue::Str)),
            "notificationAnalyticsTokenHashes" to JsonValue.Arr(state.notificationAnalyticsTokenHashes.map(JsonValue::Str)),
            "notificationNavigationTokenHashes" to JsonValue.Arr(state.notificationNavigationTokenHashes.map(JsonValue::Str)),
            "notificationPermissionAsked" to JsonValue.Bool(state.notificationPermissionAsked),
            "reminderOfferDeclined" to JsonValue.Bool(state.reminderOfferDeclined),
            "reviewAttempts" to JsonValue.Arr(state.reviewAttempts.map { JsonValue.Obj(linkedMapOf("reason" to JsonValue.Str(it.reason), "attemptedAtUtcMillis" to JsonValue.Num(it.attemptedAtUtcMillis.toString()))) }),
            "shareCacheEpoch" to JsonValue.Num(state.shareCacheEpoch.toString()),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): Phase9PlatformState {
        val root = StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: error("platform.root")
        val required = setOf("schema", "schemaVersion", "scopedEpoch", "analyticsOnceReceiptIds", "analyticsOutbox", "knownAggregateReceiptIds", "scheduledReminderTokenHashes", "notificationAnalyticsTokenHashes", "notificationNavigationTokenHashes", "reviewAttempts", "shareCacheEpoch")
        val legacyCurrent = required + "notificationPermissionAsked"
        val current = legacyCurrent + "reminderOfferDeclined"
        require(root.entries.keys == current || root.entries.keys == legacyCurrent || root.entries.keys == required) { "platform.fields" }
        val state = Phase9PlatformState(
            schema = root.string("schema"),
            schemaVersion = root.integer("schemaVersion"),
            scopedEpoch = root.long("scopedEpoch"),
            analyticsOnceReceiptIds = root.strings("analyticsOnceReceiptIds"),
            analyticsOutbox = root.array("analyticsOutbox").mapIndexed { index, value -> decodeOutbox(value as? JsonValue.Obj ?: error("platform.outbox[$index]")) },
            knownAggregateReceiptIds = root.strings("knownAggregateReceiptIds"),
            scheduledReminderTokenHashes = root.strings("scheduledReminderTokenHashes"),
            notificationAnalyticsTokenHashes = root.strings("notificationAnalyticsTokenHashes"),
            notificationNavigationTokenHashes = root.strings("notificationNavigationTokenHashes"),
            notificationPermissionAsked = (root["notificationPermissionAsked"] as? JsonValue.Bool)?.value ?: false,
            reminderOfferDeclined = (root["reminderOfferDeclined"] as? JsonValue.Bool)?.value ?: false,
            reviewAttempts = root.array("reviewAttempts").mapIndexed { index, value ->
                val item = value as? JsonValue.Obj ?: error("platform.review[$index]")
                requireExact(item, setOf("reason", "attemptedAtUtcMillis"), "platform.review")
                ReviewAttempt(item.string("reason"), item.long("attemptedAtUtcMillis"))
            },
            shareCacheEpoch = root.long("shareCacheEpoch"),
        ).also { it.validate() }
        if (root.entries.keys == current) require(bytes.contentEquals(encode(state))) { "platform.noncanonical" }
        return state
    }

    private fun encodeOutbox(value: AnalyticsOutboxRecord): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "receiptId" to JsonValue.Str(value.event.receiptId),
        "eventName" to JsonValue.Str(value.event.eventName),
        "properties" to JsonValue.Obj(value.event.properties.toSortedMap().mapValuesTo(LinkedHashMap()) { (_, property) -> encodeProperty(property) }),
        "deliveredDestinations" to JsonValue.Arr(value.deliveredDestinations.sorted().map(JsonValue::Str)),
    ))

    private fun decodeOutbox(value: JsonValue.Obj): AnalyticsOutboxRecord {
        requireExact(value, setOf("receiptId", "eventName", "properties", "deliveredDestinations"), "platform.outbox")
        val propertiesObject = value["properties"] as? JsonValue.Obj ?: error("platform.outbox.properties")
        val properties = propertiesObject.entries.mapValues { (_, property) -> decodeProperty(property) }
        val event = NativeAnalyticsEvent(value.string("receiptId"), value.string("eventName"), properties)
        val delivered = value.array("deliveredDestinations").map { (it as? JsonValue.Str)?.value ?: error("platform.outbox.destination") }.toSet()
        return AnalyticsOutboxRecord(event, delivered)
    }

    private fun encodeProperty(value: PlatformProperty): JsonValue.Obj = when (value) {
        is PlatformProperty.Text -> JsonValue.Obj(linkedMapOf("kind" to JsonValue.Str("text"), "value" to JsonValue.Str(value.value)))
        is PlatformProperty.Flag -> JsonValue.Obj(linkedMapOf("kind" to JsonValue.Str("flag"), "value" to JsonValue.Bool(value.value)))
        is PlatformProperty.Whole -> JsonValue.Obj(linkedMapOf("kind" to JsonValue.Str("whole"), "value" to JsonValue.Num(value.value.toString())))
        is PlatformProperty.Decimal -> JsonValue.Obj(linkedMapOf("kind" to JsonValue.Str("decimal"), "value" to JsonValue.Num(value.value.toString())))
    }

    private fun decodeProperty(value: JsonValue): PlatformProperty {
        val item = value as? JsonValue.Obj ?: error("platform.property")
        requireExact(item, setOf("kind", "value"), "platform.property")
        return when (item.string("kind")) {
            "text" -> PlatformProperty.Text((item["value"] as? JsonValue.Str)?.value ?: error("platform.property.text"))
            "flag" -> PlatformProperty.Flag((item["value"] as? JsonValue.Bool)?.value ?: error("platform.property.flag"))
            "whole" -> PlatformProperty.Whole(item.long("value"))
            "decimal" -> PlatformProperty.Decimal((item["value"] as? JsonValue.Num)?.raw?.toDoubleOrNull() ?: error("platform.property.decimal"))
            else -> error("platform.property.kind")
        }
    }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        require(value.entries.keys == expected) { "$field.fields" }
    }
    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: error("platform.$name.string")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: error("platform.$name.integer")
    private fun JsonValue.Obj.long(name: String): Long = (this[name] as? JsonValue.Num)?.raw?.toLongOrNull() ?: error("platform.$name.long")
    private fun JsonValue.Obj.array(name: String): List<JsonValue> = (this[name] as? JsonValue.Arr)?.values ?: error("platform.$name.array")
    private fun JsonValue.Obj.strings(name: String): List<String> = array(name).map { (it as? JsonValue.Str)?.value ?: error("platform.$name.string") }
}

public class FilePlatformStateStore(
    private val directory: Path,
) : PlatformStateStore {
    private val path = directory.resolve("platform-state-v1.json")
    private val temp = directory.resolve("platform-state-v1.json.tmp")
    private val lock = Any()

    override fun read(): Phase9PlatformState = synchronized(lock) {
        if (!Files.exists(path, LinkOption.NOFOLLOW_LINKS)) return@synchronized Phase9PlatformState()
        Phase9PlatformStateCodec.decode(Files.readAllBytes(path))
    }

    override fun write(state: Phase9PlatformState) = synchronized(lock) {
        state.validate()
        Files.createDirectories(directory)
        writeAndSync(temp, Phase9PlatformStateCodec.encode(state))
        try {
            Files.move(temp, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(temp, path, StandardCopyOption.REPLACE_EXISTING)
        }
        // The file is the durable boundary. Directory fsync is best effort because Android's
        // filesystem providers do not all expose a forceable directory channel.
        runCatching { FileChannel.open(directory, StandardOpenOption.READ).use { it.force(true) } }
        check(Phase9PlatformStateCodec.decode(Files.readAllBytes(path)) == state) { "platform.read_back" }
    }

    private fun writeAndSync(target: Path, bytes: ByteArray) {
        FileChannel.open(target, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE).use { channel ->
            var offset = 0
            while (offset < bytes.size) offset += channel.write(ByteBuffer.wrap(bytes, offset, bytes.size - offset))
            channel.force(true)
        }
    }

    override fun update(transform: (Phase9PlatformState) -> Phase9PlatformState): Phase9PlatformState = synchronized(lock) {
        val next = transform(read()).also { it.validate() }
        write(next)
        next
    }

    override fun clearAnalytics() { update { it.copy(analyticsOnceReceiptIds = emptyList(), analyticsOutbox = emptyList(), knownAggregateReceiptIds = emptyList()) } }
    override fun clearReview() { update { it.copy(reviewAttempts = emptyList()) } }
    override fun clearReminders() { update { it.copy(scheduledReminderTokenHashes = emptyList(), notificationAnalyticsTokenHashes = emptyList(), notificationNavigationTokenHashes = emptyList(), notificationPermissionAsked = false, reminderOfferDeclined = false) } }
    override fun clearScopedEpoch() { update { it.copy(scopedEpoch = it.scopedEpoch + 1L) } }
    override fun clearShareCache() { update { it.copy(shareCacheEpoch = it.shareCacheEpoch + 1L) } }
}

/**
 * Install-scoped platform state. The anonymous ID remains at the canonical no-backup root;
 * every reset epoch gets a separate hashed namespace so stale alarms, SDK receipts, and share
 * tokens cannot cross an irrevocable reset.
 */
public class InstallScopedPlatformStateStore(
    private val root: Path,
    private val installId: String,
) : PlatformStateStore {
    private val lock = Any()
    private val epochPath = root.resolve("platform-scope-epoch-v1")

    init {
        InstallIdentityContract.validate(installId)
        Files.createDirectories(root)
        if (!Files.exists(epochPath, LinkOption.NOFOLLOW_LINKS)) writeEpoch(0L)
        require(readEpoch() >= 0L) { "platform.epoch" }
    }

    public fun namespacePath(): Path = namespacePath(readEpoch())

    private fun namespacePath(epoch: Long): Path = root.resolve(
        "platform-state-${InstallIdentityContract.scopeHash(installId, epoch, "platform-state").take(32)}",
    )

    private fun delegate(epoch: Long = readEpoch()): FilePlatformStateStore = FilePlatformStateStore(namespacePath(epoch))

    override fun read(): Phase9PlatformState = synchronized(lock) {
        val epoch = readEpoch()
        val state = delegate(epoch).read()
        if (state.scopedEpoch == epoch) state else state.copy(scopedEpoch = epoch)
    }

    override fun write(state: Phase9PlatformState) = synchronized(lock) {
        val epoch = readEpoch()
        require(state.scopedEpoch == epoch) { "platform.epoch_mismatch" }
        delegate(epoch).write(state)
    }

    override fun update(transform: (Phase9PlatformState) -> Phase9PlatformState): Phase9PlatformState = synchronized(lock) {
        val epoch = readEpoch()
        val next = transform(delegate(epoch).read()).copy(scopedEpoch = epoch)
        delegate(epoch).write(next)
        next
    }

    override fun clearAnalytics() {
        update { it.copy(analyticsOnceReceiptIds = emptyList(), analyticsOutbox = emptyList(), knownAggregateReceiptIds = emptyList()) }
    }

    override fun clearReview() {
        update { it.copy(reviewAttempts = emptyList()) }
    }

    override fun clearReminders() {
        update {
            it.copy(
                scheduledReminderTokenHashes = emptyList(),
                notificationAnalyticsTokenHashes = emptyList(),
                notificationNavigationTokenHashes = emptyList(),
                notificationPermissionAsked = false,
                reminderOfferDeclined = false,
            )
        }
    }

    override fun clearScopedEpoch() {
        synchronized(lock) {
            val next = readEpoch() + 1L
            writeEpoch(next)
            delegate(next).write(Phase9PlatformState(scopedEpoch = next))
        }
    }

    override fun clearShareCache() {
        update { it.copy(shareCacheEpoch = it.shareCacheEpoch + 1L) }
    }

    private fun readEpoch(): Long = String(Files.readAllBytes(epochPath), Charsets.UTF_8).trim().toLongOrNull()
        ?: error("platform.epoch_wire")

    private fun writeEpoch(epoch: Long) {
        require(epoch >= 0L) { "platform.epoch" }
        val temp = root.resolve("platform-scope-epoch-v1.tmp")
        FileChannel.open(temp, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE).use { channel ->
            val bytes = epoch.toString().toByteArray(Charsets.UTF_8)
            channel.write(ByteBuffer.wrap(bytes))
            channel.force(true)
        }
        try {
            Files.move(temp, epochPath, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(temp, epochPath, StandardCopyOption.REPLACE_EXISTING)
        }
        runCatching { FileChannel.open(root, StandardOpenOption.READ).use { it.force(true) } }
        check(String(Files.readAllBytes(epochPath), Charsets.UTF_8).trim() == epoch.toString()) { "platform.epoch_read_back" }
    }
}

public interface AnalyticsDestination {
    public val id: String
    public val available: Boolean
    public fun enqueue(event: NativeAnalyticsEvent, context: AnalyticsContext)
    public fun flush()
    public fun clear()
}

public class NativeAnalyticsService(
    private val stateStore: PlatformStateStore,
    private val destinations: List<AnalyticsDestination>,
    private val context: AnalyticsContext,
) {
    private val lock = Any()

    public val availableDestinationIds: Set<String> get() = synchronized(lock) { destinations.filter { it.available }.map { it.id }.toSet() }

    public fun publish(receipts: List<NativeAnalyticsEvent>) {
        synchronized(lock) {
            receipts.distinctBy { it.receiptId }.forEach { receipt ->
                val valid = try {
                    NativeAnalyticsEvent(receipt.receiptId, receipt.eventName, Phase9AnalyticsSchema.validate(receipt.eventName, receipt.properties))
                } catch (_: IllegalArgumentException) {
                    return@forEach
                }
                if (valid.eventName in Phase9AnalyticsSchema.retiredEventNames) return@forEach
                val current = stateStore.read()
                if (valid.receiptId in current.analyticsOnceReceiptIds) return@forEach
                // The aggregate store may already contain receipts from before this process
                // attached. Its durable baseline is a hard replay boundary, independent of the
                // SDK delivery receipts below.
                if (valid.receiptId in current.knownAggregateReceiptIds) return@forEach
                val existing = current.analyticsOutbox.firstOrNull { it.event.receiptId == valid.receiptId }
                if (existing == null) {
                    stateStore.update { state ->
                        if (state.analyticsOutbox.any { it.event.receiptId == valid.receiptId }) state
                        else state.copy(
                            analyticsOutbox = (state.analyticsOutbox + AnalyticsOutboxRecord(valid)).takeLast(PHASE9_ANALYTICS_OUTBOX_LIMIT),
                            knownAggregateReceiptIds = (state.knownAggregateReceiptIds + valid.receiptId).distinct(),
                        )
                    }
                }
            }
            retryOutboxLocked()
        }
    }

    public fun retryOutbox() = synchronized(lock) { retryOutboxLocked() }

    public fun pendingOutbox(): List<AnalyticsOutboxRecord> = synchronized(lock) { stateStore.read().analyticsOutbox }

    /** IDs durably accepted by the native handoff, including an undelivered retryable outbox. */
    public fun durableReceiptIds(): Set<String> = synchronized(lock) {
        val state = stateStore.read()
        (state.analyticsOnceReceiptIds + state.analyticsOutbox.map { it.event.receiptId } + state.knownAggregateReceiptIds).toSet()
    }

    /** The aggregate store owns the durable receipt; this stores the restart baseline only. */
    public fun establishAggregateBaseline(receiptIds: Collection<String>) {
        synchronized(lock) {
            stateStore.update { state ->
                if (AGGREGATE_ANALYTICS_BASELINE_MARKER in state.knownAggregateReceiptIds) state
                else state.copy(
                    knownAggregateReceiptIds = (state.knownAggregateReceiptIds + AGGREGATE_ANALYTICS_BASELINE_MARKER + receiptIds).distinct(),
                )
            }
        }
    }

    public fun clear() = synchronized(lock) { destinations.forEach { runCatching { it.clear() } }; stateStore.clearAnalytics() }

    private fun retryOutboxLocked() {
        val active = destinations.filter { it.available }
        if (active.isEmpty()) return
        stateStore.read().analyticsOutbox.forEach { record ->
            var delivered = record.deliveredDestinations
            active.filter { it.id !in delivered }.forEach { destination ->
                try {
                    destination.enqueue(record.event, context)
                    delivered = delivered + destination.id
                } catch (_: Throwable) {
                    // Keep this receipt durable and retryable. SDK failure is never a game failure.
                }
            }
            stateStore.update { state ->
                val current = state.analyticsOutbox.firstOrNull { it.event.receiptId == record.event.receiptId }
                    ?: return@update state
                val nextRecord = current.copy(deliveredDestinations = delivered)
                val complete = active.all { it.id in delivered }
                state.copy(
                    analyticsOnceReceiptIds = if (complete) (state.analyticsOnceReceiptIds + record.event.receiptId).distinct() else state.analyticsOnceReceiptIds,
                    analyticsOutbox = if (complete) state.analyticsOutbox.filterNot { it.event.receiptId == record.event.receiptId } else state.analyticsOutbox.map { if (it.event.receiptId == record.event.receiptId) nextRecord else it },
                )
            }
        }
    }
}

public object StableNotificationToken {
    public fun hash(rawToken: String): String {
        require(rawToken.isNotBlank() && rawToken.length <= 256) { "notification.token" }
        return Hashing.sha256Hex(rawToken).take(32)
    }
}

public enum class NotificationDestination(public val wire: String) {
    HIGH_SCHOOL("high-school"),
    PRO("pro"),
    RECORDS("records"),
}

public data class NormalizedNotificationOpen(
    public val tokenHash: String,
    public val destination: NotificationDestination,
    public val reason: String,
    public val planReceipt: String,
) {
    init {
        require(tokenHash.matches(Regex("[0-9a-f]{32}"))) { "notification.token_hash" }
        require(reason.isNotBlank() && reason.length <= 64) { "notification.reason" }
        require(planReceipt.isNotBlank() && planReceipt.length <= 64) { "notification.plan_receipt" }
    }
}

public object NotificationIntentNormalizer {
    public const val ACTION_OPEN_REMINDER: String = "com.solkim.baseball.action.OPEN_REMINDER"
    public const val EXTRA_TOKEN: String = "baseball.notification.token"
    public const val EXTRA_DESTINATION: String = "baseball.notification.destination"
    public const val EXTRA_REASON: String = "baseball.notification.reason"
    public const val EXTRA_PLAN_RECEIPT: String = "baseball.notification.plan_receipt"

    public fun normalize(action: String?, rawToken: String?, rawDestination: String?, reason: String?, planReceipt: String?): NormalizedNotificationOpen? {
        if (action != ACTION_OPEN_REMINDER || rawToken.isNullOrBlank()) return null
        val destination = when (rawDestination?.lowercase()) {
            null, "high-school", "high_school", "current-career", "daily", "daily-inning", "daily_inning", "p-023", "p023" -> NotificationDestination.HIGH_SCHOOL
            "pro" -> NotificationDestination.PRO
            "records", "record" -> NotificationDestination.RECORDS
            else -> return null
        }
        val normalizedReason = reason?.takeIf { it.isNotBlank() } ?: "return_plan"
        val normalizedPlanReceipt = planReceipt?.takeIf { it.isNotBlank() } ?: StableNotificationToken.hash(rawToken)
        return NormalizedNotificationOpen(StableNotificationToken.hash(rawToken), destination, normalizedReason, normalizedPlanReceipt)
    }
}

public data class NotificationRecovery(
    public val open: NormalizedNotificationOpen,
    public val shouldEmitAnalytics: Boolean,
    public val shouldNavigate: Boolean,
)

public class NotificationOpenCoordinator(private val stateStore: PlatformStateStore) {
    public fun inspect(open: NormalizedNotificationOpen): NotificationRecovery = synchronized(stateStore) {
        val current = stateStore.read()
        require(open.tokenHash in current.scheduledReminderTokenHashes) { "notification.unscheduled" }
        val alreadyLogged = open.tokenHash in current.notificationAnalyticsTokenHashes
        val alreadyNavigated = open.tokenHash in current.notificationNavigationTokenHashes
        NotificationRecovery(open, !alreadyLogged, !alreadyNavigated)
    }

    public fun markAnalyticsReceipt(tokenHash: String) {
        require(tokenHash.matches(Regex("[0-9a-f]{32}"))) { "notification.token_hash" }
        stateStore.update { state ->
            if (tokenHash in state.notificationAnalyticsTokenHashes) state
            else state.copy(notificationAnalyticsTokenHashes = state.notificationAnalyticsTokenHashes + tokenHash)
        }
    }

    public fun onOpen(open: NormalizedNotificationOpen): NotificationRecovery = synchronized(stateStore) {
        val recovery = inspect(open)
        if (recovery.shouldEmitAnalytics) markAnalyticsReceipt(open.tokenHash)
        recovery
    }

    public fun markNavigationCompleted(tokenHash: String) {
        require(tokenHash.matches(Regex("[0-9a-f]{32}"))) { "notification.token_hash" }
        stateStore.update { state ->
            if (tokenHash in state.notificationNavigationTokenHashes) state
            else state.copy(notificationNavigationTokenHashes = state.notificationNavigationTokenHashes + tokenHash)
        }
    }
}

public enum class ReviewReason(public val wire: String) {
    THIRD_LIFE("third-life"),
    GOOD_RECAP("good-recap"),
    DRAFTED_REVEAL_CONFIRMED("drafted-reveal-confirmed"),
}

public data class ReviewGateDecision(public val eligible: Boolean, public val reason: String)

public class ReviewGate(private val stateStore: PlatformStateStore, private val clock: () -> Long = { System.currentTimeMillis() }) {
    public fun canRequest(reason: ReviewReason): ReviewGateDecision {
        val state = stateStore.read()
        if (state.reviewAttempts.any { it.reason == reason.wire }) return ReviewGateDecision(false, "reason_already_attempted")
        val last = state.reviewAttempts.maxOfOrNull { it.attemptedAtUtcMillis }
        if (last != null && clock() - last < 24L * 60L * 60L * 1000L) return ReviewGateDecision(false, "within_24_hours")
        return ReviewGateDecision(true, "eligible")
    }

    public fun reserve(reason: ReviewReason): ReviewGateDecision {
        val decision = canRequest(reason)
        if (decision.eligible) stateStore.update { it.copy(reviewAttempts = it.reviewAttempts + ReviewAttempt(reason.wire, clock())) }
        return decision
    }

    public fun clear() = stateStore.clearReview()
}

public enum class PlatformAction(public val wire: String) {
    REQUEST_NOTIFICATION_PERMISSION("request-notification-permission"),
    DISMISS_REMINDER_OFFER("dismiss-reminder-offer"),
    OPEN_NOTIFICATION_SETTINGS("open-notification-settings"),
    SHARE_LIFE_CARD("share-life-card"),
    REQUEST_REVIEW("request-review"),
}

public data class PlatformActionPayload(
    public val screenWire: String,
    public val action: PlatformAction,
    public val expectedRevision: ULong,
    public val stateCommitment: String,
    public val parameterHash: String,
) {
    init {
        require(screenWire.isNotBlank() && screenWire.length <= 64) { "platform.action.screen" }
        require(stateCommitment.matches(Regex("[0-9a-f]{16}"))) { "platform.action.commitment" }
        require(parameterHash.matches(Regex("[0-9a-f]{64}"))) { "platform.action.parameter_hash" }
    }
}

public object PlatformActionCodec {
    public fun encode(payload: PlatformActionPayload): String = StrictJson.canonical(JsonValue.Obj(linkedMapOf(
        "screen" to JsonValue.Str(payload.screenWire),
        "action" to JsonValue.Str(payload.action.wire),
        "expectedRevision" to JsonValue.Num(payload.expectedRevision.toString()),
        "stateCommitment" to JsonValue.Str(payload.stateCommitment),
        "parameterHash" to JsonValue.Str(payload.parameterHash),
    )))

    public fun decode(encoded: String): PlatformActionPayload {
        val root = StrictJson.parse(encoded) as? JsonValue.Obj ?: error("platform.action.root")
        require(root.entries.keys == setOf("screen", "action", "expectedRevision", "stateCommitment", "parameterHash")) { "platform.action.fields" }
        val action = PlatformAction.entries.firstOrNull { it.wire == (root["action"] as? JsonValue.Str)?.value } ?: error("platform.action.unknown")
        val revision = (root["expectedRevision"] as? JsonValue.Num)?.raw?.toULongOrNull() ?: error("platform.action.revision")
        return PlatformActionPayload(
            screenWire = (root["screen"] as? JsonValue.Str)?.value ?: error("platform.action.screen"),
            action = action,
            expectedRevision = revision,
            stateCommitment = (root["stateCommitment"] as? JsonValue.Str)?.value ?: error("platform.action.commitment"),
            parameterHash = (root["parameterHash"] as? JsonValue.Str)?.value ?: error("platform.action.parameter_hash"),
        )
    }

    public fun parameterHash(parameters: Map<String, String>): String = Hashing.sha256Hex(parameters.toSortedMap().entries.joinToString("&") { "${it.key}=${it.value}" })
}

public object InstallIdentityContract {
    public val pattern: Regex = Regex("[0-9a-f]{32}")
    public fun validate(value: String): String = value.also { require(pattern.matches(it)) { "install.identity" } }
    public fun candidate(random: SecureRandom = SecureRandom()): String = ByteArray(16).also(random::nextBytes).joinToString("") { "%02x".format(it) }
    public fun scopeHash(installId: String, epoch: Long, scope: String): String {
        validate(installId)
        require(epoch >= 0L && scope.isNotBlank()) { "install.scope" }
        return Hashing.sha256Hex("$installId|$epoch|$scope")
    }
}

public class FileInstallIdentity(
    private val directory: Path,
    private val candidateFactory: () -> String = { InstallIdentityContract.candidate() },
) {
    private val path = directory.resolve("anonymous-install-id-v1")
    private val temp = directory.resolve("anonymous-install-id-v1.tmp")

    public fun getOrCreate(): String {
        if (Files.exists(path, LinkOption.NOFOLLOW_LINKS)) return InstallIdentityContract.validate(String(Files.readAllBytes(path), Charsets.UTF_8).trim())
        val candidate = InstallIdentityContract.validate(candidateFactory())
        Files.createDirectories(directory)
        FileChannel.open(temp, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE).use { channel ->
            val bytes = candidate.toByteArray(Charsets.UTF_8)
            channel.write(ByteBuffer.wrap(bytes))
            channel.force(true)
        }
        try {
            Files.move(temp, path, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(temp, path, StandardCopyOption.REPLACE_EXISTING)
        }
        runCatching { FileChannel.open(directory, StandardOpenOption.READ).use { it.force(true) } }
        return InstallIdentityContract.validate(String(Files.readAllBytes(path), Charsets.UTF_8).trim()).also {
            check(it == candidate) { "install.identity_read_back" }
        }
    }
}
