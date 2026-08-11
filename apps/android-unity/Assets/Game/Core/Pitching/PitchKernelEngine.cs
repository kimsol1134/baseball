using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.Random;

namespace Baseball.Core.Pitching
{
    public sealed class CatcherRecommendationPair
    {
        public CatcherRecommendationPair(CatcherRecommendation primary, CatcherRecommendation alternative)
        { Primary = primary; Alternative = alternative; }
        public CatcherRecommendation Primary { get; }
        public CatcherRecommendation Alternative { get; }
    }

    public sealed class CatcherRecommendationEngine
    {
        public CatcherRecommendationPair Recommend(PitcherSnapshot pitcher, BatterSnapshot batter,
            BatterScoutingSnapshot scouting, PlateAppearanceContext context,
            RivalAdaptationSnapshot adaptation = null, int reliability = 100,
            GameStateSnapshot gameState = null, PitchAnalysisEntry lastPitch = null)
        {
            var twoStrikes = context.Strikes == 2; var protectZone = context.Balls == 3;
            var situation = new SignSituation(context, gameState, lastPitch);
            var desired = RecommendedPrimaryPitch(pitcher, scouting.PitchWeakness, twoStrikes, protectZone,
                lastPitch == null ? (PitchType?)null : lastPitch.PitchType);
            var repetitionAvoided = adaptation != null && adaptation.Level >= 500 && adaptation.DetectedPitch == desired;
            var mustChange = repetitionAvoided || (situation.AvoidsRepeat && lastPitch != null && lastPitch.PitchType == desired);
            var primaryPitch = mustChange ? RecommendedAlternativePitch(pitcher, desired,
                desired == PitchType.FourSeam ? PitchType.Slider : PitchType.FourSeam) : desired;
            var primaryProfile = pitcher.Profile(primaryPitch); var primaryZone = situation.Shift(scouting.ColdZone);
            var primaryReasons = new List<string>
            {
                repetitionAvoided ? "rival.pattern_detected" : mustChange ? "sequence.avoid_repeat" :
                    primaryPitch == scouting.PitchWeakness ? "scouting.pitch_weakness" : "arsenal.best_available",
                "scouting.cold_zone", situation.CountCode
            };
            primaryReasons.AddRange(situation.ExtraReasonCodes);
            var primary = new CatcherRecommendation(new PitchCall(primaryPitch, primaryZone,
                    ZoneIntentRules.Clamp(situation.ZoneIntent(protectZone, twoStrikes), primaryZone),
                    situation.DemandsControl || protectZone || (primaryProfile != null && primaryProfile.Role == PitchUsageRole.Development)
                        ? PitchIntensity.Controlled : PitchIntensity.Normal),
                ScoutingEstimate.AdjustedConfidence(Clamp(520 + (pitcher.Command - 50) * 4 +
                    ((primaryProfile == null ? 50 : primaryProfile.Command) - 50) * 2 + (batter.Discipline < 50 ? 45 : 0), 350, 850), reliability),
                primaryReasons);
            var alternativePitch = repetitionAvoided ? desired : RecommendedAlternativePitch(pitcher, primaryPitch,
                scouting.PitchWeakness == PitchType.FourSeam ? PitchType.Slider : PitchType.FourSeam);
            var mirrored = new PitchZone(2 - scouting.HotZone.Row, 2 - scouting.HotZone.Column);
            var alternativeZone = mirrored == scouting.HotZone ? new PitchZone(0, 2) : mirrored;
            var alternative = new CatcherRecommendation(new PitchCall(alternativePitch, alternativeZone,
                    ZoneIntentRules.Clamp(protectZone ? ZoneIntent.Strike : ZoneIntent.Edge, alternativeZone),
                    context.Fatigue >= 60 ? PitchIntensity.Controlled : PitchIntensity.Normal),
                ScoutingEstimate.AdjustedConfidence(Clamp(430 + (pitcher.Stuff - 50) * 3, 300, 760), reliability),
                new[] { "scouting.avoid_hot_zone", "sequence.change_speed", protectZone ? "count.avoid_walk" : "count.alternative" });
            return new CatcherRecommendationPair(primary, alternative);
        }

        private static PitchType RecommendedPrimaryPitch(PitcherSnapshot pitcher, PitchType desired, bool twoStrikes,
            bool protectZone, PitchType? lastPitchType)
        {
            if (pitcher.PitchProfiles == null || pitcher.PitchProfiles.Count == 0) return desired;
            PitchProfileSnapshot best = null; var bestScore = int.MinValue;
            foreach (var profile in pitcher.PitchProfiles)
            {
                var score = ProfileScore(profile) + (profile.PitchType == desired ? 90 : 0) -
                    (profile.Role == PitchUsageRole.Development ? 120 : 0) -
                    (lastPitchType.HasValue && profile.PitchType == lastPitchType.Value ? 70 : 0) +
                    (twoStrikes ? profile.Whiff - 50 : 0) + (protectZone ? profile.Command - 50 : 0);
                if (score > bestScore) { bestScore = score; best = profile; }
            }
            return best == null ? desired : best.PitchType;
        }

        private static PitchType RecommendedAlternativePitch(PitcherSnapshot pitcher, PitchType excluding, PitchType legacy)
        {
            if (pitcher.PitchProfiles == null) return legacy;
            return pitcher.PitchProfiles.Where(item => item.PitchType != excluding && item.Role != PitchUsageRole.Development)
                .OrderByDescending(ProfileScore).Select(item => item.PitchType).DefaultIfEmpty(legacy).First();
        }
        private static int ProfileScore(PitchProfileSnapshot profile) => profile.Command + profile.Whiff + profile.WeakContact;
        private static int Clamp(int value, int low, int high) => Math.Min(Math.Max(value, low), high);
    }

    public sealed class PitchKernelEngine
    {
        private enum BatterApproach { Patient, Aggressive, Protect, Power }
        private struct SituationalBias
        {
            public SituationalBias(int zoneSwing, int chase, int contact, int foul, string note)
            { ZoneSwing = zoneSwing; Chase = chase; Contact = contact; Foul = foul; Note = note; }
            public int ZoneSwing { get; }
            public int Chase { get; }
            public int Contact { get; }
            public int Foul { get; }
            public string Note { get; }
        }
        private sealed class BatterPlan
        {
            public BatterPlan(PitchType pitch, PitchZone zone, BatterApproach approach, SituationalBias bias, string commitment)
            { ExpectedPitch = pitch; ExpectedZone = zone; Approach = approach; Bias = bias; Commitment = commitment; }
            public PitchType ExpectedPitch { get; }
            public PitchZone ExpectedZone { get; }
            public BatterApproach Approach { get; }
            public SituationalBias Bias { get; }
            public string Commitment { get; }
        }
        private sealed class Resolution
        {
            public Resolution(PitchOutcome outcome, BattedBall ball) { Outcome = outcome; BattedBall = ball; }
            public PitchOutcome Outcome { get; }
            public BattedBall BattedBall { get; }
        }
        private struct CountAdvance
        {
            public CountAdvance(int balls, int strikes, PlateAppearanceResult? result) { Balls = balls; Strikes = strikes; Result = result; }
            public int Balls { get; }
            public int Strikes { get; }
            public PlateAppearanceResult? Result { get; }
        }

        private readonly CatcherRecommendationEngine recommendationEngine = new CatcherRecommendationEngine();
        private readonly RivalMemoryEngine rivalMemoryEngine = new RivalMemoryEngine();
        private readonly BallInPlayEngine ballInPlayEngine = new BallInPlayEngine();
        private readonly BaserunnerEngine baserunnerEngine = new BaserunnerEngine();
        private readonly InningStateEngine inningStateEngine = new InningStateEngine();
        private readonly GameAnalysisEngine gameAnalysisEngine = new GameAnalysisEngine();

        public PitchPreparation PreparePitch(PreparePitchParams parameters)
        {
            var seed = Validate(parameters); var adaptation = rivalMemoryEngine.Analyze(parameters.RivalMemory, parameters.Context);
            var plan = CommitBatterPlan(parameters, adaptation, seed); var reliability = ScoutingEstimate.EffectiveReliability(parameters.Scouting.Reliability, parameters.RivalMemory);
            var estimate = ScoutingEstimate.EstimatedScouting(parameters.Scouting, reliability,
                ScoutingEstimate.MatchupSeed(parameters.Pitcher.Id, parameters.Batter.Id));
            var recommendations = recommendationEngine.Recommend(parameters.Pitcher, parameters.Batter, estimate,
                parameters.Context, adaptation, reliability, parameters.GameState,
                parameters.GameLog == null ? null : parameters.GameLog.Entries.LastOrDefault());
            var token = PreparationToken(parameters, plan.Commitment, recommendations.Primary, recommendations.Alternative);
            return new PitchPreparation(parameters.Seed, parameters.Context.Revision, parameters.Context.PitchNumber,
                token, plan.Commitment, RecommendationSnapshot(recommendations.Primary, plan.Bias.Note),
                RecommendationSnapshot(recommendations.Alternative, string.Empty), adaptation,
                ScoutingEstimate.Report(estimate, reliability, parameters.RivalMemory == null ? 0 : parameters.RivalMemory.TotalPitchesSeen));
        }

        public PitchKernelResult SubmitPitch(SubmitPitchParams parameters, PitchDelivery? delivery = null)
        {
            var prepare = new PreparePitchParams(parameters.Seed, parameters.Pitcher, parameters.Batter,
                parameters.Scouting, parameters.Context, parameters.RivalMemory, parameters.GameState, parameters.GameLog);
            var seed = Validate(prepare); ValidateCall(parameters.Call, parameters.Pitcher); ValidateDelivery(delivery);
            var adaptation = rivalMemoryEngine.Analyze(parameters.RivalMemory, parameters.Context);
            var plan = CommitBatterPlan(prepare, adaptation, seed);
            var reliability = ScoutingEstimate.EffectiveReliability(parameters.Scouting.Reliability, parameters.RivalMemory);
            var estimate = ScoutingEstimate.EstimatedScouting(parameters.Scouting, reliability,
                ScoutingEstimate.MatchupSeed(parameters.Pitcher.Id, parameters.Batter.Id));
            var recommendations = recommendationEngine.Recommend(parameters.Pitcher, parameters.Batter, estimate,
                parameters.Context, adaptation, reliability, parameters.GameState,
                parameters.GameLog == null ? null : parameters.GameLog.Entries.LastOrDefault());
            if (parameters.PreparationToken != PreparationToken(prepare, plan.Commitment, recommendations.Primary, recommendations.Alternative))
                throw new SimulationException(SimulationErrorCode.InvalidPreparationToken, "Pitch preparation token is invalid or stale");

            var execution = ExecutePitch(parameters, delivery, seed);
            var wasInZone = Math.Abs(execution.ActualX) <= 500 && Math.Abs(execution.ActualY) <= 500;
            var neutral = ResolvePitch(parameters, plan, execution, wasInZone, adaptation, seed);
            var currentGame = parameters.GameState ?? GameStateSnapshot.Standard;
            var fielding = neutral.BattedBall == null ? null : ballInPlayEngine.Resolve(neutral.BattedBall, currentGame, seed, parameters.Context.PitchNumber);
            var outcome = fielding == null ? neutral.Outcome : fielding.FinalOutcome;
            var batterSwung = outcome != PitchOutcome.Ball && outcome != PitchOutcome.CalledStrike;
            var selection = SelectionQualityFor(parameters.Call, parameters.Pitcher, parameters.Scouting, parameters.Context, adaptation);
            var accepted = parameters.Call.Equals(recommendations.Primary.Call);
            var count = AdvanceCount(parameters.Context, outcome); var nextSeed = DeriveNextSeed(seed);
            var revision = unchecked(parameters.Context.Revision + 1);
            var fatigue = Math.Min(100, parameters.Context.Fatigue + PitchAbilityRules.FatigueCost(parameters.Call.Intensity, parameters.Pitcher.Profile(parameters.Call.PitchType)));
            var memory = rivalMemoryEngine.Record(parameters.RivalMemory, parameters.Pitcher, parameters.Batter,
                parameters.Context, parameters.Call, outcome, count.Result.HasValue);
            var steal = baserunnerEngine.ResolveSteal(currentGame.Runners, currentGame.Defense, parameters.Context, seed);
            var inning = inningStateEngine.Resolve(parameters.Context, currentGame, count.Result, neutral.BattedBall,
                fielding, steal.RunnersAfter, steal.OutsRecorded, seed);
            var ended = count.Result.HasValue || inning.InningEnded;
            BaserunnerAdvanceSnapshot advance = null;
            if (count.Result.HasValue) advance = baserunnerEngine.Advance(steal.RunnersAfter, outcome, count.Result.Value,
                currentGame.Defense, seed, inning.DoublePlayCompleted, neutral.BattedBall, fielding, inning.InningEnded);
            var runnersAfter = inning.InningEnded ? BaserunnerStateSnapshot.Empty : advance == null ? steal.RunnersAfter : advance.After;
            var updatedGame = new GameStateSnapshot(currentGame.Defense, currentGame.Park, runnersAfter,
                currentGame.RunsAllowed + (advance == null ? 0 : advance.RunsScored), inning.After);
            var updatedLog = gameAnalysisEngine.Record(parameters.GameLog, parameters.GameLog == null ? "game-" + parameters.Pitcher.Id : parameters.GameLog.GameId,
                parameters.Call.PitchType, wasInZone, batterSwung, outcome, count.Result, selection,
                execution.ExecutionQuality, neutral.BattedBall, fielding, accepted, execution.VelocityTenthsKph);
            var analysis = gameAnalysisEngine.Analyze(updatedLog);
            var nextContext = new PlateAppearanceContext(parameters.Context.PlateAppearanceId, revision,
                inning.After.Inning, inning.After.Outs, count.Result.HasValue ? 0 : count.Balls,
                count.Result.HasValue ? 0 : count.Strikes, count.Result.HasValue ? 1 : parameters.Context.PitchNumber + 1,
                parameters.Context.ScoreDifferential, parameters.Context.Leverage, fatigue);
            var updatedAdaptation = rivalMemoryEngine.Analyze(memory, nextContext);
            var reasons = ResolutionReasons(outcome, wasInZone, plan.ExpectedPitch == parameters.Call.PitchType,
                ZonesNear(plan.ExpectedZone, parameters.Call.Zone), selection, execution.ExecutionQuality, adaptation, fielding);
            var shortFeedback = OutcomeFeedback(outcome);
            var snapshot = new PlateAppearanceSnapshot(revision, count.Balls, count.Strikes,
                parameters.Context.PitchNumber, ended, count.Result, outcome, selection, accepted, fatigue,
                execution, neutral.BattedBall, fielding, currentGame.Runners, updatedGame.Runners,
                advance == null ? 0 : advance.RunsScored, steal.Attempt, inning, reasons,
                shortFeedback, ExecutionBand(execution.ExecutionQuality), shortFeedback + " " + ExecutionBand(execution.ExecutionQuality));
            PitchPreparation nextPreparation = null;
            if (!ended)
                nextPreparation = PreparePitch(new PreparePitchParams(nextSeed, parameters.Pitcher, parameters.Batter,
                    parameters.Scouting, nextContext, memory, parameters.GameState == null ? null : updatedGame,
                    parameters.GameLog == null ? null : updatedLog));
            var deliveryComponent = delivery.HasValue ? "|delivery:" + delivery.Value.ReleaseAccuracy + ":" + delivery.Value.AimAccuracy : string.Empty;
            var eventHash = StableHash.Fnv1A64(string.Join("|", new[]
            {
                parameters.Seed, plan.Commitment, Canonical(parameters.Call) + deliveryComponent,
                Canonical(parameters.Pitcher.Profile(parameters.Call.PitchType)), execution.TargetX.ToString(), execution.TargetY.ToString(),
                execution.ActualX.ToString(), execution.ActualY.ToString(), execution.VelocityTenthsKph.ToString(), outcome.Value(),
                count.Balls.ToString(), count.Strikes.ToString(), count.Result.HasValue ? count.Result.Value.Value() : "active",
                Canonical(memory), updatedAdaptation.Level.ToString(), Canonical(updatedGame), Canonical(updatedLog), nextSeed
            }));
            var events = new List<PitchKernelEvent>();
            events.Add(new PitchKernelEvent("batter_plan_committed", events.Count, planCommitment: plan.Commitment));
            events.Add(new PitchKernelEvent("catcher_recommendations_generated", events.Count,
                primaryRecommendation: recommendations.Primary, alternativeRecommendation: recommendations.Alternative,
                reasonCodes: recommendations.Primary.ReasonCodes));
            events.Add(new PitchKernelEvent("pitch_call_committed", events.Count, call: parameters.Call));
            events.Add(new PitchKernelEvent("pitch_executed", events.Count, execution: execution));
            events.Add(new PitchKernelEvent("pitch_resolved", events.Count, outcome: outcome, reasonCodes: reasons));
            if (steal.Attempt != null) events.Add(new PitchKernelEvent("steal_attempt_resolved", events.Count, stealAttempt: steal.Attempt));
            if (neutral.BattedBall != null) events.Add(new PitchKernelEvent("batted_ball_created", events.Count, battedBall: neutral.BattedBall));
            if (fielding != null) events.Add(new PitchKernelEvent("fielding_resolved", events.Count, fieldingResolution: fielding));
            events.Add(new PitchKernelEvent("rival_memory_updated", events.Count, rivalAdaptation: updatedAdaptation));
            if (count.Result.HasValue)
            {
                if (advance != null) events.Add(new PitchKernelEvent("baserunners_advanced", events.Count, baserunnerAdvance: advance));
                events.Add(new PitchKernelEvent("plate_appearance_ended", events.Count, plateAppearanceResult: count.Result));
            }
            if (inning.OutsRecorded > 0 || inning.InningEnded)
                events.Add(new PitchKernelEvent(inning.InningEnded ? "half_inning_ended" : "outs_recorded", events.Count,
                    inningTransition: inning));
            events.Add(new PitchKernelEvent("game_analysis_updated", events.Count, postgameAnalysis: analysis));
            return new PitchKernelResult(revision, nextSeed, snapshot, nextPreparation, memory,
                updatedAdaptation, updatedGame, updatedLog, analysis, eventHash, events);
        }

        public static string ExecutionBand(int quality)
        {
            if (quality >= 850) return "그대로 꽂혔습니다";
            if (quality >= 700) return "거의 붙었습니다";
            if (quality >= 520) return "조금 벗어났습니다";
            if (quality >= 350) return "많이 벗어났습니다";
            return "손에서 빠졌습니다";
        }

        public static int PullShift(BatSide batSide, int column)
        {
            var direction = batSide == BatSide.Left ? 1 : -1;
            return (1 - column) * 90 * direction;
        }

        public static int BattedQuality(int exitVelocity, int launchAngle)
        {
            int fit;
            if (launchAngle < 90) fit = 30 + Math.Max(0, launchAngle + 150) / 5;
            else fit = Math.Max(0, 240 - Math.Abs(launchAngle - 170) * 7 / 10 - (launchAngle > 340 ? launchAngle - 340 : 0));
            var baseQuality = Math.Max(0, Math.Min(758, exitVelocity * 7 / 10 + fit - 600));
            if (exitVelocity < 1470 || launchAngle < 170 || launchAngle > 340) return baseQuality;
            return Math.Max(700, Math.Min(940, 765 + (exitVelocity - 1470) / 3 + (90 - Math.Abs(launchAngle - 250)) / 3));
        }

        private ulong Validate(PreparePitchParams parameters)
        {
            if (!ulong.TryParse(parameters.Seed, NumberStyles.None, CultureInfo.InvariantCulture, out var seed))
                throw new SimulationException(SimulationErrorCode.InvalidSeed, "Seed must be an unsigned 64-bit integer: " + parameters.Seed);
            var ratings = new[] { parameters.Pitcher.Stuff, parameters.Pitcher.Command, parameters.Pitcher.Movement,
                parameters.Pitcher.Stamina, parameters.Batter.Contact, parameters.Batter.Discipline, parameters.Batter.Power };
            if (ratings.Any(value => value < 20 || value > 80))
                throw new SimulationException(SimulationErrorCode.InvalidRating, "ratings must be between 20 and 80");
            if (parameters.Pitcher.PitchProfiles != null)
            {
                if (parameters.Pitcher.PitchProfiles.Count == 0 || parameters.Pitcher.PitchProfiles.Select(item => item.PitchType).Distinct().Count() != parameters.Pitcher.PitchProfiles.Count)
                    throw new SimulationException(SimulationErrorCode.InvalidPitchProfile, "pitch profiles must be non-empty and unique");
                foreach (var profile in parameters.Pitcher.PitchProfiles)
                    if (new[] { profile.Control, profile.Command, profile.Movement, profile.Whiff, profile.WeakContact }.Any(value => value < 20 || value > 80) ||
                        profile.VelocityTenthsKph < 1000 || profile.VelocityTenthsKph > 1700 || profile.FatigueCost < 0 || profile.FatigueCost > 3)
                        throw new SimulationException(SimulationErrorCode.InvalidPitchProfile, "pitch profile is outside the valid range");
            }
            if (!ValidZone(parameters.Scouting.HotZone) || !ValidZone(parameters.Scouting.ColdZone) ||
                parameters.Scouting.ChaseTendency < 20 || parameters.Scouting.ChaseTendency > 80 ||
                parameters.Scouting.Reliability < 0 || parameters.Scouting.Reliability > 100)
                throw new SimulationException(SimulationErrorCode.InvalidScouting, "scouting is outside the valid range");
            rivalMemoryEngine.Validate(parameters.RivalMemory, parameters.Pitcher, parameters.Batter);
            gameAnalysisEngine.Validate(parameters.GameLog);
            var context = parameters.Context;
            if (string.IsNullOrEmpty(context.PlateAppearanceId) || context.Inning < 1 || context.Inning > 20 ||
                context.Outs < 0 || context.Outs > 2 || context.Balls < 0 || context.Balls > 3 ||
                context.Strikes < 0 || context.Strikes > 2 || context.PitchNumber < 1 ||
                context.Leverage < 0 || context.Leverage > 1000 || context.Fatigue < 0 || context.Fatigue > 100)
                throw new SimulationException(SimulationErrorCode.InvalidPlateAppearance, "plate appearance is outside the valid range");
            return seed;
        }

        private static void ValidateCall(PitchCall call, PitcherSnapshot pitcher)
        {
            if (!ValidZone(call.Zone)) throw new SimulationException(SimulationErrorCode.InvalidZone, "zone must be in the 3x3 grid");
            if (pitcher.PitchProfiles != null && pitcher.Profile(call.PitchType) == null)
                throw new SimulationException(SimulationErrorCode.InvalidPitchProfile, "pitch is not in the repertoire");
        }
        private static void ValidateDelivery(PitchDelivery? delivery)
        {
            if (delivery.HasValue && (delivery.Value.ReleaseAccuracy < 0 || delivery.Value.ReleaseAccuracy > 1000 ||
                delivery.Value.AimAccuracy < 0 || delivery.Value.AimAccuracy > 1000))
                throw new SimulationException(SimulationErrorCode.InvalidPitchDelivery, "release and aim accuracy must be between 0 and 1000");
        }
        private static bool ValidZone(PitchZone zone) => zone.Row >= 0 && zone.Row <= 2 && zone.Column >= 0 && zone.Column <= 2;

        private BatterPlan CommitBatterPlan(PreparePitchParams parameters, RivalAdaptationSnapshot adaptation, ulong seed)
        {
            var generator = new SplitMix64(DerivedSeed(seed, 0x504C414EUL, parameters.Context.PitchNumber));
            var weights = new[]
            {
                new KeyValuePair<PitchType, int>(PitchType.FourSeam, 340),
                new KeyValuePair<PitchType, int>(PitchType.Slider, 260),
                new KeyValuePair<PitchType, int>(PitchType.Changeup, 200),
                new KeyValuePair<PitchType, int>(PitchType.Curveball, 200)
            };
            var total = 0;
            for (var index = 0; index < weights.Length; index++)
            {
                var weight = weights[index].Value + (weights[index].Key == adaptation.LeanPitch ? adaptation.PitchReadStrength * 2 : 0);
                weights[index] = new KeyValuePair<PitchType, int>(weights[index].Key, weight); total += weight;
            }
            var roll = generator.NextInt(total); var expectedPitch = PitchType.FourSeam;
            foreach (var candidate in weights)
            {
                if (roll < candidate.Value) { expectedPitch = candidate.Key; break; }
                roll -= candidate.Value;
            }
            PitchZone expectedZone;
            if (adaptation.ZoneReadStrength > 0 && generator.NextInt(100) < Math.Min(60, 12 + adaptation.ZoneReadStrength / 6))
                expectedZone = adaptation.LeanZone;
            else if (generator.NextInt(100) < 45) expectedZone = parameters.Scouting.HotZone;
            else expectedZone = new PitchZone(generator.NextInt(3), generator.NextInt(3));
            BatterApproach approach;
            if (parameters.Context.Strikes == 2) approach = BatterApproach.Protect;
            else if (parameters.Context.Balls == 3) approach = BatterApproach.Patient;
            else approach = generator.NextInt(100) < 55 ? BatterApproach.Aggressive : BatterApproach.Power;
            var bias = SituationalBiasFor(parameters.Context,
                parameters.GameState == null ? BaserunnerStateSnapshot.Empty : parameters.GameState.Runners,
                parameters.Batter.Discipline);
            var commitment = StableHash.Fnv1A64(string.Join("|", new[]
            {
                parameters.Context.PlateAppearanceId, parameters.Context.PitchNumber.ToString(), expectedPitch.Value(),
                expectedZone.Row.ToString(), expectedZone.Column.ToString(), ApproachValue(approach), bias.ZoneSwing.ToString(),
                bias.Chase.ToString(), bias.Contact.ToString(), bias.Foul.ToString(), generator.Next().ToString()
            }));
            return new BatterPlan(expectedPitch, expectedZone, approach, bias, commitment);
        }

        private static SituationalBias SituationalBiasFor(PlateAppearanceContext context,
            BaserunnerStateSnapshot runners, int discipline)
        {
            var scoring = runners.SecondOccupied || runners.ThirdOccupied;
            var driveIn = scoring && context.Outs < 2; var patient = runners.OccupiedCount == 0 && context.Leverage < 400;
            var zone = 0; var chase = 0; var contact = 0; var foul = 0;
            if (driveIn) { zone += 40; chase += 20; contact += 25; foul += 35; }
            if (patient) { zone -= 30; chase -= 40; }
            if (context.Strikes == 2) { foul += 100; contact -= 45; }
            else if (context.Balls >= 3 || (context.Balls == 2 && context.Strikes == 0)) { zone += 35; contact += 55; foul -= 25; }
            chase -= (discipline - 50) * Math.Max(0, context.Leverage - 500) / 250;
            var note = context.Strikes == 2 ? "몰린 타자가 배트를 짧게 잡습니다 — 커트를 노립니다." :
                context.Balls >= 3 ? "앞선 카운트라 타자가 스트라이크를 노리고 들어옵니다." :
                driveIn ? "득점권이라 타자가 컨택 위주로 적극적입니다." : patient ?
                "주자가 없어 타자가 공을 신중히 고릅니다." : context.Leverage >= 750 ?
                "중요한 승부라 타자의 집중력이 올라갑니다." : string.Empty;
            return new SituationalBias(zone, chase, contact, foul, note);
        }

        private string PreparationToken(PreparePitchParams parameters, string planCommitment,
            CatcherRecommendation primary, CatcherRecommendation alternative)
        {
            return StableHash.Fnv1A64(string.Join("|", new[]
            {
                "pitch-preparation-v1", parameters.Seed, parameters.Context.PlateAppearanceId,
                parameters.Context.Revision.ToString(), parameters.Context.PitchNumber.ToString(),
                parameters.Context.Balls.ToString(), parameters.Context.Strikes.ToString(), Canonical(parameters.Pitcher),
                Canonical(parameters.RivalMemory), Canonical(parameters.GameState), Canonical(parameters.GameLog),
                planCommitment, Canonical(primary.Call), Canonical(alternative.Call)
            }));
        }

        private PitchExecution ExecutePitch(SubmitPitchParams parameters, PitchDelivery? delivery, ulong seed)
        {
            var generator = new SplitMix64(DerivedSeed(seed, 0x45584543UL, parameters.Context.PitchNumber));
            var target = TargetCoordinates(parameters.Call); var effect = PitchAbilityRules.Intensity(parameters.Call.Intensity);
            var profile = parameters.Pitcher.Profile(parameters.Call.PitchType);
            var command = PitchAbilityRules.CommandRating(parameters.Pitcher, profile);
            var effective = Clamp(command * 10 - parameters.Context.Fatigue * 2 - effect.CommandPenalty, 100, 900);
            var spread = Clamp(520 - effective / 2, 70, 470);
            var offsetX = generator.NextInt(spread * 2 + 1) - spread;
            var offsetY = generator.NextInt(spread * 2 + 1) - spread;
            var wildChance = Clamp(8 + parameters.Context.Fatigue / 10 + (parameters.Call.Intensity == PitchIntensity.MaxEffort ? 2 : 0) -
                (command - 50) / 4, 3, 20);
            if (generator.NextInt(100) < wildChance)
            {
                var wild = 240 + generator.NextInt(321);
                if (generator.NextInt(2) == 0) offsetX += generator.NextInt(2) == 0 ? -wild : wild;
                else offsetY += generator.NextInt(2) == 0 ? -wild : wild;
            }
            var aimShift = (delivery.HasValue ? delivery.Value.AimAccuracy : 500) - 500;
            var releaseShift = (delivery.HasValue ? delivery.Value.ReleaseAccuracy : 500) - 500;
            var aimScale = 1000 - (aimShift >= 0 ? aimShift * 240 : aimShift * 340) / 500;
            offsetX = offsetX * aimScale / 1000; offsetY = offsetY * aimScale / 1000;
            var releaseBonus = releaseShift >= 0 ? releaseShift * 120 / 500 : releaseShift * 200 / 500;
            var perfect = delivery.HasValue && delivery.Value.IsPerfectRelease;
            var quality = Clamp(1000 - Math.Abs(offsetX) - Math.Abs(offsetY) + effective / 5 + releaseBonus + (perfect ? 90 : 0), 0, 1000);
            int horizontal, vertical;
            switch (parameters.Call.PitchType)
            {
                case PitchType.FourSeam: horizontal = 70; vertical = 160; break;
                case PitchType.Slider: horizontal = -145; vertical = 35; break;
                case PitchType.Curveball: horizontal = -65; vertical = -185; break;
                default: horizontal = 105; vertical = -45; break;
            }
            var velocity = PitchAbilityRules.NominalVelocity(parameters.Pitcher, parameters.Call.PitchType,
                parameters.Call.Intensity, parameters.Context.Fatigue) + generator.NextInt(21) - 10 +
                releaseShift * 10 / 500 + (perfect ? 6 : 0);
            var movementScale = (profile == null ? parameters.Pitcher.Movement : profile.Movement) - 50;
            var actualX = target.X + offsetX; var actualY = target.Y + offsetY;
            horizontal += movementScale * 2; vertical += movementScale * 2;
            var releaseSpeed = velocity / 36.0; const double drag = 0.0053;
            var seconds = (Math.Exp(drag * 18.44) - 1.0) / (drag * releaseSpeed);
            var flightMs = Clamp((int)Math.Round(seconds * 1000.0, MidpointRounding.AwayFromZero), 330, 620);
            var plateLateral = actualX * 432.0 / 500.0 / 1000.0;
            var plateHeight = (750.0 + actualY * 250.0 / 500.0) / 1000.0;
            var duration = flightMs / 1000.0; var horizontalMeters = horizontal / 1000.0; var verticalMeters = vertical / 1000.0;
            var initialLateral = (plateLateral - horizontalMeters) / duration;
            var initialVertical = (plateHeight - verticalMeters - 1.85 + 0.5 * 9.81 * duration * duration) / duration;
            var trajectory = new List<int>(100);
            for (var index = 0; index <= 24; index++)
            {
                var progress = index / 24.0; var elapsed = duration * progress;
                var travelled = Math.Log(1.0 + drag * releaseSpeed * elapsed) / (drag * 18.44);
                var magnus = progress * progress;
                var lateral = initialLateral * elapsed + horizontalMeters * magnus;
                var height = 1.85 + initialVertical * elapsed - 0.5 * 9.81 * elapsed * elapsed + verticalMeters * magnus;
                trajectory.Add(flightMs * index / 24);
                trajectory.Add((int)Math.Round(lateral * 1000.0, MidpointRounding.AwayFromZero));
                trajectory.Add((int)Math.Round(18440.0 * (1.0 - travelled), MidpointRounding.AwayFromZero));
                trajectory.Add((int)Math.Round(height * 1000.0, MidpointRounding.AwayFromZero));
            }
            const int controlOffset = 60;
            var controlX = (int)Math.Round(trajectory[controlOffset + 1] * 500.0 / 432.0, MidpointRounding.AwayFromZero);
            var controlY = (int)Math.Round((trajectory[controlOffset + 3] - 750.0) * 500.0 / 250.0, MidpointRounding.AwayFromZero);
            return new PitchExecution(target.X, target.Y, actualX, actualY, velocity, horizontal, vertical,
                quality, flightMs, controlX, controlY, trajectory);
        }

        private Resolution ResolvePitch(SubmitPitchParams parameters, BatterPlan plan, PitchExecution execution,
            bool wasInZone, RivalAdaptationSnapshot adaptation, ulong seed)
        {
            var generator = new SplitMix64(DerivedSeed(seed, 0x5245534FUL, parameters.Context.PitchNumber));
            var pitchMatched = plan.ExpectedPitch == parameters.Call.PitchType; var zoneMatched = ZonesNear(plan.ExpectedZone, parameters.Call.Zone);
            var landed = new PitchZone(execution.ActualY >= 165 ? 0 : execution.ActualY <= -165 ? 2 : 1,
                execution.ActualX <= -165 ? 0 : execution.ActualX >= 165 ? 2 : 1);
            var weakness = parameters.Call.PitchType == parameters.Scouting.PitchWeakness;
            var strength = parameters.Call.PitchType == parameters.Scouting.PitchStrength;
            var cold = wasInZone && landed == parameters.Scouting.ColdZone; var hot = wasInZone && landed == parameters.Scouting.HotZone;
            var hasRunner = parameters.GameState != null && parameters.GameState.Runners.OccupiedCount > 0;
            var traitFired = parameters.Trait.HasValue && parameters.Trait.Value.Fires(parameters.Context.Strikes, parameters.Context.PitchNumber, hasRunner);
            var scoutingContact = (weakness ? -30 : 0) + (strength ? 26 : 0) + (cold ? -22 : 0) + (hot ? 24 : 0) +
                (traitFired ? parameters.Trait.Value.ContactAdjustment() : 0);
            var scoutingQuality = (weakness ? -36 : 0) + (strength ? 32 : 0) + (cold ? -28 : 0) + (hot ? 29 : 0) +
                (traitFired ? parameters.Trait.Value.QualityAdjustment() : 0);
            var capped = Math.Min(RivalMemoryEngine.ResolveDamageCap, adaptation.Level);
            var recognition = (pitchMatched ? 95 : -65) + (zoneMatched ? 70 : -35) +
                (pitchMatched ? capped / 6 : 0) + (zoneMatched ? capped / 10 : 0);
            var approachSwing = plan.Approach == BatterApproach.Patient ? -150 : plan.Approach == BatterApproach.Aggressive ? 120 :
                plan.Approach == BatterApproach.Protect ? 80 : 35;
            var swingChance = Clamp((wasInZone ? 640 : 110) + parameters.Scouting.ChaseTendency * (wasInZone ? 1 : 4) -
                parameters.Batter.Discipline * 2 + recognition + approachSwing + (wasInZone ? plan.Bias.ZoneSwing : plan.Bias.Chase), 25, 960);
            if (generator.NextInt(1000) >= swingChance)
            {
                if (!wasInZone && IsHitByPitch(parameters.Call, execution, parameters.Pitcher.ThrowingHand,
                    parameters.Batter.BatSide, ref generator)) return new Resolution(PitchOutcome.HitByPitch, null);
                return new Resolution(wasInZone ? PitchOutcome.CalledStrike : PitchOutcome.Ball, null);
            }
            var profile = parameters.Pitcher.Profile(parameters.Call.PitchType);
            var difficulty = profile == null ? (parameters.Pitcher.Stuff - 50) * 6 + (parameters.Pitcher.Movement - 50) * 5 +
                Math.Max(0, execution.ExecutionQuality - 500) / 2 :
                (parameters.Pitcher.Stuff - 50) * 3 + (profile.Whiff - 50) * 3 + (parameters.Pitcher.Movement - 50) * 2 +
                (profile.Movement - 50) * 2 + Math.Max(0, execution.ExecutionQuality - 500) / 2;
            var velocityEdge = Clamp((execution.VelocityTenthsKph - 1370) / 2, -80, 180);
            var speedGap = parameters.Context.PitchNumber > 1 && parameters.GameLog != null &&
                parameters.GameLog.Entries.LastOrDefault() != null && parameters.GameLog.Entries.Last().VelocityTenthsKph.HasValue
                ? Math.Min(70, Math.Max(0, Math.Abs(execution.VelocityTenthsKph - parameters.GameLog.Entries.Last().VelocityTenthsKph.Value) - 80) / 3) : 0;
            var fastball = parameters.Call.PitchType == PitchType.FourSeam;
            var heightMatch = fastball && landed.Row == 0 ? 55 : fastball && landed.Row == 2 ? -30 :
                !fastball && landed.Row == 2 ? 50 : !fastball && landed.Row == 0 ? -55 : 0;
            var platoon = PlatoonContactBonus(parameters.Pitcher.ThrowingHand, parameters.Batter.BatSide, parameters.Call.PitchType);
            var contactChance = Clamp(790 + (parameters.Batter.Contact - 50) * 6 + (pitchMatched ? 90 : -70) +
                (zoneMatched ? 50 : -35) + (pitchMatched ? capped / 5 : 0) + plan.Bias.Contact + platoon + scoutingContact -
                (difficulty + velocityEdge + speedGap + heightMatch), 120, 940);
            if (generator.NextInt(1000) >= contactChance) return new Resolution(PitchOutcome.SwingingStrike, null);
            var foulChance = Clamp(470 + ((profile == null ? parameters.Pitcher.Movement : profile.Movement) - parameters.Batter.Contact) * 3 + plan.Bias.Foul, 260, 620);
            if (generator.NextInt(1000) < foulChance) return new Resolution(PitchOutcome.Foul, null);
            var contactQuality = Clamp(455 + (parameters.Batter.Power - 50) * 3 + (parameters.Batter.Contact - 50) * 2 +
                (pitchMatched ? 90 : -70) + (zoneMatched ? 45 : -35) + (pitchMatched ? capped / 8 : 0) -
                ((profile == null ? 50 : profile.WeakContact) - 50) * 2 - Math.Max(0, execution.ExecutionQuality - 500) / 3 +
                scoutingQuality - Math.Max(0, execution.VelocityTenthsKph - 1400) / 5 - heightMatch / 2 + generator.NextInt(301) - 150, 0, 1000);
            var pull = PullShift(parameters.Batter.BatSide, landed.Column);
            var exitVelocity = Clamp(1000 + contactQuality * 3 / 4 + (parameters.Batter.Power - 50) * 6 + generator.NextInt(181) - 90, 700, 1900);
            var launchAngle = Clamp(-100 + generator.NextInt(521) + (contactQuality - 450) / 8 + (1 - landed.Row) * 55, -150, 520);
            var quality = BattedQuality(exitVelocity, launchAngle);
            var ball = new BattedBall(exitVelocity, launchAngle,
                -450 + Math.Max(0, pull) + generator.NextInt(901 - Math.Abs(pull)), quality);
            return new Resolution(BattedBallBands.Outcome(quality), ball);
        }

        private static bool BatsLeft(BatSide batSide, ThrowingHand hand) =>
            batSide == BatSide.Left || (batSide == BatSide.Switch && hand == ThrowingHand.Right);

        private static int PlatoonContactBonus(ThrowingHand hand, BatSide batSide, PitchType type)
        {
            var sameHand = BatsLeft(batSide, hand) == (hand == ThrowingHand.Left);
            if (sameHand) return 0;
            return type == PitchType.Slider || type == PitchType.Curveball ? 42 : type == PitchType.FourSeam ? 24 : 14;
        }

        private static bool IsHitByPitch(PitchCall call, PitchExecution execution, ThrowingHand hand,
            BatSide batSide, ref SplitMix64 generator)
        {
            var batsLeft = BatsLeft(batSide, hand); var insideMiss = batsLeft ? execution.ActualX : -execution.ActualX;
            if (insideMiss < 1000) return false;
            var calledInside = batsLeft ? call.Zone.Column == 2 : call.Zone.Column == 0;
            return generator.NextInt(1000) < 120 + (calledInside ? 60 : 0);
        }

        private static CountAdvance AdvanceCount(PlateAppearanceContext context, PitchOutcome outcome)
        {
            switch (outcome)
            {
                case PitchOutcome.Ball: return context.Balls == 3
                    ? new CountAdvance(3, context.Strikes, PlateAppearanceResult.Walk)
                    : new CountAdvance(context.Balls + 1, context.Strikes, null);
                case PitchOutcome.CalledStrike:
                case PitchOutcome.SwingingStrike: return context.Strikes == 2
                    ? new CountAdvance(context.Balls, 2, PlateAppearanceResult.Strikeout)
                    : new CountAdvance(context.Balls, context.Strikes + 1, null);
                case PitchOutcome.Foul: return new CountAdvance(context.Balls, Math.Min(2, context.Strikes + 1), null);
                case PitchOutcome.InPlayOut: return new CountAdvance(context.Balls, context.Strikes, PlateAppearanceResult.InPlayOut);
                case PitchOutcome.Single:
                case PitchOutcome.Double:
                case PitchOutcome.Triple:
                case PitchOutcome.HomeRun: return new CountAdvance(context.Balls, context.Strikes, PlateAppearanceResult.Hit);
                case PitchOutcome.HitByPitch: return new CountAdvance(context.Balls, context.Strikes, PlateAppearanceResult.Walk);
                default: throw new ArgumentOutOfRangeException(nameof(outcome));
            }
        }

        private static SelectionQuality SelectionQualityFor(PitchCall call, PitcherSnapshot pitcher,
            BatterScoutingSnapshot scouting, PlateAppearanceContext context, RivalAdaptationSnapshot adaptation)
        {
            var score = 500 + (call.PitchType == scouting.PitchWeakness ? 170 : 0) -
                (call.PitchType == scouting.PitchStrength ? 190 : 0) + (call.Zone == scouting.ColdZone ? 130 : 0) -
                (call.Zone == scouting.HotZone ? 170 : 0) + (context.Strikes == 2 && call.ZoneIntent == ZoneIntent.Chase ? 90 : 0) -
                (context.Balls == 3 && call.ZoneIntent == ZoneIntent.Chase ? 260 : 0) -
                (context.Fatigue >= 60 && call.Intensity == PitchIntensity.MaxEffort ? 140 : 0) +
                (call.ZoneIntent == ZoneIntent.Edge ? 35 : 0);
            var profile = pitcher.Profile(call.PitchType);
            if (profile != null)
            {
                score += profile.Role == PitchUsageRole.Primary ? 45 : profile.Role == PitchUsageRole.Development ? -120 : 0;
                if (call.ZoneIntent == ZoneIntent.Edge) score += (profile.Command - 50) * 3;
                if (call.ZoneIntent == ZoneIntent.Chase) score += (profile.Whiff - 50) * 2;
            }
            if (adaptation.DetectedPitch == call.PitchType) score -= adaptation.Level / 3;
            if (adaptation.DetectedZone.HasValue && adaptation.DetectedZone.Value == call.Zone) score -= adaptation.Level / 5;
            return score < 340 ? SelectionQuality.Poor : score < 540 ? SelectionQuality.Risky :
                score < 740 ? SelectionQuality.Good : SelectionQuality.Excellent;
        }

        private static (int X, int Y) TargetCoordinates(PitchCall call)
        {
            var x = (call.Zone.Column - 1) * 330; var y = (1 - call.Zone.Row) * 330;
            if (call.ZoneIntent == ZoneIntent.Strike) { x = x * 7 / 10; y = y * 7 / 10; }
            else if (call.ZoneIntent == ZoneIntent.Chase)
            {
                if (Math.Abs(x) >= Math.Abs(y) && x != 0) x = x > 0 ? 650 : -650;
                else if (y != 0) y = y > 0 ? 650 : -650;
                else y = -650;
            }
            return (x, y);
        }

        private static CatcherRecommendationSnapshot RecommendationSnapshot(CatcherRecommendation recommendation, string situationNote)
        {
            var reason = recommendation.ReasonCodes.Contains("rival.pattern_detected") ? "라이벌이 반복 구종을 읽고 있어 패턴을 바꿉니다." :
                recommendation.ReasonCodes.Contains("sequence.avoid_repeat") ? "방금 공과 다른 배합을 요구합니다." :
                recommendation.ReasonCodes.Contains("scouting.pitch_weakness") ? "타자의 약점 구종과 코스를 공략합니다." :
                "강한 코스를 피해 타이밍을 바꿉니다.";
            if (!string.IsNullOrEmpty(situationNote)) reason += " " + situationNote;
            return new CatcherRecommendationSnapshot(recommendation.Call, recommendation.Confidence, recommendation.ReasonCodes, reason);
        }

        private static IReadOnlyList<string> ResolutionReasons(PitchOutcome outcome, bool wasInZone,
            bool pitchMatched, bool zoneMatched, SelectionQuality selection, int executionQuality,
            RivalAdaptationSnapshot adaptation, FieldingResolutionSnapshot fielding)
        {
            var reasons = new List<string>
            {
                "outcome." + outcome.Value(), wasInZone ? "abs.in_zone" : "abs.out_of_zone",
                pitchMatched ? "batter_plan.pitch_matched" : "batter_plan.pitch_missed",
                zoneMatched ? "batter_plan.zone_matched" : "batter_plan.zone_missed",
                "selection." + selection.Value(), executionQuality < 350 ? "execution.missed_target" :
                    executionQuality < 600 ? "execution.location_vulnerable" :
                    executionQuality < 800 ? "execution.near_target" : "execution.precise"
            };
            if (adaptation.DetectedPitch.HasValue || adaptation.DetectedZone.HasValue) reasons.Add("rival.pattern");
            if (fielding != null) reasons.Add("fielding.impact." + fielding.Impact.ToString().ToLowerInvariant());
            return reasons;
        }

        private static string OutcomeFeedback(PitchOutcome outcome)
        {
            switch (outcome)
            {
                case PitchOutcome.Ball: return "타자가 골라내 볼이 됐습니다.";
                case PitchOutcome.CalledStrike: return "심판이 스트라이크를 선언했습니다.";
                case PitchOutcome.SwingingStrike: return "타자의 배트를 끌어내 헛스윙을 만들었습니다.";
                case PitchOutcome.Foul: return "타자가 걷어내 파울이 됐습니다.";
                case PitchOutcome.InPlayOut: return "약한 타구를 유도해 아웃을 만들었습니다.";
                case PitchOutcome.Single: return "타구가 수비 사이를 빠져나가 단타가 됐습니다.";
                case PitchOutcome.Double: return "강한 타구가 외야를 갈라 2루타가 됐습니다.";
                case PitchOutcome.Triple: return "타구가 외야 구석을 완전히 갈라 3루타가 됐습니다.";
                case PitchOutcome.HomeRun: return "정타를 허용해 홈런이 됐습니다.";
                case PitchOutcome.HitByPitch: return "몸에 맞는 공으로 타자가 걸어 나갔습니다.";
                default: return string.Empty;
            }
        }

        private static string ApproachValue(BatterApproach approach) => approach == BatterApproach.Patient ? "patient" :
            approach == BatterApproach.Aggressive ? "aggressive" : approach == BatterApproach.Protect ? "protect" : "power";
        private static bool ZonesNear(PitchZone first, PitchZone second) => Math.Abs(first.Row - second.Row) + Math.Abs(first.Column - second.Column) <= 1;
        private static string DeriveNextSeed(ulong seed) { var generator = new SplitMix64(seed); generator.Next(); return generator.State.ToString(); }
        private static ulong DerivedSeed(ulong seed, ulong domain, int ordinal)
        { var generator = new SplitMix64(unchecked(seed ^ domain ^ ((ulong)ordinal * 0x9E3779B9UL))); return generator.Next(); }
        private static int Clamp(int value, int low, int high) => Math.Min(Math.Max(value, low), high);

        private static string Canonical(PitchCall call) => string.Join(":", call.PitchType.Value(), call.Zone.Row,
            call.Zone.Column, call.ZoneIntent.Value(), call.Intensity.Value());
        private static string Canonical(PitchProfileSnapshot profile) => profile == null ? "legacy" : string.Join(":",
            profile.PitchType.Value(), profile.Role.Value(), profile.VelocityTenthsKph, profile.Control, profile.Command,
            profile.Movement, profile.Whiff, profile.WeakContact, profile.FatigueCost);
        private static string Canonical(PitcherSnapshot pitcher)
        {
            var profiles = pitcher.PitchProfiles == null ? "legacy" : string.Join(",", pitcher.PitchProfiles
                .OrderBy(item => item.PitchType.Value(), StringComparer.Ordinal).Select(Canonical));
            return string.Join(":", pitcher.Id, pitcher.Stuff, pitcher.Command, pitcher.Movement, pitcher.Stamina, profiles);
        }
        private static string Canonical(RivalMemorySnapshot memory)
        {
            if (memory == null) return "no-rival-memory";
            var observations = string.Join(",", memory.RecentObservations.Select(item => string.Join(":",
                item.PitchType.Value(), item.Zone.Row, item.Zone.Column, item.ZoneIntent.Value(), item.Balls,
                item.Strikes, item.Outcome.Value())));
            return string.Join("|", memory.MatchupId, memory.Revision, memory.PlateAppearancesSeen,
                memory.TotalPitchesSeen, observations);
        }
        private static string Canonical(GameStateSnapshot state)
        {
            if (state == null) return "standard-game-state";
            var fielders = state.Defense.Fielders == null ? "aggregate-defense" : string.Join(",", state.Defense.Fielders
                .OrderBy(item => item.Position.ToString(), StringComparer.Ordinal).Select(item => string.Join(":",
                    item.Id, PositionValue(item.Position), item.Range, item.Glove, item.Arm)));
            var inning = state.InningState.HasValue ? string.Join(":", state.InningState.Value.Inning,
                state.InningState.Value.Half == HalfInning.Top ? "top" : "bottom", state.InningState.Value.Outs) : "context-inning";
            return string.Join(":", state.Defense.Infield, state.Defense.Outfield, state.Defense.Arm, fielders,
                state.Park.Id, state.Park.HitFactor, state.Park.HomeRunFactor, state.Runners.FirstOccupied ? "1" : "0",
                state.Runners.SecondOccupied ? "1" : "0", state.Runners.ThirdOccupied ? "1" : "0",
                state.Runners.LeadRunnerSpeed, state.RunsAllowed, inning);
        }
        private static string Canonical(GameLogSnapshot log)
        {
            if (log == null) return "empty-game-log";
            var entries = string.Join(",", log.Entries.Select(item => string.Join(":", item.PitchType.Value(),
                item.WasInZone ? "1" : "0", item.BatterSwung ? "1" : "0", item.Outcome.Value(),
                item.SelectionQuality.Value(), item.ExecutionQuality, item.ContactQuality ?? -1,
                item.ExpectedDamage, item.ActualDamage, item.RecommendationAccepted ? "1" : "0")));
            return string.Join("|", log.GameId, log.Revision, log.TotalPitches, entries);
        }
        private static string PositionValue(FielderPosition position)
        {
            switch (position)
            {
                case FielderPosition.FirstBase: return "first_base";
                case FielderPosition.SecondBase: return "second_base";
                case FielderPosition.ThirdBase: return "third_base";
                case FielderPosition.LeftField: return "left_field";
                case FielderPosition.CenterField: return "center_field";
                case FielderPosition.RightField: return "right_field";
                default: return position.ToString().ToLowerInvariant();
            }
        }
    }
}
