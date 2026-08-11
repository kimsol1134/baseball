using System;
using UnityEngine;

namespace Baseball.Presentation.Common
{
    public enum BaseballColorToken
    {
        Canvas,
        Surface,
        SurfaceRaised,
        SurfaceSoft,
        Border,
        BorderStrong,
        TextPrimary,
        TextSecondary,
        TextTertiary,
        Action,
        ActionStrong,
        ActionSoft,
        ActionInk,
        Selection,
        SelectionSoft,
        Milestone,
        MilestoneSoft,
        Positive,
        PositiveSoft,
        Warning,
        WarningSoft,
        Negative,
        NegativeSoft,
        Information,
        InformationSoft,
        FieldNight,
        FieldDirt,
        FieldChalk,
        TeamBlue,
        TeamNavy,
        TeamGold,
        TeamRed,
        TeamTeal,
        TeamOrange,
        TeamViolet,
        TeamSilver,
    }

    public enum BaseballAvatarColorToken
    {
        Skin1,
        Skin2,
        Skin3,
        Skin4,
        Skin5,
        Hair1,
        Hair2,
        Hair3,
        HairGray,
        Jersey1,
        Jersey2,
        Jersey3,
        Jersey4,
        Jersey5,
        Cap,
        CapBrim,
        Helmet,
        Mask,
        Line,
        Highlight,
    }

    /// <summary>
    /// The C# source of truth for the Midnight Dugout palette. Raw color values are intentionally
    /// confined to this file and theme.uss. Avatar materials are illustration colors, not UI state.
    /// </summary>
    public static class BaseballTheme
    {
        public static Color32 Resolve(BaseballColorToken token, bool highContrast = false)
        {
            switch (token)
            {
                case BaseballColorToken.Canvas: return Fixed(0x080D0B, 0x020503, highContrast);
                case BaseballColorToken.Surface: return Fixed(0x101815, 0x070B09, highContrast);
                case BaseballColorToken.SurfaceRaised: return Fixed(0x17231E, 0x0B120E, highContrast);
                case BaseballColorToken.SurfaceSoft: return Fixed(0x1E2B25, 0x111A15, highContrast);
                case BaseballColorToken.Border: return Fixed(0x3F554B, 0xC1CEC7, highContrast);
                case BaseballColorToken.BorderStrong: return Fixed(0x5F736A, 0xE2E8E4, highContrast);
                case BaseballColorToken.TextPrimary: return Fixed(0xF1F4EE, 0xFFFFFF, highContrast);
                case BaseballColorToken.TextSecondary: return Fixed(0xB4C1BB, 0xE2E8E4, highContrast);
                case BaseballColorToken.TextTertiary: return Fixed(0x84968E, 0xC8D2CC, highContrast);
                case BaseballColorToken.Action: return Fixed(0xB7F36B, 0xD3FF82, highContrast);
                case BaseballColorToken.ActionStrong: return Fixed(0x96DC4E, 0xB7F36B, highContrast);
                case BaseballColorToken.ActionSoft: return Fixed(0x243A20, 0x16240F, highContrast);
                case BaseballColorToken.ActionInk: return Fixed(0x10200D, 0x000000, highContrast);
                case BaseballColorToken.Selection: return Fixed(0x86C96A, 0xB9ED8D, highContrast);
                case BaseballColorToken.SelectionSoft: return Fixed(0x1B2F20, 0x0E1C11, highContrast);
                case BaseballColorToken.Milestone: return Fixed(0xD8B565, 0xFFE08A, highContrast);
                case BaseballColorToken.MilestoneSoft: return Fixed(0x211D14, 0x14110A, highContrast);
                case BaseballColorToken.Positive: return Fixed(0x55C58A, 0x78E6AB, highContrast);
                case BaseballColorToken.PositiveSoft: return Fixed(0x14271D, 0x0A1710, highContrast);
                case BaseballColorToken.Warning: return Fixed(0xF0A94A, 0xFFC66D, highContrast);
                case BaseballColorToken.WarningSoft: return Fixed(0x251D12, 0x17110A, highContrast);
                case BaseballColorToken.Negative: return Fixed(0xEF746A, 0xFF9A91, highContrast);
                case BaseballColorToken.NegativeSoft: return Fixed(0x261816, 0x180D0C, highContrast);
                case BaseballColorToken.Information: return Fixed(0x67B6C1, 0x8ED9E2, highContrast);
                case BaseballColorToken.InformationSoft: return Fixed(0x163036, 0x0B1E22, highContrast);
                case BaseballColorToken.FieldNight: return Fixed(0x050A15, 0x000000, highContrast);
                case BaseballColorToken.FieldDirt: return Fixed(0x6B5236, 0xC7A87E, highContrast);
                case BaseballColorToken.FieldChalk: return Fixed(0xDCE5DE, 0xFFFFFF, highContrast);
                case BaseballColorToken.TeamBlue: return Fixed(0x5D8FD7, 0x8FBAFF, highContrast);
                case BaseballColorToken.TeamNavy: return Fixed(0x7189A2, 0xA8BDD2, highContrast);
                case BaseballColorToken.TeamGold: return Fixed(0xD3A64C, 0xFFD36D, highContrast);
                case BaseballColorToken.TeamRed: return Fixed(0xD76C68, 0xFF9691, highContrast);
                case BaseballColorToken.TeamTeal: return Fixed(0x52AA9E, 0x7EE0D0, highContrast);
                case BaseballColorToken.TeamOrange: return Fixed(0xD8894E, 0xFFB477, highContrast);
                case BaseballColorToken.TeamViolet: return Fixed(0x9A82D2, 0xC4A9FF, highContrast);
                case BaseballColorToken.TeamSilver: return Fixed(0xAAB5B0, 0xD7E0DC, highContrast);
                default: throw new ArgumentOutOfRangeException(nameof(token), token, null);
            }
        }

        public static Color32 TeamDecoration(string teamId, bool highContrast = false)
        {
            switch (teamId)
            {
                case "busan_marines": return Resolve(BaseballColorToken.TeamGold, highContrast);
                case "daegu_forge":
                case "jeonju_hanok": return Resolve(BaseballColorToken.TeamTeal, highContrast);
                case "daejeon_rockets": return Resolve(BaseballColorToken.TeamOrange, highContrast);
                case "gwangju_phoenix": return Resolve(BaseballColorToken.TeamRed, highContrast);
                case "suwon_guardians": return Resolve(BaseballColorToken.TeamNavy, highContrast);
                case "changwon_meteors": return Resolve(BaseballColorToken.TeamViolet, highContrast);
                case "jeju_storm": return Resolve(BaseballColorToken.TeamSilver, highContrast);
                default: return Resolve(BaseballColorToken.TeamBlue, highContrast);
            }
        }

        public static Color32 ResolveAvatar(BaseballAvatarColorToken token)
        {
            switch (token)
            {
                case BaseballAvatarColorToken.Skin1: return FromRgb(0xF2CFA5);
                case BaseballAvatarColorToken.Skin2: return FromRgb(0xE8BD8F);
                case BaseballAvatarColorToken.Skin3: return FromRgb(0xD9A878);
                case BaseballAvatarColorToken.Skin4: return FromRgb(0xC98E5F);
                case BaseballAvatarColorToken.Skin5: return FromRgb(0xB97A4E);
                case BaseballAvatarColorToken.Hair1: return FromRgb(0x20242B);
                case BaseballAvatarColorToken.Hair2: return FromRgb(0x3A2D22);
                case BaseballAvatarColorToken.Hair3: return FromRgb(0x54402C);
                case BaseballAvatarColorToken.HairGray: return FromRgb(0x6D6F76);
                case BaseballAvatarColorToken.Jersey1: return FromRgb(0x3D5A44);
                case BaseballAvatarColorToken.Jersey2: return FromRgb(0x2F4858);
                case BaseballAvatarColorToken.Jersey3: return FromRgb(0x5A4632);
                case BaseballAvatarColorToken.Jersey4: return FromRgb(0x44415A);
                case BaseballAvatarColorToken.Jersey5: return FromRgb(0x5C3A3A);
                case BaseballAvatarColorToken.Cap: return FromRgb(0x274232);
                case BaseballAvatarColorToken.CapBrim: return FromRgb(0x1C3125);
                case BaseballAvatarColorToken.Helmet: return FromRgb(0x32405C);
                case BaseballAvatarColorToken.Mask: return FromRgb(0x8B93A1);
                case BaseballAvatarColorToken.Line: return FromRgb(0x1A1D22);
                case BaseballAvatarColorToken.Highlight: return FromRgb(0xFFFFFF);
                default: throw new ArgumentOutOfRangeException(nameof(token), token, null);
            }
        }

        public static string ToHex(Color32 color)
        {
            return $"#{color.r:X2}{color.g:X2}{color.b:X2}";
        }

        private static Color32 Fixed(uint standard, uint highContrast, bool useHighContrast)
        {
            return FromRgb(useHighContrast ? highContrast : standard);
        }

        private static Color32 FromRgb(uint rgb)
        {
            return new Color32(
                (byte)((rgb >> 16) & 0xFF),
                (byte)((rgb >> 8) & 0xFF),
                (byte)(rgb & 0xFF),
                0xFF);
        }
    }
}
