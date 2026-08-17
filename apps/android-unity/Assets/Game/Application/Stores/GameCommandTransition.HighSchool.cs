using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Application.Stores
{
    public sealed partial class GameCommandTransition
    {

        private TransitionResult<GameSaveAggregate> StartHighSchool(
            GameSaveAggregate current,
            StartHighSchoolCareerCommand command,
            string commandId)
        {
            if (current.Stage != ApplicationStage.Setup || current.HighSchool != null || current.Pro != null)
                return Failure("high_school.start_not_available");
            var request = ResolvePersistedSetupDefaults(command.Request, current.Meta);
            if (string.IsNullOrWhiteSpace(request.Seed) ||
                string.IsNullOrWhiteSpace(request.PresetId) ||
                string.IsNullOrWhiteSpace(request.PlayerName) ||
                request.LifeNumber != current.Meta.LifeNumber)
            {
                return Failure("high_school.start_invalid");
            }

            var setupError = HighSchoolSetupCatalog.Validate(
                request,
                current.Meta.SoulBalance,
                current.Meta.AutomaticSoulEarned,
                current.Meta.InheritedMemories,
                current.Meta.UnlockedSignatureLegacyIds,
                HighSchoolSetupCatalog.IsRebirth(current.Meta));
            if (setupError != null) return Failure(setupError);

            var started = _highSchool.Start(request);
            if (!ValidStartedHighSchool(
                    started,
                    request.ChallengeLifeNumber ?? current.Meta.LifeNumber) ||
                started.IsChallengeRun != request.IsChallenge)
                return Failure("high_school.port_invalid");
            var meta = current.Meta;
            if (!request.IsChallenge)
            {
                var achievements = AchievementRules.Unlock(
                    meta.Achievements,
                    AchievementRules.FromLifeNumber(started.LifeNumber));
                var lastSetup = new HighSchoolLastSetupState(
                    request.PresetId,
                    request.PlayerName,
                    request.Region,
                    request.Difficulty,
                    request.Karmas,
                    request.InheritedSoulDomain);
                meta = meta.With(
                    soulBalance: meta.SoulBalance -
                        HighSchoolSetupCatalog.SoulBoostCost(request.SoulBoosts),
                    achievements: achievements,
                    lastHighSchoolSetup: lastSetup,
                    equippedSignatureLegacyId: request.SignatureLegacyId,
                    clearReturnPlan: true);
            }
            return Success(current.Commit(
                commandId,
                stage: StageFor(started),
                highSchool: started,
                clearPro: true,
                meta: meta,
                clearPitchResume: true,
                clearPendingPitchCompletion: true));
        }

        private static StartHighSchoolCareerRequest ResolvePersistedSetupDefaults(
            StartHighSchoolCareerRequest request,
            MetaProgressState meta)
        {
            if (request == null || meta == null || request.IsChallenge) return request;
            var memories = request.InheritedMemories.Count == 0
                ? meta.InheritedMemories
                : request.InheritedMemories;
            var signatureLegacyId = string.IsNullOrWhiteSpace(request.SignatureLegacyId)
                ? meta.EquippedSignatureLegacyId
                : request.SignatureLegacyId;
            var soulDomain = HighSchoolSetupCatalog.ResolveInheritedSoulDomain(
                request.InheritedSoulDomain,
                request.InheritedSoul);
            if (ReferenceEquals(memories, request.InheritedMemories) &&
                string.Equals(
                    signatureLegacyId,
                    request.SignatureLegacyId,
                    StringComparison.Ordinal) &&
                string.Equals(soulDomain, request.InheritedSoulDomain, StringComparison.Ordinal))
            {
                return request;
            }
            return new StartHighSchoolCareerRequest(
                request.Seed,
                request.PresetId,
                request.PlayerName,
                request.Region,
                request.LifeNumber,
                memories,
                request.InheritedSoul,
                request.Karmas,
                soulDomain,
                request.SoulBoosts,
                request.Difficulty,
                signatureLegacyId,
                request.ChallengeLifeNumber);
        }

        private TransitionResult<GameSaveAggregate> StartQuickRebirth(
            GameSaveAggregate current,
            StartQuickRebirthCommand command,
            string commandId)
        {
            if (!HighSchoolSetupCatalog.IsRebirth(current.Meta) ||
                current.Meta.LastHighSchoolSetup == null)
            {
                return Failure("high_school.quick_rebirth_not_available");
            }
            var prepared = current;
            if (current.Stage == ApplicationStage.Legacy ||
                current.Stage == ApplicationStage.Retirement)
            {
                var currentLife = current.HighSchool?.LifeNumber ?? current.Meta.LifeNumber;
                if (!current.Meta.LifeArchive.Any(record => record.LifeNumber == currentLife))
                    return Failure("high_school.quick_rebirth_not_available");
                var weekly = WeeklyProgramRules.Record(
                    current.Meta.Weekly,
                    WeeklyTaskKinds.NextRunStarted,
                    1,
                    commandId + ":next-run",
                    command.StartedAt);
                var rebornMeta = current.Meta.With(
                    lifeNumber: Math.Max(current.Meta.LifeNumber + 1, currentLife + 1),
                    weekly: weekly,
                    clearReturnPlan: true);
                prepared = RebaseForQuickStart(current, rebornMeta);
            }
            else if (current.Stage == ApplicationStage.BetweenLives)
            {
                prepared = RebaseForQuickStart(current, current.Meta);
            }
            else if (current.Stage != ApplicationStage.Setup ||
                     current.HighSchool != null || current.Pro != null)
            {
                return Failure("high_school.quick_rebirth_not_available");
            }

            var last = prepared.Meta.LastHighSchoolSetup;
            var request = new StartHighSchoolCareerRequest(
                DeterministicSeed.Normalize(
                    prepared.InstallId + "|" + command.EntryPoint + "|" + prepared.Meta.LifeNumber),
                last.PresetId,
                last.PlayerName,
                last.Region,
                prepared.Meta.LifeNumber,
                prepared.Meta.InheritedMemories,
                prepared.Meta.AutomaticSoulEarned,
                last.Karmas,
                last.SoulDomain,
                Array.Empty<string>(),
                last.Difficulty,
                prepared.Meta.EquippedSignatureLegacyId);
            return StartHighSchool(
                prepared,
                new StartHighSchoolCareerCommand(request),
                commandId);
        }

        private static GameSaveAggregate RebaseForQuickStart(
            GameSaveAggregate current,
            MetaProgressState meta)
        {
            return new GameSaveAggregate(
                current.AggregateVersion,
                current.Revision,
                current.InstallId,
                ApplicationStage.Setup,
                null,
                null,
                meta,
                null,
                null,
                current.CommandReceipts,
                current.Deleted,
                current.Settings,
                current.AnalyticsReceipts);
        }

        private static TransitionResult<GameSaveAggregate> EndChallengeRun(
            GameSaveAggregate current,
            string commandId)
        {
            var highSchool = current.HighSchool;
            if (highSchool?.IsChallengeRun != true || current.Pro != null ||
                (highSchool.Phase != HighSchoolPhase.Draft &&
                 highSchool.Phase != HighSchoolPhase.Legacy &&
                 highSchool.Phase != HighSchoolPhase.Completed))
            {
                return Failure("high_school.challenge_end_not_available");
            }
            return Success(current.Commit(
                commandId,
                stage: ApplicationStage.Setup,
                clearHighSchool: true,
                clearPitchResume: true,
                clearPendingPitchCompletion: true));
        }

        private TransitionResult<GameSaveAggregate> AdvanceHighSchool(
            GameSaveAggregate current,
            AdvanceHighSchoolCommand command,
            string commandId)
        {
            if (current.HighSchool == null || current.Pro != null || current.PitchResume != null ||
                current.PendingPitchCompletion != null)
                return Failure("high_school.not_active");
            if (string.IsNullOrWhiteSpace(command.Action.Kind))
                return Failure("high_school.action_invalid");
            if (string.Equals(command.Action.Kind, "record_important_game", StringComparison.Ordinal))
                return Failure("high_school.use_pitch_command");
            if (string.Equals(command.Action.Kind, "complete_prologue", StringComparison.Ordinal) &&
                !current.HighSchool.TutorialCompleted)
            {
                return Failure("high_school.tutorial_required");
            }
            if (!ValidHighSchoolChoice(current.HighSchool, command.Action))
                return Failure("high_school.choice_invalid");

            var before = current.HighSchool;
            var updated = _highSchool.Apply(before, command.Action);
            if (!ValidHighSchoolAdvance(before, updated))
                return Failure("high_school.port_invalid");

            if (before.IsChallengeRun)
            {
                return Success(current.Commit(
                    commandId,
                    stage: StageFor(updated),
                    highSchool: updated));
            }

            var meta = current.Meta;
            var weekly = meta.Weekly;
            if (updated.ChapterNumber > before.ChapterNumber)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.ChaptersAdvanced,
                    updated.ChapterNumber - before.ChapterNumber,
                    commandId + ":chapters",
                    command.OccurredAt);
            }
            if (!before.PledgeDecided && updated.PledgeDecided)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.PledgeSelected,
                    1,
                    commandId + ":pledge",
                    command.OccurredAt);
            }
            if (before.SchoolId == null && updated.SchoolId != null &&
                meta.LifeArchive.Count > 0 &&
                !string.Equals(meta.LifeArchive[0].SchoolId, updated.SchoolId, StringComparison.Ordinal))
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.DifferentSchoolSelected,
                    1,
                    commandId + ":school",
                    command.OccurredAt);
            }
            var achievements = AchievementRules.Unlock(
                meta.Achievements,
                AchievementRules.FromHighSchool(updated));
            meta = meta.With(weekly: weekly, achievements: achievements);
            return Success(current.Commit(
                commandId,
                stage: StageFor(updated),
                highSchool: updated,
                meta: meta));
        }

        private static TransitionResult<GameSaveAggregate> ChoosePledge(
            GameSaveAggregate current,
            ChoosePledgeCommand command,
            string commandId)
        {
            if (current.HighSchool == null || current.Pro != null || current.HighSchool.PledgeDecided)
                return Failure("pledge.not_available");
            if (!RunPledgeRules.IsValidSelection(current, command.PledgeId))
                return Failure("pledge.choice_invalid");
            var updated = CopyPledge(current.HighSchool, command.PledgeId);
            var weekly = current.Meta.Weekly;
            if (!string.IsNullOrWhiteSpace(command.PledgeId))
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.PledgeSelected,
                    1,
                    commandId + ":pledge",
                    command.ChosenAt);
            }
            var meta = current.Meta.With(weekly: weekly, clearNextRunIntent: true);
            return Success(current.Commit(commandId, highSchool: updated, meta: meta));
        }

        private TransitionResult<GameSaveAggregate> SkipTutorial(
            GameSaveAggregate current,
            string commandId)
        {
            var before = current.HighSchool;
            if (before?.Phase != HighSchoolPhase.Prologue || current.Pro != null ||
                current.PitchResume != null || current.PendingPitchCompletion != null)
            {
                return Failure("high_school.tutorial_skip_not_available");
            }
            var updated = _highSchool.Apply(before, new HighSchoolAction("complete_prologue"));
            if (!ValidHighSchoolAdvance(before, updated) ||
                updated.Phase != HighSchoolPhase.SchoolSelection ||
                updated.TutorialCompleted != before.TutorialCompleted ||
                updated.TutorialAttemptCount != before.TutorialAttemptCount ||
                !SameRatings(before.Ratings, updated.Ratings) ||
                !SamePerformance(before.Performance, updated.Performance))
            {
                return Failure("high_school.tutorial_skip_port_invalid");
            }
            return Success(current.Commit(
                commandId,
                stage: ApplicationStage.HighSchool,
                highSchool: updated));
        }

        private static TransitionResult<GameSaveAggregate> ArchiveHighSchoolLife(
            GameSaveAggregate current,
            ArchiveHighSchoolLifeCommand command,
            string commandId)
        {
            return ArchiveHighSchoolLife(
                current,
                current.HighSchool,
                command.Memories,
                command.CompletedAt,
                commandId);
        }

        private TransitionResult<GameSaveAggregate> FinalizeHighSchoolLegacy(
            GameSaveAggregate current,
            FinalizeHighSchoolLegacyCommand command,
            string commandId)
        {
            var highSchool = current.HighSchool;
            if (highSchool == null || highSchool.IsChallengeRun ||
                highSchool.Phase != HighSchoolPhase.Legacy)
            {
                return Failure("legacy.high_school_not_ready");
            }

            HighSchoolAction selection;
            if (highSchool.LegacySelectionMode == LegacySelectionMode.SignatureLegacy)
            {
                if (command.Memories.Count != 0 || string.IsNullOrWhiteSpace(command.SignatureLegacyId))
                    return Failure("legacy.selection_invalid");
                selection = new HighSchoolAction("select_signature_legacy", command.SignatureLegacyId);
            }
            else
            {
                if (!string.IsNullOrWhiteSpace(command.SignatureLegacyId))
                    return Failure("legacy.selection_invalid");
                selection = new HighSchoolAction(
                    "select_legacy",
                    string.Join(",", command.Memories));
            }
            if (!ValidHighSchoolChoice(highSchool, selection))
                return Failure("legacy.selection_invalid");

            var selected = _highSchool.Apply(highSchool, selection);
            if (!ValidHighSchoolAdvance(highSchool, selected) ||
                selected.Phase != HighSchoolPhase.Completed)
            {
                return Failure("legacy.selection_port_invalid");
            }
            return ArchiveHighSchoolLife(
                current,
                selected,
                command.Memories,
                command.CompletedAt,
                commandId);
        }

        private static TransitionResult<GameSaveAggregate> ArchiveHighSchoolLife(
            GameSaveAggregate current,
            HighSchoolCareerReadModel highSchool,
            IReadOnlyList<string> memories,
            DateTimeOffset completedAt,
            string commandId)
        {
            var pro = current.Pro;
            if (highSchool == null ||
                !(highSchool.Phase == HighSchoolPhase.Legacy ||
                  highSchool.Phase == HighSchoolPhase.Completed ||
                  highSchool.Draft?.Resolved == true && !highSchool.Draft.Drafted))
            {
                return Failure("legacy.high_school_not_ready");
            }
            if (memories.Any(string.IsNullOrWhiteSpace))
                return Failure("legacy.memory_invalid");
            if (highSchool.LegacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                (highSchool.SelectedSignatureLegacy == null ||
                 string.IsNullOrWhiteSpace(highSchool.SelectedSignatureLegacyId)))
            {
                return Failure("legacy.signature_selection_required");
            }
            if (pro != null &&
                (pro.Origin != ProCareerOrigin.HighSchool ||
                 pro.Phase != ProCareerPhase.Completed ||
                 !string.Equals(pro.SourceHighSchoolCareerId, highSchool.CareerId, StringComparison.Ordinal) ||
                 !current.Meta.CreditedProCareerIds.Contains(pro.ProCareerId, StringComparer.Ordinal)))
            {
                return Failure("legacy.pro_source_invalid");
            }
            if (highSchool.IsChallengeRun)
            {
                return Success(current.Commit(
                    commandId,
                    stage: ApplicationStage.Setup,
                    clearHighSchool: true,
                    clearPitchResume: true,
                    clearPendingPitchCompletion: true));
            }

            var lifeId = "life:" + highSchool.LifeNumber + ":" + highSchool.CareerId +
                (pro == null ? string.Empty : ":" + pro.ProCareerId);
            var exists = current.Meta.LifeArchive.Any(record =>
                string.Equals(record.LifeId, lifeId, StringComparison.Ordinal));
            if (exists) return Failure("legacy.already_archived");
            var reward = HighSchoolSoulReward(highSchool);
            var archive = current.Meta.LifeArchive;
            var record = MakeLifeRecord(
                lifeId,
                highSchool.LifeNumber,
                highSchool,
                pro,
                reward,
                memories,
                completedAt);
            archive = new[] { record }.Concat(archive).ToArray();
            var achievements = AchievementRules.Unlock(
                pro == null
                    ? current.Meta.Achievements
                    : AchievementRules.Unlock(
                        current.Meta.Achievements,
                        AchievementRules.FromPro(pro)),
                AchievementRules.FromArchive(archive));
            var selectedSignature = highSchool.SelectedSignatureLegacyId;
            var unlockedSignatures = string.IsNullOrWhiteSpace(selectedSignature)
                ? current.Meta.UnlockedSignatureLegacyIds
                : current.Meta.UnlockedSignatureLegacyIds
                    .Concat(new[] { selectedSignature })
                    .Distinct(StringComparer.Ordinal)
                    .ToArray();
            var meta = current.Meta.With(
                soulBalance: current.Meta.SoulBalance + reward,
                soulLifetimeEarned: current.Meta.SoulLifetimeEarned + reward,
                automaticSoulEarned: current.Meta.AutomaticSoulEarned + reward,
                inheritedMemories: string.IsNullOrWhiteSpace(selectedSignature)
                    ? memories
                    : Array.Empty<string>(),
                lifeArchive: archive,
                achievements: achievements,
                unlockedSignatureLegacyIds: unlockedSignatures,
                equippedSignatureLegacyId: selectedSignature);
            return Success(current.Commit(
                commandId,
                stage: ApplicationStage.Legacy,
                highSchool: highSchool,
                meta: meta,
                clearPro: pro != null));
        }

        private static TransitionResult<GameSaveAggregate> BeginRebirth(
            GameSaveAggregate current,
            BeginRebirthCommand command,
            string commandId)
        {
            if (current.Stage != ApplicationStage.Legacy &&
                current.Stage != ApplicationStage.Retirement)
            {
                return Failure("rebirth.not_ready");
            }
            var currentLife = current.HighSchool?.LifeNumber ?? current.Meta.LifeNumber;
            if (!current.Meta.LifeArchive.Any(record => record.LifeNumber == currentLife))
                return Failure("rebirth.life_not_archived");
            var weekly = WeeklyProgramRules.Record(
                current.Meta.Weekly,
                WeeklyTaskKinds.NextRunStarted,
                1,
                commandId + ":next-run",
                command.StartedAt);
            var meta = current.Meta.With(
                lifeNumber: Math.Max(current.Meta.LifeNumber + 1, currentLife + 1),
                weekly: weekly,
                clearReturnPlan: true);
            return Success(current.Commit(
                commandId,
                // A custom rebirth must be immediately startable after the durable boundary.
                // BetweenLives remains a readable legacy-save stage, but new commands commit the
                // same Setup state the editor UI is about to submit.
                stage: ApplicationStage.Setup,
                clearHighSchool: true,
                clearPro: true,
                meta: meta,
                clearPitchResume: true,
                clearPendingPitchCompletion: true));
        }

        private static LifeArchiveRecord MakeLifeRecord(
            string lifeId,
            int lifeNumber,
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro,
            int soulEarned,
            IReadOnlyList<string> memories,
            DateTimeOffset completedAt)
        {
            var playerName = highSchool?.PlayerName ?? pro?.PlayerName;
            var ratings = highSchool?.Ratings ?? pro?.Ratings;
            var pledge = PledgeSettlement(highSchool);
            var playerLegacy = PlayerLegacyRules.Freeze(
                highSchool,
                pro,
                memories,
                pledge?.Progress?.Achieved);
            return new LifeArchiveRecord(
                lifeId,
                lifeNumber,
                playerName,
                highSchool?.CareerId,
                pro?.ProCareerId,
                highSchool?.SchoolId,
                highSchool?.SchoolName,
                highSchool?.Draft?.Drafted ?? false,
                highSchool?.Draft?.EvaluationScore ?? 0,
                ratings,
                highSchool?.Performance ?? new CareerPerformanceReadModel(),
                pro?.CareerSeasons.Count ?? 0,
                pro?.CareerStrikeouts ?? 0,
                pro?.Awards ?? 0,
                pro?.HallOfFameScore ?? 0,
                soulEarned,
                highSchool?.Karmas,
                highSchool?.Awakenings,
                memories,
                completedAt.ToUnixTimeSeconds(),
                pledge?.Id,
                pledge?.Title,
                pledge?.TierId,
                pledge?.RewardPermille,
                pledge?.Progress?.Achieved,
                pledge?.Progress?.Current,
                pledge?.Progress?.Target,
                pledge?.Progress?.Line,
                pledge?.Progress?.RatioPermille,
                highSchool == null ? 0 : RunPledgeRules.EffectiveRulesVersion(highSchool),
                RunPledgeRules.SuggestedNextRunIntent(highSchool),
                playerLegacy,
                highSchool?.LifeDetail,
                highSchool?.SelectedSignatureLegacy,
                highSchool?.FrozenSignatureLegacyCandidates,
                highSchool?.Performance?.Pitches,
                highSchool?.Performance?.Outs,
                highSchool?.Performance?.Hits,
                highSchool?.Draft?.TeamName);
        }

        private static int HighSchoolSoulReward(HighSchoolCareerReadModel state)
        {
            var record = state.Performance.Strikeouts * 2 - state.Performance.Walks -
                state.Performance.RunsAllowed * 2;
            var baseReward = Math.Max(4, state.Ratings.Total / 8 + Math.Max(0, record) / 4);
            var pledge = PledgeSettlement(state);
            var pledgeBonus = pledge?.Progress?.Achieved == true ? pledge.RewardPermille : 0;
            var multiplier = Math.Max(1000, state.LegacyRewardPermille) + pledgeBonus;
            return (int)Math.Min(int.MaxValue, (long)baseReward * multiplier / 1000L);
        }

        private static RunPledgeReadModel PledgeSettlement(HighSchoolCareerReadModel state)
        {
            if (state == null || string.IsNullOrWhiteSpace(state.PledgeId)) return null;
            return RunPledgeRules.Resolve(
                state.PledgeId,
                RunPledgeRules.EffectiveRulesVersion(state),
                state);
        }

        private static HighSchoolCareerReadModel CopyPledge(
            HighSchoolCareerReadModel value,
            string pledgeId)
        {
            return new HighSchoolCareerReadModel(
                value.CareerId,
                value.LifeNumber,
                value.Phase,
                value.NextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.PresetId,
                value.Ratings,
                value.Performance,
                value.SchoolId,
                value.SchoolName,
                value.SchoolYear,
                value.ChapterNumber,
                value.RemainingImportantGames,
                value.RemainingChapterAdvances,
                value.Draft,
                value.CoreStateJson,
                pledgeId,
                true,
                value.Karmas,
                value.Awakenings,
                value.SchoolChoices,
                value.TrainingFocusChoices,
                value.TrainingIntensityChoices,
                value.RelationshipChoices,
                value.AwakeningChoices,
                value.LegacyMemoryChoices,
                value.MemorySlots,
                value.Tournament,
                value.ProspectRankings,
                value.GameLines,
                value.SignatureLegacyChoices,
                value.EquippedSignatureLegacyId,
                value.SelectedSignatureLegacyId,
                value.Difficulty,
                value.IsChallengeRun,
                value.LegacySelectionMode,
                value.TutorialCompleted,
                value.TutorialAttemptCount,
                RunPledgeRules.CurrentRulesVersion,
                value.LegacyRewardPermille,
                value.RivalStrikeouts,
                value.Fatigue,
                value.ArmRisk,
                value.InjuryRecovery,
                value.ManagerTrust,
                value.CatcherTrust,
                value.RivalTrust,
                value.FanInterest,
                value.DraftForecastScore,
                value.ChapterProgress,
                value.ScheduleMilestones,
                value.CurrentRelationshipEvent,
                value.CurrentGameScenario,
                value.LastTraining,
                value.LastRelationship,
                value.News,
                value.TrainingPitchChoices,
                value.LastTrainingBlock,
                value.MaximumTrainingBlockSessions,
                value.FrozenSignatureLegacyCandidates,
                value.SelectedSignatureLegacy,
                value.LifeDetail,
                value.TrainingOutlooks);
        }

        private static HighSchoolCareerReadModel CopySignatureLegacyState(
            HighSchoolCareerReadModel value,
            IReadOnlyList<SignatureLegacyReadModel> candidates,
            SignatureLegacyReadModel selected)
        {
            candidates = (candidates ?? Array.Empty<SignatureLegacyReadModel>()).ToArray();
            return new HighSchoolCareerReadModel(
                value.CareerId,
                value.LifeNumber,
                value.Phase,
                value.NextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.PresetId,
                value.Ratings,
                value.Performance,
                value.SchoolId,
                value.SchoolName,
                value.SchoolYear,
                value.ChapterNumber,
                value.RemainingImportantGames,
                value.RemainingChapterAdvances,
                value.Draft,
                value.CoreStateJson,
                value.PledgeId,
                value.PledgeDecided,
                value.Karmas,
                value.Awakenings,
                value.SchoolChoices,
                value.TrainingFocusChoices,
                value.TrainingIntensityChoices,
                value.RelationshipChoices,
                value.AwakeningChoices,
                value.LegacyMemoryChoices,
                value.MemorySlots,
                value.Tournament,
                value.ProspectRankings,
                value.GameLines,
                candidates.Select(candidate => new CareerChoiceReadModel(
                    candidate.Id,
                    candidate.Title,
                    candidate.Detail,
                    candidate.EvidenceSummary)).ToArray(),
                value.EquippedSignatureLegacyId,
                selected?.Id,
                value.Difficulty,
                value.IsChallengeRun,
                LegacySelectionMode.SignatureLegacy,
                value.TutorialCompleted,
                value.TutorialAttemptCount,
                value.PledgeRulesVersion,
                value.LegacyRewardPermille,
                value.RivalStrikeouts,
                value.Fatigue,
                value.ArmRisk,
                value.InjuryRecovery,
                value.ManagerTrust,
                value.CatcherTrust,
                value.RivalTrust,
                value.FanInterest,
                value.DraftForecastScore,
                value.ChapterProgress,
                value.ScheduleMilestones,
                value.CurrentRelationshipEvent,
                value.CurrentGameScenario,
                value.LastTraining,
                value.LastRelationship,
                value.News,
                value.TrainingPitchChoices,
                value.LastTrainingBlock,
                value.MaximumTrainingBlockSessions,
                candidates,
                selected,
                value.LifeDetail,
                value.TrainingOutlooks);
        }

        private static HighSchoolCareerReadModel CopyTutorialState(
            HighSchoolCareerReadModel value,
            bool completed,
            int attemptCount)
        {
            return new HighSchoolCareerReadModel(
                value.CareerId,
                value.LifeNumber,
                value.Phase,
                value.NextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.PresetId,
                value.Ratings,
                value.Performance,
                value.SchoolId,
                value.SchoolName,
                value.SchoolYear,
                value.ChapterNumber,
                value.RemainingImportantGames,
                value.RemainingChapterAdvances,
                value.Draft,
                value.CoreStateJson,
                value.PledgeId,
                value.PledgeDecided,
                value.Karmas,
                value.Awakenings,
                value.SchoolChoices,
                value.TrainingFocusChoices,
                value.TrainingIntensityChoices,
                value.RelationshipChoices,
                value.AwakeningChoices,
                value.LegacyMemoryChoices,
                value.MemorySlots,
                value.Tournament,
                value.ProspectRankings,
                value.GameLines,
                value.SignatureLegacyChoices,
                value.EquippedSignatureLegacyId,
                value.SelectedSignatureLegacyId,
                value.Difficulty,
                value.IsChallengeRun,
                value.LegacySelectionMode,
                tutorialCompleted: completed,
                tutorialAttemptCount: attemptCount,
                pledgeRulesVersion: value.PledgeRulesVersion,
                legacyRewardPermille: value.LegacyRewardPermille,
                rivalStrikeouts: value.RivalStrikeouts,
                fatigue: value.Fatigue,
                armRisk: value.ArmRisk,
                injuryRecovery: value.InjuryRecovery,
                managerTrust: value.ManagerTrust,
                catcherTrust: value.CatcherTrust,
                rivalTrust: value.RivalTrust,
                fanInterest: value.FanInterest,
                draftForecastScore: value.DraftForecastScore,
                chapterProgress: value.ChapterProgress,
                scheduleMilestones: value.ScheduleMilestones,
                currentRelationshipEvent: value.CurrentRelationshipEvent,
                currentGameScenario: value.CurrentGameScenario,
                lastTraining: value.LastTraining,
                lastRelationship: value.LastRelationship,
                news: value.News,
                trainingPitchChoices: value.TrainingPitchChoices,
                lastTrainingBlock: value.LastTrainingBlock,
                maximumTrainingBlockSessions: value.MaximumTrainingBlockSessions,
                frozenSignatureLegacyCandidates: value.FrozenSignatureLegacyCandidates,
                selectedSignatureLegacy: value.SelectedSignatureLegacy,
                lifeDetail: value.LifeDetail,
                trainingOutlooks: value.TrainingOutlooks);
        }
    }
}
