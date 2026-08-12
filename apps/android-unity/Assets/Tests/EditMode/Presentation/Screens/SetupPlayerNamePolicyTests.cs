using Baseball.Presentation.Shell;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using NUnit.Framework;

namespace Baseball.Tests.EditMode.Presentation.Screens
{
    public sealed class SetupPlayerNamePolicyTests
    {
        [Test]
        public void EmptyInputIsPreservedAndResolvesToCurrentPresetSuggestion()
        {
            Assert.That(SetupPlayerNamePolicy.TryUpdate("이전 이름", string.Empty, out string draft), Is.True);
            Assert.That(draft, Is.Empty);
            Assert.That(SetupPlayerNamePolicy.Resolve(draft, "강태윤"), Is.EqualTo("강태윤"));
            Assert.That(SetupPlayerNamePolicy.Resolve(draft, "윤시우"), Is.EqualTo("윤시우"));
        }

        [Test]
        public void TwelveCharactersAreAcceptedAndThirteenKeepPriorDraft()
        {
            const string twelve = "가나다라마바사아자차카타";
            Assert.That(twelve.Length, Is.EqualTo(12));
            Assert.That(SetupPlayerNamePolicy.TryUpdate(string.Empty, twelve, out string accepted), Is.True);
            Assert.That(accepted, Is.EqualTo(twelve));
            Assert.That(SetupPlayerNamePolicy.TryUpdate(accepted, twelve + "파", out string rejected), Is.False);
            Assert.That(rejected, Is.EqualTo(twelve));
        }

        [Test]
        public void ExplicitNameWinsWhileWhitespaceUsesSuggestion()
        {
            Assert.That(SetupPlayerNamePolicy.Resolve("  한서준  ", "강태윤"), Is.EqualTo("한서준"));
            Assert.That(SetupPlayerNamePolicy.Resolve("   ", "강태윤"), Is.EqualTo("강태윤"));
        }

        [Test]
        public void ChallengeExitResetsButSameSetupRouteRoundTripPreservesDraft()
        {
            var lifecycle = new SetupDraftLifecyclePolicy();
            Assert.That(lifecycle.Observe(true, "install-a", 2), Is.True,
                "first ready projection hydrates a fresh setup draft");
            Assert.That(lifecycle.Observe(true, "install-a", 2), Is.False,
                "same-cycle publication or route away/back preserves the unsaved draft");

            Assert.That(lifecycle.Observe(false, "install-a", 2), Is.False,
                "starting a challenge only closes the current draft");
            Assert.That(lifecycle.Observe(true, "install-a", 2), Is.True,
                "ending a challenge re-enters Setup at the same life but is a new draft cycle");
        }

        [Test]
        public void NewLifeStoreRecoveryAndResetIdentityEachStartFreshSetupCycle()
        {
            var lifecycle = new SetupDraftLifecyclePolicy();
            Assert.That(lifecycle.Observe(false, "install-a", 1), Is.False);
            Assert.That(lifecycle.Observe(true, "install-a", 2), Is.True,
                "custom rebirth increments life and clears spent boosts and seed input");
            Assert.That(lifecycle.Observe(true, "install-a", 2), Is.False);
            Assert.That(lifecycle.Observe(true, "install-a", 2, storeReplaced: true), Is.True,
                "a recovered store must rebuild draft defaults from durable state");
            Assert.That(lifecycle.Observe(true, "install-b", 1), Is.True,
                "reset-all identity starts an unrelated first-life draft");
        }

        [TestCase("18446744073709551616")]
        [TestCase("12--2")]
        [TestCase("12-0")]
        public void InvalidDecimalOrMalformedChallengeFailsClosed(string input)
        {
            Assert.That(SetupSeedInputPolicy.IsValid(input), Is.False);
            Assert.That(SetupSeedInputPolicy.ValidationMessage(input),
                Is.EqualTo(SetupSeedInputPolicy.InvalidMessage));
            Assert.That(SetupSeedInputPolicy.TryResolve(
                input,
                "install:life:2",
                out _,
                out string resolved), Is.False);
            Assert.That(resolved, Is.Null);
        }

        [Test]
        public void StaleValidInputBecomingInvalidCannotReusePriorResolution()
        {
            Assert.That(SetupSeedInputPolicy.TryResolve(
                "12345-2",
                "install:life:2",
                out var valid,
                out string validSeed), Is.True);
            Assert.That(valid.IsChallenge, Is.True);
            Assert.That(validSeed, Is.EqualTo("12345"));

            Assert.That(SetupSeedInputPolicy.TryResolve(
                "12345--2",
                "install:life:2",
                out var invalid,
                out string invalidSeed), Is.False);
            Assert.That(invalid, Is.Null);
            Assert.That(invalidSeed, Is.Null);
        }

        [Test]
        public void ValidChallengeAndEmptyInputResolveWithoutAmbiguousFallback()
        {
            Assert.That(SetupSeedInputPolicy.TryResolve(
                "도전 67890-4",
                "install:life:2",
                out var challenge,
                out string challengeSeed), Is.True);
            Assert.That(challengeSeed, Is.EqualTo("67890"));
            Assert.That(challenge.ChallengeLifeNumber, Is.EqualTo(4));

            Assert.That(SetupSeedInputPolicy.TryResolve(
                string.Empty,
                "install:life:2",
                out var empty,
                out string defaultSeed), Is.True);
            Assert.That(empty, Is.Null);
            Assert.That(defaultSeed, Is.EqualTo("install:life:2"));
        }

        [Test]
        public void CareerChoiceDraftPersistsWithinPhaseAndResetsAcrossPhaseCareerOrStore()
        {
            var lifecycle = new CareerChoiceDraftLifecyclePolicy();
            GameSaveAggregate training = WithHighSchool(
                "career-a",
                HighSchoolPhase.Training);
            Assert.That(lifecycle.Observe(training), Is.True);
            Assert.That(lifecycle.Observe(training), Is.False,
                "route round-trips and same-phase publications preserve the draft");

            GameSaveAggregate relationship = WithHighSchool(
                "career-a",
                HighSchoolPhase.Relationship);
            Assert.That(lifecycle.Observe(relationship), Is.True);
            Assert.That(lifecycle.Observe(relationship), Is.False);

            GameSaveAggregate nextCareer = WithHighSchool(
                "career-b",
                HighSchoolPhase.Relationship);
            Assert.That(lifecycle.Observe(nextCareer), Is.True);
            Assert.That(lifecycle.Observe(nextCareer, storeReplaced: true), Is.True,
                "restart rehydrates choices from the authoritative read model");
        }

        private static GameSaveAggregate WithHighSchool(
            string careerId,
            HighSchoolPhase phase)
        {
            var highSchool = new HighSchoolCareerReadModel(
                careerId,
                2,
                phase,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel());
            return GameSaveAggregate.Initial("install").Commit(
                "state-" + careerId + "-" + phase,
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool,
                meta: new Baseball.Application.Meta.MetaProgressState(lifeNumber: 2));
        }
    }
}
