#if UNITY_EDITOR || (DEVELOPMENT_BUILD && BASEBALL_INTERNAL_QA)
using NUnit.Framework;
using Baseball.Presentation.Pitch;

namespace Baseball.Platform.InternalQa.Tests
{
    [TestFixture]
    public sealed class InternalQaContractTests
    {
        [Test]
        public void RequestParserIsAllowlistedAndDeterministic()
        {
            Assert.That(InternalQaRequest.TryCreate(
                "fixture", "42", "tutorial_checkpoint", "low", out InternalQaRequest request, out string error),
                Is.True,
                error);
            Assert.That(request.Command, Is.EqualTo("fixture"));
            Assert.That(request.Seed, Is.EqualTo("42"));
            Assert.That(request.Phase, Is.EqualTo("tutorial_checkpoint"));
            Assert.That(request.Quality, Is.EqualTo(PitchQualityTier.Low));

            Assert.That(InternalQaRequest.TryCreate(
                "unknown", "42", "opening", "high", out _, out error), Is.False);
            Assert.That(error, Is.EqualTo("command_not_allowed"));
            Assert.That(InternalQaRequest.TryCreate(
                "fixture", "player-name", "opening", "high", out _, out error), Is.False);
            Assert.That(error, Is.EqualTo("seed_invalid"));
        }

        [Test]
        public void PitchFixtureIsExactForTheSameSeedAndQualityDoesNotAlterIt()
        {
            PitchPresentationSnapshot first = InternalQaPitchFixture.Create("20260811");
            PitchPresentationSnapshot second = InternalQaPitchFixture.Create("20260811");

            Assert.That(second.PitchId, Is.EqualTo(first.PitchId));
            Assert.That(second.PresentationSeed, Is.EqualTo(first.PresentationSeed));
            Assert.That(second.Call, Is.EqualTo(first.Call));
            Assert.That(second.Contact.ExitVelocityKph, Is.EqualTo(first.Contact.ExitVelocityKph));
            Assert.That(second.Fielding.LandingDistanceMeters, Is.EqualTo(first.Fielding.LandingDistanceMeters));
            Assert.That(second.Trajectory.Count, Is.EqualTo(first.Trajectory.Count));
            Assert.That(first.PresentationSeed, Is.EqualTo(20260811UL));
        }

        [TestCase("tutorial-checkpoint", "opening", "tutorial_checkpoint")]
        [TestCase("pitch-sample", "setup", "setup")]
        public void CommandNormalizationHasStablePhaseRules(
            string command,
            string requestedPhase,
            string expectedPhase)
        {
            Assert.That(InternalQaRequest.TryCreate(
                command, null, requestedPhase, null, out InternalQaRequest request, out string error),
                Is.True,
                error);
            Assert.That(request.Seed, Is.EqualTo(InternalQaRequest.DefaultSeed));
            Assert.That(request.Phase, Is.EqualTo(expectedPhase));
            Assert.That(request.Quality, Is.EqualTo(PitchQualityTier.High));
        }
    }
}
#endif
