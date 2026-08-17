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
        public HighSchoolCareerReadModel Apply(
            HighSchoolCareerReadModel current,
            HighSchoolAction action)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (action == null || string.IsNullOrWhiteSpace(action.Kind))
                throw new ArgumentException("A high-school action is required.", nameof(action));
            var state = Restore(current);
            HighSchoolCareerResult result;
            var frozenSignatureCandidates = current.FrozenSignatureLegacyCandidates;
            var selectedSignatureLegacy = current.SelectedSignatureLegacy;
            var lifeDetail = current.LifeDetail;
            switch (action.Kind)
            {
                case "complete_prologue":
                    result = _engine.CompletePrologue(
                        new AdvanceCareerChapterParams(current.NextSeed, state));
                    break;
                case "choose_school":
                    result = _engine.ChooseSchool(new ChooseSchoolParams(
                        current.NextSeed,
                        state,
                        Parse<SchoolId>(action.Value)));
                    break;
                case "train":
                    var training = TrainingParts(action.Value);
                    var trainingFocus = Parse<TrainingFocus>(training[0]);
                    var trainingTarget = training.Length == 3 ? (PitchType?)Parse<PitchType>(training[2]) : null;
                    ValidateTrainingTarget(state, trainingFocus, trainingTarget);
                    result = _engine.CommitTraining(new CommitCareerTrainingParams(
                        current.NextSeed,
                        state,
                        trainingFocus,
                        Parse<TrainingIntensity>(training[1]),
                        trainingTarget));
                    break;
                case "train_block":
                    var blockTraining = TrainingParts(action.Value);
                    var blockFocus = Parse<TrainingFocus>(blockTraining[0]);
                    var blockTarget = blockTraining.Length == 3 ? (PitchType?)Parse<PitchType>(blockTraining[2]) : null;
                    ValidateTrainingTarget(state, blockFocus, blockTarget);
                    var block = _engine.CommitTrainingBlock(new CommitCareerTrainingBlockParams(
                        current.NextSeed,
                        state,
                        blockFocus,
                        Parse<TrainingIntensity>(blockTraining[1]),
                        blockTarget,
                        HighSchoolTrainingActionPayload.MaximumBlockSessions));
                    return Map(
                        block.Career,
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
                        current.RivalStrikeouts,
                        TrainingBlock(block.Block),
                        frozenSignatureCandidates,
                        selectedSignatureLegacy,
                        lifeDetail);
                case "relationship":
                    var relationshipResponse = Parse<RelationshipResponse>(action.Value);
                    result = _engine.ResolveRelationship(new ResolveCareerRelationshipParams(
                        current.NextSeed,
                        state,
                        relationshipResponse));
                    lifeDetail = RecordResponse(lifeDetail, relationshipResponse);
                    break;
                case "awakening":
                    result = _engine.ChooseAwakening(new ChooseCareerAwakeningParams(
                        current.NextSeed,
                        state,
                        Parse<AwakeningId>(action.Value)));
                    break;
                case "advance_chapter":
                    result = _engine.AdvanceChapter(
                        new AdvanceCareerChapterParams(current.NextSeed, state));
                    break;
                case "resolve_draft":
                    result = _engine.ResolveDraft(new ResolveDraftParams(current.NextSeed, state));
                    break;
                case "open_legacy":
                    result = _engine.OpenLegacy(
                        new AdvanceCareerChapterParams(current.NextSeed, state));
                    break;
                case "select_legacy":
                    result = _engine.SelectLegacy(new SelectCareerLegacyParams(
                        current.NextSeed,
                        state,
                        ParseCsv<MemoryCardId>(action.Value)));
                    break;
                case "select_signature_legacy":
                    selectedSignatureLegacy = SelectFrozenSignatureLegacy(
                        state,
                        frozenSignatureCandidates,
                        Parse<CareerSignatureLegacyId>(action.Value));
                    result = _engine.SelectLegacy(new SelectCareerLegacyParams(
                        current.NextSeed,
                        state,
                        Array.Empty<MemoryCardId>(),
                        Parse<CareerSignatureLegacyId>(action.Value)));
                    break;
                default:
                    throw new InvalidOperationException("high_school.action_unsupported:" + action.Kind);
            }
            return Map(
                result,
                current.PledgeId,
                current.PledgeDecided,
                current.EquippedSignatureLegacyId,
                string.Equals(action.Kind, "select_signature_legacy", StringComparison.Ordinal)
                    ? action.Value
                    : current.SelectedSignatureLegacyId,
                current.Difficulty,
                current.IsChallengeRun,
                current.LegacySelectionMode,
                current.TutorialCompleted,
                current.TutorialAttemptCount,
                current.PledgeRulesVersion,
                current.RivalStrikeouts,
                frozenSignatureLegacyCandidates: frozenSignatureCandidates,
                selectedSignatureLegacy: selectedSignatureLegacy,
                priorLifeDetail: lifeDetail);
        }
    }
}
