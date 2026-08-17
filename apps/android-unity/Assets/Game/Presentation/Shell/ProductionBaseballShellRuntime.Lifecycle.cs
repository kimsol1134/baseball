using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Core.Catalogs;
using Baseball.Platform.Analytics;
using Baseball.Platform.Configuration;
using Baseball.Platform.Crash;
using Baseball.Platform.Haptics;
using Baseball.Platform.Identity;
using Baseball.Platform.Notifications;
using Baseball.Platform.Review;
using Baseball.Platform.Share;
using Baseball.Presentation.Pitch;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    public sealed partial class ProductionBaseballShellRuntime
    {
        public void OnApplicationPause(bool paused)
        {
            if (paused) return;
            if (_store?.Current != null) ApplyPersistedSettings(_store.Current);
            DrainPendingReminderSetting();
            ObserveReturnPlanOpen("warm");
        }

        public void Dispose()
        {
            if (_disposed) return;
            RuntimeGameServices.Ready -= OnReady;
            RuntimeGameServices.StoreChanged -= OnStoreChanged;
            RuntimeGameServices.BecameUnavailable -= OnUnavailable;
            RuntimeGameServices.StartupFailed -= OnStartupFailed;
            RuntimeGameServices.SessionEndPrepared -= OnSessionEndPrepared;
            if (AndroidReminderService.Instance != null)
            {
                AndroidReminderService.Instance.EnablementChanged -= OnReminderChanged;
                AndroidReminderService.Instance.ReminderOpenAvailable -= OnReminderOpenAvailable;
            }
            DetachStore();
            _pitchFeedback.Dispose();
            _disposed = true;
        }

        private static string InitialPitchQualityTier() => PitchQualityPolicy.Select(
            new PitchQualitySignals(SystemInfo.systemMemorySize, 0d, 0, false)).Value();

        private static string CurrentPitchQualityTier()
        {
            string current = CrashRuntimeDiagnostics.CurrentQualityTier;
            if (!string.Equals(current, "unknown", StringComparison.Ordinal)) return current;
            string initial = InitialPitchQualityTier();
            CrashRuntimeDiagnostics.InitializeQualityTier(initial);
            return initial;
        }

        void IPitchFeedbackBoundary.OnRelease(PitchHapticCue cue) => _pitchFeedback.OnRelease(cue);
        void IPitchFeedbackBoundary.OnSessionStarted() => _pitchFeedback.OnSessionStarted();
        void IPitchFeedbackBoundary.OnSessionEnded() => _pitchFeedback.OnSessionEnded();
        void IPitchFeedbackBoundary.OnResult(PitchPresentationSnapshot presentation) =>
            _pitchFeedback.OnResult(presentation);

        private void OnReady(GameApplicationStore store)
        {
            if (store == null) return;
            bool storeChanged = !ReferenceEquals(_store, store);
            AttachStore(store);
            _status = ShellRuntimeStatus.Ready;
            _statusMessage = store.RequiresRecoveryNotice
                ? "백업 저장에서 안전하게 복구했습니다."
                : string.Empty;
            UpdateSetupDraftProjection(store.Current, storeChanged);
            UpdateCareerChoiceDraftProjection(store.Current, storeChanged);
            ApplyPersistedSettings(store.Current);
            ClearRetiredDailyResume();
            DrainPendingReminderSetting();
            DrainPendingReminderOpen();
            if (!_coldStartAnalyticsObserved)
            {
                _coldStartAnalyticsObserved = true;
                ObserveReturnPlanOpen("cold");
            }
            Changed?.Invoke();
        }

        private void OnStoreChanged(GameApplicationStore store)
        {
            if (store == null)
            {
                OnUnavailable();
                return;
            }
            OnReady(store);
        }

        private void OnUnavailable()
        {
            DetachStore();
            _status = ShellRuntimeStatus.Unavailable;
            _statusMessage = "저장 서비스 연결이 끊겼습니다. 잠시 후 다시 시도해 주세요.";
            Changed?.Invoke();
        }

        private void OnStartupFailed(Exception exception)
        {
            DetachStore();
            _status = ShellRuntimeStatus.StartupFailed;
            _statusMessage = StartupFailureMessage(exception);
            CrashReporting.RecordUnexpected(exception, "presentation_startup");
            Changed?.Invoke();
        }

        private void AttachStore(GameApplicationStore store)
        {
            if (ReferenceEquals(_store, store)) return;
            DetachStore();
            _store = store;
            _store.StatePublished += OnStatePublished;
            _store.BusyChanged += OnBusyChanged;
        }

        private void DetachStore()
        {
            if (_store == null) return;
            _store.StatePublished -= OnStatePublished;
            _store.BusyChanged -= OnBusyChanged;
            _store = null;
        }

        private void OnStatePublished(GameSaveAggregate state)
        {
            UpdateSetupDraftProjection(state, false);
            UpdateCareerChoiceDraftProjection(state, false);
            ApplyPersistedSettings(state);
            ClearRetiredDailyResume();
            Changed?.Invoke();
        }

        private void OnBusyChanged(bool busy)
        {
            if (!busy)
            {
                DrainPendingReminderSetting();
                DrainPendingReminderOpen();
                ClearRetiredDailyResume();
            }
            Changed?.Invoke();
        }

        private void OnReminderChanged(bool enabled, string source)
        {
            _pendingReminderEnabled = enabled;
            _pendingReminderSource = string.IsNullOrWhiteSpace(source) ? "settings" : source;
            DrainPendingReminderSetting();
        }

        private async void DrainPendingReminderSetting()
        {
            if (_reminderSettingsInFlight || !_pendingReminderEnabled.HasValue ||
                _store == null || _status != ShellRuntimeStatus.Ready || _store.IsBusy) return;

            bool enabled = _pendingReminderEnabled.Value;
            string source = _pendingReminderSource ?? "settings";
            _pendingReminderEnabled = null;
            _pendingReminderSource = null;
            _reminderSettingsInFlight = true;
            GameSaveAggregate before = _store.Current;
            string commandId = "settings:reminder:" + before.Revision + ":" + (++_commandSequence);
            bool saved = false;
            try
            {
                DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(
                    new CommandEnvelope<GameCommand>(
                        commandId,
                        before.Revision,
                        new UpdateGameSettingsCommand(notificationsEnabled: enabled)),
                    CancellationToken.None);
                saved = result.IsSuccess;
                if (!saved)
                {
                    if (!string.Equals(source, "system", StringComparison.Ordinal))
                        AndroidReminderService.Instance?.ApplySavedEnabled(
                            before.Settings.NotificationsEnabled);
                    _statusMessage = "복귀 알림 설정을 저장하지 못했습니다. 이전 설정을 유지합니다.";
                }
                else
                {
                    _statusMessage = enabled
                        ? "복귀 알림 설정을 저장했습니다."
                        : source == "system"
                            ? "기기에서 알림 권한이 꺼져 복귀 알림도 해제했습니다."
                            : "복귀 알림 설정을 저장했습니다.";
                    SafeLog(
                        AnalyticsEvent.ReminderChanged,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["enabled"] = enabled,
                            ["source"] = source,
                        });
                }
            }
            catch (Exception exception)
            {
                if (!string.Equals(source, "system", StringComparison.Ordinal))
                    AndroidReminderService.Instance?.ApplySavedEnabled(
                        before.Settings.NotificationsEnabled);
                CrashReporting.RecordUnexpected(exception, "reminder_settings_update");
                _statusMessage = "복귀 알림 설정을 저장하지 못했습니다. 이전 설정을 유지합니다.";
            }
            finally
            {
                if (string.Equals(source, "system", StringComparison.Ordinal))
                    AndroidReminderService.Instance?.ResolvePersistedDenial(saved);
                _reminderSettingsInFlight = false;
                Changed?.Invoke();
                if (_pendingReminderEnabled.HasValue) DrainPendingReminderSetting();
            }
        }

        private void OnReminderOpenAvailable() => DrainPendingReminderOpen();

        private GameCommand CreateCommand(string actionId, GameSaveAggregate state)
        {
            DateTimeOffset now = DateTimeOffset.UtcNow;
            const string achievementPrefix = "ack_achievement:";
            if (actionId.StartsWith(achievementPrefix, StringComparison.Ordinal))
            {
                string achievementId = actionId.Substring(achievementPrefix.Length);
                return state.Meta.Achievements.Unacknowledged.Contains(achievementId, StringComparer.Ordinal)
                    ? new AcknowledgeAchievementCommand(achievementId)
                    : null;
            }
            switch (actionId)
            {
                case "enter_setup": return new EnterSetupCommand();
                case "start_high_school":
                    if (!SetupSeedInputPolicy.TryResolve(
                        _seedInput,
                        state.InstallId + ":life:" + state.Meta.LifeNumber,
                        out HighSchoolSeedSelection seedSelection,
                        out string resolvedSeed))
                        return null;
                    bool challenge = seedSelection?.IsChallenge == true;
                    return new StartHighSchoolCareerCommand(new StartHighSchoolCareerRequest(
                        resolvedSeed,
                        _presetId,
                        EffectivePlayerName(),
                        _region,
                        state.Meta.LifeNumber,
                        challenge ? Array.Empty<string>() : SetupMemories,
                        challenge ? 0 : state.Meta.AutomaticSoulEarned,
                        challenge ? Array.Empty<string>() : SetupKarmas,
                        challenge ? null : EmptyToNull(_setupSoulDomain),
                        challenge ? Array.Empty<string>() : SetupSoulBoosts,
                        _setupDifficulty,
                        challenge ? null : EmptyToNull(SetupSignatureLegacy),
                        seedSelection?.ChallengeLifeNumber));
                case "quick_rebirth": return new StartQuickRebirthCommand("quick_rebirth", now);
                case "quick_rebirth_from_recap": return new StartQuickRebirthCommand("recap", now);
                case "end_challenge": return new EndChallengeRunCommand();
                case "start_direct_pro":
                    return new StartDirectProCommand(DirectProStartRequestFactory.Create(
                        state,
                        _presetId,
                        EffectivePlayerName()));
                case "skip_tutorial": return new SkipTutorialCommand();
                case "choose_pledge":
                    string pledge = GetChoice("run_pledge");
                    return RunPledgeRules.IsValidSelection(state, pledge) && !string.IsNullOrWhiteSpace(pledge)
                        ? new ChoosePledgeCommand(pledge, now)
                        : null;
                case "skip_pledge":
                    return RunPledgeRules.IsValidSelection(state, null)
                        ? new ChoosePledgeCommand(null, now)
                        : null;
                case "choose_school": return HighSchool("choose_school", Selected("school", state.HighSchool?.SchoolChoices), now);
                case "train":
                case "train_block":
                    string focus = Selected("training_focus", state.HighSchool?.TrainingFocusChoices);
                    string intensity = Selected("training_intensity", state.HighSchool?.TrainingIntensityChoices);
                    string trainingTarget = Selected("training_pitch", state.HighSchool?.TrainingPitchChoices);
                    string trainingPayload = CareerActionSelectionPolicy.TrainingPayload(
                        focus,
                        intensity,
                        trainingTarget,
                        state.HighSchool?.TrainingPitchChoices?.Count > 0);
                    return string.IsNullOrWhiteSpace(trainingPayload)
                        ? null
                        : HighSchool(
                            actionId == "train_block"
                                ? HighSchoolTrainingActionPayload.BlockAction
                                : HighSchoolTrainingActionPayload.SingleAction,
                            trainingPayload,
                            now);
                case "relationship": return HighSchool("relationship", Selected("relationship", state.HighSchool?.RelationshipChoices), now);
                case "awakening": return HighSchool("awakening", Selected("awakening", state.HighSchool?.AwakeningChoices), now);
                case "advance_chapter": return HighSchool("advance_chapter", null, now);
                case "resolve_draft": return HighSchool("resolve_draft", null, now);
                case "open_legacy": return HighSchool("open_legacy", null, now);
                case "enter_pro": return new EnterProFromDraftCommand();
                case "decline_pro": return new DeclineProCareerCommand();
                case "sign_pro_contract": return new SignProContractCommand();
                case "advance_pro_week":
                case "advance_pro_segment":
                    string proPlan = Selected("pro_week_plan", state.Pro?.WeekPlanChoices);
                    string developmentPitch = Selected("pro_development_pitch", state.Pro?.DevelopmentPitchChoices);
                    string proPayload = CareerActionSelectionPolicy.ProWeekPayload(
                        proPlan,
                        developmentPitch,
                        state.Pro?.DevelopmentPitchChoices?.Count > 0);
                    return string.IsNullOrWhiteSpace(proPayload)
                        ? null
                        : Pro(
                            actionId == "advance_pro_segment"
                                ? ProWeekActionPayload.AdvanceSegmentAction
                                : ProWeekActionPayload.AdvanceWeekAction,
                            proPayload,
                            now);
                case "resolve_pro_decision": return Pro("season_decision", Selected("pro_season_decision", state.Pro?.SeasonDecision?.Choices), now);
                case "review_season": return Pro("review_season", null, now);
                case "continue_pro_career": return Pro("offseason", Selected("pro_offseason", state.Pro?.OffseasonChoices), now);
                case "retire_pro": return new RetireProCareerCommand(now);
                case "finalize_high_school_legacy":
                    if (state.HighSchool?.LegacySelectionMode == LegacySelectionMode.SignatureLegacy)
                    {
                        string signature = Selected("legacy_signature", state.HighSchool.SignatureLegacyChoices);
                        return string.IsNullOrWhiteSpace(signature)
                            ? null
                            : new FinalizeHighSchoolLegacyCommand(Array.Empty<string>(), signature, now);
                    }
                    IReadOnlyList<string> memories = GetChoices("legacy_memories");
                    bool validMemories = state.HighSchool != null && memories.Count == state.HighSchool.MemorySlots &&
                        memories.All(value => state.HighSchool.LegacyMemoryChoices.Any(option =>
                            option.Enabled && option.Payload == value));
                    return validMemories
                        ? new FinalizeHighSchoolLegacyCommand(memories, null, now)
                        : null;
                case "begin_rebirth": return new BeginRebirthCommand(now);
                case "save_next_run_intent":
                    NextRunIntentState nextIntent = RunPledgeRules.SuggestedNextRunIntent(state.HighSchool);
                    return nextIntent == null ? null : new SetNextRunIntentCommand(nextIntent);
                case "claim_weekly": return new ClaimWeeklyRewardCommand(now);
                case "begin_pitch": return BeginPitch(state, now);
                case "begin_tutorial_pitch": return BeginTutorialPitch(state, now);
                case "acknowledge_pitch_result":
                    return string.IsNullOrWhiteSpace(state.PendingPitchCompletion?.CompletionId)
                        ? null
                        : new AcknowledgePitchResultCommand(state.PendingPitchCompletion.CompletionId);
                case "open_return_plan": return new CompleteReturnPlanInteractionCommand(false, now);
                case "dismiss_return_plan": return new CompleteReturnPlanInteractionCommand(true, now);
                default: return null;
            }
        }

        private static GameCommand HighSchool(string kind, string value, DateTimeOffset now) =>
            new AdvanceHighSchoolCommand(new HighSchoolAction(kind, value), now);

        private static GameCommand Pro(string kind, string value, DateTimeOffset now) =>
            new AdvanceProCommand(new ProCareerAction(kind, value), now);

        private static GameCommand BeginPitch(GameSaveAggregate state, DateTimeOffset now)
        {
            PitchCareerKind kind = state.Pro != null ? PitchCareerKind.Pro : PitchCareerKind.HighSchool;
            string gameId = "pitch:" + kind.ToString().ToLowerInvariant() + ":" + (state.Revision + 1);
            string scenario = kind == PitchCareerKind.Pro ? "pro-important" : "high-school-important";
            return new BeginPitchSessionCommand(gameId, kind, scenario, 6, now);
        }

        private static GameCommand BeginTutorialPitch(GameSaveAggregate state, DateTimeOffset now)
        {
            if (state.HighSchool?.Phase != HighSchoolPhase.Prologue) return null;
            string gameId = "pitch:tutorial:" + (state.Revision + 1);
            return new BeginPitchSessionCommand(
                gameId,
                PitchCareerKind.Tutorial,
                "tutorial",
                2,
                now);
        }

        private static string EmptyToNull(string value) =>
            string.IsNullOrWhiteSpace(value) ? null : value;

        private string EffectivePlayerName() =>
            SetupPlayerNamePolicy.Resolve(_playerName, SuggestedPlayerName);

        private string Selected(
            string group,
            IReadOnlyList<Baseball.Application.Commands.CareerChoiceReadModel> choices)
        {
            if (choices == null || choices.Count == 0) return null;
            string selected = GetChoice(group);
            Baseball.Application.Commands.CareerChoiceReadModel match = choices.FirstOrDefault(option =>
                option.Enabled && string.Equals(option.Payload, selected, StringComparison.Ordinal));
            return match?.Payload;
        }

        private ShellRoute DestinationAfterCommand(ScreenActionViewModel action)
        {
            switch (action.Id)
            {
                case "claim_weekly": return action.Target;
                case "acknowledge_pitch_result": return action.Target;
                case "begin_pitch": return ShellRoute.PitchHandoff;
                case "begin_tutorial_pitch": return ShellRoute.PitchHandoff;
                default: return PreferredRoute;
            }
        }

        private async Task<ShellActionResult> ResetAsync(CancellationToken cancellationToken)
        {
            string previousInstallId = _store.Current.InstallId;
            string newInstallId = AnonymousInstallIdentity.CreateCandidate();
            AndroidReminderService reminders = AndroidReminderService.Instance;
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                AnonymousInstallIdentity.PrepareReset(previousInstallId, newInstallId);
                reminders?.PrepareLocalReset();
                await _store.ResetWithPreparedIdentityAsync(
                    newInstallId,
                    (installId, token) =>
                    {
                        token.ThrowIfCancellationRequested();
                        if (!AnonymousInstallIdentity.MarkPreparedResetStep(
                                InstallResetStep.RepositoryReset))
                            throw new InvalidOperationException("reset.repository_receipt_failed");
                        AnonymousInstallIdentity.PublishPreparedReset(installId);
                        return Task.CompletedTask;
                    },
                    cancellationToken);
            }
            catch (GameResetException exception)
            {
                CrashReporting.RecordUnexpected(exception, exception.ResetCommitted
                    ? "save_reset_committed_pending"
                    : "save_reset_reconcile_pending");
                return ResetRequiresRestart();
            }
            catch (OperationCanceledException)
            {
                return ResetRequiresRestart();
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "save_reset_reconcile_pending");
                return ResetRequiresRestart();
            }

            try { AnalyticsBootstrap.ResetIdentityAndOnceFlags(newInstallId); }
            catch { /* Analytics identity reset must not invalidate the atomic save/identity reset. */ }
            _analyticsReceiptsInFlight.Clear();
            _analyticsReceiptsAwaitingEnqueue.Clear();
            _externalRoute = null;
            _externalRouteReminderToken = null;
            _consumedExternalRoute = null;
            _consumedExternalRouteReminderToken = null;
            reminders?.ResetLocalState();
            PlayReviewPrompt.ResetLocalAttempt();
            if (AndroidShareService.TryClearShareCache())
            {
                AnonymousInstallIdentity.MarkPreparedResetStep(
                    InstallResetStep.ShareCacheCleaned);
            }
            ApplyPersistedSettings(_store.Current);
            AnonymousInstallIdentity.TryCompletePreparedReset();
            return ShellActionResult.Success(ShellRoute.Opening, "저장 데이터와 익명 식별자를 함께 초기화했습니다.");
        }

        private ShellActionResult ResetRequiresRestart()
        {
            _status = ShellRuntimeStatus.StartupFailed;
            _statusMessage =
                "초기화 요청을 안전하게 기록했습니다. 앱을 완전히 닫고 다시 열면 초기화를 마무리합니다.";
            Changed?.Invoke();
            return ShellActionResult.Failure(_statusMessage);
        }
    }
}
