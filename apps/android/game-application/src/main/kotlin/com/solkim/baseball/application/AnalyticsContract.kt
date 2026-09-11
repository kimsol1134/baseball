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
public sealed interface AnalyticsValue {
    public data class Text(public val value: String) : AnalyticsValue
    public data class Flag(public val value: Boolean) : AnalyticsValue
    public data class Whole(public val value: Long) : AnalyticsValue
    public data class Decimal(public val value: Double) : AnalyticsValue
}

/**
 * The aggregate command wire stores analytics properties as strings for compatibility with the
 * existing command codec.  The string is not the type: every matrix property has a frozen wire
 * kind and is checked before the command can be committed.  This keeps a caller from turning a
 * boolean into the text "True", or silently sending a decimal as an integer, when it crosses the
 * native SDK boundary.
 */
public enum class AnalyticsPropertyKind {
    TEXT,
    FLAG,
    WHOLE,
    DECIMAL,
}

public data class ProjectedAnalyticsEvent(
    public val eventName: String,
    public val scope: String,
    public val properties: Map<String, AnalyticsValue> = emptyMap(),
) {
    init {
        require(eventName in AnalyticsContract.nonRetiredEvents) { "analytics.projected_event:$eventName" }
        require(scope.isNotBlank()) { "analytics.projected_scope" }
    }
}

/** Source ledger for the current iOS/Unity matrix.  Retired Daily and chooser-completion events
 * are deliberately listed as zero-caller exceptions so a checker cannot mistake omission for a
 * forgotten caller. */
public object AnalyticsContract {
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
        "manual_pitch_released_v2" to "actual native manual release after accepted submit",
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
        "manual_pitch_released_v2" to setOf("release_accuracy", "aim_accuracy"),
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
    public val propertyKinds: Map<String, Map<String, AnalyticsPropertyKind>> = mapOf(
        "manual_pitch_released_v2" to kinds(wholes = setOf("release_accuracy", "aim_accuracy")),
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
        when (propertyKinds[eventName]?.get(key) ?: AnalyticsPropertyKind.TEXT) {
            AnalyticsPropertyKind.TEXT -> {
                require(value.length <= 64) { "analytics.property_text_length:$key" }
                allowedTextValues[eventName]?.get(key)?.let { allowed ->
                    require(value in allowed) { "analytics.property_text_value:$eventName:$key" }
                }
            }
            AnalyticsPropertyKind.FLAG -> require(value == "true" || value == "false") { "analytics.property_flag:$key" }
            AnalyticsPropertyKind.WHOLE -> require(value.matches(Regex("-?[0-9]+")) && value.toLongOrNull() != null) { "analytics.property_whole:$key" }
            AnalyticsPropertyKind.DECIMAL -> require(value.matches(Regex("-?[0-9]+\\.[0-9]+")) && value.toDoubleOrNull()?.isFinite() == true) { "analytics.property_decimal:$key" }
        }
    }

    private fun kinds(
        flags: Set<String> = emptySet(),
        wholes: Set<String> = emptySet(),
        decimals: Set<String> = emptySet(),
    ): Map<String, AnalyticsPropertyKind> = buildMap {
        flags.forEach { put(it, AnalyticsPropertyKind.FLAG) }
        wholes.forEach { put(it, AnalyticsPropertyKind.WHOLE) }
        decimals.forEach { put(it, AnalyticsPropertyKind.DECIMAL) }
    }

    private fun returnPlanKinds(): Map<String, AnalyticsPropertyKind> = kinds(wholes = setOf("day_gap", "development_rules_version"))
}

