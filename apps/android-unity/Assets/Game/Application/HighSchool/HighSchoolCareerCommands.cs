using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Application.HighSchool
{
    public sealed class StartHighSchoolCareerRequest
    {
        public StartHighSchoolCareerRequest(
            string seed,
            string presetId,
            string playerName,
            string region,
            int lifeNumber,
            IReadOnlyList<string> inheritedMemories = null,
            int inheritedSoul = 0,
            IReadOnlyList<string> karmas = null,
            string inheritedSoulDomain = null,
            IReadOnlyList<string> soulBoosts = null,
            string difficulty = "standard",
            string signatureLegacyId = null,
            int? challengeLifeNumber = null)
        {
            Seed = seed;
            PresetId = presetId;
            PlayerName = playerName;
            Region = region;
            LifeNumber = lifeNumber;
            InheritedMemories = (inheritedMemories ?? Array.Empty<string>()).ToArray();
            InheritedSoul = inheritedSoul;
            Karmas = (karmas ?? Array.Empty<string>()).ToArray();
            InheritedSoulDomain = inheritedSoulDomain;
            SoulBoosts = (soulBoosts ?? Array.Empty<string>()).ToArray();
            Difficulty = string.IsNullOrWhiteSpace(difficulty) ? "standard" : difficulty;
            SignatureLegacyId = signatureLegacyId;
            ChallengeLifeNumber = challengeLifeNumber;
        }

        public string Seed { get; }
        public string PresetId { get; }
        public string PlayerName { get; }
        public string Region { get; }
        public int LifeNumber { get; }
        public IReadOnlyList<string> InheritedMemories { get; }
        public int InheritedSoul { get; }
        public IReadOnlyList<string> Karmas { get; }
        public string InheritedSoulDomain { get; }
        public IReadOnlyList<string> SoulBoosts { get; }
        public string Difficulty { get; }
        public string SignatureLegacyId { get; }
        public int? ChallengeLifeNumber { get; }
        public bool IsChallenge => ChallengeLifeNumber.HasValue;
    }


    public sealed class HighSchoolAction
    {
        public HighSchoolAction(string kind, string value = null)
        {
            Kind = kind;
            Value = value;
        }

        public string Kind { get; }
        public string Value { get; }
    }


    public sealed class PitchGameReport
    {
        public PitchGameReport(
            string gameId,
            int pitches,
            int batters,
            int outs,
            int strikeouts,
            int walks,
            int hits,
            int runsAllowed,
            int sequenceMasteryCount = 0,
            int expectedDamage = 0,
            int actualDamage = 0,
            int recommendationAccepted = 0,
            int directDeliveryCount = 0,
            int deliveryScoreTotal = 0,
            int bestDeliveryScore = 0,
            int perfectDeliveryCount = 0,
            int rivalStrikeouts = 0,
            int abilityMomentCount = 0,
            IReadOnlyList<string> abilityMomentTypes = null,
            int? homeRuns = null)
        {
            GameId = gameId;
            Pitches = pitches;
            Batters = batters;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits;
            RunsAllowed = runsAllowed;
            SequenceMasteryCount = sequenceMasteryCount;
            ExpectedDamage = expectedDamage;
            ActualDamage = actualDamage;
            RecommendationAccepted = recommendationAccepted;
            DirectDeliveryCount = directDeliveryCount;
            DeliveryScoreTotal = deliveryScoreTotal;
            BestDeliveryScore = bestDeliveryScore;
            PerfectDeliveryCount = perfectDeliveryCount;
            RivalStrikeouts = rivalStrikeouts;
            AbilityMomentCount = abilityMomentCount;
            AbilityMomentTypes = (abilityMomentTypes ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
            HomeRuns = homeRuns;
        }

        public string GameId { get; }
        public int Pitches { get; }
        public int Batters { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int Hits { get; }
        public int RunsAllowed { get; }
        public int SequenceMasteryCount { get; }
        public int ExpectedDamage { get; }
        public int ActualDamage { get; }
        public int RecommendationAccepted { get; }
        public int DirectDeliveryCount { get; }
        public int DeliveryScoreTotal { get; }
        public int BestDeliveryScore { get; }
        public int PerfectDeliveryCount { get; }
        /// <summary>Strikeouts against the named high-school rival, supplied by the typed lineup report.</summary>
        public int RivalStrikeouts { get; }
        public int AbilityMomentCount { get; }
        public IReadOnlyList<string> AbilityMomentTypes { get; }
        /// <summary>Null means the pitch-session source did not classify home runs.</summary>
        public int? HomeRuns { get; }
        public int? AverageDeliveryScore => DirectDeliveryCount == 0
            ? (int?)null
            : DeliveryScoreTotal / DirectDeliveryCount;
    }
}
