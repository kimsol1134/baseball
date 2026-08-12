using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Baseball.Platform.Analytics;
using Baseball.Platform.Identity;
using NUnit.Framework;

namespace Baseball.Platform.Tests
{
    public sealed class AnalyticsContractTests
    {
        [Test]
        public void EventWireValuesAreCompleteAndUnique()
        {
            AnalyticsEvent[] events = (AnalyticsEvent[])Enum.GetValues(typeof(AnalyticsEvent));
            string[] values = events.Select(item => item.Value()).ToArray();
            Assert.That(values, Has.Length.EqualTo(44));
            Assert.That(values.Distinct(StringComparer.Ordinal).Count(), Is.EqualTo(values.Length));
            Assert.That(AnalyticsEvent.FirstPitch.Value(), Is.EqualTo("first_pitch"));
            Assert.That(AnalyticsEvent.ReturnPlanNextDayOpen.Value(), Is.EqualTo("return_plan_next_day_open"));
        }

        [TestCase("editor", AnalyticsDistribution.Editor)]
        [TestCase("development", AnalyticsDistribution.Development)]
        [TestCase("internal", AnalyticsDistribution.Internal)]
        [TestCase("closed", AnalyticsDistribution.Closed)]
        [TestCase("production", AnalyticsDistribution.Production)]
        [TestCase(" INTERNAL ", AnalyticsDistribution.Internal)]
        [TestCase("unknown-channel", AnalyticsDistribution.Development)]
        public void DistributionParserAllowsOnlyBuildChannels(
            string value,
            AnalyticsDistribution expected)
        {
            Assert.That(AnalyticsContext.ParseDistribution(value), Is.EqualTo(expected));
            Assert.That(
                new[] { "editor", "development", "internal", "closed", "production" },
                Does.Contain(AnalyticsContext.DistributionValue(expected)));
        }

        [TestCase("name")]
        [TestCase("player_name")]
        [TestCase("seed")]
        [TestCase("save_json")]
        [TestCase("advertising_id")]
        public void PrivacyGuardRejectsProhibitedProperties(string key)
        {
            var properties = new Dictionary<string, object> { [key] = "금지 값" };
            Assert.Throws<ArgumentException>(() => AnalyticsPrivacyGuard.ValidateAndCopy(properties));
        }

        [Test]
        public void PayloadSeparatesAmplitudeOriginAndNeverOverwritesContext()
        {
            var firebase = new RecordingDestination(AnalyticsDestinationKind.Firebase);
            var amplitude = new RecordingDestination(AnalyticsDestinationKind.Amplitude);
            var service = new AnalyticsService(
                new AnalyticsContext("1.0.0", "7", AnalyticsDistribution.Production),
                new IAnalyticsDestination[] { firebase, amplitude },
                new MemoryOnceStore(),
                "2ea11855f1844af680ae122b77e72e61");

            service.Log(AnalyticsEvent.PhaseEntered, new Dictionary<string, object> { ["phase"] = "training" });

            Assert.That(firebase.Properties["platform"], Is.EqualTo("android"));
            Assert.That(firebase.Properties["environment"], Is.EqualTo("production"));
            Assert.That(firebase.Properties.ContainsKey("ingestion_origin"), Is.False);
            Assert.That(amplitude.Properties["ingestion_origin"], Is.EqualTo("android_unity_direct"));
            Assert.That(amplitude.Properties["event_schema_version"], Is.EqualTo(2L));
        }

        [Test]
        public void FirebaseBooleanAdapterUsesLongsWhileAmplitudeKeepsLogicalSchemaValues()
        {
            var logical = new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["drafted"] = true,
                ["recommended"] = false,
                ["perfect"] = true,
                ["enabled"] = false,
                ["return_eligible"] = true,
            };
            var amplitude = new RecordingDestination(AnalyticsDestinationKind.Amplitude);
            var service = new AnalyticsService(
                new AnalyticsContext("1.0.0", "7", AnalyticsDistribution.Production),
                new[] { amplitude },
                new MemoryOnceStore(),
                "2ea11855f1844af680ae122b77e72e61");

            service.Log(AnalyticsEvent.SessionEnded, logical);

            foreach (KeyValuePair<string, object> pair in logical)
            {
                object firebase = FirebaseAnalyticsValueAdapter.Normalize(pair.Value);
                Assert.That(firebase, Is.TypeOf<long>(), pair.Key);
                Assert.That(firebase, Is.EqualTo((bool)pair.Value ? 1L : 0L), pair.Key);
                Assert.That(amplitude.Properties[pair.Key], Is.TypeOf<bool>(), pair.Key);
                Assert.That(amplitude.Properties[pair.Key], Is.EqualTo(pair.Value), pair.Key);
            }
        }

        [Test]
        public void ScopedOnceHashesScopeLocallyAndSendsNoIdentifier()
        {
            var destination = new RecordingDestination(AnalyticsDestinationKind.Test);
            var service = new AnalyticsService(
                new AnalyticsContext("1", "1", AnalyticsDistribution.Internal),
                new[] { destination }, new MemoryOnceStore(), "anonymous");

            Assert.That(service.LogOnce(AnalyticsEvent.CareerWindSeen, "career-a"), Is.True);
            Assert.That(service.LogOnce(AnalyticsEvent.CareerWindSeen, "career-a"), Is.False);
            Assert.That(service.LogOnce(AnalyticsEvent.CareerWindSeen, "career-b"), Is.True);
            Assert.That(destination.Count, Is.EqualTo(2));
            Assert.That(destination.Properties.Keys, Does.Not.Contain("scope"));
            Assert.That(destination.Properties.Keys, Does.Not.Contain("career_id"));
        }

        [Test]
        public void IdentityResetRebindsDestinationsAndClearsOnceFlags()
        {
            var destination = new RecordingDestination(AnalyticsDestinationKind.Test);
            var service = new AnalyticsService(
                new AnalyticsContext("1", "1", AnalyticsDistribution.Internal),
                new[] { destination }, new MemoryOnceStore(), "old-anonymous");
            Assert.That(service.LogOnce(AnalyticsEvent.FirstPitch), Is.True);
            Assert.That(service.LogOnce(AnalyticsEvent.FirstPitch), Is.False);

            service.ResetIdentityAndOnceFlags("new-anonymous");

            Assert.That(destination.AnonymousInstallId, Is.EqualTo("new-anonymous"));
            Assert.That(service.LogOnce(AnalyticsEvent.FirstPitch), Is.True);
        }

        [Test]
        public void IdentityResetSwapsOnceStoreAndProcessRestartUsesOnlyNewEpoch()
        {
            const string oldInstallId = "11111111111111111111111111111111";
            const string newInstallId = "22222222222222222222222222222222";
            const string noBackupDirectory = "/virtual/no-backup";
            var files = new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
            Func<string, IAnalyticsOnceStore> storeForInstall = installId =>
                new RestartableOnceStore(
                    InstallScopedLocalStatePolicy.AnalyticsOncePath(
                        noBackupDirectory,
                        installId),
                    files);
            var destination = new RecordingDestination(AnalyticsDestinationKind.Test);
            var service = new AnalyticsService(
                new AnalyticsContext("1", "1", AnalyticsDistribution.Internal),
                new[] { destination },
                storeForInstall(oldInstallId),
                oldInstallId,
                storeForInstall);
            Assert.That(service.LogOnce(AnalyticsEvent.FirstPitch), Is.True);
            Assert.That(service.LogOnce(AnalyticsEvent.FirstPitch), Is.False);

            service.ResetIdentityAndOnceFlags(newInstallId);

            Assert.That(destination.AnonymousInstallId, Is.EqualTo(newInstallId));
            Assert.That(files.Keys, Does.Not.Contain(
                InstallScopedLocalStatePolicy.AnalyticsOncePath(
                    noBackupDirectory,
                    oldInstallId)),
                "live reset must physically clear the prior install once store");
            Assert.That(service.LogOnce(AnalyticsEvent.FirstPitch), Is.True,
                "the running service must write through the new install store");
            var restarted = new AnalyticsService(
                new AnalyticsContext("1", "1", AnalyticsDistribution.Internal),
                new[] { new RecordingDestination(AnalyticsDestinationKind.Test) },
                storeForInstall(newInstallId),
                newInstallId,
                storeForInstall);
            Assert.That(restarted.LogOnce(AnalyticsEvent.FirstPitch), Is.False,
                "the new install receipt must survive process restart");
            Assert.That(files.Keys, Does.Contain(
                InstallScopedLocalStatePolicy.AnalyticsOncePath(
                    noBackupDirectory,
                    newInstallId)));
            Assert.That(files.Keys, Does.Not.Contain(Path.Combine(
                noBackupDirectory,
                InstallScopedLocalStatePolicy.AnalyticsOnceFileName)));
        }

        [Test]
        public void ProcessDeathAfterIdentityPublishCannotReadPriorInstallOnceFlags()
        {
            const string oldInstallId = "33333333333333333333333333333333";
            const string newInstallId = "44444444444444444444444444444444";
            var files = new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
            Func<string, IAnalyticsOnceStore> storeForInstall = installId =>
                new RestartableOnceStore(
                    InstallScopedLocalStatePolicy.AnalyticsOncePath("/virtual/no-backup", installId),
                    files);
            AnalyticsService Create(string installId) => new AnalyticsService(
                new AnalyticsContext("1", "1", AnalyticsDistribution.Internal),
                new[] { new RecordingDestination(AnalyticsDestinationKind.Test) },
                storeForInstall(installId),
                installId,
                storeForInstall);

            Assert.That(Create(oldInstallId).LogOnce(AnalyticsEvent.OnboardingStarted), Is.True);
            Assert.That(Create(newInstallId).LogOnce(AnalyticsEvent.OnboardingStarted), Is.True,
                "a crash before live cleanup must not carry the old receipt into the new install");
            Assert.That(Create(newInstallId).LogOnce(AnalyticsEvent.OnboardingStarted), Is.False);
            Assert.That(Create(oldInstallId).LogOnce(AnalyticsEvent.OnboardingStarted), Is.False);
        }

        [Test]
        public void ProductionBootstrapCreatesInstallScopedOnceStoreFactory()
        {
            string source = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Analytics",
                "AnalyticsBootstrap.cs")));

            Assert.That(source, Does.Contain("InstallScopedLocalStatePolicy.AnalyticsOncePath"));
            Assert.That(source, Does.Contain("onceStoreForInstall(installId)"));
            Assert.That(source, Does.Contain("installId,\n                    onceStoreForInstall"));
            Assert.That(source, Does.Not.Contain(
                "Path.Combine(AnonymousInstallIdentity.ResolveNoBackupDirectory(), \"analytics-once-v1.txt\")"));
        }

        [Test]
        public void StartupBufferIsBoundedAndDrainsOldestFirst()
        {
            var buffer = new AnalyticsStartupBuffer(2);
            buffer.Enqueue(AnalyticsEvent.OnboardingStarted, new Dictionary<string, object> { ["order"] = 1 });
            buffer.Enqueue(AnalyticsEvent.FirstPitch, new Dictionary<string, object> { ["order"] = 2 });
            buffer.Enqueue(AnalyticsEvent.GameFinished, new Dictionary<string, object> { ["order"] = 3 });

            AnalyticsStartupEvent[] drained = buffer.Drain();

            Assert.That(drained.Select(item => item.Event), Is.EqualTo(new[]
            {
                AnalyticsEvent.FirstPitch,
                AnalyticsEvent.GameFinished
            }));
            Assert.That(drained.Select(item => item.Properties["order"]), Is.EqualTo(new object[] { 2, 3 }));
            Assert.That(buffer.Count, Is.Zero);
        }

        [Test]
        public void ProductionStartupCapacityExceedsEntireDefinedEventCatalog()
        {
            Assert.That(
                AnalyticsStartupBuffer.ProductionCapacity,
                Is.GreaterThan(Enum.GetValues(typeof(AnalyticsEvent)).Length));
            Assert.That(AnalyticsStartupBuffer.ProductionCapacity, Is.EqualTo(128));
        }

        [Test]
        public void DurableEventQueuedBeforeReadinessDrainsExactlyOnce()
        {
            var buffer = new AnalyticsStartupBuffer(8);
            buffer.Enqueue(
                AnalyticsEvent.OnboardingCompleted,
                new Dictionary<string, object> { ["status"] = "receipt_saved" });

            AnalyticsStartupEvent[] firstDrain = buffer.Drain();
            AnalyticsStartupEvent[] secondDrain = buffer.Drain();

            Assert.That(firstDrain, Has.Length.EqualTo(1));
            Assert.That(firstDrain[0].Event, Is.EqualTo(AnalyticsEvent.OnboardingCompleted));
            Assert.That(firstDrain[0].Properties["status"], Is.EqualTo("receipt_saved"));
            Assert.That(secondDrain, Is.Empty);
        }

        [Test]
        public void ResetDropsQueuedEventsFromPreviousAnonymousIdentity()
        {
            var buffer = new AnalyticsStartupBuffer(8);
            buffer.Enqueue(AnalyticsEvent.FirstPitch, new Dictionary<string, object>());

            buffer.Clear();

            Assert.That(buffer.Drain(), Is.Empty);
        }

        [Test]
        public void ProductionCallersUseStartupBarrierInsteadOfNullableServiceLogging()
        {
            string[] relativePaths =
            {
                Path.Combine("apps", "android-unity", "Assets", "Game", "Presentation", "Shell", "ProductionBaseballShellRuntime.cs"),
                Path.Combine("apps", "android-unity", "Assets", "Game", "Presentation", "Shell", "ProductionAnalyticsReceipts.cs"),
                Path.Combine("apps", "android-unity", "Assets", "Game", "Presentation", "Shell", "ProductionPitchSessionPersistence.cs"),
                Path.Combine("apps", "android-unity", "Assets", "Game", "Platform", "Notifications", "AndroidReminderService.cs")
            };

            foreach (string relativePath in relativePaths)
            {
                string source = File.ReadAllText(FindFromParents(relativePath));
                Assert.That(source, Does.Not.Contain("AnalyticsBootstrap.Service?.Log"), relativePath);
                Assert.That(source, Does.Not.Contain("AnalyticsBootstrap.Service.Log"), relativePath);
            }
        }

        private sealed class RecordingDestination : IAnalyticsDestination
        {
            public RecordingDestination(AnalyticsDestinationKind kind) { Kind = kind; }
            public AnalyticsDestinationKind Kind { get; }
            public bool IsReady => true;
            public int Count { get; private set; }
            public IReadOnlyDictionary<string, object> Properties { get; private set; }
            public string AnonymousInstallId { get; private set; }
            public void SetAnonymousInstallId(string installId) => AnonymousInstallId = installId;
            public void Log(string eventName, IReadOnlyDictionary<string, object> properties)
            {
                Count++;
                Properties = properties;
            }
            public void Flush() { }
        }

        private sealed class MemoryOnceStore : IAnalyticsOnceStore
        {
            private readonly HashSet<string> _keys = new HashSet<string>(StringComparer.Ordinal);
            public bool TryMark(string key) => _keys.Add(key);
            public void Clear() => _keys.Clear();
        }

        private sealed class RestartableOnceStore : IAnalyticsOnceStore
        {
            private readonly string _path;
            private readonly IDictionary<string, HashSet<string>> _files;

            public RestartableOnceStore(
                string path,
                IDictionary<string, HashSet<string>> files)
            {
                _path = path;
                _files = files;
            }

            public bool TryMark(string key)
            {
                if (!_files.TryGetValue(_path, out HashSet<string> keys))
                {
                    keys = new HashSet<string>(StringComparer.Ordinal);
                    _files[_path] = keys;
                }
                return keys.Add(key);
            }

            public void Clear()
            {
                _files.Remove(_path);
            }
        }

        private static string FindFromParents(string relativePath)
        {
            DirectoryInfo current = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (current != null)
            {
                string candidate = Path.Combine(current.FullName, relativePath);
                if (File.Exists(candidate)) return candidate;
                current = current.Parent;
            }
            throw new FileNotFoundException("Repository contract source was not found.", relativePath);
        }
    }
}
