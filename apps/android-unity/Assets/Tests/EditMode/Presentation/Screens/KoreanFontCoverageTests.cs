using System.Collections.Generic;
using System.IO;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class KoreanFontCoverageTests
    {
        private const string RegularPath =
            "Assets/Game/Presentation/Common/Resources/Fonts/Pretendard-Regular.otf";
        private const string BoldPath =
            "Assets/Game/Presentation/Common/Resources/Fonts/Pretendard-Bold.otf";

        [Test]
        public void BundledFontsCoverEveryHangulGlyphUsedByCopyAndGameplayCatalogs()
        {
            Font regular = AssetDatabase.LoadAssetAtPath<Font>(RegularPath);
            Font bold = AssetDatabase.LoadAssetAtPath<Font>(BoldPath);
            Assert.That(regular, Is.Not.Null, RegularPath);
            Assert.That(bold, Is.Not.Null, BoldPath);

            var glyphs = new HashSet<char>();
            AddHangulFromFiles(glyphs, "Assets/Game/Content", "*.json");
            AddHangulFromFiles(glyphs, "Assets/Game/Core", "*.cs");
            AddHangulFromFiles(glyphs, "Assets/Game/Application", "*.cs");
            AddHangulFromFiles(glyphs, "Assets/Game/Presentation", "*.cs");

            foreach (char glyph in glyphs)
            {
                Assert.That(regular.HasCharacter(glyph), Is.True, "Regular 누락 글리프: " + glyph);
                Assert.That(bold.HasCharacter(glyph), Is.True, "Bold 누락 글리프: " + glyph);
            }
            Assert.That(glyphs.Count, Is.GreaterThan(300), "검사할 한국어 콘텐츠가 비정상적으로 적습니다.");
        }

        [Test]
        public void RuntimePanelUsesBundledDefaultAndFallbackTextSettings()
        {
            string host = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellHost.cs");
            string settings = File.ReadAllText("Assets/Game/Presentation/Common/KoreanFontTextSettings.cs");
            string license = File.ReadAllText(
                "Assets/Game/Presentation/Common/Resources/Fonts/LICENSE.txt");
            StringAssert.Contains("panelSettings.textSettings = KoreanFontTextSettings.Create()", host);
            StringAssert.Contains("defaultFontAsset", settings);
            StringAssert.Contains("fallbackFontAssets", settings);
            StringAssert.Contains("useModernHangulLineBreakingRules = true", settings);
            StringAssert.Contains("SIL OPEN FONT LICENSE", license);
        }

        private static void AddHangulFromFiles(HashSet<char> glyphs, string root, string pattern)
        {
            foreach (string file in Directory.GetFiles(root, pattern, SearchOption.AllDirectories))
            {
                foreach (char value in File.ReadAllText(file))
                {
                    if ((value >= '\u1100' && value <= '\u11ff') ||
                        (value >= '\u3130' && value <= '\u318f') ||
                        (value >= '\uac00' && value <= '\ud7af'))
                    {
                        glyphs.Add(value);
                    }
                }
            }
        }
    }
}
