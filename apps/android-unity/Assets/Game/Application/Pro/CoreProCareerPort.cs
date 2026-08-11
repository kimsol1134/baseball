using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Pro;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;
using AppProCareerPhase = Baseball.Application.Pro.ProCareerPhase;
using CoreProCareerPhase = Baseball.Core.Pro.ProCareerPhase;

namespace Baseball.Application.Pro
{
    /// <summary>
    /// Keeps the revisioned application save contract independent from Core's richer pro snapshot.
    /// The opaque snapshot is commitment-checked whenever a command resumes from disk.
    /// </summary>
    public sealed class CoreProCareerPort :
        IProCareerPort,
        IProPitchScenarioPort,
        IProCareerLegacyPort
    {
        private readonly ProCareerEngine _engine = new ProCareerEngine();
        private readonly JsonSerializerSettings _snapshotSettings;

        public CoreProCareerPort()
        {
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

        public ProCareerReadModel StartFromDraft(HighSchoolCareerReadModel highSchoolCareer)
        {
            if (highSchoolCareer == null) throw new ArgumentNullException(nameof(highSchoolCareer));
            if (highSchoolCareer.Draft?.Drafted != true)
                throw new InvalidOperationException("pro.draft_required");
            var source = RestoreHighSchool(highSchoolCareer);
            if (source.DraftResult?.Outcome != DraftOutcome.Drafted ||
                source.DraftResult.Team == null)
            {
                throw new InvalidOperationException("pro.core_draft_required");
            }

            var started = _engine.Start(new StartProCareerParams(
                highSchoolCareer.NextSeed,
                source.Identity,
                source.Pitcher,
                source.DraftResult,
                DevelopmentEntitlement("high-school-draft")));
            return Map(started, ProCareerOrigin.HighSchool, highSchoolCareer.CareerId);
        }

        public ProCareerReadModel StartDirect(StartDirectProRequest request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            var result = _engine.StartDirect(new StartDirectProParams(
                DeterministicSeed.Normalize(request.Seed),
                NormalizePresetId(request.PresetId),
                request.PlayerName,
                request.TeamId));
            return Map(result, ProCareerOrigin.Direct, null);
        }

        public ProCareerReadModel Apply(ProCareerReadModel current, ProCareerAction action)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (action == null || string.IsNullOrWhiteSpace(action.Kind))
                throw new ArgumentException("A pro action is required.", nameof(action));
            var state = Restore(current);
            ProCareerResult result;
            switch (Normalize(action.Kind))
            {
                case "signcontract":
                    result = _engine.SignContract(new ProStateParams(current.NextSeed, state));
                    break;
                case "advanceweek":
                case "planweek":
                    if (state.Phase == CoreProCareerPhase.SeasonDecision)
                        throw new InvalidOperationException("pro.season_decision_required");
                    var weekSelection = PlanSelection.Parse(action.Value, state, ProWeekPlan.EarnTrust);
                    result = _engine.PlanWeek(new PlanProWeekParams(
                        current.NextSeed,
                        state,
                        weekSelection.Plan,
                        weekSelection.TargetPitch));
                    break;
                case "advancesegment":
                    var segmentSelection = PlanSelection.Parse(action.Value, state, ProWeekPlan.EarnTrust);
                    var segment = _engine.AdvanceSegment(new AdvanceProSegmentParams(
                        current.NextSeed,
                        state,
                        segmentSelection.Plan,
                        segmentSelection.TargetPitch));
                    return Map(
                        segment.Career,
                        current.Origin,
                        current.SourceHighSchoolCareerId,
                        SegmentProgress(segment.Progress));
                case "seasondecision":
                case "resolveseasondecision":
                    var decision = state.PendingDecision ??
                                   throw new InvalidOperationException("pro.season_decision_missing");
                    var decisionParts = Parts(action.Value);
                    if (decisionParts.Length != 2 ||
                        !string.Equals(decisionParts[0], decision.Id, StringComparison.Ordinal) ||
                        !decision.Choices.Any(value =>
                            string.Equals(value.Id, decisionParts[1], StringComparison.Ordinal)))
                    {
                        throw new InvalidOperationException("pro.season_decision_choice_invalid");
                    }
                    result = _engine.ApplySeasonDecision(new ApplyProSeasonDecisionParams(
                        current.NextSeed,
                        state,
                        decisionParts[0],
                        decisionParts[1]));
                    break;
                case "reviewseason":
                    result = _engine.ReviewSeason(new ProStateParams(current.NextSeed, state));
                    break;
                case "offseason":
                case "continuecareer":
                    result = _engine.ChooseOffseason(new ProOffseasonParams(
                        current.NextSeed,
                        state,
                        ParseOrDefault(action.Value, OffseasonDecision.ContinueCareer)));
                    break;
                case "retire":
                    result = _engine.ChooseOffseason(new ProOffseasonParams(
                        current.NextSeed,
                        state,
                        OffseasonDecision.Retire));
                    break;
                case "normalizebalance":
                    result = _engine.NormalizeBalance(new ProStateParams(current.NextSeed, state));
                    break;
                default:
                    throw new InvalidOperationException("pro.action_unsupported:" + action.Kind);
            }
            return Map(result, current.Origin, current.SourceHighSchoolCareerId);
        }

        public ProCareerReadModel ReservePitch(ProCareerReadModel current, string scenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (string.IsNullOrWhiteSpace(scenarioId))
                throw new ArgumentException("A scenario ID is required.", nameof(scenarioId));
            // Core owns the deterministic seed wire contract; snapshot revision intentionally stays put.
            return CopyWithNextSeed(current, ProSeedReservation.Advance(current.NextSeed));
        }

        public PitchScenarioReadModel CreatePitchScenario(
            ProCareerReadModel current,
            string requestedScenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (string.IsNullOrWhiteSpace(requestedScenarioId))
                throw new ArgumentException("A requested scenario ID is required.", nameof(requestedScenarioId));
            return PitchScenarioFactory.Pro(Restore(current));
        }

        public ProCareerReadModel ApplyPitchResult(
            ProCareerReadModel current,
            PitchGameReport report)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (report == null) throw new ArgumentNullException(nameof(report));
            var state = Restore(current);
            var coreReport = new ImportantInningReport(
                (state.GameLines?.Count ?? 0) + 1,
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
            var result = _engine.ResolveImportantGame(new ResolveProGameParams(
                current.NextSeed,
                state,
                coreReport));
            return Map(result, current.Origin, current.SourceHighSchoolCareerId);
        }

        public IReadOnlyList<SignatureLegacyReadModel> CreateLegacyCandidates(
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro)
        {
            if (highSchool == null || pro == null)
                throw new ArgumentNullException(highSchool == null ? nameof(highSchool) : nameof(pro));
            var highSchoolState = RestoreHighSchool(highSchool);
            var proState = Restore(pro);
            var startingPitcher = PitcherPresetCatalog.All.FirstOrDefault(value =>
                    string.Equals(value.Id, highSchool.PresetId, StringComparison.Ordinal))
                ?.Pitcher ?? highSchoolState.Pitcher;
            var candidates = ProCareerLegacy.Candidates(
                    startingPitcher,
                    highSchoolState,
                    proState)
                .Select(value => new SignatureLegacyReadModel(
                    value.Legacy.Id.Value(),
                    value.Legacy.Title,
                    value.Legacy.Detail,
                    value.Evidence.Summary,
                    value.Score))
                .ToArray();
            if (candidates.Length != 3 ||
                candidates.Select(value => value.Id).Distinct(StringComparer.Ordinal).Count() != 3)
            {
                throw new InvalidOperationException("pro.legacy_candidates_invalid");
            }
            return candidates;
        }

        private ProCareerReadModel Map(
            ProCareerResult result,
            ProCareerOrigin origin,
            string sourceHighSchoolCareerId,
            ProSegmentProgressReadModel lastSegmentProgress = null)
        {
            if (result?.Snapshot == null) throw new InvalidOperationException("pro.core_result_missing");
            var state = result.Snapshot;
            var stats = state.CurrentStats ??
                        throw new InvalidOperationException("pro.core_stats_missing");
            var currentLines = (state.GameLines ?? Array.Empty<ProGameLine>())
                .Where(value => value.Season == state.Season)
                .ToArray();
            var career = (state.CareerStats ?? Array.Empty<ProSeasonStats>())
                .Select(SeasonLine)
                .ToArray();
            var currentRecord = PitchingRecord(stats, currentLines);
            var seasonGameLines = GameLines(state, null, false);
            var recordBook = new ProRecordBookReadModel(
                currentRecord,
                seasonGameLines,
                career,
                state.Awards,
                state.Milestones,
                DecisionHistory(state),
                state.HallOfFameScore,
                state.GameLines != null && currentLines.Length == stats.Games);
            return new ProCareerReadModel(
                state.ProCareerId,
                origin,
                Map(state.Phase),
                result.NextSeed,
                state.Revision,
                state.Pitcher.Id,
                state.Identity.Name,
                state.Team.Id,
                state.Team.Name,
                state.Season,
                state.Week,
                new PitcherRatingsReadModel(
                    state.Pitcher.Stuff,
                    state.Pitcher.Command,
                    state.Pitcher.Movement,
                    state.Pitcher.Stamina),
                new CareerPerformanceReadModel(
                    stats.Games,
                    currentRecord.Pitches ?? 0,
                    stats.InningsOuts,
                    stats.Strikeouts,
                    stats.Walks,
                    currentRecord.Hits ?? 0,
                    stats.RunsAllowed),
                career,
                sourceHighSchoolCareerId,
                JsonConvert.SerializeObject(state, Formatting.None, _snapshotSettings),
                state.HallOfFameScore ?? 0,
                state.Awards?.Count ?? 0,
                state.Level.Value(),
                state.Role.Value(),
                state.ManagerTrust,
                state.CatcherTrust,
                state.Fatigue,
                WeekPlanChoices(state),
                SeasonDecision(state),
                OffseasonChoices(state),
                LeagueStandings(state),
                LeaguePitchers(state),
                GameLines(state, 20, true),
                ContractOffer(state),
                (state.SeasonSegment ?? ProSeasonSegment.SpringCamp).Value(),
                ProCareerEngine.SegmentLabel(state.SeasonSegment ?? ProSeasonSegment.SpringCamp),
                DevelopmentProgress(state.DevelopmentProgress),
                DevelopmentPitchChoices(state),
                lastSegmentProgress,
                state.InjuryWeeks,
                recordBook);
        }

        private ProCareerSnapshot Restore(ProCareerReadModel current)
        {
            var state = Deserialize<ProCareerSnapshot>(current.CoreStateJson, "pro.core_state_missing");
            if (!string.Equals(state.ProCareerId, current.ProCareerId, StringComparison.Ordinal) ||
                state.Revision != current.CoreRevision ||
                !string.Equals(state.Commitment, _engine.Commitment(state), StringComparison.Ordinal))
            {
                throw new InvalidOperationException("pro.core_state_mismatch");
            }
            return state;
        }

        private HighSchoolCareerSnapshot RestoreHighSchool(HighSchoolCareerReadModel current)
        {
            var state = Deserialize<HighSchoolCareerSnapshot>(
                current.CoreStateJson,
                "pro.high_school_core_state_missing");
            if (!string.Equals(state.CareerId, current.CareerId, StringComparison.Ordinal) ||
                state.Revision != current.CoreRevision)
            {
                throw new InvalidOperationException("pro.high_school_core_state_mismatch");
            }
            return state;
        }

        private T Deserialize<T>(string json, string missingCode)
        {
            if (string.IsNullOrWhiteSpace(json)) throw new InvalidOperationException(missingCode);
            var value = JsonConvert.DeserializeObject<T>(json, _snapshotSettings);
            return value == null
                ? throw new InvalidOperationException(missingCode)
                : value;
        }

        private static IReadOnlyList<CareerChoiceReadModel> WeekPlanChoices(ProCareerSnapshot state)
        {
            if (state.Phase != CoreProCareerPhase.WeeklyPlan) return Array.Empty<CareerChoiceReadModel>();
            var relief = state.Role != ProRole.Starter;
            var veteran = state.Season >= 9;
            var recommendation = ProWeekRecommendationRules.Resolve(
                state.Fatigue,
                state.Level,
                state.ManagerTrust,
                state.Pitcher);
            return new[]
            {
                PlanChoice("develop_stuff", relief ? "한 타자 강속구" : veteran ? "포심 위력 다듬기" : "강속구 불펜",
                    "구위·포심 구속·헛스윙 성장 · " + ProgressText(state, ProWeekPlan.DevelopStuff), "폭발력이 큰 대신 피로가 가장 크게 쌓입니다.", ProWeekPlan.DevelopStuff, recommendation),
                PlanChoice("develop_movement", "결정구 완성",
                    "고른 변화구의 움직임·헛스윙 성장 · " + ProgressText(state, ProWeekPlan.DevelopMovement), "집중할 구종을 직접 골라야 합니다.", ProWeekPlan.DevelopMovement, recommendation),
                PlanChoice("refine_command", "코스 제구 훈련",
                    "제구·전 구종 코스 성장 · " + ProgressText(state, ProWeekPlan.RefineCommand), "성장은 안정적이고 피로 부담은 작습니다.", ProWeekPlan.RefineCommand, recommendation),
                PlanChoice("build_stamina", relief ? "연투 버티기" : "긴 이닝 루틴",
                    "후반 체감 피로가 줄어듭니다 · " + ProgressText(state, ProWeekPlan.BuildStamina), "초반 투구 위력은 바로 오르지 않습니다.", ProWeekPlan.BuildStamina, recommendation),
                PlanChoice("recover", veteran ? "베테랑 회복 루틴" : "회복", "피로가 줄고 부상 위험이 낮아집니다.", "능력이 오르지 않습니다.", ProWeekPlan.Recover, recommendation),
                PlanChoice("earn_trust", state.Level == ProLevel.Minor ? "콜업 경쟁 집중" : relief ? "필승조 신뢰 쌓기" : "로테이션 신뢰 쌓기",
                    "감독의 믿음이 오릅니다.", "능력이 오르지 않습니다.", ProWeekPlan.EarnTrust, recommendation)
            };
        }

        private static CareerChoiceReadModel PlanChoice(
            string id,
            string title,
            string detail,
            string effectSummary,
            ProWeekPlan plan,
            ProWeekRecommendation recommendation)
        {
            var recommended = recommendation.Plan == plan;
            return new CareerChoiceReadModel(
                id,
                title,
                detail,
                effectSummary,
                recommended: recommended,
                recommendationReason: recommended ? recommendation.Reason : null);
        }

        private static string ProgressText(ProCareerSnapshot state, ProWeekPlan plan)
        {
            return "현재 " + (state.DevelopmentProgress?.Value(plan) ?? 0) + "/2 · 두 번 채우면 능력 +1";
        }

        private static ProDevelopmentProgressReadModel DevelopmentProgress(ProDevelopmentProgress value)
        {
            return value == null
                ? new ProDevelopmentProgressReadModel()
                : new ProDevelopmentProgressReadModel(value.Stuff, value.Command, value.Movement, value.Stamina);
        }

        private static IReadOnlyList<CareerChoiceReadModel> DevelopmentPitchChoices(ProCareerSnapshot state)
        {
            if (state.Phase != CoreProCareerPhase.WeeklyPlan || state.Pitcher?.PitchProfiles == null)
                return Array.Empty<CareerChoiceReadModel>();
            return state.Pitcher.PitchProfiles
                .Where(value => value.PitchType != PitchType.FourSeam)
                .Select(value => new CareerChoiceReadModel(
                    value.PitchType.Value(),
                    PitchTitle(value.PitchType),
                    "결정구 완성 훈련이 이 구종에 적용됩니다."))
                .ToArray();
        }

        private static ProSegmentProgressReadModel SegmentProgress(ProSegmentProgressSnapshot value)
        {
            return value == null ? null : new ProSegmentProgressReadModel(
                value.AdvancedWeeks,
                value.StartingSegment.Value(),
                value.EndingSegment.Value(),
                SegmentStopWire(value.StopReason),
                value.Plan.Value(),
                value.TargetPitch.HasValue ? value.TargetPitch.Value.Value() : null);
        }

        private static ProContractOfferReadModel ContractOffer(ProCareerSnapshot state)
        {
            if (state.Phase != CoreProCareerPhase.ContractOffer) return null;
            return new ProContractOfferReadModel(
                state.Team.Id,
                state.Team.Name,
                ProWire.Value(ProRole.Starter),
                3,
                Math.Max(30000000, state.Pitcher.Stuff * 1000000));
        }

        private static ProSeasonDecisionReadModel SeasonDecision(ProCareerSnapshot state)
        {
            var value = state.PendingDecision;
            if (state.Phase != CoreProCareerPhase.SeasonDecision || value == null) return null;
            return new ProSeasonDecisionReadModel(
                value.Id,
                value.Title,
                value.Detail,
                value.Choices.Select(choice => new CareerChoiceReadModel(
                    choice.Id,
                    choice.Title,
                    choice.Detail,
                    choice.Effect?.Summary,
                    payload: value.Id + "|" + choice.Id)).ToArray());
        }

        private static IReadOnlyList<CareerChoiceReadModel> OffseasonChoices(ProCareerSnapshot state)
        {
            if (state.Phase != CoreProCareerPhase.OffseasonDecision &&
                state.Phase != CoreProCareerPhase.RetirementDecision)
            {
                return Array.Empty<CareerChoiceReadModel>();
            }

            var forced = state.Phase == CoreProCareerPhase.RetirementDecision;
            var serviceAfterSeason = state.ServiceYears + (state.Level == ProLevel.Major ? 1 : 0);
            return new[]
            {
                new CareerChoiceReadModel(
                    "continue_career", "현 소속팀에서 계속", "다음 시즌 계약과 역할 경쟁을 이어 갑니다.",
                    enabled: !forced,
                    disabledReason: forced ? "12시즌 또는 은퇴 연령에 도달했습니다." : null),
                new CareerChoiceReadModel(
                    "military_service", "군 복무", "두 시즌을 보내고 복귀합니다.",
                    enabled: !forced && !state.MilitaryCompleted,
                    disabledReason: forced ? "은퇴 결정만 남았습니다." : state.MilitaryCompleted ? "이미 군 복무를 마쳤습니다." : null,
                    payload: "military_service"),
                new CareerChoiceReadModel(
                    "free_agency", "FA 신청", "다른 가상 구단에서 새 도전을 시작합니다.",
                    enabled: !forced && serviceAfterSeason >= 6,
                    disabledReason: forced ? "은퇴 결정만 남았습니다." : serviceAfterSeason < 6 ? "1군 등록 6년이 필요합니다." : null,
                    payload: "free_agency"),
                new CareerChoiceReadModel("retire", "은퇴", "통산 기록을 확정하고 이번 삶을 마칩니다.")
            };
        }

        private static IReadOnlyList<LeagueStandingReadModel> LeagueStandings(ProCareerSnapshot state)
        {
            var lines = (state.GameLines ?? Array.Empty<ProGameLine>())
                .Select(value => new LeagueTable.PlayerGameResult(value.TeamRuns, value.OpponentRuns))
                .ToArray();
            var rows = LeagueTable.Standings(
                    state.Season,
                    state.ProCareerId,
                    LeagueTable.GamesPlayed(state.Week),
                    state.Team.Id,
                    lines)
                .ToArray();
            if (rows.Length == 0) return Array.Empty<LeagueStandingReadModel>();
            var leader = rows[0];
            return rows.Select((value, index) => new LeagueStandingReadModel(
                index + 1,
                value.TeamId,
                value.TeamName,
                value.Wins,
                value.Losses,
                value.Draws,
                LeagueTable.GamesBehind(value, leader),
                string.Equals(value.TeamId, state.Team.Id, StringComparison.Ordinal))).ToArray();
        }

        private static ProSeasonLineReadModel SeasonLine(ProSeasonStats value)
        {
            return new ProSeasonLineReadModel(
                value.Season,
                value.TeamId,
                value.Games,
                value.InningsOuts,
                value.Strikeouts,
                value.Walks,
                value.RunsAllowed,
                wins: value.Wins,
                losses: value.Losses,
                saves: value.Saves,
                starts: value.Starts,
                hits: value.Hits,
                homeRuns: value.HomeRuns,
                pitches: value.Pitches,
                qualityStarts: value.QualityStarts);
        }

        private static PitchingRecordReadModel PitchingRecord(
            ProSeasonStats stats,
            IReadOnlyList<ProGameLine> gameLines)
        {
            var lines = (gameLines ?? Array.Empty<ProGameLine>()).ToArray();
            var completeLog = lines.Length == stats.Games;
            var hits = stats.Hits ?? (completeLog ? KnownSum(lines.Select(value => value.Hits)) : null);
            var homeRuns = stats.HomeRuns ??
                           (completeLog ? KnownSum(lines.Select(value => value.HomeRuns)) : null);
            var pitches = stats.Pitches ??
                          (completeLog ? lines.Sum(value => value.Pitches) : (int?)null);
            var qualityStarts = stats.QualityStarts ??
                                (completeLog
                                    ? lines.Count(value => PitchingMetrics.IsQualityStart(
                                        value.Started, value.Outs, value.RunsAllowed))
                                    : (int?)null);
            return new PitchingRecordReadModel(
                stats.Games,
                stats.Starts,
                stats.InningsOuts,
                stats.Strikeouts,
                stats.Walks,
                stats.RunsAllowed,
                stats.Wins,
                stats.Losses,
                stats.Saves,
                hits,
                homeRuns,
                pitches,
                qualityStarts);
        }

        private static IReadOnlyList<ProDecisionHistoryReadModel> DecisionHistory(
            ProCareerSnapshot state)
        {
            return (state.DecisionHistory ?? Array.Empty<ProDecisionRecord>())
                .Select(value => new ProDecisionHistoryReadModel(
                    value.DecisionId,
                    value.Type.Value(),
                    value.Season,
                    value.Week,
                    value.ChoiceId,
                    value.ChoiceTitle,
                    value.Effect.Summary,
                    value.Effect.StuffDelta,
                    value.Effect.CommandDelta,
                    value.Effect.MovementDelta,
                    value.Effect.StaminaDelta,
                    value.Effect.ManagerTrustDelta,
                    value.Effect.CatcherTrustDelta,
                    value.Effect.FatigueDelta,
                    value.Effect.RoleTarget.HasValue
                        ? value.Effect.RoleTarget.Value.Value()
                        : null))
                .ToArray();
        }

        private static int? KnownSum(IEnumerable<int?> values)
        {
            var items = values.ToArray();
            return items.All(value => value.HasValue)
                ? items.Sum(value => value.Value)
                : (int?)null;
        }

        private static IReadOnlyList<LeaguePitcherReadModel> LeaguePitchers(ProCareerSnapshot state)
        {
            var stats = state.CurrentStats;
            var gameLines = state.GameLines ?? Array.Empty<ProGameLine>();
            var record = PitchingRecord(stats, gameLines);
            var player = new LeagueTable.PitcherRow(
                state.Identity.Name,
                state.Team.Name,
                stats.InningsOuts,
                stats.Wins,
                stats.Losses,
                stats.Saves,
                stats.Strikeouts,
                stats.Walks,
                record.Hits ?? 0,
                record.HomeRuns ?? 0,
                stats.RunsAllowed,
                true);
            return LeagueTable.Pitchers(
                    state.Season,
                    state.ProCareerId,
                    LeagueTable.GamesPlayed(state.Week),
                    player)
                .Take(20)
                .Select((value, index) => new LeaguePitcherReadModel(
                    index + 1,
                    value.Name,
                    value.TeamName,
                    value.InningsOuts,
                    value.Wins,
                    value.Losses,
                    value.Saves,
                    value.Strikeouts,
                    value.Walks,
                    value.IsPlayer ? record.Hits : value.Hits,
                    value.RunsAllowed,
                    value.IsPlayer,
                    value.IsPlayer ? record.HomeRuns : value.HomeRuns,
                    value.IsPlayer ? record.Hits : value.Hits))
                .ToArray();
        }

        private static IReadOnlyList<CareerGameLineReadModel> GameLines(
            ProCareerSnapshot state,
            int? maximum,
            bool newestFirst)
        {
            IEnumerable<ProGameLine> source = (state.GameLines ?? Array.Empty<ProGameLine>())
                .Where(value => value.Season == state.Season);
            source = newestFirst
                ? source.OrderByDescending(value => value.OutingNumber)
                : source.OrderBy(value => value.OutingNumber);
            var lines = source.Select(value => new CareerGameLineReadModel(
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
                    value.Hits));
            return (maximum.HasValue ? lines.Take(maximum.Value) : lines)
                .ToArray();
        }

        private static ProCareerReadModel CopyWithNextSeed(
            ProCareerReadModel value,
            string nextSeed)
        {
            return new ProCareerReadModel(
                value.ProCareerId,
                value.Origin,
                value.Phase,
                nextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.TeamId,
                value.TeamName,
                value.Season,
                value.Week,
                value.Ratings,
                value.CurrentSeason,
                value.CareerSeasons,
                value.SourceHighSchoolCareerId,
                value.CoreStateJson,
                value.HallOfFameScore,
                value.Awards,
                value.Level,
                value.Role,
                value.ManagerTrust,
                value.CatcherTrust,
                value.Fatigue,
                value.WeekPlanChoices,
                value.SeasonDecision,
                value.OffseasonChoices,
                value.LeagueStandings,
                value.LeaguePitchers,
                value.RecentGameLines,
                value.ContractOffer,
                value.SeasonSegment,
                value.SeasonSegmentTitle,
                value.DevelopmentProgress,
                value.DevelopmentPitchChoices,
                value.LastSegmentProgress,
                value.InjuryWeeks,
                value.RecordBook);
        }

        private static AppProCareerPhase Map(CoreProCareerPhase value)
        {
            switch (value)
            {
                case CoreProCareerPhase.ContractOffer:
                    return AppProCareerPhase.ContractOffer;
                case CoreProCareerPhase.ImportantGame:
                    return AppProCareerPhase.ImportantGame;
                case CoreProCareerPhase.SeasonDecision:
                    return AppProCareerPhase.SeasonDecision;
                case CoreProCareerPhase.SeasonReview:
                    return AppProCareerPhase.SeasonReview;
                case CoreProCareerPhase.OffseasonDecision:
                    return AppProCareerPhase.Offseason;
                case CoreProCareerPhase.RetirementDecision:
                    return AppProCareerPhase.RetirementDecision;
                case CoreProCareerPhase.Completed:
                    return AppProCareerPhase.Completed;
                default:
                    return AppProCareerPhase.WeeklyPlan;
            }
        }

        private static ProEntitlementSnapshot DevelopmentEntitlement(string source)
        {
            return new ProEntitlementSnapshot(
                EntitlementStatus.Active,
                EntitlementSource.Development,
                source);
        }

        private static string NormalizePresetId(string value)
        {
            switch (Normalize(value))
            {
                case "power": return "power_prospect";
                case "command": return "precision_commander";
                case "artist": return "breaking_ball_artist";
                case "stamina": return "innings_eater";
                default: return value;
            }
        }

        private static T ParseOrDefault<T>(string value, T fallback) where T : struct
        {
            if (string.IsNullOrWhiteSpace(value)) return fallback;
            var normalized = Normalize(value);
            foreach (T candidate in Enum.GetValues(typeof(T)))
            {
                if (Normalize(candidate.ToString()) == normalized) return candidate;
            }
            throw new InvalidOperationException("pro.enum_invalid:" + typeof(T).Name);
        }

        private static string[] Parts(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return Array.Empty<string>();
            return value.Split(new[] { '|', ':' }, StringSplitOptions.RemoveEmptyEntries);
        }

        private static string Normalize(string value)
        {
            return new string((value ?? string.Empty)
                .Where(character => character != '_' && character != '-' && !char.IsWhiteSpace(character))
                .Select(char.ToLowerInvariant)
                .ToArray());
        }

        private sealed class PlanSelection
        {
            private PlanSelection(ProWeekPlan plan, PitchType? targetPitch)
            { Plan = plan; TargetPitch = targetPitch; }

            public ProWeekPlan Plan { get; }
            public PitchType? TargetPitch { get; }

            public static PlanSelection Parse(
                string payload,
                ProCareerSnapshot state,
                ProWeekPlan fallback)
            {
                var parts = Parts(payload);
                if (parts.Length == 0) return new PlanSelection(fallback, null);
                if (parts.Length > 2) throw new InvalidOperationException("pro.week_plan_payload_invalid");
                var plan = ParseOrDefault(parts[0], fallback);
                var target = parts.Length == 2 ? (PitchType?)ParseOrDefault(parts[1], PitchType.FourSeam) : null;
                if (target.HasValue &&
                    (target.Value == PitchType.FourSeam ||
                     plan != ProWeekPlan.DevelopMovement && plan != ProWeekPlan.DevelopWeapon ||
                     !PitcherGrowthRules.IsOwnedBreakingBall(target.Value, state.Pitcher)))
                {
                    throw new InvalidOperationException("pro.development_pitch_invalid");
                }
                return new PlanSelection(plan, target);
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

        private static string SegmentStopWire(ProSegmentStopReason value)
        {
            switch (value)
            {
                case ProSegmentStopReason.SegmentChanged: return "segment_changed";
                case ProSegmentStopReason.PhaseChanged: return "phase_changed";
                case ProSegmentStopReason.RoleChanged: return "role_changed";
                case ProSegmentStopReason.LevelChanged: return "level_changed";
                case ProSegmentStopReason.Injury: return "injury";
                default: return "maximum_weeks";
            }
        }

        private sealed class InternalSetterContractResolver : DefaultContractResolver
        {
            protected override JsonProperty CreateProperty(
                MemberInfo member,
                MemberSerialization serialization)
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
