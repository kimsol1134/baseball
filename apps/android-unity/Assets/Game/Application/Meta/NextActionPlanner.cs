using System;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;

namespace Baseball.Application.Meta
{
    public sealed class NextActionReadModel
    {
        public NextActionReadModel(string route, string title, string action, bool resumesInterruption)
        {
            Route = route;
            Title = title;
            Action = action;
            ResumesInterruption = resumesInterruption;
        }

        public string Route { get; }
        public string Title { get; }
        public string Action { get; }
        public bool ResumesInterruption { get; }
    }

    public static class NextActionPlanner
    {
        public static NextActionReadModel Resolve(GameSaveAggregate state)
        {
            return Resolve(state, true);
        }

        /// <summary>
        /// Resolves durable career progress without exposing experiment-personalized return-plan
        /// copy. Pending committed pitch work remains highest priority for crash recovery.
        /// </summary>
        public static NextActionReadModel ResolveCoreProgress(GameSaveAggregate state)
        {
            return Resolve(state, false);
        }

        public static NextActionReadModel Resolve(
            GameSaveAggregate state,
            bool includeReturnPlan)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            if (state.PendingPitchCompletion != null)
            {
                return new NextActionReadModel(
                    "pitch/result",
                    "경기 결과 확인",
                    "저장된 경기 결과를 확인합니다.",
                    true);
            }
            if (state.PitchResume != null)
            {
                return new NextActionReadModel(
                    "pitch/resume",
                    "등판 이어하기",
                    "마지막 타자 경계부터 이어 던집니다.",
                    true);
            }
            if (includeReturnPlan &&
                state.Meta.ReturnPlan != null &&
                !state.Meta.ReturnPlan.Dismissed)
            {
                return new NextActionReadModel(
                    state.Meta.ReturnPlan.Route,
                    state.Meta.ReturnPlan.Title,
                    state.Meta.ReturnPlan.NextAction,
                    false);
            }
            if (state.HighSchool?.Phase == HighSchoolPhase.Prologue)
            {
                return new NextActionReadModel(
                    "high-school/tutorial",
                    "첫 불펜",
                    "기록에 남지 않는 연습 승부를 마칩니다.",
                    false);
            }
            if (state.HighSchool?.Phase == HighSchoolPhase.SchoolSelection)
            {
                return new NextActionReadModel(
                    "high-school/school-selection",
                    "진학 제안",
                    "네 학교 후보를 살펴보고 진학할 곳을 고릅니다.",
                    false);
            }
            switch (state.Stage)
            {
                case ApplicationStage.Opening:
                    return new NextActionReadModel("opening", "새 이야기", "시작 방식을 고릅니다.", false);
                case ApplicationStage.Setup:
                case ApplicationStage.BetweenLives:
                    return new NextActionReadModel("setup", "선수 만들기", "다음 선수를 준비합니다.", false);
                case ApplicationStage.HighSchool:
                case ApplicationStage.Draft:
                    return new NextActionReadModel("high-school", "고교 커리어", "다음 일정을 진행합니다.", false);
                case ApplicationStage.Pro:
                    return new NextActionReadModel("pro", "프로 커리어", "다음 주 일정을 진행합니다.", false);
                case ApplicationStage.Retirement:
                    return new NextActionReadModel("retirement", "은퇴 정산", "프로 기록을 유산으로 남깁니다.", false);
                case ApplicationStage.Legacy:
                    return new NextActionReadModel("legacy", "유산 선택", "이번 삶을 마치고 다음 삶을 준비합니다.", false);
                case ApplicationStage.Deleted:
                    return new NextActionReadModel("opening", "저장 초기화 필요", "새 게임을 시작하려면 초기화합니다.", false);
                default:
                    throw new ArgumentOutOfRangeException();
            }
        }
    }
}
