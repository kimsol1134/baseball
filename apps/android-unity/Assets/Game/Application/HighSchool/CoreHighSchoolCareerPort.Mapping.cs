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
    public sealed partial class CoreHighSchoolCareerPort
    {
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
                LifeDetail(state, priorLifeDetail, startingRatings),
                TrainingOutlooks(state));
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
                        : "훈련 초점을 선택합니다."))
                .ToArray();
        }

        private IReadOnlyList<TrainingOutlookReadModel> TrainingOutlooks(
            HighSchoolCareerSnapshot state)
        {
            if (state.Phase != HighSchoolCareerPhase.Training)
                return Array.Empty<TrainingOutlookReadModel>();
            var values = new List<TrainingOutlookReadModel>();
            foreach (TrainingFocus focus in Enum.GetValues(typeof(TrainingFocus)))
            {
                foreach (TrainingIntensity intensity in Enum.GetValues(typeof(TrainingIntensity)))
                {
                    var outlook = _engine.TrainingOutlook(state, focus, intensity);
                    var title = OutlookTitle(outlook);
                    values.Add(new TrainingOutlookReadModel(
                        focus.Value(),
                        IntensityWire(intensity),
                        OutlookWire(outlook),
                        title,
                        OutlookSummary(outlook)));
                }
            }
            return values;
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
                    value.TargetPitch.HasValue ? value.TargetPitch.Value.Value() : null,
                    value.BloomedAbility.HasValue
                        ? TalentAbilityWire(value.BloomedAbility.Value)
                        : null,
                    value.BloomedGrade.HasValue
                        ? TalentGradeWire(value.BloomedGrade.Value)
                        : null);
        }

        private static TrainingBlockResultReadModel TrainingBlock(CareerTrainingBlockSnapshot value)
        {
            if (value == null) return null;
            var sessions = value.Sessions.Select(TrainingResult).ToArray();
            var bloom = sessions.FirstOrDefault(result =>
                !string.IsNullOrWhiteSpace(result?.BloomedAbility));
            return new TrainingBlockResultReadModel(
                value.MaximumSessions,
                value.CompletedSessions,
                value.Focus.Value(),
                IntensityWire(value.Intensity),
                value.TargetPitch.HasValue ? value.TargetPitch.Value.Value() : null,
                value.StopReason.Value(),
                value.Growth,
                value.FatigueChange,
                sessions,
                bloom?.BloomedAbility,
                bloom?.BloomedGrade);
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
    }
}
