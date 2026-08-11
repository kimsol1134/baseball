using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Baseball.Application.Meta
{
    public static class WeeklyTaskKinds
    {
        public const string PlayedOnTwoDays = "played_on_two_days";
        public const string DailyInningCompleted = "daily_inning_completed";
        public const string ImportantGamesCompleted = "important_games_completed";
        public const string ChaptersAdvanced = "chapters_advanced";
        public const string NextRunStarted = "next_run_started";
        public const string PledgeSelected = "pledge_selected";
        public const string DifferentSchoolSelected = "different_school_selected";
        public const string SequenceMasteryTriggered = "sequence_mastery_triggered";
        public const string ProWeeksAdvanced = "pro_weeks_advanced";

        public static readonly IReadOnlyList<string> All = new[]
        {
            PlayedOnTwoDays,
            DailyInningCompleted,
            ImportantGamesCompleted,
            ChaptersAdvanced,
            NextRunStarted,
            PledgeSelected,
            DifferentSchoolSelected,
            SequenceMasteryTriggered,
            ProWeeksAdvanced
        };

        public static int Target(string kind)
        {
            switch (kind)
            {
                case PlayedOnTwoDays:
                case ImportantGamesCompleted:
                case ChaptersAdvanced:
                    return 2;
                case SequenceMasteryTriggered:
                case ProWeeksAdvanced:
                    return 3;
                default:
                    return 1;
            }
        }
    }

    public sealed class WeeklyEligibility
    {
        public WeeklyEligibility(
            bool hasHighSchoolCareer,
            int remainingImportantGames,
            int remainingChapterAdvances,
            bool dailyInningUnlocked,
            bool canStartNextRun,
            bool canSelectPledge,
            bool canChooseDifferentSchool,
            bool hasProCareer)
        {
            HasHighSchoolCareer = hasHighSchoolCareer;
            RemainingImportantGames = remainingImportantGames;
            RemainingChapterAdvances = remainingChapterAdvances;
            DailyInningUnlocked = dailyInningUnlocked;
            CanStartNextRun = canStartNextRun;
            CanSelectPledge = canSelectPledge;
            CanChooseDifferentSchool = canChooseDifferentSchool;
            HasProCareer = hasProCareer;
        }

        public bool HasHighSchoolCareer { get; }
        public int RemainingImportantGames { get; }
        public int RemainingChapterAdvances { get; }
        public bool DailyInningUnlocked { get; }
        public bool CanStartNextRun { get; }
        public bool CanSelectPledge { get; }
        public bool CanChooseDifferentSchool { get; }
        public bool HasProCareer { get; }
    }

    public sealed class WeeklyTaskState
    {
        public WeeklyTaskState(string id, string kind, int target, int progress)
        {
            Id = id;
            Kind = kind;
            Target = target;
            Progress = progress;
        }

        public string Id { get; }
        public string Kind { get; }
        public int Target { get; }
        public int Progress { get; }
        public bool IsCompleted => Progress >= Target;
    }

    public sealed class WeeklyProgramState
    {
        public WeeklyProgramState(
            string weekKey,
            IReadOnlyList<WeeklyTaskState> tasks,
            IReadOnlyList<string> completedTaskIds,
            bool claimed)
        {
            WeekKey = weekKey;
            Tasks = (tasks ?? Array.Empty<WeeklyTaskState>()).ToArray();
            CompletedTaskIds = (completedTaskIds ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
            Claimed = claimed;
        }

        public string WeekKey { get; }
        public IReadOnlyList<WeeklyTaskState> Tasks { get; }
        public IReadOnlyList<string> CompletedTaskIds { get; }
        public bool Claimed { get; }
        public int CompletedCount => Tasks.Count(task =>
            CompletedTaskIds.Contains(task.Id, StringComparer.Ordinal));
        public bool RewardReady => CompletedCount >= 2 && !Claimed;
        public bool IsPerfect => Tasks.Count > 0 && CompletedCount == Tasks.Count;
    }

    public sealed class WeeklyStampState
    {
        public WeeklyStampState(
            string weekKey,
            int completedTaskCount,
            bool perfect,
            long earnedAtUnixSeconds)
        {
            WeekKey = weekKey;
            CompletedTaskCount = completedTaskCount;
            Perfect = perfect;
            EarnedAtUnixSeconds = earnedAtUnixSeconds;
        }

        public string WeekKey { get; }
        public int CompletedTaskCount { get; }
        public bool Perfect { get; }
        public long EarnedAtUnixSeconds { get; }
    }

    public sealed class WeeklyProgressState
    {
        public WeeklyProgressState(
            WeeklyProgramState program = null,
            IReadOnlyList<WeeklyStampState> stamps = null,
            string lastObservedWeekStartDayKey = null,
            IReadOnlyList<string> processedReceiptIds = null,
            IReadOnlyList<string> playedDayKeys = null)
        {
            Program = program;
            Stamps = (stamps ?? Array.Empty<WeeklyStampState>()).ToArray();
            LastObservedWeekStartDayKey = lastObservedWeekStartDayKey;
            ProcessedReceiptIds = (processedReceiptIds ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
            PlayedDayKeys = (playedDayKeys ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
        }

        public WeeklyProgramState Program { get; }
        public IReadOnlyList<WeeklyStampState> Stamps { get; }
        public string LastObservedWeekStartDayKey { get; }
        public IReadOnlyList<string> ProcessedReceiptIds { get; }
        public IReadOnlyList<string> PlayedDayKeys { get; }

        public static WeeklyProgressState Empty { get; } = new WeeklyProgressState();
    }

    public static class WeeklyProgramRules
    {
        public const int RewardSoul = 15;

        public static WeeklyProgressState Configure(
            WeeklyProgressState current,
            WeeklyEligibility eligibility,
            string stableUserId,
            DateTimeOffset instant)
        {
            current = current ?? WeeklyProgressState.Empty;
            var weekStart = SeoulGameCalendar.WeekStartDayKey(instant);
            if (current.LastObservedWeekStartDayKey != null &&
                string.CompareOrdinal(weekStart, current.LastObservedWeekStartDayKey) < 0)
            {
                return current;
            }

            var weekKey = SeoulGameCalendar.WeekKey(instant);
            WeeklyProgramState program;
            IReadOnlyList<string> dayKeys;
            IReadOnlyList<string> receipts;
            if (current.Program != null &&
                string.Equals(current.Program.WeekKey, weekKey, StringComparison.Ordinal))
            {
                program = Reconcile(current.Program, eligibility, stableUserId);
                dayKeys = current.PlayedDayKeys;
                receipts = current.ProcessedReceiptIds;
            }
            else
            {
                program = Make(weekKey, stableUserId, eligibility);
                dayKeys = Array.Empty<string>();
                receipts = Array.Empty<string>();
            }

            return new WeeklyProgressState(
                program,
                current.Stamps,
                weekStart,
                receipts,
                dayKeys);
        }

        public static WeeklyProgressState Record(
            WeeklyProgressState current,
            string kind,
            int amount,
            string receiptId,
            DateTimeOffset instant)
        {
            current = current ?? WeeklyProgressState.Empty;
            if (amount <= 0 || string.IsNullOrWhiteSpace(receiptId) ||
                current.ProcessedReceiptIds.Contains(receiptId, StringComparer.Ordinal))
            {
                return current;
            }

            var weekStart = SeoulGameCalendar.WeekStartDayKey(instant);
            if (current.LastObservedWeekStartDayKey != null &&
                string.CompareOrdinal(weekStart, current.LastObservedWeekStartDayKey) < 0)
            {
                return current;
            }

            var program = current.Program;
            if (program == null ||
                !string.Equals(program.WeekKey, SeoulGameCalendar.WeekKey(instant), StringComparison.Ordinal))
            {
                return current;
            }

            var processed = current.ProcessedReceiptIds.Concat(new[] { receiptId }).ToArray();
            var dayKeys = current.PlayedDayKeys;
            if (string.Equals(kind, WeeklyTaskKinds.PlayedOnTwoDays, StringComparison.Ordinal))
            {
                var dayKey = SeoulGameCalendar.DayKey(instant);
                dayKeys = dayKeys.Concat(new[] { dayKey })
                    .Distinct(StringComparer.Ordinal)
                    .OrderBy(value => value, StringComparer.Ordinal)
                    .ToArray();
                amount = dayKeys.Count;
            }

            var tasks = program.Tasks.Select(task =>
            {
                if (!string.Equals(task.Kind, kind, StringComparison.Ordinal))
                {
                    return task;
                }

                var progress = string.Equals(kind, WeeklyTaskKinds.PlayedOnTwoDays, StringComparison.Ordinal)
                    ? Math.Min(task.Target, amount)
                    : Math.Min(task.Target, task.Progress + amount);
                return new WeeklyTaskState(task.Id, task.Kind, task.Target, progress);
            }).ToArray();
            var completed = program.CompletedTaskIds.Concat(
                tasks.Where(task => task.IsCompleted).Select(task => task.Id));
            var updated = new WeeklyProgramState(
                program.WeekKey,
                tasks,
                completed.ToArray(),
                program.Claimed);
            return new WeeklyProgressState(
                updated,
                UpgradePerfectStamp(current.Stamps, updated),
                weekStart,
                processed,
                dayKeys);
        }

        public static WeeklyProgressState Claim(
            WeeklyProgressState current,
            DateTimeOffset instant)
        {
            if (current?.Program == null || !current.Program.RewardReady)
            {
                return current;
            }

            var program = new WeeklyProgramState(
                current.Program.WeekKey,
                current.Program.Tasks,
                current.Program.CompletedTaskIds,
                true);
            var stamp = new WeeklyStampState(
                program.WeekKey,
                program.CompletedCount,
                program.IsPerfect,
                instant.ToUnixTimeSeconds());
            var stamps = current.Stamps.Where(value =>
                    !string.Equals(value.WeekKey, stamp.WeekKey, StringComparison.Ordinal))
                .Prepend(stamp)
                .ToArray();
            return new WeeklyProgressState(
                program,
                stamps,
                current.LastObservedWeekStartDayKey,
                current.ProcessedReceiptIds,
                current.PlayedDayKeys);
        }

        public static WeeklyProgramState Make(
            string weekKey,
            string stableUserId,
            WeeklyEligibility eligibility)
        {
            var eligible = EligibleKinds(eligibility)
                .OrderBy(kind => Rank(stableUserId, weekKey, kind))
                .ThenBy(kind => kind, StringComparer.Ordinal)
                .ToList();
            if (eligible.Count < 3)
            {
                return null;
            }

            if (eligible.Remove(WeeklyTaskKinds.PlayedOnTwoDays))
            {
                eligible.Insert(0, WeeklyTaskKinds.PlayedOnTwoDays);
            }

            var tasks = eligible.Take(3)
                .Select(kind => new WeeklyTaskState(
                    weekKey + "-" + kind,
                    kind,
                    WeeklyTaskKinds.Target(kind),
                    0))
                .ToArray();
            return new WeeklyProgramState(weekKey, tasks, Array.Empty<string>(), false);
        }

        public static IReadOnlyList<string> EligibleKinds(WeeklyEligibility value)
        {
            var result = new List<string>();
            if (value.HasHighSchoolCareer)
            {
                if (value.RemainingImportantGames >= 2) result.Add(WeeklyTaskKinds.ImportantGamesCompleted);
                if (value.RemainingChapterAdvances >= 2) result.Add(WeeklyTaskKinds.ChaptersAdvanced);
            }
            if (value.CanStartNextRun) result.Add(WeeklyTaskKinds.NextRunStarted);
            if (value.CanSelectPledge) result.Add(WeeklyTaskKinds.PledgeSelected);
            if (value.CanChooseDifferentSchool) result.Add(WeeklyTaskKinds.DifferentSchoolSelected);
            if (value.HasHighSchoolCareer || value.HasProCareer)
            {
                result.Add(WeeklyTaskKinds.SequenceMasteryTriggered);
                result.Add(WeeklyTaskKinds.PlayedOnTwoDays);
            }
            if (value.HasProCareer) result.Add(WeeklyTaskKinds.ProWeeksAdvanced);
            return result;
        }

        private static WeeklyProgramState Reconcile(
            WeeklyProgramState existing,
            WeeklyEligibility eligibility,
            string stableUserId)
        {
            var eligible = EligibleKinds(eligibility)
                .OrderBy(kind => Rank(stableUserId, existing.WeekKey, kind))
                .ThenBy(kind => kind, StringComparer.Ordinal)
                .ToArray();
            var eligibleSet = new HashSet<string>(eligible, StringComparer.Ordinal);
            var tasks = existing.Tasks.ToArray();
            var replace = tasks.Select((task, index) => new { task, index })
                .Where(value => !value.task.IsCompleted &&
                    !existing.CompletedTaskIds.Contains(value.task.Id, StringComparer.Ordinal) &&
                    !IsStillFeasible(value.task, eligibleSet, eligibility))
                .Select(value => value.index)
                .ToArray();
            var retained = new HashSet<string>(
                tasks.Where((_, index) => !replace.Contains(index)).Select(task => task.Kind),
                StringComparer.Ordinal);
            var replacements = new Queue<string>(eligible.Where(kind => !retained.Contains(kind)));
            var completedTaskIds = new HashSet<string>(
                existing.CompletedTaskIds,
                StringComparer.Ordinal);
            for (var index = 0; index < replace.Length; index++)
            {
                int taskIndex = replace[index];
                if (replacements.Count > 0)
                {
                    var kind = replacements.Dequeue();
                    tasks[taskIndex] = new WeeklyTaskState(
                        existing.WeekKey + "-" + kind,
                        kind,
                        WeeklyTaskKinds.Target(kind),
                        0);
                }
                else if (string.Equals(
                    tasks[taskIndex].Kind,
                    WeeklyTaskKinds.DailyInningCompleted,
                    StringComparison.Ordinal))
                {
                    WeeklyTaskState retired = tasks[taskIndex];
                    tasks[taskIndex] = new WeeklyTaskState(
                        retired.Id,
                        retired.Kind,
                        retired.Target,
                        retired.Target);
                    completedTaskIds.Add(retired.Id);
                }
            }
            return new WeeklyProgramState(
                existing.WeekKey,
                tasks,
                completedTaskIds.ToArray(),
                existing.Claimed);
        }

        private static bool IsStillFeasible(
            WeeklyTaskState task,
            ISet<string> eligibleKinds,
            WeeklyEligibility eligibility)
        {
            if (string.Equals(task.Kind, WeeklyTaskKinds.ImportantGamesCompleted, StringComparison.Ordinal))
            {
                return eligibility.HasHighSchoolCareer &&
                    Math.Min(task.Target, Math.Max(0, task.Progress)) +
                    Math.Max(0, eligibility.RemainingImportantGames) >= task.Target;
            }
            if (string.Equals(task.Kind, WeeklyTaskKinds.ChaptersAdvanced, StringComparison.Ordinal))
            {
                return eligibility.HasHighSchoolCareer &&
                    Math.Min(task.Target, Math.Max(0, task.Progress)) +
                    Math.Max(0, eligibility.RemainingChapterAdvances) >= task.Target;
            }
            return eligibleKinds.Contains(task.Kind);
        }

        private static IReadOnlyList<WeeklyStampState> UpgradePerfectStamp(
            IReadOnlyList<WeeklyStampState> stamps,
            WeeklyProgramState program)
        {
            if (!program.Claimed || !program.IsPerfect) return stamps;
            return stamps.Select(stamp =>
                string.Equals(stamp.WeekKey, program.WeekKey, StringComparison.Ordinal) && !stamp.Perfect
                    ? new WeeklyStampState(stamp.WeekKey, program.CompletedCount, true, stamp.EarnedAtUnixSeconds)
                    : stamp).ToArray();
        }

        private static ulong Rank(string stableUserId, string weekKey, string kind)
        {
            var bytes = Encoding.UTF8.GetBytes(
                (stableUserId ?? string.Empty) + "|" + weekKey + "|" + kind + "|weekly-v1");
            var hash = 14695981039346656037UL;
            foreach (var value in bytes)
            {
                hash ^= value;
                hash *= 1099511628211UL;
            }
            return hash;
        }
    }
}
