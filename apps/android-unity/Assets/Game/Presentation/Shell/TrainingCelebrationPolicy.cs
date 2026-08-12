using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    public sealed class TrainingCelebrationViewModel
    {
        public TrainingCelebrationViewModel(
            string receiptId,
            string title,
            string abilityTitle,
            int before,
            int after,
            int growth,
            string nextStep,
            string summary,
            bool jackpot,
            int sessions,
            string bloomedAbilityTitle = null,
            string bloomedGrade = null)
        {
            ReceiptId = receiptId ?? throw new ArgumentNullException(nameof(receiptId));
            Title = title ?? string.Empty;
            AbilityTitle = abilityTitle ?? string.Empty;
            Before = before;
            After = after;
            Growth = growth;
            NextStep = nextStep ?? string.Empty;
            Summary = summary ?? string.Empty;
            Jackpot = jackpot;
            Sessions = sessions;
            BloomedAbilityTitle = bloomedAbilityTitle ?? string.Empty;
            BloomedGrade = bloomedGrade ?? string.Empty;
        }

        public string ReceiptId { get; }
        public string Title { get; }
        public string AbilityTitle { get; }
        public int Before { get; }
        public int After { get; }
        public int Growth { get; }
        public string NextStep { get; }
        public string Summary { get; }
        public bool Jackpot { get; }
        public int Sessions { get; }
        public string BloomedAbilityTitle { get; }
        public string BloomedGrade { get; }
        public bool HasBloom => !string.IsNullOrWhiteSpace(BloomedAbilityTitle) &&
            !string.IsNullOrWhiteSpace(BloomedGrade);
    }

    public static class TrainingCelebrationPolicy
    {
        private static readonly (int Minimum, string Label)[] RatingSteps =
        {
            (33, "성장 중인 기본기"),
            (38, "고교 주전 경쟁"),
            (43, "고교 상위권 도전"),
            (47, "지역에서 손꼽는 재능"),
            (50, "프로 평균"),
            (55, "프로 평균 이상"),
            (65, "프로 최상급"),
            (75, "세대 최고 수준"),
        };

        public static TrainingCelebrationViewModel Project(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            if (after?.HighSchool == null ||
                !string.Equals(before?.HighSchool?.CareerId, after.HighSchool.CareerId, StringComparison.Ordinal))
                return null;
            int beforeNumber = before.HighSchool.LastTraining?.Number ?? 0;
            IReadOnlyList<TrainingResultReadModel> sessions;
            if (actionId == "train_block")
                sessions = after.HighSchool.LastTrainingBlock?.Sessions ?? Array.Empty<TrainingResultReadModel>();
            else if (actionId == "train")
                sessions = after.HighSchool.LastTraining == null
                    ? Array.Empty<TrainingResultReadModel>()
                    : new[] { after.HighSchool.LastTraining };
            else
                return null;

            TrainingResultReadModel[] fresh = sessions
                .Where(value => value != null && value.Number > beforeNumber)
                .OrderBy(value => value.Number)
                .ToArray();
            if (fresh.Length == 0 || fresh.Sum(value => Math.Max(0, value.Growth)) <= 0)
                return null;
            TrainingResultReadModel first = fresh.First(value => value.Growth > 0);
            TrainingResultReadModel last = fresh.Last(value => value.Growth > 0);
            if (!first.MetricBefore.HasValue || !last.MetricAfter.HasValue) return null;
            int growth = fresh.Sum(value => Math.Max(0, value.Growth));
            bool jackpot = fresh.Any(value => value.Jackpot);
            TrainingResultReadModel bloom = fresh.FirstOrDefault(value =>
                !string.IsNullOrWhiteSpace(value.BloomedAbility) &&
                !string.IsNullOrWhiteSpace(value.BloomedGrade));
            string receipt = after.HighSchool.CareerId + ":training:" +
                fresh[0].Number + "-" + fresh[fresh.Length - 1].Number;
            string summary = fresh.Length == 1
                ? first.Feedback
                : fresh.Length + "회 연속 훈련 · 총 성장 +" + growth +
                  " · 마지막 결과: " + last.Feedback;
            return new TrainingCelebrationViewModel(
                receipt,
                bloom != null ? "재능이 만개했습니다" : jackpot ? "대성공!" : "능력이 올랐습니다",
                AbilityTitle(last.Focus),
                first.MetricBefore.Value,
                last.MetricAfter.Value,
                growth,
                NextStep(last.MetricAfter.Value),
                summary,
                jackpot,
                fresh.Length,
                bloom == null ? null : AbilityTitleFromTalent(bloom.BloomedAbility),
                bloom?.BloomedGrade?.ToUpperInvariant());
        }

        private static string AbilityTitle(string focus)
        {
            switch (focus)
            {
                case "velocity": return "구위";
                case "command":
                case "game_planning": return "제구";
                case "breaking_ball": return "변화";
                case "stamina":
                case "recovery": return "체력";
                default: return "능력";
            }
        }

        private static string AbilityTitleFromTalent(string ability)
        {
            switch ((ability ?? string.Empty).ToLowerInvariant())
            {
                case "stuff": return "구위";
                case "command": return "제구";
                case "movement": return "변화";
                case "stamina": return "체력";
                default: return "투수 재능";
            }
        }

        private static string NextStep(int value)
        {
            foreach ((int minimum, string label) in RatingSteps)
            {
                if (minimum > value)
                    return "다음 단계 ‘" + label + "’까지 " + (minimum - value);
            }
            return "세대 최고 수준에 도달했습니다.";
        }
    }
}
