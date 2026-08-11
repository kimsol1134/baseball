using System;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;

namespace Baseball.Application.Commands
{
    /// <summary>
    /// Pure projection used when the weekly screen is entered or a new Seoul week is observed.
    /// A null command means the durable board is already reconciled for this observation.
    /// </summary>
    public static class WeeklyProgramCommandFactory
    {
        public static ConfigureWeeklyProgramCommand Observe(
            GameSaveAggregate current,
            DateTimeOffset observedAt)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            var eligibility = Eligibility(current);
            var projected = WeeklyProgramRules.Configure(
                current.Meta.Weekly,
                eligibility,
                current.InstallId,
                observedAt);
            return Same(current.Meta.Weekly, projected)
                ? null
                : new ConfigureWeeklyProgramCommand(eligibility, observedAt);
        }

        public static WeeklyEligibility Eligibility(GameSaveAggregate current)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            var highSchool = current.HighSchool;
            var pro = current.Pro;
            var playablePro = pro != null && pro.Phase != ProCareerPhase.Completed &&
                pro.Phase != ProCareerPhase.RetirementDecision;
            if (playablePro)
            {
                return new WeeklyEligibility(
                    false, 0, 0, true, false, false, false, true);
            }

            var beforeSchoolChoice = highSchool != null &&
                (highSchool.Phase == HighSchoolPhase.Prologue ||
                 highSchool.Phase == HighSchoolPhase.SchoolSelection);
            var playableHighSchool = highSchool != null &&
                (highSchool.Phase == HighSchoolPhase.Prologue ||
                 highSchool.Phase == HighSchoolPhase.SchoolSelection ||
                 highSchool.Phase == HighSchoolPhase.Training ||
                 highSchool.Phase == HighSchoolPhase.Relationship ||
                 highSchool.Phase == HighSchoolPhase.ImportantGame ||
                 highSchool.Phase == HighSchoolPhase.Awakening ||
                 highSchool.Phase == HighSchoolPhase.ChapterReview);
            var activeHighSchool = playableHighSchool && pro == null && !highSchool.IsChallengeRun;
            var hasArchive = current.Meta.LifeArchive.Count > 0;
            var hasPreviousSchool = current.Meta.LifeArchive.FirstOrDefault()?.SchoolName != null;
            var canStartNextRun = (highSchool == null || !highSchool.IsChallengeRun) && hasArchive &&
                (pro == null || pro.Phase == ProCareerPhase.Completed);
            return new WeeklyEligibility(
                activeHighSchool,
                activeHighSchool ? Math.Max(0, highSchool.RemainingImportantGames) : 0,
                activeHighSchool ? Math.Max(0, highSchool.RemainingChapterAdvances) : 0,
                (highSchool?.Performance?.ImportantGames ?? 0) >= 1 || hasArchive,
                canStartNextRun,
                activeHighSchool && beforeSchoolChoice && !highSchool.PledgeDecided,
                activeHighSchool && beforeSchoolChoice && hasPreviousSchool,
                false);
        }

        private static bool Same(WeeklyProgressState left, WeeklyProgressState right)
        {
            if (ReferenceEquals(left, right)) return true;
            if (left == null || right == null ||
                !string.Equals(left.LastObservedWeekStartDayKey,
                    right.LastObservedWeekStartDayKey, StringComparison.Ordinal) ||
                !left.ProcessedReceiptIds.SequenceEqual(right.ProcessedReceiptIds) ||
                !left.PlayedDayKeys.SequenceEqual(right.PlayedDayKeys) ||
                !Same(left.Program, right.Program) || left.Stamps.Count != right.Stamps.Count)
            {
                return false;
            }
            return left.Stamps.Zip(right.Stamps, (a, b) =>
                    string.Equals(a.WeekKey, b.WeekKey, StringComparison.Ordinal) &&
                    a.CompletedTaskCount == b.CompletedTaskCount && a.Perfect == b.Perfect &&
                    a.EarnedAtUnixSeconds == b.EarnedAtUnixSeconds)
                .All(value => value);
        }

        private static bool Same(WeeklyProgramState left, WeeklyProgramState right)
        {
            if (ReferenceEquals(left, right)) return true;
            if (left == null || right == null ||
                !string.Equals(left.WeekKey, right.WeekKey, StringComparison.Ordinal) ||
                left.Claimed != right.Claimed || left.Tasks.Count != right.Tasks.Count ||
                !left.CompletedTaskIds.SequenceEqual(right.CompletedTaskIds))
            {
                return false;
            }
            return left.Tasks.Zip(right.Tasks, (a, b) =>
                    string.Equals(a.Id, b.Id, StringComparison.Ordinal) &&
                    string.Equals(a.Kind, b.Kind, StringComparison.Ordinal) &&
                    a.Target == b.Target && a.Progress == b.Progress)
                .All(value => value);
        }
    }
}
