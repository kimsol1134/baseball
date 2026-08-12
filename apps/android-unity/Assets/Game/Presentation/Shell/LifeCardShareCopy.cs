using System;
using Baseball.Application.Meta;

namespace Baseball.Presentation.Shell
{
    public static class LifeCardShareCopy
    {
        public static string Build(LifeArchiveRecord life)
        {
            if (life == null) return "야구 못하면 또 환생함 · 아직 완성한 야구 인생이 없습니다.";
            string copy = Build(
                life.LifeNumber,
                life.PlayerName,
                life.HighSchoolPerformance?.Strikeouts,
                life.ProStrikeouts,
                life.SoulEarned);
            string draft = life.Drafted
                ? (string.IsNullOrWhiteSpace(life.DraftTeamName)
                    ? "지명 구단 기록 없음"
                    : life.DraftTeamName + " 지명")
                : "드래프트 미지명";
            copy += "\n" + draft + " · 스카우트 평가 " + life.DraftEvaluation + "점";
            string challengeCode = ChallengeCode(life);
            if (!string.IsNullOrWhiteSpace(challengeCode))
                copy += "\n같은 판에 도전: " + challengeCode;
            return copy;
        }

        public static string ChallengeCode(LifeArchiveRecord life)
        {
            if (life == null || string.IsNullOrWhiteSpace(life.HighSchoolCareerId)) return null;
            const string prefix = "career-";
            const string lifeMarker = "-life-";
            if (!life.HighSchoolCareerId.StartsWith(prefix, StringComparison.Ordinal)) return null;
            int marker = life.HighSchoolCareerId.LastIndexOf(lifeMarker, StringComparison.Ordinal);
            if (marker <= prefix.Length) return null;
            string seed = life.HighSchoolCareerId.Substring(prefix.Length, marker - prefix.Length);
            return string.IsNullOrWhiteSpace(seed) ? null : seed + "-" + life.LifeNumber;
        }

        public static string Build(
            int lifeNumber,
            string playerName,
            int? highSchoolStrikeouts,
            int proStrikeouts,
            int soulEarned)
        {
            string safeName = string.IsNullOrWhiteSpace(playerName)
                ? "이름이 남지 않은 선수"
                : playerName;
            return "야구 못하면 또 환생함\n" + lifeNumber + "번째 인생 · " + safeName +
                "\n고교 탈삼진 " + (highSchoolStrikeouts ?? 0) + " · 프로 탈삼진 " + proStrikeouts +
                "\n야구혼 +" + soulEarned;
        }
    }
}
