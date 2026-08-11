using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    /// <summary>
    /// Keeps challenge runs from consuming lifetime/scoped receipts that belong to the normal
    /// career. The saved aggregate is the authority; UI route or copy is never used as a proxy.
    /// </summary>
    public static class CareerAnalyticsEligibility
    {
        public static bool CountsTowardHighSchoolProgress(
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            return before?.HighSchool?.IsChallengeRun != true &&
                after?.HighSchool?.IsChallengeRun != true;
        }

        public static bool CountsPitchEvent(
            PitchCareerKind? kind,
            GameSaveAggregate state)
        {
            return kind != PitchCareerKind.HighSchool && kind != PitchCareerKind.Tutorial ||
                state?.HighSchool?.IsChallengeRun != true;
        }

        public static bool IsFirstPitchCompletion(
            PitchCareerKind? kind,
            GameSaveAggregate state)
        {
            return kind == PitchCareerKind.Tutorial &&
                state?.HighSchool?.IsChallengeRun != true;
        }
    }
}
