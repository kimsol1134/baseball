using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Core.Pitching;
using Baseball.Presentation.Shell;

namespace Baseball.Presentation.Pitch
{
    public readonly struct PitchSessionLoadResult
    {
        public PitchSessionLoadResult(
            bool succeeded,
            string gameId,
            PitchPlayRequest request,
            int completedBatters,
            int maximumBatters,
            PitchScenarioReadModel scenario,
            PitchGameReport accumulatedReport,
            PitchCommittedReplay committedReplay,
            bool awaitingCompletion,
            string message,
            PitchSessionMetricsState metrics = null,
            PitchCareerKind? careerKind = null)
        {
            Succeeded = succeeded;
            GameId = gameId ?? string.Empty;
            Request = request;
            CompletedBatters = completedBatters;
            MaximumBatters = maximumBatters;
            Scenario = scenario;
            AccumulatedReport = accumulatedReport;
            CommittedReplay = committedReplay;
            AwaitingCompletion = awaitingCompletion;
            Message = message ?? string.Empty;
            Metrics = metrics ?? PitchSessionMetricsState.Empty;
            CareerKind = careerKind;
        }

        public bool Succeeded { get; }
        public string GameId { get; }
        public PitchPlayRequest Request { get; }
        public int CompletedBatters { get; }
        public int MaximumBatters { get; }
        public PitchScenarioReadModel Scenario { get; }
        public PitchGameReport AccumulatedReport { get; }
        public PitchCommittedReplay CommittedReplay { get; }
        public bool AwaitingCompletion { get; }
        public string Message { get; }
        public PitchSessionMetricsState Metrics { get; }
        public PitchCareerKind? CareerKind { get; }
        public bool IsTutorial => CareerKind == PitchCareerKind.Tutorial;
    }

    public sealed class PitchCommittedReplay
    {
        public PitchCommittedReplay(
            string pitchId,
            int batterIndex,
            PitchKernelResult result,
            PitchPresentationSnapshot presentation,
            PitchCommitMetricEvidence metricEvidence = null)
        {
            PitchId = string.IsNullOrWhiteSpace(pitchId)
                ? throw new ArgumentException("A pitch ID is required.", nameof(pitchId))
                : pitchId;
            BatterIndex = batterIndex;
            Result = result ?? throw new ArgumentNullException(nameof(result));
            Presentation = presentation ?? throw new ArgumentNullException(nameof(presentation));
            MetricEvidence = metricEvidence;
        }

        public string PitchId { get; }
        public int BatterIndex { get; }
        public PitchKernelResult Result { get; }
        public PitchPresentationSnapshot Presentation { get; }
        public PitchCommitMetricEvidence MetricEvidence { get; }
    }

    public interface IPitchSessionPersistence
    {
        Task<PitchSessionLoadResult> LoadReservedAsync(PitchHandoffViewModel handoff, CancellationToken cancellationToken);
        Task<ShellActionResult> CommitAsync(
            string gameId,
            int batterIndex,
            PitchCommit commit,
            CancellationToken cancellationToken);
        Task<ShellActionResult> ConsumeAsync(
            string gameId,
            string pitchId,
            int completedBatters,
            PitchPlayRequest nextRequest,
            PitchGameReport accumulatedReport,
            bool sessionCompleted,
            CancellationToken cancellationToken);
        Task<ShellActionResult> CompleteAsync(
            string gameId,
            PitchGameReport accumulatedReport,
            CancellationToken cancellationToken);
        Task<PitchSessionLoadResult> RetryTutorialAsync(
            string currentGameId,
            CancellationToken cancellationToken);
        Task<ShellActionResult> AcknowledgeAsync(CancellationToken cancellationToken);
        Task<ShellActionResult> AbandonAsync(string gameId, CancellationToken cancellationToken);
    }
}
