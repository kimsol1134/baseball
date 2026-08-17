using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Pitch;

namespace Baseball.Presentation.Shell
{
    public sealed partial class StoreBaseballCareerReadModel
    {

        public static ShellRoute PreferredRouteFor(GameSaveAggregate state)
        {
            if (state == null) return ShellRoute.Opening;
            if (state.PitchResume != null) return ShellRoute.PitchHandoff;
            if (state.PendingPitchCompletion != null) return CareerRouteWithoutInterruption(state);
            switch (state.Stage)
            {
                case ApplicationStage.Opening: return ShellRoute.Opening;
                case ApplicationStage.Setup:
                case ApplicationStage.BetweenLives: return ShellRoute.Setup;
                case ApplicationStage.HighSchool:
                case ApplicationStage.Draft: return HighSchoolRoute(state.HighSchool);
                case ApplicationStage.Pro: return ProRoute(state.Pro);
                case ApplicationStage.Retirement: return ShellRoute.ProRetirement;
                case ApplicationStage.Legacy: return ShellRoute.RunRecap;
                case ApplicationStage.Deleted: return ShellRoute.Opening;
                default: return ShellRoute.Opening;
            }
        }

        public static ShellRoute RetiredDailyFallbackFor(GameSaveAggregate state)
        {
            if (state?.PendingPitchCompletion != null)
                return CareerRouteWithoutInterruption(state);
            if (state?.Pro != null) return ProRoute(state.Pro);
            if (state?.HighSchool != null) return HighSchoolRoute(state.HighSchool);
            return ShellRoute.Opening;
        }

        private static ShellRoute CareerRouteWithoutInterruption(GameSaveAggregate state)
        {
            if (state.Pro != null) return ProRoute(state.Pro);
            if (state.HighSchool != null) return HighSchoolRoute(state.HighSchool);
            return ShellRoute.Records;
        }

        private static ShellRoute HighSchoolRoute(HighSchoolCareerReadModel career)
        {
            if (career == null) return ShellRoute.Setup;
            switch (career.Phase)
            {
                case HighSchoolPhase.Prologue:
                case HighSchoolPhase.SchoolSelection: return ShellRoute.Prologue;
                case HighSchoolPhase.Training: return ShellRoute.Training;
                case HighSchoolPhase.Relationship: return ShellRoute.Relationship;
                case HighSchoolPhase.ImportantGame: return ShellRoute.ImportantGame;
                case HighSchoolPhase.Awakening: return ShellRoute.Awakening;
                case HighSchoolPhase.Draft: return ShellRoute.Draft;
                case HighSchoolPhase.Legacy:
                case HighSchoolPhase.Completed: return ShellRoute.RunRecap;
                default: return ShellRoute.HighSchoolOverview;
            }
        }

        private static ShellRoute ProRoute(ProCareerReadModel career)
        {
            if (career == null) return ShellRoute.ProContract;
            switch (career.Phase)
            {
                case ProCareerPhase.ContractOffer: return ShellRoute.ProContract;
                case ProCareerPhase.WeeklyPlan: return ShellRoute.ProWeek;
                case ProCareerPhase.ImportantGame: return ShellRoute.ImportantGame;
                case ProCareerPhase.SeasonDecision:
                case ProCareerPhase.SeasonReview: return ShellRoute.ProSeason;
                case ProCareerPhase.Offseason: return ShellRoute.ProRetirement;
                case ProCareerPhase.RetirementDecision: return ShellRoute.ProRetirement;
                case ProCareerPhase.Completed: return ShellRoute.ProRetirement;
                default: return ShellRoute.ProWeek;
            }
        }

        private static ShellRoute RouteForPlanner(string route, ShellRoute fallback)
        {
            switch ((route ?? string.Empty).ToLowerInvariant())
            {
                case "opening": return ShellRoute.Opening;
                case "setup": return ShellRoute.Setup;
                case "high-school": return ShellRoute.HighSchoolOverview;
                case "pro": return ShellRoute.ProWeek;
                case "retirement": return ShellRoute.ProRetirement;
                case "legacy": return ShellRoute.RunRecap;
                case "pitch/resume":
                case "pitch/result": return ShellRoute.PitchHandoff;
                default: return fallback;
            }
        }
    }
}
