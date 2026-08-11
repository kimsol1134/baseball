using System;
using System.Threading;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

namespace Baseball.Presentation.Shell
{
    /// <summary>Loads imported local Addressables without creating Resources duplicates.</summary>
    public sealed class AddressableVisualAssetLoader : IBaseballVisualAssetLoader
    {
        public async Task<IBaseballVisualAssetLease> LoadSpriteAsync(
            string address,
            CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(address))
                throw new ArgumentException("An Addressables key is required.", nameof(address));
            cancellationToken.ThrowIfCancellationRequested();
            AsyncOperationHandle<Sprite> handle = Addressables.LoadAssetAsync<Sprite>(address);
            try
            {
                Sprite sprite = await handle.Task;
                cancellationToken.ThrowIfCancellationRequested();
                if (handle.Status != AsyncOperationStatus.Succeeded || sprite == null)
                    throw new InvalidOperationException("asset.addressable_load_failed:" + address);
                return new Lease(handle, sprite);
            }
            catch
            {
                if (handle.IsValid()) Addressables.Release(handle);
                throw;
            }
        }

        private sealed class Lease : IBaseballVisualAssetLease
        {
            private AsyncOperationHandle<Sprite> _handle;
            private bool _disposed;

            public Lease(AsyncOperationHandle<Sprite> handle, Sprite sprite)
            {
                _handle = handle;
                Sprite = sprite;
            }

            public Sprite Sprite { get; }

            public void Dispose()
            {
                if (_disposed) return;
                if (_handle.IsValid()) Addressables.Release(_handle);
                _disposed = true;
            }
        }
    }
}
