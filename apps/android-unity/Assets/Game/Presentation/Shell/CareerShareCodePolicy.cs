using System;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;

namespace Baseball.Presentation.Shell
{
    public sealed class CareerShareCode
    {
        public CareerShareCode(string code, string mode, int? lifeNumber, bool challenge)
        {
            Code = code ?? string.Empty;
            Mode = mode ?? string.Empty;
            LifeNumber = lifeNumber;
            Challenge = challenge;
        }

        public string Code { get; }
        public string Mode { get; }
        public int? LifeNumber { get; }
        public bool Challenge { get; }
    }

    public static class CareerShareCodePolicy
    {
        public static CareerShareCode Project(GameSaveAggregate state)
        {
            if (state == null) return null;
            if (state.Pro != null)
            {
                if (state.Pro.Origin == ProCareerOrigin.HighSchool &&
                    !string.IsNullOrWhiteSpace(state.Pro.SourceHighSchoolCareerId))
                {
                    int life = state.HighSchool?.LifeNumber ?? state.Meta.LifeNumber;
                    string linked = ChallengeCode(state.Pro.SourceHighSchoolCareerId, life);
                    if (!string.IsNullOrWhiteSpace(linked))
                        return new CareerShareCode(linked, "고교에서 이어진 프로", life, false);
                }
                if (!string.IsNullOrWhiteSpace(state.Pro.ProCareerId))
                    return new CareerShareCode(state.Pro.ProCareerId, "바로 시작한 프로", null, false);
            }
            if (state.HighSchool != null)
            {
                string code = ChallengeCode(state.HighSchool.CareerId, state.HighSchool.LifeNumber);
                return string.IsNullOrWhiteSpace(code)
                    ? null
                    : new CareerShareCode(
                        code,
                        state.HighSchool.IsChallengeRun ? "도전 중인 고교" : "고교",
                        state.HighSchool.LifeNumber,
                        state.HighSchool.IsChallengeRun);
            }
            return null;
        }

        public static string ShareText(CareerShareCode value)
        {
            if (value == null || string.IsNullOrWhiteSpace(value.Code)) return string.Empty;
            string life = value.LifeNumber.HasValue
                ? "\n" + value.LifeNumber.Value + "번째 야구 인생"
                : string.Empty;
            return "야구 못하면 또 환생함\n" + value.Mode + life +
                "\n같은 판에 도전: " + value.Code;
        }

        private static string ChallengeCode(string careerId, int lifeNumber)
        {
            string prefix = "career-";
            string suffix = "-life-" + lifeNumber;
            if (string.IsNullOrWhiteSpace(careerId) ||
                !careerId.StartsWith(prefix, StringComparison.Ordinal) ||
                !careerId.EndsWith(suffix, StringComparison.Ordinal) ||
                careerId.Length <= prefix.Length + suffix.Length)
                return null;
            return careerId.Substring(
                prefix.Length,
                careerId.Length - prefix.Length - suffix.Length) + "-" + lifeNumber;
        }
    }
}
