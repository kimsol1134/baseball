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

    public sealed class AbilityMasterySnapshot : IEquatable<AbilityMasterySnapshot>
    {
        public const int TechnicalMaximum = int.MaxValue;

        public AbilityMasterySnapshot(int stuff = 0, int command = 0, int movement = 0, int stamina = 0)
        {
            Stuff = Saturate(stuff); Command = Saturate(command); Movement = Saturate(movement); Stamina = Saturate(stamina);
        }

        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }

        public int Value(TalentAbility ability)
        {
            switch (ability)
            {
                case TalentAbility.Stuff: return Stuff;
                case TalentAbility.Command: return Command;
                case TalentAbility.Movement: return Movement;
                default: return Stamina;
            }
        }

        public AbilityMasterySnapshot With(TalentAbility ability, int value)
        {
            switch (ability)
            {
                case TalentAbility.Stuff: return new AbilityMasterySnapshot(value, Command, Movement, Stamina);
                case TalentAbility.Command: return new AbilityMasterySnapshot(Stuff, value, Movement, Stamina);
                case TalentAbility.Movement: return new AbilityMasterySnapshot(Stuff, Command, value, Stamina);
                default: return new AbilityMasterySnapshot(Stuff, Command, Movement, value);
            }
        }

        public AbilityMasterySnapshot Add(TalentAbility ability, int points)
        {
            if (points <= 0) return this;
            long next = Math.Min((long)TechnicalMaximum, (long)Value(ability) + points);
            return With(ability, (int)next);
        }

        public bool Equals(AbilityMasterySnapshot other)
        {
            return other != null && Stuff == other.Stuff && Command == other.Command &&
                Movement == other.Movement && Stamina == other.Stamina;
        }

        public override bool Equals(object obj) { return Equals(obj as AbilityMasterySnapshot); }
        public override int GetHashCode() { return (((Stuff * 31) + Command) * 31 + Movement) * 31 + Stamina; }

        private static int Saturate(int value) { return Math.Min(TechnicalMaximum, Math.Max(0, value)); }
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
            ThrowingHand throwingHand = ThrowingHand.Right,
            AbilityMasterySnapshot mastery = null)
        {
            Id = id;
            Name = name;
            Stuff = stuff;
            Command = command;
            Movement = movement;
            Stamina = stamina;
            PitchProfiles = pitchProfiles;
            ThrowingHand = throwingHand;
            Mastery = mastery;
        }

        public string Id { get; }
        public string Name { get; }
        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }
        public IReadOnlyList<PitchProfileSnapshot> PitchProfiles { get; }
        public ThrowingHand ThrowingHand { get; }
        public AbilityMasterySnapshot Mastery { get; }
        public AbilityMasterySnapshot EffectiveMastery { get { return Mastery ?? new AbilityMasterySnapshot(); } }

        public PitchProfileSnapshot Profile(PitchType pitchType)
        {
            return PitchProfiles == null ? null : PitchProfiles.FirstOrDefault(profile => profile.PitchType == pitchType);
        }

        public bool HasGameReadyProfile(PitchType pitchType)
        {
            return PitchProfiles == null || Profile(pitchType) != null;
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
