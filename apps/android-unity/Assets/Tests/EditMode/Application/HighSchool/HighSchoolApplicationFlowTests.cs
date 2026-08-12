using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Pitching;
using CoreRunPledgeCatalog = Baseball.Core.HighSchool.RunPledgeCatalog;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class HighSchoolApplicationFlowTests
    {
        [Test]
        public async Task SkipTutorial_SavesBeforePublishAndRestartsAtSchoolSelection()
        {
            var repository = new RecordingGameRepository();
            GameSaveAggregate saved;
            var instant = new DateTimeOffset(2026, 8, 11, 0, 30, 0, TimeSpan.Zero);
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "setup-skip", new EnterSetupCommand());
                await Applied(store, "start-skip", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "seed", "power_prospect", "민서준", "서울", 1)));
                var before = store.Current.HighSchool;
                var envelope = new CommandEnvelope<GameCommand>(
                    "skip-tutorial",
                    store.Current.Revision,
                    new SkipTutorialCommand());
                repository.FailSave = true;
                var failed = await store.DispatchAsync(envelope);
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.HighSchool.Phase, Is.EqualTo(HighSchoolPhase.Prologue));

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.HighSchool.Phase,
                    Is.EqualTo(HighSchoolPhase.SchoolSelection));
                Assert.That(store.Current.HighSchool.TutorialCompleted, Is.False);
                Assert.That(store.Current.HighSchool.TutorialAttemptCount, Is.Zero);
                Assert.That(store.Current.HighSchool.Ratings.Total, Is.EqualTo(before.Ratings.Total));
                Assert.That(store.Current.HighSchool.Performance.ImportantGames,
                    Is.EqualTo(before.Performance.ImportantGames));
                Assert.That(store.Current.Meta.Weekly.ProcessedReceiptIds, Is.Empty);
                saved = repository.Saved;
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    saved.Revision,
                    instant,
                    new string('b', 64),
                    saved));
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                Assert.That(restarted.Current.HighSchool.Phase,
                    Is.EqualTo(HighSchoolPhase.SchoolSelection));
                await Applied(restarted, "choose-after-skip", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("choose_school", "school-a"), instant));
                Assert.That(restarted.Current.HighSchool.Phase, Is.EqualTo(HighSchoolPhase.Training));
            }
        }

        [Test]
        public async Task DeclineDraftedProOffer_AtomicallyOpensFrozenLegacyChoices()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var instant = new DateTimeOffset(2026, 8, 11, 0, 45, 0, TimeSpan.Zero);
                await Applied(store, "setup-decline", new EnterSetupCommand());
                await Applied(store, "start-decline", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "draft-decline", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "drafted"), instant));
                var envelope = new CommandEnvelope<GameCommand>(
                    "decline-pro",
                    store.Current.Revision,
                    new DeclineProCareerCommand());
                repository.FailSave = true;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Draft));
                Assert.That(store.Current.HighSchool.Phase, Is.EqualTo(HighSchoolPhase.Completed));

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.Applied));
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.AlreadyApplied));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Legacy));
                Assert.That(store.Current.Pro, Is.Null);
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates.Count, Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.SignatureLegacyChoices.Select(x => x.Id),
                    Is.EquivalentTo(store.Current.HighSchool.FrozenSignatureLegacyCandidates.Select(x => x.Id)));
            }
        }

        [Test]
        public async Task OpeningSetupHighSchoolDraftAndPro_UseOneRevisionedAggregate()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Opening));
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "draft", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "drafted"),
                    new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Draft));
                await Applied(store, "pro", new EnterProFromDraftCommand());
                await Applied(store, "sign-contract", new SignProContractCommand());

                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Pro));
                Assert.That(store.Current.Revision, Is.EqualTo(5));
                Assert.That(store.Current.Pro.SourceHighSchoolCareerId, Is.EqualTo("hs-1"));
                Assert.That(store.Current.HighSchool.CareerId, Is.EqualTo("hs-1"));
                Assert.That(repository.SaveCount, Is.EqualTo(5));
                Assert.That(repository.Saved, Is.SameAs(store.Current));
            }
        }

        [Test]
        public async Task CompleteThreeYearPath_DraftProRetirementAndRebirthPreserveOneLifeArchive()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "school", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("choose_school", "school-a"), instant));
                for (var chapter = 2; chapter <= 8; chapter++)
                {
                    await Applied(store, "chapter-" + chapter, new AdvanceHighSchoolCommand(
                        new HighSchoolAction("advance_chapter"), instant.AddMinutes(chapter)));
                }
                Assert.That(store.Current.HighSchool.SchoolYear, Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.ChapterNumber, Is.EqualTo(8));

                await Applied(store, "draft", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "drafted"), instant.AddMinutes(20)));
                await Applied(store, "pro", new EnterProFromDraftCommand());
                await Applied(store, "sign-contract", new SignProContractCommand());
                await Applied(store, "retire", new RetireProCareerCommand(instant.AddMinutes(30)));
                Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates.Count, Is.EqualTo(3));
                var signature = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0];
                await Applied(store, "finalize-legacy", new FinalizeHighSchoolLegacyCommand(
                    Array.Empty<string>(), signature.Id, instant.AddMinutes(31)));
                var frozenLegacy = store.Current.Meta.LifeArchive.Single().PlayerLegacy;
                Assert.That(frozenLegacy, Is.Not.Null);
                Assert.That(frozenLegacy.Title, Is.EqualTo("자기 공을 남긴 투수"));
                Assert.That(frozenLegacy.DefiningMoment, Is.EqualTo(signature.EvidenceSummary));
                Assert.That(frozenLegacy.Farewell, Is.Not.Empty);
                await Applied(store, "rebirth", new BeginRebirthCommand(instant.AddMinutes(32)));

                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Setup));
                Assert.That(store.Current.Meta.LifeNumber, Is.EqualTo(2));
                Assert.That(store.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                Assert.That(store.Current.Meta.LifeArchive[0].HighSchoolCareerId, Is.EqualTo("hs-1"));
                Assert.That(store.Current.Meta.LifeArchive[0].ProCareerId, Is.EqualTo("pro-1"));
                Assert.That(store.Current.Meta.LifeArchive[0].PlayerLegacy.Title,
                    Is.EqualTo(frozenLegacy.Title));
                Assert.That(store.Current.Meta.LifeArchive[0].PlayerLegacy.DefiningMoment,
                    Is.EqualTo(frozenLegacy.DefiningMoment));
                Assert.That(store.Current.Meta.LifeArchive[0].PlayerLegacy.Farewell,
                    Is.EqualTo(frozenLegacy.Farewell));
                Assert.That(store.Current.HighSchool, Is.Null);
                Assert.That(store.Current.Pro, Is.Null);

                await Applied(store, "custom-rebirth", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "second-seed",
                        "precision_commander",
                        "고태윤",
                        "대전",
                        2,
                        difficulty: "challenging")));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.HighSchool));
                Assert.That(store.Current.HighSchool.LifeNumber, Is.EqualTo(2));
                Assert.That(store.Current.HighSchool.PresetId, Is.EqualTo("precision_commander"));
                Assert.That(store.Current.HighSchool.PlayerName, Is.EqualTo("고태윤"));
                Assert.That(store.Current.HighSchool.Difficulty, Is.EqualTo("challenging"));
                Assert.That(store.Current.HighSchool.EquippedSignatureLegacyId,
                    Is.EqualTo(signature.Id));
                Assert.That(store.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task DirectPitch_CheckpointSurvivesRestartAtBatterBoundary()
        {
            var root = Path.Combine(Path.GetTempPath(), "BaseballGameFlow", Guid.NewGuid().ToString("N"));
            try
            {
                var highSchool = new FakeHighSchoolPort();
                var pro = new FakeProPort();
                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root), highSchool, pro, "install-a"))
                {
                    await Applied(store, "setup", new EnterSetupCommand());
                    await Applied(store, "start", new StartHighSchoolCareerCommand(
                        new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                    await Applied(store, "game-phase", new AdvanceHighSchoolCommand(
                        new HighSchoolAction("important_game"),
                        new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));
                    var seedBefore = store.Current.HighSchool.NextSeed;
                    await Applied(store, "begin-game", new BeginPitchSessionCommand(
                        "game-1",
                        PitchCareerKind.HighSchool,
                        "regional-final",
                        6,
                        new DateTimeOffset(2026, 8, 11, 1, 1, 0, TimeSpan.Zero)));
                    await Applied(store, "checkpoint-2", new CheckpointPitchSessionCommand(
                        "game-1", 2, "{\"batter\":2,\"balls\":1,\"strikes\":2}"));

                    Assert.That(store.Current.PitchResume.SessionSeed, Is.Not.EqualTo(seedBefore));
                    Assert.That(store.Current.HighSchool.NextSeed,
                        Is.EqualTo(store.Current.PitchResume.SessionSeed));
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(restarted.Current.PitchResume.GameId, Is.EqualTo("game-1"));
                    Assert.That(restarted.Current.PitchResume.CompletedBatters, Is.EqualTo(2));
                    Assert.That(restarted.Current.PitchResume.MaximumBatters, Is.EqualTo(6));
                    Assert.That(restarted.Current.PitchResume.CheckpointJson, Does.Contain("balls"));
                    Assert.That(NextActionPlanner.Resolve(restarted.Current).Route, Is.EqualTo("pitch/resume"));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task PitchCompletion_AppliesCoreAndMetaExactlyOnceBeforeResultIsVisible()
        {
            var repository = new RecordingGameRepository();
            var highSchool = new FakeHighSchoolPort();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, highSchool, new FakeProPort(), "install-a"))
            {
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "game-phase", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("important_game"),
                    new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));
                await Applied(store, "begin", new BeginPitchSessionCommand(
                    "game-1", PitchCareerKind.HighSchool, "final", 4,
                    new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));
                var completedAt = new DateTimeOffset(2026, 8, 11, 1, 4, 0, TimeSpan.Zero);
                var report = new PitchGameReport("game-1", 14, 1, 3, 2, 0, 1, 0);
                var fabricated = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "fabricated-complete",
                    store.Current.Revision,
                    new CompletePitchSessionCommand(report, completedAt)));
                Assert.That(fabricated.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(fabricated.ErrorCode, Is.EqualTo("pitch.authoritative_pitch_required"));
                await CommitTerminalReport(store, "game-1", report, completedAt.AddSeconds(-1));
                var forgedAfterConsume = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "forged-after-consume",
                    store.Current.Revision,
                    new CompletePitchSessionCommand(
                        new PitchGameReport(
                            report.GameId,
                            report.Pitches,
                            report.Batters,
                            report.Outs,
                            report.Strikeouts + 1,
                            report.Walks,
                            report.Hits,
                            report.RunsAllowed),
                        completedAt)));
                Assert.That(forgedAfterConsume.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(forgedAfterConsume.ErrorCode,
                    Is.EqualTo("pitch.report_checkpoint_mismatch"));
                var envelope = new CommandEnvelope<GameCommand>(
                    "complete",
                    store.Current.Revision,
                    new CompletePitchSessionCommand(report, completedAt));

                var first = await store.DispatchAsync(envelope);
                var duplicate = await store.DispatchAsync(envelope);

                Assert.That(first.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.AlreadyApplied));
                Assert.That(highSchool.PitchApplyCount, Is.EqualTo(1));
                Assert.That(store.Current.Meta.CompletedGameCount, Is.EqualTo(1));
                Assert.That(repository.Saved.Meta.CompletedGameCount, Is.EqualTo(1));
                Assert.That(store.Current.HighSchool.Performance.ImportantGames, Is.EqualTo(1));
                Assert.That(store.Current.PitchResume, Is.Null);
                Assert.That(store.Current.PendingPitchCompletion.CompletionId, Is.EqualTo("pitch-result:game-1"));
                Assert.That(store.Current.Meta.Daily.CurrentStreak, Is.EqualTo(1));
                Assert.That(store.Current.Meta.Achievements.Unlocked,
                    Does.Contain(AchievementIds.CleanInning));
                Assert.That(repository.Saved.PendingPitchCompletion, Is.Not.Null);
                Assert.That(NextActionPlanner.Resolve(store.Current).Route, Is.EqualTo("pitch/result"));
            }
        }

        [Test]
        public async Task FirstOfficialGameCounter_IsNotPublishedWhenAtomicSaveFails()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
                await Applied(store, "counter-setup", new EnterSetupCommand());
                await Applied(store, "counter-start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "counter-game-phase", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("important_game"), instant));
                await Applied(store, "counter-begin", new BeginPitchSessionCommand(
                    "counter-game", PitchCareerKind.HighSchool, "official", 4, instant));
                var report = new PitchGameReport(
                    "counter-game", 5, 1, 3, 1, 0, 0, 0);
                await CommitTerminalReport(
                    store, "counter-game", report, instant.AddMinutes(1));
                var publications = 0;
                store.StatePublished += _ => publications++;
                repository.FailSave = true;

                var failed = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "counter-complete",
                    store.Current.Revision,
                    new CompletePitchSessionCommand(report, instant.AddMinutes(2))));

                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Meta.CompletedGameCount, Is.Zero);
                Assert.That(store.Current.PendingPitchCompletion, Is.Null);
                Assert.That(store.Current.PitchResume.AwaitingCompletion, Is.True);
                Assert.That(repository.Saved.Meta.CompletedGameCount, Is.Zero);
                Assert.That(publications, Is.Zero);
            }
        }

        [Test]
        public async Task AbandonedPitch_ClearsCheckpointButNeverReusesConsumedSeed()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "game-phase", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("important_game"),
                    new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));
                await Applied(store, "begin-1", new BeginPitchSessionCommand(
                    "game-1", PitchCareerKind.HighSchool, "final", 4,
                    new DateTimeOffset(2026, 8, 11, 1, 1, 0, TimeSpan.Zero)));
                var firstSessionSeed = store.Current.PitchResume.SessionSeed;
                await Applied(store, "abandon", new AbandonPitchSessionCommand("game-1"));
                await Applied(store, "begin-2", new BeginPitchSessionCommand(
                    "game-2", PitchCareerKind.HighSchool, "final", 4,
                    new DateTimeOffset(2026, 8, 11, 1, 2, 0, TimeSpan.Zero)));

                Assert.That(store.Current.PitchResume.GameId, Is.EqualTo("game-2"));
                Assert.That(store.Current.PitchResume.SessionSeed, Is.Not.EqualTo(firstSessionSeed));
            }
        }

        [Test]
        public async Task SuspendedPitch_SaveFailureThenRestartPreservesExactBatterAndSeed()
        {
            var repository = new RecordingGameRepository();
            var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            GameSaveAggregate saved;
            PitchResumeState suspended;
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "suspend-setup", new EnterSetupCommand());
                await Applied(store, "suspend-start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "suspend-game", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("important_game"), instant));
                await Applied(store, "suspend-begin", new BeginPitchSessionCommand(
                    "suspend-game", PitchCareerKind.HighSchool, "regional-final", 6,
                    instant.AddMinutes(1)));
                await Applied(store, "suspend-commit", new CommitPitchResultCommand(
                    "suspend-game", "suspend-pitch-1", 0, "suspend-hash-1",
                    "{\"result\":\"out\"}", "{\"cue\":\"glove\"}",
                    instant.AddMinutes(2),
                    delivery: new PitchDeliveryMetricState(940, 920, true),
                    abilityMomentEvidence: AbilityEvidence(null)));
                var report = new PitchGameReport(
                    "suspend-game", 1, 1, 1, 1, 0, 0, 0,
                    directDeliveryCount: 1,
                    deliveryScoreTotal: 930,
                    bestDeliveryScore: 930,
                    perfectDeliveryCount: 1);
                await Applied(store, "suspend-consume", new ConsumeCommittedPitchResultCommand(
                    "suspend-game", "suspend-pitch-1", 1,
                    "{\"batter\":1,\"outs\":1}", report));

                suspended = store.Current.PitchResume;
                var revision = store.Current.Revision;
                var publications = 0;
                store.StatePublished += _ => publications++;
                var command = new CommandEnvelope<GameCommand>(
                    "suspend",
                    revision,
                    new SuspendPitchSessionCommand("suspend-game"));

                repository.FailSave = true;
                Assert.That((await store.DispatchAsync(command)).Status,
                    Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Revision, Is.EqualTo(revision));
                Assert.That(store.Current.PitchResume, Is.SameAs(suspended));
                Assert.That(publications, Is.Zero);

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(command)).Status,
                    Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.HighSchool));
                Assert.That(store.Current.PitchResume, Is.SameAs(suspended));
                Assert.That(store.Current.PitchResume.SessionSeed,
                    Is.EqualTo(suspended.SessionSeed));
                Assert.That(store.Current.PitchResume.CompletedBatters, Is.EqualTo(1));
                Assert.That(store.Current.PitchResume.AccumulatedReport, Is.SameAs(report));
                Assert.That(store.Current.PitchResume.Metrics.DirectDeliveryCount, Is.EqualTo(1));
                Assert.That(store.Current.PitchResume.Metrics.PerfectDeliveryCount, Is.EqualTo(1));
                Assert.That(store.Current.PitchResume.CheckpointJson,
                    Is.EqualTo("{\"batter\":1,\"outs\":1}"));
                Assert.That(publications, Is.EqualTo(1));
                saved = repository.Saved;
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                Envelope(saved));
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var resume = restarted.Current.PitchResume;
                Assert.That(restarted.Current.Stage, Is.EqualTo(ApplicationStage.HighSchool));
                Assert.That(resume.GameId, Is.EqualTo(suspended.GameId));
                Assert.That(resume.SessionSeed, Is.EqualTo(suspended.SessionSeed));
                Assert.That(resume.CompletedBatters, Is.EqualTo(suspended.CompletedBatters));
                Assert.That(resume.MaximumBatters, Is.EqualTo(suspended.MaximumBatters));
                Assert.That(resume.Scenario.ScenarioId, Is.EqualTo(suspended.Scenario.ScenarioId));
                Assert.That(resume.AccumulatedReport.Pitches,
                    Is.EqualTo(suspended.AccumulatedReport.Pitches));
                Assert.That(resume.ConsumedPitchIds,
                    Is.EqualTo(suspended.ConsumedPitchIds));
                Assert.That(resume.Metrics.DirectDeliveryCount, Is.EqualTo(1));
                Assert.That(resume.Metrics.PerfectDeliveryCount, Is.EqualTo(1));
                Assert.That(NextActionPlanner.Resolve(restarted.Current).Route,
                    Is.EqualTo("pitch/resume"));

                await Applied(restarted, "suspend-next-commit", new CommitPitchResultCommand(
                    resume.GameId, "suspend-pitch-2", resume.CompletedBatters,
                    "suspend-hash-2", "{\"result\":\"ball\"}",
                    "{\"cue\":\"take\"}", instant.AddMinutes(3),
                    abilityMomentEvidence: AbilityEvidence(null)));
                var blocked = await restarted.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "suspend-with-commit",
                    restarted.Current.Revision,
                    new SuspendPitchSessionCommand(resume.GameId)));
                Assert.That(blocked.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(blocked.ErrorCode, Is.EqualTo("pitch.committed_result_pending"));
            }
        }

        [Test]
        public async Task CommittedPitch_SurvivesRestartAndMustBeConsumedBeforeNextBatter()
        {
            var root = Path.Combine(Path.GetTempPath(), "BaseballCommittedPitch", Guid.NewGuid().ToString("N"));
            try
            {
                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    await Applied(store, "setup", new EnterSetupCommand());
                    await Applied(store, "start", new StartHighSchoolCareerCommand(
                        new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                    await Applied(store, "game", new AdvanceHighSchoolCommand(
                        new HighSchoolAction("important_game"),
                        new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));
                    await Applied(store, "begin", new BeginPitchSessionCommand(
                        "multi-game", PitchCareerKind.HighSchool, "important", 6,
                        new DateTimeOffset(2026, 8, 11, 1, 1, 0, TimeSpan.Zero)));

                    Assert.That(store.Current.PitchResume.MaximumBatters, Is.EqualTo(6));
                    Assert.That(store.Current.PitchResume.Scenario.Lineup.Count, Is.GreaterThanOrEqualTo(6));
                    await Applied(store, "commit-1", new CommitPitchResultCommand(
                        "multi-game", "pitch-1", 0, "hash-1",
                        "{\"result\":\"strike\"}", "{\"cue\":\"glove\"}",
                        new DateTimeOffset(2026, 8, 11, 1, 2, 0, TimeSpan.Zero),
                        abilityMomentEvidence: AbilityEvidence(null)));

                    var blocked = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "checkpoint-too-early",
                        store.Current.Revision,
                        new CheckpointPitchSessionCommand("multi-game", 1, "{\"batter\":1}")));
                    Assert.That(blocked.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(blocked.ErrorCode, Is.EqualTo("pitch.committed_result_pending"));
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    var committed = restarted.Current.PitchResume.CommittedPitch;
                    Assert.That(committed.PitchId, Is.EqualTo("pitch-1"));
                    Assert.That(committed.KernelResultJson, Does.Contain("strike"));
                    Assert.That(restarted.Current.PitchResume.CompletedBatters, Is.Zero);
                    var accumulated = new PitchGameReport(
                        "multi-game", 4, 1, 1, 1, 0, 0, 0);
                    await Applied(restarted, "consume-1", new ConsumeCommittedPitchResultCommand(
                        "multi-game", "pitch-1", 1,
                        "{\"batter\":1,\"outs\":1}", accumulated));
                }

                using (var resumedAgain = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(resumedAgain.Current.PitchResume.CommittedPitch, Is.Null);
                    Assert.That(resumedAgain.Current.PitchResume.CompletedBatters, Is.EqualTo(1));
                    Assert.That(resumedAgain.Current.PitchResume.CheckpointJson, Does.Contain("outs"));
                    Assert.That(resumedAgain.Current.PitchResume.AccumulatedReport.Batters, Is.EqualTo(1));
                    Assert.That(resumedAgain.Current.PitchResume.Scenario.Lineup[1].Id, Is.Not.Empty);
                    Assert.That(resumedAgain.Current.PitchResume.ConsumedPitchIds,
                        Is.EquivalentTo(new[] { "pitch-1" }));
                    var replay = await resumedAgain.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "replay-pitch-id",
                        resumedAgain.Current.Revision,
                        new CommitPitchResultCommand(
                            "multi-game", "pitch-1", 1, "hash-replayed",
                            "{\"result\":\"replayed\"}", "{\"cue\":\"replayed\"}",
                            DateTimeOffset.UtcNow,
                            abilityMomentEvidence: AbilityEvidence(null))));
                    Assert.That(replay.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(replay.ErrorCode, Is.EqualTo("pitch.committed_result_invalid"));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task AbilityMomentEvidence_IsDerivedBeforeCommitAndConsumedOnceAcrossRestart()
        {
            var root = Path.Combine(Path.GetTempPath(), "BaseballAbilityMoment", Guid.NewGuid().ToString("N"));
            var instant = new DateTimeOffset(2026, 8, 11, 4, 0, 0, TimeSpan.Zero);
            try
            {
                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    await Applied(store, "ability-setup", new EnterSetupCommand());
                    await Applied(store, "ability-start", new StartHighSchoolCareerCommand(
                        new StartHighSchoolCareerRequest(
                            "seed", "power_prospect", "민서준", "서울", 1)));
                    await Applied(store, "ability-game-phase", new AdvanceHighSchoolCommand(
                        new HighSchoolAction("important_game"), instant));
                    await Applied(store, "ability-begin", new BeginPitchSessionCommand(
                        "daily-ability", PitchCareerKind.HighSchool, "important", 1, instant));
                    var missingEvidence = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "ability-missing",
                        store.Current.Revision,
                        new CommitPitchResultCommand(
                            "daily-ability", "ability-pitch", 0, "hash-missing",
                            "{\"outcome\":\"called_strike\"}", "{\"cue\":1}", instant)));
                    Assert.That(missingEvidence.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    var invalid = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "ability-invalid",
                        store.Current.Revision,
                        new CommitPitchResultCommand(
                            "daily-ability", "ability-pitch", 0, "hash-invalid",
                            "{\"outcome\":\"called_strike\"}", "{\"cue\":1}", instant,
                            abilityMomentEvidence: new PitchAbilityMomentEvidence(
                                new PitchCall(PitchType.FourSeam, new PitchZone(1, 1), ZoneIntent.Strike, PitchIntensity.Normal),
                                new PlateAppearanceContext("ability-pa", 0, 9, 0, 0, 0, 1, 1, 900, 20),
                                PitchOutcome.CalledStrike,
                                new PitchExecution(0, 0, 0, 0, 1430, 0, 0, 1001)))));
                    Assert.That(invalid.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    var mismatched = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "ability-mismatch",
                        store.Current.Revision,
                        new CommitPitchResultCommand(
                            "daily-ability", "ability-pitch", 0, "hash-mismatch",
                            "{\"outcome\":\"called_strike\"}", "{\"cue\":1}", instant,
                            sequencePitch: new PitchSequencePitch(
                                PitchType.Slider, new PitchZone(1, 1), ZoneIntent.Strike, 143,
                                PitchOutcome.CalledStrike),
                            abilityMomentEvidence: AbilityEvidence(PitchAbilityKind.Command))));
                    Assert.That(mismatched.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    await Applied(store, "ability-commit", new CommitPitchResultCommand(
                        "daily-ability", "ability-pitch", 0, "hash",
                        "{\"outcome\":\"in_play_out\"}", "{\"cue\":1}", instant,
                        abilityMomentEvidence: AbilityEvidence(
                            PitchAbilityKind.Movement,
                            recommendationAccepted: true)));
                    Assert.That(store.Current.PitchResume.PitchLog, Is.Empty,
                        "a committed-but-unconsumed pitch is replay evidence, not a log entry");
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(restarted.Current.PitchResume.CommittedPitch.AbilityMomentType,
                        Is.EqualTo("movement"));
                    var pendingLog = restarted.Current.PitchResume.CommittedPitch.PitchLogEntry;
                    Assert.That(pendingLog, Is.Not.Null);
                    Assert.That(pendingLog.PitchId, Is.EqualTo("ability-pitch"));
                    Assert.That(pendingLog.PitchNumber, Is.EqualTo(1));
                    Assert.That(pendingLog.PitchType, Is.EqualTo("slider"));
                    Assert.That(pendingLog.ZoneRow, Is.EqualTo(1));
                    Assert.That(pendingLog.ZoneColumn, Is.EqualTo(1));
                    Assert.That(pendingLog.ZoneIntent, Is.EqualTo("strike"));
                    Assert.That(pendingLog.Intensity, Is.EqualTo("normal"));
                    Assert.That(pendingLog.Outcome, Is.EqualTo("in_play_out"));
                    Assert.That(pendingLog.VelocityTenthsKph, Is.EqualTo(1450));
                    Assert.That(pendingLog.ExecutionQuality, Is.EqualTo(900));
                    Assert.That(pendingLog.SignAccepted, Is.True);
                    var report = new PitchGameReport(
                        "daily-ability", 1, 0, 0, 0, 0, 0, 0,
                        abilityMomentCount: 1,
                        abilityMomentTypes: new[] { "movement" });
                    var envelope = new CommandEnvelope<GameCommand>(
                        "ability-consume",
                        restarted.Current.Revision,
                        new ConsumeCommittedPitchResultCommand(
                            "daily-ability", "ability-pitch", 0, "{\"pitch\":1}", report));
                    Assert.That((await restarted.DispatchAsync(envelope)).Status,
                        Is.EqualTo(DispatchStatus.Applied));
                    Assert.That((await restarted.DispatchAsync(envelope)).Status,
                        Is.EqualTo(DispatchStatus.AlreadyApplied));
                }

                using (var replay = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(replay.Current.PitchResume.Metrics.AbilityMomentCount, Is.EqualTo(1));
                    Assert.That(replay.Current.PitchResume.Metrics.AbilityMomentTypes,
                        Is.EqualTo(new[] { "movement" }));
                    Assert.That(replay.Current.PitchResume.CommittedPitch, Is.Null);
                    Assert.That(replay.Current.PitchResume.PitchLog.Count, Is.EqualTo(1));
                    Assert.That(replay.Current.PitchResume.PitchLog[0].PitchId,
                        Is.EqualTo("ability-pitch"));
                    Assert.That(replay.Current.PitchResume.PitchLog[0].SignAccepted, Is.True);
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task CommitPitchPersistenceFailure_DoesNotPublishOrExposeAnimationResult()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "game", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("important_game"), DateTimeOffset.UtcNow));
                await Applied(store, "begin", new BeginPitchSessionCommand(
                    "fault-game", PitchCareerKind.HighSchool, "important", 4, DateTimeOffset.UtcNow));
                var publications = 0;
                store.StatePublished += _ => publications++;
                repository.FailSave = true;

                var result = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "commit-fault",
                    store.Current.Revision,
                    new CommitPitchResultCommand(
                        "fault-game", "pitch-1", 0, "hash",
                        "{\"kernel\":1}", "{\"presentation\":1}", DateTimeOffset.UtcNow,
                        abilityMomentEvidence: AbilityEvidence(null))));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.PitchResume.CommittedPitch, Is.Null);
                Assert.That(publications, Is.Zero);
            }
        }

        [Test]
        public async Task ConsumePitchPersistenceFailure_DoesNotAppendDurableLogOrPublish()
        {
            var repository = new RecordingGameRepository();
            var instant = new DateTimeOffset(2026, 8, 11, 4, 30, 0, TimeSpan.Zero);
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "log-setup", new EnterSetupCommand());
                await Applied(store, "log-start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "log-game", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("important_game"), instant));
                await Applied(store, "log-begin", new BeginPitchSessionCommand(
                    "log-fault-game", PitchCareerKind.HighSchool, "important", 1, instant));
                await Applied(store, "log-commit", new CommitPitchResultCommand(
                    "log-fault-game", "log-pitch", 0, "log-hash",
                    "{\"outcome\":\"ball\"}", "{\"cue\":\"ball\"}", instant,
                    abilityMomentEvidence: AbilityEvidence(
                        null,
                        recommendationAccepted: true)));
                var committed = store.Current;
                Assert.That(committed.PitchResume.PitchLog, Is.Empty);
                var publications = 0;
                store.StatePublished += _ => publications++;
                var command = new CommandEnvelope<GameCommand>(
                    "log-consume",
                    store.Current.Revision,
                    new ConsumeCommittedPitchResultCommand(
                        "log-fault-game",
                        "log-pitch",
                        0,
                        "{\"pitch\":1}",
                        new PitchGameReport(
                            "log-fault-game", 1, 0, 0, 0, 0, 0, 0)));

                repository.FailSave = true;
                Assert.That((await store.DispatchAsync(command)).Status,
                    Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current, Is.SameAs(committed));
                Assert.That(store.Current.PitchResume.CommittedPitch, Is.Not.Null);
                Assert.That(store.Current.PitchResume.PitchLog, Is.Empty);
                Assert.That(publications, Is.Zero);

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(command)).Status,
                    Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.PitchResume.CommittedPitch, Is.Null);
                Assert.That(store.Current.PitchResume.PitchLog.Count, Is.EqualTo(1));
                Assert.That(store.Current.PitchResume.PitchLog[0].SignAccepted, Is.True);
                Assert.That(publications, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task EarlyThreeOutTerminal_SurvivesAfterConsumeAndCompletesExactlyOnce()
        {
            var root = Path.Combine(Path.GetTempPath(), "BaseballTerminalPitch", Guid.NewGuid().ToString("N"));
            var instant = new DateTimeOffset(2026, 8, 11, 3, 0, 0, TimeSpan.Zero);
            try
            {
                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    await Applied(store, "terminal-setup", new EnterSetupCommand());
                    await Applied(store, "terminal-start", new StartHighSchoolCareerCommand(
                        new StartHighSchoolCareerRequest(
                            "seed", "power_prospect", "민서준", "서울", 1)));
                    await Applied(store, "terminal-game-phase", new AdvanceHighSchoolCommand(
                        new HighSchoolAction("important_game"), instant));
                    await Applied(store, "daily-begin", new BeginPitchSessionCommand(
                        "daily-terminal", PitchCareerKind.HighSchool, "important", 6, instant));
                    Assert.That(store.Current.PitchResume.MaximumBatters, Is.EqualTo(6));

                    for (var batter = 0; batter < 3; batter++)
                    {
                        var pitchId = "terminal-pitch-" + batter;
                        var outcome = batter == 0
                            ? PitchOutcome.CalledStrike
                            : batter == 1 ? PitchOutcome.SwingingStrike : PitchOutcome.InPlayOut;
                        var sequencePitch = new PitchSequencePitch(
                            batter == 2 ? PitchType.Slider : PitchType.FourSeam,
                            new PitchZone(1, 1),
                            ZoneIntent.Strike,
                            145,
                            outcome);
                        var sequenceContext = new PlateAppearanceContext(
                            "terminal-pa-" + batter,
                            (ulong)batter,
                            9,
                            batter,
                            batter == 0 ? 1 : 0,
                            0,
                            1,
                            0,
                            900,
                            20);
                        if (batter == 0)
                        {
                            var mismatchedTag = await store.DispatchAsync(
                                new CommandEnvelope<GameCommand>(
                                    "terminal-invalid-tag",
                                    store.Current.Revision,
                                    new CommitPitchResultCommand(
                                        "daily-terminal", pitchId, batter, "bad-hash",
                                        "{\"out\":true}", "{\"cue\":\"out\"}", instant,
                                        sequencePitch: sequencePitch,
                                        sequenceTag: PitchSequenceTag.SpeedLadder,
                                        sequenceContext: sequenceContext,
                                        abilityMomentEvidence: AbilityEvidence(sequencePitch, sequenceContext))));
                            Assert.That(mismatchedTag.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                            Assert.That(mismatchedTag.ErrorCode, Is.EqualTo("pitch.committed_result_invalid"));
                        }
                        await Applied(store, "terminal-commit-" + batter, new CommitPitchResultCommand(
                            "daily-terminal", pitchId, batter, "hash-" + batter,
                            "{\"out\":true}", "{\"cue\":\"out\"}", instant.AddSeconds(batter),
                            sequencePitch: sequencePitch,
                            sequenceTag: batter == 0
                                ? (PitchSequenceTag?)PitchSequenceTag.StealStrike
                                : null,
                            delivery: batter == 0
                                ? new PitchDeliveryMetricState(950, 950, true)
                                : new PitchDeliveryMetricState(500, 500, false),
                            sequenceContext: sequenceContext,
                            abilityMomentEvidence: AbilityEvidence(sequencePitch, sequenceContext)));
                        var report = new PitchGameReport(
                            "daily-terminal", batter + 1, batter + 1, batter + 1,
                            batter + 1, 0, 0, 0,
                            sequenceMasteryCount: 1,
                            expectedDamage: (batter + 1) * 100,
                            actualDamage: 0,
                            recommendationAccepted: batter + 1,
                            directDeliveryCount: 1,
                            deliveryScoreTotal: 950,
                            bestDeliveryScore: 950,
                            perfectDeliveryCount: 1,
                            abilityMomentCount: batter == 2 ? 1 : 0,
                            abilityMomentTypes: batter == 2
                                ? new[] { "movement" }
                                : Array.Empty<string>());
                        await Applied(store, "terminal-consume-" + batter,
                            new ConsumeCommittedPitchResultCommand(
                                "daily-terminal", pitchId, batter + 1,
                                "{\"completedBatters\":" + (batter + 1) + "}",
                                report,
                                sessionCompleted: batter == 2));
                    }

                    Assert.That(store.Current.PitchResume.CompletedBatters, Is.EqualTo(3));
                    Assert.That(store.Current.PitchResume.AwaitingCompletion, Is.True);
                    Assert.That(store.Current.PitchResume.CompletedBatters,
                        Is.LessThan(store.Current.PitchResume.MaximumBatters));
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(restarted.Current.PitchResume.AwaitingCompletion, Is.True);
                    Assert.That(restarted.Current.PitchResume.Metrics.SequenceMasteryTags,
                        Is.EquivalentTo(new[] { PitchSequenceTag.StealStrike }));
                    Assert.That(restarted.Current.PitchResume.Metrics.DirectDeliveryCount, Is.EqualTo(1));
                    Assert.That(restarted.Current.PitchResume.Metrics.PerfectDeliveryCount, Is.EqualTo(1));
                    Assert.That(restarted.Current.PitchResume.Metrics.AverageDeliveryScore, Is.EqualTo(950));
                    Assert.That(restarted.Current.PitchResume.Metrics.AbilityMomentCount, Is.EqualTo(1));
                    Assert.That(restarted.Current.PitchResume.Metrics.AbilityMomentTypes,
                        Is.EqualTo(new[] { "movement" }));
                    var abandon = await restarted.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "terminal-abandon", restarted.Current.Revision,
                        new AbandonPitchSessionCommand("daily-terminal")));
                    Assert.That(abandon.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(abandon.ErrorCode, Is.EqualTo("pitch.completion_required"));
                    var suspend = await restarted.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "terminal-suspend", restarted.Current.Revision,
                        new SuspendPitchSessionCommand("daily-terminal")));
                    Assert.That(suspend.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(suspend.ErrorCode, Is.EqualTo("pitch.completion_required"));

                    var report = restarted.Current.PitchResume.AccumulatedReport;
                    var envelope = new CommandEnvelope<GameCommand>(
                        "terminal-complete",
                        restarted.Current.Revision,
                        new CompletePitchSessionCommand(report, instant.AddMinutes(1)));
                    var first = await restarted.DispatchAsync(envelope);
                    var duplicate = await restarted.DispatchAsync(envelope);

                    Assert.That(first.Status, Is.EqualTo(DispatchStatus.Applied));
                    Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.AlreadyApplied));
                    Assert.That(restarted.Current.PitchResume, Is.Null);
                    Assert.That(restarted.Current.PendingPitchCompletion.Report.Batters, Is.EqualTo(3));
                    Assert.That(restarted.Current.HighSchool.Performance.ImportantGames,
                        Is.EqualTo(1));
                    Assert.That(restarted.Current.Meta.Achievements.Unlocked,
                        Does.Contain(AchievementIds.PerfectDelivery));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task DailyInningCommands_AreRetiredWhileLegacyStateRoundTripsAndCanBeCleared()
        {
            var root = Path.Combine(
                Path.GetTempPath(),
                "BaseballRetiredDaily",
                Guid.NewGuid().ToString("N"));
            var instant = new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero);
            const string rewardId = "daily-inning:20260811";
            try
            {
                var legacyBest = new PitchGameReport(
                    "legacy-daily", 3, 1, 3, 1, 0, 0, 0);
                var legacyDaily = new DailyStreakState(
                    "20260811",
                    "20260811",
                    1,
                    1,
                    new LegacyDailyInningData(
                        "20260811",
                        2,
                        913,
                        legacyBest,
                        "legacy-daily-scenario",
                        "legacy-daily-seed"));
                var initial = GameSaveAggregate.Initial("install-a").Commit(
                    "legacy-daily-fixture",
                    stage: ApplicationStage.HighSchool,
                    highSchool: FakeHighSchoolPort.HighSchool(),
                    meta: MetaProgressState.Initial.With(
                        soulBalance: 5,
                        soulLifetimeEarned: 5,
                        creditedRewardIds: new[] { rewardId },
                        daily: legacyDaily),
                    pitchResume: new PitchResumeState(
                        legacyBest.GameId,
                        PitchCareerKind.Daily,
                        "daily:20260811",
                        "legacy-daily-scenario",
                        "legacy-daily-seed",
                        6,
                        1,
                        "{\"legacy\":true}",
                        null,
                        legacyBest,
                        consumedPitchIds: new[] { "legacy-pitch" },
                        awaitingCompletion: true));
                using (var repository = Repository(root))
                {
                    await repository.SaveAsync(initial, initial.Revision);
                }

                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(store.Current.Meta.Daily.DailyInning.AttemptCount, Is.EqualTo(2));
                    Assert.That(store.Current.Meta.Daily.DailyInning.BestScore, Is.EqualTo(913));
                    Assert.That(store.Current.Meta.Daily.DailyInning.BestReport.GameId,
                        Is.EqualTo("legacy-daily"));
                    Assert.That(store.Current.Meta.Daily.DailyInning.ScenarioId,
                        Is.EqualTo("legacy-daily-scenario"));
                    Assert.That(store.Current.Meta.CreditedRewardIds, Does.Contain(rewardId));
                    var revision = store.Current.Revision;
                    var completion = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "retired-complete",
                        revision,
                        new CompletePitchSessionCommand(legacyBest, instant)));
                    Assert.That(completion.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(completion.ErrorCode, Is.EqualTo("daily.retired"));
                    Assert.That(store.Current.Revision, Is.EqualTo(revision));

                    await Applied(store, "retired-clear",
                        new AbandonPitchSessionCommand("legacy-daily"));
                    Assert.That(store.Current.PitchResume, Is.Null);
                    Assert.That(NextActionPlanner.ResolveCoreProgress(store.Current).Route,
                        Is.EqualTo("high-school"));
                    Assert.That(ReturnPlanRules.DestinationForLegacyRoute("daily-inning"),
                        Is.EqualTo(ReturnPlanDestination.HighSchool));
                    Assert.That(WeeklyProgramCommandFactory.Eligibility(store.Current)
                        .DailyInningUnlocked, Is.False);

                    foreach (var command in new GameCommand[]
                             {
                                 new BeginPitchSessionCommand(
                                     "new-daily", PitchCareerKind.Daily, "daily", 1,
                                     instant.AddMinutes(1)),
                                 new SetReturnPlanCommand(ReturnPlanState.Create(
                                     "옛 일일 계획",
                                     "호환을 위해 읽기만 합니다.",
                                     ReturnPlanDestination.DailyInning,
                                     "legacy_daily")),
                                 new RecordWeeklyProgressCommand(
                                     WeeklyTaskKinds.DailyInningCompleted,
                                     1,
                                     "retired-weekly",
                                     instant.AddMinutes(1),
                                     false)
                             })
                    {
                        revision = store.Current.Revision;
                        var rejected = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                            "retired-command-" + command.GetType().Name,
                            revision,
                            command));
                        Assert.That(rejected.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                        Assert.That(rejected.ErrorCode, Is.EqualTo("daily.retired"));
                        Assert.That(store.Current.Revision, Is.EqualTo(revision));
                    }
                    Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(5));
                    Assert.That(store.Current.Meta.Daily.DailyInning.AttemptCount, Is.EqualTo(2));
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(restarted.Current.PitchResume, Is.Null);
                    Assert.That(restarted.Current.Meta.Daily.DailyInning.AttemptCount, Is.EqualTo(2));
                    Assert.That(restarted.Current.Meta.Daily.DailyInning.BestScore, Is.EqualTo(913));
                    Assert.That(restarted.Current.Meta.CreditedRewardIds,
                        Is.EqualTo(new[] { rewardId }));
                    Assert.That(restarted.Current.Meta.SoulBalance, Is.EqualTo(5));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task MaximumPitchTerminal_SurvivesRestartAndCompletesWithoutAnotherPitch()
        {
            var root = Path.Combine(Path.GetTempPath(), "BaseballPitchCap", Guid.NewGuid().ToString("N"));
            var instant = new DateTimeOffset(2026, 8, 11, 3, 0, 0, TimeSpan.Zero);
            const string gameId = "daily-pitch-cap";
            try
            {
                var scenario = PitchScenarioFactory.Fallback(
                    "pitch-cap-scenario",
                    new PitcherRatingsReadModel(50, 50, 50, 50),
                    "오늘의 투수",
                    1);
                var highSchool = FakeHighSchoolPort.HighSchool(
                    phase: HighSchoolPhase.ImportantGame,
                    careerId: "hs-pitch-cap");
                var initial = new GameSaveAggregate(
                    GameSaveAggregate.CurrentAggregateVersion,
                    0,
                    "install-a",
                    ApplicationStage.HighSchool,
                    highSchool,
                    null,
                    MetaProgressState.Initial,
                    new PitchResumeState(
                        gameId,
                        PitchCareerKind.HighSchool,
                        highSchool.CareerId,
                        scenario.ScenarioId,
                        "17",
                        scenario.MaximumBatters,
                        scenario: scenario),
                    null,
                    Array.Empty<string>());
                using (var repository = Repository(root))
                {
                    await repository.SaveAsync(initial, initial.Revision);
                }

                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(store.Current.PitchResume.Scenario.MaximumPitches, Is.EqualTo(12));
                    for (var pitch = 1; pitch <= 12; pitch++)
                    {
                        var pitchId = "cap-pitch-" + pitch;
                        await Applied(store, "cap-commit-" + pitch,
                            new CommitPitchResultCommand(
                                gameId, pitchId, 0, "hash-" + pitch,
                                "{\"foul\":true}", "{\"cue\":\"foul\"}",
                                instant.AddSeconds(pitch),
                                abilityMomentEvidence: AbilityEvidence(null)));
                        await Applied(store, "cap-consume-" + pitch,
                            new ConsumeCommittedPitchResultCommand(
                                gameId,
                                pitchId,
                                0,
                                "{\"pitch\":" + pitch + "}",
                                new PitchGameReport(gameId, pitch, 0, 0, 0, 0, 0, 0),
                                sessionCompleted: pitch == 12));
                    }
                    Assert.That(store.Current.PitchResume.AwaitingCompletion, Is.True);
                    Assert.That(store.Current.PitchResume.CompletedBatters, Is.Zero);
                    Assert.That(store.Current.PitchResume.PitchLog.Count, Is.EqualTo(12));
                    Assert.That(store.Current.PitchResume.PitchLog.Select(value => value.PitchNumber),
                        Is.EqualTo(Enumerable.Range(1, 12)));
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
                {
                    Assert.That(restarted.Current.PitchResume.AwaitingCompletion, Is.True);
                    Assert.That(restarted.Current.PitchResume.ConsumedPitchIds.Count, Is.EqualTo(12));
                    var report = restarted.Current.PitchResume.AccumulatedReport;
                    var envelope = new CommandEnvelope<GameCommand>(
                        "cap-complete",
                        restarted.Current.Revision,
                        new CompletePitchSessionCommand(report, instant.AddMinutes(1)));
                    Assert.That((await restarted.DispatchAsync(envelope)).Status,
                        Is.EqualTo(DispatchStatus.Applied));
                    Assert.That((await restarted.DispatchAsync(envelope)).Status,
                        Is.EqualTo(DispatchStatus.AlreadyApplied));
                    Assert.That(restarted.Current.PitchResume, Is.Null);
                    Assert.That(restarted.Current.PendingPitchCompletion.Report.Pitches, Is.EqualTo(12));
                    Assert.That(restarted.Current.PendingPitchCompletion.PitchLog.Count, Is.EqualTo(12));
                    Assert.That(restarted.Current.PendingPitchCompletion.PitchLog.Last().PitchId,
                        Is.EqualTo("cap-pitch-12"));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void PitchLogValidator_RejectsMalformedWireEvidence()
        {
            var highSchool = FakeHighSchoolPort.HighSchool(
                phase: HighSchoolPhase.ImportantGame,
                careerId: "hs-log-validator");
            var scenario = PitchScenarioFactory.Fallback(
                "log-validator",
                highSchool.Ratings,
                highSchool.PlayerName,
                1);
            PitchLogEntryState Entry(string outcome) => new PitchLogEntryState(
                "pitch-1", 0, 1, "four_seam", 1, 1, "strike", "normal",
                0, 0, 4, -3, 1450, 20, 80, 900, outcome, true, 1);
            GameSaveAggregate Aggregate(PitchLogEntryState entry) =>
                GameSaveAggregate.Initial("install-a").Commit(
                    "log-fixture",
                    stage: ApplicationStage.HighSchool,
                    highSchool: highSchool,
                    pitchResume: new PitchResumeState(
                        "log-game",
                        PitchCareerKind.HighSchool,
                        highSchool.CareerId,
                        scenario.ScenarioId,
                        "1",
                        scenario.MaximumBatters,
                        scenario: scenario,
                        consumedPitchIds: new[] { "pitch-1" },
                        pitchLog: new[] { entry }));

            var valid = Aggregate(Entry("called_strike"));
            Assert.That(new GameSaveValidator().Validate(valid).IsValid, Is.True);
            var invalid = new GameSaveValidator().Validate(Aggregate(Entry("invented_outcome")));
            Assert.That(invalid.IsValid, Is.False);
            Assert.That(invalid.Errors, Does.Contain("aggregate.pitch_log"));

            var legacyJson = JObject.Parse(JsonConvert.SerializeObject(valid));
            ((JObject)legacyJson["PitchResume"]).Remove("PitchLog");
            var legacy = legacyJson.ToObject<GameSaveAggregate>();
            Assert.That(legacy.PitchResume.PitchLog, Is.Empty);
            Assert.That(legacy.PitchResume.ConsumedPitchIds.Count, Is.EqualTo(1));
            Assert.That(new GameSaveValidator().Validate(legacy).IsValid, Is.True);
        }

        [Test]
        public async Task PersistenceFailure_DoesNotPublishFlowTransition()
        {
            var repository = new RecordingGameRepository { FailSave = true };
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var published = 0;
                store.StatePublished += _ => published++;

                var result = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "setup", 0, new EnterSetupCommand()));

                Assert.That(result.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Opening));
                Assert.That(store.Current.Revision, Is.Zero);
                Assert.That(published, Is.Zero);
            }
        }

        [Test]
        public async Task CustomRebirth_SaveFailureThenRestartKeepsSetupAndStartsEditedCareer()
        {
            var repository = new RecordingGameRepository();
            var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            GameSaveAggregate saved;
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "draft", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "undrafted"),
                    instant));
                var signature = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0];
                await Applied(store, "archive", new FinalizeHighSchoolLegacyCommand(
                    Array.Empty<string>(), signature.Id,
                    instant.AddMinutes(5)));
                var earned = store.Current.Meta.SoulBalance;
                var beforeRebirth = store.Current;
                var published = 0;
                store.StatePublished += _ => published++;
                var rebirth = new CommandEnvelope<GameCommand>(
                    "rebirth",
                    beforeRebirth.Revision,
                    new BeginRebirthCommand(instant.AddMinutes(6)));

                repository.FailSave = true;
                var failed = await store.DispatchAsync(rebirth);
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current, Is.SameAs(beforeRebirth));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Legacy));
                Assert.That(store.Current.HighSchool, Is.Not.Null);
                Assert.That(store.Current.Meta.LifeNumber, Is.EqualTo(1));
                Assert.That(published, Is.Zero);

                repository.FailSave = false;
                Assert.That((await store.DispatchAsync(rebirth)).Status,
                    Is.EqualTo(DispatchStatus.Applied));

                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Setup));
                Assert.That(store.Current.HighSchool, Is.Null);
                Assert.That(store.Current.Pro, Is.Null);
                Assert.That(store.Current.Meta.LifeNumber, Is.EqualTo(2));
                Assert.That(store.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(earned).And.GreaterThan(0));
                Assert.That(store.Current.Meta.InheritedMemories, Is.Empty);
                Assert.That(store.Current.Meta.EquippedSignatureLegacyId, Is.EqualTo(signature.Id));
                Assert.That(NextActionPlanner.ResolveCoreProgress(store.Current).Route,
                    Is.EqualTo("setup"));
                saved = repository.Saved;
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    saved.Revision,
                    instant.AddMinutes(6),
                    new string('d', 64),
                    saved));
            var highSchool = new FakeHighSchoolPort();
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository, highSchool, new FakeProPort(), "install-a"))
            {
                Assert.That(restarted.Current.Stage, Is.EqualTo(ApplicationStage.Setup));
                Assert.That(restarted.Current.HighSchool, Is.Null);
                Assert.That(restarted.Current.Meta.LifeNumber, Is.EqualTo(2));
                Assert.That(restarted.Current.Meta.LifeArchive.Count, Is.EqualTo(1));

                await Applied(restarted, "custom-start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest(
                        "custom-seed",
                        "precision_commander",
                        "고태윤",
                        "대전",
                        2,
                        difficulty: "challenging")));

                Assert.That(restarted.Current.Stage, Is.EqualTo(ApplicationStage.HighSchool));
                Assert.That(restarted.Current.HighSchool.LifeNumber, Is.EqualTo(2));
                Assert.That(restarted.Current.HighSchool.PresetId,
                    Is.EqualTo("precision_commander"));
                Assert.That(restarted.Current.HighSchool.PlayerName, Is.EqualTo("고태윤"));
                Assert.That(restarted.Current.HighSchool.Difficulty, Is.EqualTo("challenging"));
                Assert.That(highSchool.LastStartRequest.SignatureLegacyId,
                    Is.EqualTo(restarted.Current.Meta.EquippedSignatureLegacyId));
                Assert.That(restarted.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task FinalizeSignatureLegacy_SelectsAndArchivesAtomicallyWithoutDoubleReward()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 4, 0, 0, TimeSpan.Zero);
            var highSchool = FakeHighSchoolPort.HighSchool(
                phase: HighSchoolPhase.Legacy,
                legacySelectionMode: LegacySelectionMode.SignatureLegacy,
                signatureLegacyChoices: new[]
                {
                    new CareerChoiceReadModel(
                        "command_map", "미트 끝의 지도", "원하는 곳에 공을 놓던 궤적")
                });
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                4,
                "install-a",
                ApplicationStage.Legacy,
                highSchool,
                null,
                MetaProgressState.Initial,
                null,
                null,
                Array.Empty<string>());
            var repository = new RecordingGameRepository
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.LoadedCanonical,
                    new SaveEnvelope<GameSaveAggregate>(
                        SaveSchema.Name,
                        SaveSchema.Version,
                        aggregate.Revision,
                        instant,
                        new string('c', 64),
                        aggregate))
            };

            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var mixed = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "legacy-mixed",
                    store.Current.Revision,
                    new FinalizeHighSchoolLegacyCommand(
                        new[] { "catcher_notebook" }, "command_map", instant)));
                Assert.That(mixed.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(mixed.ErrorCode, Is.EqualTo("legacy.selection_invalid"));

                var envelope = new CommandEnvelope<GameCommand>(
                    "legacy-finalize",
                    store.Current.Revision,
                    new FinalizeHighSchoolLegacyCommand(
                        Array.Empty<string>(), "command_map", instant));
                repository.FailSave = true;
                var failed = await store.DispatchAsync(envelope);
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.HighSchool.Phase, Is.EqualTo(HighSchoolPhase.Legacy));
                Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                Assert.That(store.Current.Meta.SoulBalance, Is.Zero);

                repository.FailSave = false;
                var applied = await store.DispatchAsync(envelope);
                var balance = store.Current.Meta.SoulBalance;
                var duplicate = await store.DispatchAsync(envelope);

                Assert.That(applied.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.AlreadyApplied));
                Assert.That(store.Current.HighSchool.Phase, Is.EqualTo(HighSchoolPhase.Completed));
                Assert.That(store.Current.HighSchool.SelectedSignatureLegacyId,
                    Is.EqualTo("command_map"));
                Assert.That(store.Current.Meta.LifeArchive.Count, Is.EqualTo(1));
                Assert.That(store.Current.Meta.LifeArchive[0].PlayerLegacy.Title,
                    Is.EqualTo("자기 공을 남긴 투수"));
                Assert.That(store.Current.Meta.LifeArchive[0].PlayerLegacy.DefiningMoment,
                    Is.EqualTo("원하는 곳에 공을 놓던 궤적"));
                Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(balance).And.GreaterThan(0));
                Assert.That(store.Current.Meta.UnlockedSignatureLegacyIds,
                    Is.EquivalentTo(new[] { "command_map" }));
                Assert.That(store.Current.Meta.EquippedSignatureLegacyId,
                    Is.EqualTo("command_map"));
                Assert.That(store.Current.Meta.InheritedMemories, Is.Empty);
            }
        }

        [Test]
        public async Task TutorialPitch_UsesExactScenarioPersistsCommitAndNeverChangesCareerResults()
        {
            var root = Path.Combine(
                Path.GetTempPath(),
                "BaseballTutorialPitch",
                Guid.NewGuid().ToString("N"));
            var instant = new DateTimeOffset(2026, 8, 11, 2, 0, 0, TimeSpan.Zero);
            string firstSessionSeed;
            string careerSeed;
            string coreStateJson;
            ulong coreRevision;
            try
            {
                using (var store = await GameApplicationStore.OpenAsync(
                           Repository(root),
                           new CoreHighSchoolCareerPort(),
                           new FakeProPort(),
                           "tutorial-install"))
                {
                    await Applied(store, "tutorial-setup", new EnterSetupCommand());
                    await Applied(store, "tutorial-start", new StartHighSchoolCareerCommand(
                        new StartHighSchoolCareerRequest(
                            "12345", "power_prospect", "민서준", "서울", 1)));

                    var blocked = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "tutorial-skip",
                        store.Current.Revision,
                        new AdvanceHighSchoolCommand(
                            new HighSchoolAction("complete_prologue"), instant)));
                    Assert.That(blocked.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(blocked.ErrorCode, Is.EqualTo("high_school.tutorial_required"));

                    careerSeed = store.Current.HighSchool.NextSeed;
                    coreStateJson = store.Current.HighSchool.CoreStateJson;
                    coreRevision = store.Current.HighSchool.CoreRevision;
                    await Applied(store, "tutorial-begin", new BeginPitchSessionCommand(
                        "tutorial-game", PitchCareerKind.Tutorial, "tutorial", 18, instant));
                    var resume = store.Current.PitchResume;
                    firstSessionSeed = resume.SessionSeed;
                    Assert.That(firstSessionSeed, Is.EqualTo(careerSeed));
                    Assert.That(store.Current.HighSchool.NextSeed, Is.EqualTo(careerSeed));
                    Assert.That(store.Current.HighSchool.CoreRevision, Is.EqualTo(coreRevision));
                    Assert.That(store.Current.HighSchool.CoreStateJson, Is.EqualTo(coreStateJson));
                    Assert.That(store.Current.HighSchool.TutorialAttemptCount, Is.EqualTo(1));
                    Assert.That(resume.CareerKind, Is.EqualTo(PitchCareerKind.Tutorial));
                    Assert.That(resume.Scenario.ScenarioId,
                        Is.EqualTo("hs-bullpen-" + store.Current.HighSchool.CareerId));
                    Assert.That(resume.Scenario.Headline, Is.EqualTo("첫 불펜"));
                    Assert.That(resume.Scenario.Detail,
                        Is.EqualTo("기록에 남지 않는 연습 한 타석입니다. 마음껏 던져 보세요."));
                    Assert.That(resume.MaximumBatters, Is.EqualTo(2));
                    Assert.That(resume.Scenario.MaximumPitches, Is.EqualTo(8));
                    Assert.That(resume.Scenario.Lineup.Count, Is.EqualTo(2));
                    Assert.That(resume.Scenario.Lineup[0].Name, Is.EqualTo("연습 타자"));
                    Assert.That(resume.Scenario.Lineup[1].Name, Is.EqualTo("연습 타자 B"));
                    Assert.That(resume.Scenario.Scouting.ChaseTendency, Is.EqualTo(45));
                    Assert.That(resume.Scenario.Scouting.Reliability, Is.EqualTo(100));
                    Assert.That(resume.Scenario.GameState.Park.Name, Is.EqualTo("학교 불펜"));

                    var cannotAbandon = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "tutorial-abandon",
                        store.Current.Revision,
                        new AbandonPitchSessionCommand("tutorial-game")));
                    Assert.That(cannotAbandon.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(cannotAbandon.ErrorCode,
                        Is.EqualTo("pitch.tutorial_cannot_abandon"));

                    var cannotSuspend = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                        "tutorial-suspend",
                        store.Current.Revision,
                        new SuspendPitchSessionCommand("tutorial-game")));
                    Assert.That(cannotSuspend.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                    Assert.That(cannotSuspend.ErrorCode,
                        Is.EqualTo("pitch.tutorial_cannot_suspend"));

                    await Applied(store, "tutorial-commit-0", new CommitPitchResultCommand(
                        "tutorial-game", "tutorial-pitch-0", 0, "tutorial-hash-0",
                        "{\"outcome\":\"strikeout\"}", "{\"cue\":\"strikeout\"}", instant,
                        abilityMomentEvidence: AbilityEvidence(null)));
                }

                using (var restarted = await GameApplicationStore.OpenAsync(
                           Repository(root),
                           new CoreHighSchoolCareerPort(),
                           new FakeProPort(),
                           "tutorial-install"))
                {
                    Assert.That(restarted.Current.PitchResume.CommittedPitch.PitchId,
                        Is.EqualTo("tutorial-pitch-0"));
                    var firstReport = new PitchGameReport(
                        "tutorial-game", 1, 1, 1, 1, 0, 0, 0);
                    await Applied(restarted, "tutorial-consume-0",
                        new ConsumeCommittedPitchResultCommand(
                            "tutorial-game", "tutorial-pitch-0", 1,
                            "{\"completedBatters\":1}", firstReport));
                    await Applied(restarted, "tutorial-commit-1", new CommitPitchResultCommand(
                        "tutorial-game", "tutorial-pitch-1", 1, "tutorial-hash-1",
                        "{\"outcome\":\"strikeout\"}", "{\"cue\":\"strikeout\"}",
                        instant.AddSeconds(1),
                        abilityMomentEvidence: AbilityEvidence(null)));
                    var finalReport = new PitchGameReport(
                        "tutorial-game", 2, 2, 2, 2, 0, 0, 0);
                    await Applied(restarted, "tutorial-consume-1",
                        new ConsumeCommittedPitchResultCommand(
                            "tutorial-game", "tutorial-pitch-1", 2,
                            "{\"completedBatters\":2}", finalReport,
                            sessionCompleted: true));

                    await Applied(restarted, "tutorial-retry", new RetryTutorialPitchCommand(
                        "tutorial-game", "tutorial-retry-game", "tutorial",
                        instant.AddSeconds(2)));
                    Assert.That(restarted.Current.PitchResume.SessionSeed,
                        Is.Not.EqualTo(firstSessionSeed));
                    Assert.That(restarted.Current.HighSchool.NextSeed, Is.EqualTo(careerSeed));
                    Assert.That(restarted.Current.HighSchool.CoreRevision, Is.EqualTo(coreRevision));
                    Assert.That(restarted.Current.HighSchool.CoreStateJson, Is.EqualTo(coreStateJson));
                    Assert.That(restarted.Current.HighSchool.TutorialAttemptCount, Is.EqualTo(2));

                    await Applied(restarted, "tutorial-retry-commit-0",
                        new CommitPitchResultCommand(
                            "tutorial-retry-game", "tutorial-retry-pitch-0", 0,
                            "tutorial-retry-hash-0",
                            "{\"outcome\":\"strikeout\"}",
                            "{\"cue\":\"strikeout\"}", instant.AddSeconds(3),
                            abilityMomentEvidence: AbilityEvidence(null)));
                    var retryFirstReport = new PitchGameReport(
                        "tutorial-retry-game", 1, 1, 1, 1, 0, 0, 0);
                    await Applied(restarted, "tutorial-retry-consume-0",
                        new ConsumeCommittedPitchResultCommand(
                            "tutorial-retry-game", "tutorial-retry-pitch-0", 1,
                            "{\"completedBatters\":1}", retryFirstReport));
                    await Applied(restarted, "tutorial-retry-commit-1",
                        new CommitPitchResultCommand(
                            "tutorial-retry-game", "tutorial-retry-pitch-1", 1,
                            "tutorial-retry-hash-1",
                            "{\"outcome\":\"strikeout\"}",
                            "{\"cue\":\"strikeout\"}", instant.AddSeconds(4),
                            abilityMomentEvidence: AbilityEvidence(null)));
                    var retryFinalReport = new PitchGameReport(
                        "tutorial-retry-game", 2, 2, 2, 2, 0, 0, 0);
                    await Applied(restarted, "tutorial-retry-consume-1",
                        new ConsumeCommittedPitchResultCommand(
                            "tutorial-retry-game", "tutorial-retry-pitch-1", 2,
                            "{\"completedBatters\":2}", retryFinalReport,
                            sessionCompleted: true));

                    var complete = new CommandEnvelope<GameCommand>(
                        "tutorial-complete",
                        restarted.Current.Revision,
                        new CompletePitchSessionCommand(retryFinalReport, instant.AddMinutes(1)));
                    var applied = await restarted.DispatchAsync(complete);
                    var duplicate = await restarted.DispatchAsync(complete);
                    Assert.That(applied.Status, Is.EqualTo(DispatchStatus.Applied));
                    Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.AlreadyApplied));
                    Assert.That(restarted.Current.HighSchool.TutorialCompleted, Is.True);
                    Assert.That(restarted.Current.HighSchool.Phase,
                        Is.EqualTo(HighSchoolPhase.SchoolSelection));
                    Assert.That(restarted.Current.HighSchool.NextSeed, Is.Not.EqualTo(careerSeed));
                    Assert.That(restarted.Current.HighSchool.CoreRevision,
                        Is.EqualTo(coreRevision + 1));
                    Assert.That(restarted.Current.HighSchool.CoreStateJson, Is.Not.EqualTo(coreStateJson));
                    Assert.That(restarted.Current.HighSchool.Performance.ImportantGames, Is.Zero);
                    Assert.That(restarted.Current.HighSchool.Performance.Pitches, Is.Zero);
                    Assert.That(restarted.Current.Meta.Daily.CurrentStreak, Is.Zero);
                    Assert.That(restarted.Current.Meta.CompletedGameCount, Is.Zero);
                    Assert.That(restarted.Current.Meta.Achievements.Unlocked, Is.Empty);
                }

                using (var recovered = await GameApplicationStore.OpenAsync(
                           Repository(root),
                           new CoreHighSchoolCareerPort(),
                           new FakeProPort(),
                           "tutorial-install"))
                {
                    Assert.That(recovered.Current.HighSchool.TutorialCompleted, Is.True);
                    Assert.That(recovered.Current.HighSchool.Phase,
                        Is.EqualTo(HighSchoolPhase.SchoolSelection));
                    Assert.That(recovered.Current.HighSchool.SchoolChoices.Count, Is.EqualTo(4));
                    Assert.That(recovered.Current.PendingPitchCompletion, Is.Not.Null);
                    Assert.That(NextActionPlanner.Resolve(recovered.Current).Route,
                        Is.EqualTo("pitch/result"));
                    await Applied(recovered, "tutorial-ack", new AcknowledgePitchResultCommand(
                        recovered.Current.PendingPitchCompletion.CompletionId));
                    Assert.That(NextActionPlanner.Resolve(recovered.Current).Route,
                        Is.EqualTo("high-school/school-selection"));
                    Assert.That(recovered.Current.HighSchool.TutorialAttemptCount, Is.EqualTo(2));
                    Assert.That(recovered.Current.Meta.CompletedGameCount, Is.Zero);
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void CoreAdapter_RestoresOpaqueSnapshotAcrossAdapterInstances()
        {
            var firstAdapter = new CoreHighSchoolCareerPort();
            var started = firstAdapter.Start(new StartHighSchoolCareerRequest(
                "12345",
                "power_prospect",
                "민서준",
                "서울",
                1));
            var schoolSelection = firstAdapter.Apply(
                started,
                new HighSchoolAction("complete_prologue"));

            var restartedAdapter = new CoreHighSchoolCareerPort();
            var training = restartedAdapter.Apply(
                schoolSelection,
                new HighSchoolAction("choose_school", "HanbitTraditional"));

            Assert.That(started.CoreRevision, Is.Zero);
            Assert.That(schoolSelection.Phase, Is.EqualTo(HighSchoolPhase.SchoolSelection));
            Assert.That(training.Phase, Is.EqualTo(HighSchoolPhase.Training));
            Assert.That(training.SchoolId, Is.EqualTo("HanbitTraditional"));
            Assert.That(training.CoreRevision, Is.EqualTo(schoolSelection.CoreRevision + 1));
            Assert.That(training.CoreStateJson, Does.Contain("StateCommitment"));
        }

        [Test]
        public void CoreAdapter_ProjectsChapterScheduleNarrativeAndResultCopyFromOpaqueSnapshot()
        {
            var adapter = new CoreHighSchoolCareerPort();
            var current = adapter.Start(new StartHighSchoolCareerRequest(
                "12345", "power_prospect", "민서준", "서울", 1));

            Assert.That(current.News, Is.Not.Empty);
            Assert.That(current.ChapterProgress.Number, Is.EqualTo(1));
            Assert.That(current.ChapterProgress.Title, Is.Not.Empty);
            Assert.That(current.ScheduleMilestones, Is.Not.Empty);
            Assert.That(current.ScheduleMilestones.Select(value => value.ChapterNumber), Is.Ordered);

            current = adapter.Apply(current, new HighSchoolAction("complete_prologue"));
            current = adapter.Apply(current, new HighSchoolAction(
                "choose_school", current.SchoolChoices[0].Id));
            for (var count = 0; count < 4 && current.Phase == HighSchoolPhase.Training; count++)
            {
                current = adapter.Apply(current, new HighSchoolAction("train", "velocity:standard"));
                Assert.That(current.LastTraining, Is.Not.Null);
                Assert.That(current.LastTraining.Focus, Is.EqualTo("velocity"));
                Assert.That(current.LastTraining.Feedback, Is.Not.Empty);
                Assert.That(current.CoreStateJson, Does.Contain(current.LastTraining.Feedback));
            }

            Assert.That(current.Phase, Is.EqualTo(HighSchoolPhase.Relationship));
            Assert.That(current.CurrentRelationshipEvent, Is.Not.Null);
            Assert.That(current.CurrentRelationshipEvent.Title, Is.Not.Empty);
            Assert.That(current.CurrentRelationshipEvent.Summary, Is.Not.Empty);
            Assert.That(current.CurrentRelationshipEvent.Speaker, Is.Not.Empty);
            Assert.That(current.CurrentRelationshipEvent.Quote, Is.Not.Empty);
            Assert.That(current.CurrentRelationshipEvent.Quote, Does.Not.Contain("{player}"));
            Assert.That(current.RelationshipChoices, Is.Not.Empty);
            Assert.That(current.CoreStateJson,
                Does.Contain(current.CurrentRelationshipEvent.Title));

            current = adapter.Apply(current, new HighSchoolAction(
                "relationship", current.RelationshipChoices[0].Id));
            Assert.That(current.LastRelationship, Is.Not.Null);
            Assert.That(current.LastRelationship.Feedback, Is.Not.Empty);
            Assert.That(current.CoreStateJson, Does.Contain(current.LastRelationship.Feedback));
            Assert.That(current.Phase, Is.EqualTo(HighSchoolPhase.ImportantGame));
            Assert.That(current.CurrentGameScenario, Is.Not.Null);
            Assert.That(current.CurrentGameScenario.Title, Is.Not.Empty);
            Assert.That(current.CurrentGameScenario.Narrative, Is.Not.Empty);
            Assert.That(current.CoreStateJson, Does.Contain(current.CurrentGameScenario.Narrative));

            current = adapter.ApplyPitchResult(current, new PitchGameReport(
                "hs-record-projection", 24, 2, 6, 4, 1, 2, 1));
            var directLine = current.GameLines.Single(value => value.Played);
            Assert.That(directLine.Hits, Is.EqualTo(2),
                "legacy display value remains source-compatible");
            Assert.That(directLine.RecordedHits, Is.EqualTo(2));
            Assert.That(directLine.HomeRuns, Is.Null,
                "a source that did not classify home runs must stay unavailable");
            Assert.That(current.PitchingRecord.Hits, Is.EqualTo(2));
            Assert.That(current.PitchingRecord.HomeRuns, Is.Null);
            Assert.That(current.PitchingRecord.HomeRunsPerNine, Is.Null);
            Assert.That(current.PitchingRecord.FieldingIndependentPitching, Is.Null);
        }

        [Test]
        public void CoreAdapter_ProjectsAuthoritativeFocusByIntensityOutlookMatrix()
        {
            var adapter = new CoreHighSchoolCareerPort();
            var current = adapter.Start(new StartHighSchoolCareerRequest(
                "12345", "breaking_ball_artist", "민서준", "서울", 1));
            current = adapter.Apply(current, new HighSchoolAction("complete_prologue"));
            current = adapter.Apply(current, new HighSchoolAction(
                "choose_school", current.SchoolChoices[0].Id));

            Assert.That(current.Phase, Is.EqualTo(HighSchoolPhase.Training));
            Assert.That(current.TrainingOutlooks.Count, Is.EqualTo(18));
            Assert.That(current.TrainingOutlooks.Select(value =>
                value.FocusId + ":" + value.IntensityId), Is.Unique);

            var light = HighSchoolTrainingOutlookProjection.Resolve(
                current, "breaking_ball", "light");
            var standard = HighSchoolTrainingOutlookProjection.Resolve(
                current, "breaking_ball", "standard");
            var intensive = HighSchoolTrainingOutlookProjection.Resolve(
                current, "breaking_ball", "intensive");
            Assert.That(light, Is.Not.Null);
            Assert.That(standard, Is.Not.Null);
            Assert.That(intensive, Is.Not.Null);
            Assert.That(light.OutlookId, Is.EqualTo("none"));
            Assert.That(light.Summary,
                Is.EqualTo("이대로면 성장 없이 지나갑니다. 피로가 높거나 강도가 약합니다."));
            Assert.That(standard.OutlookId, Is.EqualTo("zero_or_one"));
            Assert.That(standard.Summary,
                Is.EqualTo("+1이 나올 수도, 성장 없이 지날 수도 있습니다."));
            Assert.That(intensive.OutlookId, Is.EqualTo("one"));
            Assert.That(intensive.Summary, Is.EqualTo("+1이 확실한 훈련입니다."));
            Assert.That(HighSchoolTrainingOutlookProjection.Resolve(
                current, "invented_focus", "standard"), Is.Null);
            Assert.That(HighSchoolTrainingOutlookProjection.Resolve(
                current, "breaking_ball", "invented_intensity"), Is.Null);

            var aggregate = GameSaveAggregate.Initial("outlook-install").Commit(
                "outlook-fixture",
                ApplicationStage.HighSchool,
                highSchool: current);
            Assert.That(new GameSaveValidator().Validate(aggregate).IsValid, Is.True);
            var legacyJson = JObject.Parse(JsonConvert.SerializeObject(aggregate));
            ((JObject)legacyJson["HighSchool"]).Remove("TrainingOutlooks");
            var legacy = legacyJson.ToObject<GameSaveAggregate>();
            Assert.That(legacy.HighSchool.TrainingOutlooks, Is.Empty);
            Assert.That(new GameSaveValidator().Validate(legacy).IsValid, Is.True);
        }

        [Test]
        public void CoreTrainingBloom_ProjectsAndRoundTripsWithoutRecalculation()
        {
            var first = new CareerTrainingSnapshot(
                7,
                TrainingFocus.BreakingBall,
                TrainingIntensity.Intensive,
                2,
                15,
                "변화구 끝이 한 단계 열렸습니다.",
                59,
                61,
                44,
                59,
                true,
                TalentAbility.Movement,
                TalentGrade.A,
                true,
                PitchType.Slider);
            var second = new CareerTrainingSnapshot(
                8,
                TrainingFocus.BreakingBall,
                TrainingIntensity.Intensive,
                1,
                15,
                "슬라이더 궤적을 다시 고정했습니다.",
                61,
                62,
                59,
                74,
                true,
                targetPitch: PitchType.Slider);
            var block = new CareerTrainingBlockSnapshot(
                3,
                2,
                TrainingFocus.BreakingBall,
                TrainingIntensity.Intensive,
                PitchType.Slider,
                TrainingBlockStopReason.TalentBloom,
                3,
                30,
                new[] { first, second });

            var flags = BindingFlags.NonPublic | BindingFlags.Static;
            var resultMapper = typeof(CoreHighSchoolCareerPort).GetMethod(
                "TrainingResult", flags);
            var blockMapper = typeof(CoreHighSchoolCareerPort).GetMethod(
                "TrainingBlock", flags);
            Assert.That(resultMapper, Is.Not.Null);
            Assert.That(blockMapper, Is.Not.Null);
            var result = (TrainingResultReadModel)resultMapper.Invoke(null, new object[] { first });
            var projected = (TrainingBlockResultReadModel)blockMapper.Invoke(
                null, new object[] { block });

            Assert.That(result.BloomedAbility, Is.EqualTo("movement"));
            Assert.That(result.BloomedGrade, Is.EqualTo("a"));
            Assert.That(projected.StopReason, Is.EqualTo("talent_bloom"));
            Assert.That(projected.BloomedAbility, Is.EqualTo("movement"));
            Assert.That(projected.BloomedGrade, Is.EqualTo("a"));
            Assert.That(projected.Sessions.Count, Is.EqualTo(2));
            Assert.That(projected.Sessions[0].BloomedAbility, Is.EqualTo("movement"));

            var highSchool = new HighSchoolCareerReadModel(
                "hs-training-bloom",
                1,
                HighSchoolPhase.Training,
                "1",
                1,
                "pitcher",
                "민서준",
                "breaking_ball_artist",
                new PitcherRatingsReadModel(50, 50, 50, 50),
                new CareerPerformanceReadModel(),
                lastTraining: result,
                lastTrainingBlock: projected);
            var aggregate = GameSaveAggregate.Initial("install-a").Commit(
                "training-bloom",
                ApplicationStage.HighSchool,
                highSchool: highSchool);
            var roundTrip = JsonConvert.DeserializeObject<GameSaveAggregate>(
                JsonConvert.SerializeObject(aggregate));
            Assert.That(new GameSaveValidator().Validate(roundTrip).IsValid, Is.True);
            Assert.That(roundTrip.HighSchool.LastTraining.BloomedAbility,
                Is.EqualTo("movement"));
            Assert.That(roundTrip.HighSchool.LastTrainingBlock.BloomedGrade,
                Is.EqualTo("a"));

            var oldJson = JsonConvert.SerializeObject(aggregate)
                .Replace(",\"BloomedAbility\":\"movement\"", string.Empty)
                .Replace(",\"BloomedGrade\":\"a\"", string.Empty);
            var old = JsonConvert.DeserializeObject<GameSaveAggregate>(oldJson);
            Assert.That(new GameSaveValidator().Validate(old).IsValid, Is.True);
            Assert.That(old.HighSchool.LastTraining.BloomedAbility, Is.Null);

            var receiptlessJson = JObject.Parse(JsonConvert.SerializeObject(aggregate));
            var legacyBlock = (JObject)receiptlessJson["HighSchool"]["LastTrainingBlock"];
            legacyBlock.Remove("Sessions");
            legacyBlock.Remove("BloomedAbility");
            legacyBlock.Remove("BloomedGrade");
            var receiptless = receiptlessJson.ToObject<GameSaveAggregate>();
            Assert.That(receiptless.HighSchool.LastTrainingBlock.Sessions, Is.Empty);
            Assert.That(new GameSaveValidator().Validate(receiptless).IsValid, Is.True);
        }

        [Test]
        public async Task TargetedTrainingBlock_SavesBeforePublishAndRestartsWithPerSessionReceipts()
        {
            var adapter = new CoreHighSchoolCareerPort();
            HighSchoolCareerReadModel training = null;
            for (var seed = 1; seed < 10000 && training == null; seed++)
            {
                var candidate = adapter.Start(new StartHighSchoolCareerRequest(
                    seed.ToString(), "breaking_ball_artist", "민서준", "서울", 1));
                candidate = adapter.Apply(candidate, new HighSchoolAction("complete_prologue"));
                candidate = adapter.Apply(candidate, new HighSchoolAction(
                    "choose_school", candidate.SchoolChoices[0].Id));
                if (candidate.ChapterProgress.TrainingsRequired == 3) training = candidate;
            }
            Assert.That(training, Is.Not.Null);
            Assert.That(training.TrainingPitchChoices, Is.Not.Empty);
            var target = training.TrainingPitchChoices[0].Id;
            var initial = GameSaveAggregate.Initial("training-install").Commit(
                "training-fixture", ApplicationStage.HighSchool, highSchool: training);
            var repository = new RecordingGameRepository
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.LoadedCanonical,
                    Envelope(initial))
            };

            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new CoreHighSchoolCareerPort(), new FakeProPort(), "training-install"))
            {
                var published = 0;
                store.StatePublished += _ => published++;
                var command = new CommandEnvelope<GameCommand>(
                    "training-block",
                    store.Current.Revision,
                    new AdvanceHighSchoolCommand(
                        new HighSchoolAction(
                            HighSchoolTrainingActionPayload.BlockAction,
                            HighSchoolTrainingActionPayload.Encode(
                                "breaking_ball", "standard", target)),
                        new DateTimeOffset(2026, 8, 11, 3, 0, 0, TimeSpan.Zero)));

                repository.FailSave = true;
                var failed = await store.DispatchAsync(command);
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.HighSchool.LastTrainingBlock, Is.Null);
                Assert.That(published, Is.Zero);

                repository.FailSave = false;
                var applied = await store.DispatchAsync(command);
                Assert.That(applied.Status, Is.EqualTo(DispatchStatus.Applied), applied.ErrorCode);
                Assert.That(published, Is.EqualTo(1));
                Assert.That(store.Current.HighSchool.LastTrainingBlock.CompletedSessions, Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.LastTrainingBlock.Sessions.Count, Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.LastTrainingBlock.Sessions.Select(value => value.Number),
                    Is.Ordered.And.Unique);
                Assert.That(store.Current.HighSchool.LastTrainingBlock.Sessions.All(value =>
                    value.Focus == "breaking_ball" && value.TargetPitch == target), Is.True);
                Assert.That(repository.Saved, Is.SameAs(store.Current));
            }

            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                Envelope(repository.Saved));
            using (var restarted = await GameApplicationStore.OpenAsync(
                       repository, new CoreHighSchoolCareerPort(), new FakeProPort(), "training-install"))
            {
                Assert.That(restarted.Current.HighSchool.LastTrainingBlock, Is.Not.Null);
                Assert.That(restarted.Current.HighSchool.LastTrainingBlock.Sessions.Count, Is.EqualTo(3));
                Assert.That(restarted.Current.HighSchool.LastTrainingBlock.TargetPitch, Is.EqualTo(target));
            }
        }

        [Test]
        public async Task PledgeDecision_IsDurableAndConsumesCarriedNextRunIntent()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "intent", new SetNextRunIntentCommand(
                    new NextRunIntentState("get_drafted", 1, CoreRunPledgeCatalog.RetryIntentReason)));
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                // Starting a life consumes the old UI suggestion; a pledge decision itself is
                // stored inside the authoritative career read model.
                await Applied(store, "pledge", new ChoosePledgeCommand(
                    "get_drafted",
                    new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)));

                Assert.That(store.Current.HighSchool.PledgeDecided, Is.True);
                Assert.That(store.Current.HighSchool.PledgeId, Is.EqualTo("get_drafted"));
                Assert.That(store.Current.Meta.NextRunIntent, Is.Null);
            }
        }

        [Test]
        public async Task PledgeSelection_RejectsUnknownOrUnofferedIdsFromCoreCatalog()
        {
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(), new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                var projected = RunPledgeRules.Project(store.Current);
                Assert.That(projected.Choices.Count, Is.EqualTo(3));
                Assert.That(projected.Choices.Select(value => value.Id),
                    Is.EqualTo(CoreRunPledgeCatalog.Options(
                        store.Current.HighSchool.CareerId,
                        RunPledgeRules.Context(store.Current.HighSchool)).Select(value => value.Id)));

                var rejected = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "pledge-invalid",
                    store.Current.Revision,
                    new ChoosePledgeCommand(
                        "invented_pledge",
                        new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero))));

                Assert.That(rejected.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(rejected.ErrorCode, Is.EqualTo("pledge.choice_invalid"));
                Assert.That(store.Current.HighSchool.PledgeDecided, Is.False);
            }
        }

        [Test]
        public async Task AchievedPledge_SettlesRewardAndFrozenArchiveExactlyOnceAfterSave()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
                await Applied(store, "intent", new SetNextRunIntentCommand(
                    new NextRunIntentState("get_drafted", 1, CoreRunPledgeCatalog.RetryIntentReason)));
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "pledge", new ChoosePledgeCommand("get_drafted", instant));
                await Applied(store, "draft", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "drafted"), instant.AddMinutes(1)));
                await Applied(store, "pro", new EnterProFromDraftCommand());
                await Applied(store, "sign", new SignProContractCommand());

                var envelope = new CommandEnvelope<GameCommand>(
                    "retire-pledge",
                    store.Current.Revision,
                    new RetireProCareerCommand(instant.AddMinutes(2)));
                repository.FailSave = true;
                var failed = await store.DispatchAsync(envelope);
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                Assert.That(store.Current.Meta.SoulBalance, Is.Zero);

                repository.FailSave = false;
                var retired = await store.DispatchAsync(envelope);
                Assert.That(retired.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That((await store.DispatchAsync(envelope)).Status,
                    Is.EqualTo(DispatchStatus.AlreadyApplied));
                Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(73));
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates.Count, Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates,
                    Has.All.Matches<SignatureLegacyReadModel>(value =>
                        value.EvidenceSummary.StartsWith("프로 통산", StringComparison.Ordinal)));
                var signature = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0];
                var finalize = new CommandEnvelope<GameCommand>(
                    "finalize-pledge",
                    store.Current.Revision,
                    new FinalizeHighSchoolLegacyCommand(
                        Array.Empty<string>(), signature.Id, instant.AddMinutes(3)));
                repository.FailSave = true;
                var finalizeFailed = await store.DispatchAsync(finalize);
                Assert.That(finalizeFailed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                Assert.That(store.Current.Meta.SoulBalance, Is.EqualTo(73));

                repository.FailSave = false;
                var applied = await store.DispatchAsync(finalize);
                var balance = store.Current.Meta.SoulBalance;
                var duplicate = await store.DispatchAsync(finalize);
                var record = store.Current.Meta.LifeArchive.Single();

                Assert.That(applied.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.AlreadyApplied));
                Assert.That(record.PledgeId, Is.EqualTo("get_drafted"));
                Assert.That(record.PledgeTitle, Is.EqualTo("이름이 불린다"));
                Assert.That(record.PledgeTier, Is.EqualTo("safe"));
                Assert.That(record.PledgeRewardPermille, Is.EqualTo(100));
                Assert.That(record.PledgeAchieved, Is.True);
                Assert.That(record.PledgeProgressLine, Is.EqualTo("지명 1/1"));
                Assert.That(record.PledgeProgressRatioPermille, Is.EqualTo(1000));
                Assert.That(record.PledgeRulesVersion,
                    Is.EqualTo(CoreRunPledgeCatalog.CurrentRulesVersion));
                Assert.That(balance, Is.EqualTo(99),
                    "24 HS base × 1.10 pledge plus 73 pro legacy points");
                Assert.That(record.SoulEarned, Is.EqualTo(26),
                    "archive settlement excludes the separately credited pro wallet bonus");
                Assert.That(store.Current.Meta.NextRunIntent, Is.Null,
                    "recap suggestions must never opt the player in automatically");
                Assert.That(record.SuggestedNextRunIntent.PledgeId, Is.Not.EqualTo("get_drafted"));
                Assert.That(record.SuggestedNextRunIntent.PledgeTitle, Is.Not.Empty);
            }
        }

        [Test]
        public async Task MissedPledge_ArchivesProgressAndSuggestsSameGoalForNextLife()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
                await Applied(store, "intent", new SetNextRunIntentCommand(
                    new NextRunIntentState("get_drafted", 1, CoreRunPledgeCatalog.RetryIntentReason)));
                await Applied(store, "setup", new EnterSetupCommand());
                await Applied(store, "start", new StartHighSchoolCareerCommand(
                    new StartHighSchoolCareerRequest("seed", "power_prospect", "민서준", "서울", 1)));
                await Applied(store, "pledge", new ChoosePledgeCommand("get_drafted", instant));
                await Applied(store, "draft", new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "undrafted"), instant.AddMinutes(1)));
                var signature = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0];
                await Applied(store, "archive", new FinalizeHighSchoolLegacyCommand(
                    Array.Empty<string>(), signature.Id, instant.AddMinutes(2)));

                var record = store.Current.Meta.LifeArchive.Single();
                Assert.That(record.PledgeAchieved, Is.False);
                Assert.That(record.PledgeProgressLine, Is.EqualTo("지명 0/1"));
                Assert.That(record.PledgeProgressRatioPermille, Is.Zero);
                Assert.That(store.Current.Meta.NextRunIntent, Is.Null);
                Assert.That(record.SuggestedNextRunIntent.PledgeId, Is.EqualTo("get_drafted"));
                Assert.That(record.SuggestedNextRunIntent.SourceLifeNumber, Is.EqualTo(1));
                Assert.That(record.SuggestedNextRunIntent.Reason,
                    Is.EqualTo(CoreRunPledgeCatalog.RetryIntentReason));

                repository.FailSave = true;
                var failed = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "save-intent", store.Current.Revision,
                    new SetNextRunIntentCommand(record.SuggestedNextRunIntent)));
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Meta.NextRunIntent, Is.Null);
                repository.FailSave = false;
                var saved = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "save-intent", store.Current.Revision,
                    new SetNextRunIntentCommand(record.SuggestedNextRunIntent)));
                Assert.That(saved.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.Meta.NextRunIntent.PledgeId, Is.EqualTo("get_drafted"));
            }
        }

        private static AtomicSaveRepository<GameSaveAggregate> Repository(string root)
        {
            return new AtomicSaveRepository<GameSaveAggregate>(
                new SaveFileLayout(Path.Combine(root, "save")),
                new SystemAtomicFileSystem(),
                new GameSaveValidator(),
                new GameSaveSemanticPriority());
        }

        private static SaveEnvelope<GameSaveAggregate> Envelope(GameSaveAggregate value)
        {
            return new SaveEnvelope<GameSaveAggregate>(
                "baseball.game-save",
                1,
                value.Revision,
                new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                "fixture",
                value);
        }

        private static PitchAbilityMomentEvidence AbilityEvidence(
            PitchAbilityKind? kind,
            bool recommendationAccepted = false)
        {
            var pitchType = kind == PitchAbilityKind.Movement
                ? PitchType.Slider
                : PitchType.FourSeam;
            var outcome = !kind.HasValue
                ? PitchOutcome.Ball
                : kind == PitchAbilityKind.Command
                ? PitchOutcome.CalledStrike
                : kind == PitchAbilityKind.Movement
                    ? PitchOutcome.InPlayOut
                    : PitchOutcome.SwingingStrike;
            return new PitchAbilityMomentEvidence(
                new PitchCall(
                    pitchType,
                    new PitchZone(1, 1),
                    ZoneIntent.Strike,
                    PitchIntensity.Normal),
                new PlateAppearanceContext(
                    "ability-pa", 0, 1, 0, 0, 0, 1, 0, 500, 0),
                outcome,
                new PitchExecution(0, 0, 0, 0, 1450, 0, 0, 900),
                recommendationAccepted);
        }

        private static PitchAbilityMomentEvidence AbilityEvidence(
            PitchSequencePitch pitch,
            PlateAppearanceContext context)
        {
            return new PitchAbilityMomentEvidence(
                new PitchCall(
                    pitch.PitchType,
                    pitch.Zone,
                    pitch.Intent,
                    PitchIntensity.Normal),
                context,
                pitch.Outcome,
                new PitchExecution(0, 0, 0, 0, pitch.ExpectedVelocityKph * 10, 0, 0, 900));
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
            await Applied(store, id + ":commit", new CommitPitchResultCommand(
                resume.GameId,
                pitchId,
                resume.CompletedBatters,
                id + ":hash",
                "{\"outcome\":\"terminal\"}",
                "{\"cue\":\"terminal\"}",
                occurredAt,
                abilityMomentEvidence: AbilityEvidence(null)));
            await Applied(store, id + ":consume", new ConsumeCommittedPitchResultCommand(
                resume.GameId,
                pitchId,
                report.Batters,
                "{\"terminal\":true}",
                report,
                sessionCompleted: true));
        }
    }
}
