using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.Meta;
using Baseball.Core.Catalogs;
using Baseball.Core.HighSchool;

namespace Baseball.Application.HighSchool
{
    public sealed class HighSchoolSeedSelection
    {
        public HighSchoolSeedSelection(string seed, int? challengeLifeNumber = null)
        {
            Seed = seed;
            ChallengeLifeNumber = challengeLifeNumber;
        }

        public string Seed { get; }
        public int? ChallengeLifeNumber { get; }
        public bool IsChallenge => ChallengeLifeNumber.HasValue;
    }

    /// <summary>The complete setup surface; advanced choices are intentionally absent on life one.</summary>
    public sealed class HighSchoolSetupReadModel
    {
        public HighSchoolSetupReadModel(
            bool advancedOptionsVisible,
            bool canQuickRebirth,
            int lifeNumber,
            int soulBalance,
            int automaticSoul,
            IReadOnlyList<string> carriedMemories,
            IReadOnlyList<CareerChoiceReadModel> regions,
            IReadOnlyList<CareerChoiceReadModel> presets,
            IReadOnlyList<CareerChoiceReadModel> difficulties,
            IReadOnlyList<CareerChoiceReadModel> karmas,
            IReadOnlyList<CareerChoiceReadModel> soulDomains,
            IReadOnlyList<CareerChoiceReadModel> soulBoosts,
            IReadOnlyList<CareerChoiceReadModel> signatureLegacies,
            HighSchoolLastSetupState lastSetup)
        {
            AdvancedOptionsVisible = advancedOptionsVisible;
            CanQuickRebirth = canQuickRebirth;
            LifeNumber = lifeNumber;
            SoulBalance = soulBalance;
            AutomaticSoul = automaticSoul;
            CarriedMemories = (carriedMemories ?? Array.Empty<string>()).ToArray();
            Regions = regions;
            Presets = presets;
            Difficulties = difficulties;
            Karmas = karmas;
            SoulDomains = soulDomains;
            SoulBoosts = soulBoosts;
            SignatureLegacies = signatureLegacies;
            LastSetup = lastSetup;
        }

        public bool AdvancedOptionsVisible { get; }
        public bool CanQuickRebirth { get; }
        public int LifeNumber { get; }
        public int SoulBalance { get; }
        public int AutomaticSoul { get; }
        public IReadOnlyList<string> CarriedMemories { get; }
        public IReadOnlyList<CareerChoiceReadModel> Regions { get; }
        public IReadOnlyList<CareerChoiceReadModel> Presets { get; }
        public IReadOnlyList<CareerChoiceReadModel> Difficulties { get; }
        public IReadOnlyList<CareerChoiceReadModel> Karmas { get; }
        public IReadOnlyList<CareerChoiceReadModel> SoulDomains { get; }
        public IReadOnlyList<CareerChoiceReadModel> SoulBoosts { get; }
        public IReadOnlyList<CareerChoiceReadModel> SignatureLegacies { get; }
        public HighSchoolLastSetupState LastSetup { get; }
    }

    /// <summary>Stable setup options and pre-Core validation shared by UI and command handling.</summary>
    public static class HighSchoolSetupCatalog
    {
        public static readonly IReadOnlyList<CareerChoiceReadModel> Regions = new[]
        {
            Region("서울", "스카우트가 가장 자주 오는 무대"),
            Region("인천", "바닷바람 속 끈질긴 야구"),
            Region("수원", "신흥 명문들의 각축전"),
            Region("대전", "뚝심의 원포인트 승부"),
            Region("광주", "타격의 고장, 투수에겐 시련"),
            Region("대구", "더위를 이기는 근성"),
            Region("부산", "함성이 가장 큰 관중석"),
            Region("창원", "짜임새 있는 수비 야구"),
            Region("울산", "묵묵히 던지는 공업 도시"),
            Region("세종", "역사가 짧아 기회가 많은 무대"),
            Region("경기", "팀 수가 가장 많은 격전지"),
            Region("강원", "산바람에 단련된 어깨"),
            Region("충북", "조용히 강한 다크호스"),
            Region("충남", "전통 강호의 자존심"),
            Region("전북", "거친 바람의 홈그라운드"),
            Region("전남", "느리게, 그러나 확실하게"),
            Region("경북", "전통과 자부심의 명문가"),
            Region("경남", "남쪽 끝의 탄탄한 전력"),
            Region("제주", "가장 먼 곳에서 온 유망주")
        };

        public static readonly IReadOnlyList<CareerChoiceReadModel> Presets =
            PitcherPresetCatalog.All.Select(value => new CareerChoiceReadModel(
                value.Id,
                value.Name,
                value.Tagline,
                string.Join(" · ", value.Strengths) + " / " + value.Tradeoff)).ToArray();

        public static readonly IReadOnlyList<CareerChoiceReadModel> Karmas =
            Enum.GetValues(typeof(KarmaId)).Cast<KarmaId>().Select(value =>
                new CareerChoiceReadModel(
                    Wire(value),
                    KarmaTitle(value),
                    "이번 삶의 난도가 오르는 대신 다음 계승 보상이 커집니다.",
                    "+" + (value.RewardPermille() / 10) + "% 계승 보상")).ToArray();

        public static readonly IReadOnlyList<CareerChoiceReadModel> SoulDomains = new[]
        {
            new CareerChoiceReadModel("body", "몸", "구속과 몸의 힘에 먼저 배분합니다."),
            new CareerChoiceReadModel("technique", "기술", "제구와 손끝 감각에 먼저 배분합니다."),
            new CareerChoiceReadModel("game", "경기", "경기 운영 능력에 먼저 배분합니다.")
        };

        public static readonly IReadOnlyList<CareerChoiceReadModel> SoulBoosts =
            Enum.GetValues(typeof(SoulBoostId)).Cast<SoulBoostId>().Select(value =>
                new CareerChoiceReadModel(
                    Wire(value),
                    SoulBoostTitle(value),
                    SoulBoostDetail(value),
                    value.Cost() + " 야구혼")).ToArray();

        public static readonly IReadOnlyList<CareerChoiceReadModel> Difficulties = new[]
        {
            new CareerChoiceReadModel("relaxed", "여유롭게", "성장과 라이벌 압박이 부드럽습니다."),
            new CareerChoiceReadModel("standard", "표준", "기본 커리어 난도입니다."),
            new CareerChoiceReadModel("challenging", "혹독하게", "라이벌과 드래프트 경쟁이 더 거셉니다.")
        };

        public static HighSchoolSetupReadModel For(MetaProgressState meta)
        {
            if (meta == null) throw new ArgumentNullException(nameof(meta));
            var advanced = IsRebirth(meta);
            var signatures = advanced
                ? SignatureChoices(meta.UnlockedSignatureLegacyIds)
                : Array.Empty<CareerChoiceReadModel>();
            return new HighSchoolSetupReadModel(
                advanced,
                advanced && meta.LastHighSchoolSetup != null,
                meta.LifeNumber,
                meta.SoulBalance,
                meta.AutomaticSoulEarned,
                advanced ? meta.InheritedMemories : Array.Empty<string>(),
                Regions,
                Presets,
                advanced ? Difficulties : Array.Empty<CareerChoiceReadModel>(),
                advanced ? Karmas : Array.Empty<CareerChoiceReadModel>(),
                advanced ? SoulDomains : Array.Empty<CareerChoiceReadModel>(),
                advanced ? SoulBoosts : Array.Empty<CareerChoiceReadModel>(),
                signatures,
                advanced ? meta.LastHighSchoolSetup : null);
        }

        public static bool IsRebirth(MetaProgressState meta)
        {
            return meta != null && (meta.LifeNumber > 1 || meta.SoulBalance > 0 ||
                meta.AutomaticSoulEarned > 0 || meta.InheritedMemories.Count > 0 ||
                meta.UnlockedSignatureLegacyIds.Count > 0 ||
                !string.IsNullOrWhiteSpace(meta.EquippedSignatureLegacyId));
        }

        /// <summary>Parses either a decimal seed or the share-card form "seed-life".</summary>
        public static bool TryParseSeedInput(
            string input,
            out HighSchoolSeedSelection selection,
            out string errorCode)
        {
            selection = null;
            errorCode = null;
            var normalized = new string((input ?? string.Empty)
                .Where(character => char.IsDigit(character) || character == '-')
                .ToArray());
            if (string.IsNullOrWhiteSpace(input)) return true;
            var parts = normalized.Split(new[] { '-' }, StringSplitOptions.None);
            if (parts.Length == 1 && ulong.TryParse(parts[0], out _))
            {
                selection = new HighSchoolSeedSelection(parts[0]);
                return true;
            }
            if (parts.Length == 2 && ulong.TryParse(parts[0], out _) &&
                int.TryParse(parts[1], out var life) && life >= 1 && life <= 999)
            {
                selection = new HighSchoolSeedSelection(parts[0], life);
                return true;
            }
            errorCode = "high_school.seed_or_challenge_invalid";
            return false;
        }

        public static int SoulBoostCost(IReadOnlyList<string> values)
        {
            return (values ?? Array.Empty<string>())
                .Select(Parse<SoulBoostId>)
                .Sum(value => value.Cost());
        }

        /// <summary>Returns null when valid, otherwise a stable Application error code.</summary>
        public static string Validate(
            StartHighSchoolCareerRequest request,
            int availableSoul,
            int availableAutomaticSoul,
            IReadOnlyList<string> availableMemories,
            IReadOnlyList<string> unlockedSignatureLegacyIds = null,
            bool advancedSetupAvailable = true)
        {
            if (request == null) return "high_school.start_invalid";
            if (!Contains(Regions, request.Region)) return "high_school.region_invalid";
            if (!Contains(Presets, request.PresetId)) return "high_school.preset_invalid";
            if (!Contains(Difficulties, request.Difficulty)) return "high_school.difficulty_invalid";
            if (request.IsChallenge)
            {
                if (request.ChallengeLifeNumber < 1 || request.ChallengeLifeNumber > 999 ||
                    !ulong.TryParse(request.Seed, out _) || request.InheritedSoul != 0 ||
                    request.InheritedMemories.Count != 0 || request.Karmas.Count != 0 ||
                    request.SoulBoosts.Count != 0 ||
                    !string.IsNullOrWhiteSpace(request.InheritedSoulDomain) ||
                    !string.IsNullOrWhiteSpace(request.SignatureLegacyId))
                {
                    return "high_school.challenge_invalid";
                }
            }
            else if (!advancedSetupAvailable &&
                (!string.Equals(Normalize(request.Difficulty), "standard", StringComparison.Ordinal) ||
                 request.InheritedSoul != 0 || request.InheritedMemories.Count != 0 ||
                 request.Karmas.Count != 0 || request.SoulBoosts.Count != 0 ||
                 !string.IsNullOrWhiteSpace(request.InheritedSoulDomain) ||
                 !string.IsNullOrWhiteSpace(request.SignatureLegacyId)))
            {
                return "high_school.advanced_setup_locked";
            }
            if (!string.IsNullOrWhiteSpace(request.SignatureLegacyId) &&
                !(unlockedSignatureLegacyIds ?? Array.Empty<string>())
                    .Any(value => string.Equals(
                        Normalize(value), Normalize(request.SignatureLegacyId), StringComparison.Ordinal)))
            {
                return "high_school.signature_legacy_locked";
            }
            if (request.InheritedSoul < 0 || request.InheritedSoul > availableAutomaticSoul)
                return "high_school.inherited_soul_invalid";
            if (!string.IsNullOrWhiteSpace(request.InheritedSoulDomain) &&
                !Contains(SoulDomains, request.InheritedSoulDomain))
            {
                return "high_school.soul_domain_invalid";
            }

            var karmas = NormalizeMany(request.Karmas);
            if (karmas.Count != request.Karmas.Count || karmas.Count > 2 ||
                karmas.Any(value => !Contains(Karmas, value)))
            {
                return "high_school.karmas_invalid";
            }

            var boosts = NormalizeMany(request.SoulBoosts);
            if (boosts.Count != request.SoulBoosts.Count ||
                boosts.Any(value => !Contains(SoulBoosts, value)))
            {
                return "high_school.soul_boosts_invalid";
            }
            if (SoulBoostCost(boosts) > availableSoul)
                return "high_school.soul_balance_insufficient";

            var memories = NormalizeMany(request.InheritedMemories);
            var carried = new HashSet<string>(NormalizeMany(availableMemories), StringComparer.Ordinal);
            if (memories.Count != request.InheritedMemories.Count || memories.Count > 4 ||
                memories.Any(value => !EnumValue<MemoryCardId>(value) || !carried.Contains(value)))
            {
                return "high_school.memories_invalid";
            }
            return null;
        }

        private static IReadOnlyList<CareerChoiceReadModel> SignatureChoices(
            IReadOnlyList<string> unlockedIds)
        {
            var unlocked = new HashSet<string>(
                (unlockedIds ?? Array.Empty<string>()).Select(Normalize),
                StringComparer.Ordinal);
            return Enum.GetValues(typeof(CareerSignatureLegacyId))
                .Cast<CareerSignatureLegacyId>()
                .Where(value => unlocked.Contains(Normalize(value.Value())))
                .Select(value =>
                {
                    var definition = CareerSignatureLegacy.Definition(value);
                    var effect = definition.Effect;
                    return new CareerChoiceReadModel(
                        value.Value(),
                        definition.Title,
                        definition.Detail,
                        $"구위 +{effect.Stuff} · 제구 +{effect.Command} · 변화 +{effect.Movement} · 체력 +{effect.Stamina}");
                })
                .ToArray();
        }

        private static CareerChoiceReadModel Region(string id, string detail) =>
            new CareerChoiceReadModel(id, id, detail);

        private static bool Contains(IEnumerable<CareerChoiceReadModel> choices, string value)
        {
            var normalized = Normalize(value);
            return choices.Any(choice => Normalize(choice.Id) == normalized);
        }

        private static IReadOnlyList<string> NormalizeMany(IReadOnlyList<string> values)
        {
            return (values ?? Array.Empty<string>())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Select(Normalize)
                .Distinct(StringComparer.Ordinal)
                .ToArray();
        }

        private static bool EnumValue<T>(string value) where T : struct
        {
            return Enum.GetValues(typeof(T)).Cast<T>()
                .Any(candidate => Normalize(candidate.ToString()) == Normalize(value));
        }

        private static T Parse<T>(string value) where T : struct
        {
            return Enum.GetValues(typeof(T)).Cast<T>()
                .First(candidate => Normalize(candidate.ToString()) == Normalize(value));
        }

        private static string Normalize(string value) => new string((value ?? string.Empty)
            .Where(character => character != '_' && character != '-' && !char.IsWhiteSpace(character))
            .Select(char.ToLowerInvariant)
            .ToArray());

        private static string Wire(KarmaId value)
        {
            switch (value)
            {
                case KarmaId.UnknownLand: return "unknown_land";
                case KarmaId.StubbornCoach: return "stubborn_coach";
                case KarmaId.SingleWeapon: return "single_weapon";
                case KarmaId.GeniusGeneration: return "genius_generation";
                case KarmaId.ErasedMemory: return "erased_memory";
                default: return "no_last_chance";
            }
        }

        private static string Wire(SoulBoostId value)
        {
            switch (value)
            {
                case SoulBoostId.TalentBreak: return "talent_break";
                case SoulBoostId.ExtraMemory: return "extra_memory";
                case SoulBoostId.HeadStart: return "head_start";
                default: return "training_rhythm";
            }
        }

        private static string KarmaTitle(KarmaId value)
        {
            switch (value)
            {
                case KarmaId.UnknownLand: return "낯선 땅";
                case KarmaId.StubbornCoach: return "완고한 감독";
                case KarmaId.SingleWeapon: return "하나뿐인 무기";
                case KarmaId.GeniusGeneration: return "천재 세대";
                case KarmaId.ErasedMemory: return "지워진 기억";
                default: return "마지막 기회 없음";
            }
        }

        private static string SoulBoostTitle(SoulBoostId value)
        {
            switch (value)
            {
                case SoulBoostId.TalentBreak: return "재능 돌파";
                case SoulBoostId.ExtraMemory: return "기억 한 자리 추가";
                case SoulBoostId.HeadStart: return "빠른 출발";
                default: return "훈련 리듬";
            }
        }

        private static string SoulBoostDetail(SoulBoostId value)
        {
            switch (value)
            {
                case SoulBoostId.TalentBreak: return "가장 낮은 재능 한계를 한 단계 높입니다.";
                case SoulBoostId.ExtraMemory: return "이번 삶이 끝날 때 남길 기억의 수가 하나 늘어납니다.";
                case SoulBoostId.HeadStart: return "시작 능력 성장치를 추가로 받습니다.";
                default: return "훈련 대성공 확률이 높아집니다.";
            }
        }
    }
}
