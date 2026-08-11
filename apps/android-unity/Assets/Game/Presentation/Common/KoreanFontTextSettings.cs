using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.TextCore.LowLevel;
using UnityEngine.TextCore.Text;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    /// <summary>Bundled, deterministic Hangul coverage for every runtime UI Toolkit panel.</summary>
    public static class KoreanFontTextSettings
    {
        public const string RegularResourcePath = "Fonts/Pretendard-Regular";
        public const string BoldResourcePath = "Fonts/Pretendard-Bold";

        public static PanelTextSettings Create()
        {
            Font regular = Resources.Load<Font>(RegularResourcePath);
            Font bold = Resources.Load<Font>(BoldResourcePath);
            if (regular == null || bold == null)
                throw new InvalidOperationException("번들 한국어 폰트를 불러오지 못했습니다.");

            FontAsset regularAsset = CreateDynamicAsset(regular, "Baseball Korean Regular");
            FontAsset boldAsset = CreateDynamicAsset(bold, "Baseball Korean Bold");
            regularAsset.fallbackFontAssetTable = new List<FontAsset> { boldAsset };

            var settings = ScriptableObject.CreateInstance<PanelTextSettings>();
            settings.name = "Baseball Korean UITK Text Settings";
            settings.defaultFontAsset = regularAsset;
            settings.defaultFontAssetPath = "Fonts";
            settings.fallbackFontAssets = new List<FontAsset> { boldAsset };
            settings.missingCharacterUnicode = 0x25A1;
            settings.clearDynamicDataOnBuild = false;
            settings.displayWarnings = true;
            settings.lineBreakingRules = new UnicodeLineBreakingRules
            {
                useModernHangulLineBreakingRules = true,
            };
            return settings;
        }

        private static FontAsset CreateDynamicAsset(Font source, string assetName)
        {
            FontAsset asset = FontAsset.CreateFontAsset(
                source,
                90,
                9,
                GlyphRenderMode.SDFAA,
                2048,
                2048,
                AtlasPopulationMode.Dynamic,
                true);
            if (asset == null) throw new InvalidOperationException("한국어 동적 폰트 에셋을 만들지 못했습니다.");
            asset.name = assetName;
            asset.isMultiAtlasTexturesEnabled = true;
            return asset;
        }
    }
}
