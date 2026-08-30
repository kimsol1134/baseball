using System;
using Baseball.Core.Domain;

namespace Baseball.Core.Pitching
{
    public enum PitchAbilityKind { Power, Command, Movement }

    public static class PitchAbilityWire
    {
        public static string Value(this PitchAbilityKind value)
        {
            switch (value)
            {
                case PitchAbilityKind.Power: return "power";
                case PitchAbilityKind.Command: return "command";
                case PitchAbilityKind.Movement: return "movement";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static bool IsValid(string value)
        {
            return string.Equals(value, "power", StringComparison.Ordinal) ||
                string.Equals(value, "command", StringComparison.Ordinal) ||
                string.Equals(value, "movement", StringComparison.Ordinal);
        }
    }

    public sealed class PitchAbilityReadout
    {
        public PitchAbilityReadout(PitchType pitchType, int stuffRating, int commandRating,
            int movementRating, int staminaRating, int whiffRating, int weakContactRating,
            int nominalVelocityTenthsKph, int fatigueCost)
        {
            PitchType = pitchType; StuffRating = stuffRating; CommandRating = commandRating;
            MovementRating = movementRating; StaminaRating = staminaRating; WhiffRating = whiffRating;
            WeakContactRating = weakContactRating; NominalVelocityTenthsKph = nominalVelocityTenthsKph;
            FatigueCost = fatigueCost;
        }
        public PitchType PitchType { get; }
        public int StuffRating { get; }
        public int CommandRating { get; }
        public int MovementRating { get; }
        public int StaminaRating { get; }
        public int WhiffRating { get; }
        public int WeakContactRating { get; }
        public int NominalVelocityTenthsKph { get; }
        public int FatigueCost { get; }
    }

    internal struct IntensityEffect
    {
        public IntensityEffect(int commandPenalty, int velocityBonusTenthsKph)
        { CommandPenalty = commandPenalty; VelocityBonusTenthsKph = velocityBonusTenthsKph; }
        public int CommandPenalty { get; }
        public int VelocityBonusTenthsKph { get; }
    }

    public static class PitchAbilityRules
    {
        public const int MaximumProfileVelocityTenthsKph = 1600;
        public const int MaximumExecutedVelocityTenthsKph = 1650;

        public static int MaximumProfileVelocity(PitchType type)
        {
            switch (type)
            {
                case PitchType.FourSeam: return 1600;
                case PitchType.Slider: return 1500;
                case PitchType.Curveball: return 1370;
                case PitchType.Changeup: return 1480;
                default: throw new ArgumentOutOfRangeException(nameof(type));
            }
        }

        public static PitchAbilityReadout Readout(PitcherSnapshot pitcher, PitchCall call, PlateAppearanceContext context)
        {
            var profile = pitcher.Profile(call.PitchType);
            var fatigue = pitcher.EffectiveMastery.Stamina > 0
                ? EffectiveFatigue(context.Fatigue, pitcher.Stamina, pitcher.EffectiveMastery.Stamina)
                : context.Fatigue;
            var movement = MasteryEffectRules.AdjustedRating(
                profile == null ? pitcher.Movement : profile.Movement,
                pitcher.EffectiveMastery.Movement);
            return new PitchAbilityReadout(call.PitchType, pitcher.Stuff, CommandRating(pitcher, profile),
                movement, pitcher.Stamina,
                profile == null ? pitcher.Stuff : profile.Whiff, profile == null ? 50 : profile.WeakContact,
                NominalVelocity(pitcher, call.PitchType, call.Intensity, fatigue),
                FatigueCost(call.Intensity, profile));
        }

        public static PitchAbilityKind? Moment(PitchOutcome outcome, PitchExecution execution, PitchAbilityReadout readout)
        {
            if (outcome != PitchOutcome.CalledStrike && outcome != PitchOutcome.SwingingStrike && outcome != PitchOutcome.InPlayOut)
                return null;
            if (outcome == PitchOutcome.CalledStrike && readout.CommandRating >= 55 && execution.ExecutionQuality >= 650)
                return PitchAbilityKind.Command;
            if (outcome == PitchOutcome.SwingingStrike)
            {
                if (readout.PitchType != PitchType.FourSeam && Math.Max(readout.MovementRating, readout.WhiffRating) >= 55)
                    return PitchAbilityKind.Movement;
                if (Math.Max(readout.StuffRating, readout.WhiffRating) >= 55) return PitchAbilityKind.Power;
            }
            if (outcome == PitchOutcome.InPlayOut && Math.Max(readout.MovementRating, readout.WeakContactRating) >= 55)
                return PitchAbilityKind.Movement;
            return null;
        }

        internal static IntensityEffect Intensity(PitchIntensity intensity)
        {
            switch (intensity)
            {
                case PitchIntensity.Controlled: return new IntensityEffect(-18, -105);
                case PitchIntensity.Normal: return new IntensityEffect(0, 0);
                case PitchIntensity.MaxEffort: return new IntensityEffect(34, 130);
                default: throw new ArgumentOutOfRangeException(nameof(intensity));
            }
        }

        internal static int CommandRating(PitcherSnapshot pitcher, PitchProfileSnapshot profile)
        {
            var command = MasteryEffectRules.AdjustedRating(pitcher.Command, pitcher.EffectiveMastery.Command);
            return profile == null ? command : (command * 4 + profile.Control * 4 + profile.Command * 2) / 10;
        }

        internal static int NominalVelocity(PitcherSnapshot pitcher, PitchType type, PitchIntensity intensity, int fatigue)
        {
            var profile = pitcher.Profile(type);
            var baseVelocity = profile == null ? BaseVelocity(type) + (pitcher.Stuff - 50) * 4 : profile.VelocityTenthsKph;
            var masteryVelocity = MasteryEffectRules.BonusForContribution(
                Math.Max(0, pitcher.Stuff - 20), pitcher.EffectiveMastery.Stuff) / 8;
            var rawVelocity = baseVelocity + masteryVelocity + Intensity(intensity).VelocityBonusTenthsKph - fatigue;
            var profileCeiling = MaximumProfileVelocity(type);
            var ceiling = intensity == PitchIntensity.Controlled ? profileCeiling - 20
                : intensity == PitchIntensity.Normal ? profileCeiling
                : profileCeiling + (type == PitchType.FourSeam ? 40 : 30);
            return Math.Min(rawVelocity, ceiling);
        }

        public static int FatigueCost(PitchIntensity intensity, PitchProfileSnapshot profile)
        {
            if (profile != null)
            {
                var modifier = intensity == PitchIntensity.Controlled ? -1 : intensity == PitchIntensity.MaxEffort ? 1 : 0;
                return Math.Max(0, profile.FatigueCost + modifier);
            }
            return intensity == PitchIntensity.Controlled ? 0 : intensity == PitchIntensity.Normal ? 1 : 2;
        }

        public static int ReducedFatigueCost(int current, int reduction) => current <= 0 ? 0 : Math.Max(1, current - Math.Max(0, reduction));

        public static int EffectiveFatigue(int rawFatigue, int stamina, int mastery = 0)
        {
            var raw = Math.Min(100, Math.Max(0, rawFatigue));
            var effectiveStamina = Math.Min(100, Math.Max(20,
                20 + MasteryEffectRules.AdjustedContribution(Math.Min(60, Math.Max(0, stamina - 20)), mastery)));
            var multiplier = 1250 - (effectiveStamina - 20) * 500 / 60;
            return Math.Min(100, Math.Max(0, raw * multiplier / 1000));
        }

        private static int BaseVelocity(PitchType type)
        {
            switch (type)
            {
                case PitchType.FourSeam: return 1420;
                case PitchType.Slider: return 1275;
                case PitchType.Curveball: return 1165;
                case PitchType.Changeup: return 1285;
                default: throw new ArgumentOutOfRangeException(nameof(type));
            }
        }
    }
}
