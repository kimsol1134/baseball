using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Core.Pitching;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Pitch
{
    /// <summary>
    /// Coordinates the durable Core-result boundary with the disposable 3D presentation. A pitch
    /// is always committed before stage playback, and a committed result is consumed only after
    /// its exact saved presentation has finished.
    /// </summary>
    public sealed class PitchShellFlowCoordinator : IDisposable
    {
        private readonly VisualElement _documentRoot;
        private readonly BaseballShellController _shell;
        private readonly IPitchKernelGateway _kernel;
        private readonly IPitchFeedbackBoundary _feedback;
        private readonly IPitchSessionPersistence _persistence;
        private readonly PitchPresentationCompletionMarker _completionMarker =
            new PitchPresentationCompletionMarker();
        private CancellationTokenSource _sessionLifetime;
        private GameObject _stageObject;
        private PitchStageController _stage;
        private string _stagePreparationFailure;
        private PitchPlayPresenter _presenter;
        private PitchHudController _hud;
        private PitchTutorialDecisionController _tutorialDecision;
        private string _gameId;
        private PitchScenarioReadModel _scenario;
        private int _completedBatters;
        private int _maximumBatters;
        private PitchGameReport _accumulatedReport;
        private PitchSessionMetricsState _metrics = PitchSessionMetricsState.Empty;
        private PitchKernelResult _activeResult;
        private PitchPresentationSnapshot _activePresentation;
        private string _activePitchId;
        private PitchCommit _activeCommit;
        private PitchCommitMetricEvidence _activeMetricEvidence;
        private bool _commitDurable;
        private bool _presentationFinished;
        private bool _resultSaved;
        private bool _persistenceBusy;
        private bool _recoveredCompletionActive;
        private bool _isTutorial;
        private bool _disposed;

        public PitchShellFlowCoordinator(
            VisualElement documentRoot,
            BaseballShellController shell,
            IPitchKernelGateway kernel = null,
            IPitchFeedbackBoundary feedback = null,
            IPitchSessionPersistence persistence = null)
        {
            _documentRoot = documentRoot ?? throw new ArgumentNullException(nameof(documentRoot));
            _shell = shell ?? throw new ArgumentNullException(nameof(shell));
            _kernel = kernel ?? new AuthoritativePitchKernelGateway();
            _feedback = feedback ?? NullPitchFeedbackBoundary.Instance;
            _persistence = persistence;
            _shell.PitchRequested += Open;
        }

        public bool IsOpen => _hud != null || _tutorialDecision != null || _recoveredCompletionActive;

        public void Tick(double unscaledDeltaSeconds) => _hud?.Tick(unscaledDeltaSeconds);

        public bool TryHandleBack()
        {
            if (_recoveredCompletionActive)
            {
                _shell.Announce("저장된 경기 결과를 먼저 완료해 주세요. 저장 다시 시도 버튼으로 이어갈 수 있습니다.");
                return true;
            }
            return _tutorialDecision?.TryHandleBack() == true || _hud?.TryHandleBack() == true;
        }

        public void Dispose()
        {
            if (_disposed) return;
            _shell.PitchRequested -= Open;
            CloseActive();
            _disposed = true;
        }

        private async void Open(PitchHandoffViewModel handoff)
        {
            CloseActive();
            try
            {
                _sessionLifetime = new CancellationTokenSource();
                PitchSessionLoadResult loaded;
                if (_persistence != null)
                {
                    loaded = await _persistence.LoadReservedAsync(handoff, _sessionLifetime.Token);
                    if (!loaded.Succeeded)
                    {
                        _shell.Announce(string.IsNullOrWhiteSpace(loaded.Message)
                            ? "투구 세션을 불러오지 못했습니다."
                            : loaded.Message);
                        CloseActive();
                        _shell.TryGoBack();
                        return;
                    }
                }
                else
                {
                    _shell.Announce("저장 서비스가 준비되지 않아 투구를 시작할 수 없습니다.");
                    CloseActive();
                    _shell.TryGoBack();
                    return;
                }

                _gameId = loaded.GameId;
                _scenario = loaded.Scenario;
                _completedBatters = loaded.CompletedBatters;
                _maximumBatters = loaded.MaximumBatters;
                _accumulatedReport = loaded.AccumulatedReport;
                _metrics = loaded.Metrics ?? PitchSessionMetricsState.Empty;
                _isTutorial = loaded.IsTutorial;

                if (loaded.AwaitingCompletion)
                {
                    _recoveredCompletionActive = true;
                    _shell.SetPitchPresentationActive(true);
                    _feedback.OnSessionStarted();
                    if (loaded.IsTutorial)
                    {
                        ShowTutorialDecision();
                        return;
                    }
                    FinishRecoveredSession();
                    return;
                }

                if (!await CreateStageAsync(_sessionLifetime.Token))
                {
                    _shell.Announce(StagePreparationFailureMessage(
                        "저장된 경기 상태는 그대로 보존됩니다."));
                    CloseActive();
                    _shell.TryGoBack();
                    return;
                }
                _shell.SetPitchPresentationActive(true);
                _feedback.OnSessionStarted();
                MountPresenter(loaded.Request, loaded.CommittedReplay);
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
                CloseActive();
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_session_open");
                CloseActive();
                _shell.Announce("투구 화면을 준비하지 못했습니다. 저장된 진행은 그대로 유지됩니다.");
                _shell.TryGoBack();
            }
        }

        private async Task<bool> CreateStageAsync(CancellationToken cancellationToken)
        {
            Baseball.Platform.Crash.CrashRuntimeDiagnostics.PublishPitchStageLoaded(false);
            _stagePreparationFailure = string.Empty;
            _stageObject = new GameObject("Pitch Presentation Stage");
            _stage = _stageObject.AddComponent<PitchStageController>();
            _stage.ReducedMotion = _shell.ReducedMotion;
            bool ready = await _stage.PrepareVisualsAsync(
                _shell.VisualAssetLoader,
                cancellationToken);
            if (!ready)
            {
                _stagePreparationFailure = _stage.VisualPreparationError;
                DestroyStage();
                return false;
            }
            _stage.ResultReadable += OnResultReadable;
            _stage.PresentationCompleted += OnPresentationCompleted;
            Baseball.Platform.Crash.CrashRuntimeDiagnostics.PublishPitchStageLoaded(true);
            return true;
        }

        private void MountPresenter(PitchPlayRequest request, PitchCommittedReplay replay)
        {
            if (request == null) throw new InvalidOperationException("pitch.request_missing");
            DetachPresenter();
            _presenter = new PitchPlayPresenter(request, _kernel);
            _hud = new PitchHudController(
                _documentRoot,
                _presenter,
                _shell.HighContrast,
                _shell.ReducedMotion,
                _shell.VisualAssetLoader,
                _shell.AutoRelease,
                _isTutorial);
            _presenter.PitchCommitted += OnPitchCommitted;
            _hud.SkipRequested += _stage.RequestSkip;
            _hud.ExitRequested += Complete;
            _hud.SuspendRequested += Suspend;
            _hud.AbortRequested += Abort;

            _activeResult = null;
            _activePresentation = null;
            _activePitchId = null;
            _activeCommit = null;
            _activeMetricEvidence = null;
            _commitDurable = false;
            _presentationFinished = false;
            if (replay == null)
            {
                _presenter.Start();
                return;
            }

            _activeResult = replay.Result;
            _activePresentation = replay.Presentation;
            _activePitchId = replay.PitchId;
            _activeMetricEvidence = replay.MetricEvidence;
            _commitDurable = true;
            _presenter.RestoreCommitted(replay.Result, replay.Presentation);
            _hud.SetCommittedMetricFeedback(replay.MetricEvidence);
            _hud.SetPersistenceStatus(false, true, "저장된 투구 결과를 다시 보여 드립니다.");
            _stage.PlayRecoveredSummary(replay.Presentation);
        }

        private void OnPitchCommitted(PitchCommit commit)
        {
            _activeResult = commit.Result;
            _activePresentation = commit.Presentation;
            _activePitchId = commit.Presentation.PitchId;
            _activeCommit = commit;
            try
            {
                _activeMetricEvidence = PitchCommitMetrics.Evaluate(_metrics, commit);
                _hud?.SetCommittedMetricFeedback(_activeMetricEvidence);
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_metric_projection");
                _hud?.SetPersistenceStatus(false, false, "투구 성장 지표를 검증하지 못해 결과를 저장하지 않았습니다.");
                return;
            }
            _commitDurable = _persistence == null;
            _presentationFinished = false;
            _feedback.OnRelease(PitchHapticCue.Release);
            CommitAndPlay(commit);
        }

        private async void CommitAndPlay(PitchCommit commit)
        {
            if (_persistenceBusy || commit == null || _sessionLifetime == null) return;
            if (_persistence == null)
            {
                _stage.Play(commit.Presentation);
                return;
            }
            _persistenceBusy = true;
            _hud?.SetPersistenceStatus(true, false, "투구 결과를 먼저 안전하게 저장하고 있습니다.");
            try
            {
                ShellActionResult saved = await _persistence.CommitAsync(
                    _gameId,
                    _completedBatters,
                    commit,
                    _sessionLifetime.Token);
                if (!saved.Succeeded)
                {
                    _hud?.SetPersistenceStatus(false, false,
                        string.IsNullOrWhiteSpace(saved.Message) ? "투구 결과를 저장하지 못했습니다. 다시 시도해 주세요." : saved.Message);
                    return;
                }
                _commitDurable = true;
                _hud?.SetPersistenceStatus(false, true, "투구 결과를 저장했습니다.");
                _stage.Play(commit.Presentation);
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_commit_before_play");
                _hud?.SetPersistenceStatus(false, false, "투구 결과를 저장하지 못했습니다. 다시 시도해 주세요.");
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private void OnResultReadable(PitchPresentationSnapshot presentation)
        {
            _presenter?.MarkResultReadable(presentation);
            _feedback.OnResult(presentation);
        }

        private void OnPresentationCompleted(PitchPresentationSnapshot presentation)
        {
            if (_activePresentation == null ||
                !string.Equals(_activePresentation.PitchId, presentation.PitchId, StringComparison.Ordinal)) return;
            _presentationFinished = true;
            if (_completionMarker.TryMark(
                    presentation.PitchId,
                    _commitDurable,
                    _presentationFinished))
            {
#if !BASEBALL_INTERNAL_QA
                Debug.Log(PitchPresentationCompletionMarker.LogLine);
#endif
            }
            ConsumeActivePresentation();
        }

        private async void ConsumeActivePresentation()
        {
            if (_persistenceBusy || !_commitDurable || !_presentationFinished ||
                _activeResult == null || _activePresentation == null || _sessionLifetime == null) return;

            PitchKernelResult result = _activeResult;
            PitchPresentationSnapshot presentation = _activePresentation;
            if (_activeMetricEvidence == null)
            {
                _hud?.SetPersistenceStatus(false, false, "저장된 투구 성장 지표를 확인하지 못했습니다. 진행은 보존되어 있습니다.");
                return;
            }
            bool plateEnded = result.Snapshot.Ended;
            int nextCompleted = _completedBatters + (plateEnded ? 1 : 0);
            PitchSessionMetricsState nextMetrics = PitchCommitMetrics.Consuming(
                _metrics,
                _activeMetricEvidence,
                plateEnded);
            PitchGameReport nextReport = PitchGameReportBuilder.WithMetrics(_accumulatedReport, nextMetrics);
            if (plateEnded)
            {
                nextReport = PitchGameReportBuilder.WithMetrics(
                    PitchGameReportBuilder.Combine(
                        _gameId,
                        _accumulatedReport,
                        PitchGameReportBuilder.BuildPlate(_gameId, result, nextMetrics)),
                    nextMetrics);
            }

            bool sessionEnded = plateEnded && (_scenario == null ||
                PitchSessionRequestFactory.SessionEnded(_scenario, nextCompleted, result));
            PitchPlayRequest nextRequest = null;
            if (!sessionEnded)
            {
                nextRequest = plateEnded
                    ? PitchSessionRequestFactory.NextBatter(_gameId, _scenario, nextCompleted, result)
                    : _presenter.ContinuationAfter(result);
            }

            if (_persistence == null)
            {
                ApplyConsumedState(presentation, result, plateEnded, sessionEnded, nextCompleted, nextReport, nextRequest, nextMetrics);
                return;
            }

            _persistenceBusy = true;
            _hud?.SetPersistenceStatus(true, false, plateEnded
                ? "타자 결과와 다음 타순을 저장하고 있습니다."
                : "다음 공 상태를 저장하고 있습니다.");
            try
            {
                ShellActionResult consumed = await _persistence.ConsumeAsync(
                    _gameId,
                    _activePitchId,
                    nextCompleted,
                    nextRequest,
                    nextReport,
                    sessionEnded,
                    _sessionLifetime.Token);
                if (!consumed.Succeeded)
                {
                    _hud?.SetPersistenceStatus(false, false,
                        string.IsNullOrWhiteSpace(consumed.Message) ? "다음 상태를 저장하지 못했습니다. 다시 시도해 주세요." : consumed.Message);
                    return;
                }
                ApplyConsumedState(presentation, result, plateEnded, sessionEnded, nextCompleted, nextReport, nextRequest, nextMetrics);
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_consume_after_play");
                _hud?.SetPersistenceStatus(false, false, "다음 상태를 저장하지 못했습니다. 다시 시도해 주세요.");
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private void ApplyConsumedState(
            PitchPresentationSnapshot presentation,
            PitchKernelResult result,
            bool plateEnded,
            bool sessionEnded,
            int nextCompleted,
            PitchGameReport nextReport,
            PitchPlayRequest nextRequest,
            PitchSessionMetricsState nextMetrics)
        {
            _completedBatters = nextCompleted;
            _accumulatedReport = nextReport;
            _metrics = nextMetrics ?? PitchSessionMetricsState.Empty;
            _activeResult = null;
            _activePresentation = null;
            _activePitchId = null;
            _activeCommit = null;
            _activeMetricEvidence = null;
            _commitDurable = false;
            _presentationFinished = false;
            _presenter.CompletePresentation(presentation);

            if (!plateEnded) return;
            if (!sessionEnded)
            {
                MountPresenter(nextRequest, null);
                _shell.Announce("다음 타자가 타석에 들어섭니다. " + (_completedBatters + 1) + "번째 타자입니다.");
                return;
            }
            if (_isTutorial)
            {
                ShowTutorialDecision();
                return;
            }
            PitchSessionPostgameSnapshot postgame = _persistence?.ReadPostgame(_gameId) ??
                new PitchSessionPostgameSnapshot(_accumulatedReport, Array.Empty<PitchLogEntryState>());
            _hud?.ShowPostgameSummary(postgame);
            _shell.Announce("이닝 정산과 전체 투구 기록을 확인한 뒤 결과를 저장해 주세요.");
        }

        private void ShowTutorialDecision()
        {
            if (_accumulatedReport == null)
                throw new InvalidOperationException("pitch.tutorial_report_missing");
            DetachPresenter();
            DestroyStage();
            DetachTutorialDecision();
            _tutorialDecision = new PitchTutorialDecisionController(
                _documentRoot,
                _accumulatedReport,
                _shell.HighContrast,
                _shell.ReducedMotion);
            _tutorialDecision.AcceptRequested += AcceptTutorialResult;
            _tutorialDecision.RetryRequested += RetryTutorial;
        }

        private async void RetryTutorial()
        {
            if (_persistenceBusy || _persistence == null || _sessionLifetime == null) return;
            _persistenceBusy = true;
            _tutorialDecision?.SetBusy(true, "새 첫 불펜을 안전하게 준비하고 있습니다.");
            try
            {
                if (!await CreateStageAsync(_sessionLifetime.Token))
                {
                    _tutorialDecision?.SetBusy(
                        false,
                        StagePreparationFailureMessage(
                            "저장된 첫 불펜 결과는 그대로입니다."),
                        true);
                    return;
                }
                PitchSessionLoadResult loaded = await _persistence.RetryTutorialAsync(
                    _gameId,
                    _sessionLifetime.Token);
                if (!loaded.Succeeded)
                {
                    DestroyStage();
                    _tutorialDecision?.SetBusy(false, loaded.Message, true);
                    return;
                }
                _gameId = loaded.GameId;
                _scenario = loaded.Scenario;
                _completedBatters = loaded.CompletedBatters;
                _maximumBatters = loaded.MaximumBatters;
                _accumulatedReport = loaded.AccumulatedReport;
                _metrics = loaded.Metrics ?? PitchSessionMetricsState.Empty;
                _resultSaved = false;
                DetachTutorialDecision();
                MountPresenter(loaded.Request, loaded.CommittedReplay);
                _shell.Announce("새 첫 불펜을 저장했습니다. 다시 던져 보세요.");
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
                DestroyStage();
            }
            catch (Exception exception)
            {
                DestroyStage();
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_tutorial_retry");
                _tutorialDecision?.SetBusy(false, "첫 불펜을 다시 준비하지 못했습니다. 기존 결과는 보존되어 있습니다.", true);
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private string StagePreparationFailureMessage(string preservedStateMessage)
        {
            string lead = string.Equals(
                _stagePreparationFailure,
                PitchStageVisualPolicy.ShaderUnavailableError,
                StringComparison.Ordinal)
                ? "투구 렌더링 재료를 이 기기에서 준비하지 못했습니다."
                : "투구 구장 이미지를 불러오지 못했습니다.";
            return lead + " " + preservedStateMessage;
        }

        private async void AcceptTutorialResult()
        {
            if (_persistenceBusy || _persistence == null || _sessionLifetime == null || _accumulatedReport == null)
                return;
            _persistenceBusy = true;
            _tutorialDecision?.SetBusy(true, _resultSaved
                ? "결과 확인을 저장하고 있습니다."
                : "첫 불펜 결과를 저장하고 있습니다.");
            try
            {
                if (!_resultSaved)
                {
                    ShellActionResult completed = await _persistence.CompleteAsync(
                        _gameId,
                        _accumulatedReport,
                        _sessionLifetime.Token);
                    if (!completed.Succeeded)
                    {
                        _tutorialDecision?.SetBusy(false, completed.Message, true);
                        return;
                    }
                    _resultSaved = true;
                    _tutorialDecision?.SetPendingAcknowledgement();
                }
                ShellActionResult acknowledged = await _persistence.AcknowledgeAsync(_sessionLifetime.Token);
                if (!acknowledged.Succeeded)
                {
                    _tutorialDecision?.SetBusy(false, acknowledged.Message, false);
                    return;
                }
                CloseActive();
                _shell.CompletePitchHandoff();
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_tutorial_accept");
                _tutorialDecision?.SetBusy(false, "첫 불펜 결과를 저장하지 못했습니다. 다시 눌러 주세요.", !_resultSaved);
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private async void PersistSessionCompletion()
        {
            if (_persistence == null)
            {
                _resultSaved = true;
                _hud?.SetPersistenceStatus(false, true, "승부를 마쳤습니다.");
                return;
            }
            if (_persistenceBusy || _accumulatedReport == null || _sessionLifetime == null) return;
            _persistenceBusy = true;
            _hud?.SetPersistenceStatus(true, false, "경기 전체 결과를 저장하고 있습니다.");
            try
            {
                ShellActionResult completed = await _persistence.CompleteAsync(
                    _gameId,
                    _accumulatedReport,
                    _sessionLifetime.Token);
                _resultSaved = completed.Succeeded;
                _hud?.SetPersistenceStatus(false, completed.Succeeded, completed.Succeeded
                    ? "경기 결과를 저장했습니다."
                    : completed.Message);
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_session_complete");
                _hud?.SetPersistenceStatus(false, false, "경기 결과를 저장하지 못했습니다. 다시 시도해 주세요.");
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private async void FinishRecoveredSession()
        {
            if (_persistence == null || _accumulatedReport == null || _sessionLifetime == null)
            {
                _shell.Announce("완료 직전의 경기 기록을 복구하지 못했습니다. 저장된 진행은 보존되어 있습니다.");
                CloseActive();
                _shell.TryGoBack();
                return;
            }
            _persistenceBusy = true;
            _shell.Announce("마지막 타자까지 저장되어 경기 결과를 마무리하고 있습니다.");
            CancellationToken recoveryToken = _sessionLifetime.Token;
            try
            {
                ShellActionResult completed = await _persistence.CompleteAsync(
                    _gameId, _accumulatedReport, recoveryToken);
                if (recoveryToken.IsCancellationRequested || !_recoveredCompletionActive) return;
                if (!completed.Succeeded)
                {
                    string message = string.IsNullOrWhiteSpace(completed.Message)
                        ? "경기 결과를 마무리하지 못했습니다. 저장된 결과로 다시 시도해 주세요."
                        : completed.Message;
                    CloseActive();
                    _shell.Announce(message);
                    return;
                }
                _shell.Announce("복구한 경기 결과를 저장했습니다. 결과 확인 후 다음 일정으로 이동할 수 있습니다.");
                CloseActive();
                _shell.CompletePitchHandoff();
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_recovered_complete");
                CloseActive();
                _shell.Announce("경기 결과 마무리에 실패했습니다. 저장된 진행으로 다시 시도할 수 있습니다.");
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private async void Complete()
        {
            if (_persistenceBusy) return;
            if (_activeResult != null)
            {
                if (!_commitDurable)
                {
                    if (_activeCommit != null) CommitAndPlay(_activeCommit);
                }
                else if (_presentationFinished)
                {
                    ConsumeActivePresentation();
                }
                return;
            }
            if (!_resultSaved)
            {
                PersistSessionCompletion();
                return;
            }
            if (_persistence != null)
            {
                _persistenceBusy = true;
                _hud?.SetPersistenceStatus(true, true, "결과 확인을 저장하고 있습니다.");
                ShellActionResult acknowledged;
                try
                {
                    acknowledged = await _persistence.AcknowledgeAsync(_sessionLifetime.Token);
                }
                catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception exception)
                {
                    Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_acknowledge");
                    _hud?.SetPersistenceStatus(false, false, "결과 확인을 저장하지 못했습니다. 다시 시도해 주세요.");
                    return;
                }
                finally
                {
                    _persistenceBusy = false;
                }
                if (!acknowledged.Succeeded)
                {
                    _hud?.SetPersistenceStatus(false, false, acknowledged.Message);
                    return;
                }
            }
            CloseActive();
            _shell.CompletePitchHandoff();
        }

        private async void Abort()
        {
            if (_persistenceBusy) return;
            // A durably committed pitch cannot be abandoned until its presentation is consumed.
            if (_activeResult != null && _commitDurable)
            {
                _shell.Announce("저장된 투구 결과를 먼저 확인해 주세요.");
                if (_presentationFinished) ConsumeActivePresentation();
                else _stage?.RequestSkip();
                return;
            }
            if (_persistence != null && !string.IsNullOrWhiteSpace(_gameId) && _sessionLifetime != null)
            {
                _persistenceBusy = true;
                ShellActionResult abandoned;
                try
                {
                    abandoned = await _persistence.AbandonAsync(_gameId, _sessionLifetime.Token);
                }
                catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception exception)
                {
                    Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_abandon");
                    _shell.Announce("경기 이탈 상태를 저장하지 못했습니다. 다시 시도해 주세요.");
                    return;
                }
                finally
                {
                    _persistenceBusy = false;
                }
                if (!abandoned.Succeeded)
                {
                    _shell.Announce(abandoned.Message);
                    return;
                }
            }
            _presenter?.Abort();
            CloseActive();
            _shell.TryGoBack();
        }

        private async void Suspend()
        {
            if (_persistenceBusy || _sessionLifetime == null) return;
            if (_activeResult != null && _commitDurable)
            {
                _shell.Announce("저장된 투구 결과를 먼저 확인해 주세요.");
                if (_presentationFinished) ConsumeActivePresentation();
                else _stage?.RequestSkip();
                return;
            }
            if (_persistence == null || string.IsNullOrWhiteSpace(_gameId))
            {
                _hud?.SetExitStatus(false, "경기 진행을 보존할 저장 서비스가 준비되지 않았습니다.");
                return;
            }

            _persistenceBusy = true;
            _hud?.SetExitStatus(true, "현재 타자 시작 지점을 저장하고 있습니다.");
            CancellationToken token = _sessionLifetime.Token;
            try
            {
                ShellActionResult suspended = await _persistence.SuspendAsync(_gameId, token);
                if (!suspended.Succeeded)
                {
                    _hud?.SetExitStatus(false, string.IsNullOrWhiteSpace(suspended.Message)
                        ? "경기 진행을 저장하지 못했습니다. 다시 시도해 주세요."
                        : suspended.Message);
                    return;
                }
                CloseActive();
                if (!_shell.TryGoBack()) _shell.CompletePitchHandoff();
            }
            catch (OperationCanceledException) when (_sessionLifetime == null || _sessionLifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Baseball.Platform.Crash.CrashReporting.RecordUnexpected(exception, "pitch_suspend");
                _hud?.SetExitStatus(false, "경기 진행을 저장하지 못했습니다. 다시 시도해 주세요.");
            }
            finally
            {
                _persistenceBusy = false;
            }
        }

        private void DetachPresenter()
        {
            if (_hud != null)
            {
                if (_stage != null) _hud.SkipRequested -= _stage.RequestSkip;
                _hud.ExitRequested -= Complete;
                _hud.SuspendRequested -= Suspend;
                _hud.AbortRequested -= Abort;
                _hud.Dispose();
                _hud = null;
            }
            if (_presenter != null)
            {
                _presenter.PitchCommitted -= OnPitchCommitted;
                _presenter = null;
            }
        }

        private void DetachTutorialDecision()
        {
            if (_tutorialDecision == null) return;
            _tutorialDecision.AcceptRequested -= AcceptTutorialResult;
            _tutorialDecision.RetryRequested -= RetryTutorial;
            _tutorialDecision.Dispose();
            _tutorialDecision = null;
        }

        private void DestroyStage()
        {
            Baseball.Platform.Crash.CrashRuntimeDiagnostics.PublishPitchStageLoaded(false);
            if (_stage != null)
            {
                _stage.ResultReadable -= OnResultReadable;
                _stage.PresentationCompleted -= OnPresentationCompleted;
                _stage = null;
            }
            if (_stageObject == null) return;
            if (UnityEngine.Application.isPlaying) UnityEngine.Object.Destroy(_stageObject);
            else UnityEngine.Object.DestroyImmediate(_stageObject);
            _stageObject = null;
        }

        private void CloseActive()
        {
            _feedback.OnSessionEnded();
            DetachPresenter();
            DetachTutorialDecision();
            DestroyStage();
            _sessionLifetime?.Cancel();
            _sessionLifetime?.Dispose();
            _sessionLifetime = null;
            _gameId = null;
            _scenario = null;
            _completedBatters = 0;
            _maximumBatters = 0;
            _accumulatedReport = null;
            _metrics = PitchSessionMetricsState.Empty;
            _activeResult = null;
            _activePresentation = null;
            _activePitchId = null;
            _activeCommit = null;
            _activeMetricEvidence = null;
            _commitDurable = false;
            _presentationFinished = false;
            _resultSaved = false;
            _persistenceBusy = false;
            _recoveredCompletionActive = false;
            _shell.SetPitchPresentationActive(false);
        }
    }
}
