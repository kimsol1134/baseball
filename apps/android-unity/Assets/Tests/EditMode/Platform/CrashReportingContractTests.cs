using System;
using System.Collections.Generic;
using System.IO;
using Baseball.Platform.Crash;
using NUnit.Framework;

namespace Baseball.Platform.Tests
{
    public sealed class CrashReportingContractTests
    {
        [SetUp]
        public void SetUp() => CrashReporting.Reset();

        [TearDown]
        public void TearDown() => CrashReporting.Reset();

        [Test]
        public void ContextRecordedBeforeConfigureReplaysExactlyOnce()
        {
            var context = new CrashContext("production", 4, 17, "proweek", false, "high");
            CrashReporting.SetContext(context);
            var reporter = new RecordingReporter();

            CrashReporting.Configure(reporter);

            Assert.That(reporter.Contexts.Count, Is.EqualTo(1));
            AssertContext(reporter.Contexts[0], "production", 17, "high", false);
        }

        [Test]
        public void CrashContextRejectsFreeFormDistributionQualityAndPhase()
        {
            var context = new CrashContext(
                "runtime",
                4,
                1,
                "선수 이름 포함",
                false,
                "Mobile");

            Assert.That(context.Distribution, Is.EqualTo("unknown"));
            Assert.That(context.AppPhase, Is.EqualTo("unknown"));
            Assert.That(context.QualityTier, Is.EqualTo("unknown"));
        }

        [Test]
        public void RepeatedPreInitUpdatesReplayLatestContextOnly()
        {
            CrashReporting.SetContext(new CrashContext("internal", 4, 21, "opening", false, "high"));
            CrashReporting.SetContext(new CrashContext("internal", 4, 22, "pitchhandoff", false, "low"));
            var reporter = new RecordingReporter();

            CrashReporting.Configure(reporter);

            Assert.That(reporter.Contexts.Count, Is.EqualTo(1));
            AssertContext(reporter.Contexts[0], "internal", 22, "low", false);
        }

        [Test]
        public void ResetClearsBufferedContextAndRuntimeDiagnostics()
        {
            CrashRuntimeDiagnostics.InitializeQualityTier("high");
            CrashRuntimeDiagnostics.PublishPitchStageLoaded(true);
            CrashReporting.SetContext(new CrashContext("closed", 4, 23, "pitchhandoff", true, "high"));

            CrashReporting.Reset();
            var reporter = new RecordingReporter();
            CrashReporting.Configure(reporter);

            Assert.That(reporter.Contexts, Is.Empty);
            Assert.That(CrashRuntimeDiagnostics.CurrentQualityTier, Is.EqualTo("unknown"));
            Assert.That(CrashRuntimeDiagnostics.PitchStageLoaded, Is.False);
        }

        [Test]
        public void ReporterFailureDoesNotDiscardLatestContextForLaterFirebaseReadiness()
        {
            CrashReporting.SetContext(new CrashContext("production", 4, 29, "records", false, "high"));

            Assert.DoesNotThrow(() => CrashReporting.Configure(new ThrowingReporter()));
            var recovered = new RecordingReporter();
            CrashReporting.Configure(recovered);

            Assert.That(recovered.Contexts.Count, Is.EqualTo(1));
            AssertContext(recovered.Contexts[0], "production", 29, "high", false);
        }

        [Test]
        public void AdaptiveQualityAndLoadedStageRefreshLatestCrashContext()
        {
            Assert.That(CrashRuntimeDiagnostics.InitializeQualityTier("high"), Is.True);
            CrashReporting.SetContext(new CrashContext("internal", 4, 31, "pitchhandoff", false, "high"));
            var reporter = new RecordingReporter();
            CrashReporting.Configure(reporter);

            Assert.That(CrashRuntimeDiagnostics.PublishQualityTier("low"), Is.True);
            CrashRuntimeDiagnostics.PublishPitchStageLoaded(true);

            Assert.That(reporter.Contexts.Count, Is.EqualTo(3));
            AssertContext(reporter.Contexts[1], "internal", 31, "low", false);
            AssertContext(reporter.Contexts[2], "internal", 31, "low", true);
            Assert.That(CrashRuntimeDiagnostics.PublishQualityTier("Mobile"), Is.False);
            Assert.That(reporter.Contexts.Count, Is.EqualTo(3));
        }

        [Test]
        public void StageLoadFailureCloseAndRetryRemainReversible()
        {
            Assert.That(CrashRuntimeDiagnostics.PitchStageLoaded, Is.False);

            CrashRuntimeDiagnostics.PublishPitchStageLoaded(false);
            Assert.That(CrashRuntimeDiagnostics.PitchStageLoaded, Is.False,
                "failed asset preparation must remain unloaded");

            CrashRuntimeDiagnostics.PublishPitchStageLoaded(true);
            Assert.That(CrashRuntimeDiagnostics.PitchStageLoaded, Is.True,
                "a successful retry publishes the loaded stage");

            CrashRuntimeDiagnostics.PublishPitchStageLoaded(false);
            Assert.That(CrashRuntimeDiagnostics.PitchStageLoaded, Is.False,
                "close always clears the diagnostic state");
        }

        [Test]
        public void ProductionSourcesUseBuildConfigAndActualStageLifecycle()
        {
            string runtime = Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string stage = Read("apps/android-unity/Assets/Game/Presentation/Pitch/Runtime/PitchStageController.cs");
            string coordinator = Read("apps/android-unity/Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs");
            string controller = Read("apps/android-unity/Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string screenContracts = Read("apps/android-unity/Assets/Game/Presentation/Shell/ScreenContracts.cs");
            string bootstrap = Read("apps/android-unity/Assets/Game/Platform/Crash/CrashReportingBootstrap.cs");
            string firebaseReporter = Read("apps/android-unity/Assets/Game/Platform/Crash/FirebaseCrashReporter.cs");
            string configuration = Read("apps/android-unity/Assets/Game/Platform/Configuration/AnalyticsRuntimeConfiguration.cs");
            string analyticsBootstrap = Read("apps/android-unity/Assets/Game/Platform/Analytics/AnalyticsBootstrap.cs");

            Assert.That(runtime, Does.Contain("AnalyticsRuntimeConfiguration.Load().ResolveDistributionValue()"));
            Assert.That(runtime, Does.Not.Contain("new CrashContext(\n                \"runtime\""));
            Assert.That(runtime, Does.Not.Contain("QualitySettings.names"));
            Assert.That(runtime, Does.Contain("CrashRuntimeDiagnostics.PitchStageLoaded"));
            Assert.That(runtime, Does.Contain("InitializeQualityTier(InitialPitchQualityTier())"));
            Assert.That(stage, Does.Contain("CrashRuntimeDiagnostics.PublishQualityTier(tier.Value())"));
            Assert.That(controller, Does.Contain("OnRouteChanged(CurrentRoute)"));
            Assert.That(screenContracts, Does.Contain("void OnRouteChanged(ShellRoute route);"));
            Assert.That(screenContracts, Does.Not.Contain("bool pitchStageLoaded"));

            int prepared = coordinator.IndexOf("if (!ready)", StringComparison.Ordinal);
            int loaded = coordinator.IndexOf("PublishPitchStageLoaded(true)", StringComparison.Ordinal);
            Assert.That(prepared, Is.GreaterThanOrEqualTo(0));
            Assert.That(loaded, Is.GreaterThan(prepared), "stage is loaded only after required art succeeds");
            Assert.That(coordinator.Substring(prepared, loaded - prepared), Does.Contain("DestroyStage()"),
                "asset load failure clears the diagnostic before leaving CreateStageAsync");
            Assert.That(coordinator, Does.Contain("DestroyStage()"));
            Assert.That(coordinator, Does.Contain("PublishPitchStageLoaded(false)"));

            Assert.That(bootstrap, Does.Contain("if (firebase.IsReady) CrashReporting.Configure(firebase)"));
            Assert.That(bootstrap, Does.Contain("CrashReporting.Reset()"));
            Assert.That(bootstrap, Does.Not.Contain("CrashReporting.Configure(null)"));
            Assert.That(firebaseReporter, Does.Contain("Task.WhenAny(dependencyCheck, Task.Delay(DependencyTimeout))"));
            Assert.That(firebaseReporter, Does.Contain("if (TryBindDefaultApp()) return"));
            Assert.That(firebaseReporter, Does.Contain("attempt < DefaultAppPollAttempts"));
            Assert.That(firebaseReporter, Does.Contain("Task.Delay(DefaultAppPollDelayMilliseconds)"));
            Assert.That(firebaseReporter, Does.Contain("FirebaseApp.DefaultInstance == null"));
            Assert.That(firebaseReporter, Does.Contain("TimeSpan.FromSeconds(10)"));
            Assert.That(configuration, Does.Contain("#elif BASEBALL_INTERNAL_QA"));
            Assert.That(configuration, Does.Contain("return AnalyticsDistribution.Internal"));
            Assert.That(configuration, Does.Contain("AnalyticsContext.ParseDistribution(distribution)"));
            Assert.That(analyticsBootstrap, Does.Contain("config.ResolveDistribution()"));
        }

        private static void AssertContext(
            CrashContext context,
            string distribution,
            ulong revision,
            string quality,
            bool stageLoaded)
        {
            Assert.That(context.Distribution, Is.EqualTo(distribution));
            Assert.That(context.SaveSchema, Is.EqualTo(4));
            Assert.That(context.SaveRevision, Is.EqualTo(revision));
            Assert.That(context.QualityTier, Is.EqualTo(quality));
            Assert.That(context.PitchStageLoaded, Is.EqualTo(stageLoaded));
        }

        private static string Read(string relativePath)
        {
            DirectoryInfo current = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (current != null)
            {
                string candidate = Path.Combine(current.FullName, relativePath);
                if (File.Exists(candidate)) return File.ReadAllText(candidate);
                current = current.Parent;
            }
            throw new FileNotFoundException("Repository source was not found.", relativePath);
        }

        private sealed class RecordingReporter : ICrashReporter
        {
            public bool IsReady => true;
            public List<CrashContext> Contexts { get; } = new List<CrashContext>();
            public void SetContext(CrashContext context) => Contexts.Add(context);
            public void RecordUnexpected(Exception exception, string category) { }
        }

        private sealed class ThrowingReporter : ICrashReporter
        {
            public bool IsReady => false;
            public void SetContext(CrashContext context) => throw new InvalidOperationException("firebase unavailable");
            public void RecordUnexpected(Exception exception, string category) =>
                throw new InvalidOperationException("firebase unavailable");
        }
    }
}
