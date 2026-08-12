using System;
using System.Threading;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    /// <summary>
    /// Meaningful local-only artwork with an explicit text fallback. The element owns the
    /// Addressables lease and releases it whenever its screen is detached.
    /// </summary>
    public sealed class AddressableContentImage : VisualElement, IDisposable
    {
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly Image _image;
        private readonly Label _fallback;
        private IBaseballVisualAssetLease _lease;
        private bool _disposed;

        public AddressableContentImage(
            string address,
            string accessibilityLabel,
            string stableId,
            IBaseballVisualAssetLoader loader,
            bool compact = false)
        {
            name = stableId;
            AddToClassList(compact
                ? "baseball-content-image--compact"
                : "baseball-content-image");
            _image = new Image
            {
                name = stableId + "-image",
                scaleMode = ScaleMode.ScaleAndCrop,
            };
            _image.AddToClassList("baseball-content-image__image");
            _image.style.display = DisplayStyle.None;
            BaseballAccessibility.Configure(
                _image,
                stableId + "-image",
                accessibilityLabel,
                AccessibilityRole.Image,
                hint: "화면 설명을 돕는 게임 삽화입니다.",
                focusable: true);
            Add(_image);

            _fallback = new Label("삽화를 불러오는 중입니다.");
            _fallback.AddToClassList("baseball-content-image__fallback");
            BaseballAccessibility.Configure(
                _fallback,
                stableId + "-fallback",
                accessibilityLabel + " 삽화 상태",
                AccessibilityRole.StaticText,
                value: _fallback.text,
                focusable: true);
            Add(_fallback);
            RegisterCallback<DetachFromPanelEvent>(_ => Dispose());

            if (loader == null || !BaseballVisualContentCatalog.IsLocalOnlyAddress(address))
            {
                ShowFallback();
                return;
            }
            LoadAsync(loader, address);
        }

        public static VisualElement WrapChoice(
            ChoiceCard card,
            string address,
            string accessibilityLabel,
            string stableId,
            IBaseballVisualAssetLoader loader)
        {
            if (card == null) throw new ArgumentNullException(nameof(card));
            var wrapper = new VisualElement { name = stableId };
            wrapper.AddToClassList("baseball-visual-choice");
            wrapper.Add(new AddressableContentImage(
                address,
                accessibilityLabel,
                stableId + "-art",
                loader,
                compact: true));
            wrapper.Add(card);
            return wrapper;
        }

        public static VisualElement WrapChoiceGallery(
            ChoiceCard card,
            string primaryAddress,
            string primaryLabel,
            string secondaryAddress,
            string secondaryLabel,
            string stableId,
            IBaseballVisualAssetLoader loader)
        {
            if (card == null) throw new ArgumentNullException(nameof(card));
            var wrapper = new VisualElement { name = stableId };
            wrapper.AddToClassList("baseball-visual-choice");
            var gallery = new VisualElement { name = stableId + "-gallery" };
            gallery.AddToClassList("baseball-visual-choice__gallery");
            gallery.Add(new AddressableContentImage(
                primaryAddress,
                primaryLabel,
                stableId + "-primary-art",
                loader,
                compact: true));
            gallery.Add(new AddressableContentImage(
                secondaryAddress,
                secondaryLabel,
                stableId + "-secondary-art",
                loader,
                compact: true));
            wrapper.Add(gallery);
            wrapper.Add(card);
            return wrapper;
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            _lifetime.Cancel();
            _lifetime.Dispose();
            _lease?.Dispose();
            _lease = null;
        }

        private async void LoadAsync(IBaseballVisualAssetLoader loader, string address)
        {
            try
            {
                IBaseballVisualAssetLease lease = await loader.LoadSpriteAsync(
                    address,
                    _lifetime.Token);
                if (_disposed || _lifetime.IsCancellationRequested || lease?.Sprite == null)
                {
                    lease?.Dispose();
                    if (!_disposed) ShowFallback();
                    return;
                }
                _lease = lease;
                _image.sprite = lease.Sprite;
                _image.style.display = DisplayStyle.Flex;
                _fallback.style.display = DisplayStyle.None;
            }
            catch (OperationCanceledException) when (_lifetime.IsCancellationRequested)
            {
            }
            catch
            {
                if (!_disposed) ShowFallback();
            }
        }

        private void ShowFallback()
        {
            _image.style.display = DisplayStyle.None;
            _fallback.text = "삽화를 불러오지 못했습니다. 선택과 저장 상태는 그대로 유지됩니다.";
            _fallback.style.display = DisplayStyle.Flex;
            if (BaseballAccessibility.TryGet(
                    _fallback,
                    out BaseballAccessibilityMetadata metadata))
                metadata.Value = _fallback.text;
        }
    }
}
