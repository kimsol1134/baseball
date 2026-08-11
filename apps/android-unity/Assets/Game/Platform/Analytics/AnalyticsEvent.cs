using System;

namespace Baseball.Platform.Analytics
{
    public enum AnalyticsEvent
    {
        OnboardingStarted,
        OnboardingCompleted,
        FirstPitch,
        ActivationFirstGame,
        GameFinished,
        ChapterAdvanced,
        DraftResolved,
        RebirthStarted,
        LifeCardShared,
        LifeCardShareTapped,
        LifeCardShareCompleted,
        RunPledgeSelected,
        RunPledgeResolved,
        CareerWindSeen,
        NextRunIntentSaved,
        NextRunIntentApplied,
        WeeklyProgramOpened,
        WeeklyProgramCompleted,
        ProSeasonDecisionSelected,
        ProLegacyRecorded,
        PlayerLegacySeen,
        PlayerHeartlineSeen,
        RecapContinueTapped,
        SignatureLegacyOptionsSeen,
        SignatureLegacySelected,
        SignatureLegacyEquipped,
        LifeCompleted,
        CareerTrainingCompleted,
        GameGrowthApplied,
        PhaseEntered,
        GameAbandoned,
        DailyInningOpened,
        DailyInningRewarded,
        ProCareerStarted,
        ReminderChanged,
        ReminderOfferShown,
        ReminderOpened,
        ReturnPlanShown,
        ReturnPlanTapped,
        ReturnPlanDismissed,
        ReturnPlanEligible,
        ReturnPlanColdStart,
        ReturnPlanNextDayOpen,
        SessionEnded
    }

    public static class AnalyticsEventWire
    {
        public static string Value(this AnalyticsEvent value)
        {
            switch (value)
            {
                case AnalyticsEvent.OnboardingStarted: return "onboarding_started";
                case AnalyticsEvent.OnboardingCompleted: return "onboarding_completed";
                case AnalyticsEvent.FirstPitch: return "first_pitch";
                case AnalyticsEvent.ActivationFirstGame: return "activation_first_game";
                case AnalyticsEvent.GameFinished: return "game_finished";
                case AnalyticsEvent.ChapterAdvanced: return "chapter_advanced";
                case AnalyticsEvent.DraftResolved: return "draft_resolved";
                case AnalyticsEvent.RebirthStarted: return "rebirth_started";
                case AnalyticsEvent.LifeCardShared: return "life_card_shared";
                case AnalyticsEvent.LifeCardShareTapped: return "life_card_share_tapped";
                case AnalyticsEvent.LifeCardShareCompleted: return "life_card_share_completed";
                case AnalyticsEvent.RunPledgeSelected: return "run_pledge_selected";
                case AnalyticsEvent.RunPledgeResolved: return "run_pledge_resolved";
                case AnalyticsEvent.CareerWindSeen: return "career_wind_seen";
                case AnalyticsEvent.NextRunIntentSaved: return "next_run_intent_saved";
                case AnalyticsEvent.NextRunIntentApplied: return "next_run_intent_applied";
                case AnalyticsEvent.WeeklyProgramOpened: return "weekly_program_opened";
                case AnalyticsEvent.WeeklyProgramCompleted: return "weekly_program_completed";
                case AnalyticsEvent.ProSeasonDecisionSelected: return "pro_season_decision_selected";
                case AnalyticsEvent.ProLegacyRecorded: return "pro_legacy_recorded";
                case AnalyticsEvent.PlayerLegacySeen: return "player_legacy_seen";
                case AnalyticsEvent.PlayerHeartlineSeen: return "player_heartline_seen";
                case AnalyticsEvent.RecapContinueTapped: return "recap_continue_tapped";
                case AnalyticsEvent.SignatureLegacyOptionsSeen: return "signature_legacy_options_seen";
                case AnalyticsEvent.SignatureLegacySelected: return "signature_legacy_selected";
                case AnalyticsEvent.SignatureLegacyEquipped: return "signature_legacy_equipped";
                case AnalyticsEvent.LifeCompleted: return "life_completed";
                case AnalyticsEvent.CareerTrainingCompleted: return "career_training_completed";
                case AnalyticsEvent.GameGrowthApplied: return "game_growth_applied";
                case AnalyticsEvent.PhaseEntered: return "phase_entered";
                case AnalyticsEvent.GameAbandoned: return "game_abandoned";
                case AnalyticsEvent.DailyInningOpened: return "daily_inning_opened";
                case AnalyticsEvent.DailyInningRewarded: return "daily_inning_rewarded";
                case AnalyticsEvent.ProCareerStarted: return "pro_career_started";
                case AnalyticsEvent.ReminderChanged: return "reminder_changed";
                case AnalyticsEvent.ReminderOfferShown: return "reminder_offer_shown";
                case AnalyticsEvent.ReminderOpened: return "reminder_opened";
                case AnalyticsEvent.ReturnPlanShown: return "return_plan_shown";
                case AnalyticsEvent.ReturnPlanTapped: return "return_plan_tapped";
                case AnalyticsEvent.ReturnPlanDismissed: return "return_plan_dismissed";
                case AnalyticsEvent.ReturnPlanEligible: return "return_plan_eligible";
                case AnalyticsEvent.ReturnPlanColdStart: return "return_plan_cold_start";
                case AnalyticsEvent.ReturnPlanNextDayOpen: return "return_plan_next_day_open";
                case AnalyticsEvent.SessionEnded: return "session_ended";
                default: throw new ArgumentOutOfRangeException(nameof(value), value, null);
            }
        }
    }
}
