using System;
using Baseball.Core.Random;

namespace Baseball.Core.Domain
{
    public enum TrainingFocus { Velocity, Command, BreakingBall, Stamina, Recovery, GamePlanning }
    public enum TalentGrade { D, C, B, A, S }
    public enum TalentAbility { Stuff, Command, Movement, Stamina }

    public static class TalentGradeRules
    {
        public static int Ceiling(this TalentGrade grade)
        {
            switch (grade)
            {
                case TalentGrade.D: return 52;
                case TalentGrade.C: return 58;
                case TalentGrade.B: return 65;
                case TalentGrade.A: return 72;
                case TalentGrade.S: return 80;
                default: throw new ArgumentOutOfRangeException(nameof(grade));
            }
        }

        public static int BloomThreshold(this TalentGrade grade)
        {
            switch (grade)
            {
                case TalentGrade.D: return 2;
                case TalentGrade.C: return 3;
                case TalentGrade.B: return 4;
                case TalentGrade.A: return 6;
                case TalentGrade.S: return int.MaxValue;
                default: throw new ArgumentOutOfRangeException(nameof(grade));
            }
        }

        public static TalentGrade? Next(this TalentGrade grade)
        {
            return grade == TalentGrade.S ? (TalentGrade?)null : grade + 1;
        }
    }

    public sealed class TalentSnapshot
    {
        public TalentSnapshot(
            TalentGrade stuff,
            TalentGrade command,
            TalentGrade movement,
            TalentGrade stamina,
            int stuffPressure = 0,
            int commandPressure = 0,
            int movementPressure = 0,
            int staminaPressure = 0)
        {
            Stuff = stuff;
            Command = command;
            Movement = movement;
            Stamina = stamina;
            StuffPressure = stuffPressure;
            CommandPressure = commandPressure;
            MovementPressure = movementPressure;
            StaminaPressure = staminaPressure;
        }

        public TalentGrade Stuff { get; }
        public TalentGrade Command { get; }
        public TalentGrade Movement { get; }
        public TalentGrade Stamina { get; }
        public int StuffPressure { get; }
        public int CommandPressure { get; }
        public int MovementPressure { get; }
        public int StaminaPressure { get; }

        public static TalentSnapshot Unlimited => new TalentSnapshot(
            TalentGrade.S, TalentGrade.S, TalentGrade.S, TalentGrade.S);

        public TalentGrade Grade(TalentAbility ability)
        {
            switch (ability)
            {
                case TalentAbility.Stuff: return Stuff;
                case TalentAbility.Command: return Command;
                case TalentAbility.Movement: return Movement;
                case TalentAbility.Stamina: return Stamina;
                default: throw new ArgumentOutOfRangeException(nameof(ability));
            }
        }

        public int Pressure(TalentAbility ability)
        {
            switch (ability)
            {
                case TalentAbility.Stuff: return StuffPressure;
                case TalentAbility.Command: return CommandPressure;
                case TalentAbility.Movement: return MovementPressure;
                case TalentAbility.Stamina: return StaminaPressure;
                default: throw new ArgumentOutOfRangeException(nameof(ability));
            }
        }

        public TalentSnapshot Replacing(TalentAbility ability, TalentGrade grade, int pressure)
        {
            return new TalentSnapshot(
                ability == TalentAbility.Stuff ? grade : Stuff,
                ability == TalentAbility.Command ? grade : Command,
                ability == TalentAbility.Movement ? grade : Movement,
                ability == TalentAbility.Stamina ? grade : Stamina,
                ability == TalentAbility.Stuff ? pressure : StuffPressure,
                ability == TalentAbility.Command ? pressure : CommandPressure,
                ability == TalentAbility.Movement ? pressure : MovementPressure,
                ability == TalentAbility.Stamina ? pressure : StaminaPressure);
        }
    }

    public sealed class TalentApplication
    {
        public TalentApplication(int allowed, TalentSnapshot talent, TalentAbility? bloomed)
        {
            Allowed = allowed;
            Talent = talent;
            Bloomed = bloomed;
        }

        public int Allowed { get; }
        public TalentSnapshot Talent { get; }
        public TalentAbility? Bloomed { get; }
    }

    public static class TalentRules
    {
        public static TalentSnapshot Make(string careerId)
        {
            var generator = new SplitMix64(StableHash.Fnv1A64Value("talent|" + careerId));
            var grades = new[] { Draw(ref generator), Draw(ref generator), Draw(ref generator), Draw(ref generator) };
            var hasAtLeastB = false;
            var hasAtMostC = false;
            for (var index = 0; index < grades.Length; index++)
            {
                hasAtLeastB |= grades[index] >= TalentGrade.B;
                hasAtMostC |= grades[index] <= TalentGrade.C;
            }

            if (!hasAtLeastB)
            {
                grades[generator.NextInt(4)] = generator.NextInt(2) == 0 ? TalentGrade.B : TalentGrade.A;
            }

            if (!hasAtMostC)
            {
                grades[generator.NextInt(4)] = generator.NextInt(2) == 0 ? TalentGrade.C : TalentGrade.D;
            }

            return new TalentSnapshot(grades[0], grades[1], grades[2], grades[3]);
        }

        public static TalentApplication Apply(TalentSnapshot talent, TalentAbility ability, int current, int points)
        {
            var allowed = Math.Max(0, Math.Min(points, talent.Grade(ability).Ceiling() - current));
            if (allowed >= points) return new TalentApplication(allowed, talent, null);
            var grade = talent.Grade(ability);
            var next = grade.Next();
            if (!next.HasValue) return new TalentApplication(allowed, talent, null);
            var pressure = talent.Pressure(ability) + 1;
            if (pressure < grade.BloomThreshold())
            {
                return new TalentApplication(allowed, talent.Replacing(ability, grade, pressure), null);
            }

            return new TalentApplication(allowed, talent.Replacing(ability, next.Value, 0), ability);
        }

        public static TalentAbility From(TrainingFocus focus)
        {
            switch (focus)
            {
                case TrainingFocus.Velocity: return TalentAbility.Stuff;
                case TrainingFocus.Command:
                case TrainingFocus.GamePlanning: return TalentAbility.Command;
                case TrainingFocus.BreakingBall: return TalentAbility.Movement;
                case TrainingFocus.Stamina:
                case TrainingFocus.Recovery: return TalentAbility.Stamina;
                default: throw new ArgumentOutOfRangeException(nameof(focus));
            }
        }

        private static TalentGrade Draw(ref SplitMix64 generator)
        {
            var roll = generator.NextInt(100);
            if (roll < 18) return TalentGrade.D;
            if (roll < 45) return TalentGrade.C;
            if (roll < 75) return TalentGrade.B;
            if (roll < 93) return TalentGrade.A;
            return TalentGrade.S;
        }
    }
}
