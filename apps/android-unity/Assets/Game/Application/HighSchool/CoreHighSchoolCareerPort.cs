using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Random;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;

namespace Baseball.Application.HighSchool
{
    /// <summary>
    /// Adapter for the Unity Core port. Only this file understands Core command DTOs; the save
    /// aggregate and presentation-facing contracts stay independent of engine implementation.
    /// </summary>
    public sealed class CoreHighSchoolCareerPort :
        IHighSchoolCareerPort,
        IHighSchoolPitchScenarioPort,
        IHighSchoolTutorialScenarioPort
    {
        private readonly HighSchoolCareerEngine _engine;
        private readonly JsonSerializerSettings _snapshotSettings;

        public CoreHighSchoolCareerPort()
        {
            _engine = new HighSchoolCareerEngine();
            _snapshotSettings = new JsonSerializerSettings
            {
                ConstructorHandling = ConstructorHandling.AllowNonPublicDefaultConstructor,
                ContractResolver = new InternalSetterContractResolver(),
                MissingMemberHandling = MissingMemberHandling.Ignore,
                NullValueHandling = NullValueHandling.Include,
                ObjectCreationHandling = ObjectCreationHandling.Replace,
                TypeNameHandling = TypeNameHandling.None
            };
            _snapshotSettings.Converters.Add(new StringEnumConverter());
        }

        public HighSchoolCareerReadModel Start(StartHighSchoolCareerRequest request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            var memories = ParseMany<MemoryCardId>(request.InheritedMemories);
            var karmas = ParseMany<KarmaId>(request.Karmas);
            var boosts = ParseMany<SoulBoostId>(request.SoulBoosts);
            var soulDomain = string.IsNullOrWhiteSpace(request.InheritedSoulDomain)
                ? (SoulDomain?)null
                : Parse<SoulDomain>(request.InheritedSoulDomain);
            var difficulty = Parse<DifficultyLevel>(request.Difficulty);
            var signatureLegacy = string.IsNullOrWhiteSpace(request.SignatureLegacyId)
                ? (CareerSignatureLegacyId?)null
                : Parse<CareerSignatureLegacyId>(request.SignatureLegacyId);
            var identity = new PlayerIdentitySnapshot(
                request.PlayerName,
                ThrowingHand.Right,
                BodyType.Balanced,
                request.Region);
            var result = _engine.Start(new StartHighSchoolCareerParams(
                DeterministicSeed.Normalize(request.Seed),
                request.PresetId,
                request.ChallengeLifeNumber ?? request.LifeNumber,
                inheritedSoulPoints: request.InheritedSoul,
                inheritedSoulDomain: soulDomain,
                inheritedMemories: memories,
                identity: identity,
                difficulty: new CareerDifficultySnapshot(difficulty),
                karmas: karmas,
                soulBoosts: boosts.Count == 0 ? null : boosts,
                inheritedSoulTotal: request.InheritedSoul,
                signatureLegacyId: signatureLegacy,
                inheritanceRulesVersion: 2));
            return Map(
                result,
                equippedSignatureLegacyId: request.SignatureLegacyId,
                difficulty: request.Difficulty,
                isChallengeRun: request.IsChallenge,
                legacySelectionMode: request.IsChallenge
                    ? LegacySelectionMode.Memories
                    : LegacySelectionMode.SignatureLegacy,
                startingRatings: Ratings(result.Snapshot.Pitcher));
        }

        public HighSchoolCareerReadModel Apply(
            HighSchoolCareerReadModel current,
            HighSchoolAction action)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (action == null || string.IsNullOrWhiteSpace(action.Kind))
                throw new ArgumentException("A high-school action is required.", nameof(action));
            var state = Restore(current);
            HighSchoolCareerResult result;
            var frozenSignatureCandidates = current.FrozenSignatureLegacyCandidates;
            var selectedSignatureLegacy = current.SelectedSignatureLegacy;
            var lifeDetail = current.LifeDetail;
            switch (action.Kind)
            {
                case "complete_prologue":
                    result = _engine.CompletePrologue(
                        new AdvanceCareerChapterParams(current.NextSeed, state));
                    break;
                case "choose_school":
                    result = _engine.ChooseSchool(new ChooseSchoolParams(
                        current.NextSeed,
                        state,
                        Parse<SchoolId>(action.Value)));
                    break;
                case "train":
                    var training = TrainingParts(action.Value);
                    var trainingFocus = Parse<TrainingFocus>(training[0]);
                    var trainingTarget = training.Length == 3 ? (PitchType?)Parse<PitchType>(training[2]) : null;
                    ValidateTrainingTarget(state, trainingFocus, trainingTarget);
                    result = _engine.CommitTraining(new CommitCareerTrainingParams(
                        current.NextSeed,
                        state,
                        trainingFocus,
                        Parse<TrainingIntensity>(training[1]),
                        trainingTarget));
                    break;
                case "train_block":
                    var blockTraining = TrainingParts(action.Value);
                    var blockFocus = Parse<TrainingFocus>(blockTraining[0]);
                    var blockTarget = blockTraining.Length == 3 ? (PitchType?)Parse<PitchType>(blockTraining[2]) : null;
                    ValidateTrainingTarget(state, blockFocus, blockTarget);
                    var block = _engine.CommitTrainingBlock(new CommitCareerTrainingBlockParams(
                        current.NextSeed,
                        state,
                        blockFocus,
                        Parse<TrainingIntensity>(blockTraining[1]),
                        blockTarget,
                        HighSchoolTrainingActionPayload.MaximumBlockSessions));
                    return Map(
                        block.Career,
                        current.PledgeId,
                        current.PledgeDecided,
                        current.EquippedSignatureLegacyId,
                        current.SelectedSignatureLegacyId,
                        current.Difficulty,
                        current.IsChallengeRun,
                        current.LegacySelectionMode,
                        current.TutorialCompleted,
                        current.TutorialAttemptCount,
                        current.PledgeRulesVersion,
                        current.RivalStrikeouts,
                        TrainingBlock(block.Block),
                        frozenSignatureCandidates,
                        selectedSignatureLegacy,
                        lifeDetail);
                case "relationship":
                    var relationshipResponse = Parse<RelationshipResponse>(action.Value);
                    result = _engine.ResolveRelationship(new ResolveCareerRelationshipParams(
                        current.NextSeed,
                        state,
                        relationshipResponse));
                    lifeDetail = RecordResponse(lifeDetail, relationshipResponse);
                    break;
                case "awakening":
                    result = _engine.ChooseAwakening(new ChooseCareerAwakeningParams(
                        current.NextSeed,
                        state,
                        Parse<AwakeningId>(action.Value)));
                    break;
                case "advance_chapter":
                    result = _engine.AdvanceChapter(
                        new AdvanceCareerChapterParams(current.NextSeed, state));
                    break;
                case "resolve_draft":
                    result = _engine.ResolveDraft(new ResolveDraftParams(current.NextSeed, state));
                    break;
                case "open_legacy":
                    result = _engine.OpenLegacy(
                        new AdvanceCareerChapterParams(current.NextSeed, state));
                    break;
                case "select_legacy":
                    result = _engine.SelectLegacy(new SelectCareerLegacyParams(
                        current.NextSeed,
                        state,
                        ParseCsv<MemoryCardId>(action.Value)));
                    break;
                case "select_signature_legacy":
                    selectedSignatureLegacy = SelectFrozenSignatureLegacy(
                        state,
                        frozenSignatureCandidates,
                        Parse<CareerSignatureLegacyId>(action.Value));
                    result = _engine.SelectLegacy(new SelectCareerLegacyParams(
                        current.NextSeed,
                        state,
                        Array.Empty<MemoryCardId>(),
                        Parse<CareerSignatureLegacyId>(action.Value)));
                    break;
                default:
                    throw new InvalidOperationException("high_school.action_unsupported:" + action.Kind);
            }
            return Map(
                result,
                current.PledgeId,
                current.PledgeDecided,
                current.EquippedSignatureLegacyId,
                string.Equals(action.Kind, "select_signature_legacy", StringComparison.Ordinal)
                    ? action.Value
                    : current.SelectedSignatureLegacyId,
                current.Difficulty,
                current.IsChallengeRun,
                current.LegacySelectionMode,
                current.TutorialCompleted,
                current.TutorialAttemptCount,
                current.PledgeRulesVersion,
                current.RivalStrikeouts,
                frozenSignatureLegacyCandidates: frozenSignatureCandidates,
                selectedSignatureLegacy: selectedSignatureLegacy,
                priorLifeDetail: lifeDetail);
        }

        public HighSchoolCareerReadModel ReservePitch(
            HighSchoolCareerReadModel current,
            string scenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            // Match iOS: the advanced seed becomes both the session seed and the next Core input.
            return CopyWithNextSeed(current, AdvanceSeed(current.NextSeed));
        }

        public PitchScenarioReadModel CreatePitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (string.IsNullOrWhiteSpace(requestedScenarioId))
                throw new ArgumentException("A requested scenario ID is required.", nameof(requestedScenarioId));
            return PitchScenarioFactory.HighSchool(Restore(current));
        }

        public PitchScenarioReadModel CreateTutorialPitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (string.IsNullOrWhiteSpace(requestedScenarioId))
                throw new ArgumentException("A requested scenario ID is required.", nameof(requestedScenarioId));
            return PitchScenarioFactory.Tutorial(Restore(current));
        }

        public HighSchoolCareerReadModel ApplyPitchResult(
            HighSchoolCareerReadModel current,
            PitchGameReport report)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (report == null) throw new ArgumentNullException(nameof(report));
            var state = Restore(current);
            var coreReport = new ImportantInningReport(
                state.Performance.ImportantGamesCompleted + 1,
                report.Pitches,
                report.Strikeouts,
                report.Walks,
                report.RunsAllowed,
                report.ExpectedDamage,
                report.ActualDamage,
                report.RecommendationAccepted,
                report.Outs,
                null,
                null,
                report.SequenceMasteryCount,
                report.Hits,
                report.HomeRuns);
            return Map(
                _engine.RecordImportantGame(new RecordCareerGameParams(
                    current.NextSeed,
                    state,
                    coreReport)),
                current.PledgeId,
                current.PledgeDecided,
                current.EquippedSignatureLegacyId,
                current.SelectedSignatureLegacyId,
                current.Difficulty,
                current.IsChallengeRun,
                current.LegacySelectionMode,
                current.TutorialCompleted,
                current.TutorialAttemptCount,
                current.PledgeRulesVersion,
                current.RivalStrikeouts + report.RivalStrikeouts,
                frozenSignatureLegacyCandidates: current.FrozenSignatureLegacyCandidates,
                selectedSignatureLegacy: current.SelectedSignatureLegacy,
                priorLifeDetail: current.LifeDetail);
        }

        private HighSchoolCareerReadModel Map(
            HighSchoolCareerResult result,
            string pledgeId = null,
            bool pledgeDecided = false,
            string equippedSignatureLegacyId = null,
            string selectedSignatureLegacyId = null,
            string difficulty = "standard",
            bool isChallengeRun = false,
            LegacySelectionMode legacySelectionMode = LegacySelectionMode.Memories,
            bool tutorialCompleted = false,
            int tutorialAttemptCount = 0,
            int pledgeRulesVersion = 0,
            int rivalStrikeouts = 0,
            TrainingBlockResultReadModel lastTrainingBlock = null,
            IReadOnlyList<SignatureLegacyReadModel> frozenSignatureLegacyCandidates = null,
            SignatureLegacyReadModel selectedSignatureLegacy = null,
            HighSchoolLifeDetailReadModel priorLifeDetail = null,
            PitcherRatingsReadModel startingRatings = null)
        {
            var state = result.Snapshot;
            var schedule = state.Schedule ?? CareerScheduleSnapshot.FixedDefault;
            var totalGames = schedule.ImportantGameTotal;
            var remainingGames = Math.Max(0, totalGames - state.Performance.ImportantGamesCompleted);
            var frozenCandidates = (frozenSignatureLegacyCandidates ??
                (legacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                 state.Phase == HighSchoolCareerPhase.Legacy
                    ? FrozenSignatureLegacyCandidates(state)
                    : Array.Empty<SignatureLegacyReadModel>())).ToArray();
            return new HighSchoolCareerReadModel(
                state.CareerId,
                state.LifeNumber,
                Map(state.Phase),
                result.NextSeed,
                state.Revision,
                state.Pitcher.Id,
                state.Identity.Name,
                InferPresetId(state.Pitcher.Id),
                new PitcherRatingsReadModel(
                    state.Pitcher.Stuff,
                    state.Pitcher.Command,
                    state.Pitcher.Movement,
                    state.Pitcher.Stamina),
                new CareerPerformanceReadModel(
                    state.Performance.ImportantGamesCompleted,
                    state.Performance.Pitches,
                    state.Performance.Outs ?? 0,
                    state.Performance.Strikeouts,
                    state.Performance.Walks,
                    state.Performance.Hits ?? 0,
                    state.Performance.RunsAllowed),
                state.School?.Id.ToString(),
                state.School?.Name,
                state.Chapter.SchoolYear,
                state.Chapter.Number,
                remainingGames,
                Math.Max(0, 8 - state.Chapter.Number),
                Map(state.DraftResult),
                JsonConvert.SerializeObject(state, Formatting.None, _snapshotSettings),
                pledgeId,
                pledgeDecided,
                state.Karmas.Select(KarmaWire).ToArray(),
                state.SelectedAwakenings.Select(value => value.Value()).ToArray(),
                SchoolChoices(state),
                TrainingFocusChoices(state),
                TrainingIntensityChoices(state),
                RelationshipChoices(state),
                AwakeningChoices(state),
                legacySelectionMode == LegacySelectionMode.Memories
                    ? LegacyMemoryChoices(state)
                    : Array.Empty<CareerChoiceReadModel>(),
                state.MemorySlots,
                Tournament(state),
                ProspectRankings(state),
                GameLines(state),
                legacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                state.Phase == HighSchoolCareerPhase.Legacy
                    ? SignatureLegacyChoices(frozenCandidates)
                    : Array.Empty<CareerChoiceReadModel>(),
                equippedSignatureLegacyId,
                selectedSignatureLegacyId,
                difficulty,
                isChallengeRun,
                legacySelectionMode,
                tutorialCompleted,
                tutorialAttemptCount,
                pledgeRulesVersion,
                state.LegacyRewardPermille,
                rivalStrikeouts,
                state.Fatigue,
                state.ArmRisk ?? 0,
                state.InjuryRecovery ?? 0,
                state.ManagerTrust ?? state.RelationshipTrust,
                state.CatcherTrust ?? state.RelationshipTrust,
                state.RivalTrust ?? state.RelationshipTrust,
                state.FanInterest,
                HighSchoolCareerEngine.DraftForecast(state).Score,
                ChapterProgress(state, schedule),
                ScheduleMilestones(state, schedule),
                RelationshipEvent(state),
                GameScenario(state),
                TrainingResult(state.LastTraining),
                RelationshipResult(state.LastRelationship),
                state.News,
                TrainingPitchChoices(state),
                lastTrainingBlock,
                HighSchoolTrainingActionPayload.MaximumBlockSessions,
                frozenCandidates,
                selectedSignatureLegacy,
                LifeDetail(state, priorLifeDetail, startingRatings));
        }

        private HighSchoolCareerSnapshot Restore(HighSchoolCareerReadModel current)
        {
            if (string.IsNullOrWhiteSpace(current.CoreStateJson))
                throw new InvalidOperationException("high_school.core_state_missing");
            var state = JsonConvert.DeserializeObject<HighSchoolCareerSnapshot>(
                current.CoreStateJson,
                _snapshotSettings);
            if (state == null || !string.Equals(state.CareerId, current.CareerId, StringComparison.Ordinal) ||
                state.Revision != current.CoreRevision)
            {
                throw new InvalidOperationException("high_school.core_state_mismatch");
            }
            return state;
        }

        private static IReadOnlyList<CareerChoiceReadModel> SchoolChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.SchoolSelection) return Array.Empty<CareerChoiceReadModel>();
            return (state.SchoolOptions ?? Array.Empty<SchoolSnapshot>())
                .Select(value => new CareerChoiceReadModel(
                    SchoolWire(value.Id),
                    value.Name,
                    value.Philosophy + " · 감독 " + value.CoachName + " · 포수 " + value.CatcherName,
                    "강점 " + FocusTitle(value.Strength) + " · " + value.Tradeoff))
                .ToArray();
        }

        private IReadOnlyList<CareerChoiceReadModel> TrainingFocusChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Training) return Array.Empty<CareerChoiceReadModel>();
            return Enum.GetValues(typeof(TrainingFocus)).Cast<TrainingFocus>()
                .Select(value => new CareerChoiceReadModel(
                    value.Value(),
                    FocusTitle(value),
                    state.TrainingOpportunity?.Focus == value
                        ? "오늘의 성장 기회 · " + state.TrainingOpportunity.Reason
                        : "현재 능력과 피로를 기준으로 훈련합니다.",
                    "표준 강도 전망 " + OutlookTitle(_engine.TrainingOutlook(
                        state,
                        value,
                        TrainingIntensity.Standard))))
                .ToArray();
        }

        private static IReadOnlyList<CareerChoiceReadModel> TrainingIntensityChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Training) return Array.Empty<CareerChoiceReadModel>();
            return new[]
            {
                new CareerChoiceReadModel("light", "가볍게", "피로 +3 · 성장 신호가 낮습니다."),
                new CareerChoiceReadModel("standard", "표준", "피로 +8 · 성장과 컨디션의 균형을 잡습니다."),
                new CareerChoiceReadModel("intensive", "집중", "피로 +15 · 성장 신호가 높지만 팔 부담도 큽니다.")
            };
        }

        private static IReadOnlyList<CareerChoiceReadModel> TrainingPitchChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Training || state.Pitcher?.PitchProfiles == null)
                return Array.Empty<CareerChoiceReadModel>();
            return state.Pitcher.PitchProfiles
                .Where(value => value.PitchType != PitchType.FourSeam)
                .Select(value => new CareerChoiceReadModel(
                    value.PitchType.Value(),
                    PitchTitle(value.PitchType),
                    "이 변화구의 움직임과 헛스윙을 집중적으로 다듬습니다."))
                .ToArray();
        }

        private static IReadOnlyList<CareerChoiceReadModel> RelationshipChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Relationship) return Array.Empty<CareerChoiceReadModel>();
            var content = state.CurrentRelationshipEvent;
            var scene = RelationshipVoiceCatalog.GetScene(content?.Id, content?.Category);
            if (scene != null)
            {
                return scene.Choices.Select(value => new CareerChoiceReadModel(
                    RelationshipWire(value.Response),
                    value.Title,
                    value.Detail)).ToArray();
            }
            return new[]
            {
                new CareerChoiceReadModel("listen", "먼저 듣는다", "상대가 본 장면을 확인합니다."),
                new CareerChoiceReadModel("explain", "설명한다", "내 판단의 근거를 전합니다."),
                new CareerChoiceReadModel("challenge", "결과로 답한다", "다음 승부로 직접 증명합니다.")
            };
        }

        private static IReadOnlyList<CareerChoiceReadModel> AwakeningChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Awakening) return Array.Empty<CareerChoiceReadModel>();
            return (state.AwakeningOptions ?? Array.Empty<AwakeningId>())
                .Select(value => new CareerChoiceReadModel(
                    value.Value(),
                    AwakeningTitle(value),
                    AwakeningTree.GetBranch(value) + " 계열 · " + AwakeningTree.GetTier(value) + "단계",
                    AwakeningTree.IsLeap(value, state.SelectedAwakenings ?? Array.Empty<AwakeningId>())
                        ? "각성 불꽃을 써서 선행 단계를 건너뜁니다."
                        : "현재 계보에서 배울 수 있습니다."))
                .ToArray();
        }

        private static IReadOnlyList<CareerChoiceReadModel> LegacyMemoryChoices(HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Legacy) return Array.Empty<CareerChoiceReadModel>();
            return (state.LegacyOptions ?? Array.Empty<MemoryCardId>())
                .Select(value => new CareerChoiceReadModel(
                    value.Value(),
                    MemoryTitle(value),
                    "다음 삶의 시작 능력과 이야기에 남기는 기억입니다."))
                .ToArray();
        }

        private static IReadOnlyList<SignatureLegacyReadModel> FrozenSignatureLegacyCandidates(
            HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Legacy)
                return Array.Empty<SignatureLegacyReadModel>();
            var preset = PitcherPresetCatalog.All.FirstOrDefault(value =>
                string.Equals(value.Id, InferPresetId(state.Pitcher.Id), StringComparison.Ordinal));
            if (preset == null) return Array.Empty<SignatureLegacyReadModel>();
            return CareerSignatureLegacy.Candidates(preset.Pitcher, state)
                .Select(value => new SignatureLegacyReadModel(
                    value.Id.Value(),
                    value.Title,
                    value.Detail,
                    value.Evidence.Summary))
                .ToArray();
        }

        private static IReadOnlyList<CareerChoiceReadModel> SignatureLegacyChoices(
            IReadOnlyList<SignatureLegacyReadModel> candidates)
        {
            return (candidates ?? Array.Empty<SignatureLegacyReadModel>())
                .Select(value => new CareerChoiceReadModel(
                    value.Id,
                    value.Title,
                    value.Detail,
                    value.EvidenceSummary))
                .ToArray();
        }

        private static SignatureLegacyReadModel SelectFrozenSignatureLegacy(
            HighSchoolCareerSnapshot state,
            IReadOnlyList<SignatureLegacyReadModel> frozenCandidates,
            CareerSignatureLegacyId selectedId)
        {
            var id = selectedId.Value();
            var candidates = frozenCandidates == null || frozenCandidates.Count == 0
                ? FrozenSignatureLegacyCandidates(state)
                : frozenCandidates;
            var selected = candidates.SingleOrDefault(value =>
                string.Equals(value.Id, id, StringComparison.Ordinal));
            return selected ?? throw new InvalidOperationException(
                "high_school.signature_legacy_not_offered");
        }

        private static TournamentBracketReadModel Tournament(HighSchoolCareerSnapshot state)
        {
            if (state.School == null || !TournamentBracket.IsTournamentChapter(state.Chapter.Number)) return null;
            var field = TournamentBracket.GetField(
                state.CareerId,
                state.Chapter.Number,
                state.School.Name);
            return new TournamentBracketReadModel(field.TournamentName, field.Schools, field.PlayerRound);
        }

        private static IReadOnlyList<ProspectEntryReadModel> ProspectRankings(HighSchoolCareerSnapshot state)
        {
            if (state.School == null || state.Performance == null) return Array.Empty<ProspectEntryReadModel>();
            return ProspectRanking.Board(
                    state.CareerId,
                    state.Identity.Name,
                    state.School.Name,
                    state.Performance)
                .Select(value => new ProspectEntryReadModel(
                    value.Rank,
                    value.Name,
                    value.School,
                    value.Tag,
                    value.IsPlayer))
                .ToArray();
        }

        private static IReadOnlyList<CareerGameLineReadModel> GameLines(HighSchoolCareerSnapshot state)
        {
            return (state.SeasonLog ?? Array.Empty<ProGameLine>())
                .Select(MapLine)
                .ToArray();
        }

        private static CareerGameLineReadModel MapLine(ProGameLine value)
        {
            return new CareerGameLineReadModel(
                value.Season,
                value.Week,
                value.OutingNumber,
                value.Played,
                value.Started,
                value.Outs,
                value.Strikeouts,
                value.Walks,
                value.Hits,
                value.RunsAllowed,
                value.Pitches,
                value.TeamRuns,
                value.OpponentRuns,
                value.Decision.ToString().ToLowerInvariant(),
                value.HomeRuns,
                value.Hits);
        }

        private static ChapterProgressReadModel ChapterProgress(
            HighSchoolCareerSnapshot state,
            CareerScheduleSnapshot schedule)
        {
            var index = Math.Max(0, Math.Min(schedule.TrainingsByChapter.Count - 1,
                state.Chapter.Number - 1));
            var milestones = schedule.MilestonesByChapter[index];
            return new ChapterProgressReadModel(
                state.Chapter.Number,
                state.Chapter.Title,
                state.Chapter.SchoolYear,
                state.Chapter.Season,
                state.Chapter.Theme,
                state.ChapterTrainingCount,
                schedule.TrainingsByChapter[index],
                state.MilestoneIndex,
                milestones.Count,
                state.Phase == HighSchoolCareerPhase.ChapterReview
                    ? state.News?.FirstOrDefault()
                    : null);
        }

        private static IReadOnlyList<CareerMilestoneReadModel> ScheduleMilestones(
            HighSchoolCareerSnapshot state,
            CareerScheduleSnapshot schedule)
        {
            var result = new List<CareerMilestoneReadModel>();
            for (var chapterIndex = 0; chapterIndex < schedule.MilestonesByChapter.Count; chapterIndex++)
            {
                var phases = schedule.MilestonesByChapter[chapterIndex];
                for (var order = 0; order < phases.Count; order++)
                {
                    var chapter = chapterIndex + 1;
                    result.Add(new CareerMilestoneReadModel(
                        chapter,
                        order,
                        phases[order].Value(),
                        chapter < state.Chapter.Number ||
                        chapter == state.Chapter.Number && order < state.MilestoneIndex,
                        chapter == state.Chapter.Number && order == state.MilestoneIndex &&
                        phases[order] == state.Phase));
                }
            }
            return result;
        }

        private static RelationshipEventReadModel RelationshipEvent(
            HighSchoolCareerSnapshot state)
        {
            var content = state.CurrentRelationshipEvent;
            if (content == null) return null;
            var scene = RelationshipVoiceCatalog.GetScene(content.Id, content.Category);
            if (scene == null)
            {
                return new RelationshipEventReadModel(
                    content.Id, content.Title, content.Category, content.Summary,
                    SpeakerCategory(content.Category), "mid", null);
            }
            var manager = state.ManagerTrust ?? state.RelationshipTrust;
            var catcher = state.CatcherTrust ?? state.RelationshipTrust;
            var rival = state.RivalTrust ?? state.RelationshipTrust;
            var band = RelationshipVoiceCatalog.TrustBandFor(
                scene.Speaker, manager, catcher, rival);
            var quote = scene.Quote(band)?.Replace("{player}", state.Identity.Name);
            return new RelationshipEventReadModel(
                content.Id,
                content.Title,
                content.Category,
                content.Summary,
                SpeakerName(scene.Speaker, state),
                band.ToString().ToLowerInvariant(),
                quote);
        }

        private static string SpeakerName(
            RelationshipVoiceCatalog.Speaker speaker,
            HighSchoolCareerSnapshot state)
        {
            switch (speaker.Kind)
            {
                case RelationshipVoiceCatalog.SpeakerKind.Coach:
                    return state.School == null ? "감독" : state.School.CoachName + " 감독";
                case RelationshipVoiceCatalog.SpeakerKind.Catcher:
                    return state.School == null ? "포수" : state.School.CatcherName + " 포수";
                case RelationshipVoiceCatalog.SpeakerKind.Rival:
                    return state.Rival?.Name ?? "라이벌";
                default:
                    return speaker.Name ?? SpeakerCategory(state.CurrentRelationshipEvent?.Category);
            }
        }

        private static string SpeakerCategory(string category)
        {
            switch (category)
            {
                case "life": return "집";
                case "coach": return "감독";
                case "catcher": return "포수";
                case "rival": return "라이벌";
                case "media": return "취재";
                case "fan": return "팬";
                case "health": return "몸 상태";
                case "team": return "팀";
                case "draft": return "스카우트";
                case "growth": return "훈련장";
                case "game": return "경기장";
                default: return "학교";
            }
        }

        private static GameScenarioNarrativeReadModel GameScenario(
            HighSchoolCareerSnapshot state)
        {
            var value = state.CurrentGameScenario;
            return value == null
                ? null
                : new GameScenarioNarrativeReadModel(
                    value.Id,
                    value.Title,
                    value.Narrative,
                    value.Inning,
                    value.Outs,
                    value.Leverage,
                    value.ScoreDifferential ?? 0);
        }

        private static TrainingResultReadModel TrainingResult(CareerTrainingSnapshot value)
        {
            return value == null
                ? null
                : new TrainingResultReadModel(
                    value.Number,
                    value.Focus.Value(),
                    value.Intensity == TrainingIntensity.Light
                        ? "light"
                        : value.Intensity == TrainingIntensity.Intensive ? "intensive" : "standard",
                    value.Growth,
                    value.FatigueChange,
                    value.Feedback,
                    value.MetricBefore,
                    value.MetricAfter,
                    value.OpportunityHit == true,
                    value.Jackpot == true,
                    value.TargetPitch.HasValue ? value.TargetPitch.Value.Value() : null);
        }

        private static TrainingBlockResultReadModel TrainingBlock(CareerTrainingBlockSnapshot value)
        {
            return value == null
                ? null
                : new TrainingBlockResultReadModel(
                    value.MaximumSessions,
                    value.CompletedSessions,
                    value.Focus.Value(),
                    value.Intensity == TrainingIntensity.Light
                        ? "light"
                        : value.Intensity == TrainingIntensity.Intensive ? "intensive" : "standard",
                    value.TargetPitch.HasValue ? value.TargetPitch.Value.Value() : null,
                    value.StopReason.Value(),
                    value.Growth,
                    value.FatigueChange,
                    value.Sessions.Select(TrainingResult).ToArray());
        }

        private static RelationshipResultReadModel RelationshipResult(
            CareerRelationshipResultSnapshot value)
        {
            return value == null
                ? null
                : new RelationshipResultReadModel(
                    value.Number,
                    value.Category,
                    value.Title,
                    RelationshipWire(value.Response),
                    value.TrustBefore,
                    value.TrustAfter,
                    value.FatigueBefore,
                    value.FatigueAfter,
                    value.FanInterestBefore,
                    value.FanInterestAfter,
                    value.Feedback);
        }

        private static PitcherRatingsReadModel Ratings(PitcherSnapshot value)
        {
            return value == null
                ? null
                : new PitcherRatingsReadModel(
                    value.Stuff,
                    value.Command,
                    value.Movement,
                    value.Stamina);
        }

        private static HighSchoolLifeDetailReadModel RecordResponse(
            HighSchoolLifeDetailReadModel current,
            RelationshipResponse response)
        {
            var tally = current?.ResponseTally ?? new RelationshipResponseTallyReadModel();
            tally = new RelationshipResponseTallyReadModel(
                tally.Listen + (response == RelationshipResponse.Listen ? 1 : 0),
                tally.Explain + (response == RelationshipResponse.Explain ? 1 : 0),
                tally.Challenge + (response == RelationshipResponse.Challenge ? 1 : 0));
            return new HighSchoolLifeDetailReadModel(
                current?.StartingRatings,
                current?.Nicknames,
                current?.Chronicle,
                current?.CoachName,
                current?.CatcherName,
                current?.RivalName,
                current?.Personality,
                current?.WindId,
                current?.WindTitle,
                current?.SchoolStrength,
                tally,
                current?.Talents,
                current?.PresetId,
                current?.PresetTitle,
                current?.DifficultyId,
                current?.DifficultyTitle);
        }

        private static HighSchoolLifeDetailReadModel LifeDetail(
            HighSchoolCareerSnapshot state,
            HighSchoolLifeDetailReadModel prior,
            PitcherRatingsReadModel startingRatings)
        {
            var tally = prior?.ResponseTally ?? new RelationshipResponseTallyReadModel();
            var personality = PersonalityRules.Resolve(
                tally.Listen,
                tally.Explain,
                tally.Challenge);
            var wind = state.CareerWind;
            var presetId = InferPresetId(state.Pitcher.Id);
            var preset = PitcherPresetCatalog.All.FirstOrDefault(value =>
                string.Equals(value.Id, presetId, StringComparison.Ordinal));
            var difficultyId = state.Difficulty.CareerHarshness
                .ToString()
                .ToLowerInvariant();
            var difficulty = HighSchoolSetupCatalog.Difficulties.FirstOrDefault(value =>
                string.Equals(value.Id, difficultyId, StringComparison.Ordinal));
            return new HighSchoolLifeDetailReadModel(
                prior?.StartingRatings ?? startingRatings,
                NicknameRules.Earned(state.Performance).Select(value => value.Title).ToArray(),
                (state.News ?? Array.Empty<string>()).Reverse().ToArray(),
                state.School?.CoachName,
                state.School?.CatcherName,
                state.Rival?.Name,
                personality?.Title,
                wind.Id,
                wind.Title,
                state.School == null ? null : FocusTitle(state.School.Strength),
                tally,
                TalentGrades(state.Talent),
                presetId,
                preset?.Name,
                difficultyId,
                difficulty?.Title ?? difficultyId);
        }

        private static IReadOnlyList<TalentGradeReadModel> TalentGrades(TalentSnapshot value)
        {
            if (value == null) return Array.Empty<TalentGradeReadModel>();
            return new[]
            {
                TalentGrade("stuff", "구위", value.Stuff),
                TalentGrade("command", "제구", value.Command),
                TalentGrade("movement", "변화", value.Movement),
                TalentGrade("stamina", "체력", value.Stamina)
            };
        }

        private static TalentGradeReadModel TalentGrade(
            string abilityId,
            string abilityTitle,
            TalentGrade grade)
        {
            var wire = grade.ToString().ToLowerInvariant();
            return new TalentGradeReadModel(
                abilityId,
                abilityTitle,
                wire,
                grade + "등급");
        }

        private static HighSchoolCareerReadModel CopyWithNextSeed(
            HighSchoolCareerReadModel value,
            string nextSeed)
        {
            return new HighSchoolCareerReadModel(
                value.CareerId,
                value.LifeNumber,
                value.Phase,
                nextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.PresetId,
                value.Ratings,
                value.Performance,
                value.SchoolId,
                value.SchoolName,
                value.SchoolYear,
                value.ChapterNumber,
                value.RemainingImportantGames,
                value.RemainingChapterAdvances,
                value.Draft,
                value.CoreStateJson,
                value.PledgeId,
                value.PledgeDecided,
                value.Karmas,
                value.Awakenings,
                value.SchoolChoices,
                value.TrainingFocusChoices,
                value.TrainingIntensityChoices,
                value.RelationshipChoices,
                value.AwakeningChoices,
                value.LegacyMemoryChoices,
                value.MemorySlots,
                value.Tournament,
                value.ProspectRankings,
                value.GameLines,
                value.SignatureLegacyChoices,
                value.EquippedSignatureLegacyId,
                value.SelectedSignatureLegacyId,
                value.Difficulty,
                value.IsChallengeRun,
                value.LegacySelectionMode,
                value.TutorialCompleted,
                value.TutorialAttemptCount,
                value.PledgeRulesVersion,
                value.LegacyRewardPermille,
                value.RivalStrikeouts,
                value.Fatigue,
                value.ArmRisk,
                value.InjuryRecovery,
                value.ManagerTrust,
                value.CatcherTrust,
                value.RivalTrust,
                value.FanInterest,
                value.DraftForecastScore,
                value.ChapterProgress,
                value.ScheduleMilestones,
                value.CurrentRelationshipEvent,
                value.CurrentGameScenario,
                value.LastTraining,
                value.LastRelationship,
                value.News,
                value.TrainingPitchChoices,
                value.LastTrainingBlock,
                value.MaximumTrainingBlockSessions,
                value.FrozenSignatureLegacyCandidates,
                value.SelectedSignatureLegacy,
                value.LifeDetail);
        }

        private static string AdvanceSeed(string value)
        {
            if (!ulong.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var seed))
                seed = 0x9E3779B97F4A7C15UL;
            var generator = new SplitMix64(seed);
            return Math.Max(1UL, generator.Next() >> 1)
                .ToString(CultureInfo.InvariantCulture);
        }

        private static string InferPresetId(string pitcherId)
        {
            switch (pitcherId)
            {
                case "pitcher-power": return "power_prospect";
                case "pitcher-command": return "precision_commander";
                case "pitcher-artist": return "breaking_ball_artist";
                case "pitcher-stamina": return "innings_eater";
                default: return pitcherId;
            }
        }

        private static string SchoolWire(SchoolId value)
        {
            switch (value)
            {
                case SchoolId.HanbitTraditional: return "hanbit_traditional";
                case SchoolId.MiraeAnalytics: return "mirae_analytics";
                case SchoolId.HaedongPower: return "haedong_power";
                default: return "cheongam_development";
            }
        }

        private static string RelationshipWire(RelationshipResponse value)
        {
            return value == RelationshipResponse.Listen
                ? "listen"
                : value == RelationshipResponse.Explain ? "explain" : "challenge";
        }

        private static string KarmaWire(KarmaId value)
        {
            switch (value)
            {
                case KarmaId.UnknownLand: return "unknown_land";
                case KarmaId.StubbornCoach: return "stubborn_coach";
                case KarmaId.SingleWeapon: return "single_weapon";
                case KarmaId.GeniusGeneration: return "genius_generation";
                case KarmaId.ErasedMemory: return "erased_memory";
                default: return "no_last_chance";
            }
        }

        private static string FocusTitle(TrainingFocus value)
        {
            switch (value)
            {
                case TrainingFocus.Velocity: return "구속";
                case TrainingFocus.Command: return "제구";
                case TrainingFocus.BreakingBall: return "변화구";
                case TrainingFocus.Stamina: return "체력";
                case TrainingFocus.Recovery: return "회복";
                default: return "경기 운영";
            }
        }

        private static string OutlookTitle(TrainingGrowthOutlook value)
        {
            switch (value)
            {
                case TrainingGrowthOutlook.Wall: return "재능 한계";
                case TrainingGrowthOutlook.None: return "성장 없음";
                case TrainingGrowthOutlook.ZeroOrOne: return "0~1";
                case TrainingGrowthOutlook.One: return "+1";
                case TrainingGrowthOutlook.OneOrTwo: return "+1~2";
                default: return "+2";
            }
        }

        private static string AwakeningTitle(AwakeningId value)
        {
            switch (value)
            {
                case AwakeningId.ExplosiveFastball: return "폭발하는 포심";
                case AwakeningId.PinpointEdge: return "바늘끝 제구";
                case AwakeningId.DisappearingBreaker: return "사라지는 변화구";
                case AwakeningId.IronArm: return "강철 어깨";
                case AwakeningId.CalmUnderPressure: return "위기 속 평정";
                case AwakeningId.BatterySync: return "배터리 호흡";
                case AwakeningId.RisingFourSeam: return "떠오르는 포심";
                case AwakeningId.SinkerTunnel: return "싱커 터널";
                case AwakeningId.FrozenChangeup: return "얼어붙는 체인지업";
                case AwakeningId.SweepingSlider: return "가로지르는 슬라이더";
                case AwakeningId.CurveballClock: return "커브 타이밍";
                case AwakeningId.RepeatableRelease: return "한결같은 손끝";
                case AwakeningId.PickoffRhythm: return "견제 리듬";
                case AwakeningId.TwoStrikePlan: return "투 스트라이크 설계";
                case AwakeningId.FirstPitchStrike: return "초구 스트라이크";
                case AwakeningId.TrafficController: return "주자 통제";
                case AwakeningId.LateInningReserve: return "후반의 여력";
                default: return "스카우트 앞 평정";
            }
        }

        private static string MemoryTitle(MemoryCardId value)
        {
            switch (value)
            {
                case MemoryCardId.VelocityBlueprint: return "구속 설계도";
                case MemoryCardId.FingertipMemory: return "손끝의 기억";
                case MemoryCardId.CatcherNotebook: return "포수의 노트";
                case MemoryCardId.RivalNotebook: return "라이벌 노트";
                case MemoryCardId.RecoveryRoutine: return "회복 루틴";
                case MemoryCardId.PressureRehearsal: return "압박 리허설";
                case MemoryCardId.FirstPitchMap: return "초구 지도";
                case MemoryCardId.TwoStrikeSequence: return "투 스트라이크 배합";
                case MemoryCardId.FatigueDiary: return "피로 일지";
                case MemoryCardId.MechanicsVideo: return "투구 동작 영상";
                case MemoryCardId.SchoolPlaybook: return "학교 작전 노트";
                case MemoryCardId.CoachLetter: return "감독의 편지";
                case MemoryCardId.DraftReport: return "드래프트 보고서";
                case MemoryCardId.StadiumEcho: return "구장의 메아리";
                case MemoryCardId.TeamFirstPromise: return "팀 우선의 약속";
                case MemoryCardId.FailureScorebook: return "실패의 스코어북";
                case MemoryCardId.WinterProgram: return "겨울 프로그램";
                default: return "불펜 나침반";
            }
        }

        private static HighSchoolPhase Map(HighSchoolCareerPhase value)
        {
            return (HighSchoolPhase)(int)value;
        }

        private static DraftReadModel Map(DraftResultSnapshot value)
        {
            return value == null
                ? null
                : new DraftReadModel(
                    true,
                    value.Outcome == DraftOutcome.Drafted,
                    value.EvaluationScore,
                    value.Team?.Id,
                    value.Team?.Name,
                    value.Round,
                    value.OverallPick);
        }

        private static T Parse<T>(string value) where T : struct
        {
            var normalized = Normalize(value);
            foreach (T candidate in Enum.GetValues(typeof(T)))
            {
                if (Normalize(candidate.ToString()) == normalized) return candidate;
            }
            throw new InvalidOperationException("high_school.enum_invalid:" + typeof(T).Name);
        }

        private static IReadOnlyList<T> ParseMany<T>(IReadOnlyList<string> values) where T : struct
        {
            return (values ?? Array.Empty<string>()).Select(Parse<T>).ToArray();
        }

        private static IReadOnlyList<T> ParseCsv<T>(string value) where T : struct
        {
            if (string.IsNullOrWhiteSpace(value)) return Array.Empty<T>();
            return value.Split(',').Select(Parse<T>).ToArray();
        }

        private static string[] Parts(string value, int count)
        {
            var parts = (value ?? string.Empty).Split(':');
            if (parts.Length != count) throw new InvalidOperationException("high_school.action_value_invalid");
            return parts;
        }

        private static string[] TrainingParts(string value)
        {
            var parts = (value ?? string.Empty).Split(':');
            if (parts.Length != 2 && parts.Length != 3)
                throw new InvalidOperationException("high_school.training_payload_invalid");
            return parts;
        }

        private static void ValidateTrainingTarget(
            HighSchoolCareerSnapshot state,
            TrainingFocus focus,
            PitchType? targetPitch)
        {
            if (!targetPitch.HasValue) return;
            if (focus != TrainingFocus.BreakingBall ||
                !PitcherGrowthRules.IsOwnedBreakingBall(targetPitch.Value, state.Pitcher))
            {
                throw new InvalidOperationException("high_school.training_target_invalid");
            }
        }

        private static string PitchTitle(PitchType value)
        {
            switch (value)
            {
                case PitchType.FourSeam: return "포심";
                case PitchType.Slider: return "슬라이더";
                case PitchType.Curveball: return "커브";
                default: return "체인지업";
            }
        }

        private static string Normalize(string value)
        {
            return new string((value ?? string.Empty)
                .Where(character => character != '_' && character != '-' && !char.IsWhiteSpace(character))
                .Select(char.ToLowerInvariant)
                .ToArray());
        }

        private sealed class InternalSetterContractResolver : DefaultContractResolver
        {
            protected override JsonProperty CreateProperty(MemberInfo member, MemberSerialization serialization)
            {
                var property = base.CreateProperty(member, serialization);
                if (!property.Writable && member is PropertyInfo propertyInfo &&
                    propertyInfo.GetSetMethod(true) != null)
                {
                    property.Writable = true;
                }
                return property;
            }
        }
    }
}
