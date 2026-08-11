using System;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.HighSchool
{
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

        public static PitcherSnapshot Grow(
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
                        profile.VelocityTenthsKph + (focus == TrainingFocus.Velocity ? points * 5 : 0),
                        1000,
                        1700);
                    var control = Bound(
                        profile.Control + (focus == TrainingFocus.Command ? points : 0),
                        20,
                        80);
                    var command = Bound(
                        profile.Command +
                        (focus == TrainingFocus.Command || focus == TrainingFocus.GamePlanning
                            ? points
                            : 0),
                        20,
                        80);
                    var movement = Bound(
                        profile.Movement + (isBreakingTarget ? points * 2 : 0),
                        20,
                        80);
                    var whiff = Bound(
                        profile.Whiff +
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
                Bound(pitcher.Stuff + (focus == TrainingFocus.Velocity ? points : 0), 20, 80),
                Bound(
                    pitcher.Command +
                    (focus == TrainingFocus.Command || focus == TrainingFocus.GamePlanning
                        ? points
                        : 0),
                    20,
                    80),
                Bound(pitcher.Movement + (focus == TrainingFocus.BreakingBall ? points : 0), 20, 80),
                Bound(
                    pitcher.Stamina +
                    (focus == TrainingFocus.Stamina || focus == TrainingFocus.Recovery ? points : 0),
                    20,
                    80),
                profiles,
                pitcher.ThrowingHand);
        }

        private static int Bound(int value, int lower, int upper)
        {
            return Math.Min(upper, Math.Max(lower, value));
        }
    }
}
