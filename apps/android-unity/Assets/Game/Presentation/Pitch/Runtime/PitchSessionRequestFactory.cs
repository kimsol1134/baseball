using System;
using Baseball.Application.Persistence;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    public static class PitchSessionRequestFactory
    {
        public static PitchPlayRequest Initial(
            string gameId,
            string sessionSeed,
            PitchScenarioReadModel scenario,
            int batterIndex)
        {
            if (string.IsNullOrWhiteSpace(gameId)) throw new ArgumentException("A game ID is required.", nameof(gameId));
            if (scenario == null) throw new ArgumentNullException(nameof(scenario));
            if (batterIndex < 0 || batterIndex >= scenario.MaximumBatters || batterIndex >= scenario.Lineup.Count)
                throw new InvalidOperationException("pitch.batter_index_invalid");
            if (batterIndex != 0)
                throw new InvalidOperationException("pitch.checkpoint_required_after_first_batter");

            InningStateSnapshot inning = scenario.GameState?.InningState ??
                new InningStateSnapshot(1, HalfInning.Top, 0);
            var context = new PlateAppearanceContext(
                PlateAppearanceId(gameId, batterIndex),
                0,
                inning.Inning,
                inning.Outs,
                0,
                0,
                1,
                scenario.ScoreDifferential,
                scenario.Leverage,
                scenario.Fatigue);
            return new PitchPlayRequest(
                sessionSeed,
                scenario.Pitcher,
                scenario.Lineup[batterIndex],
                scenario.Scouting,
                context,
                gameState: scenario.GameState,
                gameLog: new GameLogSnapshot(gameId, 0, 0, Array.Empty<PitchAnalysisEntry>()));
        }

        public static PitchPlayRequest NextBatter(
            string gameId,
            PitchScenarioReadModel scenario,
            int batterIndex,
            PitchKernelResult previous)
        {
            if (scenario == null) throw new ArgumentNullException(nameof(scenario));
            if (previous?.Snapshot == null || !previous.Snapshot.Ended)
                throw new InvalidOperationException("pitch.previous_batter_active");
            if (batterIndex < 0 || batterIndex >= scenario.MaximumBatters || batterIndex >= scenario.Lineup.Count)
                throw new InvalidOperationException("pitch.batter_index_invalid");
            InningStateSnapshot inning = previous.GameState?.InningState ??
                new InningStateSnapshot(previous.Snapshot.InningTransition?.After.Inning ?? 1, HalfInning.Top, 0);
            var context = new PlateAppearanceContext(
                PlateAppearanceId(gameId, batterIndex),
                previous.Revision,
                inning.Inning,
                inning.Outs,
                0,
                0,
                1,
                scenario.ScoreDifferential - Math.Max(0, previous.GameState?.RunsAllowed ?? 0),
                scenario.Leverage,
                previous.Snapshot.FatigueAfterPitch);
            return new PitchPlayRequest(
                previous.NextSeed,
                scenario.Pitcher,
                scenario.Lineup[batterIndex],
                scenario.Scouting,
                context,
                gameState: previous.GameState ?? scenario.GameState,
                gameLog: previous.GameLog);
        }

        public static bool SessionEnded(
            PitchScenarioReadModel scenario,
            int completedBatters,
            PitchKernelResult result)
        {
            if (scenario == null) throw new ArgumentNullException(nameof(scenario));
            if (result?.Snapshot == null) throw new ArgumentNullException(nameof(result));
            if (completedBatters >= scenario.MaximumBatters) return true;
            if (result.Snapshot.InningTransition?.InningEnded == true) return true;
            return scenario.MaximumPitches.HasValue &&
                (result.GameLog?.TotalPitches ?? result.Snapshot.PitchNumber) >= scenario.MaximumPitches.Value;
        }

        private static string PlateAppearanceId(string gameId, int batterIndex) =>
            gameId + ":batter:" + batterIndex;
    }
}
