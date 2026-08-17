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
    public sealed partial class CoreHighSchoolCareerPort
    {
        public HighSchoolCareerReadModel ReservePitch(
            HighSchoolCareerReadModel current,
            string scenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            // Match iOS: the advanced seed becomes both the session seed and the next Core input.
            return CopyWithNextSeed(current, AdvanceSeed(current.NextSeed));
        }

        public PitchScenarioReadModel CreatePitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (string.IsNullOrWhiteSpace(requestedScenarioId))
                throw new ArgumentException("A requested scenario ID is required.", nameof(requestedScenarioId));
            return PitchScenarioFactory.HighSchool(Restore(current));
        }

        public PitchScenarioReadModel CreateTutorialPitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (string.IsNullOrWhiteSpace(requestedScenarioId))
                throw new ArgumentException("A requested scenario ID is required.", nameof(requestedScenarioId));
            return PitchScenarioFactory.Tutorial(Restore(current));
        }

        public HighSchoolCareerReadModel ApplyPitchResult(
            HighSchoolCareerReadModel current,
            PitchGameReport report)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (report == null) throw new ArgumentNullException(nameof(report));
            var state = Restore(current);
            var coreReport = new ImportantInningReport(
                state.Performance.ImportantGamesCompleted + 1,
                report.Pitches,
                report.Strikeouts,
                report.Walks,
                report.RunsAllowed,
                report.ExpectedDamage,
                report.ActualDamage,
                report.RecommendationAccepted,
                report.Outs,
                null,
                null,
                report.SequenceMasteryCount,
                report.Hits,
                report.HomeRuns);
            return Map(
                _engine.RecordImportantGame(new RecordCareerGameParams(
                    current.NextSeed,
                    state,
                    coreReport)),
                current.PledgeId,
                current.PledgeDecided,
                current.EquippedSignatureLegacyId,
                current.SelectedSignatureLegacyId,
                current.Difficulty,
                current.IsChallengeRun,
                current.LegacySelectionMode,
                current.TutorialCompleted,
                current.TutorialAttemptCount,
                current.PledgeRulesVersion,
                current.RivalStrikeouts + report.RivalStrikeouts,
                frozenSignatureLegacyCandidates: current.FrozenSignatureLegacyCandidates,
                selectedSignatureLegacy: current.SelectedSignatureLegacy,
                priorLifeDetail: current.LifeDetail);
        }
    }
}
