using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Application.Stores
{
    public sealed partial class GameCommandTransition
    {

        private static bool ValidHighSchoolChoice(
            HighSchoolCareerReadModel current,
            HighSchoolAction action)
        {
            switch (action.Kind)
            {
                case "choose_school":
                    return ChoiceMatchesWhenPresent(current.SchoolChoices, action.Value);
                case "train":
                case "train_block":
                    var training = (action.Value ?? string.Empty).Split(':');
                    if (training.Length != 2 && training.Length != 3) return false;
                    var breakingBall = string.Equals(training[0], "breaking_ball", StringComparison.Ordinal);
                    var targetValid = training.Length == 3
                        ? breakingBall && ChoiceMatchesWhenPresent(current.TrainingPitchChoices, training[2])
                        : !breakingBall || current.TrainingPitchChoices.Count == 0;
                    return targetValid &&
                        ChoiceMatchesWhenPresent(current.TrainingFocusChoices, training[0]) &&
                        ChoiceMatchesWhenPresent(current.TrainingIntensityChoices, training[1]);
                case "relationship":
                    return ChoiceMatchesWhenPresent(current.RelationshipChoices, action.Value);
                case "awakening":
                    return ChoiceMatchesWhenPresent(current.AwakeningChoices, action.Value);
                case "select_signature_legacy":
                    return current.LegacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                        ChoiceMatchesWhenPresent(current.SignatureLegacyChoices, action.Value);
                case "select_legacy":
                    if (current.LegacySelectionMode != LegacySelectionMode.Memories) return false;
                    if (current.LegacyMemoryChoices.Count == 0) return true;
                    var selected = (action.Value ?? string.Empty)
                        .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                    return selected.Length == current.MemorySlots &&
                        selected.Distinct(StringComparer.Ordinal).Count() == selected.Length &&
                        selected.All(value => ChoiceMatches(current.LegacyMemoryChoices, value));
                default:
                    return true;
            }
        }

        private static bool ValidProChoice(ProCareerReadModel current, ProCareerAction action)
        {
            if (current.Phase == ProCareerPhase.ContractOffer) return false;
            if (current.WeekPlanChoices.Count == 0 && current.SeasonDecision == null &&
                current.OffseasonChoices.Count == 0)
            {
                return true;
            }
            switch (current.Phase)
            {
                case ProCareerPhase.WeeklyPlan:
                    return (string.Equals(action.Kind, "advance_week", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "plan_week", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "advance_segment", StringComparison.Ordinal)) &&
                        ValidProWeekPayload(current, action.Value);
                case ProCareerPhase.SeasonDecision:
                    return (string.Equals(action.Kind, "season_decision", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "resolve_season_decision", StringComparison.Ordinal)) &&
                        current.SeasonDecision != null &&
                        ChoiceMatches(current.SeasonDecision.Choices, action.Value);
                case ProCareerPhase.SeasonReview:
                    return string.Equals(action.Kind, "review_season", StringComparison.Ordinal);
                case ProCareerPhase.Offseason:
                case ProCareerPhase.RetirementDecision:
                    if (string.Equals(action.Kind, "retire", StringComparison.Ordinal)) return true;
                    return (string.Equals(action.Kind, "offseason", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "continue_career", StringComparison.Ordinal)) &&
                        ChoiceMatchesWhenPresent(current.OffseasonChoices, action.Value);
                default:
                    return false;
            }
        }

        private static bool ValidProWeekPayload(ProCareerReadModel current, string payload)
        {
            var parts = (payload ?? string.Empty)
                .Split(new[] { '|' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 1 || parts.Length > 2 ||
                !ChoiceMatchesWhenPresent(current.WeekPlanChoices, parts[0]))
            {
                return false;
            }
            var movement = string.Equals(parts[0], "develop_movement", StringComparison.Ordinal);
            if (parts.Length == 2)
                return movement && ChoiceMatchesWhenPresent(current.DevelopmentPitchChoices, parts[1]);
            return !movement || current.DevelopmentPitchChoices.Count == 0;
        }

        private static bool ChoiceMatchesWhenPresent(
            IReadOnlyList<CareerChoiceReadModel> choices,
            string payload)
        {
            return choices == null || choices.Count == 0 || ChoiceMatches(choices, payload);
        }

        private static bool ChoiceMatches(
            IReadOnlyList<CareerChoiceReadModel> choices,
            string payload)
        {
            return !string.IsNullOrWhiteSpace(payload) && choices.Any(value =>
                value.Enabled && (string.Equals(value.Id, payload, StringComparison.Ordinal) ||
                                  string.Equals(value.Payload, payload, StringComparison.Ordinal)));
        }

        private static bool ValidStartedHighSchool(HighSchoolCareerReadModel value, int lifeNumber)
        {
            return value != null && !string.IsNullOrWhiteSpace(value.CareerId) &&
                !string.IsNullOrWhiteSpace(value.NextSeed) && value.LifeNumber == lifeNumber &&
                value.Ratings != null && value.Performance != null;
        }

        private static bool ValidHighSchoolAdvance(
            HighSchoolCareerReadModel before,
            HighSchoolCareerReadModel after)
        {
            return after != null &&
                string.Equals(before.CareerId, after.CareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                after.CoreRevision > before.CoreRevision &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.Performance != null;
        }

        private static bool ValidHighSchoolReservation(
            HighSchoolCareerReadModel before,
            HighSchoolCareerReadModel after)
        {
            return after != null &&
                string.Equals(before.CareerId, after.CareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                after.CoreRevision == before.CoreRevision &&
                after.Phase == before.Phase &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.Performance != null;
        }

        private static bool ValidTutorialReservation(
            HighSchoolCareerReadModel before,
            HighSchoolCareerReadModel after)
        {
            return after != null &&
                string.Equals(before.CareerId, after.CareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                string.Equals(before.NextSeed, after.NextSeed, StringComparison.Ordinal) &&
                string.Equals(before.CoreStateJson, after.CoreStateJson, StringComparison.Ordinal) &&
                after.CoreRevision == before.CoreRevision && after.Phase == before.Phase &&
                after.TutorialAttemptCount == before.TutorialAttemptCount + 1 &&
                after.TutorialCompleted == before.TutorialCompleted &&
                after.Ratings != null && after.Performance != null;
        }

        private static bool ValidStartedPro(ProCareerReadModel value, ProCareerOrigin origin)
        {
            var validInitialPhase = origin == ProCareerOrigin.HighSchool
                ? value?.Phase == ProCareerPhase.ContractOffer && value.ContractOffer != null
                : value?.Phase == ProCareerPhase.WeeklyPlan && value.CoreRevision > 0;
            return value != null && validInitialPhase && value.Origin == origin &&
                !string.IsNullOrWhiteSpace(value.ProCareerId) &&
                !string.IsNullOrWhiteSpace(value.PlayerId) &&
                !string.IsNullOrWhiteSpace(value.NextSeed) &&
                value.Ratings != null && value.CurrentSeason != null;
        }

        private static bool ValidProAdvance(ProCareerReadModel before, ProCareerReadModel after)
        {
            return after != null && after.Origin == before.Origin &&
                string.Equals(before.ProCareerId, after.ProCareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                string.Equals(
                    before.SourceHighSchoolCareerId,
                    after.SourceHighSchoolCareerId,
                    StringComparison.Ordinal) &&
                after.CoreRevision > before.CoreRevision &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.CurrentSeason != null;
        }

        private static bool ValidProReservation(ProCareerReadModel before, ProCareerReadModel after)
        {
            return after != null && after.Origin == before.Origin &&
                string.Equals(before.ProCareerId, after.ProCareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                string.Equals(
                    before.SourceHighSchoolCareerId,
                    after.SourceHighSchoolCareerId,
                    StringComparison.Ordinal) &&
                after.CoreRevision == before.CoreRevision && after.Phase == before.Phase &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.CurrentSeason != null;
        }

        private static ApplicationStage StageFor(HighSchoolCareerReadModel state)
        {
            if (state.Phase == HighSchoolPhase.Draft ||
                state.Draft?.Resolved == true && state.Draft.Drafted &&
                state.Phase == HighSchoolPhase.Completed)
            {
                return ApplicationStage.Draft;
            }
            if (state.Phase == HighSchoolPhase.Legacy || state.Phase == HighSchoolPhase.Completed)
                return ApplicationStage.Legacy;
            return ApplicationStage.HighSchool;
        }

        private static ApplicationStage StageFor(ProCareerReadModel state)
        {
            return state.Phase == ProCareerPhase.RetirementDecision ||
                   state.Phase == ProCareerPhase.Completed
                ? ApplicationStage.Retirement
                : ApplicationStage.Pro;
        }
    }
}
