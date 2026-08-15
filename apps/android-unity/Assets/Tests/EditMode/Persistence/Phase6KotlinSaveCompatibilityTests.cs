using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Baseball.Application.Persistence;
using NUnit.Framework;

namespace Baseball.Persistence.Tests
{
    public sealed class Phase6KotlinSaveCompatibilityTests
    {
        private string _testRoot;

        [SetUp]
        public void SetUp()
        {
            _testRoot = Path.Combine(
                Path.GetTempPath(),
                "BaseballPhase6CSharpReaderTests",
                Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_testRoot);
        }

        [TearDown]
        public void TearDown()
        {
            if (Directory.Exists(_testRoot)) Directory.Delete(_testRoot, true);
        }

        [Test]
        public async Task CurrentEmulatorClone_IsReadByTheRealCSharpAggregateReader()
        {
            var result = await ReadWithCSharpRepository(CurrentFixturePath());

            Assert.That(result.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
            Assert.That(result.Envelope.Revision, Is.EqualTo(6UL));
            Assert.That(result.Envelope.Payload.InstallId, Is.EqualTo("718fa1083cc647d0b169ff301fdb9ad7"));
            Assert.That(result.Envelope.Payload.Stage, Is.EqualTo(ApplicationStage.HighSchool));
        }

        [Test]
        public async Task KotlinWrittenFixture_IsReadAndRewrittenByTheRealCSharpReader()
        {
            var kotlinPath = KotlinWrittenFixturePath();
            Assert.That(File.Exists(kotlinPath), Is.True, kotlinPath);

            var result = await ReadWithCSharpRepository(kotlinPath);

            Assert.That(result.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
            Assert.That(result.Envelope.Revision, Is.EqualTo(7UL));
            Assert.That(result.Envelope.Payload.InstallId, Is.EqualTo("718fa1083cc647d0b169ff301fdb9ad7"));

            var outputPath = Path.Combine(RepositoryRoot(), "artifacts/android-compose/fixtures/csharp-written-after-kotlin-save-v1.json");
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath));
            var layout = new SaveFileLayout(Path.Combine(_testRoot, "rewrite"));
            using (var repository = CreateRepository(layout))
            {
                await repository.SaveAsync(result.Envelope.Payload, 8);
                File.Copy(layout.CanonicalPath, outputPath, true);
            }

            Assert.That(File.Exists(outputPath), Is.True);
            var roundTrip = await ReadWithCSharpRepository(outputPath);
            Assert.That(roundTrip.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
            Assert.That(roundTrip.Envelope.Revision, Is.EqualTo(8UL));
            Assert.That(roundTrip.Envelope.Payload.InstallId, Is.EqualTo(result.Envelope.Payload.InstallId));
            Assert.That(roundTrip.Envelope.Payload.Stage, Is.EqualTo(result.Envelope.Payload.Stage));
        }

        private async Task<SaveLoadResult<GameSaveAggregate>> ReadWithCSharpRepository(string sourcePath)
        {
            var layout = new SaveFileLayout(Path.Combine(_testRoot, Path.GetFileNameWithoutExtension(sourcePath)));
            Directory.CreateDirectory(layout.SaveDirectory);
            File.Copy(sourcePath, layout.CanonicalPath, true);
            using (var repository = CreateRepository(layout))
            {
                return await repository.LoadAsync();
            }
        }

        private AtomicSaveRepository<GameSaveAggregate> CreateRepository(SaveFileLayout layout)
        {
            return new AtomicSaveRepository<GameSaveAggregate>(
                layout,
                new SystemAtomicFileSystem(),
                new GameSaveValidator(),
                new GameSaveSemanticPriority(),
                new FixedClock(new DateTimeOffset(2026, 8, 14, 0, 0, 0, TimeSpan.Zero)));
        }

        private static string CurrentFixturePath() => Path.Combine(
            RepositoryRoot(),
            "apps/android/game-persistence/src/test/resources/legacy/save-v1-current.json");

        private static string KotlinWrittenFixturePath() => Path.Combine(
            RepositoryRoot(),
            "apps/android/game-persistence/src/test/resources/legacy/kotlin-written-save-v1.json");

        private static string RepositoryRoot()
        {
            var directory = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (directory != null)
            {
                var marker = Path.Combine(directory.FullName, "apps/android-unity/Assets");
                if (Directory.Exists(marker)) return directory.FullName;
                directory = directory.Parent;
            }

            throw new AssertionException("Repository root could not be located from the Unity test working directory.");
        }

        private sealed class FixedClock : IUtcClock
        {
            public FixedClock(DateTimeOffset utcNow) { UtcNow = utcNow; }
            public DateTimeOffset UtcNow { get; }
        }
    }
}
