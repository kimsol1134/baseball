using System;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    public readonly struct NormalizedPitchAim
    {
        public NormalizedPitchAim(double x, double y)
        {
            X = Math.Max(-1.0, Math.Min(1.0, x));
            Y = Math.Max(-1.0, Math.Min(1.0, y));
        }

        public double X { get; }
        public double Y { get; }
    }

    public static class PitchInputMapper
    {
        private const double CellCenterOffset = 2.0 / 3.0;
        private const double CellHalfWidth = 1.0 / 3.0;

        public static PitchZone ZoneFor(NormalizedPitchAim aim)
        {
            int column = aim.X < -CellHalfWidth ? 0 : aim.X > CellHalfWidth ? 2 : 1;
            int row = aim.Y > CellHalfWidth ? 0 : aim.Y < -CellHalfWidth ? 2 : 1;
            return new PitchZone(row, column);
        }

        public static NormalizedPitchAim CenterOf(PitchZone zone)
        {
            Validate(zone);
            return new NormalizedPitchAim(
                (zone.Column - 1) * CellCenterOffset,
                (1 - zone.Row) * CellCenterOffset);
        }

        public static int AimAccuracy(NormalizedPitchAim aim)
        {
            PitchZone zone = ZoneFor(aim);
            NormalizedPitchAim center = CenterOf(zone);
            double distance = Math.Max(Math.Abs(aim.X - center.X), Math.Abs(aim.Y - center.Y));
            int penalty = (int)Math.Round(Math.Min(1.0, distance / CellHalfWidth) * 400.0, MidpointRounding.AwayFromZero);
            return Math.Max(600, 1000 - penalty);
        }

        private static void Validate(PitchZone zone)
        {
            if (zone.Row < 0 || zone.Row > 2 || zone.Column < 0 || zone.Column > 2)
            {
                throw new ArgumentOutOfRangeException(nameof(zone), "Pitch zone must be inside the 3x3 grid.");
            }
        }
    }

    public sealed class PitchReleaseMeter
    {
        public const double SweepSeconds = 1.20;
        public const double PerfectPhase = 0.62;
        private double _elapsedSeconds;

        public double Phase
        {
            get
            {
                double sweep = _elapsedSeconds / SweepSeconds;
                long whole = (long)Math.Floor(sweep);
                double fraction = sweep - whole;
                return (whole & 1L) == 0L ? fraction : 1.0 - fraction;
            }
        }

        public int Accuracy => AccuracyAt(Phase);

        public void Reset()
        {
            _elapsedSeconds = 0.0;
        }

        public void Advance(double deltaSeconds)
        {
            if (double.IsNaN(deltaSeconds) || double.IsInfinity(deltaSeconds))
            {
                throw new ArgumentOutOfRangeException(nameof(deltaSeconds));
            }
            _elapsedSeconds += Math.Max(0.0, deltaSeconds);
        }

        public static int AccuracyAt(double phase)
        {
            double clamped = Math.Max(0.0, Math.Min(1.0, phase));
            int penalty = (int)Math.Round(Math.Abs(clamped - PerfectPhase) * 1600.0, MidpointRounding.AwayFromZero);
            return Math.Max(0, 1000 - penalty);
        }
    }
}
