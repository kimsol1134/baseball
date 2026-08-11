using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Pro;
using Baseball.Core.HighSchool;

namespace Baseball.Application.Meta
{
    /// <summary>
    /// Display copy frozen when a life is archived. It must never be regenerated from a later
    /// catalog version, because the archive is also the replay and analytics source of truth.
    /// </summary>
    public sealed class PlayerLegacyState
    {
        public PlayerLegacyState(string title, string definingMoment, string farewell)
        {
            Title = title;
            DefiningMoment = definingMoment;
            Farewell = farewell;
        }

        public string Title { get; }
        public string DefiningMoment { get; }
        public string Farewell { get; }
    }

    public static class PlayerLegacyRules
    {
        private static readonly string[] DefiningMomentKeywords =
        {
            "별명", "만개", "숙적", "무실점", "탈삼진", "지명"
        };

        public static PlayerLegacyState Freeze(
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro,
            IReadOnlyList<string> memories,
            bool? pledgeAchieved)
        {
            memories = memories ?? Array.Empty<string>();
            var frozenSignature = highSchool?.SelectedSignatureLegacy;
            var signatureDefinition = Signature(
                frozenSignature?.Id ?? highSchool?.SelectedSignatureLegacyId);
            var signatureTitle = frozenSignature?.Title ?? signatureDefinition?.Title;
            var signatureDetail = frozenSignature?.Detail ?? signatureDefinition?.Detail;
            var signatureEvidence = frozenSignature?.EvidenceSummary;
            var drafted = highSchool?.Draft?.Drafted == true;
            var performance = highSchool?.Performance;
            var title = Title(
                !string.IsNullOrWhiteSpace(signatureTitle), drafted, pledgeAchieved,
                performance, highSchool, pro);
            var definingMoment = DefiningMoment(
                highSchool, pro, signatureTitle, signatureDetail, signatureEvidence);
            var farewell = Farewell(
                highSchool, pro, memories, drafted, signatureTitle, signatureEvidence);
            return new PlayerLegacyState(title, definingMoment, farewell);
        }

        public static bool IsValid(PlayerLegacyState value)
        {
            return value != null &&
                !string.IsNullOrWhiteSpace(value.Title) &&
                !string.IsNullOrWhiteSpace(value.DefiningMoment) &&
                !string.IsNullOrWhiteSpace(value.Farewell);
        }

        private static string Title(
            bool hasSignature,
            bool drafted,
            bool? pledgeAchieved,
            CareerPerformanceReadModel performance,
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro)
        {
            if (hasSignature) return "자기 공을 남긴 투수";
            if (drafted) return "끝까지 키워 낸 투수";
            if (pledgeAchieved == true) return "자기 목표를 지킨 투수";
            if (performance != null && performance.ImportantGames > 0 &&
                performance.RunsAllowed == 0)
            {
                return "끝까지 홈을 지킨 투수";
            }
            if (performance != null && performance.Strikeouts >= 30)
                return "삼진을 믿었던 투수";
            return highSchool == null && pro != null
                ? "프로 마운드를 끝까지 지킨 투수"
                : "함께 3년을 보낸 투수";
        }

        private static string DefiningMoment(
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro,
            string signatureTitle,
            string signatureDetail,
            string signatureEvidence)
        {
            if (!string.IsNullOrWhiteSpace(signatureEvidence)) return signatureEvidence;
            if (!string.IsNullOrWhiteSpace(signatureTitle))
                return signatureTitle + " · " + signatureDetail;

            foreach (var keyword in DefiningMomentKeywords)
            {
                var line = highSchool?.News?.FirstOrDefault(value =>
                    !string.IsNullOrWhiteSpace(value) &&
                    value.IndexOf(keyword, StringComparison.Ordinal) >= 0);
                if (!string.IsNullOrWhiteSpace(line)) return line;
            }

            var latest = highSchool?.News?.FirstOrDefault(value =>
                !string.IsNullOrWhiteSpace(value));
            if (!string.IsNullOrWhiteSpace(latest)) return latest;
            if (highSchool?.Draft?.Drafted == true)
            {
                return (highSchool.Draft.TeamName ?? "프로 구단") + "이 " +
                    highSchool.PlayerName + "의 이름을 불렀던 날";
            }
            if (highSchool != null)
                return (highSchool.SchoolName ?? "고교") + "에서 마지막 공을 던진 날";
            return (pro?.TeamName ?? "프로 구단") + "에서 마지막 공을 던진 날";
        }

        private static string Farewell(
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro,
            IReadOnlyList<string> memories,
            bool drafted,
            string signatureTitle,
            string signatureEvidence)
        {
            string opening;
            if (drafted)
            {
                opening = "내 이름이 불릴 때, 제일 먼저 우리가 한 땀씩 키운 공이 떠올랐어요.";
            }
            else if (!string.IsNullOrWhiteSpace(signatureTitle))
            {
                opening = "프로의 부름은 없었지만, " +
                    (string.IsNullOrWhiteSpace(signatureEvidence)
                        ? signatureTitle
                        : signatureEvidence + " 그 시간") +
                    "까지 사라지는 건 아니죠.";
            }
            else if (highSchool != null)
            {
                opening = "프로의 부름은 없었지만, 내가 보낸 3년까지 사라지는 건 아니죠.";
            }
            else
            {
                opening = (pro?.TeamName ?? "프로 구단") +
                    "에서 보낸 시간까지 사라지는 건 아니죠.";
            }

            string closing;
            if (drafted && !string.IsNullOrWhiteSpace(signatureTitle))
            {
                closing = "우리가 만든 ‘" + signatureTitle +
                    "’과 함께 더 큰 마운드로 가 볼게요.";
            }
            else if (!string.IsNullOrWhiteSpace(signatureTitle))
            {
                closing = "‘" + signatureTitle +
                    "’이 언젠가 다른 마운드의 시작에 닿기를 바라요.";
            }
            else if (memories.Count > 0)
            {
                closing = PersonalityFarewell(highSchool?.PresetId, true);
            }
            else
            {
                closing = PersonalityFarewell(highSchool?.PresetId, false);
            }
            return opening + " " + closing;
        }

        private static string PersonalityFarewell(string presetId, bool hasMemories)
        {
            if (hasMemories)
            {
                switch (presetId)
                {
                    case "power_prospect":
                        return "마지막까지 물러서지 않았던 마음과 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요.";
                    case "innings_eater":
                        return "말없이 오래 쌓은 하루들과 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요.";
                    case "precision_commander":
                        return "매번 그 공을 고른 이유와 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요.";
                    case "breaking_ball_artist":
                        return "상황마다 찾은 답과 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요.";
                    default:
                        return "내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요.";
                }
            }

            switch (presetId)
            {
                case "power_prospect":
                    return "마지막까지 물러서지 않았던 마음만은 오래 기억해 주세요.";
                case "innings_eater":
                    return "말없이 오래 쌓은 하루들이 누군가의 시작에 힘이 되면 좋겠어요.";
                case "precision_commander":
                    return "결과뿐 아니라, 내가 매번 그 공을 고른 이유도 기억해 주세요.";
                case "breaking_ball_artist":
                    return "내 기록이 다른 누군가에게 자기만의 답을 찾는 힌트가 되면 좋겠어요.";
                default:
                    return "내가 남긴 기록이 언젠가 다른 마운드의 시작에 힘이 되면 좋겠어요.";
            }
        }

        private static CareerSignatureLegacy Signature(string id)
        {
            if (string.IsNullOrWhiteSpace(id)) return null;
            foreach (CareerSignatureLegacyId value in Enum.GetValues(
                         typeof(CareerSignatureLegacyId)))
            {
                if (string.Equals(value.Value(), id, StringComparison.Ordinal))
                    return CareerSignatureLegacy.Definition(value);
            }
            return null;
        }
    }
}
