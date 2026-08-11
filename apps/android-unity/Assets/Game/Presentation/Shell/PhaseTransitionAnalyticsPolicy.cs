using System;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    /// <summary>
    /// `phase_entered` is a durable transition event, not a screen/store-publish impression.
    /// Initial career creation is onboarding and is intentionally excluded.
    /// </summary>
    public static class PhaseTransitionAnalyticsPolicy
    {
        public static bool IsEntered(GameSaveAggregate before, GameSaveAggregate after)
        {
            HighSchoolCareerReadModel previous = before?.HighSchool;
            HighSchoolCareerReadModel current = after?.HighSchool;
            return previous != null && current != null && !current.IsChallengeRun &&
                string.Equals(previous.CareerId, current.CareerId, StringComparison.Ordinal) &&
                (previous.Phase != current.Phase ||
                 previous.ChapterNumber != current.ChapterNumber);
        }
    }
}
