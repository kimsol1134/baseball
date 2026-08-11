using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;

namespace Baseball.Application.Tests
{
    internal sealed class FakeHighSchoolPort : IHighSchoolCareerPort
    {
        public int PitchApplyCount { get; private set; }

        public HighSchoolCareerReadModel Start(StartHighSchoolCareerRequest request)
        {
            return HighSchool(
                phase: HighSchoolPhase.Prologue,
                playerName: request.PlayerName,
                presetId: request.PresetId,
                nextSeed: request.Seed + ":1",
                revision: 1,
                difficulty: request.Difficulty,
                equippedSignatureLegacyId: request.SignatureLegacyId,
                isChallengeRun: request.IsChallenge,
                lifeNumber: request.ChallengeLifeNumber ?? request.LifeNumber,
                legacySelectionMode: request.IsChallenge
                    ? LegacySelectionMode.Memories
                    : LegacySelectionMode.SignatureLegacy);
        }

        public HighSchoolCareerReadModel Apply(
            HighSchoolCareerReadModel current,
            HighSchoolAction action)
        {
            switch (action.Kind)
            {
                case "complete_prologue":
                    return Copy(
                        current,
                        phase: HighSchoolPhase.SchoolSelection,
                        nextSeed: current.NextSeed + ":prologue");
                case "choose_school":
                    return Copy(current, phase: HighSchoolPhase.Training, schoolId: action.Value ?? "school-a");
                case "important_game":
                    return Copy(current, phase: HighSchoolPhase.ImportantGame);
                case "advance_chapter":
                    return Copy(
                        current,
                        phase: HighSchoolPhase.Training,
                        chapterNumber: current.ChapterNumber + 1,
                        schoolYear: Math.Min(3, current.SchoolYear + 1));
                case "pledge":
                    return Copy(current, pledgeDecided: true, pledgeId: action.Value ?? "pledge-a");
                case "resolve_draft":
                    var drafted = !string.Equals(action.Value, "undrafted", StringComparison.Ordinal);
                    return Copy(
                        current,
                        phase: drafted ? HighSchoolPhase.Completed : HighSchoolPhase.Legacy,
                        draft: new DraftReadModel(true, drafted, drafted ? 77 : 41, drafted ? "team-a" : null, drafted ? "한울" : null));
                case "open_legacy":
                    return Copy(current, phase: HighSchoolPhase.Legacy);
                case "select_legacy":
                    return Copy(current, phase: HighSchoolPhase.Completed);
                case "select_signature_legacy":
                    return Copy(
                        current,
                        phase: HighSchoolPhase.Completed,
                        selectedSignatureLegacyId: action.Value);
                case "complete":
                    return Copy(current, phase: HighSchoolPhase.Completed);
                default:
                    return Copy(current);
            }
        }

        public HighSchoolCareerReadModel ReservePitch(
            HighSchoolCareerReadModel current,
            string scenarioId)
        {
            return Copy(current, nextSeed: current.NextSeed + ":reserved", preserveRevision: true);
        }

        public HighSchoolCareerReadModel ApplyPitchResult(
            HighSchoolCareerReadModel current,
            PitchGameReport report)
        {
            PitchApplyCount++;
            var before = current.Performance;
            return Copy(
                current,
                phase: HighSchoolPhase.Training,
                performance: new CareerPerformanceReadModel(
                    before.ImportantGames + 1,
                    before.Pitches + report.Pitches,
                    before.Outs + report.Outs,
                    before.Strikeouts + report.Strikeouts,
                    before.Walks + report.Walks,
                    before.Hits + report.Hits,
                    before.RunsAllowed + report.RunsAllowed));
        }

        public static HighSchoolCareerReadModel HighSchool(
            HighSchoolPhase phase = HighSchoolPhase.Training,
            int lifeNumber = 1,
            string careerId = "hs-1",
            string playerId = "player-1",
            string playerName = "민서준",
            string presetId = "balanced",
            string nextSeed = "seed-1",
            ulong revision = 1,
            string schoolId = "school-a",
            int chapterNumber = 1,
            int schoolYear = 1,
            DraftReadModel draft = null,
            CareerPerformanceReadModel performance = null,
            string difficulty = "standard",
            string equippedSignatureLegacyId = null,
            bool isChallengeRun = false,
            LegacySelectionMode legacySelectionMode = LegacySelectionMode.Memories,
            IReadOnlyList<CareerChoiceReadModel> legacyMemoryChoices = null,
            int memorySlots = 0,
            IReadOnlyList<CareerChoiceReadModel> signatureLegacyChoices = null,
            bool tutorialCompleted = false,
            int tutorialAttemptCount = 0,
            HighSchoolLifeDetailReadModel lifeDetail = null)
        {
            var ratings = new PitcherRatingsReadModel(50, 49, 48, 47);
            return new HighSchoolCareerReadModel(
                careerId,
                lifeNumber,
                phase,
                nextSeed,
                revision,
                playerId,
                playerName,
                presetId,
                ratings,
                performance ?? new CareerPerformanceReadModel(),
                schoolId,
                schoolId == null ? null : "새빛고",
                schoolYear,
                chapterNumber,
                5,
                8 - chapterNumber,
                draft,
                "{\"fixture\":true}",
                difficulty: difficulty,
                equippedSignatureLegacyId: equippedSignatureLegacyId,
                isChallengeRun: isChallengeRun,
                legacySelectionMode: legacySelectionMode,
                legacyMemoryChoices: legacyMemoryChoices,
                memorySlots: memorySlots,
                signatureLegacyChoices: signatureLegacyChoices,
                tutorialCompleted: tutorialCompleted,
                tutorialAttemptCount: tutorialAttemptCount,
                lifeDetail: lifeDetail ?? new HighSchoolLifeDetailReadModel(
                    ratings,
                    coachName: "한도윤",
                    catcherName: "서지호",
                    rivalName: "강태오",
                    windId: "calm",
                    windTitle: "바람 없는 해",
                    schoolStrength: "제구"));
        }

        public static HighSchoolCareerReadModel Copy(
            HighSchoolCareerReadModel value,
            HighSchoolPhase? phase = null,
            string nextSeed = null,
            string schoolId = null,
            int? chapterNumber = null,
            int? schoolYear = null,
            DraftReadModel draft = null,
            CareerPerformanceReadModel performance = null,
            bool? pledgeDecided = null,
            string pledgeId = null,
            bool preserveRevision = false,
            string selectedSignatureLegacyId = null)
        {
            var nextPhase = phase ?? value.Phase;
            var signatureChoices = value.SignatureLegacyChoices;
            var frozenCandidates = value.FrozenSignatureLegacyCandidates;
            if (nextPhase == HighSchoolPhase.Legacy &&
                value.LegacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                signatureChoices.Count == 0)
            {
                frozenCandidates = new[]
                {
                    new SignatureLegacyReadModel(
                        "command_map", "미트 끝의 지도", "원하는 곳에 공을 놓던 궤적",
                        "고교 통산 제구와 실제 경기 기록이 남긴 궤적", 900),
                    new SignatureLegacyReadModel(
                        "power_imprint", "마운드에 남은 불꽃", "강한 공으로 승부한 감각",
                        "고교 통산 탈삼진과 최종 구위가 남긴 흔적", 800),
                    new SignatureLegacyReadModel(
                        "battery_promise", "사인 사이의 약속", "포수와 한 공씩 쌓은 믿음",
                        "고교 3년 동안 포수와 쌓은 믿음", 700)
                };
                signatureChoices = frozenCandidates.Select(candidate =>
                    new CareerChoiceReadModel(
                        candidate.Id,
                        candidate.Title,
                        candidate.Detail,
                        candidate.EvidenceSummary)).ToArray();
            }
            return new HighSchoolCareerReadModel(
                value.CareerId,
                value.LifeNumber,
                nextPhase,
                nextSeed ?? value.NextSeed,
                value.CoreRevision + (preserveRevision ? 0UL : 1UL),
                value.PlayerId,
                value.PlayerName,
                value.PresetId,
                value.Ratings,
                performance ?? value.Performance,
                schoolId ?? value.SchoolId,
                schoolId == null ? value.SchoolName : "새빛고",
                schoolYear ?? value.SchoolYear,
                chapterNumber ?? value.ChapterNumber,
                value.RemainingImportantGames,
                Math.Max(0, 8 - (chapterNumber ?? value.ChapterNumber)),
                draft ?? value.Draft,
                value.CoreStateJson,
                pledgeId ?? value.PledgeId,
                pledgeDecided ?? value.PledgeDecided,
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
                signatureChoices,
                value.EquippedSignatureLegacyId,
                selectedSignatureLegacyId ?? value.SelectedSignatureLegacyId,
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
                frozenSignatureLegacyCandidates: frozenCandidates,
                selectedSignatureLegacy: selectedSignatureLegacyId == null
                    ? value.SelectedSignatureLegacy
                    : value.SignatureLegacyChoices
                        .Where(choice => string.Equals(
                            choice.Id, selectedSignatureLegacyId, StringComparison.Ordinal))
                        .Select(choice => new SignatureLegacyReadModel(
                            choice.Id,
                            choice.Title,
                            choice.Detail,
                            choice.EffectSummary ?? choice.Detail))
                        .FirstOrDefault(),
                lifeDetail: value.LifeDetail);
        }
    }

    internal sealed class FakeProPort : IProCareerPort, IProCareerLegacyPort
    {
        public int PitchApplyCount { get; private set; }

        public ProCareerReadModel StartFromDraft(HighSchoolCareerReadModel highSchoolCareer)
        {
            return Pro(
                origin: ProCareerOrigin.HighSchool,
                phase: ProCareerPhase.ContractOffer,
                sourceHighSchoolCareerId: highSchoolCareer.CareerId,
                playerId: highSchoolCareer.PlayerId,
                playerName: highSchoolCareer.PlayerName,
                ratings: highSchoolCareer.Ratings,
                revision: 0,
                contractOffer: new ProContractOfferReadModel(
                    "team-a", "해오름", "starter", 3, 50000000));
        }

        public ProCareerReadModel StartDirect(StartDirectProRequest request)
        {
            return Pro(
                origin: ProCareerOrigin.Direct,
                sourceHighSchoolCareerId: null,
                playerName: request.PlayerName,
                teamId: request.TeamId,
                nextSeed: request.Seed + ":1");
        }

        public ProCareerReadModel Apply(ProCareerReadModel current, ProCareerAction action)
        {
            switch (action.Kind)
            {
                case "sign_contract":
                    return Copy(
                        current,
                        phase: ProCareerPhase.WeeklyPlan,
                        clearContractOffer: true);
                case "advance_week": return Copy(current, week: current.Week + 1);
                case "advance_segment": return Copy(current, week: current.Week + 3);
                case "offseason": return Copy(
                    current,
                    phase: ProCareerPhase.WeeklyPlan,
                    season: current.Season + 1,
                    week: 0);
                case "important_game": return Copy(current, phase: ProCareerPhase.ImportantGame);
                case "retire": return Copy(current, phase: ProCareerPhase.Completed, hallOfFameScore: 74, awards: 2);
                default: return Copy(current);
            }
        }

        public ProCareerReadModel ReservePitch(ProCareerReadModel current, string scenarioId)
        {
            return Copy(current, nextSeed: current.NextSeed + ":reserved", preserveRevision: true);
        }

        public ProCareerReadModel ApplyPitchResult(ProCareerReadModel current, PitchGameReport report)
        {
            PitchApplyCount++;
            var before = current.CurrentSeason;
            return Copy(
                current,
                phase: ProCareerPhase.WeeklyPlan,
                currentSeason: new CareerPerformanceReadModel(
                    before.ImportantGames + 1,
                    before.Pitches + report.Pitches,
                    before.Outs + report.Outs,
                    before.Strikeouts + report.Strikeouts,
                    before.Walks + report.Walks,
                    before.Hits + report.Hits,
                    before.RunsAllowed + report.RunsAllowed));
        }

        public IReadOnlyList<SignatureLegacyReadModel> CreateLegacyCandidates(
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro)
        {
            return new[]
            {
                new SignatureLegacyReadModel(
                    "command_map", "미트 끝의 지도", "원하는 곳에 공을 놓던 궤적",
                    "프로 통산 144경기 312탈삼진 · 프로 최종 제구 58 · 수상 2회", 900),
                new SignatureLegacyReadModel(
                    "power_imprint", "마운드에 남은 불꽃", "강한 공으로 승부한 감각",
                    "프로 통산 144경기 312탈삼진 · 프로 최종 구위 60 · 수상 2회", 800),
                new SignatureLegacyReadModel(
                    "battery_promise", "사인 사이의 약속", "포수와 한 공씩 쌓은 믿음",
                    "프로 통산 144경기 312탈삼진 · 포수와 쌓은 믿음 50", 700)
            };
        }

        public static ProCareerReadModel Pro(
            ProCareerOrigin origin = ProCareerOrigin.Direct,
            ProCareerPhase phase = ProCareerPhase.WeeklyPlan,
            string proCareerId = "pro-1",
            string sourceHighSchoolCareerId = null,
            string playerId = "player-1",
            string playerName = "민서준",
            string teamId = "team-a",
            string nextSeed = "pro-seed-1",
            ulong revision = 1,
            PitcherRatingsReadModel ratings = null,
            CareerPerformanceReadModel currentSeason = null,
            IReadOnlyList<ProSeasonLineReadModel> seasons = null,
            int hallOfFameScore = 0,
            int awards = 0,
            ProContractOfferReadModel contractOffer = null)
        {
            return new ProCareerReadModel(
                proCareerId,
                origin,
                phase,
                nextSeed,
                revision,
                playerId,
                playerName,
                teamId,
                "해오름",
                1,
                1,
                ratings ?? new PitcherRatingsReadModel(60, 58, 57, 56),
                currentSeason ?? new CareerPerformanceReadModel(),
                seasons,
                sourceHighSchoolCareerId,
                "{\"fixture\":true}",
                hallOfFameScore,
                awards,
                contractOffer: contractOffer);
        }

        public static ProCareerReadModel Copy(
            ProCareerReadModel value,
            ProCareerPhase? phase = null,
            string nextSeed = null,
            int? week = null,
            int? season = null,
            CareerPerformanceReadModel currentSeason = null,
            int? hallOfFameScore = null,
            int? awards = null,
            bool preserveRevision = false,
            bool clearContractOffer = false)
        {
            return new ProCareerReadModel(
                value.ProCareerId,
                value.Origin,
                phase ?? value.Phase,
                nextSeed ?? value.NextSeed,
                value.CoreRevision + (preserveRevision ? 0UL : 1UL),
                value.PlayerId,
                value.PlayerName,
                value.TeamId,
                value.TeamName,
                season ?? value.Season,
                week ?? value.Week,
                value.Ratings,
                currentSeason ?? value.CurrentSeason,
                value.CareerSeasons,
                value.SourceHighSchoolCareerId,
                value.CoreStateJson,
                hallOfFameScore ?? value.HallOfFameScore,
                awards ?? value.Awards,
                contractOffer: clearContractOffer ? null : value.ContractOffer);
        }
    }

    internal sealed class RecordingGameRepository : ISaveRepository<GameSaveAggregate>
    {
        public GameSaveAggregate Saved { get; private set; }
        public int SaveCount { get; private set; }
        public int ResetCount { get; private set; }
        public bool FailSave { get; set; }
        public bool FailReset { get; set; }
        public SaveLoadResult<GameSaveAggregate> LoadResult { get; set; } =
            SaveLoadResult<GameSaveAggregate>.Create(SaveLoadStatus.NoSave);

        public Task<SaveWriteResult<GameSaveAggregate>> SaveAsync(
            GameSaveAggregate payload,
            ulong revision,
            CancellationToken cancellationToken = default)
        {
            if (FailSave) throw new InvalidOperationException("disk full");
            Saved = payload;
            SaveCount++;
            return Task.FromResult<SaveWriteResult<GameSaveAggregate>>(null);
        }

        public Task<SaveLoadResult<GameSaveAggregate>> LoadAsync(
            CancellationToken cancellationToken = default)
        {
            return Task.FromResult(LoadResult);
        }

        public Task ResetAsync(CancellationToken cancellationToken = default)
        {
            if (FailReset) throw new InvalidOperationException("reset failed");
            Saved = null;
            ResetCount++;
            LoadResult = SaveLoadResult<GameSaveAggregate>.Create(SaveLoadStatus.NoSave);
            return Task.CompletedTask;
        }
    }
}
