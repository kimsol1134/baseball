using Baseball.Application.HighSchool;

namespace Baseball.Presentation.Shell
{
    internal sealed class PlayerHeartlineViewModel
    {
        public PlayerHeartlineViewModel(string branchId, string mood, string words)
        {
            BranchId = branchId;
            Mood = mood;
            Words = words;
        }

        public string BranchId { get; }
        public string Mood { get; }
        public string Words { get; }
    }

    internal static class PlayerHeartlinePresentationPolicy
    {
        public static PlayerHeartlineViewModel Project(
            ShellRoute route,
            HighSchoolCareerReadModel career)
        {
            if (career == null || career.Performance?.ImportantGames <= 0 || !Supports(route))
                return null;
            if (career.InjuryRecovery > 0)
                return new PlayerHeartlineViewModel(
                    "injury_recovery",
                    "다시 던질 몸을 만드는 중",
                    "서두르지 않을게요. 다음 공을 오래 던질 수 있게 오늘은 회복부터 지키겠습니다.");
            if (career.ArmRisk >= 55)
                return new PlayerHeartlineViewModel(
                    "arm_warning",
                    "팔이 보내는 경고",
                    "더 던질 수는 있지만, 오래 남으려면 지금 멈출 줄도 알아야 합니다.");
            if (career.Fatigue >= 80)
                return new PlayerHeartlineViewModel(
                    "fatigue_warning",
                    "숨을 고르는 순간",
                    "몸이 무거워도 마음은 앞서갑니다. 다음 선택은 회복까지 생각하겠습니다.");
            switch (career.Phase)
            {
                case HighSchoolPhase.ChapterReview:
                    return new PlayerHeartlineViewModel("chapter_review", "한 장을 넘기며", "지나온 기록이 다음 장의 기준이 됩니다.");
                case HighSchoolPhase.Awakening:
                    return new PlayerHeartlineViewModel("awakening", "새 감각 앞에서", "지금 익힌 감각을 내 공으로 만들겠습니다.");
                case HighSchoolPhase.Draft:
                    return new PlayerHeartlineViewModel("draft", "이름이 불리기 전", "결과가 어떻든 여기까지 던진 공은 사라지지 않습니다.");
                case HighSchoolPhase.Legacy:
                    return new PlayerHeartlineViewModel("legacy", "남길 것을 고르며", "다음 선수에게 가장 나다운 한 가지를 남기고 싶습니다.");
                case HighSchoolPhase.Completed:
                    return new PlayerHeartlineViewModel("completed", "마지막 기록 뒤", "내가 남긴 기록이 다음 마운드의 시작이 되면 좋겠습니다.");
                default:
                    return null;
            }
        }

        private static bool Supports(ShellRoute route) =>
            route == ShellRoute.HighSchoolOverview || route == ShellRoute.Training ||
            route == ShellRoute.Relationship || route == ShellRoute.ImportantGame ||
            route == ShellRoute.Awakening || route == ShellRoute.Draft ||
            route == ShellRoute.RunRecap;
    }
}
