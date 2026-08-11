using System;
using System.Collections.Generic;
using Baseball.Application.Persistence;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    /// <summary>
    /// Pure projection of one committed Core result into the durable sequence/delivery evidence
    /// accepted by Application. Both coordinator and production persistence use this exact helper,
    /// preventing report counters from drifting from the command payload after process death.
    /// </summary>
    public static class PitchCommitMetrics
    {
        public static PitchCommitMetricEvidence Evaluate(
            PitchSessionMetricsState current,
            PitchCommit commit)
        {
            if (commit == null) throw new ArgumentNullException(nameof(commit));
            if (commit.PreResultContext == null)
                throw new InvalidOperationException("pitch.sequence_context_missing");
            if (commit.ExpectedVelocityKph <= 0)
                throw new InvalidOperationException("pitch.sequence_velocity_missing");

            current = current ?? PitchSessionMetricsState.Empty;
            var sequencePitch = new PitchSequencePitch(
                commit.Call.PitchType,
                commit.Call.Zone,
                commit.Call.ZoneIntent,
                commit.ExpectedVelocityKph,
                commit.Result.Snapshot.Outcome);
            PitchSequenceMoment moment = PitchSequenceEvaluator.Evaluate(
                current.RecentSequencePitches,
                commit.PreResultContext,
                sequencePitch,
                commit.PreResultRivalMemory);
            var delivery = new PitchDeliveryMetricState(
                commit.Delivery.ReleaseAccuracy,
                commit.Delivery.AimAccuracy,
                commit.WasDirect);
            if (!string.IsNullOrWhiteSpace(commit.AbilityMomentType) &&
                !PitchAbilityWire.IsValid(commit.AbilityMomentType))
            {
                throw new InvalidOperationException("pitch.ability_moment_invalid");
            }
            return new PitchCommitMetricEvidence(
                sequencePitch,
                moment?.Tag,
                delivery,
                moment,
                commit.AbilityMomentType);
        }

        /// <summary>
        /// Evaluates the same pre-result Core readout used by gameplay. Presentation persists only
        /// this stable wire value; it never infers an ability moment from display copy or animation.
        /// </summary>
        public static string AbilityMomentType(
            PitcherSnapshot pitcher,
            PitchCall call,
            PlateAppearanceContext context,
            PitchKernelResult result)
        {
            if (pitcher == null) throw new ArgumentNullException(nameof(pitcher));
            if (call == null) throw new ArgumentNullException(nameof(call));
            if (context == null) throw new ArgumentNullException(nameof(context));
            if (result?.Snapshot?.Execution == null) throw new ArgumentNullException(nameof(result));
            PitchAbilityReadout readout = PitchAbilityRules.Readout(pitcher, call, context);
            PitchAbilityKind? moment = PitchAbilityRules.Moment(
                result.Snapshot.Outcome,
                result.Snapshot.Execution,
                readout);
            return moment.HasValue ? moment.Value.Value() : null;
        }

        public static PitchSessionMetricsState Consuming(
            PitchSessionMetricsState current,
            PitchCommitMetricEvidence evidence,
            bool plateAppearanceEnded)
        {
            if (evidence == null) throw new ArgumentNullException(nameof(evidence));
            current = current ?? PitchSessionMetricsState.Empty;

            var recent = new List<PitchSequencePitch>(current.RecentSequencePitches);
            recent.Add(evidence.SequencePitch);
            while (recent.Count > 3) recent.RemoveAt(0);
            if (plateAppearanceEnded) recent.Clear();

            var tags = new List<PitchSequenceTag>(current.SequenceMasteryTags);
            if (evidence.SequenceTag.HasValue) tags.Add(evidence.SequenceTag.Value);
            bool direct = evidence.Delivery.WasDirect;
            int score = direct ? evidence.Delivery.Score : 0;
            bool hasAbilityMoment = !string.IsNullOrWhiteSpace(evidence.AbilityMomentType);
            var abilityTypes = new List<string>(current.AbilityMomentTypes);
            if (hasAbilityMoment) abilityTypes.Add(evidence.AbilityMomentType);
            return new PitchSessionMetricsState(
                recent,
                tags,
                current.DirectDeliveryCount + (direct ? 1 : 0),
                current.DeliveryScoreTotal + score,
                direct ? Math.Max(current.BestDeliveryScore, score) : current.BestDeliveryScore,
                current.PerfectDeliveryCount + (evidence.Delivery.IsPerfect ? 1 : 0),
                current.AbilityMomentCount + (hasAbilityMoment ? 1 : 0),
                abilityTypes);
        }
    }

    public sealed class PitchCommitMetricEvidence
    {
        public PitchCommitMetricEvidence(
            PitchSequencePitch sequencePitch,
            PitchSequenceTag? sequenceTag,
            PitchDeliveryMetricState delivery,
            PitchSequenceMoment moment,
            string abilityMomentType = null)
        {
            SequencePitch = sequencePitch ?? throw new ArgumentNullException(nameof(sequencePitch));
            SequenceTag = sequenceTag;
            Delivery = delivery ?? throw new ArgumentNullException(nameof(delivery));
            Moment = moment;
            AbilityMomentType = abilityMomentType;
        }

        public PitchSequencePitch SequencePitch { get; }
        public PitchSequenceTag? SequenceTag { get; }
        public PitchDeliveryMetricState Delivery { get; }
        public PitchSequenceMoment Moment { get; }
        public string AbilityMomentType { get; }
    }
}
