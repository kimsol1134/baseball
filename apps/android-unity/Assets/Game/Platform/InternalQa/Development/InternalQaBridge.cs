#if UNITY_EDITOR || (DEVELOPMENT_BUILD && BASEBALL_INTERNAL_QA)
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
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
        private const string MarkerPrefix = "BASEBALL_QA_MARKER schema=1";
        private bool _running;
        private bool _showSurface;
        private bool _crashArmed;
        private string _seed = InternalQaRequest.DefaultSeed;
        private string _phase = "prologue";
        private string _quality = "high";
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
            if (GUILayout.Button("onboarding → tutorial checkpoint"))
                RunSurface("tutorial-checkpoint", "tutorial_checkpoint");
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("pitch High")) RunPitchSurface("high");
            if (GUILayout.Button("pitch Low")) RunPitchSurface("low");
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

        private void RunPitchSurface(string quality)
        {
            _quality = quality;
            RunSurface("pitch-sample", _phase);
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
                    case "fixture":
                    case "tutorial-checkpoint":
                        await ApplyFixture(request);
                        break;
                    case "pitch-sample":
                        StartCoroutine(PlayPitchSample(request));
                        return;
                    case "nonfatal":
                        RunNonfatalProbe();
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
            PitchPresentationSnapshot expected = InternalQaPitchFixture.Create(request.Seed);
            bool readable = false;
            bool completed = false;
            stage.ResultReadable += snapshot =>
            {
                if (!ReferenceEquals(snapshot, expected)) return;
                readable = true;
                Mark(
                    "pitch_result_readable",
                    "passed",
                    "quality=" + request.Quality.Value() + " pitch_id=" + SafeToken(snapshot.PitchId));
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
                    "quality=" + request.Quality.Value() + " outcome=" + expected.Call.Value());
            }
            else
            {
                Mark(
                    "pitch_presentation_completed",
                    "failed",
                    "reason=" + (readable ? "completion_timeout" : "readable_timeout"));
            }
            Destroy(stageObject);
            _running = false;
        }

        private static void RunNonfatalProbe()
        {
            bool reporterReady = CrashReporting.Reporter.IsReady;
            CrashReporting.RecordUnexpected(
                new InvalidOperationException("internal_qa_nonfatal_probe"),
                "internal_qa_nonfatal");
            Mark(
                "nonfatal_invoked",
                "passed",
                "reporter_ready=" + (reporterReady ? "true" : "false"));
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
                    RemoveIntentExtra(intent, InternalQaRequest.CommandExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.SeedExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.PhaseExtra);
                    RemoveIntentExtra(intent, InternalQaRequest.QualityExtra);
                    return InternalQaRequest.TryCreate(
                        command, seed, phase, quality, out request, out errorCode);
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
            using (AndroidJavaObject ignored = intent.Call<AndroidJavaObject>("removeExtra", key))
            {
                // Intent.removeExtra returns the same Intent; dispose only the returned JNI wrapper.
            }
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
