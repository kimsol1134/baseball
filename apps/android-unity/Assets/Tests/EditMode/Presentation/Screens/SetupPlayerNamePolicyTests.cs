using Baseball.Presentation.Shell;
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
    }
}
