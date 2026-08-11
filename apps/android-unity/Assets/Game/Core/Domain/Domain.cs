using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Core.Domain
{
    public enum PitchType { FourSeam, Slider, Curveball, Changeup }
    public enum PitchIntensity { Controlled, Normal, MaxEffort }
    public enum PitchUsageRole { Primary, Secondary, Development }
    public enum BatSide { Right, Left, Switch }
    public enum ThrowingHand { Right, Left }
    public enum PitchOutcome
    {
        Ball,
        CalledStrike,
        SwingingStrike,
        Foul,
        InPlayOut,
        Single,
        Double,
        Triple,
        HomeRun,
        HitByPitch
    }

    /// <summary>
    /// Stable values used by saves, fixture hashes, and cross-language contracts.
    /// Never use Enum.ToString() in a deterministic payload.
    /// </summary>
    public static class DomainWire
    {
        public static readonly PitchType[] PitchTypes =
        {
            PitchType.FourSeam, PitchType.Slider, PitchType.Curveball, PitchType.Changeup
        };

        public static string Value(this PitchType value)
        {
            switch (value)
            {
                case PitchType.FourSeam: return "four_seam";
                case PitchType.Slider: return "slider";
                case PitchType.Curveball: return "curveball";
                case PitchType.Changeup: return "changeup";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this PitchIntensity value)
        {
            switch (value)
            {
                case PitchIntensity.Controlled: return "controlled";
                case PitchIntensity.Normal: return "normal";
                case PitchIntensity.MaxEffort: return "max_effort";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this PitchUsageRole value)
        {
            switch (value)
            {
                case PitchUsageRole.Primary: return "primary";
                case PitchUsageRole.Secondary: return "secondary";
                case PitchUsageRole.Development: return "development";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this PitchOutcome value)
        {
            switch (value)
            {
                case PitchOutcome.Ball: return "ball";
                case PitchOutcome.CalledStrike: return "called_strike";
                case PitchOutcome.SwingingStrike: return "swinging_strike";
                case PitchOutcome.Foul: return "foul";
                case PitchOutcome.InPlayOut: return "in_play_out";
                case PitchOutcome.Single: return "single";
                case PitchOutcome.Double: return "double";
                case PitchOutcome.Triple: return "triple";
                case PitchOutcome.HomeRun: return "home_run";
                case PitchOutcome.HitByPitch: return "hit_by_pitch";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }
    }

    public sealed class PitchProfileSnapshot
    {
        public PitchProfileSnapshot(
            PitchType pitchType,
            PitchUsageRole role,
            int velocityTenthsKph,
            int control,
            int command,
            int movement,
            int whiff,
            int weakContact,
            int fatigueCost)
        {
            PitchType = pitchType;
            Role = role;
            VelocityTenthsKph = velocityTenthsKph;
            Control = control;
            Command = command;
            Movement = movement;
            Whiff = whiff;
            WeakContact = weakContact;
            FatigueCost = fatigueCost;
        }

        public PitchType PitchType { get; }
        public PitchUsageRole Role { get; }
        public int VelocityTenthsKph { get; }
        public int Control { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Whiff { get; }
        public int WeakContact { get; }
        public int FatigueCost { get; }
    }

    public struct PitchZone : IEquatable<PitchZone>
    {
        public PitchZone(int row, int column)
        {
            Row = row;
            Column = column;
        }

        public int Row { get; }
        public int Column { get; }

        public bool Equals(PitchZone other) => Row == other.Row && Column == other.Column;
        public override bool Equals(object obj) => obj is PitchZone other && Equals(other);
        public override int GetHashCode() => unchecked((Row * 397) ^ Column);
        public static bool operator ==(PitchZone left, PitchZone right) => left.Equals(right);
        public static bool operator !=(PitchZone left, PitchZone right) => !left.Equals(right);
    }

    public sealed class PitcherSnapshot
    {
        public PitcherSnapshot(
            string id,
            string name,
            int stuff,
            int command,
            int movement,
            int stamina,
            IReadOnlyList<PitchProfileSnapshot> pitchProfiles = null,
            ThrowingHand throwingHand = ThrowingHand.Right)
        {
            Id = id;
            Name = name;
            Stuff = stuff;
            Command = command;
            Movement = movement;
            Stamina = stamina;
            PitchProfiles = pitchProfiles;
            ThrowingHand = throwingHand;
        }

        public string Id { get; }
        public string Name { get; }
        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }
        public IReadOnlyList<PitchProfileSnapshot> PitchProfiles { get; }
        public ThrowingHand ThrowingHand { get; }

        public PitchProfileSnapshot Profile(PitchType pitchType)
        {
            return PitchProfiles == null ? null : PitchProfiles.FirstOrDefault(profile => profile.PitchType == pitchType);
        }
    }

    public sealed class BatterSnapshot
    {
        public BatterSnapshot(
            string id,
            string name,
            int contact,
            int discipline,
            int power,
            BatSide batSide = BatSide.Right)
        {
            Id = id;
            Name = name;
            Contact = contact;
            Discipline = discipline;
            Power = power;
            BatSide = batSide;
        }

        public string Id { get; }
        public string Name { get; }
        public int Contact { get; }
        public int Discipline { get; }
        public int Power { get; }
        public BatSide BatSide { get; }
    }

    public struct CountState
    {
        public CountState(int balls, int strikes)
        {
            Balls = balls;
            Strikes = strikes;
        }

        public int Balls { get; }
        public int Strikes { get; }
    }

    public sealed class PitchSelection
    {
        public PitchSelection(PitchType pitchType, PitchZone zone, PitchIntensity intensity)
        {
            PitchType = pitchType;
            Zone = zone;
            Intensity = intensity;
        }

        public PitchType PitchType { get; }
        public PitchZone Zone { get; }
        public PitchIntensity Intensity { get; }
    }
}
