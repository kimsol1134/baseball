package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.model.Hashing

/**
 * The application-side half of the frozen analytics matrix.  This module intentionally does not
 * depend on Android or an SDK.  It derives typed, privacy-safe values from the committed
 * aggregate and turns them into durable aggregate receipts before the repository save.
 */
public sealed interface Phase9AnalyticsValue {
    public data class Text(public val value: String) : Phase9AnalyticsValue
    public data class Flag(public val value: Boolean) : Phase9AnalyticsValue
    public data class Whole(public val value: Long) : Phase9AnalyticsValue
    public data class Decimal(public val value: Double) : Phase9AnalyticsValue
}

/**
 * The aggregate command wire stores analytics properties as strings for compatibility with the
 * existing command codec.  The string is not the type: every matrix property has a frozen wire
 * kind and is checked before the command can be committed.  This keeps a caller from turning a
 * boolean into the text "True", or silently sending a decimal as an integer, when it crosses the
 * native SDK boundary.
 */
public enum class Phase9AnalyticsPropertyKind {
    TEXT,
    FLAG,
    WHOLE,
    DECIMAL,
}

public data class Phase9ProjectedAnalyticsEvent(
    public val eventName: String,
    public val scope: String,
    public val properties: Map<String, Phase9AnalyticsValue> = emptyMap(),
) {
    init {
        require(eventName in Phase9AnalyticsContract.nonRetiredEvents) { "analytics.projected_event:$eventName" }
        require(scope.isNotBlank()) { "analytics.projected_scope" }
    }
}

/** Source ledger for the current iOS/Unity matrix.  Retired Daily and chooser-completion events
 * are deliberately listed as zero-caller exceptions so a checker cannot mistake omission for a
 * forgotten caller. */
public object Phase9AnalyticsContract {
    public val retiredEvents: Set<String> = setOf("daily_inning_opened", "daily_inning_rewarded")
    public val intentionalZeroCallerEvents: Set<String> = setOf(
        "life_card_shared",
        "life_card_share_completed",
        "daily_inning_opened",
        "daily_inning_rewarded",
    )

    public val semanticSources: Map<String, String> = linkedMapOf(
        "onboarding_started" to "EnterSetup committed transition",
        "onboarding_completed" to "HighSchool.Start committed transition",
        "first_pitch" to "non-challenge tutorial completion committed transition",
        "activation_first_game" to "official FinishImportantGame first-completion transition",
        "game_finished" to "official FinishImportantGame report transition",
        "chapter_advanced" to "HighSchool.AdvanceChapter committed transition",
        "draft_resolved" to "HighSchool.ResolveDraft committed transition",
        "rebirth_started" to "HighSchool.BeginRebirth committed transition",
        "life_card_share_tapped" to "Compose chooser-open result",
        "run_pledge_selected" to "HighSchool.SelectPledge committed transition",
        "run_pledge_resolved" to "HighSchool.FinalizeArchive pledge settlement",
        "career_wind_seen" to "visible Compose wind card intersection",
        "next_run_intent_saved" to "HighSchool.SaveNextRunIntent committed transition",
        "next_run_intent_applied" to "HighSchool.Start inherited intent transition",
        "weekly_program_opened" to "visible Compose weekly card intersection",
        "weekly_program_completed" to "HighSchool.ClaimWeeklyReward committed transition",
        "pro_season_decision_selected" to "Pro.ApplySeasonDecision committed transition",
        "pro_legacy_recorded" to "Pro.SelectLegacy committed transition",
        "player_legacy_seen" to "visible finalized recap/archive/next-life frozen record intersection",
        "player_heartline_seen" to "visible Compose relationship card intersection",
        "recap_continue_tapped" to "HighSchool.BeginRebirth quick/custom action payload",
        "signature_legacy_options_seen" to "visible Compose signature options intersection",
        "signature_legacy_selected" to "HighSchool.SelectLegacy committed transition",
        "signature_legacy_equipped" to "HighSchool.Start inherited signature transition",
        "life_completed" to "HighSchool.FinalizeArchive committed transition",
        "career_training_completed" to "HighSchool.Training/TrainingBlock committed result",
        "game_growth_applied" to "official HighSchool.FinishImportantGame stat delta",
        "phase_entered" to "non-initial HighSchool phase transition",
        "game_abandoned" to "native pitch abandon committed transition",
        "pro_career_started" to "Pro.StartLinked/StartDirect committed transition",
        "reminder_changed" to "OS-truth after-first-game/settings/system correction committed transition",
        "reminder_offer_shown" to "visible Compose reminder offer intersection",
        "reminder_opened" to "durable notification token receipt committed transition",
        "return_plan_shown" to "visible Compose return-plan card intersection",
        "return_plan_tapped" to "HighSchool.PrepareReturnPlan CTA transition",
        "return_plan_dismissed" to "HighSchool.DismissReturnPlan committed transition",
        "return_plan_eligible" to "HighSchool.PrepareReturnPlan durable plan transition",
        "return_plan_cold_start" to "Compose cold-start return-plan receipt",
        "return_plan_next_day_open" to "Compose next-Seoul-day return-plan receipt",
        "session_ended" to "native shell pause/session boundary",
    )

    public val nonRetiredEvents: Set<String> get() = semanticSources.keys

    /** Matrix property names copied into the application boundary as well as the SDK boundary.
     *  Keeping this set here prevents a manual Compose interaction from bypassing the typed
     *  native schema simply because it is represented as a durable string pair in the aggregate.
     */
    public val allowedProperties: Map<String, Set<String>> = mapOf(
        "onboarding_started" to emptySet(),
        "onboarding_completed" to emptySet(),
        "first_pitch" to emptySet(),
        "activation_first_game" to emptySet(),
        "life_card_share_tapped" to setOf("life_number"),
        "game_finished" to setOf("mode", "sequence_mastery_count", "sequence_tags", "recommendation_acceptance_rate", "development_rules_version", "ability_moment_count", "ability_moment_types", "life_number", "act_number", "result", "strikeouts", "walks", "runs", "target_batters", "batters"),
        "chapter_advanced" to setOf("chapter", "act_number"),
        "draft_resolved" to setOf("drafted", "score", "life_number", "act_number"),
        "rebirth_started" to setOf("life_number", "entry_point", "selected_legacy_id", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied"),
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
        "pro_career_started" to setOf("round", "evaluation", "life_number", "source"),
        "reminder_changed" to setOf("enabled", "source"),
        "reminder_offer_shown" to setOf("source"),
        "reminder_opened" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "development_rules_version"),
        "return_plan_shown" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "return_day_key", "day_gap", "development_rules_version"),
        "return_plan_tapped" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "return_day_key", "day_gap", "development_rules_version"),
        "return_plan_dismissed" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "return_day_key", "day_gap", "development_rules_version"),
        "return_plan_eligible" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "return_day_key", "day_gap", "development_rules_version"),
        "return_plan_cold_start" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "return_day_key", "day_gap", "development_rules_version", "launch_type"),
        "return_plan_next_day_open" to setOf("destination", "reason", "plan_receipt", "experiment_id", "variant", "saved_day_key", "return_day_key", "day_gap", "development_rules_version", "launch_type"),
        "session_ended" to setOf("minutes", "life_number", "games", "important_games_total", "phase", "act_number", "lives_finished", "return_eligible", "return_destination", "return_reason", "plan_receipt", "experiment_id", "variant", "development_rules_version"),
    )

    /** Exact wire kinds for the matrix properties. Unlisted permitted values are text values. */
    public val propertyKinds: Map<String, Map<String, Phase9AnalyticsPropertyKind>> = mapOf(
        "game_finished" to kinds(
            flags = emptySet(),
            wholes = setOf("sequence_mastery_count", "development_rules_version", "ability_moment_count", "life_number", "act_number", "strikeouts", "walks", "runs", "target_batters", "batters"),
            decimals = setOf("recommendation_acceptance_rate"),
        ),
        "chapter_advanced" to kinds(wholes = setOf("chapter", "act_number")),
        "draft_resolved" to kinds(flags = setOf("drafted"), wholes = setOf("score", "life_number", "act_number")),
        "rebirth_started" to kinds(wholes = setOf("life_number", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied")),
        "life_card_share_tapped" to kinds(wholes = setOf("life_number")),
        "run_pledge_selected" to kinds(flags = setOf("recommended"), wholes = setOf("life_number")),
        "run_pledge_resolved" to kinds(flags = setOf("achieved"), wholes = setOf("reward_permille"), decimals = setOf("progress_ratio")),
        "career_wind_seen" to kinds(wholes = setOf("rules_version")),
        "next_run_intent_saved" to kinds(wholes = setOf("source_life_number")),
        "next_run_intent_applied" to kinds(wholes = setOf("life_number")),
        "weekly_program_opened" to kinds(wholes = setOf("completed_tasks")),
        "weekly_program_completed" to kinds(flags = setOf("perfect"), wholes = setOf("completed_tasks")),
        "pro_season_decision_selected" to kinds(wholes = setOf("season", "week")),
        "pro_legacy_recorded" to kinds(wholes = setOf("life_number", "pro_seasons", "soul_bonus"), flags = setOf("has_signature_candidates")),
        "player_legacy_seen" to kinds(flags = setOf("drafted", "has_frozen_legacy"), wholes = setOf("life_number")),
        "player_heartline_seen" to kinds(wholes = setOf("life_number")),
        "recap_continue_tapped" to kinds(flags = setOf("drafted", "has_suggested_intent", "intent_saved"), wholes = setOf("life_number")),
        "signature_legacy_options_seen" to kinds(flags = setOf("drafted", "includes_pro_career"), wholes = setOf("life_number")),
        "signature_legacy_selected" to kinds(flags = setOf("drafted", "includes_pro_career"), wholes = setOf("life_number", "rating_growth", "pro_seasons")),
        "signature_legacy_equipped" to kinds(wholes = setOf("life_number", "total_rating_bonus", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied")),
        "life_completed" to kinds(flags = setOf("drafted"), wholes = setOf("life_number", "act_number", "evaluation", "trainings", "important_games", "pitches", "legacy_rules_version", "unlocked_legacy_count", "inheritance_rules_version", "soul_total", "soul_wallet", "soul_lifetime_earned", "soul_applied")),
        "career_training_completed" to kinds(wholes = setOf("life_number", "act_number", "growth_points", "fatigue_delta")),
        "game_growth_applied" to kinds(wholes = setOf("life_number", "act_number", "growth_points")),
        "phase_entered" to kinds(wholes = setOf("chapter", "act_number", "life_number")),
        "game_abandoned" to kinds(wholes = setOf("pitches", "chapter", "life_number", "act_number", "development_rules_version", "games_completed")),
        "pro_career_started" to kinds(wholes = setOf("round", "evaluation", "life_number")),
        "reminder_changed" to kinds(flags = setOf("enabled")),
        "reminder_offer_shown" to kinds(),
        "reminder_opened" to kinds(wholes = setOf("development_rules_version")),
        "return_plan_shown" to returnPlanKinds(),
        "return_plan_tapped" to returnPlanKinds(),
        "return_plan_dismissed" to returnPlanKinds(),
        "return_plan_eligible" to returnPlanKinds(),
        "return_plan_cold_start" to returnPlanKinds(),
        "return_plan_next_day_open" to returnPlanKinds(),
        "session_ended" to kinds(flags = setOf("return_eligible"), wholes = setOf("minutes", "life_number", "games", "important_games_total", "act_number", "lives_finished")),
    )

    /** Exact enum/text domains. IDs and source evidence remain text without a fabricated domain. */
    public val allowedTextValues: Map<String, Map<String, Set<String>>> = mapOf(
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

    public fun validateManual(eventName: String, properties: List<Pair<String, String>>) {
        require(eventName !in retiredEvents) { "analytics.retired:$eventName" }
        require(eventName !in intentionalZeroCallerEvents) { "analytics.zero_caller:$eventName" }
        if (eventName !in nonRetiredEvents) return // local command receipts remain local.
        require(properties.map { it.first }.distinct().size == properties.size) { "analytics.properties_duplicate" }
        require(properties.all { it.first.matches(Regex("[a-z][a-z0-9_]{0,47}")) }) { "analytics.property_key" }
        val permitted = allowedProperties[eventName] ?: error("analytics.matrix_source:$eventName")
        require(properties.all { it.first in permitted }) { "analytics.property_unexpected:$eventName" }
        properties.forEach { (key, value) -> validateWireKind(eventName, key, value) }
    }

    private fun validateWireKind(eventName: String, key: String, value: String) {
        when (propertyKinds[eventName]?.get(key) ?: Phase9AnalyticsPropertyKind.TEXT) {
            Phase9AnalyticsPropertyKind.TEXT -> {
                require(value.length <= 64) { "analytics.property_text_length:$key" }
                allowedTextValues[eventName]?.get(key)?.let { allowed ->
                    require(value in allowed) { "analytics.property_text_value:$eventName:$key" }
                }
            }
            Phase9AnalyticsPropertyKind.FLAG -> require(value == "true" || value == "false") { "analytics.property_flag:$key" }
            Phase9AnalyticsPropertyKind.WHOLE -> require(value.matches(Regex("-?[0-9]+")) && value.toLongOrNull() != null) { "analytics.property_whole:$key" }
            Phase9AnalyticsPropertyKind.DECIMAL -> require(value.matches(Regex("-?[0-9]+\\.[0-9]+")) && value.toDoubleOrNull()?.isFinite() == true) { "analytics.property_decimal:$key" }
        }
    }

    private fun kinds(
        flags: Set<String> = emptySet(),
        wholes: Set<String> = emptySet(),
        decimals: Set<String> = emptySet(),
    ): Map<String, Phase9AnalyticsPropertyKind> = buildMap {
        flags.forEach { put(it, Phase9AnalyticsPropertyKind.FLAG) }
        wholes.forEach { put(it, Phase9AnalyticsPropertyKind.WHOLE) }
        decimals.forEach { put(it, Phase9AnalyticsPropertyKind.DECIMAL) }
    }

    private fun returnPlanKinds(): Map<String, Phase9AnalyticsPropertyKind> = kinds(wholes = setOf("day_gap", "development_rules_version"))
}

public object Phase9AnalyticsProjector {
    /** Stable IDs are aggregate-internal; no raw career/install identifier is sent to SDKs. */
    public fun receiptId(installId: String, eventName: String, scope: String): String =
        "matrix:" + Hashing.sha256Hex("$installId|$eventName|$scope").take(56)

    public fun toReceipt(
        event: Phase9ProjectedAnalyticsEvent,
        state: GameAggregateState,
    ): AnalyticsReceipt {
        val properties = event.properties.toSortedMap().map { (key, value) -> key to value.wire() }
        // Projected transitions cross exactly the same typed/domain boundary as explicit
        // viewport/manual receipts. This fails the command before an invalid enum or numeric
        // wire can become durable aggregate evidence.
        Phase9AnalyticsContract.validateManual(event.eventName, properties)
        return AnalyticsReceipt(
            receiptId = receiptId(state.installId, event.eventName, event.scope),
            eventName = event.eventName,
            revision = state.revision,
            commitment = state.commitment,
            properties = properties,
        )
    }

    /**
     * Derives only semantic transitions.  Challenge snapshots and the retired Daily wire are
     * hard guards here, so a later caller cannot accidentally bypass the matrix policy.
     */
    public fun project(
        before: GameAggregateState,
        after: GameAggregateState,
        envelope: GameCommandEnvelope,
    ): List<AnalyticsReceipt> {
        val command = envelope.command
        if (before.highSchool?.challenge?.active == true || after.highSchool?.challenge?.active == true) return emptyList()
        val events = linkedSetOf<Phase9ProjectedAnalyticsEvent>()

        fun add(eventName: String, scope: String, properties: Map<String, Phase9AnalyticsValue> = emptyMap()) {
            if (eventName in Phase9AnalyticsContract.nonRetiredEvents) {
                val allowed = Phase9AnalyticsContract.allowedProperties.getValue(eventName)
                require(properties.keys.all { it in allowed }) { "analytics.projected_property:$eventName" }
                events += Phase9ProjectedAnalyticsEvent(eventName, scope, properties)
            }
        }

        when (command) {
            GameCommand.EnterSetup -> if (before.stage == GameStage.OPENING && after.stage == GameStage.SETUP) {
                add("onboarding_started", "install")
            }
            is GameCommand.HighSchool -> projectHighSchool(before, after, command.command, ::add)
            is GameCommand.Pro -> projectPro(before, after, command.command, ::add)
            is GameCommand.CompletePitch -> Unit
            is GameCommand.AbandonPitch -> {
                val pitch = before.pitch
                if (pitch != null && !pitch.challengeRun && pitch.careerKind != PitchCareerKind.TUTORIAL) {
                    val run = after.highSchool?.run
                    add(
                        "game_abandoned",
                        "game:${pitch.gameId}",
                        buildMap {
                            put("pitches", Phase9AnalyticsValue.Whole(pitch.pitchIndex.toLong()))
                            run?.let {
                                put("chapter", Phase9AnalyticsValue.Whole(it.chapter.number.toLong()))
                                put("life_number", Phase9AnalyticsValue.Whole(it.lifeNumber.toLong()))
                                put("act_number", Phase9AnalyticsValue.Whole(actNumber(it.chapter.number).toLong()))
                                put("phase", Phase9AnalyticsValue.Text(it.phase.wire))
                                put("development_rules_version", Phase9AnalyticsValue.Whole(it.worldRulesVersion.toLong()))
                            }
                            put("games_completed", Phase9AnalyticsValue.Whole(after.meta.completedGameCount.toLong()))
                        },
                    )
                }
            }
            is GameCommand.UpdateSettings -> Unit
            is GameCommand.RecordAnalytics -> Unit
            is GameCommand.ReservePitch,
            is GameCommand.StartPitch,
            is GameCommand.CommitPitch,
            is GameCommand.ConsumePitch,
            is GameCommand.MarkPitchTerminal,
            is GameCommand.SuspendPitch,
            is GameCommand.ResumePitch,
            is GameCommand.ClearPitchPresentation -> Unit
        }

        val existing = after.analytics.receipts.mapTo(hashSetOf()) { it.receiptId }
        return events.map { toReceipt(it, after) }.filterNot { it.receiptId in existing }
    }

    private fun projectHighSchool(
        before: GameAggregateState,
        after: GameAggregateState,
        command: HighSchoolPhase4Command,
        add: (String, String, Map<String, Phase9AnalyticsValue>) -> Unit,
    ) {
        val previous = before.highSchool
        val current = after.highSchool
        val previousRun = previous?.run
        val run = current?.run ?: return
        if (command is HighSchoolPhase4Command.Start && previous == null) {
            add("onboarding_completed", "install", emptyMap())
            val inheritedIntent = current.nextRunIntent
            if (inheritedIntent != null) {
                add(
                    "next_run_intent_applied",
                    "career:${run.careerId}",
                    mapOf(
                        "pledge_id" to Phase9AnalyticsValue.Text(inheritedIntent.pledgeId),
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                    ),
                )
            }
            current.inheritance.selectedSignatureLegacyId?.let { legacyId ->
                add(
                    "signature_legacy_equipped",
                    "life:${run.careerId}",
                    mapOf(
                        "legacy_id" to Phase9AnalyticsValue.Text(legacyId),
                        "family" to Phase9AnalyticsValue.Text(signatureFamily(legacyId)),
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "total_rating_bonus" to Phase9AnalyticsValue.Whole(signatureBonus(legacyId).toLong()),
                        "inheritance_rules_version" to Phase9AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()),
                        "soul_total" to Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                        "soul_wallet" to Phase9AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()),
                        "soul_lifetime_earned" to Phase9AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()),
                        "soul_applied" to Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                    ),
                )
            }
            if (run.lifeNumber > 1) {
                add(
                    "rebirth_started",
                    "life:${run.careerId}",
                    mapOf(
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "entry_point" to Phase9AnalyticsValue.Text("setup_flow"),
                        "inheritance_rules_version" to Phase9AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()),
                        "soul_total" to Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                        "soul_wallet" to Phase9AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()),
                        "soul_lifetime_earned" to Phase9AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()),
                        "soul_applied" to Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                    ),
                )
            }
        }

        if (previousRun != null && previousRun.phase != run.phase && command !is HighSchoolPhase4Command.Start) {
            add(
                "phase_entered",
                "career:${run.careerId}|phase:${run.phase.wire}|revision:${after.revision}",
                mapOf(
                    "phase" to Phase9AnalyticsValue.Text(run.phase.wire),
                    "chapter" to Phase9AnalyticsValue.Whole(run.chapter.number.toLong()),
                    "act_number" to Phase9AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                    "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                ),
            )
        }

        when (command) {
            is HighSchoolPhase4Command.CompleteTutorial -> {
                if (previous?.tutorial?.completed != true && current.tutorial.completed &&
                    previous?.challenge?.active != true && current.challenge.active != true
                ) {
                    add("first_pitch", "install", emptyMap())
                }
            }
            is HighSchoolPhase4Command.AdvanceChapter -> if (previousRun != null && previousRun.chapter.number != run.chapter.number) {
                add(
                    "chapter_advanced",
                    "career:${run.careerId}|chapter:${run.chapter.number}",
                    mapOf(
                        "chapter" to Phase9AnalyticsValue.Whole(run.chapter.number.toLong()),
                        "act_number" to Phase9AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                    ),
                )
            }
            is HighSchoolPhase4Command.Training,
            is HighSchoolPhase4Command.TrainingBlock -> {
                val beforeEvidence = previous?.trainingEvidence.orEmpty().map { "${it.careerId}:${it.trainingNumber}" }.toSet()
                current.trainingEvidence
                    .filter { "${it.careerId}:${it.trainingNumber}" !in beforeEvidence }
                    .sortedBy { it.trainingNumber }
                    .forEach { evidence ->
                        add(
                            "career_training_completed",
                            "training:${evidence.careerId}:${evidence.trainingNumber}",
                            buildMap {
                                put("life_number", Phase9AnalyticsValue.Whole(evidence.lifeNumber.toLong()))
                                put("act_number", Phase9AnalyticsValue.Whole(actNumber(evidence.chapterNumber).toLong()))
                                put("focus_id", Phase9AnalyticsValue.Text(evidence.focus.wire))
                                put("intensity_id", Phase9AnalyticsValue.Text(evidence.intensity.wire))
                                evidence.targetPitch?.let { put("target_pitch_id", Phase9AnalyticsValue.Text(it.wire)) }
                                put("growth_points", Phase9AnalyticsValue.Whole(evidence.growthPoints.toLong()))
                                put("fatigue_delta", Phase9AnalyticsValue.Whole(evidence.fatigueDelta.toLong()))
                            },
                        )
                    }
            }
            is HighSchoolPhase4Command.SelectPledge -> current?.pledge?.let { pledge ->
                add(
                    "run_pledge_selected",
                    "career:${run.careerId}",
                    mapOf(
                        "pledge_id" to Phase9AnalyticsValue.Text(pledge.definition.id),
                        "tier" to Phase9AnalyticsValue.Text(pledge.definition.tier.wire),
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "recommended" to Phase9AnalyticsValue.Flag(previous?.nextRunIntent?.pledgeId == pledge.definition.id),
                    ),
                )
            }
            is HighSchoolPhase4Command.SaveNextRunIntent -> add(
                "next_run_intent_saved",
                "career:${run.careerId}",
                mapOf(
                    "pledge_id" to Phase9AnalyticsValue.Text(command.intent.pledgeId),
                    "source_life_number" to Phase9AnalyticsValue.Whole(command.intent.sourceLifeNumber.toLong()),
                ),
            )
            is HighSchoolPhase4Command.PrepareReturnPlan -> current?.returnPlan?.let { plan ->
                add("return_plan_tapped", "plan:${plan.receiptId}", returnPlanProperties(plan, current.selectedDayKey))
                add("return_plan_eligible", "plan:${plan.receiptId}", returnPlanProperties(plan, current.selectedDayKey))
            }
            is HighSchoolPhase4Command.DismissReturnPlan -> previous?.returnPlan?.let { plan ->
                add("return_plan_dismissed", "plan:${plan.receiptId}", returnPlanProperties(plan, current.selectedDayKey))
            }
            is HighSchoolPhase4Command.ClaimWeeklyReward -> if (current?.weekly?.rewardClaimed == true) {
                add(
                    "weekly_program_completed",
                    "week:${current.weekly.weekKey}",
                    mapOf(
                        "week_key" to Phase9AnalyticsValue.Text(current.weekly.weekKey),
                        "completed_tasks" to Phase9AnalyticsValue.Whole(current.weekly.tasks.count { it.completed }.toLong()),
                        "perfect" to Phase9AnalyticsValue.Flag(current.weekly.tasks.all { it.completed }),
                    ),
                )
            }
            is HighSchoolPhase4Command.ResolveDraft -> current?.run?.draftResult?.let { draft ->
                add(
                    "draft_resolved",
                    "career:${run.careerId}",
                    mapOf(
                        "drafted" to Phase9AnalyticsValue.Flag(draft.outcome == HighSchoolDraftOutcome.DRAFTED),
                        "score" to Phase9AnalyticsValue.Whole(draft.evaluationScore.toLong()),
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "act_number" to Phase9AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                    ),
                )
            }
            is HighSchoolPhase4Command.SelectLegacy -> {
                val legacyId = command.legacyId
                add(
                    "signature_legacy_selected",
                    "career:${run.careerId}",
                    mapOf(
                        "legacy_id" to Phase9AnalyticsValue.Text(legacyId),
                        "family" to Phase9AnalyticsValue.Text(signatureFamily(legacyId)),
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "drafted" to Phase9AnalyticsValue.Flag(run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED),
                        "rating_growth" to Phase9AnalyticsValue.Whole(signatureRatingGrowth(legacyId, current.startingPitcher, run.pitcher).toLong()),
                        "includes_pro_career" to Phase9AnalyticsValue.Flag(after.pro?.careerStats?.isNotEmpty() == true),
                        "pro_seasons" to Phase9AnalyticsValue.Whole((after.pro?.careerStats?.size ?: 0).toLong()),
                    ),
                )
            }
            is HighSchoolPhase4Command.FinalizeArchive -> current?.archive?.lastOrNull()?.let { record ->
                add(
                    "life_completed",
                    "career:${record.careerId}",
                    buildMap {
                        put("life_number", Phase9AnalyticsValue.Whole(record.lifeNumber.toLong()))
                        put("act_number", Phase9AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()))
                        put("drafted", Phase9AnalyticsValue.Flag(record.drafted))
                        put("evaluation", Phase9AnalyticsValue.Whole(record.draftEvaluation.toLong()))
                        put("trainings", Phase9AnalyticsValue.Whole(run.totalTrainingsCompleted.toLong()))
                        put("important_games", Phase9AnalyticsValue.Whole(record.importantGames.toLong()))
                        put("pitches", Phase9AnalyticsValue.Whole(record.pitches.toLong()))
                        record.selectedSignatureLegacyId?.let { put("legacy_id", Phase9AnalyticsValue.Text(it)) }
                        put("legacy_rules_version", Phase9AnalyticsValue.Whole(HighSchoolSignatureLegacyRules.RULES_VERSION.toLong()))
                        put("unlocked_legacy_count", Phase9AnalyticsValue.Whole(current.inheritance.unlockedSignatureLegacyIds.size.toLong()))
                        put("inheritance_rules_version", Phase9AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()))
                        put("soul_total", Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()))
                        put("soul_wallet", Phase9AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()))
                        put("soul_lifetime_earned", Phase9AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()))
                        put("soul_applied", Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()))
                    },
                )
                val pledgeId = record.pledgeId
                if (pledgeId != null) {
                    add(
                        "run_pledge_resolved",
                        "career:${record.careerId}",
                        mapOf(
                            "pledge_id" to Phase9AnalyticsValue.Text(pledgeId),
                            "achieved" to Phase9AnalyticsValue.Flag(record.pledgeAchieved),
                            "progress_ratio" to Phase9AnalyticsValue.Decimal(
                                current.pledge?.let { pledge ->
                                    if (pledge.definition.target > 0) (pledge.progress.toDouble() / pledge.definition.target.toDouble()).coerceIn(0.0, 1.0) else 0.0
                                } ?: 0.0,
                            ),
                            "reward_permille" to Phase9AnalyticsValue.Whole(
                                current.pledge?.definition?.tier?.rewardPermille?.toLong() ?: 0L,
                            ),
                        ),
                    )
                }
            }
            is HighSchoolPhase4Command.BeginRebirth -> {
                val inheritedIntent = previous?.nextRunIntent
                val appliedIntent = current.nextRunIntent
                if (inheritedIntent != null && appliedIntent == inheritedIntent) {
                    add(
                        "next_run_intent_applied",
                        "career:${run.careerId}",
                        mapOf(
                            "pledge_id" to Phase9AnalyticsValue.Text(appliedIntent.pledgeId),
                            "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        ),
                    )
                }
                val inheritedLegacy = previous?.inheritance?.selectedSignatureLegacyId
                val equippedLegacy = current.inheritance.selectedSignatureLegacyId
                if (inheritedLegacy != null && equippedLegacy == inheritedLegacy) {
                    add(
                        "signature_legacy_equipped",
                        "life:${run.careerId}",
                        mapOf(
                            "legacy_id" to Phase9AnalyticsValue.Text(equippedLegacy),
                            "family" to Phase9AnalyticsValue.Text(signatureFamily(equippedLegacy)),
                            "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                            "total_rating_bonus" to Phase9AnalyticsValue.Whole(signatureBonus(equippedLegacy).toLong()),
                            "inheritance_rules_version" to Phase9AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()),
                            "soul_total" to Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                            "soul_wallet" to Phase9AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()),
                            "soul_lifetime_earned" to Phase9AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()),
                            "soul_applied" to Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                        ),
                    )
                }
                add(
                    "rebirth_started",
                    "life:${run.careerId}",
                    buildMap {
                        put("life_number", Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()))
                        put("entry_point", Phase9AnalyticsValue.Text(command.entryPath))
                        current.inheritance.selectedSignatureLegacyId?.let { put("selected_legacy_id", Phase9AnalyticsValue.Text(it)) }
                        current.inheritance.inheritanceRulesVersion?.let { put("inheritance_rules_version", Phase9AnalyticsValue.Whole(it.toLong())) }
                        put("soul_total", Phase9AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()))
                        put("soul_wallet", Phase9AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()))
                        put("soul_lifetime_earned", Phase9AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()))
                        put("soul_applied", Phase9AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()))
                    },
                )
                if (command.entryPath in setOf("quick_rebirth", "customize")) {
                    add("recap_continue_tapped", "career:${previousRun?.careerId ?: run.careerId}", mapOf(
                        "life_number" to Phase9AnalyticsValue.Whole((previousRun?.lifeNumber ?: run.lifeNumber).toLong()),
                        "drafted" to Phase9AnalyticsValue.Flag(previousRun?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED),
                        "entry_path" to Phase9AnalyticsValue.Text(command.entryPath),
                        "has_suggested_intent" to Phase9AnalyticsValue.Flag(previous?.nextRunIntent != null),
                        "intent_saved" to Phase9AnalyticsValue.Flag(current.nextRunIntent != null),
                    ))
                }
            }
            is HighSchoolPhase4Command.FinishImportantGame -> {
                val session = previous?.activePitch
                if (session != null && !previous.challenge.active) {
                    val reportProperties = buildMap {
                        put("mode", Phase9AnalyticsValue.Text("high_school"))
                        put("sequence_mastery_count", Phase9AnalyticsValue.Whole(session.sequenceMasteryCount.toLong()))
                        acceptanceRate(session.recommendationAccepted, session.pitches)?.let { put("recommendation_acceptance_rate", it) }
                        put("development_rules_version", Phase9AnalyticsValue.Whole(run.worldRulesVersion.toLong()))
                        put("ability_moment_count", Phase9AnalyticsValue.Whole(session.abilityMoments.size.toLong()))
                        session.abilityMoments.distinct().sorted().takeIf { it.isNotEmpty() }?.let {
                            put("ability_moment_types", Phase9AnalyticsValue.Text(it.joinToString(",")))
                        }
                        put("life_number", Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()))
                        put("act_number", Phase9AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()))
                        put("result", Phase9AnalyticsValue.Text(if (session.runsAllowed == 0) "scoreless" else "runs_allowed"))
                        put("strikeouts", Phase9AnalyticsValue.Whole(session.strikeouts.toLong()))
                        put("walks", Phase9AnalyticsValue.Whole(session.walks.toLong()))
                        put("runs", Phase9AnalyticsValue.Whole(session.runsAllowed.toLong()))
                    /*
                     * The current Kotlin durable session does not retain the Swift scenario's
                     * maximum batter count or its completed sequence-tag set after a terminal
                     * plate appearance.  Leaving those fields absent is intentional: a zero or
                     * synthesized tag would be false evidence at the native SDK boundary.
                     */
                    }
                    add("game_finished", "game:${before.pitch?.gameId ?: session.log.gameId}", reportProperties)
                    if (before.meta.completedGameCount == 0UL && after.meta.completedGameCount > 0UL) add("activation_first_game", "install", emptyMap())
                    val growthFocus = previousRun?.let { gameGrowthFocus(it, session) }
                    val growth = growthFocus?.let { rating(it, run.pitcher) - rating(it, previousRun.pitcher) } ?: 0
                    if (growth > 0 && growthFocus != null) add("game_growth_applied", "game:${before.pitch?.gameId ?: session.log.gameId}", mapOf(
                        "life_number" to Phase9AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "act_number" to Phase9AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                        "reason_id" to Phase9AnalyticsValue.Text("important_game"),
                        "growth_focus" to Phase9AnalyticsValue.Text(growthFocus.wire),
                        "growth_points" to Phase9AnalyticsValue.Whole(growth.toLong()),
                    ))
                }
            }
            else -> Unit
        }
    }

    private fun projectPro(
        before: GameAggregateState,
        after: GameAggregateState,
        command: ProCommand,
        add: (String, String, Map<String, Phase9AnalyticsValue>) -> Unit,
    ) {
        val pro = after.pro ?: return
        when (command) {
            is ProCommand.StartLinked,
            is ProCommand.StartDirect -> add(
                "pro_career_started",
                "career:${pro.careerId}",
                buildMap {
                    put("source", Phase9AnalyticsValue.Text(if (command is ProCommand.StartLinked) "high_school_draft" else "direct_setup"))
                    if (command is ProCommand.StartLinked) {
                        before.highSchool?.run?.draftResult?.round?.let { put("round", Phase9AnalyticsValue.Whole(it.toLong())) }
                        put("evaluation", Phase9AnalyticsValue.Whole(command.request.draftEvaluation.toLong()))
                        before.highSchool?.run?.lifeNumber?.let { put("life_number", Phase9AnalyticsValue.Whole(it.toLong())) }
                    }
                },
            )
            is ProCommand.ApplySeasonDecision -> add(
                "pro_season_decision_selected",
                "season:${before.pro?.season ?: pro.season}|decision:${command.decisionId}",
                mapOf(
                    "decision_id" to Phase9AnalyticsValue.Text(command.decisionId),
                    "choice_id" to Phase9AnalyticsValue.Text(command.choiceId),
                    "season" to Phase9AnalyticsValue.Whole((before.pro?.season ?: pro.season).toLong()),
                    "week" to Phase9AnalyticsValue.Whole((before.pro?.week ?: pro.week).toLong()),
                ),
            )
            is ProCommand.SelectLegacy -> add(
                "pro_legacy_recorded",
                "career:${pro.careerId}",
                buildMap {
                    // Direct Pro has no HighSchool life; omitting this optional field avoids a
                    // fabricated life number while linked Pro retains the authoritative value.
                    before.highSchool?.run?.lifeNumber?.let { put("life_number", Phase9AnalyticsValue.Whole(it.toLong())) }
                    put("pro_seasons", Phase9AnalyticsValue.Whole(pro.careerStats.size.toLong()))
                    put("has_signature_candidates", Phase9AnalyticsValue.Flag(pro.legacyCandidates.isNotEmpty()))
                },
            )
            is ProCommand.FinishImportantGame -> if (before.pro?.activePitch != null && before.pitch?.challengeRun != true) {
                val session = before.pro?.activePitch ?: return
                add(
                    "game_finished",
                    "game:${before.pitch?.gameId ?: session.log.gameId}",
                    buildMap {
                        put("mode", Phase9AnalyticsValue.Text("pro"))
                        put("sequence_mastery_count", Phase9AnalyticsValue.Whole(session.sequenceMasteryCount.toLong()))
                        acceptanceRate(session.recommendationAccepted, session.pitches)?.let { put("recommendation_acceptance_rate", it) }
                        put("development_rules_version", Phase9AnalyticsValue.Whole(ProCatalog.RULES_VERSION.toLong()))
                        put("ability_moment_count", Phase9AnalyticsValue.Whole(session.abilityMoments.size.toLong()))
                        session.abilityMoments.distinct().sorted().takeIf { it.isNotEmpty() }?.let {
                            put("ability_moment_types", Phase9AnalyticsValue.Text(it.joinToString(",")))
                        }
                        put("result", Phase9AnalyticsValue.Text(if (session.runsAllowed == 0) "scoreless" else "runs_allowed"))
                        put("strikeouts", Phase9AnalyticsValue.Whole(session.strikeouts.toLong()))
                        put("walks", Phase9AnalyticsValue.Whole(session.walks.toLong()))
                        put("runs", Phase9AnalyticsValue.Whole(session.runsAllowed.toLong()))
                    },
                )
                if (before.meta.completedGameCount == 0UL && after.meta.completedGameCount > 0UL) add("activation_first_game", "install", emptyMap())
            }
            else -> Unit
        }
    }

    private fun returnPlanProperties(
        plan: com.solkim.baseball.core.highschool.HighSchoolReturnPlan,
        returnDayKey: String,
    ): Map<String, Phase9AnalyticsValue> = buildMap {
        put("destination", Phase9AnalyticsValue.Text(plan.destination.wire))
        put("reason", Phase9AnalyticsValue.Text(plan.reason))
        put("plan_receipt", Phase9AnalyticsValue.Text(plan.receiptId))
        plan.experimentId?.let { put("experiment_id", Phase9AnalyticsValue.Text(it)) }
        plan.experimentVariant?.let { put("variant", Phase9AnalyticsValue.Text(it)) }
        val savedDayKey = plan.savedDayKey ?: plan.createdDayKey
        put("saved_day_key", Phase9AnalyticsValue.Text(savedDayKey))
        put("return_day_key", Phase9AnalyticsValue.Text(returnDayKey))
        com.solkim.baseball.core.highschool.HighSchoolReturnPlanRules.dayGap(savedDayKey, returnDayKey)?.let {
            put("day_gap", Phase9AnalyticsValue.Whole(it.toLong()))
        }
        plan.developmentRulesVersion?.let { put("development_rules_version", Phase9AnalyticsValue.Whole(it.toLong())) }
    }

    private fun signatureFamily(id: String): String = runCatching { HighSchoolSignatureLegacyRules.definition(id).family }.getOrDefault("unknown")
    private fun signatureBonus(id: String): Int = runCatching {
        val value = HighSchoolSignatureLegacyRules.definition(id)
        value.stuff + value.command + value.movement + value.stamina
    }.getOrDefault(0)

    private fun signatureRatingGrowth(
        id: String,
        starting: com.solkim.baseball.core.highschool.HighSchoolPitcher,
        current: com.solkim.baseball.core.highschool.HighSchoolPitcher,
    ): Int {
        val definition = runCatching { HighSchoolSignatureLegacyRules.definition(id) }.getOrNull() ?: return 0
        return when (definition.family) {
            "power" -> (current.stuff - starting.stuff).coerceAtLeast(0)
            "command" -> (current.command - starting.command).coerceAtLeast(0)
            "breaking" -> (current.movement - starting.movement).coerceAtLeast(0)
            "endurance" -> (current.stamina - starting.stamina).coerceAtLeast(0)
            "gamecraft" -> ((current.command - starting.command).coerceAtLeast(0) +
                (current.movement - starting.movement).coerceAtLeast(0))
            "battery" -> (current.command - starting.command).coerceAtLeast(0)
            else -> 0
        }
    }

    private fun acceptanceRate(accepted: Int, pitches: Int): Phase9AnalyticsValue.Decimal? =
        pitches.takeIf { it > 0 }?.let {
            Phase9AnalyticsValue.Decimal((accepted.toDouble() / it.toDouble()).coerceIn(0.0, 1.0))
        }

    private fun gameGrowthFocus(state: HighSchoolState, session: com.solkim.baseball.core.highschool.HighSchoolPitchSession): HighSchoolTrainingFocus? = when {
        session.strikeouts >= 2 && session.runsAllowed <= 1 && session.actualDamage <= session.expectedDamage ->
            if (state.pitcher.stuff >= state.pitcher.movement) HighSchoolTrainingFocus.VELOCITY else HighSchoolTrainingFocus.BREAKING_BALL
        session.outs == 3 && session.pitches >= 9 && session.runsAllowed <= 1 && session.actualDamage <= session.expectedDamage ->
            HighSchoolTrainingFocus.STAMINA
        session.sequenceMasteryCount >= 4 && session.walks == 0 && session.actualDamage <= session.expectedDamage ->
            HighSchoolTrainingFocus.COMMAND
        else -> null
    }

    private fun rating(focus: HighSchoolTrainingFocus, pitcher: com.solkim.baseball.core.highschool.HighSchoolPitcher): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> pitcher.stuff
        HighSchoolTrainingFocus.COMMAND,
        HighSchoolTrainingFocus.GAME_PLANNING -> pitcher.command
        HighSchoolTrainingFocus.BREAKING_BALL -> pitcher.movement
        HighSchoolTrainingFocus.STAMINA,
        HighSchoolTrainingFocus.RECOVERY -> pitcher.stamina
    }

    private fun actNumber(chapter: Int): Int = if (chapter <= 0) 0 else ((chapter + 1) / 2).coerceIn(1, 4)

    private fun Phase9AnalyticsValue.wire(): String = when (this) {
        is Phase9AnalyticsValue.Text -> value
        is Phase9AnalyticsValue.Flag -> value.toString()
        is Phase9AnalyticsValue.Whole -> value.toString()
        is Phase9AnalyticsValue.Decimal -> value.toString()
    }
}
