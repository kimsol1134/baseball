#if UNITY_EDITOR || (DEVELOPMENT_BUILD && BASEBALL_INTERNAL_QA)
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Core.Domain;
using Baseball.Platform.Analytics;
using Baseball.Platform.Crash;
using Baseball.Presentation.Pitch;
using Baseball.Presentation.Shell;
using UnityEngine;

namespace Baseball.Platform.InternalQa
{
    /// <summary>
    /// Development-build-only deterministic QA bridge. The outer preprocessor condition requires
    /// both DevelopmentBuild and the LocalVerification-only define in Android players, so none of
    /// the command strings or destructive fixture code exists in a release-candidate assembly.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class InternalQaBridge : MonoBehaviour
    {
        private const float ReadyTimeoutSeconds = 60f;
        private const float CrashReporterReadyTimeoutSeconds = 20f;
        private const string MarkerPrefix = "BASEBALL_QA_MARKER schema=1";
        private bool _running;
        private bool _showSurface;
        private bool _crashArmed;
        private string _seed = InternalQaRequest.DefaultSeed;
        private string _phase = "prologue";
        private string _quality = "high";
        private string _pitch = "four_seam";
        private string _lastStatus = "대기 중";

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Install()
        {
            if (FindAnyObjectByType<InternalQaBridge>() != null) return;
            var bridge = new GameObject("Baseball Internal QA Bridge");
            DontDestroyOnLoad(bridge);
            bridge.AddComponent<InternalQaBridge>();
        }

        private IEnumerator Start()
        {
            float deadline = Time.realtimeSinceStartup + ReadyTimeoutSeconds;
            while (!RuntimeGameServices.IsReady && Time.realtimeSinceStartup < deadline)
            {
                yield return null;
            }

            if (!RuntimeGameServices.TryGetStore(out GameApplicationStore store))
            {
                Mark("bridge_ready", "failed", "reason=runtime_timeout");
                yield break;
            }

            Mark("bridge_ready", "passed", "phase=" + StageValue(store.Current.Stage));
            MarkRestoredTutorialCheckpoint(store);

#if UNITY_ANDROID && !UNITY_EDITOR
            if (TryConsumeAndroidIntent(out InternalQaRequest request, out string errorCode))
            {
                Execute(request);
            }
            else if (!string.IsNullOrEmpty(errorCode))
            {
                Mark("command_rejected", "failed", "reason=" + errorCode);
            }
#endif
        }

        private void OnGUI()
        {
            if (GUI.Button(new Rect(8f, 8f, 56f, 38f), "QA")) _showSurface = !_showSurface;
            if (!_showSurface) return;

            GUILayout.BeginArea(new Rect(8f, 52f, 360f, 540f), GUI.skin.box);
            GUILayout.Label("내부 QA · RC에는 포함되지 않음");
            GUILayout.Label("seed");
            _seed = GUILayout.TextField(_seed, 24);
            GUILayout.Label("phase: " + _phase + " / quality: " + _quality);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("opening")) RunSurface("fixture", "opening");
            if (GUILayout.Button("setup")) RunSurface("fixture", "setup");
            if (GUILayout.Button("prologue")) RunSurface("fixture", "prologue");
            GUILayout.EndHorizontal();
            if (GUILayout.Button("school selection")) RunSurface("fixture", "school_selection");
            if (GUILayout.Button("onboarding → tutorial checkpoint"))
                RunSurface("tutorial-checkpoint", "tutorial_checkpoint");
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("직구")) RunPitchSurface("four_seam");
            if (GUILayout.Button("슬라이더")) RunPitchSurface("slider");
            GUILayout.EndHorizontal();
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("커브")) RunPitchSurface("curveball");
            if (GUILayout.Button("체인지업")) RunPitchSurface("changeup");
            GUILayout.EndHorizontal();
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("nonfatal")) RunSurface("nonfatal", _phase);
            if (GUILayout.Button("analytics fake/log")) RunSurface("analytics-fake", _phase);
            GUILayout.EndHorizontal();
            if (GUILayout.Button("save corruption recovery")) RunSurface("save-corruption", _phase);
            if (GUILayout.Button("atomic swap fault rollback")) RunSurface("save-fault", _phase);
            if (GUILayout.Button("low-storage save failure proxy")) RunSurface("save-failure", _phase);
            if (!_crashArmed)
            {
                if (GUILayout.Button("crash probe 잠금 해제")) _crashArmed = true;
            }
            else if (GUILayout.Button("CRASH PROBE 실행"))
            {
                _crashArmed = false;
                RunSurface("crash", _phase);
            }
            GUILayout.Label("상태: " + _lastStatus);
            GUILayout.EndArea();
        }

        private void RunSurface(string command, string phase)
        {
            _phase = phase;
            if (!InternalQaRequest.TryCreate(
                command, _seed, phase, _quality, out InternalQaRequest request, out string error))
            {
                Mark("command_rejected", "failed", "reason=" + error);
                return;
            }
            Execute(request);
        }

        private void RunPitchSurface(string pitch)
        {
            _pitch = pitch;
            if (!InternalQaRequest.TryCreate(
                    "pitch-sample", _seed, _phase, _quality, _pitch,
                    out InternalQaRequest request, out string error))
            {
                Mark("command_rejected", "failed", "reason=" + error);
                return;
            }
            Execute(request);
        }

        private async void Execute(InternalQaRequest request)
        {
            if (_running)
            {
                Mark("command_rejected", "failed", "reason=command_busy");
                return;
            }

            _running = true;
            try
            {
                switch (request.Command)
                {
                    case "ping":
                        Mark("ping", "passed", "bridge=ready");
                        break;
                    case "save-inspect":
                        InspectSave();
                        break;
                    case "fixture":
                    case "tutorial-checkpoint":
                        await ApplyFixture(request);
                        break;
                    case "pitch-sample":
                        StartCoroutine(PlayPitchSample(request));
                        return;
                    case "nonfatal":
                        await RunNonfatalProbe();
                        break;
                    case "crash":
                        StartCoroutine(RunCrashProbe());
                        return;
                    case "save-corruption":
                    case "save-fault":
                    case "save-failure":
                        await RunSaveProbe(request.Command);
                        break;
                    case "analytics-fake":
                        RunAnalyticsProbe();
                        break;
                    default:
                        throw new InvalidOperationException("internal_qa.command_unreachable");
                }
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "internal_qa_bridge");
                Mark("command_failed", "failed", "reason=" + SafeReason(exception));
            }
            finally
            {
                if (request.Command != "pitch-sample" && request.Command != "crash") _running = false;
            }
        }

        private static async Task ApplyFixture(InternalQaRequest request)
        {
            if (!RuntimeGameServices.TryGetStore(out GameApplicationStore store))
                throw new InvalidOperationException("runtime_not_ready");

            string installId = store.Current.InstallId;
            await store.ResetAsync(installId);
            if (request.Phase == "opening")
            {
                Mark("fixture_ready", "passed", "phase=opening seed=" + request.Seed);
                return;
            }

            await Dispatch(store, request.Seed + ":setup", new EnterSetupCommand());
            if (request.Phase == "setup")
            {
                Mark("fixture_ready", "passed", "phase=setup seed=" + request.Seed);
                return;
            }

            var start = new StartHighSchoolCareerRequest(
                request.Seed,
                "power_prospect",
                "내부 QA 투수",
                "서울",
                store.Current.Meta.LifeNumber,
                difficulty: "standard");
            await Dispatch(store, request.Seed + ":prologue", new StartHighSchoolCareerCommand(start));
            if (request.Phase == "prologue")
            {
                Mark("fixture_ready", "passed", "phase=prologue seed=" + request.Seed);
                return;
            }

            if (request.Phase == "school_selection")
            {
                await Dispatch(store, request.Seed + ":school-selection", new SkipTutorialCommand());
                Mark("fixture_ready", "passed", "phase=school_selection seed=" + request.Seed);
                return;
            }

            if (request.Phase == "training" || request.Phase == "overview" ||
                request.Phase == "relationship")
            {
                await Dispatch(store, request.Seed + ":school-selection", new SkipTutorialCommand());
                await Dispatch(
                    store,
                    request.Seed + ":pledge-skip",
                    new ChoosePledgeCommand(null, new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero)));
                CareerChoiceReadModel school = store.Current.HighSchool?.SchoolChoices?.Count > 0
                    ? store.Current.HighSchool.SchoolChoices[0]
                    : null;
                if (school == null) throw new InvalidOperationException("training_fixture_school_missing");
                await Dispatch(
                    store,
                    request.Seed + ":school",
                    new AdvanceHighSchoolCommand(
                        new HighSchoolAction("choose_school", school.Payload),
                        new DateTimeOffset(2026, 8, 11, 0, 1, 0, TimeSpan.Zero)));
                if (request.Phase == "relationship")
                {
                    await Dispatch(
                        store,
                        request.Seed + ":relationship-training-block",
                        new AdvanceHighSchoolCommand(
                            new HighSchoolAction("train_block", "velocity:standard"),
                            new DateTimeOffset(2026, 8, 11, 0, 2, 0, TimeSpan.Zero)));
                    if (store.Current.HighSchool?.Phase != HighSchoolPhase.Relationship)
                        throw new InvalidOperationException("relationship_fixture_phase_missing");
                    BaseballShellHost relationshipHost = FindAnyObjectByType<BaseballShellHost>();
                    if (relationshipHost?.Controller == null)
                        throw new InvalidOperationException("relationship_fixture_shell_missing");
                    relationshipHost.Controller.Navigate(ShellRoute.Relationship);
                }
                if (request.Phase == "overview")
                {
                    BaseballShellHost host = FindAnyObjectByType<BaseballShellHost>();
                    if (host?.Controller == null)
                        throw new InvalidOperationException("overview_fixture_shell_missing");
                    host.Controller.Navigate(ShellRoute.HighSchoolOverview);
                }
                Mark("fixture_ready", "passed", "phase=" + request.Phase + " seed=" + request.Seed);
                return;
            }

            var startedAt = new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero);
            await Dispatch(
                store,
                request.Seed + ":tutorial-checkpoint",
                new BeginPitchSessionCommand(
                    "internal-qa-tutorial",
                    PitchCareerKind.Tutorial,
                    "internal-qa-tutorial",
                    2,
                    startedAt));
            PitchResumeState resume = store.Current.PitchResume;
            if (resume == null || resume.CareerKind != PitchCareerKind.Tutorial || resume.Scenario == null)
                throw new InvalidOperationException("tutorial_checkpoint_missing");
            Mark(
                "tutorial_checkpoint_saved",
                "passed",
                "phase=tutorial scenario=" + SafeToken(resume.ScenarioId));
        }

        private static async Task Dispatch(GameApplicationStore store, string commandId, GameCommand command)
        {
            var envelope = new CommandEnvelope<GameCommand>(
                "internal-qa:" + commandId,
                store.Current.Revision,
                command);
            DispatchResult<GameSaveAggregate> result = await store.DispatchAsync(envelope);
            if (!result.IsSuccess)
                throw new InvalidOperationException("dispatch_" + SafeToken(result.ErrorCode));
        }

        private IEnumerator PlayPitchSample(InternalQaRequest request)
        {
            var stageObject = new GameObject("Baseball Internal QA Pitch Sample");
            var stage = stageObject.AddComponent<PitchStageController>();
            Task<bool> preparation = stage.PrepareVisualsAsync(
                new AddressableVisualAssetLoader(),
                System.Threading.CancellationToken.None);
            while (!preparation.IsCompleted) yield return null;
            if (preparation.IsFaulted || preparation.IsCanceled || !preparation.Result)
            {
                string reason = preparation.IsFaulted
                    ? SafeReason(preparation.Exception?.GetBaseException())
                    : preparation.IsCanceled
                        ? "visual_preparation_canceled"
                        : SafeToken(stage.VisualPreparationError);
                Mark("pitch_presentation_completed", "failed", "reason=" + reason);
                Destroy(stageObject);
                _running = false;
                yield break;
            }
            BaseballShellController shellController =
                FindAnyObjectByType<BaseballShellHost>()?.Controller;
            shellController?.SetPitchPresentationActive(true);
            PitchPresentationSnapshot expected = InternalQaPitchFixture.Create(request.Seed, request.PitchType);
            bool readable = false;
            bool completed = false;
            stage.ResultReadable += snapshot =>
            {
                if (!ReferenceEquals(snapshot, expected)) return;
                readable = true;
                Mark(
                    "pitch_result_readable",
                    "passed",
                    "quality=" + request.Quality.Value() + " pitch=" + request.PitchType.Value() +
                    " pitch_id=" + SafeToken(snapshot.PitchId));
            };
            stage.PresentationCompleted += snapshot =>
            {
                if (ReferenceEquals(snapshot, expected)) completed = true;
            };
            stageObject.SendMessage("ApplyQuality", request.Quality, SendMessageOptions.RequireReceiver);
            stage.Play(expected);

            float deadline = Time.realtimeSinceStartup + 10f;
            while (!completed && Time.realtimeSinceStartup < deadline) yield return null;
            if (readable && completed)
            {
                Mark(
                    "pitch_presentation_completed",
                    "passed",
                    "quality=" + request.Quality.Value() + " pitch=" + request.PitchType.Value() +
                    " outcome=" + expected.Call.Value());
            }
            else
            {
                Mark(
                    "pitch_presentation_completed",
                    "failed",
                    "reason=" + (readable ? "completion_timeout" : "readable_timeout"));
            }
            shellController?.SetPitchPresentationActive(false);
            Destroy(stageObject);
            _running = false;
        }

        private static async Task RunNonfatalProbe()
        {
            float deadline = Time.realtimeSinceStartup + CrashReporterReadyTimeoutSeconds;
            while (!CrashReporting.Reporter.IsReady && Time.realtimeSinceStartup < deadline)
            {
                await Task.Delay(100);
            }

            if (!CrashReporting.Reporter.IsReady)
            {
                Mark("nonfatal_invoked", "failed", "reason=reporter_not_ready");
                return;
            }

            CrashReporting.RecordUnexpected(
                new InvalidOperationException("internal_qa_nonfatal_probe"),
                "internal_qa_nonfatal");
            Mark(
                "nonfatal_invoked",
                "passed",
                "reporter_ready=true");
        }

        private IEnumerator RunCrashProbe()
        {
            Mark("crash_requested", "passed", "category=abort");
            // Give the passive first-interactive marker and log transport a bounded window before
            // intentionally terminating the process. This is frame-driven; no blocking sleep.
            yield return new WaitForSecondsRealtime(0.5f);
#if UNITY_ANDROID && !UNITY_EDITOR
            UnityEngine.Diagnostics.Utils.ForceCrash(UnityEngine.Diagnostics.ForcedCrashCategory.Abort);
#else
            Mark("crash_executed", "not_supported", "reason=requires_android_player");
            _running = false;
#endif
        }

        private static async Task RunSaveProbe(string command)
        {
            string directory = PrepareProbeDirectory(command);
            try
            {
                switch (command)
                {
                    case "save-corruption":
                        await VerifyCorruptionRecovery(directory);
                        break;
                    case "save-fault":
                        await VerifyFaultRollback(directory);
                        break;
                    case "save-failure":
                        await VerifyWriteFailure(directory);
                        break;
                }
            }
            finally
            {
                DeleteProbeDirectory(directory);
            }
        }

        private static async Task VerifyCorruptionRecovery(string directory)
        {
            var layout = new SaveFileLayout(directory);
            var initial = GameSaveAggregate.Initial("internal-qa-install");
            var next = initial.Commit("internal-qa:revision-one", stage: ApplicationStage.Setup);
            using (var repository = CreateRepository(layout))
            {
                await repository.SaveAsync(initial, initial.Revision);
                await repository.SaveAsync(next, next.Revision);
            }
            File.WriteAllBytes(layout.CanonicalPath, new byte[] { 0x7b, 0x00, 0x7d });
            using (var reader = CreateRepository(layout))
            {
                SaveLoadResult<GameSaveAggregate> recovered = await reader.LoadAsync();
                if (recovered.Status != SaveLoadStatus.RecoveredBackup ||
                    recovered.Envelope?.Payload?.Revision != initial.Revision)
                {
                    throw new InvalidOperationException("corruption_recovery_failed");
                }
            }
            Mark("save_corruption_recovered", "passed", "source=backup revision=0");
        }

        private static async Task VerifyFaultRollback(string directory)
        {
            var layout = new SaveFileLayout(directory);
            var initial = GameSaveAggregate.Initial("internal-qa-install");
            var next = initial.Commit("internal-qa:revision-one", stage: ApplicationStage.Setup);
            using (var repository = CreateRepository(layout))
            {
                await repository.SaveAsync(initial, initial.Revision);
            }
            try
            {
                using (var faulted = new AtomicSaveRepository<GameSaveAggregate>(
                           layout,
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority(),
                           faultInjector: new ThrowAtFault(SaveFaultPoint.AfterCanonicalSwap)))
                {
                    await faulted.SaveAsync(next, next.Revision);
                }
                throw new InvalidOperationException("fault_not_triggered");
            }
            catch (SavePersistenceException exception) when (exception.Code == SaveFailureCode.IoFailed)
            {
                // Expected: repository must restore the prior canonical before surfacing failure.
            }
            using (var reader = CreateRepository(layout))
            {
                SaveLoadResult<GameSaveAggregate> restored = await reader.LoadAsync();
                if (restored.Envelope?.Payload?.Revision != initial.Revision)
                    throw new InvalidOperationException("fault_rollback_failed");
            }
            Mark("save_fault_rollback", "passed", "fault=after_canonical_swap revision=0");
        }

        private static async Task VerifyWriteFailure(string directory)
        {
            var layout = new SaveFileLayout(directory);
            try
            {
                using (var repository = new AtomicSaveRepository<GameSaveAggregate>(
                           layout,
                           new WriteFailingFileSystem(new SystemAtomicFileSystem()),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                {
                    GameSaveAggregate initial = GameSaveAggregate.Initial("internal-qa-install");
                    await repository.SaveAsync(initial, initial.Revision);
                }
                throw new InvalidOperationException("save_failure_not_triggered");
            }
            catch (SavePersistenceException exception) when (exception.Code == SaveFailureCode.IoFailed)
            {
                Mark("save_failure_proxy", "passed", "fault=enospc_simulated code=io_failed");
            }
        }

        private static AtomicSaveRepository<GameSaveAggregate> CreateRepository(SaveFileLayout layout)
        {
            return new AtomicSaveRepository<GameSaveAggregate>(
                layout,
                new SystemAtomicFileSystem(),
                new GameSaveValidator(),
                new GameSaveSemanticPriority());
        }

        private static string PrepareProbeDirectory(string command)
        {
            string root = Path.GetFullPath(Path.Combine(UnityEngine.Application.persistentDataPath, "internal-qa"));
            string directory = Path.GetFullPath(Path.Combine(root, SafeToken(command)));
            if (!directory.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
                throw new InvalidOperationException("probe_path_outside_root");
            DeleteProbeDirectory(directory);
            Directory.CreateDirectory(directory);
            return directory;
        }

        private static void DeleteProbeDirectory(string directory)
        {
            string root = Path.GetFullPath(Path.Combine(UnityEngine.Application.persistentDataPath, "internal-qa"));
            string resolved = Path.GetFullPath(directory);
            if (!resolved.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
                throw new InvalidOperationException("probe_delete_outside_root");
            if (Directory.Exists(resolved)) Directory.Delete(resolved, true);
        }

        private static void RunAnalyticsProbe()
        {
            var destination = new InternalQaAnalyticsDestination();
            var service = new AnalyticsService(
                new AnalyticsContext("internal-qa", "local", AnalyticsDistribution.Internal),
                new IAnalyticsDestination[] { destination },
                new InternalQaOnceStore(),
                "internal-qa-anonymous");
            service.Log(
                AnalyticsEvent.FirstPitch,
                new Dictionary<string, object>(StringComparer.Ordinal)
                {
                    ["status"] = "internal_qa"
                });
            if (destination.EventCount != 1 || destination.LastEvent != "first_pitch")
                throw new InvalidOperationException("analytics_fake_log_missing");
            Mark(
                "analytics_fake_logged",
                "passed",
                "event=" + destination.LastEvent + " count=" + destination.EventCount);
        }

        private static void MarkRestoredTutorialCheckpoint(GameApplicationStore store)
        {
            PitchResumeState resume = store.Current.PitchResume;
            if (resume == null || resume.CareerKind != PitchCareerKind.Tutorial) return;
            Mark(
                "tutorial_checkpoint_restored",
                "passed",
                "phase=tutorial scenario=" + SafeToken(resume.ScenarioId));
        }

        private static void InspectSave()
        {
            if (!RuntimeGameServices.TryGetStore(out GameApplicationStore store))
                throw new InvalidOperationException("runtime_not_ready");

            GameSaveAggregate current = store.Current;
            HighSchoolCareerReadModel highSchool = current.HighSchool;
            string coreCommitment = "none";
            if (highSchool != null && !string.IsNullOrEmpty(highSchool.CoreStateJson))
            {
                using (SHA256 sha256 = SHA256.Create())
                {
                    coreCommitment = BitConverter.ToString(
                        sha256.ComputeHash(Encoding.UTF8.GetBytes(highSchool.CoreStateJson)))
                        .Replace("-", string.Empty)
                        .ToLowerInvariant();
                }
            }
            Mark(
                "save_inspect",
                "passed",
                "revision=" + current.Revision.ToString() +
                " aggregateVersion=" + current.AggregateVersion.ToString() +
                " stage=" + StageValue(current.Stage) +
                " highSchool=" + (current.HighSchool != null ? "present" : "null") +
                " pro=" + (current.Pro != null ? "present" : "null") +
                " pitchResume=" + (current.PitchResume != null ? "present" : "null") +
                " pendingPitchCompletion=" + (current.PendingPitchCompletion != null ? "present" : "null") +
                " deleted=" + (current.Deleted ? "true" : "false") +
                " settings=" + SettingsToken(current.Settings) +
                " commandReceiptCount=" + current.CommandReceipts.Count.ToString() +
                " analyticsReceiptCount=" + (current.AnalyticsReceipts?.Records?.Count ?? 0).ToString() +
                " coreCommitmentSha256=" + coreCommitment);
        }

        private static string SettingsToken(GameSettingsState settings)
        {
            if (settings == null) return "missing";
            return "auto=" + (settings.AutoReleaseEnabled ? "1" : "0") +
                ",sound=" + (settings.SoundEnabled ? "1" : "0") +
                ",music=" + (settings.MusicEnabled ? "1" : "0") +
                ",haptics=" + (settings.HapticsEnabled ? "1" : "0") +
                ",notifications=" + (settings.NotificationsEnabled ? "1" : "0") +
                ",contrast=" + (settings.HighContrastEnabled ? "1" : "0") +
                ",motion=" + (settings.ReducedMotionEnabled ? "1" : "0");
        }

        private static bool TryConsumeAndroidIntent(
            out InternalQaRequest request,
            out string errorCode)
        {
            request = null;
            errorCode = null;
            try
            {
                using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                using (AndroidJavaObject activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
                using (AndroidJavaObject intent = activity?.Call<AndroidJavaObject>("getIntent"))
                {
                    if (intent == null) return false;
                    string command = intent.Call<string>("getStringExtra", InternalQaRequest.CommandExtra);
                    if (string.IsNullOrWhiteSpace(command)) return false;
                    string seed = intent.Call<string>("getStringExtra", InternalQaRequest.SeedExtra);
                    string phase = intent.Call<string>("getStringExtra", InternalQaRequest.PhaseExtra);
                    string quality = intent.Call<string>("getStringExtra", InternalQaRequest.QualityExtra);
                    string pitch = intent.Call<string>("getStringExtra", InternalQaRequest.PitchExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.CommandExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.SeedExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.PhaseExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.QualityExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.PitchExtra);
                    return InternalQaRequest.TryCreate(
                        command, seed, phase, quality, pitch, out request, out errorCode);
                }
            }
            catch (Exception exception)
            {
                errorCode = "intent_" + SafeReason(exception);
                return false;
            }
        }

        private static void RemoveIntentExtra(AndroidJavaObject intent, string key)
        {
            // android.content.Intent.removeExtra(String) returns void. Asking Unity's JNI bridge
            // for an AndroidJavaObject changes the expected method signature and fails at runtime.
            intent.Call("removeExtra", key);
        }

        private static void Mark(string name, string status, string detail)
        {
            string line = MarkerPrefix + " name=" + SafeToken(name) + " status=" + SafeToken(status);
            if (!string.IsNullOrWhiteSpace(detail)) line += " " + detail;
            Debug.Log(line);
            InternalQaBridge bridge = FindAnyObjectByType<InternalQaBridge>();
            if (bridge != null) bridge._lastStatus = line;
        }

        private static string StageValue(ApplicationStage stage) => stage.ToString().ToLowerInvariant();

        private static string SafeReason(Exception exception)
        {
            return SafeToken(exception?.GetType().Name ?? "unknown").ToLowerInvariant();
        }

        private static string SafeToken(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return "unknown";
            char[] characters = value.ToCharArray();
            for (int index = 0; index < characters.Length; index++)
            {
                char character = characters[index];
                if (!(char.IsLetterOrDigit(character) || character == '-' || character == '_' || character == ':'))
                    characters[index] = '_';
            }
            return new string(characters);
        }

        private sealed class ThrowAtFault : ISaveFaultInjector
        {
            private readonly SaveFaultPoint _target;
            public ThrowAtFault(SaveFaultPoint target) => _target = target;
            public void Checkpoint(SaveFaultPoint point)
            {
                if (point == _target) throw new IOException("internal QA injected atomic-save fault");
            }
        }

        private sealed class WriteFailingFileSystem : IAtomicFileSystem
        {
            private readonly IAtomicFileSystem _inner;
            public WriteFailingFileSystem(IAtomicFileSystem inner) => _inner = inner;
            public bool FileExists(string path) => _inner.FileExists(path);
            public byte[] ReadAllBytes(string path) => _inner.ReadAllBytes(path);
            public void CreateDirectory(string path) => _inner.CreateDirectory(path);
            public void WriteAllBytesAndFlush(string path, byte[] bytes) =>
                throw new IOException("ENOSPC simulated by internal QA");
            public void CopyFile(string sourcePath, string destinationPath, bool overwrite) =>
                _inner.CopyFile(sourcePath, destinationPath, overwrite);
            public void MoveFile(string sourcePath, string destinationPath) =>
                _inner.MoveFile(sourcePath, destinationPath);
            public void ReplaceFile(string sourcePath, string destinationPath) =>
                _inner.ReplaceFile(sourcePath, destinationPath);
            public void DeleteFile(string path) => _inner.DeleteFile(path);
            public IReadOnlyList<string> GetFiles(string directoryPath, string searchPattern) =>
                _inner.GetFiles(directoryPath, searchPattern);
        }

        private sealed class InternalQaAnalyticsDestination : IAnalyticsDestination
        {
            public AnalyticsDestinationKind Kind => AnalyticsDestinationKind.Test;
            public bool IsReady => true;
            public int EventCount { get; private set; }
            public string LastEvent { get; private set; }
            public void SetAnonymousInstallId(string installId) { }
            public void Log(string eventName, IReadOnlyDictionary<string, object> properties)
            {
                EventCount++;
                LastEvent = eventName;
            }
            public void Flush() { }
        }

        private sealed class InternalQaOnceStore : IAnalyticsOnceStore
        {
            private readonly HashSet<string> _keys = new HashSet<string>(StringComparer.Ordinal);
            public bool TryMark(string key) => _keys.Add(key);
            public void Clear() => _keys.Clear();
        }
    }
}
#endif
