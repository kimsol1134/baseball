using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using NUnit.Framework;
using UnityEngine;

namespace Baseball.Presentation.Tests
{
    public sealed class DesignSystemLintTests
    {
        private static readonly Regex RawColor = new Regex(
            @"(?:#[0-9a-fA-F]{6,8}\b|\b0x[0-9a-fA-F]{6,8}\b)",
            RegexOptions.Compiled);

        [Test]
        public void PresentationRawColorsOnlyExistInThemeSources()
        {
            string root = Path.Combine(UnityEngine.Application.dataPath, "Game", "Presentation");
            var violations = new List<string>();
            foreach (string file in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories)
                         .Where(IsPresentationSource))
            {
                string normalized = file.Replace('\\', '/');
                if (normalized.EndsWith("/Common/BaseballTheme.cs") || normalized.EndsWith("/Common/theme.uss")) continue;
                int lineNumber = 0;
                foreach (string line in File.ReadLines(file))
                {
                    lineNumber++;
                    if (RawColor.IsMatch(line)) violations.Add($"{normalized}:{lineNumber}");
                }
            }
            Assert.That(violations, Is.Empty, "Move raw colors to BaseballTheme.cs and theme.uss: " + string.Join(", ", violations));
        }

        [Test]
        public void ThemeDefinesNormalAndHighContrastTokens()
        {
            string theme = File.ReadAllText(Path.Combine(
                UnityEngine.Application.dataPath,
                "Game",
                "Presentation",
                "Common",
                "theme.uss"));
            Assert.That(theme, Does.Contain(".baseball-theme.baseball-high-contrast"));
            Assert.That(theme, Does.Contain("--baseball-action: #b7f36b"));
            Assert.That(theme, Does.Contain("--baseball-action: #d3ff82"));
            Assert.That(theme, Does.Contain("--baseball-font-display"));
            Assert.That(theme, Does.Contain(".baseball-reduced-motion"));
            Assert.That(theme, Does.Not.Contain("border-left-width"), "A repeated left accent rail is not a common card pattern.");
        }

        [Test]
        public void EveryPaletteTokenResolvesInBothModes()
        {
            foreach (Baseball.Presentation.Common.BaseballColorToken token in
                     System.Enum.GetValues(typeof(Baseball.Presentation.Common.BaseballColorToken)))
            {
                Assert.That(Baseball.Presentation.Common.BaseballTheme.Resolve(token).a, Is.EqualTo(255), token.ToString());
                Assert.That(Baseball.Presentation.Common.BaseballTheme.Resolve(token, true).a, Is.EqualTo(255), $"{token} high contrast");
            }
        }

        private static bool IsPresentationSource(string path)
        {
            string extension = Path.GetExtension(path).ToLowerInvariant();
            return extension == ".cs" || extension == ".uss" || extension == ".uxml";
        }
    }
}
