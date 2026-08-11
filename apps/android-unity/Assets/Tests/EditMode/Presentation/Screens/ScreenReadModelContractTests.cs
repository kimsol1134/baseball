using System;
using System.Collections.Generic;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ScreenReadModelContractTests
    {
        private IBaseballCareerReadModel _readModel;

        [SetUp]
        public void SetUp()
        {
            TextAsset source = AssetDatabase.LoadAssetAtPath<TextAsset>(
                "Assets/Game/Content/ko-KR/Resources/ui-copy-ko-KR.json");
            Assert.That(source, Is.Not.Null, "한국어 UI 카탈로그가 Unity Asset으로 import되어야 합니다.");
            var catalog = KoreanUiCopyCatalog.FromJson(source.text);
            Assert.That(catalog.Locale, Is.EqualTo("ko-KR"));
            _readModel = new MockBaseballCareerReadModel(catalog);
        }

        [Test]
        public void EveryRouteHasACompleteKoreanViewModel()
        {
            ShellRoute[] routes = (ShellRoute[])Enum.GetValues(typeof(ShellRoute));
            Assert.That(_readModel.Routes, Has.Count.EqualTo(routes.Length));
            foreach (ShellRoute route in routes)
            {
                BaseballScreenViewModel screen = _readModel.Read(route);
                Assert.That(screen.Route, Is.EqualTo(route));
                Assert.That(screen.Title, Is.Not.Empty, route.ToString());
                Assert.That(ContainsHangul(screen.Title), Is.True, route + " 제목은 한국어여야 합니다.");
                Assert.That(screen.AppBarTitle, Is.Not.Empty, route.ToString());
                Assert.That(screen.Sections, Is.Not.Empty, route.ToString());
                foreach (ScreenSectionViewModel section in screen.Sections)
                {
                    Assert.That(ContainsHangul(section.Heading), Is.True, route + "/" + section.Id);
                    Assert.That(section.Rows, Is.Not.Empty, route + "/" + section.Id);
                }
                foreach (ScreenActionViewModel action in screen.Actions)
                {
                    Assert.That(ContainsHangul(action.Label), Is.True, route + "/" + action.Id);
                }
            }
        }

        [Test]
        public void StableIdsAreUniqueWithinEveryScreen()
        {
            foreach (ShellRoute route in _readModel.Routes)
            {
                BaseballScreenViewModel screen = _readModel.Read(route);
                var ids = new HashSet<string>(StringComparer.Ordinal);
                foreach (ScreenSectionViewModel section in screen.Sections)
                {
                    Assert.That(ids.Add("section-" + section.Id), Is.True, route + "/" + section.Id);
                    foreach (ScreenRowViewModel row in section.Rows)
                    {
                        Assert.That(ids.Add("row-" + row.Id), Is.True, route + "/" + row.Id);
                    }
                }
                foreach (ScreenActionViewModel action in screen.Actions)
                {
                    Assert.That(ids.Add("action-" + action.Id), Is.True, route + "/" + action.Id);
                }
            }
        }

        [Test]
        public void MainCareerFlowIsActuallyConnected()
        {
            ShellRoute[] expected =
            {
                ShellRoute.Opening,
                ShellRoute.Setup,
                ShellRoute.Prologue,
                ShellRoute.HighSchoolOverview,
                ShellRoute.Training,
                ShellRoute.Relationship,
                ShellRoute.ImportantGame,
                ShellRoute.PitchHandoff,
                ShellRoute.Awakening,
                ShellRoute.Draft,
                ShellRoute.RunRecap,
                ShellRoute.ProContract,
                ShellRoute.ProWeek,
                ShellRoute.ProSeason,
                ShellRoute.ProRetirement,
                ShellRoute.Records,
            };

            for (int index = 0; index < expected.Length - 1; index++)
            {
                BaseballScreenViewModel screen = _readModel.Read(expected[index]);
                Assert.That(
                    HasActionTo(screen, expected[index + 1]),
                    Is.True,
                    expected[index] + " 화면에서 " + expected[index + 1] + " 화면으로 갈 수 있어야 합니다.");
            }
        }

        [Test]
        public void SecondarySurfacesAreReachableFromBottomDestinations()
        {
            Assert.That(HasActionTo(_readModel.Read(ShellRoute.Daily), ShellRoute.Weekly), Is.True);
            Assert.That(HasActionTo(_readModel.Read(ShellRoute.Records), ShellRoute.League), Is.True);
            Assert.That(HasActionTo(_readModel.Read(ShellRoute.Records), ShellRoute.Achievements), Is.True);
            Assert.That(HasActionTo(_readModel.Read(ShellRoute.Records), ShellRoute.LifeArchive), Is.True);
            Assert.That(HasActionTo(_readModel.Read(ShellRoute.LifeArchive), ShellRoute.LifeCard), Is.True);
        }

        [Test]
        public void EveryRouteHasAController()
        {
            foreach (ShellRoute route in _readModel.Routes)
            {
                using (IBaseballScreenController controller = BaseballScreenControllerFactory.Create(route))
                {
                    Assert.That(controller.Route, Is.EqualTo(route));
                }
            }
        }

        private static bool HasActionTo(BaseballScreenViewModel screen, ShellRoute target)
        {
            foreach (ScreenActionViewModel action in screen.Actions)
            {
                if (action.Target == target) return true;
            }
            return false;
        }

        private static bool ContainsHangul(string value)
        {
            foreach (char character in value)
            {
                if (character >= '\uac00' && character <= '\ud7a3') return true;
            }
            return false;
        }
    }
}
