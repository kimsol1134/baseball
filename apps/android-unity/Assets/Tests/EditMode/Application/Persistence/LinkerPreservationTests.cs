using System;
using System.IO;
using System.Linq;
using System.Xml.Linq;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class LinkerPreservationTests
    {
        [Test]
        public void LinkXml_PreservesEveryNewtonsoftReflectionAssemblyForIl2Cpp()
        {
            var path = FindFromWorkspace(
                "apps/android-unity/Assets/Game/Application/Persistence/link.xml");
            var document = XDocument.Load(path);
            var preserved = document.Root
                .Elements("assembly")
                .Where(value => string.Equals(
                    (string)value.Attribute("preserve"), "all", StringComparison.Ordinal))
                .Select(value => (string)value.Attribute("fullname"))
                .ToArray();

            Assert.That(preserved, Is.SupersetOf(new[]
            {
                "Baseball.Core",
                "Baseball.Application",
                "Baseball.Presentation",
                "Unity.Newtonsoft.Json"
            }), "IL2CPP must retain career and pitch DTO constructors used through Newtonsoft");
        }

        private static string FindFromWorkspace(string relativePath)
        {
            var directory = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (directory != null)
            {
                var candidate = Path.Combine(directory.FullName, relativePath);
                if (File.Exists(candidate)) return candidate;
                directory = directory.Parent;
            }
            throw new FileNotFoundException(relativePath);
        }
    }
}
