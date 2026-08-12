using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Baseball.Application.Persistence;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NUnit.Framework;

namespace Baseball.Persistence.Tests
{
    public sealed class AtomicSaveRepositoryTests
    {
        private string _testRoot;
        private SaveFileLayout _layout;
        private readonly FixedClock _clock = new FixedClock(
            new DateTimeOffset(2026, 8, 11, 12, 34, 56, TimeSpan.Zero));

        [SetUp]
        public void SetUp()
        {
            CreateFreshLayout();
        }

        private void CreateFreshLayout()
        {
            _testRoot = Path.Combine(
                Path.GetTempPath(),
                "BaseballAtomicSaveTests",
                Guid.NewGuid().ToString("N"));
            _layout = new SaveFileLayout(Path.Combine(_testRoot, "save"));
        }

        [TearDown]
        public void TearDown()
        {
            if (Directory.Exists(_testRoot))
            {
                Directory.Delete(_testRoot, true);
            }
        }

        [Test]
        public async Task Save_WritesSpecifiedEnvelopeAndRoundTrips()
        {
            var payload = Payload(42, "training", 3);
            using (var repository = CreateRepository())
            {
                var write = await repository.SaveAsync(payload, 184);
                var load = await repository.LoadAsync();

                Assert.That(write.Envelope.Revision, Is.EqualTo(184));
                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
                Assert.That(load.Envelope.Revision, Is.EqualTo(184));
                Assert.That(load.Envelope.Payload.Ability, Is.EqualTo(42));
                Assert.That(load.Envelope.Payload.Phase, Is.EqualTo("training"));

                var json = JObject.Parse(File.ReadAllText(_layout.CanonicalPath));
                Assert.That(json.Value<string>("schema"), Is.EqualTo(SaveSchema.Name));
                Assert.That(json.Value<int>("schemaVersion"), Is.EqualTo(1));
                Assert.That(json.Value<string>("revision"), Is.EqualTo("184"));
                Assert.That(json.Value<string>("payloadSha256"), Has.Length.EqualTo(64));
                Assert.That(json["revision"].Type, Is.EqualTo(JTokenType.String));
            }
        }

        [Test]
        public async Task Checksum_IsIndependentOfObjectPropertyOrder()
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(50, "school", 0), 1);
                var envelope = ParseEnvelopeWithoutDates(_layout.CanonicalPath);
                var payload = (JObject)envelope["payload"];
                var reorderedPayload = new JObject();
                foreach (var property in payload.Properties().Reverse())
                {
                    reorderedPayload.Add(property.Name, property.Value.DeepClone());
                }

                envelope["payload"] = reorderedPayload;
                File.WriteAllText(_layout.CanonicalPath, envelope.ToString());

                var load = await repository.LoadAsync();

                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
                Assert.That(load.Envelope.Payload.Ability, Is.EqualTo(50));
            }
        }

        [Test]
        public async Task Save_RotatesExactlyThreeBackups()
        {
            using (var repository = CreateRepository())
            {
                for (ulong revision = 1; revision <= 5; revision++)
                {
                    await repository.SaveAsync(Payload((int)revision, "phase", 0), revision);
                }
            }

            Assert.That(ReadRevision(_layout.CanonicalPath), Is.EqualTo(5));
            Assert.That(ReadRevision(_layout.BackupPath(1)), Is.EqualTo(4));
            Assert.That(ReadRevision(_layout.BackupPath(2)), Is.EqualTo(3));
            Assert.That(ReadRevision(_layout.BackupPath(3)), Is.EqualTo(2));
            Assert.That(
                Directory.GetFiles(_layout.SaveDirectory, "save.bak.*").Length,
                Is.EqualTo(3));
        }

        [Test]
        public async Task Save_SameRevisionAndPayload_IsIdempotentWithoutBackupRotation()
        {
            using (var repository = CreateRepository())
            {
                var payload = Payload(10, "safe", 0);
                var first = await repository.SaveAsync(payload, 7);
                var firstBytes = File.ReadAllBytes(_layout.CanonicalPath);

                var second = await repository.SaveAsync(payload, 7);

                Assert.That(second.Envelope.Revision, Is.EqualTo(first.Envelope.Revision));
                Assert.That(File.ReadAllBytes(_layout.CanonicalPath), Is.EqualTo(firstBytes));
                Assert.That(
                    Directory.GetFiles(_layout.SaveDirectory, "save.bak.*"),
                    Is.Empty);
            }
        }

        [Test]
        public Task Save_RejectsRevisionRegression()
        {
            return AssertRevisionFailure(
                6, 10, "changed", SaveFailureCode.RevisionRegression);
        }

        [Test]
        public Task Save_RejectsSameRevisionConflict()
        {
            return AssertRevisionFailure(
                7, 11, "changed", SaveFailureCode.RevisionConflict);
        }

        private async Task AssertRevisionFailure(
            int attemptedRevision,
            int attemptedAbility,
            string attemptedPhase,
            SaveFailureCode expectedCode)
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(10, "safe", 0), 7);
                var original = File.ReadAllBytes(_layout.CanonicalPath);

                var exception = await AssertThrowsAsync<SavePersistenceException>(() =>
                    repository.SaveAsync(
                        Payload(attemptedAbility, attemptedPhase, 0),
                        (ulong)attemptedRevision));

                Assert.That(exception.Code, Is.EqualTo(expectedCode));
                Assert.That(File.ReadAllBytes(_layout.CanonicalPath), Is.EqualTo(original));
            }
        }

        [Test]
        public async Task Load_CorruptCanonical_RecoversHighestValidBackupAndQuarantinesOnce()
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(10, "one", 0), 1);
                await repository.SaveAsync(Payload(20, "two", 0), 2);
                await repository.SaveAsync(Payload(30, "three", 0), 3);
                File.WriteAllText(_layout.CanonicalPath, "{truncated");

                var recovered = await repository.LoadAsync();

                Assert.That(recovered.Status, Is.EqualTo(SaveLoadStatus.RecoveredBackup));
                Assert.That(recovered.RequiresRecoveryNotice, Is.True);
                Assert.That(recovered.Envelope.Revision, Is.EqualTo(2));
                Assert.That(recovered.Envelope.Payload.Ability, Is.EqualTo(20));
                Assert.That(recovered.QuarantinedPaths.Count, Is.EqualTo(1));
                Assert.That(File.Exists(recovered.QuarantinedPaths[0]), Is.True);

                var secondLoad = await repository.LoadAsync();
                Assert.That(secondLoad.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
                Assert.That(secondLoad.RequiresRecoveryNotice, Is.False);
            }
        }

        [Test]
        public async Task Load_SameRevision_UsesExplicitSemanticPriority()
        {
            Directory.CreateDirectory(_layout.SaveDirectory);
            var lowPath = await WriteIndependentSave("low", Payload(10, "between-life", 1), 8);
            var highPath = await WriteIndependentSave("high", Payload(20, "tombstone", 9), 8);
            File.Copy(lowPath, _layout.BackupPath(1));
            File.Copy(highPath, _layout.BackupPath(2));
            File.WriteAllText(_layout.CanonicalPath, "not-json");

            using (var repository = CreateRepository())
            {
                var load = await repository.LoadAsync();

                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.RecoveredBackup));
                Assert.That(load.Envelope.Revision, Is.EqualTo(8));
                Assert.That(load.Envelope.Payload.Phase, Is.EqualTo("tombstone"));
            }
        }

        [Test]
        public async Task Load_ChecksumMismatch_FallsBackToBackup()
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(1, "safe", 0), 1);
                await repository.SaveAsync(Payload(2, "new", 0), 2);
                var envelope = ParseEnvelopeWithoutDates(_layout.CanonicalPath);
                envelope["payload"]["ability"] = 99;
                File.WriteAllText(_layout.CanonicalPath, envelope.ToString());

                var load = await repository.LoadAsync();

                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.RecoveredBackup));
                Assert.That(load.Envelope.Revision, Is.EqualTo(1));
                Assert.That(load.Envelope.Payload.Ability, Is.EqualTo(1));
                Assert.That(
                    load.Diagnostics.Any(value => value.Contains("payloadSha256.mismatch")),
                    Is.True,
                    string.Join(" | ", load.Diagnostics));
            }
        }

        [Test]
        public async Task Load_AllCandidatesCorrupt_MovesThemToQuarantine()
        {
            Directory.CreateDirectory(_layout.SaveDirectory);
            File.WriteAllText(_layout.CanonicalPath, string.Empty);
            File.WriteAllText(_layout.BackupPath(1), "{");
            File.WriteAllText(_layout.BackupPath(2), "[]");
            File.WriteAllText(_layout.BackupPath(3), "{}");

            using (var repository = CreateRepository())
            {
                var load = await repository.LoadAsync();

                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.UnrecoverableCorruption));
                Assert.That(load.QuarantinedPaths.Count, Is.EqualTo(4));
                Assert.That(load.QuarantinedPaths.All(File.Exists), Is.True);
                Assert.That(File.Exists(_layout.CanonicalPath), Is.False);
                Assert.That(File.Exists(_layout.BackupPath(1)), Is.False);
            }
        }

        [Test]
        public Task FutureSchema_IsPreservedAndNeverOverwritten()
        {
            return AssertUnsupportedSchema(
                2, SaveLoadStatus.FutureVersion, SaveFailureCode.FutureVersionWouldBeOverwritten);
        }

        [Test]
        public Task OlderSchema_IsPreservedAndNeverOverwritten()
        {
            return AssertUnsupportedSchema(
                0, SaveLoadStatus.MigrationRequired, SaveFailureCode.MigrationRequired);
        }

        private async Task AssertUnsupportedSchema(
            int schemaVersion,
            SaveLoadStatus expectedLoadStatus,
            SaveFailureCode expectedFailureCode)
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(1, "safe", 0), 1);
                var envelope = ParseEnvelopeWithoutDates(_layout.CanonicalPath);
                envelope["schemaVersion"] = schemaVersion;
                var unsupportedBytes = Encoding.UTF8.GetBytes(envelope.ToString());
                File.WriteAllBytes(_layout.CanonicalPath, unsupportedBytes);

                var load = await repository.LoadAsync();
                var exception = await AssertThrowsAsync<SavePersistenceException>(() =>
                    repository.SaveAsync(Payload(2, "new", 0), 2));

                Assert.That(load.Status, Is.EqualTo(expectedLoadStatus));
                Assert.That(exception.Code, Is.EqualTo(expectedFailureCode));
                Assert.That(File.ReadAllBytes(_layout.CanonicalPath), Is.EqualTo(unsupportedBytes));
                Assert.That(
                    Directory.GetFiles(_layout.SaveDirectory, "save.corrupt.*").Length,
                    Is.Zero);
            }
        }

        [Test]
        public Task Save_FaultBeforeCandidateValidation_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.BeforeCandidateValidation);

        [Test]
        public Task Save_FaultAfterCandidateValidation_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.AfterCandidateValidation);

        [Test]
        public Task Save_FaultAfterTempWrite_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.AfterTempWrite);

        [Test]
        public Task Save_FaultAfterTempValidation_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.AfterTempValidation);

        [Test]
        public Task Save_FaultAfterBackupRotation_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.AfterBackupRotation);

        [Test]
        public Task Save_FaultBeforeCanonicalSwap_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.BeforeCanonicalSwap);

        [Test]
        public Task Save_FaultAfterCanonicalSwap_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.AfterCanonicalSwap);

        [Test]
        public Task Save_FaultBeforeCanonicalVerification_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.BeforeCanonicalVerification);

        [Test]
        public Task Save_FaultAfterCanonicalVerification_PreservesPreviousCanonical() =>
            AssertFaultPreservesPreviousCanonical(SaveFaultPoint.AfterCanonicalVerification);

        private async Task AssertFaultPreservesPreviousCanonical(SaveFaultPoint faultPoint)
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(11, "safe", 0), 11);
            }

            var originalBytes = File.ReadAllBytes(_layout.CanonicalPath);
            using (var failingRepository = CreateRepository(new ThrowingFaultInjector(faultPoint)))
            {
                await AssertThrowsAsync<Exception>(() =>
                    failingRepository.SaveAsync(Payload(12, "candidate", 0), 12));
            }

            Assert.That(File.ReadAllBytes(_layout.CanonicalPath), Is.EqualTo(originalBytes));
            using (var verificationRepository = CreateRepository())
            {
                var load = await verificationRepository.LoadAsync();
                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
                Assert.That(load.Envelope.Revision, Is.EqualTo(11));
            }
        }

        [Test]
        public async Task FirstSave_FaultAfterSwap_LeavesNoFalseCanonical()
        {
            await AssertFirstSaveFaultLeavesNoCanonical(SaveFaultPoint.AfterCanonicalSwap);
            await AssertFirstSaveFaultLeavesNoCanonical(SaveFaultPoint.AfterCanonicalVerification);
        }

        private async Task AssertFirstSaveFaultLeavesNoCanonical(SaveFaultPoint faultPoint)
        {
            using (var repository = CreateRepository(new ThrowingFaultInjector(faultPoint)))
            {
                await AssertThrowsAsync<Exception>(() =>
                    repository.SaveAsync(Payload(1, "candidate", 0), 1));
            }

            Assert.That(File.Exists(_layout.CanonicalPath), Is.False);
        }

        [Test]
        public async Task InvalidPayload_IsRejectedBeforeAnyFileMutation()
        {
            using (var repository = CreateRepository())
            {
                var exception = await AssertThrowsAsync<SavePersistenceException>(() =>
                    repository.SaveAsync(Payload(101, "invalid", 0), 1));

                Assert.That(exception.Code, Is.EqualTo(SaveFailureCode.CandidateInvalid));
                Assert.That(Directory.Exists(_layout.SaveDirectory), Is.True);
                Assert.That(Directory.GetFiles(_layout.SaveDirectory), Is.Empty);
            }
        }

        [Test]
        public async Task Reset_DeletesCanonicalTempBackupsAndQuarantineWithoutRecovery()
        {
            using (var repository = CreateRepository())
            {
                await repository.SaveAsync(Payload(1, "one", 0), 1);
                await repository.SaveAsync(Payload(2, "two", 0), 2);
                await repository.SaveAsync(Payload(3, "three", 0), 3);
                File.WriteAllText(
                    _layout.QuarantinePath(_clock.UtcNow, "manual"),
                    "corrupt");
                File.WriteAllText(_layout.TempPath, "interrupted");

                await repository.ResetAsync();
                var load = await repository.LoadAsync();

                Assert.That(load.Status, Is.EqualTo(SaveLoadStatus.NoSave));
                Assert.That(
                    Directory.GetFiles(_layout.SaveDirectory, "save.*"),
                    Is.Empty);
            }
        }

        [Test]
        public async Task OneHundredSaveReloadCycles_PreserveStateHashInputs()
        {
            using (var repository = CreateRepository())
            {
                for (ulong revision = 1; revision <= 100; revision++)
                {
                    var expected = Payload((int)(revision % 101), "chapter-" + revision, (int)(revision % 3));
                    expected.Counters["games"] = (int)revision * 7;

                    await repository.SaveAsync(expected, revision);
                    var loaded = await repository.LoadAsync();

                    Assert.That(loaded.Envelope.Revision, Is.EqualTo(revision));
                    Assert.That(loaded.Envelope.Payload.Ability, Is.EqualTo(expected.Ability));
                    Assert.That(loaded.Envelope.Payload.Phase, Is.EqualTo(expected.Phase));
                    Assert.That(loaded.Envelope.Payload.Counters, Is.EqualTo(expected.Counters));
                }
            }
        }

        private AtomicSaveRepository<TestPayload> CreateRepository(
            ISaveFaultInjector faultInjector = null)
        {
            return new AtomicSaveRepository<TestPayload>(
                _layout,
                new SystemAtomicFileSystem(),
                new TestPayloadValidator(),
                new TestSemanticPriority(),
                _clock,
                faultInjector);
        }

        private async Task<string> WriteIndependentSave(
            string directoryName,
            TestPayload payload,
            ulong revision)
        {
            var layout = new SaveFileLayout(Path.Combine(_testRoot, directoryName));
            using (var repository = new AtomicSaveRepository<TestPayload>(
                       layout,
                       new SystemAtomicFileSystem(),
                       new TestPayloadValidator(),
                       new TestSemanticPriority(),
                       _clock))
            {
                await repository.SaveAsync(payload, revision);
            }

            return layout.CanonicalPath;
        }

        private static ulong ReadRevision(string path)
        {
            var value = JObject.Parse(File.ReadAllText(path)).Value<string>("revision");
            return ulong.Parse(value, NumberStyles.None, CultureInfo.InvariantCulture);
        }

        private static JObject ParseEnvelopeWithoutDates(string path)
        {
            using (var stringReader = new StringReader(File.ReadAllText(path)))
            using (var jsonReader = new JsonTextReader(stringReader)
                   {
                       DateParseHandling = DateParseHandling.None
                   })
            {
                return JObject.Load(jsonReader);
            }
        }

        private static TestPayload Payload(int ability, string phase, int semanticPriority)
        {
            return new TestPayload
            {
                Ability = ability,
                Phase = phase,
                SemanticPriority = semanticPriority,
                Counters = new Dictionary<string, int>(StringComparer.Ordinal)
                {
                    ["games"] = 0
                }
            };
        }

        public sealed class TestPayload
        {
            public int Ability { get; set; }

            public string Phase { get; set; }

            public int SemanticPriority { get; set; }

            public Dictionary<string, int> Counters { get; set; }
        }

        private static async Task<TException> AssertThrowsAsync<TException>(Func<Task> action)
            where TException : Exception
        {
            try
            {
                await action();
            }
            catch (TException exception)
            {
                return exception;
            }
            catch (Exception exception)
            {
                Assert.Fail("Expected " + typeof(TException).Name + " but caught " +
                    exception.GetType().Name + ": " + exception.Message);
            }
            Assert.Fail("Expected " + typeof(TException).Name + " but no exception was thrown.");
            return null;
        }

        private sealed class TestPayloadValidator : ISavePayloadValidator<TestPayload>
        {
            public SaveValidationResult Validate(TestPayload payload)
            {
                if (payload == null)
                {
                    return SaveValidationResult.Invalid("payload.null");
                }

                if (payload.Ability < 0 || payload.Ability > 100)
                {
                    return SaveValidationResult.Invalid("ability.range");
                }

                if (string.IsNullOrWhiteSpace(payload.Phase))
                {
                    return SaveValidationResult.Invalid("phase.required");
                }

                if (payload.Counters == null)
                {
                    return SaveValidationResult.Invalid("counters.required");
                }

                return SaveValidationResult.Success;
            }
        }

        private sealed class TestSemanticPriority : ISaveSemanticPriority<TestPayload>
        {
            public int GetPriority(TestPayload payload) => payload.SemanticPriority;
        }

        private sealed class FixedClock : IUtcClock
        {
            public FixedClock(DateTimeOffset utcNow)
            {
                UtcNow = utcNow;
            }

            public DateTimeOffset UtcNow { get; }
        }

        private sealed class ThrowingFaultInjector : ISaveFaultInjector
        {
            private readonly SaveFaultPoint _faultPoint;

            public ThrowingFaultInjector(SaveFaultPoint faultPoint)
            {
                _faultPoint = faultPoint;
            }

            public void Checkpoint(SaveFaultPoint point)
            {
                if (point == _faultPoint)
                {
                    throw new InjectedSaveFaultException(point);
                }
            }
        }

        private sealed class InjectedSaveFaultException : Exception
        {
            public InjectedSaveFaultException(SaveFaultPoint faultPoint)
                : base("Injected save fault at " + faultPoint)
            {
            }
        }
    }
}
