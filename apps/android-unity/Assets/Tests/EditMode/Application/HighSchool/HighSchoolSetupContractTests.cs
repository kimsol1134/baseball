using System;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class HighSchoolSetupContractTests
    {
        [Test]
        public void FirstLife_ExposesExactlyNineteenRegionsAndFourPresetsOnly()
        {
            var setup = HighSchoolSetupCatalog.For(MetaProgressState.Initial);

            Assert.That(setup.AdvancedOptionsVisible, Is.False);
            Assert.That(setup.Regions, Has.Count.EqualTo(19));
            Assert.That(setup.Presets, Has.Count.EqualTo(4));
            Assert.That(setup.Difficulties, Is.Empty);
            Assert.That(setup.Karmas, Is.Empty);
            Assert.That(setup.SoulBoosts, Is.Empty);
            Assert.That(setup.SignatureLegacies, Is.Empty);
            Assert.That(setup.CanQuickRebirth, Is.False);
        }

        [Test]
        public void Rebirth_ExposesSpendableAndInheritedChoicesWithoutCombiningBalances()
        {
            var last = new HighSchoolLastSetupState(
                "precision_commander", "고태윤", "대전", "challenging",
                new[] { "unknown_land" }, "technique");
            var meta = new MetaProgressState(
                lifeNumber: 2,
                soulBalance: 240,
                automaticSoulEarned: 37,
                inheritedMemories: new[] { "catcher_notebook" },
                lastHighSchoolSetup: last,
                unlockedSignatureLegacyIds: new[] { "command_map" },
                equippedSignatureLegacyId: "command_map");

            var setup = HighSchoolSetupCatalog.For(meta);

            Assert.That(setup.AdvancedOptionsVisible, Is.True);
            Assert.That(setup.SoulBalance, Is.EqualTo(240));
            Assert.That(setup.AutomaticSoul, Is.EqualTo(37));
            Assert.That(setup.Difficulties, Has.Count.EqualTo(3));
            Assert.That(setup.SignatureLegacies, Has.Count.EqualTo(1));
            Assert.That(setup.SignatureLegacies[0].Payload, Is.EqualTo("command_map"));
            Assert.That(setup.CanQuickRebirth, Is.True);
            Assert.That(setup.LastSetup, Is.SameAs(last));
        }

        [Test]
        public void SetupValidation_RejectsLockedAdvancedFieldsAndInvalidChallengeInheritance()
        {
            var firstLifeAdvanced = new StartHighSchoolCareerRequest(
                "7", "power_prospect", "민서준", "서울", 1,
                karmas: new[] { "unknown_land" });
            Assert.That(HighSchoolSetupCatalog.Validate(
                    firstLifeAdvanced, 0, 0, Array.Empty<string>(),
                    Array.Empty<string>(), advancedSetupAvailable: false),
                Is.EqualTo("high_school.advanced_setup_locked"));

            var lockedSignature = new StartHighSchoolCareerRequest(
                "7", "power_prospect", "민서준", "서울", 2,
                signatureLegacyId: "command_map");
            Assert.That(HighSchoolSetupCatalog.Validate(
                    lockedSignature, 0, 0, Array.Empty<string>(), Array.Empty<string>()),
                Is.EqualTo("high_school.signature_legacy_locked"));

            var invalidChallenge = new StartHighSchoolCareerRequest(
                "7", "power_prospect", "민서준", "서울", 1,
                karmas: new[] { "unknown_land" }, challengeLifeNumber: 9);
            Assert.That(HighSchoolSetupCatalog.Validate(
                    invalidChallenge, 0, 0, Array.Empty<string>(), Array.Empty<string>(), false),
                Is.EqualTo("high_school.challenge_invalid"));
        }

        [Test]
        public void SeedParser_DistinguishesNumericSeedChallengeCodeAndTypo()
        {
            Assert.That(HighSchoolSetupCatalog.TryParseSeedInput(
                "도전 12345-4", out var challenge, out var challengeError), Is.True);
            Assert.That(challengeError, Is.Null);
            Assert.That(challenge.Seed, Is.EqualTo("12345"));
            Assert.That(challenge.ChallengeLifeNumber, Is.EqualTo(4));

            Assert.That(HighSchoolSetupCatalog.TryParseSeedInput(
                "67890", out var direct, out var directError), Is.True);
            Assert.That(directError, Is.Null);
            Assert.That(direct.IsChallenge, Is.False);

            Assert.That(HighSchoolSetupCatalog.TryParseSeedInput(
                "12-0", out _, out var invalidError), Is.False);
            Assert.That(invalidError, Is.EqualTo("high_school.seed_or_challenge_invalid"));
        }

        [Test]
        public void QuickRebirth_UsesDurableLastSetupAndAutomaticSoulOnly()
        {
            var meta = new MetaProgressState(
                lifeNumber: 2,
                soulBalance: 500,
                automaticSoulEarned: 33,
                inheritedMemories: new[] { "catcher_notebook" },
                lastHighSchoolSetup: new HighSchoolLastSetupState(
                    "precision_commander", "고태윤", "대전", "challenging",
                    new[] { "unknown_land" }, "technique"));
            var aggregate = new GameSaveAggregate(
                1, 4, "install-a", ApplicationStage.Setup,
                null, null, meta, null, null, Array.Empty<string>());
            var transition = new GameCommandTransition(new FakeHighSchoolPort(), new FakeProPort());

            var result = transition.Apply(
                aggregate,
                new StartQuickRebirthCommand(),
                "quick");

            Assert.That(result.IsSuccess, Is.True, result.ErrorCode);
            Assert.That(result.NextState.HighSchool.PresetId, Is.EqualTo("precision_commander"));
            Assert.That(result.NextState.HighSchool.PlayerName, Is.EqualTo("고태윤"));
            Assert.That(result.NextState.HighSchool.Difficulty, Is.EqualTo("challenging"));
            Assert.That(result.NextState.Meta.SoulBalance, Is.EqualTo(500));
        }

        [Test]
        public void QuickRebirth_FromArchivedRecapIsOneAtomicTransition()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 4, 0, 0, TimeSpan.Zero);
            var archived = new LifeArchiveRecord(
                "life:1:hs-1",
                1,
                "고태윤",
                "hs-1",
                null,
                "school-a",
                "새빛고",
                false,
                55,
                new PitcherRatingsReadModel(50, 52, 48, 49),
                new CareerPerformanceReadModel(),
                0,
                0,
                0,
                0,
                24);
            var meta = new MetaProgressState(
                lifeNumber: 1,
                soulBalance: 24,
                automaticSoulEarned: 24,
                lifeArchive: new[] { archived },
                lastHighSchoolSetup: new HighSchoolLastSetupState(
                    "precision_commander", "고태윤", "대전", "challenging"));
            var completed = FakeHighSchoolPort.HighSchool(
                phase: HighSchoolPhase.Completed,
                careerId: "hs-1",
                lifeNumber: 1);
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                8,
                "install-a",
                ApplicationStage.Legacy,
                completed,
                null,
                meta,
                null,
                null,
                Array.Empty<string>());

            var result = new GameCommandTransition(
                new FakeHighSchoolPort(), new FakeProPort()).Apply(
                aggregate,
                new StartQuickRebirthCommand("run_recap", instant),
                "quick-recap");

            Assert.That(result.IsSuccess, Is.True, result.ErrorCode);
            Assert.That(result.NextState.Revision, Is.EqualTo(aggregate.Revision + 1));
            Assert.That(result.NextState.Meta.LifeNumber, Is.EqualTo(2));
            Assert.That(result.NextState.HighSchool.LifeNumber, Is.EqualTo(2));
            Assert.That(result.NextState.HighSchool.PresetId, Is.EqualTo("precision_commander"));
            Assert.That(result.NextState.Pro, Is.Null);
            Assert.That(result.NextState.Meta.LifeArchive, Has.Count.EqualTo(1));
            Assert.That(result.NextState.HasCommandReceipt("quick-recap"), Is.True);
        }

        [Test]
        public void ChallengeRun_UsesSharedLifeButCannotMutateArchiveOrMeta()
        {
            var aggregate = new GameSaveAggregate(
                1, 2, "install-a", ApplicationStage.Setup,
                null, null, MetaProgressState.Initial, null, null, Array.Empty<string>());
            var transition = new GameCommandTransition(new FakeHighSchoolPort(), new FakeProPort());
            var start = transition.Apply(
                aggregate,
                new StartHighSchoolCareerCommand(new StartHighSchoolCareerRequest(
                    "12345", "power_prospect", "민서준", "서울", 1,
                    challengeLifeNumber: 7)),
                "challenge-start");

            Assert.That(start.IsSuccess, Is.True, start.ErrorCode);
            Assert.That(start.NextState.HighSchool.IsChallengeRun, Is.True);
            Assert.That(start.NextState.HighSchool.LifeNumber, Is.EqualTo(7));
            Assert.That(start.NextState.Meta, Is.SameAs(aggregate.Meta));

            var drafted = transition.Apply(
                start.NextState,
                new AdvanceHighSchoolCommand(
                    new HighSchoolAction("resolve_draft", "drafted"),
                    new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)),
                "challenge-draft");
            var ended = transition.Apply(drafted.NextState, new EndChallengeRunCommand(), "challenge-end");

            Assert.That(ended.IsSuccess, Is.True, ended.ErrorCode);
            Assert.That(ended.NextState.Stage, Is.EqualTo(ApplicationStage.Setup));
            Assert.That(ended.NextState.HighSchool, Is.Null);
            Assert.That(ended.NextState.Meta.LifeArchive, Is.Empty);
            Assert.That(ended.NextState.Meta.LifeNumber, Is.EqualTo(1));
        }

        [Test]
        public void ChallengeRun_MaySkipTutorialWithoutMetaOrPerformanceEffects()
        {
            var aggregate = new GameSaveAggregate(
                GameSaveAggregate.CurrentAggregateVersion,
                2,
                "install-a",
                ApplicationStage.Setup,
                null,
                null,
                MetaProgressState.Initial,
                null,
                null,
                Array.Empty<string>());
            var transition = new GameCommandTransition(
                new FakeHighSchoolPort(), new FakeProPort());
            var started = transition.Apply(
                aggregate,
                new StartHighSchoolCareerCommand(new StartHighSchoolCareerRequest(
                    "12345", "power_prospect", "민서준", "서울", 1,
                    challengeLifeNumber: 7)),
                "challenge-start").NextState;
            var ratings = started.HighSchool.Ratings.Total;
            var performance = started.HighSchool.Performance;

            var skipped = transition.Apply(
                started,
                new SkipTutorialCommand(),
                "challenge-skip");

            Assert.That(skipped.IsSuccess, Is.True, skipped.ErrorCode);
            Assert.That(skipped.NextState.HighSchool.IsChallengeRun, Is.True);
            Assert.That(skipped.NextState.HighSchool.Phase,
                Is.EqualTo(HighSchoolPhase.SchoolSelection));
            Assert.That(skipped.NextState.HighSchool.TutorialCompleted, Is.False);
            Assert.That(skipped.NextState.HighSchool.Ratings.Total, Is.EqualTo(ratings));
            Assert.That(skipped.NextState.HighSchool.Performance.ImportantGames,
                Is.EqualTo(performance.ImportantGames));
            Assert.That(skipped.NextState.Meta, Is.SameAs(started.Meta));
        }
    }
}
