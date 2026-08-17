using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Random;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;

namespace Baseball.Application.HighSchool
{
    /// <summary>
    /// Adapter for the Unity Core port. Only this file understands Core command DTOs; the save
    /// aggregate and presentation-facing contracts stay independent of engine implementation.
    /// </summary>
    public sealed partial class CoreHighSchoolCareerPort :
        IHighSchoolCareerPort,
        IHighSchoolPitchScenarioPort,
        IHighSchoolTutorialScenarioPort
    {
        private readonly HighSchoolCareerEngine _engine;
        private readonly JsonSerializerSettings _snapshotSettings;

        public CoreHighSchoolCareerPort()
        {
            _engine = new HighSchoolCareerEngine();
            _snapshotSettings = new JsonSerializerSettings
            {
                ConstructorHandling = ConstructorHandling.AllowNonPublicDefaultConstructor,
                ContractResolver = new InternalSetterContractResolver(),
                MissingMemberHandling = MissingMemberHandling.Ignore,
                NullValueHandling = NullValueHandling.Include,
                ObjectCreationHandling = ObjectCreationHandling.Replace,
                TypeNameHandling = TypeNameHandling.None
            };
            _snapshotSettings.Converters.Add(new StringEnumConverter());
        }

        public HighSchoolCareerReadModel Start(StartHighSchoolCareerRequest request)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            var memories = ParseMany<MemoryCardId>(request.InheritedMemories);
            var karmas = ParseMany<KarmaId>(request.Karmas);
            var boosts = ParseMany<SoulBoostId>(request.SoulBoosts);
            var resolvedSoulDomain = HighSchoolSetupCatalog.ResolveInheritedSoulDomain(
                request.InheritedSoulDomain,
                request.InheritedSoul);
            var soulDomain = string.IsNullOrWhiteSpace(resolvedSoulDomain)
                ? (SoulDomain?)null
                : Parse<SoulDomain>(resolvedSoulDomain);
            var difficulty = Parse<DifficultyLevel>(request.Difficulty);
            var signatureLegacy = string.IsNullOrWhiteSpace(request.SignatureLegacyId)
                ? (CareerSignatureLegacyId?)null
                : Parse<CareerSignatureLegacyId>(request.SignatureLegacyId);
            var identity = new PlayerIdentitySnapshot(
                request.PlayerName,
                ThrowingHand.Right,
                BodyType.Balanced,
                request.Region);
            var result = _engine.Start(new StartHighSchoolCareerParams(
                DeterministicSeed.Normalize(request.Seed),
                request.PresetId,
                request.ChallengeLifeNumber ?? request.LifeNumber,
                inheritedSoulPoints: request.InheritedSoul,
                inheritedSoulDomain: soulDomain,
                inheritedMemories: memories,
                identity: identity,
                difficulty: new CareerDifficultySnapshot(difficulty),
                karmas: karmas,
                soulBoosts: boosts.Count == 0 ? null : boosts,
                inheritedSoulTotal: request.InheritedSoul,
                signatureLegacyId: signatureLegacy,
                inheritanceRulesVersion: 2));
            return Map(
                result,
                equippedSignatureLegacyId: request.SignatureLegacyId,
                difficulty: request.Difficulty,
                isChallengeRun: request.IsChallenge,
                legacySelectionMode: request.IsChallenge
                    ? LegacySelectionMode.Memories
                    : LegacySelectionMode.SignatureLegacy,
                startingRatings: Ratings(result.Snapshot.Pitcher));
        }

    }
}
