using Baseball.Application.Persistence;

namespace Baseball.Application.HighSchool
{
    /// <summary>
    /// Narrow boundary for the evolving Core high-school engine. Application tests use a fake;
    /// the production adapter can bind once the Core command surface is frozen.
    /// </summary>
    public interface IHighSchoolCareerPort
    {
        HighSchoolCareerReadModel Start(StartHighSchoolCareerRequest request);

        HighSchoolCareerReadModel Apply(
            HighSchoolCareerReadModel current,
            HighSchoolAction action);

        /// <summary>Consumes and advances the deterministic game seed before play is exposed.</summary>
        HighSchoolCareerReadModel ReservePitch(
            HighSchoolCareerReadModel current,
            string scenarioId);

        HighSchoolCareerReadModel ApplyPitchResult(
            HighSchoolCareerReadModel current,
            PitchGameReport report);
    }


    public interface IHighSchoolPitchScenarioPort
    {
        PitchScenarioReadModel CreatePitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId);
    }


    public interface IHighSchoolTutorialScenarioPort
    {
        PitchScenarioReadModel CreateTutorialPitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId);
    }
}
