using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.Pitching
{
    public enum PitchSequenceTag { SpeedLadder, EyeLevelChange, InsideOutside, ExpandAfterTwoStrikes, StealStrike, CounterRead }

    public sealed class PitchSequencePitch
    {
        public PitchSequencePitch(PitchType pitchType, PitchZone zone, ZoneIntent intent, int expectedVelocityKph, PitchOutcome outcome)
        {
            PitchType = pitchType; Zone = zone; Intent = intent; ExpectedVelocityKph = expectedVelocityKph; Outcome = outcome;
        }
        public PitchType PitchType { get; }
        public PitchZone Zone { get; }
        public ZoneIntent Intent { get; }
        public int ExpectedVelocityKph { get; }
        public PitchOutcome Outcome { get; }
    }

    public sealed class PitchSequenceMoment
    {
        public PitchSequenceMoment(int pitchNumber, PitchSequenceTag tag, string headline, string detail)
        { PitchNumber = pitchNumber; Tag = tag; Headline = headline; Detail = detail; }
        public int PitchNumber { get; }
        public PitchSequenceTag Tag { get; }
        public string Headline { get; }
        public string Detail { get; }
    }

    public static class PitchSequenceEvaluator
    {
        public const int MinimumSpeedDifferenceKph = 12;

        public static PitchSequenceMoment Evaluate(IReadOnlyList<PitchSequencePitch> recent,
            PlateAppearanceContext context, PitchSequencePitch current, RivalMemorySnapshot rivalMemory)
        {
            if (!Valid(current) || context.Balls < 0 || context.Balls > 3 || context.Strikes < 0 || context.Strikes > 2 || context.PitchNumber <= 0)
                return null;
            if (RecognizesCounterRead(context, current, rivalMemory))
                return Moment(context, PitchSequenceTag.CounterRead, "읽힘을 역이용했다", "상대 벤치가 읽은 반복을 끊고 좋은 결과를 만들었습니다.");
            if (context.Strikes == 2 && current.Intent == ZoneIntent.Chase && current.Outcome == PitchOutcome.SwingingStrike)
                return Moment(context, PitchSequenceTag.ExpandAfterTwoStrikes, "결정구 유인 성공", "2스트라이크 뒤 존 밖으로 유도해 헛스윙 삼진을 만들었습니다.");
            if (context.Balls > context.Strikes && context.Strikes < 2 && current.Intent == ZoneIntent.Strike && AddsStrike(current.Outcome))
                return Moment(context, PitchSequenceTag.StealStrike, "카운트를 되찾았다", "타자 우세 카운트에서 스트라이크를 넣어 승부를 원점으로 돌렸습니다.");
            var previous = recent == null ? null : recent.Skip(Math.Max(0, recent.Count - 3)).LastOrDefault();
            if (previous == null || !Valid(previous)) return null;
            var difference = Math.Abs(current.ExpectedVelocityKph - previous.ExpectedVelocityKph);
            if (difference >= MinimumSpeedDifferenceKph && DisruptsTiming(current.Outcome))
                return Moment(context, PitchSequenceTag.SpeedLadder, "속도차 적중 · " + difference + "km/h", "앞선 공과 " + difference + "km/h 차이를 만들어 타자의 타이밍을 무너뜨렸습니다.");
            if (Opposite(previous.Zone.Row, current.Zone.Row) && DisruptsTiming(current.Outcome))
                return Moment(context, PitchSequenceTag.EyeLevelChange, "눈높이를 바꿨다", "높은 코스와 낮은 코스를 이어 타자의 시선을 흔들었습니다.");
            if (Opposite(previous.Zone.Column, current.Zone.Column) && SecuresResult(current.Outcome))
                return Moment(context, PitchSequenceTag.InsideOutside, "가로 폭을 썼다", "몸쪽과 바깥쪽을 연달아 갈라 좋은 결과를 만들었습니다.");
            return null;
        }

        private static bool RecognizesCounterRead(PlateAppearanceContext context, PitchSequencePitch current, RivalMemorySnapshot memory)
        {
            if (memory == null || !SecuresResult(current.Outcome)) return false;
            var adaptation = new RivalMemoryEngine().Analyze(memory, context);
            if (!adaptation.DetectedPitch.HasValue && !adaptation.DetectedZone.HasValue) return false;
            return (adaptation.DetectedPitch.HasValue && adaptation.DetectedPitch.Value != current.PitchType) ||
                   (adaptation.DetectedZone.HasValue && adaptation.DetectedZone.Value != current.Zone);
        }
        private static PitchSequenceMoment Moment(PlateAppearanceContext context, PitchSequenceTag tag, string headline, string detail) =>
            new PitchSequenceMoment(context.PitchNumber, tag, headline, detail);
        private static bool Opposite(int left, int right) => (left == 0 && right == 2) || (left == 2 && right == 0);
        private static bool DisruptsTiming(PitchOutcome outcome) => outcome == PitchOutcome.SwingingStrike || outcome == PitchOutcome.InPlayOut;
        private static bool SecuresResult(PitchOutcome outcome) => outcome == PitchOutcome.CalledStrike || DisruptsTiming(outcome);
        private static bool AddsStrike(PitchOutcome outcome) => outcome == PitchOutcome.CalledStrike || outcome == PitchOutcome.SwingingStrike || outcome == PitchOutcome.Foul;
        private static bool Valid(PitchSequencePitch pitch) => pitch.Zone.Row >= 0 && pitch.Zone.Row <= 2 && pitch.Zone.Column >= 0 && pitch.Zone.Column <= 2 && pitch.ExpectedVelocityKph > 0;
    }

    public static class PitchSequenceMasteryRules
    {
        public const int MaximumTrustReward = 3;
        public static int TrustReward(int? sequenceMasteryCount) => Math.Min(Math.Max(sequenceMasteryCount ?? 0, 0), MaximumTrustReward);
    }
}
