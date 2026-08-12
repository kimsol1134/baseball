using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class ProApplicationFlowTests
    {
        [Test]
        public void DirectProFactory_IsStableAndDistributesAcrossTheWholeTeamCatalog()
        {
            var first = DirectProStartRequestFactory.Create(
                "777", "power_prospect", "윤하람");
            var replay = DirectProStartRequestFactory.Create(
                "777", "power_prospect", "윤하람");
            var selectedTeams = Enumerable.Range(1, 100)
                .Select(seed => DirectProStartRequestFactory.Create(
                    seed.ToString(), "power_prospect", "윤하람").TeamId)
                .Distinct(StringComparer.Ordinal)
                .ToArray();

            Assert.That(first.Seed, Is.EqualTo("777"));
            Assert.That(replay.Seed, Is.EqualTo(first.Seed));
            Assert.That(replay.TeamId, Is.EqualTo(first.TeamId));
            Assert.That(first.TeamId, Is.EqualTo("daejeon_rockets"));
            Assert.That(selectedTeams, Has.Length.EqualTo(
                Baseball.Core.Pro.ProCareerEngine.ProTeams.Count));
        }

        [Test]
        public async Task DirectProFactory_SaveFailureThenRestartPreservesSelectedTeam()
        {
            var repository = UnlockedDirectRepository();
            GameSaveAggregate saved;
            string selectedTeam;
            using (var store = await GameApplicationStore.OpenAsync(
                       repository,
                       new FakeHighSchoolPort(),
                       new CoreProCareerPort(),
                       "install-a"))
            {
                var request = DirectProStartRequestFactory.Create(
                    store.Current, "power_prospect", "윤하람");
                selectedTeam = request.TeamId;
                Assert.That(request.Seed, Is.EqualTo(DeterministicSeed.Normalize(
                    store.Current.InstallId + ":direct:" + store.Current.Revision)));
                var envelope = new CommandEnvelope<GameCommand>(
                    "direct-deterministic",
                    store.Current.Revision,
                    new StartDirectProCommand(request));
                var publications = 0;
                store.StatePublished += _ => publications++;

                repository.FailSave = true;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Pro, Is.Null);
                Assert.That(publications, Is.Zero);

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.Pro.TeamId, Is.EqualTo(selectedTeam));
                Assert.That(repository.Saved.Pro.TeamId, Is.EqualTo(selectedTeam));
                Assert.That(publications, Is.EqualTo(1));
                saved = repository.Saved;
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    saved.Revision,
                    new DateTimeOffset(2026, 8, 12, 0, 0, 0, TimeSpan.Zero),
                    new string('d', 64),
                    saved));
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository,
                       new FakeHighSchoolPort(),
                       new CoreProCareerPort(),
                       "install-a"))
            {
                Assert.That(restarted.Current.Pro.TeamId, Is.EqualTo(selectedTeam));
                Assert.That(restarted.Current.Pro.Origin, Is.EqualTo(ProCareerOrigin.Direct));
            }
        }

        [Test]
        public async Task DirectPro_IsLockedBeforeTheFirstCompletedLife()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(),
                       new FakeHighSchoolPort(),
                       new FakeProPort(),
                       "install-a"))
            {
                var result = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "direct-locked",
                    store.Current.Revision,
                    new StartDirectProCommand(
                        new StartDirectProRequest("seed", "power", "윤하람", "team-b"))));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(result.ErrorCode, Is.EqualTo("pro.direct_start_locked"));
                Assert.That(store.Current.Pro, Is.Null);
            }
        }

        [Test]
        public async Task DirectPro_RetirementCreditsOnceWithoutCreatingAFakeLife()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       UnlockedDirectRepository(completedGameCount: 6),
                       new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "direct", new StartDirectProCommand(
                    new StartDirectProRequest("seed", "power", "윤하람", "team-b")));
                var envelope = new CommandEnvelope<GameCommand>(
                    "retire",
                    store.Current.Revision,
                    new RetireProCareerCommand(
                        new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero)));
                Assert.That((await store.DispatchAsync(envelope)).Status, Is.EqualTo(DispatchStatus.Applied));
                var balance = store.Current.Meta.SoulBalance;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.AlreadyApplied));

                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Setup));
                Assert.That(store.Current.Pro, Is.Null);
                Assert.That(store.Current.HighSchool, Is.Null);
                Assert.That(store.Current.Meta.CreditedProCareerIds, Is.EquivalentTo(new[] { "pro-1" }));
                Assert.That(store.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                Assert.That(store.Current.Meta.LifeArchive[0].LifeId, Is.EqualTo("life:prior"));
                Assert.That(store.Current.Meta.LifeNumber, Is.EqualTo(2));
                Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(balance).And.GreaterThan(0));
                Assert.That(store.Current.Meta.Achievements.Unlocked, Does.Contain("hall_of_fame"));
                Assert.That(store.Current.Meta.CompletedGameCount, Is.EqualTo(6),
                    "Direct-Pro retirement is settlement, not another completed game.");
            }
        }

        [Test]
        public async Task LaterLifeDirectPro_PreservesActiveHighSchoolAcrossRetirement()
        {
            var highSchool = FakeHighSchoolPort.HighSchool(
                phase: HighSchoolPhase.Training,
                lifeNumber: 2,
                careerId: "hs-active",
                chapterNumber: 3,
                schoolYear: 2);
            using (var store = await GameApplicationStore.OpenAsync(
                       UnlockedDirectRepository(highSchool),
                       new FakeHighSchoolPort(),
                       new FakeProPort(),
                       "install-a"))
            {
                var highSchoolRevision = store.Current.HighSchool.CoreRevision;
                await Applied(store, "direct-alongside-hs", new StartDirectProCommand(
                    new StartDirectProRequest("seed", "power", "윤하람", "team-b")));
                await Applied(store, "retire-alongside-hs", new RetireProCareerCommand(
                    new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero)));

                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.HighSchool));
                Assert.That(store.Current.Pro, Is.Null);
                Assert.That(store.Current.HighSchool.CareerId, Is.EqualTo("hs-active"));
                Assert.That(store.Current.HighSchool.CoreRevision, Is.EqualTo(highSchoolRevision));
                Assert.That(store.Current.HighSchool.ChapterNumber, Is.EqualTo(3));
                Assert.That(store.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                Assert.That(store.Current.Meta.LifeNumber, Is.EqualTo(2));
            }
        }

        [Test]
        public async Task ProPitch_ConsumesSeedWithoutDoubleCreditingPlannedWeekAcrossRestart()
        {
            var proPort = new FakeProPort();
            var repository = UnlockedDirectRepository();
            GameSaveAggregate persisted;
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), proPort, "install-a"))
            {
                await Applied(store, "direct", new StartDirectProCommand(
                    new StartDirectProRequest("seed", "power", "윤하람", "team-b")));
                await Applied(store, "pro-pitch-weekly", new ConfigureWeeklyProgramCommand(
                    new WeeklyEligibility(false, 0, 0, true, false, false, false, true),
                    new DateTimeOffset(2026, 8, 11, 1, 59, 0, TimeSpan.Zero)));
                await Applied(store, "pro-pitch-plan", new AdvanceProCommand(
                    new ProCareerAction("advance_week"),
                    new DateTimeOffset(2026, 8, 11, 1, 59, 30, TimeSpan.Zero)));
                Assert.That(store.Current.Meta.CompletedGameCount, Is.Zero,
                    "weekly auto-simulation is not a user-completed important game");
                await Applied(store, "game-phase", new AdvanceProCommand(
                    new ProCareerAction("important_game"),
                    new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero)));
                var seed = store.Current.Pro.NextSeed;
                await Applied(store, "begin", new BeginPitchSessionCommand(
                    "pro-game-1", PitchCareerKind.Pro, "opening-series", 5,
                    new DateTimeOffset(2026, 8, 11, 2, 1, 0, TimeSpan.Zero)));
                Assert.That(store.Current.PitchResume.SessionSeed, Is.Not.EqualTo(seed));
                Assert.That(store.Current.Pro.NextSeed,
                    Is.EqualTo(store.Current.PitchResume.SessionSeed));

                var report = new PitchGameReport("pro-game-1", 18, 1, 3, 3, 1, 1, 1);
                await CommitTerminalReport(
                    store,
                    "pro-game-1",
                    report,
                    new DateTimeOffset(2026, 8, 11, 2, 4, 0, TimeSpan.Zero));
                var completion = new CommandEnvelope<GameCommand>(
                    "complete",
                    store.Current.Revision,
                    new CompletePitchSessionCommand(
                        report,
                        new DateTimeOffset(2026, 8, 11, 2, 5, 0, TimeSpan.Zero)));
                Assert.That((await store.DispatchAsync(completion)).Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That((await store.DispatchAsync(completion)).Status, Is.EqualTo(DispatchStatus.AlreadyApplied));

                Assert.That(proPort.PitchApplyCount, Is.EqualTo(1));
                Assert.That(store.Current.Meta.CompletedGameCount, Is.EqualTo(1));
                Assert.That(repository.Saved.Meta.CompletedGameCount, Is.EqualTo(1));
                Assert.That(store.Current.Pro.CurrentSeason.Strikeouts, Is.EqualTo(3));
                Assert.That(store.Current.PendingPitchCompletion.CareerKind, Is.EqualTo(PitchCareerKind.Pro));
                Assert.That(store.Current.Meta.Weekly.Program.Tasks.Single(value =>
                    value.Kind == WeeklyTaskKinds.ProWeeksAdvanced).Progress, Is.EqualTo(1));
                Assert.That(store.Current.Meta.Weekly.ProcessedReceiptIds,
                    Does.Not.Contain("complete:pro-week"));
                persisted = repository.Saved;
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    "baseball.game-save",
                    1,
                    persisted.Revision,
                    new DateTimeOffset(2026, 8, 11, 2, 6, 0, TimeSpan.Zero),
                    "fixture",
                    persisted));
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                Assert.That(restarted.Current.Meta.Weekly.Program.Tasks.Single(value =>
                    value.Kind == WeeklyTaskKinds.ProWeeksAdvanced).Progress, Is.EqualTo(1));
                Assert.That(restarted.Current.Meta.Weekly.ProcessedReceiptIds,
                    Does.Not.Contain("complete:pro-week"));
                Assert.That(restarted.Current.Meta.CompletedGameCount, Is.EqualTo(1));
            }
        }

        [Test]
        public void Retirement_RejectsMismatchedHighSchoolSource()
        {
            var highSchool = FakeHighSchoolPort.HighSchool(
                phase: HighSchoolPhase.Completed,
                careerId: "hs-current",
                draft: new DraftReadModel(true, true, 80, "team-a", "한울"));
            var pro = FakeProPort.Pro(
                origin: ProCareerOrigin.HighSchool,
                phase: ProCareerPhase.Completed,
                sourceHighSchoolCareerId: "hs-other");
            var aggregate = new GameSaveAggregate(
                1, 4, "install-a", ApplicationStage.Retirement,
                highSchool, pro, null, null, null, Array.Empty<string>());
            var transition = new GameCommandTransition(new FakeHighSchoolPort(), new FakeProPort());

            var result = transition.Apply(
                aggregate,
                new RetireProCareerCommand(new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero)),
                "retire");

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.ErrorCode, Is.EqualTo("retirement.source_mismatch"));
        }

        [Test]
        public async Task LinkedProRetirementAndFinalization_RestartWithFrozenCandidatesAndNoDuplicateReward()
        {
            var root = Path.Combine(
                Path.GetTempPath(),
                "BaseballProLegacyRestart",
                Guid.NewGuid().ToString("N"));
            var instant = new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero);
            try
            {
                string selectedId;
                string selectedEvidence;
                int proBalance;
                using (var repository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(Path.Combine(root, "save")),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                using (var store = await GameApplicationStore.OpenAsync(
                           repository,
                           new FakeHighSchoolPort(),
                           new FakeProPort(),
                           "install-a"))
                {
                    await Applied(store, "linked-setup", new EnterSetupCommand());
                    await Applied(store, "linked-start", new StartHighSchoolCareerCommand(
                        new StartHighSchoolCareerRequest(
                            "seed", "power_prospect", "민서준", "서울", 1)));
                    await Applied(store, "linked-draft", new AdvanceHighSchoolCommand(
                        new HighSchoolAction("resolve_draft", "drafted"), instant));
                    await Applied(store, "linked-pro", new EnterProFromDraftCommand());
                    await Applied(store, "linked-sign", new SignProContractCommand());
                    var retire = new CommandEnvelope<GameCommand>(
                        "linked-retire",
                        store.Current.Revision,
                        new RetireProCareerCommand(instant));
                    Assert.That((await store.DispatchAsync(retire)).Status,
                        Is.EqualTo(DispatchStatus.Applied));
                    proBalance = store.Current.Meta.SoulBalance;
                    Assert.That((await store.DispatchAsync(retire)).Status,
                        Is.EqualTo(DispatchStatus.AlreadyApplied));
                    Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(proBalance));
                    Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                    Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates.Count, Is.EqualTo(3));
                    selectedId = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0].Id;
                    selectedEvidence = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0]
                        .EvidenceSummary;
                }

                using (var repository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(Path.Combine(root, "save")),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                using (var restarted = await GameApplicationStore.OpenAsync(
                           repository,
                           new FakeHighSchoolPort(),
                           new FakeProPort(),
                           "install-a"))
                {
                    Assert.That(restarted.Current.Stage, Is.EqualTo(ApplicationStage.Legacy));
                    Assert.That(restarted.Current.Pro.Phase, Is.EqualTo(ProCareerPhase.Completed));
                    Assert.That(restarted.Current.Meta.SoulBalance, Is.EqualTo(proBalance));
                    Assert.That(restarted.Current.HighSchool.FrozenSignatureLegacyCandidates.Count, Is.EqualTo(3));
                    Assert.That(restarted.Current.HighSchool.FrozenSignatureLegacyCandidates[0]
                        .EvidenceSummary, Is.EqualTo(selectedEvidence));
                    var finalize = new CommandEnvelope<GameCommand>(
                        "linked-finalize",
                        restarted.Current.Revision,
                        new FinalizeHighSchoolLegacyCommand(
                            Array.Empty<string>(), selectedId, instant.AddMinutes(1)));
                    Assert.That((await restarted.DispatchAsync(finalize)).Status,
                        Is.EqualTo(DispatchStatus.Applied));
                    Assert.That((await restarted.DispatchAsync(finalize)).Status,
                        Is.EqualTo(DispatchStatus.AlreadyApplied));
                    Assert.That(restarted.Current.Pro, Is.Null);
                    Assert.That(restarted.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                    Assert.That(restarted.Current.Meta.LifeArchive[0].SignatureLegacy.Id,
                        Is.EqualTo(selectedId));
                    Assert.That(restarted.Current.Meta.LifeArchive[0].SignatureLegacy.EvidenceSummary,
                        Is.EqualTo(selectedEvidence));
                    Assert.That(restarted.Current.Meta.LifeArchive[0].SignatureLegacyCandidates.Count, Is.EqualTo(3));
                    Assert.That(restarted.Current.Meta.SoulBalance,
                        Is.GreaterThan(proBalance));
                }

                using (var repository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(Path.Combine(root, "save")),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                using (var restarted = await GameApplicationStore.OpenAsync(
                           repository,
                           new FakeHighSchoolPort(),
                           new FakeProPort(),
                           "install-a"))
                {
                    Assert.That(restarted.Current.Pro, Is.Null);
                    Assert.That(restarted.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                    Assert.That(restarted.Current.Meta.LifeArchive[0].SignatureLegacy.EvidenceSummary,
                        Is.EqualTo(selectedEvidence));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task ProWeekProgress_UsesReceiptAndDoesNotOvercountDoubleSubmit()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       UnlockedDirectRepository(), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "direct", new StartDirectProCommand(
                    new StartDirectProRequest("seed", "power", "윤하람", "team-b")));
                await Applied(store, "weekly", new ConfigureWeeklyProgramCommand(
                    new Baseball.Application.Meta.WeeklyEligibility(
                        false, 0, 0, true, false, false, false, true),
                    new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero)));
                var revision = store.Current.Revision;
                var envelope = new CommandEnvelope<GameCommand>(
                    "week-advance",
                    revision,
                    new AdvanceProCommand(
                        new ProCareerAction("advance_week"),
                        new DateTimeOffset(2026, 8, 11, 2, 1, 0, TimeSpan.Zero)));

                Assert.That((await store.DispatchAsync(envelope)).Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That((await store.DispatchAsync(envelope)).Status, Is.EqualTo(DispatchStatus.AlreadyApplied));
                Assert.That(store.Current.Pro.Week, Is.EqualTo(2));
                Assert.That(store.Current.Meta.Weekly.ProcessedReceiptIds,
                    Does.Contain("week-advance:pro-weeks"));
            }
        }

        [Test]
        public void OffseasonSeasonIncrement_DoesNotCreditSyntheticProWeeks()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero);
            var task = new WeeklyTaskState(
                "pro-weeks", WeeklyTaskKinds.ProWeeksAdvanced, 3, 0);
            var program = new WeeklyProgramState(
                SeoulGameCalendar.WeekKey(instant),
                new[] { task },
                Array.Empty<string>(),
                false);
            var weekly = new WeeklyProgressState(
                program,
                lastObservedWeekStartDayKey: SeoulGameCalendar.WeekStartDayKey(instant));
            var pro = FakeProPort.Copy(
                FakeProPort.Pro(),
                phase: ProCareerPhase.Offseason,
                season: 1,
                week: 24);
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                1,
                "install-a",
                ApplicationStage.Pro,
                null,
                pro,
                MetaProgressState.Initial.With(weekly: weekly),
                null,
                null,
                Array.Empty<string>());

            var result = new GameCommandTransition(new FakeHighSchoolPort(), new FakeProPort()).Apply(
                aggregate,
                new AdvanceProCommand(
                    new ProCareerAction("offseason", "continue_career"),
                    instant),
                "offseason");

            Assert.That(result.IsSuccess, Is.True, result.ErrorCode);
            Assert.That(result.NextState.Pro.Season, Is.EqualTo(2));
            Assert.That(result.NextState.Meta.Weekly.Program.Tasks.Single().Progress, Is.Zero);
            Assert.That(result.NextState.Meta.Weekly.ProcessedReceiptIds,
                Does.Not.Contain("offseason:pro-weeks"));
        }

        [Test]
        public async Task TargetedMovementSegment_SavesBeforePublishAndRestartsWithExactProgress()
        {
            var repository = UnlockedDirectRepository();
            var instant = new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero);
            string target;
            GameSaveAggregate saved;
            using (var store = await GameApplicationStore.OpenAsync(
                       repository,
                       new FakeHighSchoolPort(),
                       new CoreProCareerPort(),
                       "install-a"))
            {
                await Applied(store, "direct-segment", new StartDirectProCommand(
                    new StartDirectProRequest(
                        "4011",
                        "breaking_ball_artist",
                        "윤하람",
                        Baseball.Core.Pro.ProCareerEngine.ProTeams[0].Id)));
                target = store.Current.Pro.DevelopmentPitchChoices[0].Id;
                var missingTarget = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "segment-invalid",
                    store.Current.Revision,
                    new AdvanceProCommand(
                        new ProCareerAction(
                            ProWeekActionPayload.AdvanceSegmentAction,
                            "develop_movement"),
                        instant)));
                Assert.That(missingTarget.Status, Is.EqualTo(DispatchStatus.DomainRejected));

                var envelope = new CommandEnvelope<GameCommand>(
                    "segment-targeted",
                    store.Current.Revision,
                    new AdvanceProCommand(
                        new ProCareerAction(
                            ProWeekActionPayload.AdvanceSegmentAction,
                            ProWeekActionPayload.Encode("develop_movement", target)),
                        instant));
                var publications = 0;
                store.StatePublished += _ => publications++;
                repository.FailSave = true;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Pro.LastSegmentProgress, Is.Null);
                Assert.That(store.Current.Meta.CompletedGameCount, Is.Zero);
                Assert.That(publications, Is.Zero);

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.Applied));
                Assert.That(publications, Is.EqualTo(1));
                Assert.That(store.Current.Pro.LastSegmentProgress.AdvancedWeeks,
                    Is.GreaterThanOrEqualTo(1));
                Assert.That(store.Current.Pro.LastSegmentProgress.TargetPitch,
                    Is.EqualTo(target));
                Assert.That(store.Current.Pro.CurrentSeason.ImportantGames, Is.GreaterThan(0),
                    "the Core projection includes auto-simulated outings");
                Assert.That(store.Current.Meta.CompletedGameCount, Is.Zero,
                    "auto-progressed outings are not interactive game completions");
                saved = repository.Saved;
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    "baseball.game-save",
                    1,
                    saved.Revision,
                    instant,
                    "fixture",
                    saved));
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository,
                       new FakeHighSchoolPort(),
                       new CoreProCareerPort(),
                       "install-a"))
            {
                Assert.That(restarted.Current.Pro.LastSegmentProgress, Is.Not.Null);
                Assert.That(restarted.Current.Pro.LastSegmentProgress.TargetPitch,
                    Is.EqualTo(target));
                Assert.That(restarted.Current.Pro.DevelopmentProgress.Movement,
                    Is.EqualTo(1));
                Assert.That(restarted.Current.Pro.CoreStateJson,
                    Does.Contain("DevelopmentProgress"));
                Assert.That(restarted.Current.Meta.CompletedGameCount, Is.Zero);
            }
        }

        private static async Task Applied(
            GameApplicationStore store,
            string id,
            GameCommand command)
        {
            var result = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                id,
                store.Current.Revision,
                command));
            Assert.That(result.Status, Is.EqualTo(DispatchStatus.Applied), result.ErrorCode);
        }

        private static async Task CommitTerminalReport(
            GameApplicationStore store,
            string id,
            PitchGameReport report,
            DateTimeOffset occurredAt)
        {
            var resume = store.Current.PitchResume;
            var pitchId = id + ":pitch";
            var evidence = new PitchAbilityMomentEvidence(
                new PitchCall(
                    PitchType.FourSeam,
                    new PitchZone(1, 1),
                    ZoneIntent.Strike,
                    PitchIntensity.Normal),
                new PlateAppearanceContext(
                    id + ":pa", 0, 1, 0, 0, 0, 1, 0, 500, 0),
                PitchOutcome.Ball,
                new PitchExecution(0, 0, 0, 0, 1450, 0, 0, 900));
            await Applied(store, id + ":commit", new CommitPitchResultCommand(
                resume.GameId,
                pitchId,
                resume.CompletedBatters,
                id + ":hash",
                "{\"outcome\":\"terminal\"}",
                "{\"cue\":\"terminal\"}",
                occurredAt,
                abilityMomentEvidence: evidence));
            await Applied(store, id + ":consume", new ConsumeCommittedPitchResultCommand(
                resume.GameId,
                pitchId,
                report.Batters,
                "{\"terminal\":true}",
                report,
                sessionCompleted: true));
        }

        private static RecordingGameRepository UnlockedDirectRepository(
            HighSchoolCareerReadModel activeHighSchool = null,
            int completedGameCount = 0)
        {
            var instant = new DateTimeOffset(2026, 8, 10, 1, 0, 0, TimeSpan.Zero);
            var record = new LifeArchiveRecord(
                "life:prior",
                1,
                "이전 선수",
                "hs-prior",
                null,
                "school-a",
                "새빛고",
                false,
                42,
                new PitcherRatingsReadModel(45, 45, 45, 45),
                new CareerPerformanceReadModel(),
                0,
                0,
                0,
                0,
                20);
            var meta = MetaProgressState.Initial.With(
                lifeNumber: activeHighSchool?.LifeNumber ?? 2,
                lifeArchive: new[] { record },
                completedGameCount: completedGameCount);
            var stage = activeHighSchool == null
                ? ApplicationStage.Setup
                : ApplicationStage.HighSchool;
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                1,
                "install-a",
                stage,
                activeHighSchool,
                null,
                meta,
                null,
                null,
                Array.Empty<string>());
            return new RecordingGameRepository
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.LoadedCanonical,
                    new SaveEnvelope<GameSaveAggregate>(
                        SaveSchema.Name,
                        SaveSchema.Version,
                        aggregate.Revision,
                        instant,
                        new string('a', 64),
                        aggregate))
            };
        }
    }
}
