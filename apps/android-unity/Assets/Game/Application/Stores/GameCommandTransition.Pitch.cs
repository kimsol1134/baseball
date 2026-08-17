using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Application.Stores
{
    public sealed partial class GameCommandTransition
    {

        private TransitionResult<GameSaveAggregate> BeginPitch(
            GameSaveAggregate current,
            BeginPitchSessionCommand command,
            string commandId)
        {
            if (current.PitchResume != null || current.PendingPitchCompletion != null)
                return Failure("pitch.already_pending");
            if (string.IsNullOrWhiteSpace(command.GameId) ||
                string.IsNullOrWhiteSpace(command.ScenarioId) ||
                command.MaximumBatters < 1 || command.MaximumBatters > 18)
            {
                return Failure("pitch.begin_invalid");
            }

            string careerId;
            string sessionSeed;
            PitchScenarioReadModel scenario;
            HighSchoolCareerReadModel highSchool = null;
            ProCareerReadModel pro = null;
            var meta = current.Meta;
            switch (command.CareerKind)
            {
                case PitchCareerKind.Tutorial:
                    if (current.HighSchool?.Phase != HighSchoolPhase.Prologue)
                        return Failure("pitch.tutorial_not_ready");
                    careerId = current.HighSchool.CareerId;
                    scenario = _highSchool is IHighSchoolTutorialScenarioPort tutorialScenarios
                        ? tutorialScenarios.CreateTutorialPitchScenario(
                            current.HighSchool,
                            command.ScenarioId)
                        : PitchScenarioFactory.TutorialFallback(
                            current.HighSchool.CareerId,
                            current.HighSchool.Ratings,
                            current.HighSchool.PlayerName);
                    if (current.HighSchool.TutorialAttemptCount == int.MaxValue)
                        return Failure("pitch.tutorial_attempts_exhausted");
                    var tutorialAttempt = current.HighSchool.TutorialAttemptCount + 1;
                    sessionSeed = tutorialAttempt == 1
                        ? current.HighSchool.NextSeed
                        : DeterministicSeed.Normalize(
                            current.HighSchool.NextSeed + "|tutorial-attempt|" + tutorialAttempt);
                    highSchool = CopyTutorialState(
                        current.HighSchool,
                        current.HighSchool.TutorialCompleted,
                        tutorialAttempt);
                    if (!ValidTutorialReservation(current.HighSchool, highSchool))
                    {
                        return Failure("pitch.tutorial_reservation_invalid");
                    }
                    break;
                case PitchCareerKind.HighSchool:
                    if (current.HighSchool?.Phase != HighSchoolPhase.ImportantGame)
                        return Failure("pitch.high_school_not_ready");
                    careerId = current.HighSchool.CareerId;
                    scenario = _highSchool is IHighSchoolPitchScenarioPort highSchoolScenarios
                        ? highSchoolScenarios.CreatePitchScenario(current.HighSchool, command.ScenarioId)
                        : PitchScenarioFactory.Fallback(
                            command.ScenarioId,
                            current.HighSchool.Ratings,
                            current.HighSchool.PlayerName,
                            command.MaximumBatters);
                    sessionSeed = current.HighSchool.NextSeed;
                    highSchool = _highSchool.ReservePitch(current.HighSchool, command.ScenarioId);
                    if (!ValidHighSchoolReservation(current.HighSchool, highSchool) ||
                        string.Equals(sessionSeed, highSchool.NextSeed, StringComparison.Ordinal))
                    {
                        return Failure("pitch.seed_not_consumed");
                    }
                    sessionSeed = highSchool.NextSeed;
                    break;
                case PitchCareerKind.Pro:
                    if (current.Pro?.Phase != ProCareerPhase.ImportantGame)
                        return Failure("pitch.pro_not_ready");
                    careerId = current.Pro.ProCareerId;
                    scenario = _pro is IProPitchScenarioPort proScenarios
                        ? proScenarios.CreatePitchScenario(current.Pro, command.ScenarioId)
                        : PitchScenarioFactory.Fallback(
                            command.ScenarioId,
                            current.Pro.Ratings,
                            current.Pro.PlayerName,
                            command.MaximumBatters);
                    sessionSeed = current.Pro.NextSeed;
                    pro = _pro.ReservePitch(current.Pro, command.ScenarioId);
                    if (!ValidProReservation(current.Pro, pro) ||
                        string.Equals(sessionSeed, pro.NextSeed, StringComparison.Ordinal))
                    {
                        return Failure("pitch.seed_not_consumed");
                    }
                    sessionSeed = pro.NextSeed;
                    break;
                case PitchCareerKind.Daily:
                    return Failure("daily.retired");
                default:
                    return Failure("pitch.kind_invalid");
            }

            if (string.IsNullOrWhiteSpace(sessionSeed)) return Failure("pitch.seed_missing");
            if (scenario == null || scenario.MaximumBatters < 1 || scenario.MaximumBatters > 18 ||
                scenario.Lineup.Count < scenario.MaximumBatters)
            {
                return Failure("pitch.scenario_invalid");
            }
            var resume = new PitchResumeState(
                command.GameId,
                command.CareerKind,
                careerId,
                scenario.ScenarioId,
                sessionSeed,
                scenario.MaximumBatters,
                scenario: scenario);
            return Success(current.Commit(
                commandId,
                highSchool: highSchool,
                pro: pro,
                meta: meta,
                pitchResume: resume));
        }

        private static TransitionResult<GameSaveAggregate> CheckpointPitch(
            GameSaveAggregate current,
            CheckpointPitchSessionCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            if (resume == null || !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal))
                return Failure("pitch.session_mismatch");
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (resume.CommittedPitch != null) return Failure("pitch.committed_result_pending");
            if (resume.AwaitingCompletion) return Failure("pitch.completion_required");
            if (command.CompletedBatters < resume.CompletedBatters ||
                command.CompletedBatters > resume.MaximumBatters ||
                string.IsNullOrWhiteSpace(command.CheckpointJson))
            {
                return Failure("pitch.checkpoint_invalid");
            }
            if (!ValidAccumulatedReport(
                    resume,
                    command.CompletedBatters,
                    command.AccumulatedReport,
                    resume.Metrics))
                return Failure("pitch.accumulated_report_invalid");
            var updated = new PitchResumeState(
                resume.GameId,
                resume.CareerKind,
                resume.CareerId,
                resume.ScenarioId,
                resume.SessionSeed,
                resume.MaximumBatters,
                command.CompletedBatters,
                command.CheckpointJson,
                resume.Scenario,
                command.AccumulatedReport ?? resume.AccumulatedReport,
                consumedPitchIds: resume.ConsumedPitchIds,
                awaitingCompletion: resume.AwaitingCompletion,
                metrics: resume.Metrics,
                pitchLog: resume.PitchLog);
            return Success(current.Commit(commandId, pitchResume: updated));
        }

        private static TransitionResult<GameSaveAggregate> CommitPitchResult(
            GameSaveAggregate current,
            CommitPitchResultCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            if (resume == null || !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal))
                return Failure("pitch.session_mismatch");
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (resume.CommittedPitch != null) return Failure("pitch.committed_result_pending");
            if (resume.AwaitingCompletion) return Failure("pitch.completion_required");
            string abilityMomentType;
            if (!TryAbilityMomentType(
                    resume.Scenario?.Pitcher,
                    command.AbilityMomentEvidence,
                    command.SequencePitch,
                    command.SequenceContext,
                    out abilityMomentType))
            {
                return Failure("pitch.committed_result_invalid");
            }
            if (command.BatterIndex != resume.CompletedBatters ||
                resume.ConsumedPitchIds.Contains(command.PitchId, StringComparer.Ordinal) ||
                resume.ConsumedPitchIds.Count >= PitchLogEntryState.MaximumEntries ||
                resume.Scenario?.MaximumPitches is int maximumPitches &&
                    resume.ConsumedPitchIds.Count >= maximumPitches ||
                string.IsNullOrWhiteSpace(command.PitchId) ||
                string.IsNullOrWhiteSpace(command.EventHash) ||
                string.IsNullOrWhiteSpace(command.KernelResultJson) ||
                string.IsNullOrWhiteSpace(command.PresentationJson) ||
                !ValidCommittedMetrics(
                    resume.Metrics,
                    command.SequencePitch,
                    command.SequenceTag,
                    command.Delivery,
                    command.SequenceContext,
                    command.SequenceRivalMemory))
            {
                return Failure("pitch.committed_result_invalid");
            }

            var committed = new CommittedPitchResultState(
                command.PitchId,
                command.BatterIndex,
                command.EventHash,
                command.KernelResultJson,
                command.PresentationJson,
                command.CommittedAt.ToUnixTimeMilliseconds(),
                command.SequencePitch,
                command.SequenceTag,
                command.Delivery,
                abilityMomentType,
                PitchLogEntry(command, resume.ConsumedPitchIds.Count + 1));
            var updated = new PitchResumeState(
                resume.GameId,
                resume.CareerKind,
                resume.CareerId,
                resume.ScenarioId,
                resume.SessionSeed,
                resume.MaximumBatters,
                resume.CompletedBatters,
                resume.CheckpointJson,
                resume.Scenario,
                resume.AccumulatedReport,
                committed,
                resume.ConsumedPitchIds,
                resume.AwaitingCompletion,
                resume.Metrics,
                resume.PitchLog);
            return Success(current.Commit(commandId, pitchResume: updated));
        }

        private static TransitionResult<GameSaveAggregate> ConsumeCommittedPitchResult(
            GameSaveAggregate current,
            ConsumeCommittedPitchResultCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            var committed = resume?.CommittedPitch;
            if (resume == null || committed == null ||
                !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal) ||
                !string.Equals(committed.PitchId, command.PitchId, StringComparison.Ordinal))
            {
                return Failure("pitch.committed_result_mismatch");
            }
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (command.CompletedBatters < resume.CompletedBatters ||
                command.CompletedBatters > resume.CompletedBatters + 1 ||
                command.CompletedBatters > resume.MaximumBatters ||
                string.IsNullOrWhiteSpace(command.CheckpointJson))
            {
                return Failure("pitch.committed_result_consume_invalid");
            }

            var nextMetrics = (resume.Metrics ?? PitchSessionMetricsState.Empty).Consuming(
                committed,
                command.CompletedBatters > resume.CompletedBatters);
            if (!ValidAccumulatedReport(
                    resume,
                    command.CompletedBatters,
                    command.AccumulatedReport,
                    nextMetrics))
            {
                return Failure("pitch.committed_result_consume_invalid");
            }

            var consumedIds = resume.ConsumedPitchIds
                .Concat(new[] { committed.PitchId })
                .ToArray();
            var pitchLog = committed.PitchLogEntry == null
                ? resume.PitchLog
                : resume.PitchLog.Concat(new[] { committed.PitchLogEntry }).ToArray();
            if (pitchLog.Count > PitchLogEntryState.MaximumEntries ||
                resume.Scenario?.MaximumPitches is int logMaximum && pitchLog.Count > logMaximum)
            {
                return Failure("pitch.log_limit");
            }
            var terminal = IsTerminalPitchSession(
                resume,
                command.CompletedBatters,
                command.AccumulatedReport,
                consumedIds.Length);
            if (command.SessionCompleted && !terminal)
                return Failure("pitch.session_not_terminal");

            var updated = new PitchResumeState(
                resume.GameId,
                resume.CareerKind,
                resume.CareerId,
                resume.ScenarioId,
                resume.SessionSeed,
                resume.MaximumBatters,
                command.CompletedBatters,
                command.CheckpointJson,
                resume.Scenario,
                command.AccumulatedReport ?? resume.AccumulatedReport,
                consumedPitchIds: consumedIds,
                awaitingCompletion: command.SessionCompleted || terminal,
                metrics: nextMetrics,
                pitchLog: pitchLog);
            return Success(current.Commit(commandId, pitchResume: updated));
        }

        private TransitionResult<GameSaveAggregate> RetryTutorialPitch(
            GameSaveAggregate current,
            RetryTutorialPitchCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            var highSchool = current.HighSchool;
            if (resume == null || resume.CareerKind != PitchCareerKind.Tutorial ||
                resume.CommittedPitch != null || !resume.AwaitingCompletion ||
                !string.Equals(resume.GameId, command.CurrentGameId, StringComparison.Ordinal) ||
                highSchool == null || highSchool.Phase != HighSchoolPhase.Prologue ||
                !string.Equals(highSchool.CareerId, resume.CareerId, StringComparison.Ordinal))
            {
                return Failure("pitch.tutorial_retry_not_available");
            }
            if (string.IsNullOrWhiteSpace(command.NextGameId) ||
                string.IsNullOrWhiteSpace(command.ScenarioId) ||
                string.Equals(command.NextGameId, resume.GameId, StringComparison.Ordinal) ||
                highSchool.TutorialAttemptCount == int.MaxValue)
            {
                return Failure("pitch.tutorial_retry_invalid");
            }

            var scenario = _highSchool is IHighSchoolTutorialScenarioPort tutorialScenarios
                ? tutorialScenarios.CreateTutorialPitchScenario(highSchool, command.ScenarioId)
                : PitchScenarioFactory.TutorialFallback(
                    highSchool.CareerId,
                    highSchool.Ratings,
                    highSchool.PlayerName);
            if (scenario == null || scenario.MaximumBatters != 2 ||
                scenario.MaximumPitches != 8 || scenario.Lineup.Count < 2)
            {
                return Failure("pitch.scenario_invalid");
            }
            var nextAttempt = highSchool.TutorialAttemptCount + 1;
            var sessionSeed = DeterministicSeed.Normalize(
                highSchool.NextSeed + "|tutorial-attempt|" + nextAttempt);
            var updatedHighSchool = CopyTutorialState(
                highSchool,
                highSchool.TutorialCompleted,
                nextAttempt);
            if (!ValidTutorialReservation(highSchool, updatedHighSchool))
                return Failure("pitch.tutorial_reservation_invalid");
            var updatedResume = new PitchResumeState(
                command.NextGameId,
                PitchCareerKind.Tutorial,
                highSchool.CareerId,
                scenario.ScenarioId,
                sessionSeed,
                scenario.MaximumBatters,
                scenario: scenario);
            return Success(current.Commit(
                commandId,
                highSchool: updatedHighSchool,
                pitchResume: updatedResume));
        }

        private TransitionResult<GameSaveAggregate> CompletePitch(
            GameSaveAggregate current,
            CompletePitchSessionCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            var report = command.Report;
            if (resume == null || !string.Equals(resume.GameId, report.GameId, StringComparison.Ordinal))
                return Failure("pitch.session_mismatch");
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (resume.CommittedPitch != null) return Failure("pitch.committed_result_pending");
            if (resume.ConsumedPitchIds.Count == 0)
                return Failure("pitch.authoritative_pitch_required");
            if (!resume.AwaitingCompletion)
                return Failure("pitch.session_not_terminal");
            if (report.Pitches <= 0 || report.Batters < 0 || report.Batters > resume.MaximumBatters ||
                report.Outs < 0 || report.Strikeouts < 0 || report.Walks < 0 ||
                report.Hits < 0 || report.RunsAllowed < 0 || report.ExpectedDamage < 0 ||
                report.HomeRuns.HasValue && report.HomeRuns.Value < 0 ||
                report.RivalStrikeouts < 0 || report.RivalStrikeouts > report.Strikeouts ||
                report.ActualDamage < 0 || report.RecommendationAccepted < 0 ||
                report.RecommendationAccepted > report.Pitches ||
                !ValidReportMetrics(report))
            {
                return Failure("pitch.report_invalid");
            }
            if (report.Batters < resume.CompletedBatters)
                return Failure("pitch.report_before_checkpoint");
            if (report.Batters != resume.CompletedBatters ||
                resume.AccumulatedReport == null ||
                !SamePitchReport(report, resume.AccumulatedReport))
            {
                return Failure("pitch.report_checkpoint_mismatch");
            }
            var highSchool = current.HighSchool;
            var pro = current.Pro;
            ApplicationStage stage;
            switch (resume.CareerKind)
            {
                case PitchCareerKind.Tutorial:
                    if (highSchool == null || highSchool.Phase != HighSchoolPhase.Prologue ||
                        !string.Equals(highSchool.CareerId, resume.CareerId, StringComparison.Ordinal))
                    {
                        return Failure("pitch.career_mismatch");
                    }
                    var tutorialBefore = highSchool;
                    var schoolSelection = _highSchool.Apply(
                        highSchool,
                        new HighSchoolAction("complete_prologue"));
                    if (!ValidHighSchoolAdvance(tutorialBefore, schoolSelection) ||
                        schoolSelection.Phase != HighSchoolPhase.SchoolSelection ||
                        !SamePerformance(tutorialBefore.Performance, schoolSelection.Performance))
                    {
                        return Failure("pitch.tutorial_completion_invalid");
                    }
                    highSchool = CopyTutorialState(
                        schoolSelection,
                        completed: true,
                        attemptCount: tutorialBefore.TutorialAttemptCount);
                    stage = StageFor(highSchool);
                    break;
                case PitchCareerKind.HighSchool:
                    if (highSchool == null ||
                        !string.Equals(highSchool.CareerId, resume.CareerId, StringComparison.Ordinal))
                        return Failure("pitch.career_mismatch");
                    var highSchoolBefore = highSchool;
                    highSchool = _highSchool.ApplyPitchResult(highSchool, report);
                    if (!ValidHighSchoolAdvance(highSchoolBefore, highSchool))
                        return Failure("high_school.port_invalid");
                    stage = StageFor(highSchool);
                    break;
                case PitchCareerKind.Pro:
                    if (pro == null || !string.Equals(pro.ProCareerId, resume.CareerId, StringComparison.Ordinal))
                        return Failure("pitch.career_mismatch");
                    var proBefore = pro;
                    pro = _pro.ApplyPitchResult(pro, report);
                    if (!ValidProAdvance(proBefore, pro)) return Failure("pro.port_invalid");
                    stage = StageFor(pro);
                    break;
                case PitchCareerKind.Daily:
                    return Failure("daily.retired");
                default:
                    return Failure("pitch.kind_invalid");
            }

            var meta = resume.CareerKind == PitchCareerKind.Tutorial ||
                       resume.CareerKind == PitchCareerKind.HighSchool && highSchool?.IsChallengeRun == true
                ? current.Meta
                : ApplyPitchMeta(
                    current.Meta,
                    resume.CareerKind,
                    report,
                    resume.PitchLog,
                    command.CompletedAt,
                    commandId);
            var pending = new PendingPitchCompletion(
                "pitch-result:" + report.GameId,
                resume.CareerKind,
                resume.CareerId,
                report,
                command.CompletedAt.ToUnixTimeSeconds(),
                resume.PitchLog);
            return Success(current.Commit(
                commandId,
                stage: stage,
                highSchool: highSchool,
                pro: pro,
                meta: meta,
                clearPitchResume: true,
                pendingPitchCompletion: pending));
        }

        private static TransitionResult<GameSaveAggregate> AcknowledgePitch(
            GameSaveAggregate current,
            AcknowledgePitchResultCommand command,
            string commandId)
        {
            if (current.PendingPitchCompletion == null ||
                !string.Equals(
                    current.PendingPitchCompletion.CompletionId,
                    command.CompletionId,
                    StringComparison.Ordinal))
            {
                return Failure("pitch.completion_mismatch");
            }
            return Success(current.Commit(commandId, clearPendingPitchCompletion: true));
        }

        private static TransitionResult<GameSaveAggregate> AbandonPitch(
            GameSaveAggregate current,
            AbandonPitchSessionCommand command,
            string commandId)
        {
            if (current.PitchResume == null ||
                !string.Equals(current.PitchResume.GameId, command.GameId, StringComparison.Ordinal))
            {
                return Failure("pitch.session_mismatch");
            }
            if (current.PitchResume.CareerKind == PitchCareerKind.Daily)
                return Success(current.Commit(commandId, clearPitchResume: true));
            if (current.PitchResume.CommittedPitch != null)
                return Failure("pitch.committed_result_pending");
            if (current.PitchResume.AwaitingCompletion)
                return Failure("pitch.completion_required");
            if (current.PitchResume.CareerKind == PitchCareerKind.Tutorial)
                return Failure("pitch.tutorial_cannot_abandon");
            return Success(current.Commit(commandId, clearPitchResume: true));
        }

        private static TransitionResult<GameSaveAggregate> SuspendPitch(
            GameSaveAggregate current,
            SuspendPitchSessionCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            if (resume == null ||
                !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal))
            {
                return Failure("pitch.session_mismatch");
            }
            if (resume.CareerKind == PitchCareerKind.Daily)
                return Failure("daily.retired");
            if (resume.CommittedPitch != null)
                return Failure("pitch.committed_result_pending");
            if (resume.AwaitingCompletion)
                return Failure("pitch.completion_required");
            if (resume.CareerKind == PitchCareerKind.Tutorial)
                return Failure("pitch.tutorial_cannot_suspend");

            ApplicationStage safeStage;
            if (resume.CareerKind == PitchCareerKind.HighSchool)
            {
                if (current.HighSchool == null ||
                    !string.Equals(
                        current.HighSchool.CareerId,
                        resume.CareerId,
                        StringComparison.Ordinal))
                {
                    return Failure("pitch.career_mismatch");
                }
                safeStage = StageFor(current.HighSchool);
            }
            else if (resume.CareerKind == PitchCareerKind.Pro)
            {
                if (current.Pro == null ||
                    !string.Equals(
                        current.Pro.ProCareerId,
                        resume.CareerId,
                        StringComparison.Ordinal))
                {
                    return Failure("pitch.career_mismatch");
                }
                safeStage = StageFor(current.Pro);
            }
            else
            {
                return Failure("pitch.kind_invalid");
            }

            // Reuse the exact immutable resume object. The command receipt/revision is the durable
            // acknowledgement that navigation may leave PitchHandoff without consuming a seed.
            return Success(current.Commit(
                commandId,
                stage: safeStage,
                pitchResume: resume));
        }

        private static bool ValidAccumulatedReport(
            PitchResumeState resume,
            int completedBatters,
            PitchGameReport report,
            PitchSessionMetricsState expectedMetrics = null)
        {
            // Legacy callers may checkpoint only the opaque kernel state. New production callers
            // also persist the typed cumulative report, which is validated when supplied.
            if (report == null) return true;
            var prior = resume.AccumulatedReport;
            return string.Equals(report.GameId, resume.GameId, StringComparison.Ordinal) &&
                report.Batters == completedBatters && report.Pitches > 0 &&
                report.Outs >= 0 && report.Strikeouts >= 0 && report.Walks >= 0 &&
                report.Hits >= 0 && report.RunsAllowed >= 0 &&
                (!report.HomeRuns.HasValue || report.HomeRuns.Value >= 0) &&
                (prior == null ||
                 report.Pitches >= prior.Pitches && report.Batters >= prior.Batters &&
                 report.Outs >= prior.Outs && report.Strikeouts >= prior.Strikeouts &&
                 report.Walks >= prior.Walks && report.Hits >= prior.Hits &&
                (!prior.HomeRuns.HasValue ||
                 report.HomeRuns.HasValue && report.HomeRuns.Value >= prior.HomeRuns.Value) &&
                report.RunsAllowed >= prior.RunsAllowed &&
                report.RivalStrikeouts >= prior.RivalStrikeouts &&
                report.SequenceMasteryCount >= prior.SequenceMasteryCount &&
                report.ExpectedDamage >= prior.ExpectedDamage &&
                report.ActualDamage >= prior.ActualDamage &&
                 report.RecommendationAccepted >= prior.RecommendationAccepted) &&
                (expectedMetrics == null || ReportMatchesMetrics(report, expectedMetrics));
        }

        private static bool SamePitchReport(PitchGameReport left, PitchGameReport right)
        {
            return left != null && right != null &&
                string.Equals(left.GameId, right.GameId, StringComparison.Ordinal) &&
                left.Pitches == right.Pitches && left.Batters == right.Batters &&
                left.Outs == right.Outs && left.Strikeouts == right.Strikeouts &&
                left.Walks == right.Walks && left.Hits == right.Hits &&
                left.HomeRuns == right.HomeRuns &&
                left.RunsAllowed == right.RunsAllowed &&
                left.SequenceMasteryCount == right.SequenceMasteryCount &&
                left.ExpectedDamage == right.ExpectedDamage &&
                left.ActualDamage == right.ActualDamage &&
                left.RecommendationAccepted == right.RecommendationAccepted &&
                left.DirectDeliveryCount == right.DirectDeliveryCount &&
                left.DeliveryScoreTotal == right.DeliveryScoreTotal &&
                left.BestDeliveryScore == right.BestDeliveryScore &&
                left.PerfectDeliveryCount == right.PerfectDeliveryCount &&
                left.RivalStrikeouts == right.RivalStrikeouts &&
                left.AbilityMomentCount == right.AbilityMomentCount &&
                left.AbilityMomentTypes.SequenceEqual(
                    right.AbilityMomentTypes,
                    StringComparer.Ordinal);
        }

        private static bool SamePerformance(
            CareerPerformanceReadModel left,
            CareerPerformanceReadModel right)
        {
            return left != null && right != null &&
                left.ImportantGames == right.ImportantGames &&
                left.Pitches == right.Pitches && left.Outs == right.Outs &&
                left.Strikeouts == right.Strikeouts && left.Walks == right.Walks &&
                left.Hits == right.Hits && left.RunsAllowed == right.RunsAllowed;
        }

        private static bool SameRatings(
            PitcherRatingsReadModel left,
            PitcherRatingsReadModel right)
        {
            return left != null && right != null &&
                left.Stuff == right.Stuff && left.Command == right.Command &&
                left.Movement == right.Movement && left.Stamina == right.Stamina;
        }

        private static bool ValidCommittedMetrics(
            PitchSessionMetricsState currentMetrics,
            Baseball.Core.Pitching.PitchSequencePitch sequencePitch,
            Baseball.Core.Pitching.PitchSequenceTag? sequenceTag,
            PitchDeliveryMetricState delivery,
            Baseball.Core.Pitching.PlateAppearanceContext sequenceContext,
            Baseball.Core.Pitching.RivalMemorySnapshot sequenceRivalMemory)
        {
            if (sequenceTag.HasValue && sequencePitch == null) return false;
            if (sequenceTag.HasValue && !Enum.IsDefined(
                    typeof(Baseball.Core.Pitching.PitchSequenceTag), sequenceTag.Value)) return false;
            if (sequencePitch != null &&
                (sequencePitch.ExpectedVelocityKph <= 0 ||
                 sequencePitch.Zone.Row < 0 || sequencePitch.Zone.Row > 2 ||
                 sequencePitch.Zone.Column < 0 || sequencePitch.Zone.Column > 2)) return false;
            if (sequencePitch != null)
            {
                if (sequenceContext == null) return false;
                var evaluated = Baseball.Core.Pitching.PitchSequenceEvaluator.Evaluate(
                    currentMetrics?.RecentSequencePitches ??
                        Array.Empty<Baseball.Core.Pitching.PitchSequencePitch>(),
                    sequenceContext,
                    sequencePitch,
                    sequenceRivalMemory);
                if (evaluated?.Tag != sequenceTag) return false;
            }
            else if (sequenceContext != null || sequenceRivalMemory != null)
            {
                return false;
            }
            return delivery == null ||
                delivery.ReleaseAccuracy >= 0 && delivery.ReleaseAccuracy <= 1000 &&
                delivery.AimAccuracy >= 0 && delivery.AimAccuracy <= 1000;
        }

        private static bool TryAbilityMomentType(
            Baseball.Core.Domain.PitcherSnapshot pitcher,
            PitchAbilityMomentEvidence evidence,
            Baseball.Core.Pitching.PitchSequencePitch sequencePitch,
            Baseball.Core.Pitching.PlateAppearanceContext sequenceContext,
            out string abilityMomentType)
        {
            abilityMomentType = null;
            if (pitcher == null || evidence == null || evidence.Call == null || evidence.PreResultContext == null ||
                evidence.Execution == null || sequencePitch == null || sequenceContext == null ||
                !Enum.IsDefined(typeof(Baseball.Core.Domain.PitchOutcome), evidence.Outcome) ||
                evidence.Execution.ExecutionQuality < 0 || evidence.Execution.ExecutionQuality > 1000 ||
                evidence.Call.PitchType != sequencePitch.PitchType ||
                evidence.Call.Zone != sequencePitch.Zone ||
                evidence.Call.ZoneIntent != sequencePitch.Intent ||
                evidence.Outcome != sequencePitch.Outcome ||
                !SameContext(evidence.PreResultContext, sequenceContext))
            {
                return false;
            }
            try
            {
                var readout = Baseball.Core.Pitching.PitchAbilityRules.Readout(
                    pitcher,
                    evidence.Call,
                    evidence.PreResultContext);
                var moment = Baseball.Core.Pitching.PitchAbilityRules.Moment(
                    evidence.Outcome,
                    evidence.Execution,
                    readout);
                abilityMomentType = moment.HasValue
                    ? Baseball.Core.Pitching.PitchAbilityWire.Value(moment.Value)
                    : null;
                return true;
            }
            catch (ArgumentException)
            {
                return false;
            }
            catch (InvalidOperationException)
            {
                return false;
            }
        }

        private static PitchLogEntryState PitchLogEntry(
            CommitPitchResultCommand command,
            int pitchNumber)
        {
            var evidence = command.AbilityMomentEvidence;
            var call = evidence.Call;
            var execution = evidence.Execution;
            return new PitchLogEntryState(
                command.PitchId,
                command.BatterIndex,
                pitchNumber,
                call.PitchType.Value(),
                call.Zone.Row,
                call.Zone.Column,
                call.ZoneIntent.Value(),
                call.Intensity.Value(),
                execution.TargetX,
                execution.TargetY,
                execution.ActualX,
                execution.ActualY,
                execution.VelocityTenthsKph,
                execution.HorizontalBreakTenthsCm,
                execution.VerticalBreakTenthsCm,
                execution.ExecutionQuality,
                evidence.Outcome.Value(),
                evidence.RecommendationAccepted,
                command.CommittedAt.ToUnixTimeMilliseconds(),
                command.Delivery?.ReleaseAccuracy,
                command.Delivery?.AimAccuracy,
                command.Delivery?.WasDirect);
        }

        private static bool SameContext(
            Baseball.Core.Pitching.PlateAppearanceContext left,
            Baseball.Core.Pitching.PlateAppearanceContext right)
        {
            return left != null && right != null &&
                string.Equals(left.PlateAppearanceId, right.PlateAppearanceId, StringComparison.Ordinal) &&
                left.Revision == right.Revision && left.Inning == right.Inning &&
                left.Outs == right.Outs && left.Balls == right.Balls &&
                left.Strikes == right.Strikes && left.PitchNumber == right.PitchNumber &&
                left.ScoreDifferential == right.ScoreDifferential &&
                left.Leverage == right.Leverage && left.Fatigue == right.Fatigue;
        }

        private static bool ValidReportMetrics(PitchGameReport report)
        {
            return (!report.HomeRuns.HasValue ||
                    report.HomeRuns.Value >= 0 && report.HomeRuns.Value <= report.Hits) &&
                report.DirectDeliveryCount >= 0 && report.PerfectDeliveryCount >= 0 &&
                report.RivalStrikeouts >= 0 && report.RivalStrikeouts <= report.Strikeouts &&
                report.AbilityMomentCount >= 0 && report.AbilityMomentCount <= report.Pitches &&
                report.AbilityMomentTypes.Count <= report.AbilityMomentCount &&
                report.AbilityMomentTypes.All(Baseball.Core.Pitching.PitchAbilityWire.IsValid) &&
                report.PerfectDeliveryCount <= report.DirectDeliveryCount &&
                report.DeliveryScoreTotal >= 0 &&
                report.DeliveryScoreTotal <= report.DirectDeliveryCount * 1000 &&
                report.BestDeliveryScore >= 0 && report.BestDeliveryScore <= 1000 &&
                (report.DirectDeliveryCount != 0 ||
                 report.DeliveryScoreTotal == 0 && report.BestDeliveryScore == 0 &&
                 report.PerfectDeliveryCount == 0);
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

        private static bool IsTerminalPitchSession(
            PitchResumeState resume,
            int completedBatters,
            PitchGameReport report,
            int consumedPitchCount)
        {
            if (completedBatters >= resume.MaximumBatters) return true;
            if (resume.Scenario?.MaximumPitches is int maximumPitches &&
                consumedPitchCount >= maximumPitches) return true;
            if (report == null) return false;
            var initialOuts = resume.Scenario?.GameState?.InningState?.Outs ?? 0;
            return initialOuts + report.Outs >= 3;
        }

        private static MetaProgressState ApplyPitchMeta(
            MetaProgressState current,
            PitchCareerKind kind,
            PitchGameReport report,
            IReadOnlyList<PitchLogEntryState> pitchLog,
            DateTimeOffset completedAt,
            string commandId)
        {
            if (kind != PitchCareerKind.HighSchool && kind != PitchCareerKind.Pro)
                return current;
            var daily = DailyStreakRules.RecordBaseball(current.Daily, completedAt);
            var playedReceipt = commandId + ":played-day";
            var weekly = WeeklyProgramRules.Record(
                current.Weekly,
                WeeklyTaskKinds.PlayedOnTwoDays,
                1,
                playedReceipt,
                completedAt);
            var task = kind == PitchCareerKind.HighSchool
                ? WeeklyTaskKinds.ImportantGamesCompleted
                : null;
            if (task != null)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    task,
                    1,
                    commandId + ":game",
                    completedAt);
            }
            if (report.SequenceMasteryCount > 0)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.SequenceMasteryTriggered,
                    report.SequenceMasteryCount,
                    commandId + ":sequence",
                    completedAt);
            }
            var achievements = AchievementRules.Unlock(
                current.Achievements,
                AchievementRules.FromPitch(report));
            var directLog = (pitchLog ?? Array.Empty<PitchLogEntryState>())
                .Where(value => value?.WasDirect == true)
                .ToArray();
            int? releaseAccuracyTotal = directLog.Length == report.DirectDeliveryCount &&
                directLog.All(value => value.ReleaseAccuracy.HasValue)
                    ? directLog.Sum(value => value.ReleaseAccuracy.Value)
                    : (int?)null;
            int? aimAccuracyTotal = directLog.Length == report.DirectDeliveryCount &&
                directLog.All(value => value.AimAccuracy.HasValue)
                    ? directLog.Sum(value => value.AimAccuracy.Value)
                    : (int?)null;
            var releaseMastery = PitchReleaseMasteryRules.Record(
                current.PitchReleaseMastery,
                report.GameId,
                report.DirectDeliveryCount,
                report.DeliveryScoreTotal,
                report.BestDeliveryScore,
                releaseAccuracyTotal,
                aimAccuracyTotal);
            var updated = current.With(
                daily: daily,
                weekly: weekly,
                achievements: achievements,
                pitchReleaseMastery: releaseMastery);
            return CompletedGameCountRules.Record(updated, 1);
        }
    }
}
