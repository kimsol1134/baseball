using Baseball.Application.Meta;

namespace Baseball.Presentation.Shell
{
    public static class LifeCardShareCopy
    {
        public static string Build(LifeArchiveRecord life)
        {
            if (life == null) return "야구 못하면 또 환생함 · 아직 완성한 야구 인생이 없습니다.";
            return Build(
                life.LifeNumber,
                life.PlayerName,
                life.HighSchoolPerformance?.Strikeouts,
                life.ProStrikeouts,
                life.SoulEarned);
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
