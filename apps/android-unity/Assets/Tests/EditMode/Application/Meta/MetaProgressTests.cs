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
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class MetaProgressTests
    {
        [Test]
        public void SeoulDailyStreak_UsesLocalMidnightAndRejectsRollback()
        {
            var beforeMidnight = new DateTimeOffset(2026, 8, 11, 14, 59, 0, TimeSpan.Zero);
            var afterMidnight = beforeMidnight.AddMinutes(2);
            var first = DailyStreakRules.RecordBaseball(DailyStreakState.Empty, beforeMidnight);
            var duplicate = DailyStreakRules.RecordBaseball(first, beforeMidnight.AddSeconds(10));
            var second = DailyStreakRules.RecordBaseball(duplicate, afterMidnight);
            var rollback = DailyStreakRules.RecordBaseball(second, beforeMidnight);

            Assert.That(first.LastBaseballDayKey, Is.EqualTo("20260811"));
            Assert.That(duplicate, Is.SameAs(first));
            Assert.That(second.LastBaseballDayKey, Is.EqualTo("20260812"));
            Assert.That(second.CurrentStreak, Is.EqualTo(2));
            Assert.That(rollback, Is.SameAs(second));
        }

        [Test]
        public void DailyStreak_IsCappedAt366AndPreservesRetiredDailyWireUnchanged()
        {
            var legacy = new LegacyDailyInningData(
                "20260809", 2, 913, null, "legacy-scenario", "legacy-seed");
            var current = new DailyStreakState("20260810", "20260809", 366, 366, legacy);
            var next = DailyStreakRules.RecordBaseball(
                current,
                new DateTimeOffset(2026, 8, 11, 3, 0, 0, TimeSpan.Zero));

            Assert.That(next.CurrentStreak, Is.EqualTo(366));
            Assert.That(next.BestStreak, Is.EqualTo(366));
            Assert.That(next.LastBaseballDayKey, Is.EqualTo("20260811"));
            Assert.That(next.LastDailyInningDayKey, Is.EqualTo("20260809"));
            Assert.That(next.DailyInning, Is.SameAs(legacy));
        }

        [Test]
        public void RetiredDailyWire_RoundTripsRawValuesWithoutExecutableRules()
        {
            var report = new PitchGameReport(
                "daily", 12, 4, 3, 2, 1, 0, 1);
            var legacy = new DailyStreakState(
                "20260811",
                "20260811",
                4,
                7,
                new LegacyDailyInningData(
                    "20260811",
                    2,
                    913,
                    report,
                    "legacy-scenario-wire",
                    "legacy-seed-wire"));
            var meta = MetaProgressState.Initial.With(
                creditedRewardIds: new[] { "daily-inning:20260811" },
                daily: legacy);
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                1,
                "install-a",
                ApplicationStage.Opening,
                null,
                null,
                meta,
                null,
                null,
                Array.Empty<string>());
            Assert.That(new GameSaveValidator().Validate(aggregate).IsValid, Is.True);

            var json = Newtonsoft.Json.JsonConvert.SerializeObject(aggregate);
            var restored = Newtonsoft.Json.JsonConvert.DeserializeObject<GameSaveAggregate>(json);

            Assert.That(restored.Meta.Daily.DailyInning.AttemptCount, Is.EqualTo(2));
            Assert.That(restored.Meta.Daily.DailyInning.BestScore, Is.EqualTo(913));
            Assert.That(restored.Meta.Daily.DailyInning.BestReport.GameId, Is.EqualTo("daily"));
            Assert.That(restored.Meta.Daily.DailyInning.ScenarioId,
                Is.EqualTo("legacy-scenario-wire"));
            Assert.That(restored.Meta.Daily.DailyInning.SessionSeed,
                Is.EqualTo("legacy-seed-wire"));
            Assert.That(restored.Meta.CreditedRewardIds,
                Is.EqualTo(new[] { "daily-inning:20260811" }));
            Assert.That(typeof(PitchScenarioFactory).GetMethod("Daily"), Is.Null);
            Assert.That(typeof(DailyStreakRules).GetMethod("RecordDailyInning"), Is.Null);
            Assert.That(typeof(GameCommand).Assembly.GetType(
                "Baseball.Application.Commands.CompleteDailyInningCommand"), Is.Null);
        }

        [Test]
        public void WeeklyBoard_IsStableRequiresThreeEligibleTasksAndPinsTwoDayGoal()
        {
            var sparse = new WeeklyEligibility(false, 0, 0, false, false, false, false, false);
            var eligible = new WeeklyEligibility(true, 4, 5, true, true, true, true, false);

            var missing = WeeklyProgramRules.Make("2026-W33", "user-a", sparse);
            var first = WeeklyProgramRules.Make("2026-W33", "user-a", eligible);
            var second = WeeklyProgramRules.Make("2026-W33", "user-a", eligible);

            Assert.That(missing, Is.Null);
            Assert.That(first.Tasks, Has.Count.EqualTo(3));
            Assert.That(first.Tasks[0].Kind, Is.EqualTo(WeeklyTaskKinds.PlayedOnTwoDays));
            Assert.That(second.Tasks.Select(value => value.Kind),
                Is.EqualTo(first.Tasks.Select(value => value.Kind)));
        }

        [Test]
        public void WeeklyReceipt_IsExactlyOnceAndTwoDayTaskNeedsDistinctSeoulDays()
        {
            var eligibility = new WeeklyEligibility(true, 4, 5, true, true, true, true, false);
            var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            var current = WeeklyProgramRules.Configure(
                WeeklyProgressState.Empty, eligibility, "user-a", instant);
            current = WeeklyProgramRules.Record(
                current, WeeklyTaskKinds.PlayedOnTwoDays, 1, "receipt-a", instant);
            var duplicate = WeeklyProgramRules.Record(
                current, WeeklyTaskKinds.PlayedOnTwoDays, 1, "receipt-a", instant.AddHours(1));
            var nextDay = WeeklyProgramRules.Record(
                duplicate, WeeklyTaskKinds.PlayedOnTwoDays, 1, "receipt-b", instant.AddDays(1));

            Assert.That(duplicate, Is.SameAs(current));
            Assert.That(current.PlayedDayKeys, Has.Count.EqualTo(1));
            Assert.That(nextDay.PlayedDayKeys, Has.Count.EqualTo(2));
            Assert.That(nextDay.Program.Tasks.Single(value =>
                value.Kind == WeeklyTaskKinds.PlayedOnTwoDays).IsCompleted, Is.True);
        }

        [Test]
        public void WeeklyClaim_IsAtomicWithStampAndRollbackCannotReplaceLaterWeek()
        {
            var tasks = new[]
            {
                new WeeklyTaskState("a", WeeklyTaskKinds.DailyInningCompleted, 1, 1),
                new WeeklyTaskState("b", WeeklyTaskKinds.ChaptersAdvanced, 2, 2),
                new WeeklyTaskState("c", WeeklyTaskKinds.PlayedOnTwoDays, 2, 0)
            };
            var program = new WeeklyProgramState("2026-W34", tasks, new[] { "a", "b" }, false);
            var state = new WeeklyProgressState(program, null, "20260817");
            var claimed = WeeklyProgramRules.Claim(
                state,
                new DateTimeOffset(2026, 8, 18, 1, 0, 0, TimeSpan.Zero));
            var rollback = WeeklyProgramRules.Configure(
                claimed,
                new WeeklyEligibility(true, 4, 5, true, true, true, true, false),
                "user-a",
                new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero));

            Assert.That(claimed.Program.Claimed, Is.True);
            Assert.That(claimed.Stamps, Has.Count.EqualTo(1));
            Assert.That(claimed.Stamps[0].CompletedTaskCount, Is.EqualTo(2));
            Assert.That(rollback, Is.SameAs(claimed));
        }

        [Test]
        public void WeeklyReconcile_KeepsPartialTwoStepGoalWhenOneOpportunityRemains()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            var task = new WeeklyTaskState(
                "2026-W33-important",
                WeeklyTaskKinds.ImportantGamesCompleted,
                2,
                1);
            var program = new WeeklyProgramState(
                "2026-W33",
                new[]
                {
                    task,
                    new WeeklyTaskState("two-days", WeeklyTaskKinds.PlayedOnTwoDays, 2, 0),
                    new WeeklyTaskState("daily", WeeklyTaskKinds.DailyInningCompleted, 1, 0)
                },
                Array.Empty<string>(),
                false);
            var current = new WeeklyProgressState(program, null, "20260810");

            var reconciled = WeeklyProgramRules.Configure(
                current,
                new WeeklyEligibility(true, 1, 0, true, false, false, false, false),
                "user-a",
                instant);

            Assert.That(reconciled.Program.Tasks[0].Kind,
                Is.EqualTo(WeeklyTaskKinds.ImportantGamesCompleted));
            Assert.That(reconciled.Program.Tasks[0].Progress, Is.EqualTo(1));
            Assert.That(reconciled.Program.Tasks.Any(value => string.Equals(
                value.Kind,
                WeeklyTaskKinds.DailyInningCompleted,
                StringComparison.Ordinal)), Is.False);
        }

        [Test]
        public void WeeklyReconcile_ExemptsUnreplaceableRetiredDailyGoalExactlyOnce()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            var program = new WeeklyProgramState(
                "2026-W33",
                new[]
                {
                    new WeeklyTaskState(
                        "2026-W33-daily",
                        WeeklyTaskKinds.DailyInningCompleted,
                        1,
                        0)
                },
                Array.Empty<string>(),
                false);
            var current = new WeeklyProgressState(program, null, "20260810");
            var noPlayableGoals = new WeeklyEligibility(
                false, 0, 0, false, false, false, false, false);

            var reconciled = WeeklyProgramRules.Configure(
                current, noPlayableGoals, "user-a", instant);
            var repeated = WeeklyProgramRules.Configure(
                reconciled, noPlayableGoals, "user-a", instant.AddHours(1));
            var alreadyCompleted = new WeeklyProgressState(
                new WeeklyProgramState(
                    "2026-W33",
                    new[]
                    {
                        new WeeklyTaskState(
                            "2026-W33-daily-complete",
                            WeeklyTaskKinds.DailyInningCompleted,
                            1,
                            1)
                    },
                    new[] { "2026-W33-daily-complete" },
                    false),
                null,
                "20260810");
            var preserved = WeeklyProgramRules.Configure(
                alreadyCompleted, noPlayableGoals, "user-a", instant);

            Assert.That(reconciled.Program.Tasks, Has.Count.EqualTo(1));
            Assert.That(reconciled.Program.Tasks[0].Kind,
                Is.EqualTo(WeeklyTaskKinds.DailyInningCompleted));
            Assert.That(reconciled.Program.Tasks[0].IsCompleted, Is.True);
            Assert.That(reconciled.Program.CompletedTaskIds,
                Is.EqualTo(new[] { "2026-W33-daily" }));
            Assert.That(reconciled.Program.RewardReady, Is.False,
                "A single retired exemption cannot create a weekly reward by itself.");
            Assert.That(repeated.Program.Tasks[0].Progress,
                Is.EqualTo(reconciled.Program.Tasks[0].Progress));
            Assert.That(repeated.Program.CompletedTaskIds,
                Is.EqualTo(reconciled.Program.CompletedTaskIds));
            Assert.That(preserved.Program.Tasks[0].Progress, Is.EqualTo(1));
            Assert.That(preserved.Program.CompletedTaskIds,
                Is.EqualTo(new[] { "2026-W33-daily-complete" }));
        }

        [Test]
        public async Task WeeklyObservation_ConfiguresOnceRejectsClockRollbackAndReconcilesEligibility()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(), new FakeHighSchoolPort(), new FakeProPort(),
                       "install-a"))
            {
                var openingObservation = WeeklyProgramCommandFactory.Observe(store.Current, instant);
                Assert.That(openingObservation, Is.Not.Null);
                var configured = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "weekly-opening", store.Current.Revision, openingObservation));
                Assert.That(configured.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(WeeklyProgramCommandFactory.Observe(
                    store.Current, instant.AddHours(2)), Is.Null);
                Assert.That(WeeklyProgramCommandFactory.Observe(
                    store.Current, instant.AddDays(-7)), Is.Null);

                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "setup", store.Current.Revision, new EnterSetupCommand()));
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "start", store.Current.Revision, new StartHighSchoolCareerCommand(
                        new Baseball.Application.HighSchool.StartHighSchoolCareerRequest(
                            "7", "power_prospect", "민서준", "서울", 1))));

                var activeEligibility = WeeklyProgramCommandFactory.Eligibility(store.Current);
                Assert.That(activeEligibility.HasHighSchoolCareer, Is.True);
                Assert.That(activeEligibility.CanSelectPledge, Is.True);
                var reconcile = WeeklyProgramCommandFactory.Observe(store.Current, instant.AddHours(3));
                Assert.That(reconcile, Is.Not.Null);
                var applied = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "weekly-active", store.Current.Revision, reconcile));
                Assert.That(applied.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(store.Current.Meta.Weekly.Program, Is.Not.Null);
                Assert.That(store.Current.Meta.Weekly.Program.Tasks, Has.Count.EqualTo(3));
                Assert.That(WeeklyProgramCommandFactory.Observe(
                    store.Current, instant.AddHours(4)), Is.Null);
            }
        }

        [Test]
        public void AchievementLedger_PreservesUnknownFutureIdsAndFreshAcknowledgement()
        {
            var first = AchievementRules.Unlock(
                AchievementProgressState.Empty,
                new[] { AchievementIds.FirstDraft, "future_achievement" });
            var duplicate = AchievementRules.Unlock(first, new[] { AchievementIds.FirstDraft });
            var acknowledged = AchievementRules.Acknowledge(duplicate, AchievementIds.FirstDraft);

            Assert.That(first.Unlocked, Does.Contain("future_achievement"));
            Assert.That(duplicate, Is.SameAs(first));
            Assert.That(acknowledged.Unlocked, Has.Count.EqualTo(2));
            Assert.That(acknowledged.Unacknowledged, Is.EquivalentTo(new[] { "future_achievement" }));
        }

        [Test]
        public void PerfectDelivery_UsesNineHundredThresholdAndExcludesAutomaticNeutralInput()
        {
            Assert.That(new PitchDeliveryMetricState(900, 900, true).IsPerfect, Is.True);
            Assert.That(new PitchDeliveryMetricState(899, 1000, true).IsPerfect, Is.False);
            Assert.That(new PitchDeliveryMetricState(1000, 1000, false).IsPerfect, Is.False);

            var automatic = new Baseball.Application.HighSchool.PitchGameReport(
                "auto", 1, 0, 0, 0, 0, 0, 0,
                directDeliveryCount: 0,
                deliveryScoreTotal: 0,
                bestDeliveryScore: 0,
                perfectDeliveryCount: 0);
            var direct = new Baseball.Application.HighSchool.PitchGameReport(
                "direct", 1, 0, 0, 0, 0, 0, 0,
                directDeliveryCount: 1,
                deliveryScoreTotal: 900,
                bestDeliveryScore: 900,
                perfectDeliveryCount: 1);

            Assert.That(AchievementRules.FromPitch(automatic),
                Does.Not.Contain(AchievementIds.PerfectDelivery));
            Assert.That(AchievementRules.FromPitch(direct),
                Does.Contain(AchievementIds.PerfectDelivery));
        }

        [Test]
        public async Task VersionZeroAggregate_MigratesAndPersistsBeforeStoreOpens()
        {
            var repository = new RecordingGameRepository();
            var legacy = new GameSaveAggregate(
                0,
                7,
                "install-a",
                ApplicationStage.Opening,
                null,
                null,
                new MetaProgressState(soulBalance: 23),
                null,
                null,
                Array.Empty<string>());
            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    7,
                    new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                    new string('a', 64),
                    legacy));

            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "ignored"))
            {
                Assert.That(store.WasMigrated, Is.True);
                Assert.That(store.Current.AggregateVersion,
                    Is.EqualTo(GameSaveAggregate.CurrentAggregateVersion));
                Assert.That(store.Current.Revision, Is.EqualTo(11));
                Assert.That(store.Current.Meta.SoulLifetimeEarned, Is.EqualTo(23));
                Assert.That(store.Current.Meta.AutomaticSoulEarned, Is.EqualTo(23));
                Assert.That(store.Current.HasCommandReceipt(GameSaveMigration.VersionZeroReceipt), Is.True);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionOneSettingsReceipt), Is.True);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionTwoAnalyticsReceipt), Is.True);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionThreeCompletedGameCountReceipt), Is.True);
                Assert.That(store.Current.Meta.CompletedGameCount, Is.Zero);
                Assert.That(store.Current.AnalyticsReceipts.Records, Is.Empty);
                Assert.That(store.Current.Settings.SoundEnabled, Is.True);
                Assert.That(repository.SaveCount, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task ExplicitReset_RemovesStateBeforePublishingFreshOpening()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var setup = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "setup", 0, new EnterSetupCommand()));
                Assert.That(setup.Status, Is.EqualTo(DispatchStatus.Applied));
                var publications = 0;
                store.StatePublished += _ => publications++;

                await store.ResetAsync("install-b");

                Assert.That(repository.ResetCount, Is.EqualTo(1));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Opening));
                Assert.That(store.Current.InstallId, Is.EqualTo("install-b"));
                Assert.That(store.Current.Revision, Is.Zero);
                Assert.That(publications, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task ResetFailure_DoesNotCommitIdentityOrPublishFreshState()
        {
            var repository = new RecordingGameRepository { FailReset = true };
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "setup", 0, new EnterSetupCommand()));
                var before = store.Current;
                var identity = "install-a";
                var publications = 0;
                store.StatePublished += _ => publications++;

                Assert.ThrowsAsync<InvalidOperationException>(async () =>
                    await store.ResetAsync(
                        "install-b",
                        (candidate, _) =>
                        {
                            identity = candidate;
                            return Task.CompletedTask;
                        }));

                Assert.That(identity, Is.EqualTo("install-a"));
                Assert.That(store.Current, Is.SameAs(before));
                Assert.That(store.Current.InstallId, Is.EqualTo("install-a"));
                Assert.That(publications, Is.Zero);
            }
        }

        [Test]
        public async Task IdentityCommitFailure_RestoresPriorSaveAndKeepsCurrentState()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "setup", 0, new EnterSetupCommand()));
                var before = store.Current;
                var publications = 0;
                store.StatePublished += _ => publications++;

                var error = Assert.ThrowsAsync<GameResetException>(async () =>
                    await store.ResetAsync(
                        "install-b",
                        (_, __) => Task.FromException(new InvalidOperationException("identity disk full"))));

                Assert.That(error.ErrorCode, Is.EqualTo("reset.identity_commit_failed"));
                Assert.That(repository.ResetCount, Is.EqualTo(1));
                Assert.That(repository.Saved, Is.SameAs(before));
                Assert.That(store.Current, Is.SameAs(before));
                Assert.That(store.Current.InstallId, Is.EqualTo("install-a"));
                Assert.That(publications, Is.Zero);
            }
        }

        [Test]
        public async Task ResumeReconcile_AdoptsOnlyHigherSameInstallRevisionAndPublishesOnce()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "setup", store.Current.Revision, new EnterSetupCommand()));
                var lower = store.Current;
                var higher = lower.Commit(
                    "external-settings",
                    settings: lower.Settings.With(reducedMotionEnabled: true));
                repository.LoadResult = Loaded(higher, 'f');
                var publications = 0;
                store.StatePublished += _ => publications++;

                var adopted = await store.ReconcilePersistedRevisionAsync();
                var same = await store.ReconcilePersistedRevisionAsync();

                Assert.That(adopted, Is.True);
                Assert.That(same, Is.False);
                Assert.That(store.Current, Is.SameAs(higher));
                Assert.That(store.Current.Settings.ReducedMotionEnabled, Is.True);
                Assert.That(publications, Is.EqualTo(1));

                repository.LoadResult = Loaded(lower, 'a');
                var rollback = Assert.ThrowsAsync<GameSaveReconcileException>(async () =>
                    await store.ReconcilePersistedRevisionAsync());
                Assert.That(rollback.ErrorCode, Is.EqualTo("save.resume_revision_rollback"));
                Assert.That(store.Current, Is.SameAs(higher));
                Assert.That(publications, Is.EqualTo(1));

                var otherInstall = new GameSaveAggregate(
                    GameSaveAggregate.CurrentAggregateVersion,
                    higher.Revision + 1,
                    "install-b",
                    higher.Stage,
                    higher.HighSchool,
                    higher.Pro,
                    higher.Meta,
                    higher.PitchResume,
                    higher.PendingPitchCompletion,
                    higher.CommandReceipts,
                    higher.Deleted,
                    higher.Settings,
                    higher.AnalyticsReceipts);
                repository.LoadResult = Loaded(otherInstall, 'b');
                var mismatch = Assert.ThrowsAsync<GameSaveReconcileException>(async () =>
                    await store.ReconcilePersistedRevisionAsync());
                Assert.That(mismatch.ErrorCode, Is.EqualTo("save.resume_install_mismatch"));
                Assert.That(store.Current, Is.SameAs(higher));
                Assert.That(publications, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task Aggregate_RoundTripsAllInterruptedAndMetaStateThroughAtomicEnvelope()
        {
            var root = Path.Combine(Path.GetTempPath(), "BaseballAggregateRoundTrip", Guid.NewGuid().ToString("N"));
            try
            {
                var playerLegacy = new PlayerLegacyState(
                    "자기 공을 남긴 투수",
                    "미트 끝의 지도 · 마지막 이닝",
                    "우리가 만든 공은 다음 마운드에도 남습니다.");
                var signatureCandidates = new[]
                {
                    new SignatureLegacyReadModel(
                        "command_map", "미트 끝의 지도", "원하는 곳에 공을 놓던 궤적",
                        "프로 통산 144경기 312탈삼진", 900),
                    new SignatureLegacyReadModel(
                        "power_imprint", "마운드에 남은 불꽃", "강한 공으로 승부한 감각",
                        "프로 통산 최종 구위 68", 800),
                    new SignatureLegacyReadModel(
                        "battery_promise", "사인 사이의 약속", "포수와 쌓은 믿음",
                        "포수와 쌓은 믿음 82", 700)
                };
                var lifeDetail = new HighSchoolLifeDetailReadModel(
                    new PitcherRatingsReadModel(40, 38, 36, 39),
                    new[] { "탈삼진 머신" },
                    new[] { "1학년 봄 — 첫 공식 경기", "3학년 여름 — 마지막 마운드" },
                    "한도윤",
                    "서지호",
                    "강태오",
                    "차가운 분석가",
                    "command_year",
                    "코스의 해",
                    "제구",
                    new RelationshipResponseTallyReadModel(1, 5, 0),
                    new[]
                    {
                        new TalentGradeReadModel("stuff", "구위", "b", "B등급"),
                        new TalentGradeReadModel("command", "제구", "a", "A등급"),
                        new TalentGradeReadModel("movement", "변화", "c", "C등급"),
                        new TalentGradeReadModel("stamina", "체력", "b", "B등급")
                    },
                    "precision_commander",
                    "정교한 제구형",
                    "challenging",
                    "혹독하게");
                var archive = new LifeArchiveRecord(
                    "life:1:hs-1",
                    1,
                    "민서준",
                    "hs-1",
                    null,
                    "school-a",
                    "새빛고",
                    false,
                    61,
                    new PitcherRatingsReadModel(48, 52, 44, 46),
                    new CareerPerformanceReadModel(),
                    0,
                    0,
                    0,
                    0,
                    12,
                    playerLegacy: playerLegacy,
                    highSchoolDetail: lifeDetail,
                    signatureLegacy: signatureCandidates[0],
                    signatureLegacyCandidates: signatureCandidates,
                    pitches: 128,
                    outs: 27,
                    hits: 5,
                    draftTeamName: "해오름");
                var returnPlan = ReturnPlanState.Create(
                    "이번 선수 이어가기",
                    "다음 훈련이 기다립니다.",
                    ReturnPlanDestination.HighSchool,
                    "high_school_phase",
                    ReturnPlanRules.ReturnExperimentId,
                    "abc123",
                    "20260811",
                    "guided",
                    4);
                var aggregate = GameSaveAggregate.Initial("install-a").Commit(
                    "setup",
                    stage: ApplicationStage.Setup,
                    settings: GameSettingsState.Default.With(
                        autoReleaseEnabled: true,
                        soundEnabled: false,
                        notificationsEnabled: true,
                        highContrastEnabled: true),
                    meta: MetaProgressState.Initial.With(
                        nextRunIntent: new NextRunIntentState("pledge-a", 1, "다음 삶의 목표"),
                        lifeArchive: new[] { archive },
                        returnPlan: returnPlan,
                        returnWelcomeHandled: ReturnPlanRules.MarkWelcomeHandled(
                            returnPlan,
                            new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero))),
                    analyticsReceipts: AnalyticsReceiptRules.Mark(
                        AnalyticsReceiptState.Empty,
                        AnalyticsReceiptRules.Scope("career_started", "hs-1", "life-1"),
                        new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero)));
                using (var repository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(Path.Combine(root, "save")),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                {
                    await repository.SaveAsync(aggregate, aggregate.Revision);
                    var loaded = await repository.LoadAsync();

                    Assert.That(loaded.Status, Is.EqualTo(SaveLoadStatus.LoadedCanonical));
                    Assert.That(loaded.Envelope.Payload.Meta.NextRunIntent.PledgeId, Is.EqualTo("pledge-a"));
                    Assert.That(loaded.Envelope.Payload.Meta.ReturnPlan.Body,
                        Is.EqualTo("다음 훈련이 기다립니다."));
                    Assert.That(loaded.Envelope.Payload.Meta.ReturnPlan.Destination,
                        Is.EqualTo(ReturnPlanDestination.HighSchool));
                    Assert.That(loaded.Envelope.Payload.Meta.ReturnPlan.ExperimentId,
                        Is.EqualTo(ReturnPlanRules.ReturnExperimentId));
                    Assert.That(loaded.Envelope.Payload.Meta.ReturnPlan.ReceiptId, Is.EqualTo("abc123"));
                    Assert.That(loaded.Envelope.Payload.Meta.ReturnWelcomeHandled.DayKey,
                        Is.EqualTo("20260811"));
                    Assert.That(loaded.Envelope.Payload.Meta.LifeArchive.Single().PlayerLegacy.Title,
                        Is.EqualTo(playerLegacy.Title));
                    Assert.That(loaded.Envelope.Payload.Meta.LifeArchive.Single().PlayerLegacy.DefiningMoment,
                        Is.EqualTo(playerLegacy.DefiningMoment));
                    Assert.That(loaded.Envelope.Payload.Meta.LifeArchive.Single().PlayerLegacy.Farewell,
                        Is.EqualTo(playerLegacy.Farewell));
                    var loadedArchive = loaded.Envelope.Payload.Meta.LifeArchive.Single();
                    Assert.That(loadedArchive.SignatureLegacy.EvidenceSummary,
                        Is.EqualTo(signatureCandidates[0].EvidenceSummary));
                    Assert.That(loadedArchive.SignatureLegacyCandidates, Has.Count.EqualTo(3));
                    Assert.That(loadedArchive.HighSchoolDetail.StartingRatings.Command, Is.EqualTo(38));
                    Assert.That(loadedArchive.HighSchoolDetail.Nicknames,
                        Is.EquivalentTo(new[] { "탈삼진 머신" }));
                    Assert.That(loadedArchive.HighSchoolDetail.Chronicle, Has.Count.EqualTo(2));
                    Assert.That(loadedArchive.HighSchoolDetail.CoachName, Is.EqualTo("한도윤"));
                    Assert.That(loadedArchive.HighSchoolDetail.Personality, Is.EqualTo("차가운 분석가"));
                    Assert.That(loadedArchive.HighSchoolDetail.Talents, Has.Count.EqualTo(4));
                    Assert.That(loadedArchive.HighSchoolDetail.PresetTitle, Is.EqualTo("정교한 제구형"));
                    Assert.That(loadedArchive.HighSchoolDetail.DifficultyTitle, Is.EqualTo("혹독하게"));
                    Assert.That(loadedArchive.Pitches, Is.EqualTo(128));
                    Assert.That(loadedArchive.Outs, Is.EqualTo(27));
                    Assert.That(loadedArchive.Hits, Is.EqualTo(5));
                    Assert.That(loadedArchive.DraftTeamName, Is.EqualTo("해오름"));
                    Assert.That(loaded.Envelope.Payload.Settings.AutoReleaseEnabled, Is.True);
                    Assert.That(loaded.Envelope.Payload.Settings.SoundEnabled, Is.False);
                    Assert.That(loaded.Envelope.Payload.Settings.NotificationsEnabled, Is.True);
                    Assert.That(loaded.Envelope.Payload.Settings.HighContrastEnabled, Is.True);
                    Assert.That(loaded.Envelope.Payload.AnalyticsReceipts.Records, Has.Count.EqualTo(1));
                    Assert.That(loaded.Envelope.Payload.HasCommandReceipt("setup"), Is.True);
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public async Task SettingsUpdate_SavesBeforePublishAndFailureKeepsPreviousPreferences()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                Assert.That(store.Current.Settings.AutoReleaseEnabled, Is.False);
                Assert.That(store.Current.Settings.SoundEnabled, Is.True);
                Assert.That(store.Current.Settings.MusicEnabled, Is.True);
                Assert.That(store.Current.Settings.HapticsEnabled, Is.True);
                Assert.That(store.Current.Settings.NotificationsEnabled, Is.False);

                var publications = 0;
                store.StatePublished += _ => publications++;
                var applied = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "settings-1",
                    store.Current.Revision,
                    new UpdateGameSettingsCommand(
                        autoReleaseEnabled: true,
                        soundEnabled: false,
                        hapticsEnabled: false,
                        notificationsEnabled: true,
                        highContrastEnabled: true,
                        reducedMotionEnabled: true)));

                Assert.That(applied.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(repository.Saved.Settings.AutoReleaseEnabled, Is.True);
                Assert.That(store.Current.Settings.SoundEnabled, Is.False);
                Assert.That(store.Current.Settings.MusicEnabled, Is.True);
                Assert.That(store.Current.Settings.HapticsEnabled, Is.False);
                Assert.That(store.Current.Settings.NotificationsEnabled, Is.True);
                Assert.That(store.Current.Settings.HighContrastEnabled, Is.True);
                Assert.That(store.Current.Settings.ReducedMotionEnabled, Is.True);
                Assert.That(publications, Is.EqualTo(1));

                var beforeFailure = store.Current;
                repository.FailSave = true;
                var failed = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "settings-2",
                    store.Current.Revision,
                    new UpdateGameSettingsCommand(musicEnabled: false)));

                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current, Is.SameAs(beforeFailure));
                Assert.That(store.Current.Settings.MusicEnabled, Is.True);
                Assert.That(publications, Is.EqualTo(1));
            }
        }

        [Test]
        public async Task AnalyticsReceipt_PersistsBeforeEmissionBoundaryAndFailureDoesNotMarkOrPublish()
        {
            var repository = new RecordingGameRepository();
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                var scope = AnalyticsReceiptRules.Scope(
                    "career_started", "private-career-id", "life-1");
                Assert.That(scope, Does.Not.Contain("private-career-id"));
                var publications = 0;
                store.StatePublished += _ => publications++;

                var marked = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "analytics-1", store.Current.Revision,
                    new MarkAnalyticsReceiptCommand(
                        scope, new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero))));

                Assert.That(marked.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(repository.Saved.AnalyticsReceipts.Contains(scope), Is.True,
                    "the durable save is the permission boundary for SDK emission");
                Assert.That(store.Current.AnalyticsReceipts.Contains(scope), Is.True);
                Assert.That(publications, Is.EqualTo(1));

                var duplicate = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "analytics-duplicate", store.Current.Revision,
                    new MarkAnalyticsReceiptCommand(
                        scope, new DateTimeOffset(2026, 8, 11, 1, 1, 0, TimeSpan.Zero))));
                Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(publications, Is.EqualTo(1));

                var failedScope = AnalyticsReceiptRules.Scope("draft_result", "hs-1");
                repository.FailSave = true;
                var failed = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "analytics-2", store.Current.Revision,
                    new MarkAnalyticsReceiptCommand(
                        failedScope, new DateTimeOffset(2026, 8, 11, 1, 2, 0, TimeSpan.Zero))));
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.AnalyticsReceipts.Contains(failedScope), Is.False);
                Assert.That(publications, Is.EqualTo(1));
            }
        }

        [Test]
        public void AnalyticsReceipt_IsValidatedDeduplicatedAndPrunedToTheNewestBound()
        {
            var lifetimeScope = AnalyticsReceiptRules.Scope("onboarding_complete", "install-a");
            var current = AnalyticsReceiptRules.Mark(
                AnalyticsReceiptState.Empty,
                lifetimeScope,
                new DateTimeOffset(2026, 8, 10, 0, 0, 0, TimeSpan.Zero));
            var instant = new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero);
            for (var index = 0; index <= AnalyticsReceiptState.MaximumScopedReceipts; index++)
            {
                current = AnalyticsReceiptRules.Mark(
                    current,
                    AnalyticsReceiptRules.Scope("once_event", "scope-" + index),
                    instant.AddSeconds(index),
                    AnalyticsReceiptRetention.Scoped);
            }

            Assert.That(current.Records, Has.Count.EqualTo(
                AnalyticsReceiptState.MaximumScopedReceipts + 1));
            Assert.That(current.Contains(lifetimeScope), Is.True,
                "lifetime receipts must never be displaced by scoped event churn");
            Assert.That(current.Contains(AnalyticsReceiptRules.Scope("once_event", "scope-0")), Is.False);
            Assert.That(current.Contains(AnalyticsReceiptRules.Scope(
                "once_event", "scope-" + AnalyticsReceiptState.MaximumScopedReceipts)), Is.True);
            Assert.That(AnalyticsReceiptRules.IsValid(current), Is.True);
            Assert.That(AnalyticsReceiptRules.IsValidScope("once:invalid:raw email@example.com"), Is.False);
        }

        [Test]
        public async Task VersionOneSettings_MigratesAndResetRestoresProductDefaults()
        {
            var repository = new RecordingGameRepository();
            var versionOne = new GameSaveAggregate(
                1, 4, "install-a", ApplicationStage.Opening,
                null, null, MetaProgressState.Initial, null, null, Array.Empty<string>());
            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    versionOne.Revision,
                    new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                    new string('b', 64),
                    versionOne));

            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "ignored"))
            {
                Assert.That(store.WasMigrated, Is.True);
                Assert.That(store.Current.AggregateVersion,
                    Is.EqualTo(GameSaveAggregate.CurrentAggregateVersion));
                Assert.That(store.Current.Revision, Is.EqualTo(7));
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionOneSettingsReceipt), Is.True);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionTwoAnalyticsReceipt), Is.True);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionThreeCompletedGameCountReceipt), Is.True);

                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "settings",
                    store.Current.Revision,
                    new UpdateGameSettingsCommand(
                        autoReleaseEnabled: true,
                        soundEnabled: false,
                        musicEnabled: false,
                        hapticsEnabled: false,
                        notificationsEnabled: true,
                        highContrastEnabled: true,
                        reducedMotionEnabled: true)));
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "analytics",
                    store.Current.Revision,
                    new MarkAnalyticsReceiptCommand(
                        AnalyticsReceiptRules.Scope("settings_saved", "install-a"),
                        new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero))));
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "return-plan",
                    store.Current.Revision,
                    new SetReturnPlanCommand(ReturnPlanState.Create(
                        "이어가기",
                        "다음 목표가 기다립니다.",
                        ReturnPlanDestination.HighSchool,
                        "high_school_phase",
                        ReturnPlanRules.ReturnExperimentId,
                        "abc123",
                        "20260811",
                        "guided",
                        4))));
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "return-handled",
                    store.Current.Revision,
                    new CompleteReturnPlanInteractionCommand(
                        false,
                        new DateTimeOffset(2026, 8, 11, 0, 1, 0, TimeSpan.Zero))));
                await store.ResetAsync("install-b");

                Assert.That(store.Current.Settings.AutoReleaseEnabled, Is.False);
                Assert.That(store.Current.Settings.SoundEnabled, Is.True);
                Assert.That(store.Current.Settings.MusicEnabled, Is.True);
                Assert.That(store.Current.Settings.HapticsEnabled, Is.True);
                Assert.That(store.Current.Settings.NotificationsEnabled, Is.False);
                Assert.That(store.Current.Settings.HighContrastEnabled, Is.False);
                Assert.That(store.Current.Settings.ReducedMotionEnabled, Is.False);
                Assert.That(store.Current.AnalyticsReceipts.Records, Is.Empty);
                Assert.That(store.Current.Meta.ReturnPlan, Is.Null);
                Assert.That(store.Current.Meta.ReturnWelcomeHandled, Is.Null);
            }
        }

        [Test]
        public async Task VersionTwoAggregate_AddsAnalyticsAndCompletedGamesBeforeOpen()
        {
            var repository = new RecordingGameRepository();
            var versionTwo = new GameSaveAggregate(
                2, 8, "install-a", ApplicationStage.Opening,
                null, null, MetaProgressState.Initial, null, null, Array.Empty<string>());
            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    versionTwo.Revision,
                    new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                    new string('d', 64),
                    versionTwo));

            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "ignored"))
            {
                Assert.That(store.WasMigrated, Is.True);
                Assert.That(store.Current.AggregateVersion,
                    Is.EqualTo(GameSaveAggregate.CurrentAggregateVersion));
                Assert.That(store.Current.Revision, Is.EqualTo(10));
                Assert.That(store.Current.AnalyticsReceipts.Records, Is.Empty);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionTwoAnalyticsReceipt), Is.True);
                Assert.That(store.Current.HasCommandReceipt(
                    GameSaveMigration.VersionThreeCompletedGameCountReceipt), Is.True);
                Assert.That(repository.SaveCount, Is.EqualTo(1));
            }
        }

        [Test]
        public void VersionThreeCompletedGames_UsesConservativeUniqueLowerBoundAndJsonDefaults()
        {
            var performance = new CareerPerformanceReadModel(importantGames: 2);
            var archive = new LifeArchiveRecord(
                "life:1:hs-shared",
                1,
                "민서준",
                "hs-shared",
                null,
                "school-a",
                "새빛고",
                false,
                60,
                new PitcherRatingsReadModel(50, 50, 50, 50),
                performance,
                0,
                0,
                0,
                0,
                10);
            var priorSeason = new ProSeasonLineReadModel(
                1, "team-a", 5, 30, 12, 4, 3);
            var pro = FakeProPort.Copy(
                FakeProPort.Pro(
                    currentSeason: new CareerPerformanceReadModel(importantGames: 3),
                    seasons: new[] { priorSeason }),
                season: 2);
            var legacy = new GameSaveAggregate(
                3,
                9,
                "install-a",
                ApplicationStage.Pro,
                FakeHighSchoolPort.HighSchool(
                    careerId: "hs-shared",
                    performance: performance),
                pro,
                MetaProgressState.Initial.With(
                    lifeArchive: new[] { archive },
                    creditedRewardIds: new[] { "daily-inning:20260811" }),
                null,
                null,
                Array.Empty<string>());

            Assert.That(CompletedGameCountRules.ConservativeMigrationLowerBound(legacy),
                Is.EqualTo(2),
                "HS overlap is counted once; retired Daily and auto-simulated Pro totals are excluded");
            var migration = GameSaveMigration.Upgrade(legacy);

            Assert.That(migration.Aggregate.AggregateVersion,
                Is.EqualTo(GameSaveAggregate.CurrentAggregateVersion));
            Assert.That(migration.Aggregate.Revision, Is.EqualTo(10));
            Assert.That(migration.Aggregate.Meta.CompletedGameCount, Is.EqualTo(2));
            Assert.That(migration.Aggregate.HasCommandReceipt(
                GameSaveMigration.VersionThreeCompletedGameCountReceipt), Is.True);

            var json = Newtonsoft.Json.JsonConvert.SerializeObject(
                new MetaProgressState(completedGameCount: 7));
            var roundTrip = Newtonsoft.Json.JsonConvert.DeserializeObject<MetaProgressState>(json);
            var oldJson = Newtonsoft.Json.JsonConvert.DeserializeObject<MetaProgressState>(
                "{\"lifeNumber\":1}");
            Assert.That(roundTrip.CompletedGameCount, Is.EqualTo(7));
            Assert.That(oldJson.CompletedGameCount, Is.Zero);
            var invalid = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                0,
                "install-a",
                ApplicationStage.Opening,
                null,
                null,
                new MetaProgressState(completedGameCount: -1),
                null,
                null,
                Array.Empty<string>());
            Assert.That(new GameSaveValidator().Validate(invalid).IsValid, Is.False);
        }

        [Test]
        public void VersionThreeCompletedGames_DoesNotEstimateProLifetimeFromPartialLines()
        {
            var direct = new CareerGameLineReadModel(
                2, 8, 12, true, false,
                3, 2, 0, 1, 0, 14, 3, 1, "hold");
            var automatic = new CareerGameLineReadModel(
                2, 9, 13, false, false,
                3, 1, 1, 2, 1, 18, 2, 4, "loss");
            var legacy = new GameSaveAggregate(
                3,
                2,
                "install-a",
                ApplicationStage.Pro,
                null,
                FakeProPort.Pro(
                    currentSeason: new CareerPerformanceReadModel(importantGames: 99),
                    seasons: new[] { new ProSeasonLineReadModel(1, "team-a", 90, 30, 12, 4, 3) },
                    recentGameLines: new[] { automatic, direct, direct }),
                MetaProgressState.Initial,
                null,
                null,
                Array.Empty<string>());

            var migration = GameSaveMigration.Upgrade(legacy).Aggregate;

            Assert.That(migration.Meta.CompletedGameCount, Is.Zero,
                "a current-season direct line is not a complete monotonic lifetime ledger");
        }

        [Test]
        public void VersionOneAndTwoCompletedGames_MigrateVisibleOfficialLowerBoundWithoutDaily()
        {
            foreach (var version in new[] { 1, 2 })
            {
                var legacy = new GameSaveAggregate(
                    version,
                    4,
                    "install-a",
                    ApplicationStage.HighSchool,
                    FakeHighSchoolPort.HighSchool(
                        careerId: "hs-visible",
                        performance: new CareerPerformanceReadModel(importantGames: 2)),
                    null,
                    MetaProgressState.Initial.With(
                        creditedRewardIds: new[] { "daily-inning:20260811" }),
                    null,
                    null,
                    Array.Empty<string>());

                var migrated = GameSaveMigration.Upgrade(legacy).Aggregate;

                Assert.That(migrated.Meta.CompletedGameCount, Is.EqualTo(2));
                Assert.That(migrated.HasCommandReceipt(
                    GameSaveMigration.VersionThreeCompletedGameCountReceipt), Is.True);
            }
        }

        [Test]
        public void VersionTwoArchiveWithoutPlayerLegacy_MigratesAsNullWithoutRegeneration()
        {
            var oldArchive = new LifeArchiveRecord(
                "life:1:hs-1",
                1,
                "민서준",
                "hs-1",
                null,
                "school-a",
                "새빛고",
                false,
                61,
                new PitcherRatingsReadModel(48, 52, 44, 46),
                new CareerPerformanceReadModel(),
                0,
                0,
                0,
                0,
                12);
            var old = new GameSaveAggregate(
                2,
                8,
                "install-a",
                ApplicationStage.BetweenLives,
                null,
                null,
                MetaProgressState.Initial.With(lifeNumber: 2, lifeArchive: new[] { oldArchive }),
                null,
                null,
                Array.Empty<string>());

            var migrated = GameSaveMigration.Upgrade(old);

            Assert.That(migrated.Migrated, Is.True);
            Assert.That(migrated.Aggregate.Meta.LifeArchive.Single().PlayerLegacy, Is.Null);
            Assert.That(migrated.Aggregate.Meta.LifeArchive.Single().HighSchoolDetail, Is.Null);
            Assert.That(migrated.Aggregate.Meta.LifeArchive.Single().SignatureLegacy, Is.Null);
            Assert.That(migrated.Aggregate.Meta.LifeArchive.Single().SignatureLegacyCandidates, Is.Empty);
            Assert.That(new GameSaveValidator().Validate(migrated.Aggregate).IsValid, Is.True);
        }

        [Test]
        public void LegacyArchiveNullHighSchoolPerformance_NormalizesToFrozenZeroRecord()
        {
            var source = new LifeArchiveRecord(
                "life:1:hs-null",
                1,
                "민서준",
                "hs-null",
                null,
                "school-a",
                "새빛고",
                false,
                0,
                new PitcherRatingsReadModel(48, 52, 44, 46),
                new CareerPerformanceReadModel(1, 9, 3, 2, 1, 1, 0),
                0,
                0,
                0,
                0,
                4);
            var wire = Newtonsoft.Json.Linq.JObject.FromObject(source);
            wire["HighSchoolPerformance"] = Newtonsoft.Json.Linq.JValue.CreateNull();

            var restoredRecord = wire.ToObject<LifeArchiveRecord>();
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                5,
                "install-a",
                ApplicationStage.BetweenLives,
                null,
                null,
                MetaProgressState.Initial.With(
                    lifeNumber: 2,
                    lifeArchive: new[] { restoredRecord }),
                null,
                null,
                Array.Empty<string>());

            Assert.That(restoredRecord.HighSchoolPerformance, Is.Not.Null);
            Assert.That(restoredRecord.HighSchoolPerformance.ImportantGames, Is.Zero);
            Assert.That(restoredRecord.HighSchoolPerformance.Pitches, Is.Zero);
            Assert.That(new GameSaveValidator().Validate(aggregate).IsValid, Is.True);

            var json = Newtonsoft.Json.JsonConvert.SerializeObject(aggregate);
            var roundTrip = Newtonsoft.Json.JsonConvert.DeserializeObject<GameSaveAggregate>(json);
            Assert.That(roundTrip.Meta.LifeArchive.Single().HighSchoolPerformance, Is.Not.Null);
            Assert.That(roundTrip.Meta.LifeArchive.Single().HighSchoolPerformance.Strikeouts, Is.Zero);
        }

        [Test]
        public void ReturnPlan_PreparesStableExperimentReceiptAtSeoulDayBoundary()
        {
            var basePlan = ReturnPlanState.Create(
                "이번 선수 이어가기",
                "다음 훈련이 기다립니다.",
                ReturnPlanDestination.HighSchool,
                "high_school_phase");
            var beforeMidnight = new DateTimeOffset(2026, 8, 9, 14, 59, 0, TimeSpan.Zero);
            var first = ReturnPlanRules.PrepareForNextReturn(
                basePlan, "stable-player", 4, beforeMidnight);
            var replay = ReturnPlanRules.PrepareForNextReturn(
                basePlan, "stable-player", 4, beforeMidnight);
            var nextDay = ReturnPlanRules.PrepareForNextReturn(
                basePlan, "stable-player", 4, beforeMidnight.AddMinutes(2));
            var oldRules = ReturnPlanRules.PrepareForNextReturn(
                basePlan, "stable-player", 3, beforeMidnight);

            Assert.That(first.ReceiptId, Is.EqualTo(replay.ReceiptId));
            Assert.That(first.ExperimentVariant, Is.EqualTo(replay.ExperimentVariant));
            Assert.That(first.ExperimentId, Is.EqualTo(ReturnPlanRules.ReturnExperimentId));
            Assert.That(first.SavedDayKey, Is.EqualTo("20260809"));
            Assert.That(first.DevelopmentRulesVersion, Is.EqualTo(4));
            Assert.That(first.NextAction, Is.EqualTo("이 선수 이어서 키우기"));
            Assert.That(first.ContinueTitle, Is.EqualTo("이 선수 이어서 키우기"));
            Assert.That(ReturnPlanRules.ContinueTitle(ReturnPlanDestination.Pro),
                Is.EqualTo("프로 시즌 이어가기"));
            Assert.That(ReturnPlanRules.ContinueTitle(ReturnPlanDestination.DailyInning),
                Is.EqualTo("게임으로 돌아가기"));
            Assert.That(nextDay.SavedDayKey, Is.EqualTo("20260810"));
            Assert.That(nextDay.ReceiptId, Is.Not.EqualTo(first.ReceiptId));
            Assert.That(oldRules.ReceiptId, Is.Not.EqualTo(first.ReceiptId));

            var guided = Enumerable.Range(0, 10000).Count(index =>
                ReturnPlanRules.ExperimentVariant("player-" + index) ==
                ReturnExperimentVariant.Guided);
            Assert.That(guided, Is.InRange(4800, 5200));
        }

        [Test]
        public async Task ReturnPlan_PrepareAndColdWarmReceiptAreSaveBeforePublishExactlyOnce()
        {
            var repository = new RecordingGameRepository();
            var instant = new DateTimeOffset(2026, 8, 9, 1, 0, 0, TimeSpan.Zero);
            using (var emptyStore = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "install-a"))
            {
                Assert.That(ReturnPlanRules.IsEligible(0), Is.False);
                var ineligible = await emptyStore.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "plan-ineligible", emptyStore.Current.Revision,
                    new PrepareReturnPlanCommand(instant, 4)));
                Assert.That(ineligible.Status, Is.EqualTo(DispatchStatus.DomainRejected));
            }

            var progressed = GameSaveAggregate.Initial("install-a").Commit(
                "high-school-progress",
                stage: ApplicationStage.HighSchool,
                highSchool: FakeHighSchoolPort.HighSchool(
                    performance: new CareerPerformanceReadModel(importantGames: 1)),
                meta: MetaProgressState.Initial.With(completedGameCount: 1));
            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    progressed.Revision,
                    instant,
                    new string('f', 64),
                    progressed));
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "ignored"))
            {
                var publications = 0;
                store.StatePublished += _ => publications++;
                repository.FailSave = true;
                var failed = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "plan", store.Current.Revision,
                    new PrepareReturnPlanCommand(instant, 4)));
                Assert.That(failed.Status, Is.EqualTo(DispatchStatus.PersistenceFailed));
                Assert.That(store.Current.Meta.ReturnPlan, Is.Null);
                Assert.That(store.Current.AnalyticsReceipts.Records, Is.Empty);
                Assert.That(publications, Is.Zero);

                repository.FailSave = false;
                var prepared = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "plan", store.Current.Revision,
                    new PrepareReturnPlanCommand(instant, 4)));
                Assert.That(prepared.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(repository.Saved.Meta.ReturnPlan.ReceiptId, Is.Not.Empty);
                Assert.That(repository.Saved.AnalyticsReceipts.Contains(
                    ReturnPlanRules.EligibleReceiptScope(repository.Saved.Meta.ReturnPlan)), Is.True);
                Assert.That(publications, Is.EqualTo(1));

                var nextDay = instant.AddDays(1);
                var cold = ReturnPlanRules.NextDayOpen(
                    store.Current.Meta.ReturnPlan, "cold", nextDay);
                var warm = ReturnPlanRules.NextDayOpen(
                    store.Current.Meta.ReturnPlan, "warm", nextDay.AddHours(4));
                Assert.That(cold.DayGap, Is.EqualTo(1));
                Assert.That(cold.LaunchType, Is.EqualTo("cold"));
                Assert.That(warm.LaunchType, Is.EqualTo("warm"));
                var coldScope = ReturnPlanRules.NextDayOpenReceiptScope(cold);
                var warmScope = ReturnPlanRules.NextDayOpenReceiptScope(warm);
                Assert.That(coldScope, Is.EqualTo(warmScope));

                var first = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "return-open", store.Current.Revision,
                    new MarkAnalyticsReceiptCommand(
                        coldScope, nextDay, AnalyticsReceiptRetention.Scoped)));
                var duplicate = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "return-open-again", store.Current.Revision,
                    new MarkAnalyticsReceiptCommand(
                        warmScope, nextDay.AddHours(4), AnalyticsReceiptRetention.Scoped)));
                Assert.That(first.Status, Is.EqualTo(DispatchStatus.Applied));
                Assert.That(duplicate.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                Assert.That(store.Current.AnalyticsReceipts.Contains(coldScope), Is.True);
            }
        }

        [Test]
        public void ReturnPlanEligibility_RemainsMonotonicButArchivedLifeNeedsAPlayableDestination()
        {
            var archive = new LifeArchiveRecord(
                "life:1:hs-1", 1, "민서준", "hs-1", "pro-1", "school-a", "새빛고",
                true, 70, new Baseball.Application.HighSchool.PitcherRatingsReadModel(50, 50, 50, 50),
                new Baseball.Application.HighSchool.CareerPerformanceReadModel(),
                12, 0, 0, 0, 10);
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                3,
                "install-a",
                ApplicationStage.BetweenLives,
                null,
                null,
                MetaProgressState.Initial.With(
                    lifeNumber: 2,
                    lifeArchive: new[] { archive },
                    completedGameCount: 8),
                null,
                null,
                Array.Empty<string>());

            Assert.That(ReturnPlanRules.CompletedGameCount(aggregate), Is.EqualTo(8));
            Assert.That(ReturnPlanRules.PrepareForNextReturn(
                aggregate,
                aggregate.InstallId,
                4,
                new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero)), Is.Null);
        }

        [Test]
        public void SessionEnd_UsesExactPersistedCompletedGameDelta()
        {
            var startedAt = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            var plan = ReturnPlanState.Create(
                "이번 선수 이어가기",
                "다음 경기가 기다립니다.",
                ReturnPlanDestination.HighSchool,
                "high_school_phase");
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                5,
                "install-a",
                ApplicationStage.HighSchool,
                FakeHighSchoolPort.HighSchool(),
                null,
                MetaProgressState.Initial.With(completedGameCount: 7),
                null,
                null,
                Array.Empty<string>());

            var session = ReturnPlanRules.SessionEnd(
                aggregate,
                plan,
                startedAt,
                5,
                startedAt.AddMinutes(9));

            Assert.That(session.Games, Is.EqualTo(2));
            Assert.That(session.Minutes, Is.EqualTo(9));
            Assert.That(session.ReturnEligible, Is.True);
        }

        [Test]
        public void ReturnWelcome_GuidedOnlyAndHandledPromiseIsSuppressedForSameSeoulDay()
        {
            var previous = ReturnPlanState.Create(
                "이번 선수의 목표가 남아 있습니다",
                "탈삼진 2/5",
                ReturnPlanDestination.HighSchool,
                "run_pledge",
                ReturnPlanRules.ReturnExperimentId,
                "abc123",
                "20260809",
                "guided",
                4);
            var current = ReturnPlanState.Create(
                previous.Title,
                "탈삼진 4/5",
                previous.Destination,
                previous.Reason);
            var today = new DateTimeOffset(2026, 8, 10, 3, 0, 0, TimeSpan.Zero);
            var candidate = ReturnPlanRules.WelcomePlan(previous, current, null, today);
            Assert.That(candidate.ReceiptId, Is.EqualTo("abc123"));
            Assert.That(candidate.Body, Is.EqualTo("탈삼진 4/5"));

            var handled = ReturnPlanRules.MarkWelcomeHandled(current, today);
            Assert.That(ReturnPlanRules.WelcomePlan(previous, current, handled, today), Is.Null);
            Assert.That(ReturnPlanRules.WelcomePlan(
                previous, current, handled, today.AddDays(1)), Is.Not.Null);
            var changed = ReturnPlanState.Create(
                previous.Title, "탈삼진 5/5", previous.Destination, previous.Reason);
            Assert.That(ReturnPlanRules.WelcomePlan(previous, changed, handled, today), Is.Not.Null);

            var holdout = ReturnPlanState.Create(
                previous.Title, previous.Body, previous.Destination, previous.Reason,
                ReturnPlanRules.ReturnExperimentId, "def456", "20260809", "holdout", 4);
            Assert.That(ReturnPlanRules.WelcomePlan(holdout, current, null, today), Is.Null);
        }

        [Test]
        public async Task ReturnPlanTapAndDismissPersistWelcomeSuppressionWithoutLosingReceipt()
        {
            var repository = new RecordingGameRepository();
            var plan = ReturnPlanState.Create(
                "프로 시즌의 다음 선택",
                "프로 시즌의 다음 주를 이어서 보내세요.",
                ReturnPlanDestination.Pro,
                "pro_phase",
                ReturnPlanRules.ReturnExperimentId,
                "abc123",
                "20260809",
                "guided",
                4);
            var aggregate = GameSaveAggregate.Initial("install-a").Commit(
                "plan", meta: MetaProgressState.Initial.With(returnPlan: plan));
            repository.LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name, SaveSchema.Version, aggregate.Revision,
                    new DateTimeOffset(2026, 8, 9, 0, 0, 0, TimeSpan.Zero),
                    new string('e', 64), aggregate));
            using (var store = await GameApplicationStore.OpenAsync(
                       repository, new FakeHighSchoolPort(), new FakeProPort(), "ignored"))
            {
                var today = new DateTimeOffset(2026, 8, 10, 2, 0, 0, TimeSpan.Zero);
                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "tap", store.Current.Revision,
                    new CompleteReturnPlanInteractionCommand(false, today)));
                Assert.That(store.Current.Meta.ReturnPlan.Dismissed, Is.False);
                Assert.That(store.Current.Meta.ReturnPlan.ReceiptId, Is.EqualTo("abc123"));
                Assert.That(store.Current.Meta.ReturnWelcomeHandled.DayKey, Is.EqualTo("20260810"));

                await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                    "dismiss", store.Current.Revision,
                    new CompleteReturnPlanInteractionCommand(true, today.AddMinutes(1))));
                Assert.That(store.Current.Meta.ReturnPlan.Dismissed, Is.True);
                Assert.That(store.Current.Meta.ReturnPlan.ReceiptId, Is.EqualTo("abc123"));
                Assert.That(repository.Saved.Meta.ReturnWelcomeHandled.DayKey, Is.EqualTo("20260810"));
            }
        }

        [Test]
        public void NextAction_AlwaysPrioritizesUnconsumedPitchResultOverReturnPlan()
        {
            var report = new Baseball.Application.HighSchool.PitchGameReport(
                "game", 10, 3, 3, 2, 0, 0, 0);
            var meta = MetaProgressState.Initial.With(returnPlan: new ReturnPlanState(
                "weekly", "이번 주", "주간 노트를 확인합니다.", "20260811"));
            var state = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion, 4, "install-a", ApplicationStage.HighSchool,
                FakeHighSchoolPort.HighSchool(), null, meta, null,
                new PendingPitchCompletion("result", PitchCareerKind.HighSchool, "hs-1", report, 1),
                Array.Empty<string>());

            var action = NextActionPlanner.Resolve(state);

            Assert.That(action.Route, Is.EqualTo("pitch/result"));
            Assert.That(action.ResumesInterruption, Is.True);
        }

        [Test]
        public void NextAction_CoreProgressExcludesReturnExperimentButKeepsPitchRecoveryFirst()
        {
            var plan = ReturnPlanState.Create(
                "다음 선수의 약속",
                "개인화된 복귀 안내입니다.",
                ReturnPlanDestination.HighSchool,
                "run_pledge");
            var highSchool = FakeHighSchoolPort.HighSchool();
            var state = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                4,
                "install-a",
                ApplicationStage.HighSchool,
                highSchool,
                null,
                MetaProgressState.Initial.With(returnPlan: plan),
                null,
                null,
                Array.Empty<string>());

            Assert.That(NextActionPlanner.Resolve(state).Title, Is.EqualTo(plan.Title));
            Assert.That(NextActionPlanner.ResolveCoreProgress(state).Route,
                Is.EqualTo("high-school"));

            var report = new Baseball.Application.HighSchool.PitchGameReport(
                "game", 10, 3, 3, 2, 0, 0, 0);
            var interrupted = state.Commit(
                "pending",
                pendingPitchCompletion: new PendingPitchCompletion(
                    "result", PitchCareerKind.HighSchool, "hs-1", report, 1));
            Assert.That(NextActionPlanner.ResolveCoreProgress(interrupted).Route,
                Is.EqualTo("pitch/result"));
        }

        [Test]
        public void RetiredDailyReturnPlan_IsReadableButFallsBackWithoutWelcomeOrAnalytics()
        {
            var now = new DateTimeOffset(2026, 8, 12, 2, 0, 0, TimeSpan.Zero);
            var typed = ReturnPlanState.Create(
                "옛 일일 계획",
                "호환을 위해 읽기만 합니다.",
                ReturnPlanDestination.DailyInning,
                "legacy_daily",
                ReturnPlanRules.ReturnExperimentId,
                "abc123",
                "20260811",
                "guided",
                4);
            var rawLegacy = new ReturnPlanState(
                "daily-inning",
                "옛 링크",
                "계속",
                "20260811");
            var state = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                4,
                "install-a",
                ApplicationStage.HighSchool,
                FakeHighSchoolPort.HighSchool(),
                null,
                MetaProgressState.Initial.With(returnPlan: typed),
                null,
                null,
                Array.Empty<string>());

            Assert.That(ReturnPlanRules.IsValid(typed), Is.True,
                "Persisted typed values remain load-compatible.");
            Assert.That(ReturnPlanRules.IsRetiredDailyPlan(typed), Is.True);
            Assert.That(ReturnPlanRules.IsRetiredDailyPlan(rawLegacy), Is.True);
            Assert.That(NextActionPlanner.Resolve(state).Route, Is.EqualTo("high-school"));
            var proState = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                4,
                "install-a",
                ApplicationStage.Pro,
                null,
                FakeProPort.Pro(),
                MetaProgressState.Initial.With(returnPlan: rawLegacy),
                null,
                null,
                Array.Empty<string>());
            Assert.That(NextActionPlanner.Resolve(proState).Route, Is.EqualTo("pro"));
            Assert.That(ReturnPlanRules.WelcomePlan(typed, typed, null, now), Is.Null);
            var currentHighSchoolPlan = ReturnPlanRules.CurrentPlan(state);
            var currentProPlan = ReturnPlanRules.CurrentPlan(proState);
            Assert.That(currentHighSchoolPlan.Destination,
                Is.EqualTo(ReturnPlanDestination.HighSchool));
            Assert.That(currentProPlan.Destination, Is.EqualTo(ReturnPlanDestination.Pro));
            Assert.That(ReturnPlanRules.WelcomePlan(
                typed, currentHighSchoolPlan, null, now), Is.Null,
                "A retired typed Daily experiment cannot personalize a live high-school route.");
            Assert.That(ReturnPlanRules.WelcomePlan(
                rawLegacy, currentProPlan, null, now), Is.Null,
                "A retired raw Daily route cannot personalize a live Pro route.");
            Assert.That(ReturnPlanRules.Analytics(typed, now), Is.Null);
            Assert.That(ReturnPlanRules.NextDayOpen(typed, "cold", now), Is.Null);
            Assert.That(ReturnPlanRules.EligibleReceiptScope(typed), Is.Null);
            Assert.That(() => ReturnPlanRules.PrepareForNextReturn(
                    typed, "install-a", 4, now),
                Throws.ArgumentException.With.Message.Contains("daily.retired"));
        }

        [Test]
        public void TombstoneHasHighestSemanticConflictPriority()
        {
            var live = GameSaveAggregate.Initial("install-a");
            var deleted = live.Commit(
                "delete",
                stage: ApplicationStage.Deleted,
                deleted: true,
                clearHighSchool: true,
                clearPro: true);
            var priority = new GameSaveSemanticPriority();

            Assert.That(priority.GetPriority(deleted), Is.GreaterThan(priority.GetPriority(live)));
        }

        private static SaveLoadResult<GameSaveAggregate> Loaded(
            GameSaveAggregate aggregate,
            char checksumCharacter)
        {
            return SaveLoadResult<GameSaveAggregate>.Create(
                SaveLoadStatus.LoadedCanonical,
                new SaveEnvelope<GameSaveAggregate>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    aggregate.Revision,
                    new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                    new string(checksumCharacter, 64),
                    aggregate));
        }
    }
}
