using System;
using System.Collections.Generic;
using Baseball.Core.Domain;

namespace Baseball.Core.Pitching
{
    internal enum SignCount { First, Ahead, Behind, MustThrowStrike, Even }

    internal sealed class SignSituation
    {
        public SignSituation(PlateAppearanceContext context, GameStateSnapshot gameState, PitchAnalysisEntry lastPitch)
        {
            if (context.Balls == 0 && context.Strikes == 0) Count = SignCount.First;
            else if (context.Balls == 3 && context.Strikes == 0) Count = SignCount.MustThrowStrike;
            else if ((context.Balls == 0 || context.Balls == 1) && context.Strikes == 2) Count = SignCount.Ahead;
            else if ((context.Balls == 2 && context.Strikes == 0) || (context.Balls == 3 && context.Strikes == 1)) Count = SignCount.Behind;
            else Count = SignCount.Even;
            var runners = gameState == null ? BaserunnerStateSnapshot.Empty : gameState.Runners;
            DoublePlayChance = context.Outs < 2 && runners.FirstOccupied;
            SacrificeFlyRisk = context.Outs < 2 && runners.ThirdOccupied;
            AvoidsRepeat = lastPitch != null &&
                (lastPitch.Outcome == PitchOutcome.Single || lastPitch.Outcome == PitchOutcome.Double ||
                 lastPitch.Outcome == PitchOutcome.Triple || lastPitch.Outcome == PitchOutcome.HomeRun ||
                 (lastPitch.Outcome == PitchOutcome.Foul && context.Strikes == 2));
        }

        public SignCount Count { get; }
        public bool DoublePlayChance { get; }
        public bool SacrificeFlyRisk { get; }
        public bool AvoidsRepeat { get; }

        public PitchZone Shift(PitchZone zone)
        {
            var row = zone.Row; var column = zone.Column;
            if (Count == SignCount.MustThrowStrike) { row = 1; column = 1; }
            else if (Count == SignCount.Behind) { row = PullInward(row); column = PullInward(column); }
            else if (Count == SignCount.Ahead) row = Math.Min(2, row + 1);
            if ((DoublePlayChance || SacrificeFlyRisk) && Count != SignCount.MustThrowStrike) row = Math.Max(row, 1);
            return new PitchZone(row, column);
        }

        public ZoneIntent ZoneIntent(bool protectZone, bool twoStrikes)
        {
            if (protectZone || Count == SignCount.MustThrowStrike || Count == SignCount.Behind) return Pitching.ZoneIntent.Strike;
            if (Count == SignCount.Ahead) return Pitching.ZoneIntent.Chase;
            if (Count == SignCount.First) return Pitching.ZoneIntent.Edge;
            return twoStrikes ? Pitching.ZoneIntent.Chase : Pitching.ZoneIntent.Edge;
        }

        public bool DemandsControl => Count == SignCount.MustThrowStrike || Count == SignCount.Behind || DoublePlayChance;
        public string CountCode => Count == SignCount.First ? "count.first_pitch" : Count == SignCount.Ahead ? "count.pitcher_ahead" :
            Count == SignCount.Behind ? "count.pitcher_behind" : Count == SignCount.MustThrowStrike ? "count.avoid_walk" : "count.standard";
        public IReadOnlyList<string> ExtraReasonCodes
        {
            get
            {
                var codes = new List<string>(2);
                if (DoublePlayChance) codes.Add("runners.double_play_setup");
                if (SacrificeFlyRisk) codes.Add("runners.suppress_sacrifice_fly");
                return codes;
            }
        }
        private static int PullInward(int value) => value == 0 || value == 2 ? 1 : value;
    }
}
