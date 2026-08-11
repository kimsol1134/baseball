using System;
using System.Globalization;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Core.Random;

namespace Baseball.Core.Pro
{
    /// <summary>Inputs for the legacy one-pitch facade. Resolution remains authoritative in PitchKernelEngine.</summary>
    public sealed class SimulatePitchParams
    {
        public SimulatePitchParams(string seed, PitcherSnapshot pitcher, BatterSnapshot batter, CountState count, int fatigue, PitchSelection selection)
        { Seed = seed; Pitcher = pitcher; Batter = batter; Count = count; Fatigue = fatigue; Selection = selection; }
        public string Seed { get; }
        public PitcherSnapshot Pitcher { get; }
        public BatterSnapshot Batter { get; }
        public CountState Count { get; }
        public int Fatigue { get; }
        public PitchSelection Selection { get; }
    }

    public sealed class SimulationEngine
    {
        public PitchKernelResult SimulatePitch(SimulatePitchParams parameters)
        {
            if (parameters == null) throw new ArgumentNullException(nameof(parameters));
            var context = new PlateAppearanceContext("simulation-preview", 0, 1, 0,
                parameters.Count.Balls, parameters.Count.Strikes, 1, 0, 500, parameters.Fatigue);
            var scouting = new BatterScoutingSnapshot(new PitchZone(0, 2), new PitchZone(2, 0),
                PitchType.FourSeam, PitchType.Changeup, 50);
            var kernel = new PitchKernelEngine();
            var preparation = kernel.PreparePitch(new PreparePitchParams(
                parameters.Seed, parameters.Pitcher, parameters.Batter, scouting, context));
            var zone = parameters.Selection.Zone;
            var intent = zone.Row == 1 && zone.Column == 1 ? ZoneIntent.Strike : ZoneIntent.Edge;
            var call = new PitchCall(parameters.Selection.PitchType, zone, intent, parameters.Selection.Intensity);
            return kernel.SubmitPitch(new SubmitPitchParams(parameters.Seed, parameters.Pitcher, parameters.Batter,
                scouting, context, preparation.PreparationToken, call));
        }
    }

    /// <summary>Advances a play-session seed without mutating the signed career snapshot.</summary>
    public static class ProSeedReservation
    {
        public static string Advance(string value)
        {
            ulong seed;
            if (!ulong.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out seed))
                seed = 0x9E3779B97F4A7C15UL;
            var generator = new SplitMix64(seed);
            return Math.Max(1UL, generator.Next() >> 1).ToString(CultureInfo.InvariantCulture);
        }
    }
}
