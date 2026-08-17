using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Pitch;

namespace Baseball.Presentation.Shell
{
    public sealed partial class StoreBaseballCareerReadModel
    {

        private static string PledgeTierTitle(Baseball.Application.HighSchool.RunPledgeTier tier)
        {
            switch (tier)
            {
                case Baseball.Application.HighSchool.RunPledgeTier.Safe: return "안정 목표";
                case Baseball.Application.HighSchool.RunPledgeTier.Bold: return "도전 목표";
                case Baseball.Application.HighSchool.RunPledgeTier.Legendary: return "전설 목표";
                default: return "고교 목표";
            }
        }

        private static string TrainingFocusTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "velocity": return "구속";
                case "command": return "제구";
                case "movement":
                case "breaking_ball": return "변화구";
                case "stamina": return "체력";
                case "recovery": return "회복";
                case "game_planning": return "경기 운영";
                default: return "훈련";
            }
        }

        private static string TalentAbilityTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "stuff": return "구위";
                case "command": return "제구";
                case "movement": return "변화";
                case "stamina": return "체력";
                default: return "투수 재능";
            }
        }

        private static string TrainingBlockStopTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "maximum_sessions": return "선택한 최대 횟수를 마쳤습니다.";
                case "relationship": return "관계 일정이 열려 멈췄습니다.";
                case "awakening": return "각성 선택이 열려 멈췄습니다.";
                case "important_game": return "중요 경기가 열려 멈췄습니다.";
                case "talent_bloom": return "재능 성장 신호가 나타나 멈췄습니다.";
                case "fatigue": return "피로가 높아져 안전하게 멈췄습니다.";
                case "arm_health": return "팔 상태가 바뀌어 안전하게 멈췄습니다.";
                default: return "다음 일정이 열려 멈췄습니다.";
            }
        }

        private static string PitchTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "four_seam":
                case "four-seam":
                case "fourseam": return "포심";
                case "slider": return "슬라이더";
                case "curveball": return "커브";
                case "changeup": return "체인지업";
                default: return "선택 구종";
            }
        }

        private static string TrainingIntensityTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "light": return "가볍게";
                case "standard": return "표준";
                case "intensive": return "집중";
                default: return "강도 기록";
            }
        }

        private static string RelationshipResponseTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "listen": return "먼저 듣는다";
                case "explain": return "설명한다";
                case "challenge": return "결과로 답한다";
                default: return "선택한 응답";
            }
        }

        private static string RelationshipTrustTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "trusted": return "두터운 믿음";
                case "warm": return "가까워지는 중";
                case "strained": return "긴장된 관계";
                default: return "서로 알아가는 중";
            }
        }

        private static string LeverageTitle(int leverage) => leverage >= 850
            ? "한 공이 흐름을 바꾸는 순간"
            : leverage >= 650 ? "중요한 승부처" : "차분히 아웃을 쌓을 상황";

        private static string ScoreDifferentialTitle(int scoreDifferential) => scoreDifferential == 0
            ? "동점"
            : scoreDifferential > 0 ? scoreDifferential + "점 앞섬" : -scoreDifferential + "점 뒤짐";

        private static string Signed(int value) => value > 0 ? "+" + value : value.ToString();
    }
}
