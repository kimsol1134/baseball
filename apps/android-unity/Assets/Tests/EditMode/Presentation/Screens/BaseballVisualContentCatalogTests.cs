using System;
using System.IO;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Presentation.Common;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class BaseballVisualContentCatalogTests
    {
        [Test]
        public void EverySetupRegionAndPitcherPresetUsesPackagedLocalArtwork()
        {
            Assert.That(HighSchoolSetupCatalog.Regions.Count, Is.EqualTo(19));
            foreach (var option in HighSchoolSetupCatalog.Regions)
                Assert.That(BaseballVisualContentCatalog.IsLocalOnlyAddress(
                    BaseballVisualContentCatalog.SetupRegion(option.Payload)), Is.True, option.Payload);

            Assert.That(HighSchoolSetupCatalog.Presets.Count, Is.EqualTo(4));
            foreach (var option in HighSchoolSetupCatalog.Presets)
                Assert.That(BaseballVisualContentCatalog.IsLocalOnlyAddress(
                    BaseballVisualContentCatalog.SetupPreset(option.Payload)), Is.True, option.Payload);
            Assert.That(BaseballVisualContentCatalog.SetupPreset("innings_eater"),
                Is.EqualTo("baseball/setup/PresetArt-power_prospect"),
                "the source catalog has no dedicated innings-eater image, so its visual fallback is explicit");
            Assert.That(BaseballVisualContentCatalog.PresetResultPreview("power_prospect"),
                Is.EqualTo("구위 42 · 제구 34 · 변화 36 · 체력 38 · 주무기 포심 · 육성 체인지업"));
            Assert.That(BaseballVisualContentCatalog.PresetResultPreview("innings_eater"),
                Does.Contain("체력 44"));
        }

        [Test]
        public void MemoryLegacyRelationshipAndTournamentMappingsStayInsideLocalCatalog()
        {
            string[] memories =
            {
                "VelocityBlueprint", "CatcherNotebook", "CoachLetter", "DraftReport",
                "FailureScorebook", "FatigueDiary", "FingertipMemory", "FirstPitchMap",
                "MechanicsVideo", "PressureRehearsal", "RecoveryRoutine", "RivalNotebook",
                "SchoolPlaybook", "StadiumEcho", "TeamFirstPromise", "TwoStrikeSequence",
                "WinterProgram", "BullpenCompass",
            };
            Assert.That(memories.All(value => BaseballVisualContentCatalog.IsLocalOnlyAddress(
                BaseballVisualContentCatalog.Memory(value))), Is.True);

            string[] legacies =
            {
                "power_imprint", "command_map", "breaking_trace", "endurance_rhythm",
                "gamecraft_ledger", "battery_promise",
            };
            Assert.That(legacies.All(value => BaseballVisualContentCatalog.IsLocalOnlyAddress(
                BaseballVisualContentCatalog.SignatureLegacy(value))), Is.True);
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork("catcher", "푸른 포수"),
                Does.StartWith("baseball/highschool/PortraitCatcher"));
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork("coach", "은하 감독"),
                Does.StartWith("baseball/highschool/PortraitCoach"));
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork("rival", "라이벌"),
                Does.StartWith("baseball/highschool/PortraitRival"));
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork("media", "기자"),
                Is.EqualTo("baseball/meta/SceneArt-media"));
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork("health", "트레이너"),
                Is.EqualTo("baseball/meta/SceneArt-health"),
                "a non-character scene must never invent a catcher portrait");
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork("unknown", "담임"), Is.Empty);
            const string school = "점유율을 높이는 야구 · 감독 윤태문 · 포수 서준호";
            Assert.That(BaseballVisualContentCatalog.SchoolCoachPortrait(school),
                Is.EqualTo("baseball/highschool/PortraitCoach1"));
            Assert.That(BaseballVisualContentCatalog.SchoolCatcherPortrait(school),
                Is.EqualTo("baseball/highschool/PortraitCatcher1"));
            Assert.That(BaseballVisualContentCatalog.CoachPortrait("조범석"),
                Is.EqualTo("baseball/highschool/PortraitCoach1"));
            Assert.That(BaseballVisualContentCatalog.CoachPortrait("곽태윤"),
                Is.EqualTo("baseball/highschool/PortraitCoach2"));
            Assert.That(BaseballVisualContentCatalog.CoachPortrait("하병철"),
                Is.EqualTo("baseball/highschool/PortraitCoach3"));
            Assert.That(BaseballVisualContentCatalog.CoachPortrait("반석호"),
                Is.EqualTo("baseball/highschool/PortraitCoach4"));
            Assert.That(BaseballVisualContentCatalog.CatcherPortrait("정우빈"),
                Is.EqualTo("baseball/highschool/PortraitCatcher1"));
            Assert.That(BaseballVisualContentCatalog.CatcherPortrait("남기율"),
                Is.EqualTo("baseball/highschool/PortraitCatcher2"));
            Assert.That(BaseballVisualContentCatalog.CatcherPortrait("표재신"),
                Is.EqualTo("baseball/highschool/PortraitCatcher3"));
            Assert.That(BaseballVisualContentCatalog.CatcherPortrait("탁이현"),
                Is.EqualTo("baseball/highschool/PortraitCatcher4"));
            Assert.That(new[] { 2, 4, 6, 8 }.Select(BaseballVisualContentCatalog.TournamentBanner),
                Is.EqualTo(new[]
                {
                    "baseball/highschool/TournamentBanner2",
                    "baseball/highschool/TournamentBanner4",
                    "baseball/highschool/TournamentBanner6",
                    "baseball/highschool/TournamentBanner8",
                }));
            Assert.That(BaseballVisualContentCatalog.TournamentBanner(3), Is.Empty,
                "an unsupported chapter must not borrow another chapter's banner");
            Assert.That(BaseballVisualContentCatalog.ImportantGameScene(),
                Is.EqualTo("baseball/meta/SceneArt-game"));
            Assert.That(BaseballVisualContentCatalog.TalentBloom(),
                Is.EqualTo("baseball/meta/BloomArt"));
        }

        [Test]
        public void PlayerPortraitKeepsOneNameInTheSameTwentyFaceLineageAcrossGrowthStages()
        {
            string young = BaseballVisualContentCatalog.PlayerPortrait(
                "민서준",
                PlayerPortraitStage.Young);
            string ace = BaseballVisualContentCatalog.PlayerPortrait(
                "민서준",
                PlayerPortraitStage.Ace);
            string pro = BaseballVisualContentCatalog.PlayerPortrait(
                "민서준",
                PlayerPortraitStage.Pro);
            string suffix = new string(ace.SkipWhile(value => !char.IsDigit(value)).ToArray());

            Assert.That(young, Is.EqualTo("baseball/highschool/PortraitPlayerYoung" + suffix));
            Assert.That(pro, Is.EqualTo("baseball/pro/PortraitPlayerPro" + suffix));
            Assert.That(int.Parse(suffix), Is.InRange(1, 20));
            Assert.That(BaseballVisualContentCatalog.PlayerPortrait(string.Empty, PlayerPortraitStage.Ace),
                Is.Empty);
        }

        [Test]
        public void PlayerPortraitAddressesMatchTheImportedManifestLabels()
        {
            string manifest = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Content/Manifests/asset-manifest.json"));
            for (int index = 1; index <= 20; index++)
            {
                AssertManifestLabel(manifest, "PortraitPlayerYoung" + index, "highschool");
                AssertManifestLabel(manifest, "PortraitPlayer" + index, "highschool");
                AssertManifestLabel(manifest, "PortraitPlayerPro" + index, "pro");
            }

            string proAddress = BaseballVisualContentCatalog.PlayerPortrait(
                "민서준",
                PlayerPortraitStage.Pro);
            Assert.That(proAddress, Does.StartWith("baseball/pro/PortraitPlayerPro"));
        }

        [TestCase("https://example.invalid/image.png")]
        [TestCase("remote/image")]
        [TestCase("")]
        public void RemoteOrMissingArtworkIsRejectedForReducedDataSafety(string address)
        {
            Assert.That(BaseballVisualContentCatalog.IsLocalOnlyAddress(address), Is.False);
        }

        private static void AssertManifestLabel(string manifest, string logicalName, string label)
        {
            int entries = manifest.IndexOf("\"entries\":", StringComparison.Ordinal);
            int start = manifest.IndexOf(
                "\"logicalName\": \"" + logicalName + "\"",
                entries,
                StringComparison.Ordinal);
            int end = start < 0
                ? -1
                : manifest.IndexOf("\n    }", start, StringComparison.Ordinal);
            Assert.That(start, Is.GreaterThanOrEqualTo(entries), logicalName);
            Assert.That(end, Is.GreaterThan(start), logicalName);
            string entry = manifest.Substring(start, end - start);
            Assert.That(entry, Does.Contain("\"addressableLabel\": \"" + label + "\""), logicalName);
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
            throw new FileNotFoundException("Repository source was not found.", relativePath);
        }
    }
}
