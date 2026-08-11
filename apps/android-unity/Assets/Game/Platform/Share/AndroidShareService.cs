using System;
using System.IO;
using UnityEngine;

namespace Baseball.Platform.Share
{
    public static class AndroidShareService
    {
        public static void ClearShareCache()
        {
            string directory = Path.Combine(UnityEngine.Application.temporaryCachePath, "share");
            try
            {
                if (!Directory.Exists(directory)) return;
                foreach (string file in Directory.GetFiles(directory, "*.png")) File.Delete(file);
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }

        public static bool TryShareText(string chooserTitle, string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return false;
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using AndroidJavaObject intent = NewSendIntent("text/plain");
                using var intentClass = new AndroidJavaClass("android.content.Intent");
                intent.Call<AndroidJavaObject>(
                    "putExtra",
                    intentClass.GetStatic<string>("EXTRA_TEXT"),
                    text);
                return StartChooser(intent, chooserTitle);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                return false;
            }
#else
            return false;
#endif
        }

        public static bool TrySharePng(
            string chooserTitle,
            byte[] pngBytes,
            string suggestedName,
            string shareText)
        {
            if (!SharePayloadPolicy.IsValidPng(pngBytes)) return false;
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                string shareDirectory = Path.Combine(UnityEngine.Application.temporaryCachePath, "share");
                Directory.CreateDirectory(shareDirectory);
                string fileName = SharePayloadPolicy.NormalizePngFileName(suggestedName);
                string path = Path.Combine(shareDirectory, fileName);
                File.WriteAllBytes(path, pngBytes);
                PruneShareCache(shareDirectory, path);

                using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                using AndroidJavaObject activity = player.GetStatic<AndroidJavaObject>("currentActivity");
                string authority = activity.Call<string>("getPackageName") + ".baseball.share";
                using var builder = new AndroidJavaObject("android.net.Uri$Builder");
                builder.Call<AndroidJavaObject>("scheme", "content");
                builder.Call<AndroidJavaObject>("authority", authority);
                builder.Call<AndroidJavaObject>("appendPath", fileName);
                using AndroidJavaObject contentUri = builder.Call<AndroidJavaObject>("build");

                using AndroidJavaObject intent = NewSendIntent("image/png");
                using var intentClass = new AndroidJavaClass("android.content.Intent");
                intent.Call<AndroidJavaObject>(
                    "putExtra",
                    intentClass.GetStatic<string>("EXTRA_STREAM"),
                    contentUri);
                string safeText = SharePayloadPolicy.NormalizeShareText(shareText);
                if (!string.IsNullOrWhiteSpace(safeText))
                {
                    intent.Call<AndroidJavaObject>(
                        "putExtra",
                        intentClass.GetStatic<string>("EXTRA_TEXT"),
                        safeText);
                }
                intent.Call<AndroidJavaObject>(
                    "addFlags",
                    intentClass.GetStatic<int>("FLAG_GRANT_READ_URI_PERMISSION"));

                using AndroidJavaObject clip = new AndroidJavaClass("android.content.ClipData")
                    .CallStatic<AndroidJavaObject>("newRawUri", "공유 이미지", contentUri);
                intent.Call<AndroidJavaObject>("setClipData", clip);
                return StartChooser(intent, chooserTitle);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                return false;
            }
#else
            return false;
#endif
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        private static AndroidJavaObject NewSendIntent(string mimeType)
        {
            var intent = new AndroidJavaObject("android.content.Intent", "android.intent.action.SEND");
            intent.Call<AndroidJavaObject>("setType", mimeType);
            return intent;
        }

        private static bool StartChooser(AndroidJavaObject intent, string chooserTitle)
        {
            using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
            using AndroidJavaObject activity = player.GetStatic<AndroidJavaObject>("currentActivity");
            using var intentClass = new AndroidJavaClass("android.content.Intent");
            using AndroidJavaObject chooser = intentClass.CallStatic<AndroidJavaObject>(
                "createChooser",
                intent,
                string.IsNullOrWhiteSpace(chooserTitle) ? "공유하기" : chooserTitle);
            activity.Call("startActivity", chooser);
            return true;
        }

        private static void PruneShareCache(string directory, string currentPath)
        {
            try
            {
                FileInfo[] files = new DirectoryInfo(directory).GetFiles("*.png");
                Array.Sort(files, (left, right) => right.LastWriteTimeUtc.CompareTo(left.LastWriteTimeUtc));
                for (int index = 8; index < files.Length; index++)
                {
                    if (!string.Equals(files[index].FullName, currentPath, StringComparison.Ordinal)) files[index].Delete();
                }
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
#endif
    }
}
