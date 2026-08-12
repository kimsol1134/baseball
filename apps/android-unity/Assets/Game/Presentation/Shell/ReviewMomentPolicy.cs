using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Platform.Review;

namespace Baseball.Presentation.Shell
{
    /// <summary>Maps only the three positive, durably saved iOS-equivalent moments to Play Review.</summary>
    public static class ReviewMomentPolicy
    {
        public static ReviewPromptReason? ReasonAfter(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            if (after == null) return null;
            switch (actionId)
            {
                case "start_high_school":
                case "quick_rebirth":
                case "quick_rebirth_from_recap":
                    return after.HighSchool?.IsChallengeRun != true &&
                        (after.HighSchool?.LifeNumber ?? 0) >= 3 &&
                        !string.Equals(
                            before?.HighSchool?.CareerId,
                            after.HighSchool?.CareerId,
                            StringComparison.Ordinal)
                            ? ReviewPromptReason.ThirdLife
                            : (ReviewPromptReason?)null;
                case "finalize_high_school_legacy":
                    LifeArchiveRecord record = NewestAddedRecord(before, after);
                    return DeservesGoodRecap(record, before?.Meta?.LifeArchive)
                        ? ReviewPromptReason.GoodRecap
                        : (ReviewPromptReason?)null;
                default:
                    return null;
            }
        }

        /// <summary>
        /// The drafted prompt belongs to the user's explicit result-continuation moment, not to
        /// the command that first saves the reveal. A linked, unsigned contract is also a durable
        /// recovery marker when the process stops between the tap and the Play dialog.
        /// </summary>
        public static bool ShouldRequestDraftedAtContract(GameSaveAggregate state)
        {
            if (state?.HighSchool?.Draft?.Resolved != true ||
                !state.HighSchool.Draft.Drafted ||
                state.Pro?.Origin != ProCareerOrigin.HighSchool ||
                state.Pro.Phase != ProCareerPhase.ContractOffer)
                return false;
            return string.Equals(
                state.Pro.SourceHighSchoolCareerId,
                state.HighSchool.CareerId,
                StringComparison.Ordinal);
        }

        public static bool DeservesGoodRecap(
            LifeArchiveRecord record,
            IReadOnlyList<LifeArchiveRecord> previous)
        {
            if (record == null) return false;
            if (record.Drafted || record.PledgeAchieved == true ||
                record.HighSchoolDetail?.Nicknames?.Count > 0)
                return true;
            int previousBest = (previous ?? Array.Empty<LifeArchiveRecord>())
                .Where(value => value != null && !string.Equals(
                    value.LifeId,
                    record.LifeId,
                    StringComparison.Ordinal))
                .Select(value => value.DraftEvaluation)
                .DefaultIfEmpty(0)
                .Max();
            return record.DraftEvaluation > previousBest;
        }

        private static LifeArchiveRecord NewestAddedRecord(
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            var previousIds = new HashSet<string>(
                (before?.Meta?.LifeArchive ?? Array.Empty<LifeArchiveRecord>())
                    .Where(value => value != null)
                    .Select(value => value.LifeId),
                StringComparer.Ordinal);
            return (after.Meta?.LifeArchive ?? Array.Empty<LifeArchiveRecord>())
                .Where(value => value != null && !previousIds.Contains(value.LifeId))
                .OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();
        }
    }
}
