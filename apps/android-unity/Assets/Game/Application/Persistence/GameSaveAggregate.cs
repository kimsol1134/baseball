using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Pro;
using Baseball.Application.Stores;

namespace Baseball.Application.Persistence
{
    public enum ApplicationStage
    {
        Opening,
        Setup,
        HighSchool,
        Draft,
        Pro,
        Retirement,
        Legacy,
        BetweenLives,
        Deleted
    }

    public enum PitchCareerKind
    {
        HighSchool = 0,
        Pro = 1,
        Daily = 2,
        Tutorial = 3
    }

    public sealed class PitchResumeState
    {
        public PitchResumeState(
            string gameId,
            PitchCareerKind careerKind,
            string careerId,
            string scenarioId,
            string sessionSeed,
            int maximumBatters,
            int completedBatters = 0,
            string checkpointJson = null,
            PitchScenarioReadModel scenario = null,
            PitchGameReport accumulatedReport = null,
            CommittedPitchResultState committedPitch = null,
            IReadOnlyList<string> consumedPitchIds = null,
            bool awaitingCompletion = false,
            PitchSessionMetricsState metrics = null)
        {
            GameId = gameId;
            CareerKind = careerKind;
            CareerId = careerId;
            ScenarioId = scenarioId;
            SessionSeed = sessionSeed;
            MaximumBatters = maximumBatters;
            CompletedBatters = completedBatters;
            CheckpointJson = checkpointJson;
            Scenario = scenario;
            AccumulatedReport = accumulatedReport;
            CommittedPitch = committedPitch;
            ConsumedPitchIds = (consumedPitchIds ?? Array.Empty<string>())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            AwaitingCompletion = awaitingCompletion;
            Metrics = metrics ?? PitchSessionMetricsState.Empty;
        }

        public string GameId { get; }
        public PitchCareerKind CareerKind { get; }
        public string CareerId { get; }
        public string ScenarioId { get; }
        public string SessionSeed { get; }
        public int MaximumBatters { get; }
        public int CompletedBatters { get; }
        public string CheckpointJson { get; }
        public PitchScenarioReadModel Scenario { get; }
        public PitchGameReport AccumulatedReport { get; }
        public CommittedPitchResultState CommittedPitch { get; }
        public IReadOnlyList<string> ConsumedPitchIds { get; }
        /// <summary>True after a terminal pitch is consumed but before career/meta completion commits.</summary>
        public bool AwaitingCompletion { get; }
        public PitchSessionMetricsState Metrics { get; }
    }

    public sealed class PendingPitchCompletion
    {
        public PendingPitchCompletion(
            string completionId,
            PitchCareerKind careerKind,
            string careerId,
            PitchGameReport report,
            long completedAtUnixSeconds)
        {
            CompletionId = completionId;
            CareerKind = careerKind;
            CareerId = careerId;
            Report = report;
            CompletedAtUnixSeconds = completedAtUnixSeconds;
        }

        public string CompletionId { get; }
        public PitchCareerKind CareerKind { get; }
        public string CareerId { get; }
        public PitchGameReport Report { get; }
        public long CompletedAtUnixSeconds { get; }
    }

    /// <summary>
    /// The only Android save payload. Cross-feature effects share one revision so there is no
    /// career/weekly/achievement half-state to repair after process death.
    /// </summary>
    public sealed class GameSaveAggregate : IStoreSnapshot
    {
        public const int CurrentAggregateVersion = 3;

        public GameSaveAggregate(
            int aggregateVersion,
            ulong revision,
            string installId,
            ApplicationStage stage,
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro,
            MetaProgressState meta,
            PitchResumeState pitchResume,
            PendingPitchCompletion pendingPitchCompletion,
            IReadOnlyList<string> commandReceipts,
            bool deleted = false,
            GameSettingsState settings = null,
            AnalyticsReceiptState analyticsReceipts = null)
        {
            AggregateVersion = aggregateVersion;
            Revision = revision;
            InstallId = installId;
            Stage = stage;
            HighSchool = highSchool;
            Pro = pro;
            Meta = meta ?? MetaProgressState.Initial;
            PitchResume = pitchResume;
            PendingPitchCompletion = pendingPitchCompletion;
            Settings = settings ?? GameSettingsState.Default;
            AnalyticsReceipts = analyticsReceipts ?? AnalyticsReceiptState.Empty;
            CommandReceipts = (commandReceipts ?? Array.Empty<string>())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
            Deleted = deleted;
        }

        public int AggregateVersion { get; }
        public ulong Revision { get; }
        public string InstallId { get; }
        public ApplicationStage Stage { get; }
        public HighSchoolCareerReadModel HighSchool { get; }
        public ProCareerReadModel Pro { get; }
        public MetaProgressState Meta { get; }
        public PitchResumeState PitchResume { get; }
        public PendingPitchCompletion PendingPitchCompletion { get; }
        public GameSettingsState Settings { get; }
        public AnalyticsReceiptState AnalyticsReceipts { get; }
        public IReadOnlyList<string> CommandReceipts { get; }
        public bool Deleted { get; }

        public bool HasCommandReceipt(string commandId)
        {
            return !string.IsNullOrWhiteSpace(commandId) &&
                CommandReceipts.Contains(commandId, StringComparer.Ordinal);
        }

        public static GameSaveAggregate Initial(string installId)
        {
            return new GameSaveAggregate(
                CurrentAggregateVersion,
                0,
                installId,
                ApplicationStage.Opening,
                null,
                null,
                MetaProgressState.Initial,
                null,
                null,
                Array.Empty<string>());
        }

        public GameSaveAggregate Commit(
            string commandId,
            ApplicationStage? stage = null,
            HighSchoolCareerReadModel highSchool = null,
            bool clearHighSchool = false,
            ProCareerReadModel pro = null,
            bool clearPro = false,
            MetaProgressState meta = null,
            PitchResumeState pitchResume = null,
            bool clearPitchResume = false,
            PendingPitchCompletion pendingPitchCompletion = null,
            bool clearPendingPitchCompletion = false,
            GameSettingsState settings = null,
            AnalyticsReceiptState analyticsReceipts = null,
            bool? deleted = null,
            int? aggregateVersion = null)
        {
            if (Revision == ulong.MaxValue)
            {
                throw new InvalidOperationException("save.revision_exhausted");
            }

            return new GameSaveAggregate(
                aggregateVersion ?? AggregateVersion,
                Revision + 1,
                InstallId,
                stage ?? Stage,
                clearHighSchool ? null : highSchool ?? HighSchool,
                clearPro ? null : pro ?? Pro,
                meta ?? Meta,
                clearPitchResume ? null : pitchResume ?? PitchResume,
                clearPendingPitchCompletion
                    ? null
                    : pendingPitchCompletion ?? PendingPitchCompletion,
                CommandReceipts.Concat(new[] { commandId }).ToArray(),
                deleted ?? Deleted,
                settings ?? Settings,
                analyticsReceipts ?? AnalyticsReceipts);
        }
    }

    public sealed class GameSaveValidator : ISavePayloadValidator<GameSaveAggregate>
    {
        public SaveValidationResult Validate(GameSaveAggregate value)
        {
            if (value == null) return SaveValidationResult.Invalid("aggregate.null");
            if (value.AggregateVersion < 0 ||
                value.AggregateVersion > GameSaveAggregate.CurrentAggregateVersion)
            {
                return SaveValidationResult.Invalid("aggregate.version");
            }
            if (string.IsNullOrWhiteSpace(value.InstallId))
                return SaveValidationResult.Invalid("aggregate.install_id");
            if (value.Meta == null) return SaveValidationResult.Invalid("aggregate.meta");
            if (!DailyInningRules.IsValid(value.Meta.Daily))
                return SaveValidationResult.Invalid("aggregate.daily_inning");
            if (!ValidSignatureLegacy(value.HighSchool))
                return SaveValidationResult.Invalid("aggregate.signature_legacy");
            if (!ValidHighSchoolLifeDetail(value.HighSchool?.LifeDetail))
                return SaveValidationResult.Invalid("aggregate.high_school_life_detail");
            if (!ValidCareerGameLines(value.HighSchool?.GameLines) ||
                !ValidProRecordBook(value.Pro))
            {
                return SaveValidationResult.Invalid("aggregate.pitching_records");
            }
            if (value.Meta.ReturnPlan != null && !ReturnPlanRules.IsValid(value.Meta.ReturnPlan))
                return SaveValidationResult.Invalid("aggregate.return_plan");
            if (value.Meta.ReturnWelcomeHandled != null &&
                !ReturnPlanRules.IsValid(value.Meta.ReturnWelcomeHandled))
            {
                return SaveValidationResult.Invalid("aggregate.return_welcome_handled");
            }
            if (value.Meta.LifeArchive.Any(record =>
                    record == null ||
                    record.PlayerLegacy != null &&
                    !PlayerLegacyRules.IsValid(record.PlayerLegacy) ||
                    record != null && !ValidLifeArchiveDetail(record)))
            {
                return SaveValidationResult.Invalid("aggregate.player_legacy");
            }
            if (value.Settings == null ||
                value.Settings.SchemaVersion != GameSettingsState.CurrentSchemaVersion)
            {
                return SaveValidationResult.Invalid("aggregate.settings");
            }
            if (!AnalyticsReceiptRules.IsValid(value.AnalyticsReceipts))
                return SaveValidationResult.Invalid("aggregate.analytics_receipts");
            if (value.CommandReceipts.Any(string.IsNullOrWhiteSpace) ||
                value.CommandReceipts.Distinct(StringComparer.Ordinal).Count() !=
                value.CommandReceipts.Count)
            {
                return SaveValidationResult.Invalid("aggregate.receipts");
            }
            if (value.Deleted != (value.Stage == ApplicationStage.Deleted))
                return SaveValidationResult.Invalid("aggregate.tombstone_stage");
            if (value.PitchResume != null && value.PendingPitchCompletion != null)
                return SaveValidationResult.Invalid("aggregate.pitch_overlap");
            if (value.PitchResume != null && value.PitchResume.MaximumBatters <= 0)
                return SaveValidationResult.Invalid("aggregate.pitch_maximum_batters");
            if (value.PitchResume != null)
            {
                var resume = value.PitchResume;
                if (resume.CompletedBatters < 0 || resume.CompletedBatters > resume.MaximumBatters)
                    return SaveValidationResult.Invalid("aggregate.pitch_completed_batters");
                if (resume.Scenario != null &&
                    (resume.Scenario.SchemaVersion != PitchScenarioReadModel.CurrentSchemaVersion ||
                     !string.Equals(resume.ScenarioId, resume.Scenario.ScenarioId, StringComparison.Ordinal) ||
                     resume.Scenario.Pitcher == null || resume.Scenario.Scouting == null ||
                     resume.Scenario.GameState == null || resume.Scenario.Lineup.Count < resume.MaximumBatters ||
                     resume.Scenario.MaximumBatters != resume.MaximumBatters ||
                     resume.Scenario.MaximumPitches.HasValue && resume.Scenario.MaximumPitches.Value <= 0))
                {
                    return SaveValidationResult.Invalid("aggregate.pitch_scenario");
                }
                if (resume.AccumulatedReport != null &&
                    (!string.Equals(resume.GameId, resume.AccumulatedReport.GameId, StringComparison.Ordinal) ||
                     resume.AccumulatedReport.Batters != resume.CompletedBatters))
                {
                    return SaveValidationResult.Invalid("aggregate.pitch_accumulated_report");
                }
                if (resume.CommittedPitch != null &&
                    (resume.CommittedPitch.BatterIndex != resume.CompletedBatters ||
                     string.IsNullOrWhiteSpace(resume.CommittedPitch.PitchId) ||
                     string.IsNullOrWhiteSpace(resume.CommittedPitch.EventHash) ||
                     string.IsNullOrWhiteSpace(resume.CommittedPitch.KernelResultJson) ||
                     string.IsNullOrWhiteSpace(resume.CommittedPitch.PresentationJson) ||
                     resume.CommittedPitch.SequenceTag.HasValue &&
                         resume.CommittedPitch.SequencePitch == null ||
                     resume.CommittedPitch.SequenceTag.HasValue &&
                         !Enum.IsDefined(
                             typeof(Baseball.Core.Pitching.PitchSequenceTag),
                             resume.CommittedPitch.SequenceTag.Value) ||
                     resume.CommittedPitch.SequencePitch != null &&
                         !ValidSequencePitch(resume.CommittedPitch.SequencePitch) ||
                     resume.CommittedPitch.Delivery != null &&
                         (resume.CommittedPitch.Delivery.ReleaseAccuracy < 0 ||
                          resume.CommittedPitch.Delivery.ReleaseAccuracy > 1000 ||
                          resume.CommittedPitch.Delivery.AimAccuracy < 0 ||
                          resume.CommittedPitch.Delivery.AimAccuracy > 1000) ||
                     !string.IsNullOrWhiteSpace(resume.CommittedPitch.AbilityMomentType) &&
                         !Baseball.Core.Pitching.PitchAbilityWire.IsValid(
                             resume.CommittedPitch.AbilityMomentType) ||
                     resume.ConsumedPitchIds.Contains(
                         resume.CommittedPitch.PitchId, StringComparer.Ordinal)))
                {
                    return SaveValidationResult.Invalid("aggregate.pitch_committed_result");
                }
                if (resume.ConsumedPitchIds.Any(string.IsNullOrWhiteSpace) ||
                    resume.ConsumedPitchIds.Distinct(StringComparer.Ordinal).Count() !=
                    resume.ConsumedPitchIds.Count ||
                    resume.Scenario?.MaximumPitches is int maximumPitches &&
                    resume.ConsumedPitchIds.Count > maximumPitches)
                {
                    return SaveValidationResult.Invalid("aggregate.pitch_consumed_ids");
                }
                if (resume.AwaitingCompletion &&
                    (resume.CommittedPitch != null || resume.AccumulatedReport == null ||
                     resume.ConsumedPitchIds.Count == 0))
                {
                    return SaveValidationResult.Invalid("aggregate.pitch_awaiting_completion");
                }
                if (!ValidPitchMetrics(resume.Metrics, resume.Scenario?.MaximumPitches))
                    return SaveValidationResult.Invalid("aggregate.pitch_metrics");
                if (resume.AccumulatedReport != null &&
                    !ReportMatchesMetrics(resume.AccumulatedReport, resume.Metrics))
                    return SaveValidationResult.Invalid("aggregate.pitch_report_metrics");
            }
            if (value.Stage == ApplicationStage.HighSchool && value.HighSchool == null)
                return SaveValidationResult.Invalid("aggregate.high_school_missing");
            if (value.Stage == ApplicationStage.Pro && value.Pro == null)
                return SaveValidationResult.Invalid("aggregate.pro_missing");
            return SaveValidationResult.Success;
        }

        private static bool ValidSignatureLegacy(HighSchoolCareerReadModel highSchool)
        {
            if (highSchool == null) return true;
            var candidates = highSchool.FrozenSignatureLegacyCandidates;
            if (candidates == null || candidates.Any(value =>
                    value == null || string.IsNullOrWhiteSpace(value.Id) ||
                    string.IsNullOrWhiteSpace(value.Title) ||
                    string.IsNullOrWhiteSpace(value.Detail) ||
                    string.IsNullOrWhiteSpace(value.EvidenceSummary) ||
                    value.Score.HasValue && value.Score.Value < 0) ||
                candidates.Select(value => value.Id).Distinct(StringComparer.Ordinal).Count() !=
                candidates.Count)
            {
                return false;
            }
            var selected = highSchool.SelectedSignatureLegacy;
            if (selected == null) return true;
            return !string.IsNullOrWhiteSpace(highSchool.SelectedSignatureLegacyId) &&
                string.Equals(selected.Id, highSchool.SelectedSignatureLegacyId, StringComparison.Ordinal) &&
                !string.IsNullOrWhiteSpace(selected.Title) &&
                !string.IsNullOrWhiteSpace(selected.Detail) &&
                !string.IsNullOrWhiteSpace(selected.EvidenceSummary) &&
                (candidates.Count == 0 || candidates.Any(value =>
                    string.Equals(value.Id, selected.Id, StringComparison.Ordinal)));
        }

        private static bool ValidLifeArchiveDetail(LifeArchiveRecord record)
        {
            if (record.Pitches.HasValue && record.Pitches.Value < 0 ||
                record.Outs.HasValue && record.Outs.Value < 0 ||
                record.Hits.HasValue && record.Hits.Value < 0 ||
                record.DraftTeamName != null && string.IsNullOrWhiteSpace(record.DraftTeamName))
            {
                return false;
            }
            if (!ValidHighSchoolLifeDetail(record.HighSchoolDetail)) return false;
            var candidates = record.SignatureLegacyCandidates;
            if (candidates == null || candidates.Count != 0 && candidates.Count != 3 ||
                candidates.Any(value => !ValidSignatureCandidate(value)) ||
                candidates.Select(value => value.Id).Distinct(StringComparer.Ordinal).Count() !=
                    candidates.Count)
            {
                return false;
            }
            var selected = record.SignatureLegacy;
            return selected == null
                ? candidates.Count == 0
                : ValidSignatureCandidate(selected) && candidates.Any(value =>
                    string.Equals(value.Id, selected.Id, StringComparison.Ordinal) &&
                    string.Equals(value.EvidenceSummary, selected.EvidenceSummary, StringComparison.Ordinal));
        }

        private static bool ValidSignatureCandidate(SignatureLegacyReadModel value)
        {
            return value != null && !string.IsNullOrWhiteSpace(value.Id) &&
                !string.IsNullOrWhiteSpace(value.Title) &&
                !string.IsNullOrWhiteSpace(value.Detail) &&
                !string.IsNullOrWhiteSpace(value.EvidenceSummary) &&
                (!value.Score.HasValue || value.Score.Value >= 0);
        }

        private static bool ValidHighSchoolLifeDetail(HighSchoolLifeDetailReadModel detail)
        {
            return detail == null ||
                detail.Nicknames != null && detail.Chronicle != null &&
                detail.ResponseTally != null && detail.Talents != null &&
                !detail.Nicknames.Any(string.IsNullOrWhiteSpace) &&
                !detail.Chronicle.Any(string.IsNullOrWhiteSpace) &&
                detail.ResponseTally.Listen >= 0 && detail.ResponseTally.Explain >= 0 &&
                detail.ResponseTally.Challenge >= 0 &&
                (detail.StartingRatings == null || ValidRatings(detail.StartingRatings)) &&
                (detail.Talents.Count == 0 || detail.Talents.Count == 4) &&
                !detail.Talents.Any(value => value == null ||
                    string.IsNullOrWhiteSpace(value.AbilityId) ||
                    string.IsNullOrWhiteSpace(value.AbilityTitle) ||
                    string.IsNullOrWhiteSpace(value.GradeId) ||
                    string.IsNullOrWhiteSpace(value.GradeTitle)) &&
                detail.Talents.Select(value => value.AbilityId)
                    .Distinct(StringComparer.Ordinal).Count() == detail.Talents.Count;
        }

        private static bool ValidProRecordBook(ProCareerReadModel pro)
        {
            if (pro == null || pro.RecordBook == null) return true;
            var book = pro.RecordBook;
            return ValidPitchingRecord(book.CurrentSeason) &&
                ValidCareerGameLines(book.SeasonGameLines) &&
                (!book.SeasonGameLinesAvailable ||
                 CurrentRecordMatchesLines(book)) &&
                book.CareerSeasons != null && book.CareerSeasons.All(value =>
                    value != null && value.Season > 0 && value.Games >= 0 &&
                    value.InningsOuts >= 0 && value.Strikeouts >= 0 &&
                    value.Walks >= 0 && value.RunsAllowed >= 0 &&
                    value.Wins >= 0 && value.Losses >= 0 && value.Saves >= 0 &&
                    (!value.Starts.HasValue || value.Starts.Value >= 0 &&
                     value.Starts.Value <= value.Games) &&
                    (!value.Hits.HasValue || value.Hits.Value >= 0) &&
                    (!value.HomeRuns.HasValue || value.HomeRuns.Value >= 0) &&
                    (!value.Hits.HasValue || !value.HomeRuns.HasValue ||
                     value.HomeRuns.Value <= value.Hits.Value) &&
                    (!value.Pitches.HasValue || value.Pitches.Value >= 0) &&
                    (!value.QualityStarts.HasValue || value.QualityStarts.Value >= 0 &&
                     (!value.Starts.HasValue || value.QualityStarts.Value <= value.Starts.Value))) &&
                book.AwardNames != null && !book.AwardNames.Any(string.IsNullOrWhiteSpace) &&
                book.Milestones != null && !book.Milestones.Any(string.IsNullOrWhiteSpace) &&
                book.DecisionHistory != null && book.DecisionHistory.All(value =>
                    value != null && !string.IsNullOrWhiteSpace(value.DecisionId) &&
                    !string.IsNullOrWhiteSpace(value.TypeId) && value.Season > 0 &&
                    value.Week >= 0 && !string.IsNullOrWhiteSpace(value.ChoiceId) &&
                    !string.IsNullOrWhiteSpace(value.ChoiceTitle) &&
                    !string.IsNullOrWhiteSpace(value.EffectSummary)) &&
                (!book.HallOfFameScore.HasValue ||
                 book.HallOfFameScore.Value >= 0 && book.HallOfFameScore.Value <= 100);
        }

        private static bool CurrentRecordMatchesLines(ProRecordBookReadModel book)
        {
            if (book.SeasonGameLines.Count != book.CurrentSeason.Games) return false;
            var projected = PitchingRecordReadModel.FromGameLines(book.SeasonGameLines);
            var current = book.CurrentSeason;
            return projected.Starts == current.Starts && projected.Outs == current.Outs &&
                projected.Strikeouts == current.Strikeouts && projected.Walks == current.Walks &&
                projected.RunsAllowed == current.RunsAllowed && projected.Wins == current.Wins &&
                projected.Losses == current.Losses && projected.Saves == current.Saves &&
                projected.Hits == current.Hits && projected.HomeRuns == current.HomeRuns &&
                projected.Pitches == current.Pitches &&
                projected.QualityStarts == current.QualityStarts;
        }

        private static bool ValidCareerGameLines(IReadOnlyList<CareerGameLineReadModel> lines)
        {
            return lines == null || lines.All(value => value != null &&
                value.Season >= 0 && value.Week >= 0 && value.OutingNumber > 0 &&
                value.Outs >= 0 && value.Strikeouts >= 0 && value.Walks >= 0 &&
                value.RunsAllowed >= 0 && value.Pitches >= 0 &&
                value.TeamRuns >= 0 && value.OpponentRuns >= 0 &&
                (!value.RecordedHits.HasValue || value.RecordedHits.Value >= 0) &&
                (!value.HomeRuns.HasValue || value.HomeRuns.Value >= 0) &&
                (!value.RecordedHits.HasValue || !value.HomeRuns.HasValue ||
                 value.HomeRuns.Value <= value.RecordedHits.Value) &&
                !string.IsNullOrWhiteSpace(value.Decision));
        }

        private static bool ValidPitchingRecord(PitchingRecordReadModel value)
        {
            return value != null && value.Games >= 0 && value.Starts >= 0 &&
                value.Starts <= value.Games && value.Outs >= 0 &&
                value.Strikeouts >= 0 && value.Walks >= 0 && value.RunsAllowed >= 0 &&
                value.Wins >= 0 && value.Losses >= 0 && value.Saves >= 0 &&
                (!value.Hits.HasValue || value.Hits.Value >= 0) &&
                (!value.HomeRuns.HasValue || value.HomeRuns.Value >= 0) &&
                (!value.Hits.HasValue || !value.HomeRuns.HasValue ||
                 value.HomeRuns.Value <= value.Hits.Value) &&
                (!value.Pitches.HasValue || value.Pitches.Value >= 0) &&
                (!value.QualityStarts.HasValue || value.QualityStarts.Value >= 0 &&
                 value.QualityStarts.Value <= value.Starts);
        }

        private static bool ValidRatings(PitcherRatingsReadModel value)
        {
            return value.Stuff >= 0 && value.Command >= 0 &&
                value.Movement >= 0 && value.Stamina >= 0;
        }

        private static bool ValidPitchMetrics(PitchSessionMetricsState metrics, int? maximumPitches)
        {
            if (metrics == null || metrics.RecentSequencePitches == null ||
                metrics.SequenceMasteryTags == null || metrics.RecentSequencePitches.Count > 3 ||
                metrics.DirectDeliveryCount < 0 || metrics.DeliveryScoreTotal < 0 ||
                metrics.BestDeliveryScore < 0 || metrics.BestDeliveryScore > 1000 ||
                metrics.PerfectDeliveryCount < 0 ||
                metrics.PerfectDeliveryCount > metrics.DirectDeliveryCount ||
                metrics.AbilityMomentCount < 0 || metrics.AbilityMomentTypes == null ||
                metrics.AbilityMomentTypes.Count > metrics.AbilityMomentCount ||
                metrics.AbilityMomentTypes.Any(value =>
                    !Baseball.Core.Pitching.PitchAbilityWire.IsValid(value)) ||
                metrics.DeliveryScoreTotal > metrics.DirectDeliveryCount * 1000 ||
                metrics.RecentSequencePitches.Any(value => !ValidSequencePitch(value)) ||
                metrics.SequenceMasteryTags.Any(value => !Enum.IsDefined(typeof(Baseball.Core.Pitching.PitchSequenceTag), value)))
            {
                return false;
            }
            return !maximumPitches.HasValue ||
                metrics.SequenceMasteryCount <= maximumPitches.Value &&
                metrics.DirectDeliveryCount <= maximumPitches.Value &&
                metrics.AbilityMomentCount <= maximumPitches.Value;
        }

        private static bool ValidSequencePitch(Baseball.Core.Pitching.PitchSequencePitch value)
        {
            return value != null && value.ExpectedVelocityKph > 0 &&
                value.Zone.Row >= 0 && value.Zone.Row <= 2 &&
                value.Zone.Column >= 0 && value.Zone.Column <= 2;
        }

        private static bool ReportMatchesMetrics(
            PitchGameReport report,
            PitchSessionMetricsState metrics)
        {
            return report.SequenceMasteryCount == metrics.SequenceMasteryCount &&
                report.DirectDeliveryCount == metrics.DirectDeliveryCount &&
                report.DeliveryScoreTotal == metrics.DeliveryScoreTotal &&
                report.BestDeliveryScore == metrics.BestDeliveryScore &&
                report.PerfectDeliveryCount == metrics.PerfectDeliveryCount &&
                report.AbilityMomentCount == metrics.AbilityMomentCount &&
                report.AbilityMomentTypes.SequenceEqual(
                    metrics.AbilityMomentTypes,
                    StringComparer.Ordinal);
        }
    }

    public sealed class GameSaveSemanticPriority : ISaveSemanticPriority<GameSaveAggregate>
    {
        public int GetPriority(GameSaveAggregate payload)
        {
            if (payload == null) return 0;
            if (payload.Deleted) return 3;
            if (payload.Stage == ApplicationStage.BetweenLives) return 2;
            return 1;
        }
    }
}
