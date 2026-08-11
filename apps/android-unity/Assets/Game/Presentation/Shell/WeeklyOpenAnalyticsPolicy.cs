using Baseball.Application.Meta;

namespace Baseball.Presentation.Shell
{
    public static class WeeklyOpenAnalyticsPolicy
    {
        public static bool CanEmit(WeeklyProgramState program, bool observeInFlight) =>
            !observeInFlight && program != null && !string.IsNullOrWhiteSpace(program.WeekKey);
    }
}
