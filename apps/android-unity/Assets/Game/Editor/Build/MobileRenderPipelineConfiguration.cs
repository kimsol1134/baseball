using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Baseball.Editor
{
    /// <summary>Creates and assigns the single local-only mobile URP asset used by Android builds.</summary>
    public static class MobileRenderPipelineConfiguration
    {
        private const string AssetDirectory = "Assets/Game/Rendering";
        private const string AssetPath = AssetDirectory + "/BaseballMobileURP.asset";

        public static void EnsureConfigured()
        {
            UniversalRenderPipelineAsset pipeline = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(AssetPath);
            if (pipeline == null)
            {
                Directory.CreateDirectory(AssetDirectory);
                pipeline = UniversalRenderPipelineAsset.Create();
                pipeline.name = "Baseball Mobile URP";
                AssetDatabase.CreateAsset(pipeline, AssetPath);

                if (pipeline.rendererDataList.Length != 1 || pipeline.rendererDataList[0] == null)
                {
                    throw new BuildFailedException("The mobile URP asset did not create its default renderer data.");
                }

                ScriptableRendererData rendererData = pipeline.rendererDataList[0];
                rendererData.name = "Baseball Mobile Renderer";
                AssetDatabase.AddObjectToAsset(rendererData, pipeline);
            }

            pipeline.supportsHDR = false;
            pipeline.supportsCameraDepthTexture = false;
            pipeline.supportsCameraOpaqueTexture = false;
            pipeline.msaaSampleCount = 1;
            pipeline.renderScale = 1f;
            pipeline.shadowDistance = 0f;
            pipeline.maxAdditionalLightsCount = 0;
            pipeline.supportsDynamicBatching = true;

            GraphicsSettings.defaultRenderPipeline = pipeline;
            QualitySettings.renderPipeline = pipeline;
            EditorUtility.SetDirty(pipeline);
            AssetDatabase.SaveAssets();

            if (!ReferenceEquals(GraphicsSettings.defaultRenderPipeline, pipeline)
                || !ReferenceEquals(QualitySettings.renderPipeline, pipeline))
            {
                throw new BuildFailedException("The Android player and Mobile quality tier must both use Baseball Mobile URP.");
            }
        }
    }
}
