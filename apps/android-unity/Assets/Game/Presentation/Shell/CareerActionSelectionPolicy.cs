using Baseball.Application.HighSchool;
using Baseball.Application.Pro;

namespace Baseball.Presentation.Shell
{
    /// <summary>
    /// Pure UI draft contract for the conditional pitch targets used by career commands.
    /// The Application layer still validates the enabled catalog choices authoritatively.
    /// </summary>
    public static class CareerActionSelectionPolicy
    {
        public static string TrainingPayload(
            string focusId,
            string intensityId,
            string targetPitchId,
            bool hasTargetPitchChoices)
        {
            if (string.IsNullOrWhiteSpace(focusId) || string.IsNullOrWhiteSpace(intensityId))
                return null;
            bool requiresTarget = focusId == "breaking_ball" && hasTargetPitchChoices;
            if (requiresTarget && string.IsNullOrWhiteSpace(targetPitchId)) return null;
            return HighSchoolTrainingActionPayload.Encode(
                focusId,
                intensityId,
                focusId == "breaking_ball" ? targetPitchId : null);
        }

        public static string ProWeekPayload(
            string planId,
            string targetPitchId,
            bool hasTargetPitchChoices)
        {
            if (string.IsNullOrWhiteSpace(planId)) return null;
            bool requiresTarget = planId == "develop_movement" && hasTargetPitchChoices;
            if (requiresTarget && string.IsNullOrWhiteSpace(targetPitchId)) return null;
            return ProWeekActionPayload.Encode(
                planId,
                planId == "develop_movement" ? targetPitchId : null);
        }
    }
}
