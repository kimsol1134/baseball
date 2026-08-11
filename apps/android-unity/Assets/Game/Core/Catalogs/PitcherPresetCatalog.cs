using System.Collections.Generic;
using Baseball.Core.Domain;

namespace Baseball.Core.Catalogs
{
    public sealed class PitcherPresetSnapshot
    {
        public PitcherPresetSnapshot(
            string id,
            string name,
            string tagline,
            IReadOnlyList<string> strengths,
            string tradeoff,
            PitcherSnapshot pitcher)
        {
            Id = id;
            Name = name;
            Tagline = tagline;
            Strengths = strengths;
            Tradeoff = tradeoff;
            Pitcher = pitcher;
        }

        public string Id { get; }
        public string Name { get; }
        public string Tagline { get; }
        public IReadOnlyList<string> Strengths { get; }
        public string Tradeoff { get; }
        public PitcherSnapshot Pitcher { get; }
    }

    /// <summary>Balance-v4 snapshot ported from PitcherPresetCatalog.swift.</summary>
    public static class PitcherPresetCatalog
    {
        public const int BalanceVersion = 4;

        public static readonly IReadOnlyList<PitcherPresetSnapshot> All = new[]
        {
            new PitcherPresetSnapshot(
                "power_prospect",
                "강속구 원석",
                "빠른 포심으로 타자를 밀어붙입니다.",
                new[] { "직구의 위력", "최고 구속", "헛스윙" },
                "전력투구의 피로와 제구 난도가 큽니다.",
                new PitcherSnapshot(
                    "pitcher-power", "민서준", 42, 34, 36, 38,
                    new[]
                    {
                        Profile(PitchType.FourSeam, PitchUsageRole.Primary, 1410, 35, 32, 37, 45, 41, 2),
                        Profile(PitchType.Slider, PitchUsageRole.Secondary, 1240, 31, 29, 40, 41, 38, 2),
                        Profile(PitchType.Curveball, PitchUsageRole.Secondary, 1090, 27, 26, 38, 33, 35, 2),
                        Profile(PitchType.Changeup, PitchUsageRole.Development, 1210, 23, 22, 31, 28, 31, 2)
                    })),
            new PitcherPresetSnapshot(
                "precision_commander",
                "정교한 제구형",
                "스트라이크존 끝에 꾸준히 던집니다.",
                new[] { "제구", "코스 공략", "볼넷 억제" },
                "삼진을 잡을 강한 결정구가 부족합니다.",
                new PitcherSnapshot(
                    "pitcher-command", "고태윤", 34, 43, 35, 38,
                    new[]
                    {
                        Profile(PitchType.FourSeam, PitchUsageRole.Primary, 1340, 45, 44, 34, 33, 39, 1),
                        Profile(PitchType.Slider, PitchUsageRole.Secondary, 1190, 41, 42, 39, 37, 40, 1),
                        Profile(PitchType.Curveball, PitchUsageRole.Development, 1060, 31, 33, 37, 29, 34, 2),
                        Profile(PitchType.Changeup, PitchUsageRole.Secondary, 1210, 43, 44, 39, 36, 42, 1)
                    })),
            new PitcherPresetSnapshot(
                "breaking_ball_artist",
                "변화구 아티스트",
                "속도와 움직임이 다른 변화구로 타자의 타이밍을 빼앗습니다.",
                new[] { "변화구 움직임", "헛스윙", "빗맞은 타구" },
                "직구 구속과 장기 체력은 평범합니다.",
                new PitcherSnapshot(
                    "pitcher-artist", "진서율", 37, 34, 44, 35,
                    new[]
                    {
                        Profile(PitchType.FourSeam, PitchUsageRole.Secondary, 1360, 38, 35, 34, 33, 37, 1),
                        Profile(PitchType.Slider, PitchUsageRole.Primary, 1220, 39, 40, 46, 44, 45, 2),
                        Profile(PitchType.Curveball, PitchUsageRole.Secondary, 1080, 37, 39, 45, 41, 46, 2),
                        Profile(PitchType.Changeup, PitchUsageRole.Development, 1200, 31, 33, 41, 38, 41, 2)
                    })),
            new PitcherPresetSnapshot(
                "innings_eater",
                "체력형 선발",
                "큰 기복 없이 많은 공을 소화합니다.",
                new[] { "체력", "피로가 천천히 쌓임", "꾸준한 제구" },
                "타자를 압도하는 헛스윙 능력은 낮습니다.",
                new PitcherSnapshot(
                    "pitcher-stamina", "도하람", 34, 38, 34, 44,
                    new[]
                    {
                        Profile(PitchType.FourSeam, PitchUsageRole.Primary, 1370, 41, 40, 34, 32, 39, 0),
                        Profile(PitchType.Slider, PitchUsageRole.Secondary, 1200, 38, 40, 37, 33, 39, 1),
                        Profile(PitchType.Curveball, PitchUsageRole.Development, 1060, 33, 32, 35, 28, 34, 1),
                        Profile(PitchType.Changeup, PitchUsageRole.Secondary, 1210, 40, 41, 39, 34, 43, 0)
                    }))
        };

        private static PitchProfileSnapshot Profile(
            PitchType pitchType,
            PitchUsageRole role,
            int velocity,
            int control,
            int command,
            int movement,
            int whiff,
            int weakContact,
            int fatigueCost)
        {
            return new PitchProfileSnapshot(
                pitchType, role, velocity, control, command, movement, whiff, weakContact, fatigueCost);
        }
    }
}
