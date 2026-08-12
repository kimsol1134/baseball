using System;
using System.Linq;
using System.Text;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;

namespace Baseball.Presentation.Common
{
    public enum PlayerPortraitStage
    {
        Young,
        Ace,
        Pro,
    }

    /// <summary>
    /// Presentation mapping for the imported, local-only Addressables catalog. Stable domain
    /// payloads select artwork; labels remain authoritative even when artwork cannot be loaded.
    /// </summary>
    public static class BaseballVisualContentCatalog
    {
        private const string Prefix = "baseball/";

        public static bool IsLocalOnlyAddress(string address) =>
            !string.IsNullOrWhiteSpace(address) &&
            address.StartsWith(Prefix, StringComparison.Ordinal) &&
            address.IndexOf("://", StringComparison.Ordinal) < 0;

        public static string SetupRegion(string region)
        {
            switch ((region ?? string.Empty).Trim())
            {
                case "서울": return Scene("media");
                case "인천": return Scene("game");
                case "수원": return Scene("team");
                case "대전": return Scene("growth");
                case "광주": return Scene("game");
                case "대구": return Scene("health");
                case "부산": return Scene("fan");
                case "창원": return Scene("team");
                case "울산": return Scene("health");
                case "세종": return Scene("growth");
                case "경기": return Scene("team");
                case "강원": return Scene("life");
                case "충북": return Scene("growth");
                case "충남": return Scene("team");
                case "전북": return Scene("game");
                case "전남": return Scene("life");
                case "경북": return Scene("life");
                case "경남": return Scene("team");
                case "제주": return Scene("life");
                default: return string.Empty;
            }
        }

        public static string SetupPreset(string presetId)
        {
            switch (Normalize(presetId))
            {
                case "powerprospect": return "baseball/setup/PresetArt-power_prospect";
                case "precisioncommander": return "baseball/setup/PresetArt-precision_commander";
                case "breakingballartist": return "baseball/setup/PresetArt-breaking_ball_artist";
                // The imported source catalog has no dedicated innings-eater illustration.
                // Use the documented pitcher fallback without changing the selected payload.
                case "inningseater": return "baseball/setup/PresetArt-power_prospect";
                default: return string.Empty;
            }
        }

        public static string PresetResultPreview(string presetId)
        {
            PitcherPresetSnapshot preset = PitcherPresetCatalog.All.FirstOrDefault(value =>
                string.Equals(value.Id, presetId, StringComparison.Ordinal));
            if (preset?.Pitcher == null) return string.Empty;
            PitchProfileSnapshot primary = preset.Pitcher.PitchProfiles.FirstOrDefault(value =>
                value.Role == PitchUsageRole.Primary);
            PitchProfileSnapshot development = preset.Pitcher.PitchProfiles.FirstOrDefault(value =>
                value.Role == PitchUsageRole.Development);
            string pitches = primary == null
                ? string.Empty
                : " · 주무기 " + PitchTitle(primary.PitchType);
            if (development != null)
                pitches += " · 육성 " + PitchTitle(development.PitchType);
            return "구위 " + preset.Pitcher.Stuff +
                " · 제구 " + preset.Pitcher.Command +
                " · 변화 " + preset.Pitcher.Movement +
                " · 체력 " + preset.Pitcher.Stamina + pitches;
        }

        public static string Memory(string memoryId)
        {
            switch (Normalize(memoryId))
            {
                case "bullpencompass": return MemoryArt("bullpen_compass");
                case "catchernotebook": return MemoryArt("catcher_notebook");
                case "coachletter": return MemoryArt("coach_letter");
                case "draftreport": return MemoryArt("draft_report");
                case "failurescorebook": return MemoryArt("failure_scorebook");
                case "fatiguediary": return MemoryArt("fatigue_diary");
                case "fingertipmemory": return MemoryArt("fingertip_memory");
                case "firstpitchmap": return MemoryArt("first_pitch_map");
                case "mechanicsvideo": return MemoryArt("mechanics_video");
                case "pressurerehearsal": return MemoryArt("pressure_rehearsal");
                case "recoveryroutine": return MemoryArt("recovery_routine");
                case "rivalnotebook": return MemoryArt("rival_notebook");
                case "schoolplaybook": return MemoryArt("school_playbook");
                case "stadiumecho": return MemoryArt("stadium_echo");
                case "teamfirstpromise": return MemoryArt("team_first_promise");
                case "twostrikesequence": return MemoryArt("two_strike_sequence");
                case "velocityblueprint": return MemoryArt("velocity_blueprint");
                case "winterprogram": return MemoryArt("winter_program");
                default: return string.Empty;
            }
        }

        public static string SignatureLegacy(string legacyId)
        {
            switch (Normalize(legacyId))
            {
                case "powerimprint": return MemoryArt("velocity_blueprint");
                case "commandmap": return MemoryArt("first_pitch_map");
                case "breakingtrace": return MemoryArt("fingertip_memory");
                case "endurancerhythm": return MemoryArt("recovery_routine");
                case "gamecraftledger": return MemoryArt("school_playbook");
                case "batterypromise": return MemoryArt("catcher_notebook");
                default: return Scene("life");
            }
        }

        public static string Choice(string groupId, string payload)
        {
            string group = Normalize(groupId);
            if (group == "legacymemories" || group == "memory" || group == "memories")
                return Memory(payload);
            if (group == "legacysignature" || group == "signature" ||
                group == "signaturelegacy")
                return SignatureLegacy(payload);
            return string.Empty;
        }

        public static string RelationshipArtwork(string category, string speakerEvidence)
        {
            switch (Normalize(category))
            {
                case "coach": return CoachPortrait(speakerEvidence);
                case "catcher": return CatcherPortrait(speakerEvidence);
                case "rival": return "baseball/highschool/PortraitRival" + PortraitVariant(speakerEvidence, 3);
                case "life": return Scene("life");
                case "media": return Scene("media");
                case "fan": return Scene("fan");
                case "health": return Scene("health");
                case "team": return Scene("team");
                case "draft": return Scene("draft");
                case "growth": return Scene("growth");
                case "game": return Scene("game");
                default: return string.Empty;
            }
        }

        public static string CoachPortrait(string name) =>
            "baseball/highschool/PortraitCoach" + CoachVariant(name);

        public static string CatcherPortrait(string name) =>
            "baseball/highschool/PortraitCatcher" + CatcherVariant(name);

        public static string SchoolCoachPortrait(string schoolChoiceDetail)
        {
            string name = ExtractRoleName(schoolChoiceDetail, "감독 ");
            return string.IsNullOrWhiteSpace(name) ? string.Empty : CoachPortrait(name);
        }

        public static string SchoolCatcherPortrait(string schoolChoiceDetail)
        {
            string name = ExtractRoleName(schoolChoiceDetail, "포수 ");
            return string.IsNullOrWhiteSpace(name) ? string.Empty : CatcherPortrait(name);
        }

        public static string PlayerPortrait(string playerName, PlayerPortraitStage stage)
        {
            if (string.IsNullOrWhiteSpace(playerName)) return string.Empty;
            string prefix;
            string catalog;
            switch (stage)
            {
                case PlayerPortraitStage.Young:
                    catalog = "highschool";
                    prefix = "PortraitPlayerYoung";
                    break;
                case PlayerPortraitStage.Pro:
                    catalog = "pro";
                    prefix = "PortraitPlayerPro";
                    break;
                default:
                    catalog = "highschool";
                    prefix = "PortraitPlayer";
                    break;
            }
            return "baseball/" + catalog + "/" + prefix + PortraitVariant(playerName, 20);
        }

        /// <summary>
        /// The imported tournament banners are keyed by the authoritative career chapter,
        /// matching the iOS catalog. PlayerRound is deliberately not used because chapters 2
        /// and 4 can both project the same bracket round.
        /// </summary>
        public static string TournamentBanner(int chapterNumber)
        {
            switch (chapterNumber)
            {
                case 2: return "baseball/highschool/TournamentBanner2";
                case 4: return "baseball/highschool/TournamentBanner4";
                case 6: return "baseball/highschool/TournamentBanner6";
                case 8: return "baseball/highschool/TournamentBanner8";
                default: return string.Empty;
            }
        }

        public static string ImportantGameScene() => Scene("game");
        public static string TalentBloom() => "baseball/meta/BloomArt";

        private static string Scene(string id) => "baseball/meta/SceneArt-" + id;
        private static string MemoryArt(string id) => "baseball/meta/MemoryArt-" + id;

        private static string PitchTitle(PitchType value)
        {
            switch (value)
            {
                case PitchType.FourSeam: return "포심";
                case PitchType.Slider: return "슬라이더";
                case PitchType.Curveball: return "커브";
                case PitchType.Changeup: return "체인지업";
                default: return value.Value();
            }
        }

        private static string ExtractRoleName(string detail, string marker)
        {
            if (string.IsNullOrWhiteSpace(detail)) return string.Empty;
            int start = detail.IndexOf(marker, StringComparison.Ordinal);
            if (start < 0) return string.Empty;
            start += marker.Length;
            int end = detail.IndexOf(" ·", start, StringComparison.Ordinal);
            return (end < 0 ? detail.Substring(start) : detail.Substring(start, end - start)).Trim();
        }

        private static int PortraitVariant(string value, int maximum)
        {
            unchecked
            {
                uint hash = 2166136261;
                byte[] bytes = Encoding.UTF8.GetBytes("portrait:" + (value ?? string.Empty));
                foreach (byte character in bytes)
                {
                    hash ^= character;
                    hash *= 16777619;
                }
                return (int)(hash % (uint)maximum) + 1;
            }
        }

        private static int CoachVariant(string name)
        {
            switch (name ?? string.Empty)
            {
                case "윤태문": case "강일도": case "백승관": case "임동혁": case "조범석": return 1;
                case "노재형": case "한기표": case "유상민": case "신정록": case "곽태윤": return 2;
                case "오승렬": case "마동준": case "채희성": case "도진광": case "하병철": return 3;
                case "배도환": case "어재원": case "편상욱": case "소진철": case "반석호": return 4;
                default: return PortraitVariant(name, 4);
            }
        }

        private static int CatcherVariant(string name)
        {
            switch (name ?? string.Empty)
            {
                case "서준호": case "김도현": case "박성재": case "이재영": case "정우빈": return 1;
                case "한도윤": case "송지헌": case "오세민": case "권혁준": case "남기율": return 2;
                case "차민석": case "변진서": case "육정환": case "구자헌": case "표재신": return 3;
                case "문하진": case "안시후": case "방준서": case "석민규": case "탁이현": return 4;
                default: return PortraitVariant(name, 4);
            }
        }

        private static string Normalize(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return string.Empty;
            var result = new StringBuilder(value.Length);
            foreach (char character in value)
                if (char.IsLetterOrDigit(character))
                    result.Append(char.ToLowerInvariant(character));
            return result.ToString();
        }
    }
}
