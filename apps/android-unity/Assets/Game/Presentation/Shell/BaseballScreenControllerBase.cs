using System;
using System.Collections.Generic;
using System.Threading;
using Baseball.Presentation.Common;
using UnityEngine;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Shell
{
    public abstract class BaseballScreenControllerBase : IBaseballScreenController
    {
        private readonly string _resourceName;
        private VisualElement _screenRoot;
        private CancellationTokenSource _assetLifetime;
        private IBaseballVisualAssetLease _keyArtLease;
        private readonly List<ViewportExposureObserver> _exposureObservers =
            new List<ViewportExposureObserver>();

        protected BaseballScreenControllerBase(ShellRoute route, string resourceName)
        {
            Route = route;
            _resourceName = resourceName;
        }

        public ShellRoute Route { get; private set; }

        protected void SetRoute(ShellRoute route)
        {
            Route = route;
        }

        public void Mount(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            if (host == null) throw new ArgumentNullException(nameof(host));
            if (viewModel == null) throw new ArgumentNullException(nameof(viewModel));
            if (navigator == null) throw new ArgumentNullException(nameof(navigator));
            SetRoute(viewModel.Route);
            host.Clear();
            DisposeExposureObservers();

            VisualTreeAsset template = Resources.Load<VisualTreeAsset>(_resourceName);
            if (template == null) throw new InvalidOperationException($"UI Toolkit 화면 템플릿을 찾을 수 없습니다: {_resourceName}");
            template.CloneTree(host);
            _screenRoot = host.Q<VisualElement>("screen-root") ?? host;
            _assetLifetime = new CancellationTokenSource();

            Label eyebrow = Require<Label>(host, "screen-eyebrow");
            Label title = Require<Label>(host, "screen-title");
            Label lead = Require<Label>(host, "screen-lead");
            eyebrow.text = viewModel.Eyebrow;
            title.text = viewModel.Title;
            lead.text = viewModel.Lead;
            eyebrow.style.display = string.IsNullOrWhiteSpace(viewModel.Eyebrow) ? DisplayStyle.None : DisplayStyle.Flex;
            lead.style.display = string.IsNullOrWhiteSpace(viewModel.Lead) ? DisplayStyle.None : DisplayStyle.Flex;
            BaseballAccessibility.Configure(
                title,
                StableId(viewModel.Route, "title"),
                viewModel.Title,
                AccessibilityRole.Header,
                hint: viewModel.Lead,
                focusable: true);

            VisualElement customHost = Require<VisualElement>(host, "screen-custom");
            AddCustomContent(customHost, viewModel, navigator);
            LoadKeyArt(host, viewModel, navigator);

            VisualElement sectionHost = Require<VisualElement>(host, "screen-sections");
            if (UsesStandardSections(viewModel))
            {
                foreach (ScreenSectionViewModel section in viewModel.Sections)
                {
                    VisualElement sectionElement = CreateSection(section, viewModel.Route);
                    sectionHost.Add(sectionElement);
                    TrackContentExposure(
                        sectionElement,
                        section.Id,
                        SectionExposureInstance(section),
                        navigator);
                }
            }

            VisualElement actionHost = Require<VisualElement>(host, "screen-actions");
            foreach (ScreenActionViewModel action in viewModel.Actions)
            {
                actionHost.Add(CreateAction(action, viewModel.Route, navigator));
            }

            OnMounted(_screenRoot, viewModel, navigator);
        }

        protected virtual void AddCustomContent(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.None;
        }

        protected virtual void OnMounted(
            VisualElement screenRoot,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
        }

        /// <summary>
        /// Large collections can supply a virtualized custom surface without first constructing
        /// every standard row under the enclosing ScrollView.
        /// </summary>
        protected virtual bool UsesStandardSections(BaseballScreenViewModel viewModel) => true;

        public virtual void Dispose()
        {
            DisposeExposureObservers();
            _assetLifetime?.Cancel();
            _assetLifetime?.Dispose();
            _assetLifetime = null;
            _keyArtLease?.Dispose();
            _keyArtLease = null;
            _screenRoot = null;
        }

        protected void TrackContentExposure(
            VisualElement element,
            string contentId,
            string instanceId,
            IShellNavigator navigator)
        {
            IBaseballContentExposure exposure = navigator as IBaseballContentExposure;
            if (element == null || exposure == null || string.IsNullOrWhiteSpace(contentId) ||
                string.IsNullOrWhiteSpace(instanceId)) return;
            ScrollView scroll = element.GetFirstAncestorOfType<ScrollView>() ??
                _screenRoot?.Q<ScrollView>("screen-scroll");
            _exposureObservers.Add(new ViewportExposureObserver(
                element,
                scroll,
                () => exposure.OnContentVisible(Route, contentId, instanceId)));
        }

        protected static string SectionExposureInstance(ScreenSectionViewModel section)
        {
            string instance = section?.Id ?? string.Empty;
            if (section?.Rows == null) return instance;
            foreach (ScreenRowViewModel row in section.Rows)
            {
                instance += "|" + row.Id + "|" + row.Label + "|" + row.Value + "|" + row.Detail;
            }
            return instance;
        }

        private void DisposeExposureObservers()
        {
            foreach (ViewportExposureObserver observer in _exposureObservers) observer.Dispose();
            _exposureObservers.Clear();
        }

        private async void LoadKeyArt(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            if (string.IsNullOrWhiteSpace(viewModel.KeyArtAddress)) return;
            IBaseballVisualAssetLoader loader = (navigator as IBaseballVisualAssets)?.VisualAssetLoader;
            if (loader == null) return;
            CancellationToken token = _assetLifetime.Token;
            try
            {
                IBaseballVisualAssetLease lease = await loader.LoadSpriteAsync(viewModel.KeyArtAddress, token);
                if (token.IsCancellationRequested || lease?.Sprite == null)
                {
                    lease?.Dispose();
                    return;
                }
                _keyArtLease = lease;
                var image = new Image
                {
                    name = StableId(viewModel.Route, "key-art"),
                    sprite = lease.Sprite,
                    scaleMode = ScaleMode.ScaleAndCrop,
                };
                image.AddToClassList("screen-key-art");
                BaseballAccessibility.HideDecoration(image);
                VisualElement dedicatedHost = host.Q<VisualElement>("screen-key-art-host");
                ScrollView scroll = host.Q<ScrollView>("screen-scroll");
                (dedicatedHost ?? scroll?.contentContainer ?? _screenRoot).Insert(0, image);
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested)
            {
            }
            catch
            {
                // Imported art is enhancement-only. Text UI remains fully usable if loading fails.
            }
        }

        protected static string StableId(ShellRoute route, string suffix)
        {
            return "screen-" + route.ToString().ToLowerInvariant() + "-" + suffix;
        }

        private static VisualElement CreateSection(ScreenSectionViewModel section, ShellRoute route)
        {
            VisualElement content;
            VisualElement container;
            if (section.Tone == ScreenSectionTone.Plain)
            {
                var standard = new BaseballSection(section.Heading, StableId(route, "section-" + section.Id));
                container = standard;
                content = standard.Content;
            }
            else
            {
                var callout = new BaseballCallout(
                    section.Heading,
                    MapTone(section.Tone),
                    StableId(route, "section-" + section.Id));
                container = callout;
                content = callout.Content;
            }

            foreach (ScreenRowViewModel row in section.Rows) content.Add(CreateRow(row, route));
            return container;
        }

        private static VisualElement CreateRow(ScreenRowViewModel row, ShellRoute route)
        {
            var root = new VisualElement();
            root.AddToClassList("screen-data-row");
            var copyColumn = new VisualElement();
            copyColumn.AddToClassList("screen-data-row__copy");
            var label = new Label(row.Label);
            label.AddToClassList("screen-data-row__label");
            copyColumn.Add(label);
            if (!string.IsNullOrWhiteSpace(row.Detail))
            {
                var detail = new Label(row.Detail);
                detail.AddToClassList("screen-data-row__detail");
                copyColumn.Add(detail);
            }
            root.Add(copyColumn);
            if (!string.IsNullOrWhiteSpace(row.Value))
            {
                var value = new Label(row.Value);
                value.AddToClassList("screen-data-row__value");
                root.Add(value);
            }
            string summary = row.Label;
            if (!string.IsNullOrWhiteSpace(row.Value)) summary += ", " + row.Value;
            if (!string.IsNullOrWhiteSpace(row.Detail)) summary += ". " + row.Detail;
            BaseballAccessibility.Configure(
                root,
                StableId(route, "row-" + row.Id),
                summary,
                AccessibilityRole.StaticText,
                focusable: true);
            return root;
        }

        private static VisualElement CreateAction(ScreenActionViewModel action, ShellRoute route, IShellNavigator navigator)
        {
            Action activate = () =>
            {
                if (!action.IsEnabled)
                {
                    navigator.Announce(string.IsNullOrWhiteSpace(action.DisabledReason) ? action.Hint : action.DisabledReason);
                }
                else if (action.RequiresConfirmation) navigator.ShowConfirmation(action);
                else navigator.Execute(action);
            };
            string stableId = StableId(route, "action-" + action.Id);
            VisualElement button;
            switch (action.Style)
            {
                case ScreenActionStyle.Primary:
                    button = new PrimaryPill(action.Label, stableId, activate);
                    break;
                case ScreenActionStyle.Destructive:
                    button = new DestructiveButton(action.Label, stableId, activate);
                    break;
                default:
                    button = new SecondaryButton(action.Label, stableId, activate);
                    break;
            }
            button.tooltip = string.IsNullOrWhiteSpace(action.Hint) ? action.Label : action.Hint;
            button.SetEnabled(action.IsEnabled);
            return button;
        }

        private static BaseballCalloutTone MapTone(ScreenSectionTone tone)
        {
            switch (tone)
            {
                case ScreenSectionTone.Positive: return BaseballCalloutTone.Positive;
                case ScreenSectionTone.Warning: return BaseballCalloutTone.Warning;
                case ScreenSectionTone.Milestone: return BaseballCalloutTone.Milestone;
                default: return BaseballCalloutTone.Information;
            }
        }

        private static T Require<T>(VisualElement root, string name) where T : VisualElement
        {
            T element = root.Q<T>(name);
            if (element == null) throw new InvalidOperationException($"UI Toolkit 요소를 찾을 수 없습니다: {name}");
            return element;
        }
    }
}
