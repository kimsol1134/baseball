using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Random;

namespace Baseball.Core.Pro
{
    public sealed class PitcherLabEngine
    {
        private enum HiddenGrowthTrait { VelocityBody, BreakingLearner, MechanicsResponder, GameTranslator, RecoveryGift, PressureAdapter }

        public PitcherLabResult Start(StartPitcherLabParams parameters)
        {
            var seed = Seed(parameters.Seed);
            var preset = PitcherPresetCatalog.All.FirstOrDefault(value => value.Id == parameters.PresetId);
            if (preset == null) throw Invalid("unknown pitcher preset");
            if (parameters.LifeNumber < 1 || parameters.LifeNumber > 99 || parameters.InheritedSoulPoints < 0 || parameters.InheritedSoulPoints > 20)
                throw Invalid("life number or inherited soul points are invalid");
            var allocation = parameters.CreationAllocation ?? CreationAllocationSnapshot.Balanced;
            if (allocation.Total != 5 || new[] { allocation.Stuff, allocation.Command, allocation.Movement, allocation.Stamina }.Any(value => value < 0 || value > 5))
                throw Invalid("creation allocation must spend exactly five points");
            var runId = "lab-" + parameters.Seed + "-life-" + parameters.LifeNumber;
            var trait = HiddenTrait(runId, seed);
            var playerName = (parameters.PlayerName ?? preset.Pitcher.Name).Trim();
            if (playerName.Length < 1 || playerName.Length > 12) throw Invalid("player name must contain between one and twelve characters");
            var named = new PitcherSnapshot(preset.Pitcher.Id, playerName, preset.Pitcher.Stuff, preset.Pitcher.Command,
                preset.Pitcher.Movement, preset.Pitcher.Stamina, preset.Pitcher.PitchProfiles);
            var pitcher = ApplyCreation(allocation, named);
            pitcher = ApplyInheritance(pitcher, parameters.InheritedSoulPoints, parameters.InheritedSoulDomain, parameters.InheritedMemory);
            var state = new PitcherLabSnapshot
            {
                RunId = runId, Revision = 0, LifeNumber = parameters.LifeNumber, PresetId = parameters.PresetId,
                Phase = PitcherLabPhase.Training, Pitcher = pitcher, TrainingSessionsCompleted = 0,
                RelationshipEventsCompleted = 0, SelectedAwakenings = new AwakeningId[0], AwakeningOptions = new AwakeningId[0],
                Readiness = 72, Fatigue = 8, CatcherTrust = 50, DevelopmentSignals = new DevelopmentSignalsSnapshot(),
                PotentialRanges = PotentialRanges(pitcher, trait, 0, seed), Performance = new LabPerformanceSnapshot(),
                LastTraining = null, ScoutingEvaluation = null, LegacyOptions = new MemoryCardId[0], LegacySelection = null,
                StateCommitment = string.Empty, BalanceVersion = PitcherPresetCatalog.BalanceVersion, FocusStreak = 0
            };
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("pitcher_lab_started", 0) });
        }

        public PitcherLabResult NormalizeBalance(PitcherLabStateParams parameters)
        {
            Seed(parameters.Seed);
            ValidateState(parameters.State);
            var state = parameters.State.Clone();
            state.BalanceVersion = PitcherPresetCatalog.BalanceVersion;
            state.PotentialRanges = PotentialRanges(state.Pitcher, HiddenTrait(state.RunId, RunSeed(state.RunId)), state.TrainingSessionsCompleted, RunSeed(state.RunId));
            if (state.ScoutingEvaluation != null) state.ScoutingEvaluation = ScoutingEvaluation(state);
            Sign(state);
            return new PitcherLabResult(state.Revision, parameters.Seed, new PitcherLabEvent[0], state,
                StableHash.Fnv1A64(state.RunId + "|" + state.Revision + "|balance_normalized|" + state.StateCommitment));
        }

        public PitcherLabResult CommitTraining(CommitTrainingParams parameters)
        {
            var seed = Seed(parameters.Seed);
            Validate(parameters.State, PitcherLabPhase.Training);
            if (parameters.State.TrainingSessionsCompleted >= 6) throw Invalid("all six training sessions are already complete");
            var trait = HiddenTrait(parameters.State.RunId, RunSeed(parameters.State.RunId));
            var sessionNumber = parameters.State.TrainingSessionsCompleted + 1;
            var rng = new SplitMix64(seed ^ 0x545241494E494E47UL ^ (ulong)sessionNumber);
            var intensityBase = parameters.Intensity == TrainingIntensity.Light ? 125 : parameters.Intensity == TrainingIntensity.Standard ? 190 : 255;
            var fatigueCost = parameters.Intensity == TrainingIntensity.Light ? 5 : parameters.Intensity == TrainingIntensity.Standard ? 11 : 20;
            var traitBonus = MatchingFocus(trait) == parameters.Focus ? 135 : 0;
            var readinessModifier = (parameters.State.Readiness - 50) * 2;
            var fatiguePenalty = Math.Max(0, parameters.State.Fatigue - 35) * 2;
            var repeat = parameters.State.LastTraining != null && parameters.State.LastTraining.Focus == parameters.Focus;
            var priorStreak = parameters.State.FocusStreak ?? (parameters.State.LastTraining == null ? 0 : 1);
            var repeatCount = repeat ? priorStreak : 0;
            var repeatModifier = repeatCount == 0 ? 20 : repeatCount == 1 ? 55 : -45;
            var nextStreak = repeat ? priorStreak + 1 : 1;
            var signal = Clamp(intensityBase + traitBonus + readinessModifier - fatiguePenalty + repeatModifier + rng.NextInt(81) - 40, 60, 520);
            var totalSignal = parameters.State.DevelopmentSignals.Value(parameters.Focus) + signal;
            var ratingPoints = totalSignal / 500;
            var signals = parameters.State.DevelopmentSignals.Replacing(parameters.Focus, totalSignal % 500);
            var pitcher = ApplyGrowth(parameters.State.Pitcher, parameters.Focus, ratingPoints);
            var before = Rating(parameters.State.Pitcher, parameters.Focus);
            var after = Rating(pitcher, parameters.Focus);
            var recoveryBonus = parameters.Focus == TrainingFocus.Recovery ? 18 + (trait == HiddenGrowthTrait.RecoveryGift ? 8 : 0) : 0;
            var fatigue = Clamp(parameters.State.Fatigue + fatigueCost - recoveryBonus, 0, 100);
            var readinessCost = parameters.Intensity == TrainingIntensity.Intensive ? 12 : parameters.Intensity == TrainingIntensity.Standard ? 6 : 2;
            var readiness = Clamp(parameters.State.Readiness - readinessCost + (parameters.Focus == TrainingFocus.Recovery ? 16 : 0), 20, 100);
            var reaction = Reaction(signal);
            var training = new TrainingSessionSnapshot(sessionNumber, parameters.Focus, parameters.Intensity, reaction,
                signal, ratingPoints, parameters.State.Readiness, readiness, parameters.State.Fatigue, fatigue,
                Clue(reaction, parameters.Focus), TrainingFeedback(parameters.Focus, reaction, ratingPoints),
                before, after, after - before);
            var phase = sessionNumber == 2 || sessionNumber == 4 ? PitcherLabPhase.ImportantInning :
                sessionNumber == 3 ? PitcherLabPhase.Relationship :
                sessionNumber == 5 || sessionNumber == 6 ? PitcherLabPhase.Awakening : PitcherLabPhase.Training;
            var options = phase == PitcherLabPhase.Awakening ? AwakeningOptions(parameters.State, seed, sessionNumber) : new AwakeningId[0];
            var state = Next(parameters.State);
            state.Phase = phase; state.Pitcher = pitcher; state.TrainingSessionsCompleted = sessionNumber;
            state.AwakeningOptions = options; state.Readiness = readiness; state.Fatigue = fatigue;
            state.DevelopmentSignals = signals; state.PotentialRanges = PotentialRanges(pitcher, trait, sessionNumber, RunSeed(state.RunId));
            state.LastTraining = training; state.FocusStreak = nextStreak;
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("training_session_resolved", 0,
                new[] { "training.focus." + parameters.Focus.Value(), "training.reaction." + ReactionValue(reaction) }, training: training) });
        }

        public PitcherLabResult RecordImportantInning(RecordImportantInningParams parameters)
        {
            var seed = Seed(parameters.Seed);
            Validate(parameters.State, PitcherLabPhase.ImportantInning);
            var expected = parameters.State.Performance.ImportantInningsCompleted + 1;
            var report = parameters.Report;
            if (report.ScenarioNumber != expected || report.Pitches < 1 || report.Pitches > 200 || report.Strikeouts < 0 ||
                report.Walks < 0 || report.RunsAllowed < 0 || report.RunsAllowed > 20 || report.ExpectedDamage < 0 ||
                report.ActualDamage < 0 || report.RecommendationAccepted < 0 || report.RecommendationAccepted > report.Pitches)
                throw Invalid("important inning report is invalid or out of order");
            var state = Next(parameters.State);
            state.Phase = expected == 3 ? PitcherLabPhase.Scouting : PitcherLabPhase.Training;
            state.Readiness = Clamp(parameters.State.Readiness - 8, 20, 100);
            state.Fatigue = Clamp(parameters.State.Fatigue + Math.Max(2, report.Pitches / 4), 0, 100);
            state.Performance = parameters.State.Performance.Adding(report);
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("important_inning_completed", 0,
                new[] { "important_inning." + expected }, importantInning: report) });
        }

        public PitcherLabResult ChooseRelationship(ChooseRelationshipParams parameters)
        {
            var seed = Seed(parameters.Seed);
            Validate(parameters.State, PitcherLabPhase.Relationship);
            if (parameters.State.RelationshipEventsCompleted >= 2) throw Invalid("both catcher relationship events are complete");
            var eventNumber = parameters.State.RelationshipEventsCompleted + 1;
            var change = parameters.Choice == RelationshipChoice.TrustCatcher ? 12 : -7;
            var trust = Clamp(parameters.State.CatcherTrust + change, 0, 100);
            var state = Next(parameters.State);
            state.Phase = PitcherLabPhase.Training; state.RelationshipEventsCompleted = eventNumber; state.CatcherTrust = trust;
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("catcher_relationship_changed", 0,
                new[] { "catcher.trust." + (change >= 0 ? "up" : "down") }, relationshipChoice: parameters.Choice,
                catcherTrustBefore: parameters.State.CatcherTrust, catcherTrustAfter: trust,
                catcherTrustChangeApplied: trust - parameters.State.CatcherTrust) });
        }

        public PitcherLabResult ChooseAwakening(ChooseAwakeningParams parameters)
        {
            var seed = Seed(parameters.Seed);
            Validate(parameters.State, PitcherLabPhase.Awakening);
            if (!parameters.State.AwakeningOptions.Contains(parameters.Awakening) || parameters.State.SelectedAwakenings.Contains(parameters.Awakening) || parameters.State.SelectedAwakenings.Count >= 2)
                throw Invalid("awakening is not currently available");
            var awakenings = parameters.State.SelectedAwakenings.Concat(new[] { parameters.Awakening }).ToArray();
            var state = Next(parameters.State);
            state.Phase = awakenings.Length == 1 ? PitcherLabPhase.Relationship : PitcherLabPhase.ImportantInning;
            state.Pitcher = ApplyAwakening(parameters.Awakening, parameters.State.Pitcher);
            state.SelectedAwakenings = awakenings; state.AwakeningOptions = new AwakeningId[0];
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("awakening_granted", 0,
                new[] { "awakening." + parameters.Awakening.Value() }, awakening: parameters.Awakening) });
        }

        public PitcherLabResult FinalizeScouting(FinalizeScoutingParams parameters)
        {
            var seed = Seed(parameters.Seed);
            Validate(parameters.State, PitcherLabPhase.Scouting);
            if (parameters.State.Performance.ImportantInningsCompleted != 3) throw Invalid("three important innings are required");
            var evaluation = ScoutingEvaluation(parameters.State);
            var options = MemoryOptions(parameters.State, seed);
            var state = Next(parameters.State);
            state.Phase = PitcherLabPhase.Reflection; state.ScoutingEvaluation = evaluation; state.LegacyOptions = options;
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("scouting_evaluation_completed", 0,
                new[] { "scouting.grade." + ScoutingValue(evaluation.Grade) }, scouting: evaluation) });
        }

        public PitcherLabResult SelectLegacy(SelectLegacyParams parameters)
        {
            var seed = Seed(parameters.Seed);
            Validate(parameters.State, PitcherLabPhase.Reflection);
            if (!parameters.State.LegacyOptions.Contains(parameters.MemoryCard)) throw Invalid("memory card is not currently available");
            var legacy = new LegacySelectionSnapshot(parameters.SoulDomain, parameters.MemoryCard, 2,
                parameters.State.LifeNumber == 1 ? "school-data-lab" : "school-river-tech",
                parameters.State.LifeNumber == 1 ? "coach-analyst-han" : "coach-mechanics-kim",
                SoulLabel(parameters.SoulDomain) + " 훈련으로 얻은 능력과 ‘" + MemoryLabel(parameters.MemoryCard) + "’을 다음 선수에게 넘깁니다.");
            var state = Next(parameters.State);
            state.Phase = PitcherLabPhase.Completed; state.LegacySelection = legacy;
            Sign(state);
            return MakeResult(seed, state, new[] { new PitcherLabEvent("life_completed", 0,
                new[] { "soul." + SoulValue(parameters.SoulDomain), "memory." + parameters.MemoryCard.Value() }, legacy: legacy) });
        }

        public string Commitment(PitcherLabSnapshot state)
        {
            var profile = state.Pitcher.PitchProfiles == null ? "none" : string.Join(",", state.Pitcher.PitchProfiles.Select(value =>
                value.PitchType.Value() + ":" + value.VelocityTenthsKph + ":" + value.Control + ":" + value.Command + ":" + value.Movement + ":" + value.Whiff + ":" + value.FatigueCost));
            var ratings = state.Pitcher.Stuff + ":" + state.Pitcher.Command + ":" + state.Pitcher.Movement + ":" + state.Pitcher.Stamina;
            var signals = state.DevelopmentSignals.Velocity + ":" + state.DevelopmentSignals.Command + ":" + state.DevelopmentSignals.BreakingBall + ":" + state.DevelopmentSignals.Stamina + ":" + state.DevelopmentSignals.Recovery + ":" + state.DevelopmentSignals.GamePlanning;
            var performance = state.Performance.ImportantInningsCompleted + ":" + state.Performance.Pitches + ":" + state.Performance.Strikeouts + ":" + state.Performance.Walks + ":" + state.Performance.RunsAllowed + ":" + state.Performance.ExpectedDamage + ":" + state.Performance.ActualDamage + ":" + state.Performance.RecommendationAccepted;
            var potential = string.Join(",", state.PotentialRanges.Select(value => value.Metric + ":" + value.Current + ":" + value.LowerBound + ":" + value.UpperBound + ":" + value.Confidence));
            var last = "no-training";
            if (state.LastTraining != null)
            {
                var value = state.LastTraining;
                last = value.SessionNumber + ":" + value.Focus.Value() + ":" + IntensityValue(value.Intensity) + ":" + ReactionValue(value.Reaction) + ":" + value.SignalGained + ":" + value.RatingPointsGained + ":" + value.ReadinessAfter + ":" + value.FatigueAfter;
                if (value.RatingBefore.HasValue && value.RatingAfter.HasValue && value.RatingPointsApplied.HasValue)
                    last += ":rating:" + value.RatingBefore.Value + ":" + value.RatingAfter.Value + ":" + value.RatingPointsApplied.Value;
            }
            var scouting = state.ScoutingEvaluation == null ? "no-scouting" : ScoutingValue(state.ScoutingEvaluation.Grade) + ":" + state.ScoutingEvaluation.Score;
            var legacy = state.LegacySelection == null ? "no-legacy" : SoulValue(state.LegacySelection.SoulDomain) + ":" + state.LegacySelection.MemoryCard.Value();
            var canonical = new List<string>
            {
                state.RunId, state.Revision.ToString(), state.LifeNumber.ToString(), state.PresetId, PhaseValue(state.Phase),
                state.TrainingSessionsCompleted.ToString(), state.RelationshipEventsCompleted.ToString(),
                string.Join(",", state.SelectedAwakenings.Select(value => value.Value())),
                string.Join(",", state.AwakeningOptions.Select(value => value.Value())), state.Readiness.ToString(),
                state.Fatigue.ToString(), state.CatcherTrust.ToString(), ratings, profile, signals, potential, last,
                performance, scouting, string.Join(",", state.LegacyOptions.Select(value => value.Value())), legacy
            };
            if (state.BalanceVersion.HasValue) canonical.Add("balance_version:" + state.BalanceVersion.Value);
            if (state.FocusStreak.HasValue) canonical.Add("focus_streak:" + state.FocusStreak.Value);
            return StableHash.Fnv1A64(string.Join("|", canonical));
        }

        private static HiddenGrowthTrait HiddenTrait(string runId, ulong seed)
        {
            var rng = new SplitMix64(seed ^ StableHash.Fnv1A64Value(runId) ^ 0x47524F575448UL);
            return (HiddenGrowthTrait)rng.NextInt(Enum.GetValues(typeof(HiddenGrowthTrait)).Length);
        }
        private static TrainingFocus MatchingFocus(HiddenGrowthTrait trait)
        {
            switch (trait)
            {
                case HiddenGrowthTrait.VelocityBody: return TrainingFocus.Velocity;
                case HiddenGrowthTrait.BreakingLearner: return TrainingFocus.BreakingBall;
                case HiddenGrowthTrait.MechanicsResponder: return TrainingFocus.Command;
                case HiddenGrowthTrait.GameTranslator: return TrainingFocus.GamePlanning;
                case HiddenGrowthTrait.RecoveryGift: return TrainingFocus.Recovery;
                default: return TrainingFocus.Stamina;
            }
        }
        private static ulong RunSeed(string runId)
        { var values = runId.Split('-'); ulong seed; return values.Length >= 2 && ulong.TryParse(values[1], out seed) ? seed : 0; }
        private static IReadOnlyList<PotentialRangeSnapshot> PotentialRanges(PitcherSnapshot pitcher, HiddenGrowthTrait trait, int sessions, ulong seed)
        {
            var rows = new[]
            {
                new { Focus = TrainingFocus.Velocity, Metric = "stuff", Current = pitcher.Stuff },
                new { Focus = TrainingFocus.Command, Metric = "command", Current = pitcher.Command },
                new { Focus = TrainingFocus.BreakingBall, Metric = "movement", Current = pitcher.Movement },
                new { Focus = TrainingFocus.Stamina, Metric = "stamina", Current = pitcher.Stamina }
            };
            return rows.Select((entry, index) =>
            {
                var rng = new SplitMix64(seed ^ (ulong)(index + 1) ^ 0x504F54454E54UL);
                var traitBonus = MatchingFocus(trait) == entry.Focus ? 8 : 0;
                var uncertainty = Math.Max(3, 9 - sessions);
                var center = Clamp(entry.Current + 8 + traitBonus + rng.NextInt(7), 20, 80);
                return new PotentialRangeSnapshot(entry.Metric, entry.Current, Clamp(entry.Current + 2, 20, 80),
                    Clamp(center + uncertainty / 2, 20, 80), Clamp(280 + sessions * 90, 0, 900));
            }).ToArray();
        }
        private static TrainingReactionBand Reaction(int signal)
        { return signal < 160 ? TrainingReactionBand.Muted : signal < 270 ? TrainingReactionBand.Steady : signal < 390 ? TrainingReactionBand.Strong : TrainingReactionBand.Breakthrough; }
        private static string Clue(TrainingReactionBand reaction, TrainingFocus focus)
        {
            if (reaction == TrainingReactionBand.Muted) return "몸이 자극을 받아들이는 데 시간이 더 필요해 보입니다.";
            if (reaction == TrainingReactionBand.Steady) return "반복할수록 같은 동작을 이어 가는 힘이 좋아집니다.";
            if (reaction == TrainingReactionBand.Strong) return FocusLabel(focus) + " 훈련에서 동작이 예상보다 빠르게 안정됐습니다.";
            return "코치가 같은 훈련을 계속하자고 할 만큼 동작이 빠르게 좋아졌습니다.";
        }
        private static string TrainingFeedback(TrainingFocus focus, TrainingReactionBand reaction, int points)
        {
            return FocusLabel(focus) + " 훈련 효과가 " + ReactionLabel(reaction) + " 편이었습니다." +
                (points > 0 ? " 실제 능력치가 " + points + "포인트 상승했습니다." : " 능력치는 그대로지만 다음 상승까지 훈련량이 쌓였습니다.");
        }
        private static PitcherSnapshot ApplyGrowth(PitcherSnapshot pitcher, TrainingFocus focus, int points)
        {
            if (points <= 0) return pitcher;
            IReadOnlyList<PitchProfileSnapshot> profiles = null;
            if (pitcher.PitchProfiles != null)
                profiles = pitcher.PitchProfiles.Select(profile => new PitchProfileSnapshot(profile.PitchType, profile.Role,
                    Clamp(profile.VelocityTenthsKph + (focus == TrainingFocus.Velocity ? points * 5 : 0), 1000, 1700),
                    Clamp(profile.Control + (focus == TrainingFocus.Command ? points : 0), 20, 80),
                    Clamp(profile.Command + (focus == TrainingFocus.Command || focus == TrainingFocus.GamePlanning ? points : 0), 20, 80),
                    Clamp(profile.Movement + (focus == TrainingFocus.BreakingBall && profile.PitchType != PitchType.FourSeam ? points * 2 : 0), 20, 80),
                    Clamp(profile.Whiff + (focus == TrainingFocus.BreakingBall && profile.PitchType != PitchType.FourSeam ? points : 0), 20, 80),
                    profile.WeakContact, focus == TrainingFocus.Stamina && points > 1 ? Math.Max(0, profile.FatigueCost - 1) : profile.FatigueCost)).ToArray();
            return new PitcherSnapshot(pitcher.Id, pitcher.Name,
                Clamp(pitcher.Stuff + (focus == TrainingFocus.Velocity ? points : 0), 20, 80),
                Clamp(pitcher.Command + (focus == TrainingFocus.Command || focus == TrainingFocus.GamePlanning ? points : 0), 20, 80),
                Clamp(pitcher.Movement + (focus == TrainingFocus.BreakingBall ? points : 0), 20, 80),
                Clamp(pitcher.Stamina + (focus == TrainingFocus.Stamina || focus == TrainingFocus.Recovery ? points : 0), 20, 80), profiles);
        }
        private static int Rating(PitcherSnapshot pitcher, TrainingFocus focus)
        { return focus == TrainingFocus.Velocity ? pitcher.Stuff : focus == TrainingFocus.BreakingBall ? pitcher.Movement : focus == TrainingFocus.Stamina || focus == TrainingFocus.Recovery ? pitcher.Stamina : pitcher.Command; }
        private static PitcherSnapshot ApplyInheritance(PitcherSnapshot pitcher, int points, SoulDomain? domain, MemoryCardId? memory)
        {
            if (points <= 0 && !memory.HasValue) return pitcher;
            var focus = domain == SoulDomain.Body ? TrainingFocus.Velocity : domain == SoulDomain.Technique ? TrainingFocus.Command : TrainingFocus.GamePlanning;
            var value = ApplyGrowth(pitcher, focus, points);
            if (!memory.HasValue) return value;
            var card = memory.Value;
            var memoryFocus = card == MemoryCardId.VelocityBlueprint ? TrainingFocus.Velocity : card == MemoryCardId.FingertipMemory ? TrainingFocus.BreakingBall :
                card == MemoryCardId.RecoveryRoutine || card == MemoryCardId.FatigueDiary || card == MemoryCardId.WinterProgram ? TrainingFocus.Recovery :
                card == MemoryCardId.MechanicsVideo || card == MemoryCardId.CoachLetter ? TrainingFocus.Command : card == MemoryCardId.BullpenCompass ? TrainingFocus.Stamina : TrainingFocus.GamePlanning;
            return ApplyGrowth(value, memoryFocus, 2);
        }
        private static PitcherSnapshot ApplyCreation(CreationAllocationSnapshot allocation, PitcherSnapshot pitcher)
        {
            var value = ApplyGrowth(pitcher, TrainingFocus.Velocity, allocation.Stuff);
            value = ApplyGrowth(value, TrainingFocus.Command, allocation.Command);
            value = ApplyGrowth(value, TrainingFocus.BreakingBall, allocation.Movement);
            return ApplyGrowth(value, TrainingFocus.Stamina, allocation.Stamina);
        }
        private static IReadOnlyList<AwakeningId> AwakeningOptions(PitcherLabSnapshot state, ulong seed, int ordinal)
        {
            var values = Enum.GetValues(typeof(AwakeningId)).Cast<AwakeningId>().Where(value => !state.SelectedAwakenings.Contains(value)).ToList();
            var rng = new SplitMix64(seed ^ (ulong)ordinal ^ 0x4157414B454EUL);
            for (var index = values.Count - 1; index > 0; index--) { var other = rng.NextInt(index + 1); var value = values[index]; values[index] = values[other]; values[other] = value; }
            return values.Take(2).ToArray();
        }
        private static PitcherSnapshot ApplyAwakening(AwakeningId awakening, PitcherSnapshot pitcher)
        {
            var power = awakening == AwakeningId.ExplosiveFastball || awakening == AwakeningId.RisingFourSeam;
            var command = awakening == AwakeningId.PinpointEdge || awakening == AwakeningId.BatterySync || awakening == AwakeningId.RepeatableRelease || awakening == AwakeningId.FirstPitchStrike;
            var breaking = awakening == AwakeningId.DisappearingBreaker || awakening == AwakeningId.SinkerTunnel || awakening == AwakeningId.FrozenChangeup || awakening == AwakeningId.SweepingSlider || awakening == AwakeningId.CurveballClock;
            var stamina = awakening == AwakeningId.IronArm || awakening == AwakeningId.LateInningReserve;
            return ApplyGrowth(pitcher, power ? TrainingFocus.Velocity : command ? TrainingFocus.Command : breaking ? TrainingFocus.BreakingBall : stamina ? TrainingFocus.Stamina : TrainingFocus.GamePlanning, 2);
        }
        private static ScoutingEvaluationSnapshot ScoutingEvaluation(PitcherLabSnapshot state)
        {
            var average = (state.Pitcher.Stuff + state.Pitcher.Command + state.Pitcher.Movement + state.Pitcher.Stamina) / 4;
            var performance = state.Performance;
            var score = Clamp((average + 18) * 10 + performance.Strikeouts * 15 + Clamp((performance.ExpectedDamage - performance.ActualDamage) / 8, -120, 120) - performance.RunsAllowed * 28 - performance.Walks * 12, 0, 1000);
            var grade = score < 500 ? ScoutingGrade.Undrafted : score < 620 ? ScoutingGrade.Follow : score < 760 ? ScoutingGrade.Draftable : ScoutingGrade.Elite;
            var strengths = new List<string>();
            if (state.Pitcher.Stuff >= 45) strengths.Add("고교 무대에서 돋보이는 직구");
            if (state.Pitcher.Command >= 45) strengths.Add("프로 가능성을 보인 제구");
            if (state.Pitcher.Movement >= 45) strengths.Add("결정구로 성장 중인 변화구");
            if (state.Pitcher.Stamina >= 45) strengths.Add("선발 후보로 평가받는 체력");
            if (strengths.Count == 0) strengths.Add("구위·제구·변화구·체력의 균형");
            var concerns = new List<string>();
            if (performance.Walks >= 3) concerns.Add("위기에서 늘어나는 볼넷");
            if (performance.RunsAllowed >= 5) concerns.Add("실점 억제의 기복");
            if (state.Fatigue >= 70) concerns.Add("누적 피로 관리");
            if (concerns.Count == 0) concerns.Add("긴 경기에서도 같은 투구를 이어 갈 수 있는지");
            return new ScoutingEvaluationSnapshot(grade, score, strengths, concerns,
                "세 번의 중요 이닝과 여섯 번의 훈련 기록을 바탕으로 구단 평가에서 ‘" + ScoutingLabel(grade) + "’ 등급을 받았습니다.");
        }
        private static IReadOnlyList<MemoryCardId> MemoryOptions(PitcherLabSnapshot state, ulong seed)
        {
            var values = new List<MemoryCardId>();
            if (state.Pitcher.Stuff >= state.Pitcher.Movement) values.Add(MemoryCardId.VelocityBlueprint);
            if (state.Pitcher.Movement >= state.Pitcher.Command) values.Add(MemoryCardId.FingertipMemory);
            if (state.CatcherTrust >= 55) values.Add(MemoryCardId.CatcherNotebook);
            if (state.Performance.ActualDamage > state.Performance.ExpectedDamage) values.Add(MemoryCardId.RivalNotebook);
            if (state.Fatigue >= 55) values.Add(MemoryCardId.RecoveryRoutine);
            values.Add(MemoryCardId.PressureRehearsal);
            var unique = values.Distinct().ToList();
            if (unique.Count >= 2) return unique.Take(2).ToArray();
            var rng = new SplitMix64(seed ^ 0x4D454D4F5259UL);
            var fallback = Enum.GetValues(typeof(MemoryCardId)).Cast<MemoryCardId>().Where(value => !unique.Contains(value)).ToArray();
            unique.Add(fallback[rng.NextInt(fallback.Length)]);
            return unique;
        }
        private PitcherLabResult MakeResult(ulong seed, PitcherLabSnapshot state, IReadOnlyList<PitcherLabEvent> events)
        {
            var rng = new SplitMix64(seed); var next = rng.Next().ToString(CultureInfo.InvariantCulture);
            var hash = StableHash.Fnv1A64(seed + "|" + state.StateCommitment + "|" + string.Join(",", events.Select(value => value.EventType)) + "|" + next);
            return new PitcherLabResult(state.Revision, next, events, state, hash);
        }
        private void Validate(PitcherLabSnapshot state, PitcherLabPhase phase)
        { if (state.Phase != phase) throw Invalid("expected " + PhaseValue(phase) + ", got " + PhaseValue(state.Phase)); ValidateState(state); }
        private void ValidateState(PitcherLabSnapshot state)
        {
            if (state.StateCommitment != Commitment(state) || state.TrainingSessionsCompleted < 0 || state.TrainingSessionsCompleted > 6 ||
                state.RelationshipEventsCompleted < 0 || state.RelationshipEventsCompleted > 2 || state.Readiness < 0 || state.Readiness > 100 ||
                state.Fatigue < 0 || state.Fatigue > 100 || state.CatcherTrust < 0 || state.CatcherTrust > 100)
                throw Invalid("state commitment or counters are invalid");
        }
        private void Sign(PitcherLabSnapshot state) { state.StateCommitment = Commitment(state); }
        private static PitcherLabSnapshot Next(PitcherLabSnapshot state) { var value = state.Clone(); value.Revision++; return value; }
        private static ulong Seed(string value) { ulong result; if (!ulong.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out result)) throw new SimulationException(SimulationErrorCode.InvalidSeed, "invalid seed: " + value); return result; }
        private static SimulationException Invalid(string message) { return new SimulationException(SimulationErrorCode.InvalidGameState, message); }
        private static int Clamp(int value, int low, int high) { return Math.Min(high, Math.Max(low, value)); }

        private static string PhaseValue(PitcherLabPhase value) { var values = new[] { "training", "important_inning", "relationship", "awakening", "scouting", "reflection", "completed" }; return values[(int)value]; }
        private static string ReactionValue(TrainingReactionBand value) { return new[] { "muted", "steady", "strong", "breakthrough" }[(int)value]; }
        private static string IntensityValue(TrainingIntensity value) { return value == TrainingIntensity.Light ? "light" : value == TrainingIntensity.Standard ? "standard" : "intensive"; }
        private static string SoulValue(SoulDomain value) { return value == SoulDomain.Body ? "body" : value == SoulDomain.Technique ? "technique" : "game"; }
        private static string ScoutingValue(ScoutingGrade value) { return value == ScoutingGrade.Undrafted ? "undrafted" : value == ScoutingGrade.Follow ? "follow" : value == ScoutingGrade.Draftable ? "draftable" : "elite"; }
        private static string FocusLabel(TrainingFocus value) { return value == TrainingFocus.Velocity ? "직구 구속" : value == TrainingFocus.Command ? "제구" : value == TrainingFocus.BreakingBall ? "변화구" : value == TrainingFocus.Stamina ? "선발 체력" : value == TrainingFocus.Recovery ? "휴식과 회복" : "타자 상대법"; }
        private static string ReactionLabel(TrainingReactionBand value) { return value == TrainingReactionBand.Muted ? "낮은" : value == TrainingReactionBand.Steady ? "보통인" : value == TrainingReactionBand.Strong ? "큰" : "매우 큰"; }
        private static string SoulLabel(SoulDomain value) { return value == SoulDomain.Body ? "몸" : value == SoulDomain.Technique ? "기술" : "경기 경험"; }
        private static string ScoutingLabel(ScoutingGrade value) { return value == ScoutingGrade.Undrafted ? "미지명 예상" : value == ScoutingGrade.Follow ? "더 지켜봄" : value == ScoutingGrade.Draftable ? "지명 가능" : "상위 순번 유력"; }
        private static string MemoryLabel(MemoryCardId value)
        {
            var labels = new[] { "직구 구속 훈련법", "손끝의 기억", "포수의 노트", "라이벌 노트", "회복 방법", "압박의 예행연습", "초구 지도", "2스트라이크 구종 순서", "피로 일지", "투구 동작 교정 영상", "학교에서 배운 승부법", "코치의 편지", "구단 평가표", "구장의 메아리", "팀을 위한 약속", "실패의 스코어북", "겨울 훈련표", "불펜의 나침반" };
            return labels[(int)value];
        }
    }
}
