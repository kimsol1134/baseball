using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Core.HighSchool
{
    public sealed class PitchProfileAdvancement
    {
        public PitchProfileAdvancement(PitchType pitchType, PitchProfileSnapshot before, PitchProfileSnapshot after)
        { PitchType = pitchType; Before = before; After = after; }
        public PitchType PitchType { get; }
        public PitchProfileSnapshot Before { get; }
        public PitchProfileSnapshot After { get; }
    }

    public sealed class PitcherAdvancementReceipt
    {
        public PitcherAdvancementReceipt(
            PitcherSnapshot pitcher,
            TalentAbility ability,
            int baseBefore,
            int baseAfter,
            int masteryBefore,
            int masteryAfter,
            IReadOnlyList<PitchProfileAdvancement> profileChanges)
        {
            Pitcher = pitcher; Ability = ability; BaseBefore = baseBefore; BaseAfter = baseAfter;
            MasteryBefore = masteryBefore; MasteryAfter = masteryAfter; ProfileChanges = profileChanges;
        }
        public PitcherSnapshot Pitcher { get; }
        public TalentAbility Ability { get; }
        public int BaseBefore { get; }
        public int BaseAfter { get; }
        public int MasteryBefore { get; }
        public int MasteryAfter { get; }
        public IReadOnlyList<PitchProfileAdvancement> ProfileChanges { get; }
        public int BaseDelta { get { return BaseAfter - BaseBefore; } }
        public int MasteryDelta { get { return MasteryAfter - MasteryBefore; } }
    }

    public enum PitcherBuildIdentity
    {
        Power,
        Command,
        Movement,
        Stamina
    }

    /// <summary>
    /// Stable pitcher identity. Ties deliberately keep the first value in stuff, command,
    /// movement, stamina order so recommendation copy is identical after save/restart.
    /// </summary>
    public static class PitcherBuildRules
    {
        public static PitcherBuildIdentity Identity(PitcherSnapshot pitcher)
        {
            if (pitcher == null) throw new ArgumentNullException(nameof(pitcher));
            var identity = PitcherBuildIdentity.Power;
            var rating = pitcher.Stuff;
            if (pitcher.Command > rating) { identity = PitcherBuildIdentity.Command; rating = pitcher.Command; }
            if (pitcher.Movement > rating) { identity = PitcherBuildIdentity.Movement; rating = pitcher.Movement; }
            if (pitcher.Stamina > rating) identity = PitcherBuildIdentity.Stamina;
            return identity;
        }
    }

    /// <summary>
    /// Shared high-school/pro development projection. A missing breaking-ball target deliberately
    /// keeps the legacy behaviour and develops every owned breaking ball.
    /// </summary>
    public static class PitcherGrowthRules
    {
        public static PitchType? NormalizeBreakingBallTarget(
            PitchType? targetPitch,
            PitcherSnapshot pitcher)
        {
            if (!targetPitch.HasValue || targetPitch.Value == PitchType.FourSeam ||
                pitcher?.PitchProfiles == null ||
                !pitcher.PitchProfiles.Any(profile => profile.PitchType == targetPitch.Value))
            {
                return null;
            }
            return targetPitch;
        }

        public static bool IsOwnedBreakingBall(PitchType targetPitch, PitcherSnapshot pitcher)
        {
            return targetPitch != PitchType.FourSeam &&
                pitcher?.PitchProfiles != null &&
                pitcher.PitchProfiles.Any(profile => profile.PitchType == targetPitch);
        }

        private static PitcherSnapshot ApplyStoredGrowth(
            PitcherSnapshot pitcher,
            TrainingFocus focus,
            int points,
            PitchType? targetPitch = null,
            bool promoteDevelopmentPitch = true)
        {
            if (pitcher == null) throw new ArgumentNullException(nameof(pitcher));
            if (points <= 0) return pitcher;

            var breakingTarget = NormalizeBreakingBallTarget(targetPitch, pitcher);
            var profiles = pitcher.PitchProfiles == null
                ? null
                : pitcher.PitchProfiles.Select(profile =>
                {
                    var isBreakingTarget = focus == TrainingFocus.BreakingBall &&
                        profile.PitchType != PitchType.FourSeam &&
                        (!breakingTarget.HasValue || profile.PitchType == breakingTarget.Value);
                    var velocity = Bound(
                        (long)profile.VelocityTenthsKph + (focus == TrainingFocus.Velocity ? (long)points * 5L : 0L),
                        1000,
                        PitchAbilityRules.MaximumProfileVelocity(profile.PitchType));
                    var control = Bound(
                        (long)profile.Control + (focus == TrainingFocus.Command ? points : 0),
                        20,
                        80);
                    var command = Bound(
                        (long)profile.Command +
                        (focus == TrainingFocus.Command || focus == TrainingFocus.GamePlanning
                            ? points
                            : 0),
                        20,
                        80);
                    var movement = Bound(
                        (long)profile.Movement + (isBreakingTarget ? (long)points * 2L : 0L),
                        20,
                        80);
                    var whiff = Bound(
                        (long)profile.Whiff +
                        (focus == TrainingFocus.Velocity && profile.PitchType == PitchType.FourSeam
                            ? points
                            : 0) +
                        (isBreakingTarget ? points : 0),
                        20,
                        80);
                    var fatigueCost = focus == TrainingFocus.Stamina
                        ? Math.Max(0, profile.FatigueCost - points / 2)
                        : profile.FatigueCost;
                    var role = promoteDevelopmentPitch &&
                               profile.Role == PitchUsageRole.Development &&
                               command + whiff + profile.WeakContact >= 150
                        ? PitchUsageRole.Secondary
                        : profile.Role;
                    return new PitchProfileSnapshot(
                        profile.PitchType,
                        role,
                        velocity,
                        control,
                        command,
                        movement,
                        whiff,
                        profile.WeakContact,
                        fatigueCost);
                }).ToArray();

            return new PitcherSnapshot(
                pitcher.Id,
                pitcher.Name,
                Bound((long)pitcher.Stuff + (focus == TrainingFocus.Velocity ? points : 0), 20, 80),
                Bound(
                    (long)pitcher.Command +
                    (focus == TrainingFocus.Command || focus == TrainingFocus.GamePlanning
                        ? points
                        : 0),
                    20,
                    80),
                Bound((long)pitcher.Movement + (focus == TrainingFocus.BreakingBall ? points : 0), 20, 80),
                Bound(
                    (long)pitcher.Stamina +
                    (focus == TrainingFocus.Stamina || focus == TrainingFocus.Recovery ? points : 0),
                    20,
                    80),
                profiles,
                pitcher.ThrowingHand,
                pitcher.Mastery);
        }

        public static PitcherAdvancementReceipt Advance(
            PitcherSnapshot pitcher,
            TrainingFocus focus,
            int points,
            PitchType? targetPitch = null,
            bool promoteDevelopmentPitch = true)
        {
            if (pitcher == null) throw new ArgumentNullException(nameof(pitcher));
            var ability = TalentRules.From(focus);
            var before = Rating(pitcher, ability);
            var masteryBefore = pitcher.EffectiveMastery.Value(ability);
            if (points <= 0)
                return new PitcherAdvancementReceipt(pitcher, ability, before, before, masteryBefore, masteryBefore, new PitchProfileAdvancement[0]);
            var safePoints = Math.Min(points, AbilityMasterySnapshot.TechnicalMaximum);
            var stored = ApplyStoredGrowth(pitcher, focus, safePoints, targetPitch, promoteDevelopmentPitch);
            var after = Rating(stored, ability);
            var applied = Math.Max(0, after - before);
            var overflow = Math.Max(0, safePoints - applied);
            var masteryAfter = pitcher.EffectiveMastery.Add(ability, overflow).Value(ability);
            var updated = new PitcherSnapshot(
                stored.Id, stored.Name, stored.Stuff, stored.Command, stored.Movement, stored.Stamina,
                stored.PitchProfiles, stored.ThrowingHand,
                pitcher.Mastery != null || overflow > 0 ? pitcher.EffectiveMastery.With(ability, masteryAfter) : null);
            var changes = new List<PitchProfileAdvancement>();
            var beforeProfiles = pitcher.PitchProfiles ?? new PitchProfileSnapshot[0];
            var afterProfiles = updated.PitchProfiles ?? new PitchProfileSnapshot[0];
            for (var index = 0; index < Math.Min(beforeProfiles.Count, afterProfiles.Count); index++)
                if (!Equals(beforeProfiles[index], afterProfiles[index]))
                    changes.Add(new PitchProfileAdvancement(afterProfiles[index].PitchType, beforeProfiles[index], afterProfiles[index]));
            return new PitcherAdvancementReceipt(updated, ability, before, after, masteryBefore, masteryAfter, changes);
        }

        public static PitcherSnapshot Grow(
            PitcherSnapshot pitcher,
            TrainingFocus focus,
            int points,
            PitchType? targetPitch = null,
            bool promoteDevelopmentPitch = true)
        { return Advance(pitcher, focus, points, targetPitch, promoteDevelopmentPitch).Pitcher; }

        private static int Rating(PitcherSnapshot pitcher, TalentAbility ability)
        {
            switch (ability)
            {
                case TalentAbility.Stuff: return pitcher.Stuff;
                case TalentAbility.Command: return pitcher.Command;
                case TalentAbility.Movement: return pitcher.Movement;
                default: return pitcher.Stamina;
            }
        }

        private static int Bound(long value, int lower, int upper)
        {
            return (int)Math.Min(upper, Math.Max(lower, value));
        }
    }
}
