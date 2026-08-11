using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;
using Baseball.Platform.Analytics;
using Baseball.Platform.Review;
using Baseball.Presentation.Pitch;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    public sealed partial class ProductionBaseballShellRuntime : IPitchSessionPersistence
    {
        public Task<PitchSessionLoadResult> LoadReservedAsync(
            PitchHandoffViewModel handoff,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            PitchResumeState resume = _store?.Current?.PitchResume;
            if (resume == null)
                return Task.FromResult(LoadFailure("저장된 투구 세션이 없습니다."));
            try
            {
                PitchScenarioReadModel scenario = resume.Scenario;
                if (scenario == null || scenario.SchemaVersion != PitchScenarioReadModel.CurrentSchemaVersion ||
                    resume.MaximumBatters != scenario.MaximumBatters ||
                    scenario.Lineup.Count < scenario.MaximumBatters ||
                    resume.CompletedBatters < 0 || resume.CompletedBatters > resume.MaximumBatters)
                {
                    return Task.FromResult(LoadFailure("저장된 경기 상황의 버전이 맞지 않습니다. 앱을 업데이트한 뒤 다시 시도해 주세요."));
                }

                bool awaitingCompletion = resume.AwaitingCompletion ||
                    resume.CompletedBatters >= resume.MaximumBatters;
                PitchPlayRequest request = null;
                if (!awaitingCompletion && !string.IsNullOrWhiteSpace(resume.CheckpointJson))
                {
                    PitchSessionCheckpoint checkpoint =
                        PitchPersistenceJsonCodec.DeserializeCheckpoint(resume.CheckpointJson);
                    awaitingCompletion = checkpoint.IsTerminal;
                    request = checkpoint.Request;
                }
                else if (!awaitingCompletion)
                    request = PitchSessionRequestFactory.Initial(resume.GameId, resume.SessionSeed, scenario, resume.CompletedBatters);

                PitchCommittedReplay replay = null;
                if (resume.CommittedPitch != null)
                {
                    if (awaitingCompletion || resume.CommittedPitch.BatterIndex != resume.CompletedBatters)
                        throw new InvalidOperationException("pitch.committed_batter_mismatch");
                    var result = PitchPersistenceJsonCodec.DeserializeKernelResult(resume.CommittedPitch.KernelResultJson);
                    var presentation = PitchPersistenceJsonCodec.DeserializePresentation(resume.CommittedPitch.PresentationJson);
                    if (!string.Equals(result.EventHash, resume.CommittedPitch.EventHash, StringComparison.Ordinal) ||
                        !string.Equals(presentation.PitchId, resume.CommittedPitch.PitchId, StringComparison.Ordinal))
                    {
                        throw new InvalidOperationException("pitch.committed_checksum_mismatch");
                    }
                    replay = new PitchCommittedReplay(
                        resume.CommittedPitch.PitchId,
                        resume.CommittedPitch.BatterIndex,
                        result,
                        presentation,
                        resume.CommittedPitch.SequencePitch == null || resume.CommittedPitch.Delivery == null
                            ? null
                            : new PitchCommitMetricEvidence(
                                resume.CommittedPitch.SequencePitch,
                                resume.CommittedPitch.SequenceTag,
                                resume.CommittedPitch.Delivery,
                                null,
                                resume.CommittedPitch.AbilityMomentType));
                }
                return Task.FromResult(new PitchSessionLoadResult(
                    true,
                    resume.GameId,
                    request,
                    resume.CompletedBatters,
                    resume.MaximumBatters,
                    scenario,
                    resume.AccumulatedReport,
                    replay,
                    awaitingCompletion,
                    null,
                    resume.Metrics,
                    resume.CareerKind));
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_resume_decode");
                return Task.FromResult(LoadFailure("저장된 투구 진행을 검증하지 못했습니다. 진행은 보존되어 있습니다."));
            }
        }

        public async Task<ShellActionResult> CommitAsync(
            string gameId,
            int batterIndex,
            PitchCommit commit,
            CancellationToken cancellationToken)
        {
            if (commit?.Result == null || commit.Presentation == null)
                return ShellActionResult.Failure("저장할 투구 결과가 없습니다.");
            PitchSessionMetricsState currentMetrics =
                _store?.Current?.PitchResume?.Metrics ?? PitchSessionMetricsState.Empty;
            PitchCommitMetricEvidence evidence;
            try
            {
                evidence = PitchCommitMetrics.Evaluate(currentMetrics, commit);
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_metric_projection");
                return ShellActionResult.Failure("투구 성장 지표를 검증하지 못해 결과를 저장하지 않았습니다.");
            }
            var command = new CommitPitchResultCommand(
                gameId,
                commit.Presentation.PitchId,
                batterIndex,
                commit.Result.EventHash,
                PitchPersistenceJsonCodec.SerializeKernelResult(commit.Result),
                PitchPersistenceJsonCodec.SerializePresentation(commit.Presentation),
                DateTimeOffset.UtcNow,
                evidence.SequencePitch,
                evidence.SequenceTag,
                evidence.Delivery,
                commit.PreResultContext,
                commit.PreResultRivalMemory,
                abilityMomentEvidence: new PitchAbilityMomentEvidence(
                    commit.Call,
                    commit.PreResultContext,
                    commit.Result.Snapshot.Outcome,
                    commit.Result.Snapshot.Execution));
            return await DispatchPitchAsync("commit", command, cancellationToken);
        }

        public async Task<ShellActionResult> ConsumeAsync(
            string gameId,
            string pitchId,
            int completedBatters,
            PitchPlayRequest nextRequest,
            PitchGameReport accumulatedReport,
            bool sessionCompleted,
            CancellationToken cancellationToken)
        {
            string checkpoint = PitchPersistenceJsonCodec.SerializeCheckpoint(
                nextRequest,
                nextRequest == null);
            var command = new ConsumeCommittedPitchResultCommand(
                gameId,
                pitchId,
                completedBatters,
                checkpoint,
                accumulatedReport,
                sessionCompleted);
            return await DispatchPitchAsync("consume", command, cancellationToken);
        }

        public async Task<ShellActionResult> CompleteAsync(
            string gameId,
            PitchGameReport report,
            CancellationToken cancellationToken)
        {
            if (report == null || !string.Equals(report.GameId, gameId, StringComparison.Ordinal))
                return ShellActionResult.Failure("완료할 경기 기록이 없습니다.");
            GameSaveAggregate before = _store?.Current;
            PitchResumeState completedResume = before?.PitchResume;
            DateTimeOffset completedAt = DateTimeOffset.UtcNow;
            var command = new CompletePitchSessionCommand(report, completedAt);
            ShellActionResult dispatch = await DispatchPitchAsync("complete", command, cancellationToken);
            if (!dispatch.Succeeded) return dispatch;

            GameSaveAggregate after = _store.Current;
            await EmitPhaseTransitionAnalyticsAsync(before, after, cancellationToken);
            PitchCareerKind? completedKind = after.PendingPitchCompletion?.CareerKind;
            bool countsPitchEvent = CareerAnalyticsEligibility.CountsPitchEvent(completedKind, before);
            if (CareerAnalyticsEligibility.IsFirstPitchCompletion(completedKind, before))
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.FirstPitch,
                    new Dictionary<string, object>(StringComparer.Ordinal),
                    Baseball.Application.Meta.AnalyticsReceiptRetention.Lifetime,
                    cancellationToken,
                    "install");
            }
            if (completedKind != PitchCareerKind.Tutorial && countsPitchEvent)
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.GameFinished,
                    GameFinishedProperties(completedKind, before, after, completedResume, report),
                    Baseball.Application.Meta.AnalyticsReceiptRetention.Scoped,
                    cancellationToken,
                    gameId);
            }
            if (completedKind == PitchCareerKind.HighSchool &&
                countsPitchEvent &&
                HasGameGrowth(before, after, completedResume, report))
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.GameGrowthApplied,
                    GameGrowthProperties(before, after, report),
                    Baseball.Application.Meta.AnalyticsReceiptRetention.Scoped,
                    cancellationToken,
                    gameId,
                    "growth");
            }
            if (completedKind == PitchCareerKind.Pro ||
                completedKind == PitchCareerKind.HighSchool && countsPitchEvent)
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.ActivationFirstGame,
                    new Dictionary<string, object>(StringComparer.Ordinal),
                    Baseball.Application.Meta.AnalyticsReceiptRetention.Lifetime,
                    cancellationToken,
                    "install");
            }
            if (completedKind != PitchCareerKind.Tutorial) TryRequestReview(report);
            return dispatch;
        }

        public async Task<PitchSessionLoadResult> RetryTutorialAsync(
            string currentGameId,
            CancellationToken cancellationToken)
        {
            GameSaveAggregate state = _store?.Current;
            if (state?.PitchResume?.CareerKind != PitchCareerKind.Tutorial ||
                !state.PitchResume.AwaitingCompletion ||
                !string.Equals(state.PitchResume.GameId, currentGameId, StringComparison.Ordinal))
            {
                return LoadFailure("다시 던질 수 있는 첫 불펜 결과가 없습니다.");
            }
            string nextGameId = "pitch:tutorial:" + state.HighSchool.CareerId + ":" +
                (state.HighSchool.TutorialAttemptCount + 1) + ":" + (state.Revision + 1);
            ShellActionResult retried = await DispatchPitchAsync(
                "tutorial_retry",
                new RetryTutorialPitchCommand(
                    currentGameId,
                    nextGameId,
                    "tutorial",
                    DateTimeOffset.UtcNow),
                cancellationToken);
            if (!retried.Succeeded) return LoadFailure(retried.Message);
            return await LoadReservedAsync(ResumeHandoff, cancellationToken);
        }

        private static PitchSessionLoadResult LoadFailure(string message) =>
            new PitchSessionLoadResult(false, null, null, 0, 0, null, null, null, false, message);

        public async Task<ShellActionResult> AcknowledgeAsync(CancellationToken cancellationToken)
        {
            PendingPitchCompletion pending = _store?.Current?.PendingPitchCompletion;
            string completionId = pending?.CompletionId;
            if (string.IsNullOrWhiteSpace(completionId))
                return ShellActionResult.Failure("확인할 경기 결과가 없습니다.");
            ShellActionResult result = await DispatchPitchAsync(
                "acknowledge",
                new AcknowledgePitchResultCommand(completionId),
                cancellationToken);
            if (result.Succeeded && pending.CareerKind == PitchCareerKind.Daily)
                _pitchReturnOverride = ShellRoute.Records;
            return result;
        }

        public async Task<ShellActionResult> AbandonAsync(string gameId, CancellationToken cancellationToken)
        {
            GameSaveAggregate before = _store?.Current;
            PitchResumeState resume = before?.PitchResume;
            if (resume == null) return ShellActionResult.Success();
            ShellActionResult result = await DispatchPitchAsync(
                "abandon",
                new AbandonPitchSessionCommand(gameId),
                cancellationToken);
            if (result.Succeeded && resume.CareerKind == PitchCareerKind.HighSchool &&
                CareerAnalyticsEligibility.CountsPitchEvent(resume.CareerKind, before))
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.GameAbandoned,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["pitches"] = resume.AccumulatedReport?.Pitches ?? resume.ConsumedPitchIds.Count,
                        ["chapter"] = before.HighSchool?.ChapterNumber ?? 0,
                        ["life_number"] = before.HighSchool?.LifeNumber ?? before.Meta.LifeNumber,
                        ["act_number"] = ActNumber(before.HighSchool?.ChapterNumber ?? 0),
                        ["phase"] = before.HighSchool == null
                            ? "none"
                            : Baseball.Application.Meta.ReturnPlanRules.PhaseWire(before.HighSchool.Phase),
                        ["development_rules_version"] = resume.Scenario?.DevelopmentRulesVersion ?? 1,
                        ["games_completed"] = before.HighSchool?.Performance?.ImportantGames ?? 0,
                    },
                    Baseball.Application.Meta.AnalyticsReceiptRetention.Scoped,
                    cancellationToken,
                    gameId,
                    "abandoned");
            }
            return result;
        }

        private async Task<ShellActionResult> DispatchPitchAsync(
            string operation,
            GameCommand command,
            CancellationToken cancellationToken)
        {
            if (_store == null || _status != ShellRuntimeStatus.Ready)
                return ShellActionResult.Failure("저장 서비스가 준비되지 않았습니다.");
            GameSaveAggregate before = _store.Current;
            string commandId = "pitch:" + operation + ":" + before.Revision + ":" + (++_commandSequence);
            DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(
                new CommandEnvelope<GameCommand>(commandId, before.Revision, command),
                cancellationToken);
            if (!result.IsSuccess)
            {
                return ShellActionResult.Failure(KoreanFailure(result));
            }
            return ShellActionResult.Success(null, "경기 진행을 저장했습니다.");
        }

        private static IReadOnlyDictionary<string, object> GameFinishedProperties(
            PitchCareerKind? kind,
            GameSaveAggregate before,
            GameSaveAggregate after,
            PitchResumeState resume,
            PitchGameReport report)
        {
            string mode = kind == PitchCareerKind.HighSchool
                ? "high_school"
                : kind == PitchCareerKind.Pro ? "pro" : kind == PitchCareerKind.Daily ? "daily" : "unknown";
            PitchSessionMetricsState metrics = resume?.Metrics ?? PitchSessionMetricsState.Empty;
            var properties = new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["mode"] = mode,
                ["sequence_mastery_count"] = report.SequenceMasteryCount,
                ["sequence_tags"] = string.Join(",", metrics.SequenceMasteryTags
                    .Select(SequenceTagWire)
                    .Distinct(StringComparer.Ordinal)
                    .OrderBy(value => value, StringComparer.Ordinal)
                    .Take(6)),
                ["recommendation_acceptance_rate"] = report.Pitches == 0
                    ? 0d
                    : (double)report.RecommendationAccepted / report.Pitches,
                ["development_rules_version"] = resume?.Scenario?.DevelopmentRulesVersion ?? 1,
                ["ability_moment_count"] = report.AbilityMomentCount,
                ["ability_moment_types"] = string.Join(",", report.AbilityMomentTypes),
            };
            if (kind == PitchCareerKind.HighSchool)
            {
                properties["result"] = report.RunsAllowed == 0 ? "scoreless" : "runs_allowed";
                properties["strikeouts"] = report.Strikeouts;
                properties["walks"] = report.Walks;
                properties["runs"] = report.RunsAllowed;
                properties["target_batters"] = resume?.MaximumBatters ?? report.Batters;
                properties["batters"] = report.Batters;
                properties["life_number"] = before?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1;
                properties["act_number"] = ActNumber(before?.HighSchool?.ChapterNumber ?? 0);
            }
            if (kind == PitchCareerKind.Pro)
            {
                properties["result"] = report.RunsAllowed == 0 ? "scoreless" : "runs_allowed";
                properties["strikeouts"] = report.Strikeouts;
                properties["walks"] = report.Walks;
                properties["runs"] = report.RunsAllowed;
            }
            if (kind == PitchCareerKind.Daily)
            {
                properties["result"] = "completed";
                properties["score"] = DailyScore(report);
                properties["streak"] = after?.Meta?.Daily?.CurrentStreak ?? 0;
            }
            return properties;
        }

        private static bool HasGameGrowth(
            GameSaveAggregate before,
            GameSaveAggregate after,
            PitchResumeState resume,
            PitchGameReport report)
        {
            if (before?.HighSchool?.Ratings == null || after?.HighSchool?.Ratings == null ||
                (resume?.Scenario?.DevelopmentRulesVersion ?? 1) < 4) return false;
            return report.Strikeouts >= 2 && report.RunsAllowed <= 1 &&
                    report.ActualDamage <= report.ExpectedDamage ||
                report.Outs == 3 && report.Pitches >= 9 && report.RunsAllowed <= 1 &&
                    report.ActualDamage <= report.ExpectedDamage ||
                report.SequenceMasteryCount >= 4 && report.Walks == 0 &&
                    report.ActualDamage <= report.ExpectedDamage;
        }

        private static IReadOnlyDictionary<string, object> GameGrowthProperties(
            GameSaveAggregate before,
            GameSaveAggregate after,
            PitchGameReport report)
        {
            PitcherRatingsReadModel prior = before.HighSchool.Ratings;
            PitcherRatingsReadModel next = after.HighSchool.Ratings;
            string focus;
            string reason;
            int points;
            if (report.Strikeouts >= 2 && report.RunsAllowed <= 1 &&
                report.ActualDamage <= report.ExpectedDamage)
            {
                bool stuff = prior.Stuff >= prior.Movement;
                focus = stuff ? "stuff" : "movement";
                reason = stuff ? "strikeout_stuff" : "strikeout_movement";
                points = stuff ? next.Stuff - prior.Stuff : next.Movement - prior.Movement;
            }
            else if (report.Outs == 3 && report.Pitches >= 9 && report.RunsAllowed <= 1 &&
                report.ActualDamage <= report.ExpectedDamage)
            {
                focus = "stamina";
                reason = "long_outing";
                points = next.Stamina - prior.Stamina;
            }
            else
            {
                focus = "command";
                reason = "sequence_command";
                points = next.Command - prior.Command;
            }
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["life_number"] = after.HighSchool.LifeNumber,
                ["act_number"] = ActNumber(after.HighSchool.ChapterNumber),
                ["reason_id"] = reason,
                ["growth_focus"] = focus,
                ["growth_points"] = Math.Max(0, points),
            };
        }

        private static int DailyScore(PitchGameReport report) => Math.Max(
            0,
            report.Strikeouts * 300 + report.Outs * 100 - report.Walks * 50 -
            report.RunsAllowed * 250 + (report.RunsAllowed == 0 && report.Outs >= 3 ? 300 : 0));

        private static string SequenceTagWire(Baseball.Core.Pitching.PitchSequenceTag value)
        {
            switch (value)
            {
                case Baseball.Core.Pitching.PitchSequenceTag.SpeedLadder: return "speed_ladder";
                case Baseball.Core.Pitching.PitchSequenceTag.EyeLevelChange: return "eye_level_change";
                case Baseball.Core.Pitching.PitchSequenceTag.InsideOutside: return "inside_outside";
                case Baseball.Core.Pitching.PitchSequenceTag.ExpandAfterTwoStrikes: return "expand_after_two_strikes";
                case Baseball.Core.Pitching.PitchSequenceTag.StealStrike: return "steal_strike";
                case Baseball.Core.Pitching.PitchSequenceTag.CounterRead: return "counter_read";
                default: return "unknown";
            }
        }

        private void TryRequestReview(PitchGameReport report)
        {
            try
            {
                GameSaveAggregate state = _store.Current;
                int highSchoolGames = state.HighSchool?.Performance?.ImportantGames ?? 0;
                int proGames = state.Pro?.CurrentSeason?.ImportantGames ?? 0;
                int archivedGames = 0;
                foreach (var life in state.Meta.LifeArchive)
                    archivedGames += life.HighSchoolPerformance?.ImportantGames ?? 0;
                var context = new ReviewEligibilityContext(
                    state.HighSchool != null || state.Pro != null || state.Meta.LifeArchive.Count > 0,
                    highSchoolGames + proGames + archivedGames,
                    highSchoolGames + proGames,
                    TimeSpan.FromSeconds(Math.Max(0d, Time.realtimeSinceStartupAsDouble)));
                PlayReviewPrompt.TryRequest(context);
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "review_prompt");
            }
        }
    }
}
