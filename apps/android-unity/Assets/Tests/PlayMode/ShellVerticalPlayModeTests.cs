using System;
using System.Collections;
using System.Linq;
using System.Reflection;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using UnityEngine.UIElements;

namespace Baseball.PlayMode.Tests
{
    [TestFixture]
    public sealed class ShellVerticalPlayModeTests
    {
        [UnitySetUp]
        public IEnumerator SetUp()
        {
            foreach (BaseballShellHost host in UnityEngine.Object.FindObjectsByType<BaseballShellHost>(FindObjectsSortMode.None))
            {
                PanelSettings panel = host.GetComponent<UIDocument>()?.panelSettings;
                UnityEngine.Object.Destroy(host.gameObject);
                if (panel != null) UnityEngine.Object.Destroy(panel);
            }
            yield return null;
        }

        [UnityTearDown]
        public IEnumerator TearDown()
        {
            foreach (BaseballShellHost host in UnityEngine.Object.FindObjectsByType<BaseballShellHost>(FindObjectsSortMode.None))
            {
                PanelSettings panel = host.GetComponent<UIDocument>()?.panelSettings;
                UnityEngine.Object.Destroy(host.gameObject);
                if (panel != null) UnityEngine.Object.Destroy(panel);
            }
            yield return null;
        }

        [Test]
        public void EveryRouteBuildsARealScreenAndHardwareBackRestoresHistory()
        {
            IKoreanUiCopyCatalog copy = KoreanUiCopyCatalog.LoadDefault();
            var readModel = new BaseballScreenTemplateReadModel(copy);
            var documentRoot = new VisualElement();
            using (var controller = new BaseballShellController(documentRoot, readModel, copy))
            {
                ShellRoute[] routes = ((ShellRoute[])Enum.GetValues(typeof(ShellRoute)))
                    .Where(route => route != ShellRoute.Daily)
                    .ToArray();
                Assert.That(routes, Has.Length.EqualTo(22));
                Assert.That(readModel.Routes.Count, Is.EqualTo(routes.Length));

                var pitchHandoffs = 0;
                controller.PitchRequested += _ => pitchHandoffs++;
                foreach (ShellRoute route in routes)
                {
                    controller.Navigate(route);
                    Label title = documentRoot.Q<Label>(className: "baseball-display");
                    Assert.That(controller.CurrentRoute, Is.EqualTo(route), route.ToString());
                    Assert.That(title, Is.Not.Null, route + " 화면 제목이 생성되지 않았습니다.");
                    Assert.That(title.text, Is.Not.Empty, route + " 화면 제목이 비었습니다.");
                }
                Assert.That(pitchHandoffs, Is.EqualTo(1));

                controller.Navigate(ShellRoute.Daily);
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Opening),
                    "legacy Daily navigation must normalize without constructing a retired screen");
                Assert.Throws<ArgumentOutOfRangeException>(() => readModel.Read(ShellRoute.Daily));

                controller.Navigate(ShellRoute.Setup);
                controller.Navigate(ShellRoute.Training);
                controller.HandleHardwareBack();
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Setup));
                controller.HandleHardwareBack();
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Opening));
                controller.HandleHardwareBack();
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Settings));
            }
        }

        [UnityTest]
        public IEnumerator RuntimeShellUsesPortraitReferenceResolutionAndSafeAreaInsets()
        {
            MethodInfo ensureShell = typeof(BaseballShellRuntimeBootstrap).GetMethod(
                "EnsureShell",
                BindingFlags.NonPublic | BindingFlags.Static);
            Assert.That(ensureShell, Is.Not.Null);
            ensureShell.Invoke(null, null);
            yield return null;

            BaseballShellHost host = UnityEngine.Object.FindAnyObjectByType<BaseballShellHost>();
            Assert.That(host, Is.Not.Null);
            PanelSettings panel = host.GetComponent<UIDocument>().panelSettings;
            Assert.That(panel, Is.Not.Null);
            Assert.That(panel.themeStyleSheet, Is.Not.Null,
                "production runtime PanelSettings must carry Unity's default control theme");
            Assert.That(panel.referenceResolution, Is.EqualTo(new Vector2Int(390, 844)));
            Assert.That(panel.referenceResolution.x, Is.LessThan(panel.referenceResolution.y));

            BaseballSafeAreaInsets insets = BaseballSafeAreaController.Calculate(
                new Rect(0f, 24f, 390f, 800f),
                new Vector2(390f, 844f),
                new Vector2(390f, 844f));
            Assert.That(insets.Left, Is.Zero.Within(0.001f));
            Assert.That(insets.Top, Is.EqualTo(20f).Within(0.001f));
            Assert.That(insets.Right, Is.Zero.Within(0.001f));
            Assert.That(insets.Bottom, Is.EqualTo(24f).Within(0.001f));
        }
    }
}
