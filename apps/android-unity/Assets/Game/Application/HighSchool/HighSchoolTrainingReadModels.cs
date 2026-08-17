using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Application.HighSchool
{
    public sealed class TrainingResultReadModel
    {
        public TrainingResultReadModel(
            int number,
            string focus,
            string intensity,
            int growth,
            int fatigueChange,
            string feedback,
            int? metricBefore,
            int? metricAfter,
            bool opportunityHit,
            bool jackpot,
            string targetPitch = null,
            string bloomedAbility = null,
            string bloomedGrade = null)
        {
            Number = number;
            Focus = focus;
            Intensity = intensity;
            Growth = growth;
            FatigueChange = fatigueChange;
            Feedback = feedback;
            MetricBefore = metricBefore;
            MetricAfter = metricAfter;
            OpportunityHit = opportunityHit;
            Jackpot = jackpot;
            TargetPitch = targetPitch;
            BloomedAbility = bloomedAbility;
            BloomedGrade = bloomedGrade;
        }

        public int Number { get; }
        public string Focus { get; }
        public string Intensity { get; }
        public int Growth { get; }
        public int FatigueChange { get; }
        public string Feedback { get; }
        public int? MetricBefore { get; }
        public int? MetricAfter { get; }
        public bool OpportunityHit { get; }
        public bool Jackpot { get; }
        public string TargetPitch { get; }
        /// <summary>Stable TalentAbility wire captured by Core when a ceiling blooms.</summary>
        public string BloomedAbility { get; }
        /// <summary>Stable TalentGrade wire captured with BloomedAbility.</summary>
        public string BloomedGrade { get; }
    }


    public sealed class TrainingBlockResultReadModel
    {
        public TrainingBlockResultReadModel(
            int maximumSessions,
            int completedSessions,
            string focus,
            string intensity,
            string targetPitch,
            string stopReason,
            int growth,
            int fatigueChange,
            IReadOnlyList<TrainingResultReadModel> sessions = null,
            string bloomedAbility = null,
            string bloomedGrade = null)
        {
            MaximumSessions = maximumSessions;
            CompletedSessions = completedSessions;
            Focus = focus;
            Intensity = intensity;
            TargetPitch = targetPitch;
            StopReason = stopReason;
            Growth = growth;
            FatigueChange = fatigueChange;
            Sessions = (sessions ?? Array.Empty<TrainingResultReadModel>()).ToArray();
            BloomedAbility = bloomedAbility;
            BloomedGrade = bloomedGrade;
        }

        public int MaximumSessions { get; }
        public int CompletedSessions { get; }
        public string Focus { get; }
        public string Intensity { get; }
        public string TargetPitch { get; }
        public string StopReason { get; }
        public int Growth { get; }
        public int FatigueChange { get; }
        public IReadOnlyList<TrainingResultReadModel> Sessions { get; }
        /// <summary>The first Core-reported bloom in this bounded block, if any.</summary>
        public string BloomedAbility { get; }
        public string BloomedGrade { get; }
    }


    /// <summary>
    /// Core-calculated growth outlook for one exact focus/intensity payload pair. Presentation
    /// selects a row; it does not reproduce fatigue, opportunity, talent, or career-wind rules.
    /// </summary>
    public sealed class TrainingOutlookReadModel
    {
        public TrainingOutlookReadModel(
            string focusId,
            string intensityId,
            string outlookId,
            string title,
            string summary)
        {
            FocusId = focusId;
            IntensityId = intensityId;
            OutlookId = outlookId;
            Title = title;
            Summary = summary;
        }

        public string FocusId { get; }
        public string IntensityId { get; }
        public string OutlookId { get; }
        public string Title { get; }
        public string Summary { get; }
    }


    public static class HighSchoolTrainingOutlookProjection
    {
        /// <summary>
        /// Returns the saved Core projection only when both supplied payloads are currently
        /// enabled choices. Null is the fail-closed result for stale, blank, or illegal payloads.
        /// </summary>
        public static TrainingOutlookReadModel Resolve(
            HighSchoolCareerReadModel career,
            string focusPayload,
            string intensityPayload)
        {
            if (career == null || career.Phase != HighSchoolPhase.Training ||
                string.IsNullOrWhiteSpace(focusPayload) ||
                string.IsNullOrWhiteSpace(intensityPayload))
            {
                return null;
            }
            var focusAllowed = career.TrainingFocusChoices.Any(value =>
                value != null && value.Enabled &&
                string.Equals(value.Payload, focusPayload, StringComparison.Ordinal));
            var intensityAllowed = career.TrainingIntensityChoices.Any(value =>
                value != null && value.Enabled &&
                string.Equals(value.Payload, intensityPayload, StringComparison.Ordinal));
            if (!focusAllowed || !intensityAllowed) return null;
            return career.TrainingOutlooks.FirstOrDefault(value =>
                value != null &&
                string.Equals(value.FocusId, focusPayload, StringComparison.Ordinal) &&
                string.Equals(value.IntensityId, intensityPayload, StringComparison.Ordinal));
        }
    }


    public static class HighSchoolTrainingActionPayload
    {
        public const string SingleAction = "train";
        public const string BlockAction = "train_block";
        public const int MaximumBlockSessions = 3;

        public static string Encode(string focusId, string intensityId, string targetPitchId = null)
        {
            if (string.IsNullOrWhiteSpace(focusId)) throw new ArgumentException("A focus ID is required.", nameof(focusId));
            if (string.IsNullOrWhiteSpace(intensityId)) throw new ArgumentException("An intensity ID is required.", nameof(intensityId));
            return string.IsNullOrWhiteSpace(targetPitchId)
                ? focusId + ":" + intensityId
                : focusId + ":" + intensityId + ":" + targetPitchId;
        }
    }
}
