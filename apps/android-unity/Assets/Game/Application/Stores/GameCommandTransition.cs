using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;

namespace Baseball.Application.Stores
{
    public sealed class GameCommandTransition : IStateTransition<GameSaveAggregate, GameCommand>
    {
        private readonly IHighSchoolCareerPort _highSchool;
        private readonly IProCareerPort _pro;

        public GameCommandTransition(IHighSchoolCareerPort highSchool, IProCareerPort pro)
        {
            _highSchool = highSchool ?? throw new ArgumentNullException(nameof(highSchool));
            _pro = pro ?? throw new ArgumentNullException(nameof(pro));
        }

        public TransitionResult<GameSaveAggregate> Apply(
            GameSaveAggregate current,
            GameCommand command,
            string commandId)
        {
            if (current == null || command == null)
            {
                return Failure("command.invalid");
            }
            if (current.Deleted && !(command is DeleteSaveCommand))
            {
                return Failure("save.deleted_requires_reset");
            }

            try
            {
                switch (command)
                {
                    case EnterSetupCommand _:
                        return EnterSetup(current, commandId);
                    case StartHighSchoolCareerCommand value:
                        return StartHighSchool(current, value, commandId);
                    case StartQuickRebirthCommand value:
                        return StartQuickRebirth(current, value, commandId);
                    case EndChallengeRunCommand _:
                        return EndChallengeRun(current, commandId);
                    case UpdateGameSettingsCommand value:
                        return UpdateSettings(current, value, commandId);
                    case AdvanceHighSchoolCommand value:
                        return AdvanceHighSchool(current, value, commandId);
                    case SkipTutorialCommand _:
                        return SkipTutorial(current, commandId);
                    case ChoosePledgeCommand value:
                        return ChoosePledge(current, value, commandId);
                    case EnterProFromDraftCommand _:
                        return EnterProFromDraft(current, commandId);
                    case DeclineProCareerCommand _:
                        return DeclineProCareer(current, commandId);
                    case SignProContractCommand _:
                        return SignProContract(current, commandId);
                    case StartDirectProCommand value:
                        return StartDirectPro(current, value, commandId);
                    case AdvanceProCommand value:
                        return AdvancePro(current, value, commandId);
                    case BeginPitchSessionCommand value:
                        return BeginPitch(current, value, commandId);
                    case CheckpointPitchSessionCommand value:
                        return CheckpointPitch(current, value, commandId);
                    case CommitPitchResultCommand value:
                        return CommitPitchResult(current, value, commandId);
                    case ConsumeCommittedPitchResultCommand value:
                        return ConsumeCommittedPitchResult(current, value, commandId);
                    case RetryTutorialPitchCommand value:
                        return RetryTutorialPitch(current, value, commandId);
                    case CompletePitchSessionCommand value:
                        return CompletePitch(current, value, commandId);
                    case AcknowledgePitchResultCommand value:
                        return AcknowledgePitch(current, value, commandId);
                    case AbandonPitchSessionCommand value:
                        return AbandonPitch(current, value, commandId);
                    case ConfigureWeeklyProgramCommand value:
                        return ConfigureWeekly(current, value, commandId);
                    case RecordWeeklyProgressCommand value:
                        return RecordWeekly(current, value, commandId);
                    case CompleteDailyInningCommand value:
                        return CompleteDaily(current, value, commandId);
                    case ClaimWeeklyRewardCommand value:
                        return ClaimWeekly(current, value, commandId);
                    case UnlockAchievementsCommand value:
                        return UnlockAchievements(current, value, commandId);
                    case AcknowledgeAchievementCommand value:
                        return AcknowledgeAchievement(current, value, commandId);
                    case MarkAnalyticsReceiptCommand value:
                        return MarkAnalyticsReceipt(current, value, commandId);
                    case SetNextRunIntentCommand value:
                        return SetNextRunIntent(current, value, commandId);
                    case SetReturnPlanCommand value:
                        return SetReturnPlan(current, value, commandId);
                    case PrepareReturnPlanCommand value:
                        return PrepareReturnPlan(current, value, commandId);
                    case CompleteReturnPlanInteractionCommand value:
                        return CompleteReturnPlanInteraction(current, value, commandId);
                    case DismissReturnPlanCommand value:
                        return DismissReturnPlan(current, value, commandId);
                    case ArchiveHighSchoolLifeCommand value:
                        return ArchiveHighSchoolLife(current, value, commandId);
                    case FinalizeHighSchoolLegacyCommand value:
                        return FinalizeHighSchoolLegacy(current, value, commandId);
                    case RetireProCareerCommand value:
                        return RetirePro(current, value, commandId);
                    case BeginRebirthCommand value:
                        return BeginRebirth(current, value, commandId);
                    case DeleteSaveCommand _:
                        return DeleteSave(current, commandId);
                    default:
                        return Failure("command.unknown");
                }
            }
            catch (Exception)
            {
                return Failure("command.port_failure");
            }
        }

        private static TransitionResult<GameSaveAggregate> EnterSetup(
            GameSaveAggregate current,
            string commandId)
        {
            if (current.Stage != ApplicationStage.Opening &&
                current.Stage != ApplicationStage.BetweenLives)
            {
                return Failure("flow.setup_not_available");
            }
            return Success(current.Commit(commandId, stage: ApplicationStage.Setup));
        }

        private static TransitionResult<GameSaveAggregate> UpdateSettings(
            GameSaveAggregate current,
            UpdateGameSettingsCommand command,
            string commandId)
        {
            if (!command.HasChanges) return Failure("settings.no_changes");
            var settings = current.Settings.With(
                command.AutoReleaseEnabled,
                command.SoundEnabled,
                command.MusicEnabled,
                command.HapticsEnabled,
                command.NotificationsEnabled,
                command.HighContrastEnabled,
                command.ReducedMotionEnabled);
            return Success(current.Commit(commandId, settings: settings));
        }

        private TransitionResult<GameSaveAggregate> StartHighSchool(
            GameSaveAggregate current,
            StartHighSchoolCareerCommand command,
            string commandId)
        {
            if (current.Stage != ApplicationStage.Setup || current.HighSchool != null || current.Pro != null)
                return Failure("high_school.start_not_available");
            if (string.IsNullOrWhiteSpace(command.Request.Seed) ||
                string.IsNullOrWhiteSpace(command.Request.PresetId) ||
                string.IsNullOrWhiteSpace(command.Request.PlayerName) ||
                command.Request.LifeNumber != current.Meta.LifeNumber)
            {
                return Failure("high_school.start_invalid");
            }

            var setupError = HighSchoolSetupCatalog.Validate(
                command.Request,
                current.Meta.SoulBalance,
                current.Meta.AutomaticSoulEarned,
                current.Meta.InheritedMemories,
                current.Meta.UnlockedSignatureLegacyIds,
                HighSchoolSetupCatalog.IsRebirth(current.Meta));
            if (setupError != null) return Failure(setupError);

            var started = _highSchool.Start(command.Request);
            if (!ValidStartedHighSchool(
                    started,
                    command.Request.ChallengeLifeNumber ?? current.Meta.LifeNumber) ||
                started.IsChallengeRun != command.Request.IsChallenge)
                return Failure("high_school.port_invalid");
            var meta = current.Meta;
            if (!command.Request.IsChallenge)
            {
                var achievements = AchievementRules.Unlock(
                    meta.Achievements,
                    AchievementRules.FromLifeNumber(started.LifeNumber));
                var lastSetup = new HighSchoolLastSetupState(
                    command.Request.PresetId,
                    command.Request.PlayerName,
                    command.Request.Region,
                    command.Request.Difficulty,
                    command.Request.Karmas,
                    command.Request.InheritedSoulDomain);
                meta = meta.With(
                    soulBalance: meta.SoulBalance -
                        HighSchoolSetupCatalog.SoulBoostCost(command.Request.SoulBoosts),
                    achievements: achievements,
                    lastHighSchoolSetup: lastSetup,
                    equippedSignatureLegacyId: command.Request.SignatureLegacyId,
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

        private TransitionResult<GameSaveAggregate> EnterProFromDraft(
            GameSaveAggregate current,
            string commandId)
        {
            var highSchool = current.HighSchool;
            if (highSchool?.Draft?.Resolved != true || !highSchool.Draft.Drafted || current.Pro != null)
                return Failure("pro.draft_entry_not_available");
            if (highSchool.IsChallengeRun) return Failure("pro.challenge_run_not_recorded");
            var pro = _pro.StartFromDraft(highSchool);
            if (!ValidStartedPro(pro, ProCareerOrigin.HighSchool) ||
                !string.Equals(pro.SourceHighSchoolCareerId, highSchool.CareerId, StringComparison.Ordinal) ||
                !string.Equals(pro.PlayerId, highSchool.PlayerId, StringComparison.Ordinal))
            {
                return Failure("pro.port_invalid");
            }
            return Success(current.Commit(commandId, stage: ApplicationStage.Pro, pro: pro));
        }

        private TransitionResult<GameSaveAggregate> DeclineProCareer(
            GameSaveAggregate current,
            string commandId)
        {
            var before = current.HighSchool;
            if (before?.Draft?.Resolved != true || !before.Draft.Drafted ||
                before.Phase != HighSchoolPhase.Completed || before.IsChallengeRun ||
                current.Pro != null || current.PitchResume != null ||
                current.PendingPitchCompletion != null)
            {
                return Failure("pro.decline_not_available");
            }
            var opened = _highSchool.Apply(before, new HighSchoolAction("open_legacy"));
            if (!ValidHighSchoolAdvance(before, opened) ||
                opened.Phase != HighSchoolPhase.Legacy)
            {
                return Failure("pro.decline_port_invalid");
            }
            return Success(current.Commit(
                commandId,
                stage: ApplicationStage.Legacy,
                highSchool: opened));
        }

        private TransitionResult<GameSaveAggregate> StartDirectPro(
            GameSaveAggregate current,
            StartDirectProCommand command,
            string commandId)
        {
            if (current.Pro != null || current.PitchResume != null ||
                current.PendingPitchCompletion != null)
            {
                return Failure("pro.direct_start_not_available");
            }
            if (current.Meta.LifeArchive.Count == 0)
                return Failure("pro.direct_start_locked");
            var pro = _pro.StartDirect(command.Request);
            if (!ValidStartedPro(pro, ProCareerOrigin.Direct) || pro.SourceHighSchoolCareerId != null)
                return Failure("pro.port_invalid");
            return Success(current.Commit(commandId, stage: ApplicationStage.Pro, pro: pro));
        }

        private TransitionResult<GameSaveAggregate> SignProContract(
            GameSaveAggregate current,
            string commandId)
        {
            var before = current.Pro;
            if (before == null || before.Phase != ProCareerPhase.ContractOffer ||
                before.ContractOffer == null || current.PitchResume != null)
            {
                return Failure("pro.contract_not_available");
            }
            var signed = _pro.Apply(before, new ProCareerAction("sign_contract"));
            if (!ValidProAdvance(before, signed) || signed.Phase != ProCareerPhase.WeeklyPlan ||
                signed.ContractOffer != null)
            {
                return Failure("pro.contract_invalid");
            }
            return Success(current.Commit(commandId, stage: ApplicationStage.Pro, pro: signed));
        }

        private TransitionResult<GameSaveAggregate> AdvancePro(
            GameSaveAggregate current,
            AdvanceProCommand command,
            string commandId)
        {
            if (current.Pro == null || current.PitchResume != null)
                return Failure("pro.not_active");
            if (string.IsNullOrWhiteSpace(command.Action.Kind) ||
                string.Equals(command.Action.Kind, "record_important_game", StringComparison.Ordinal))
            {
                return Failure("pro.action_invalid");
            }
            if (!ValidProChoice(current.Pro, command.Action))
                return Failure("pro.choice_invalid");
            var before = current.Pro;
            var updated = _pro.Apply(before, command.Action);
            if (!ValidProAdvance(before, updated)) return Failure("pro.port_invalid");
            var weekly = current.Meta.Weekly;
            var recordsAdvancedWeeks =
                string.Equals(command.Action.Kind, "advance_week", StringComparison.Ordinal) ||
                string.Equals(command.Action.Kind, "plan_week", StringComparison.Ordinal) ||
                string.Equals(command.Action.Kind, "advance_segment", StringComparison.Ordinal) ||
                string.Equals(command.Action.Kind, "plan_segment", StringComparison.Ordinal) ||
                string.Equals(command.Action.Kind, "plan_block", StringComparison.Ordinal);
            var weeksAdvanced = recordsAdvancedWeeks && updated.Season == before.Season
                ? Math.Max(0, updated.Week - before.Week)
                : 0;
            if (weeksAdvanced > 0)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.ProWeeksAdvanced,
                    weeksAdvanced,
                    commandId + ":pro-weeks",
                    command.OccurredAt);
            }
            var achievements = AchievementRules.Unlock(
                current.Meta.Achievements,
                AchievementRules.FromPro(updated));
            var meta = current.Meta.With(weekly: weekly, achievements: achievements);
            return Success(current.Commit(
                commandId,
                stage: StageFor(updated),
                pro: updated,
                meta: meta));
        }

        private TransitionResult<GameSaveAggregate> BeginPitch(
            GameSaveAggregate current,
            BeginPitchSessionCommand command,
            string commandId)
        {
            if (current.PitchResume != null || current.PendingPitchCompletion != null)
                return Failure("pitch.already_pending");
            if (string.IsNullOrWhiteSpace(command.GameId) ||
                string.IsNullOrWhiteSpace(command.ScenarioId) ||
                command.MaximumBatters < 1 || command.MaximumBatters > 18)
            {
                return Failure("pitch.begin_invalid");
            }

            string careerId;
            string sessionSeed;
            PitchScenarioReadModel scenario;
            HighSchoolCareerReadModel highSchool = null;
            ProCareerReadModel pro = null;
            var meta = current.Meta;
            switch (command.CareerKind)
            {
                case PitchCareerKind.Tutorial:
                    if (current.HighSchool?.Phase != HighSchoolPhase.Prologue)
                        return Failure("pitch.tutorial_not_ready");
                    careerId = current.HighSchool.CareerId;
                    scenario = _highSchool is IHighSchoolTutorialScenarioPort tutorialScenarios
                        ? tutorialScenarios.CreateTutorialPitchScenario(
                            current.HighSchool,
                            command.ScenarioId)
                        : PitchScenarioFactory.TutorialFallback(
                            current.HighSchool.CareerId,
                            current.HighSchool.Ratings,
                            current.HighSchool.PlayerName);
                    if (current.HighSchool.TutorialAttemptCount == int.MaxValue)
                        return Failure("pitch.tutorial_attempts_exhausted");
                    var tutorialAttempt = current.HighSchool.TutorialAttemptCount + 1;
                    sessionSeed = tutorialAttempt == 1
                        ? current.HighSchool.NextSeed
                        : DeterministicSeed.Normalize(
                            current.HighSchool.NextSeed + "|tutorial-attempt|" + tutorialAttempt);
                    highSchool = CopyTutorialState(
                        current.HighSchool,
                        current.HighSchool.TutorialCompleted,
                        tutorialAttempt);
                    if (!ValidTutorialReservation(current.HighSchool, highSchool))
                    {
                        return Failure("pitch.tutorial_reservation_invalid");
                    }
                    break;
                case PitchCareerKind.HighSchool:
                    if (current.HighSchool?.Phase != HighSchoolPhase.ImportantGame)
                        return Failure("pitch.high_school_not_ready");
                    careerId = current.HighSchool.CareerId;
                    scenario = _highSchool is IHighSchoolPitchScenarioPort highSchoolScenarios
                        ? highSchoolScenarios.CreatePitchScenario(current.HighSchool, command.ScenarioId)
                        : PitchScenarioFactory.Fallback(
                            command.ScenarioId,
                            current.HighSchool.Ratings,
                            current.HighSchool.PlayerName,
                            command.MaximumBatters);
                    sessionSeed = current.HighSchool.NextSeed;
                    highSchool = _highSchool.ReservePitch(current.HighSchool, command.ScenarioId);
                    if (!ValidHighSchoolReservation(current.HighSchool, highSchool) ||
                        string.Equals(sessionSeed, highSchool.NextSeed, StringComparison.Ordinal))
                    {
                        return Failure("pitch.seed_not_consumed");
                    }
                    sessionSeed = highSchool.NextSeed;
                    break;
                case PitchCareerKind.Pro:
                    if (current.Pro?.Phase != ProCareerPhase.ImportantGame)
                        return Failure("pitch.pro_not_ready");
                    careerId = current.Pro.ProCareerId;
                    scenario = _pro is IProPitchScenarioPort proScenarios
                        ? proScenarios.CreatePitchScenario(current.Pro, command.ScenarioId)
                        : PitchScenarioFactory.Fallback(
                            command.ScenarioId,
                            current.Pro.Ratings,
                            current.Pro.PlayerName,
                            command.MaximumBatters);
                    sessionSeed = current.Pro.NextSeed;
                    pro = _pro.ReservePitch(current.Pro, command.ScenarioId);
                    if (!ValidProReservation(current.Pro, pro) ||
                        string.Equals(sessionSeed, pro.NextSeed, StringComparison.Ordinal))
                    {
                        return Failure("pitch.seed_not_consumed");
                    }
                    sessionSeed = pro.NextSeed;
                    break;
                case PitchCareerKind.Daily:
                    return Failure("daily.retired");
                default:
                    return Failure("pitch.kind_invalid");
            }

            if (string.IsNullOrWhiteSpace(sessionSeed)) return Failure("pitch.seed_missing");
            if (scenario == null || scenario.MaximumBatters < 1 || scenario.MaximumBatters > 18 ||
                scenario.Lineup.Count < scenario.MaximumBatters)
            {
                return Failure("pitch.scenario_invalid");
            }
            var resume = new PitchResumeState(
                command.GameId,
                command.CareerKind,
                careerId,
                scenario.ScenarioId,
                sessionSeed,
                scenario.MaximumBatters,
                scenario: scenario);
            return Success(current.Commit(
                commandId,
                highSchool: highSchool,
                pro: pro,
                meta: meta,
                pitchResume: resume));
        }

        private static TransitionResult<GameSaveAggregate> CheckpointPitch(
            GameSaveAggregate current,
            CheckpointPitchSessionCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            if (resume == null || !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal))
                return Failure("pitch.session_mismatch");
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (resume.CommittedPitch != null) return Failure("pitch.committed_result_pending");
            if (resume.AwaitingCompletion) return Failure("pitch.completion_required");
            if (command.CompletedBatters < resume.CompletedBatters ||
                command.CompletedBatters > resume.MaximumBatters ||
                string.IsNullOrWhiteSpace(command.CheckpointJson))
            {
                return Failure("pitch.checkpoint_invalid");
            }
            if (!ValidAccumulatedReport(
                    resume,
                    command.CompletedBatters,
                    command.AccumulatedReport,
                    resume.Metrics))
                return Failure("pitch.accumulated_report_invalid");
            var updated = new PitchResumeState(
                resume.GameId,
                resume.CareerKind,
                resume.CareerId,
                resume.ScenarioId,
                resume.SessionSeed,
                resume.MaximumBatters,
                command.CompletedBatters,
                command.CheckpointJson,
                resume.Scenario,
                command.AccumulatedReport ?? resume.AccumulatedReport,
                consumedPitchIds: resume.ConsumedPitchIds,
                awaitingCompletion: resume.AwaitingCompletion,
                metrics: resume.Metrics);
            return Success(current.Commit(commandId, pitchResume: updated));
        }

        private static TransitionResult<GameSaveAggregate> CommitPitchResult(
            GameSaveAggregate current,
            CommitPitchResultCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            if (resume == null || !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal))
                return Failure("pitch.session_mismatch");
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (resume.CommittedPitch != null) return Failure("pitch.committed_result_pending");
            if (resume.AwaitingCompletion) return Failure("pitch.completion_required");
            string abilityMomentType;
            if (!TryAbilityMomentType(
                    resume.Scenario?.Pitcher,
                    command.AbilityMomentEvidence,
                    command.SequencePitch,
                    command.SequenceContext,
                    out abilityMomentType))
            {
                return Failure("pitch.committed_result_invalid");
            }
            if (command.BatterIndex != resume.CompletedBatters ||
                resume.ConsumedPitchIds.Contains(command.PitchId, StringComparer.Ordinal) ||
                resume.Scenario?.MaximumPitches is int maximumPitches &&
                    resume.ConsumedPitchIds.Count >= maximumPitches ||
                string.IsNullOrWhiteSpace(command.PitchId) ||
                string.IsNullOrWhiteSpace(command.EventHash) ||
                string.IsNullOrWhiteSpace(command.KernelResultJson) ||
                string.IsNullOrWhiteSpace(command.PresentationJson) ||
                !ValidCommittedMetrics(
                    resume.Metrics,
                    command.SequencePitch,
                    command.SequenceTag,
                    command.Delivery,
                    command.SequenceContext,
                    command.SequenceRivalMemory))
            {
                return Failure("pitch.committed_result_invalid");
            }

            var committed = new CommittedPitchResultState(
                command.PitchId,
                command.BatterIndex,
                command.EventHash,
                command.KernelResultJson,
                command.PresentationJson,
                command.CommittedAt.ToUnixTimeMilliseconds(),
                command.SequencePitch,
                command.SequenceTag,
                command.Delivery,
                abilityMomentType);
            var updated = new PitchResumeState(
                resume.GameId,
                resume.CareerKind,
                resume.CareerId,
                resume.ScenarioId,
                resume.SessionSeed,
                resume.MaximumBatters,
                resume.CompletedBatters,
                resume.CheckpointJson,
                resume.Scenario,
                resume.AccumulatedReport,
                committed,
                resume.ConsumedPitchIds,
                resume.AwaitingCompletion,
                resume.Metrics);
            return Success(current.Commit(commandId, pitchResume: updated));
        }

        private static TransitionResult<GameSaveAggregate> ConsumeCommittedPitchResult(
            GameSaveAggregate current,
            ConsumeCommittedPitchResultCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            var committed = resume?.CommittedPitch;
            if (resume == null || committed == null ||
                !string.Equals(resume.GameId, command.GameId, StringComparison.Ordinal) ||
                !string.Equals(committed.PitchId, command.PitchId, StringComparison.Ordinal))
            {
                return Failure("pitch.committed_result_mismatch");
            }
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (command.CompletedBatters < resume.CompletedBatters ||
                command.CompletedBatters > resume.CompletedBatters + 1 ||
                command.CompletedBatters > resume.MaximumBatters ||
                string.IsNullOrWhiteSpace(command.CheckpointJson))
            {
                return Failure("pitch.committed_result_consume_invalid");
            }

            var nextMetrics = (resume.Metrics ?? PitchSessionMetricsState.Empty).Consuming(
                committed,
                command.CompletedBatters > resume.CompletedBatters);
            if (!ValidAccumulatedReport(
                    resume,
                    command.CompletedBatters,
                    command.AccumulatedReport,
                    nextMetrics))
            {
                return Failure("pitch.committed_result_consume_invalid");
            }

            var consumedIds = resume.ConsumedPitchIds
                .Concat(new[] { committed.PitchId })
                .ToArray();
            var terminal = IsTerminalPitchSession(
                resume,
                command.CompletedBatters,
                command.AccumulatedReport,
                consumedIds.Length);
            if (command.SessionCompleted && !terminal)
                return Failure("pitch.session_not_terminal");

            var updated = new PitchResumeState(
                resume.GameId,
                resume.CareerKind,
                resume.CareerId,
                resume.ScenarioId,
                resume.SessionSeed,
                resume.MaximumBatters,
                command.CompletedBatters,
                command.CheckpointJson,
                resume.Scenario,
                command.AccumulatedReport ?? resume.AccumulatedReport,
                consumedPitchIds: consumedIds,
                awaitingCompletion: command.SessionCompleted || terminal,
                metrics: nextMetrics);
            return Success(current.Commit(commandId, pitchResume: updated));
        }

        private TransitionResult<GameSaveAggregate> RetryTutorialPitch(
            GameSaveAggregate current,
            RetryTutorialPitchCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            var highSchool = current.HighSchool;
            if (resume == null || resume.CareerKind != PitchCareerKind.Tutorial ||
                resume.CommittedPitch != null || !resume.AwaitingCompletion ||
                !string.Equals(resume.GameId, command.CurrentGameId, StringComparison.Ordinal) ||
                highSchool == null || highSchool.Phase != HighSchoolPhase.Prologue ||
                !string.Equals(highSchool.CareerId, resume.CareerId, StringComparison.Ordinal))
            {
                return Failure("pitch.tutorial_retry_not_available");
            }
            if (string.IsNullOrWhiteSpace(command.NextGameId) ||
                string.IsNullOrWhiteSpace(command.ScenarioId) ||
                string.Equals(command.NextGameId, resume.GameId, StringComparison.Ordinal) ||
                highSchool.TutorialAttemptCount == int.MaxValue)
            {
                return Failure("pitch.tutorial_retry_invalid");
            }

            var scenario = _highSchool is IHighSchoolTutorialScenarioPort tutorialScenarios
                ? tutorialScenarios.CreateTutorialPitchScenario(highSchool, command.ScenarioId)
                : PitchScenarioFactory.TutorialFallback(
                    highSchool.CareerId,
                    highSchool.Ratings,
                    highSchool.PlayerName);
            if (scenario == null || scenario.MaximumBatters != 2 ||
                scenario.MaximumPitches != 8 || scenario.Lineup.Count < 2)
            {
                return Failure("pitch.scenario_invalid");
            }
            var nextAttempt = highSchool.TutorialAttemptCount + 1;
            var sessionSeed = DeterministicSeed.Normalize(
                highSchool.NextSeed + "|tutorial-attempt|" + nextAttempt);
            var updatedHighSchool = CopyTutorialState(
                highSchool,
                highSchool.TutorialCompleted,
                nextAttempt);
            if (!ValidTutorialReservation(highSchool, updatedHighSchool))
                return Failure("pitch.tutorial_reservation_invalid");
            var updatedResume = new PitchResumeState(
                command.NextGameId,
                PitchCareerKind.Tutorial,
                highSchool.CareerId,
                scenario.ScenarioId,
                sessionSeed,
                scenario.MaximumBatters,
                scenario: scenario);
            return Success(current.Commit(
                commandId,
                highSchool: updatedHighSchool,
                pitchResume: updatedResume));
        }

        private TransitionResult<GameSaveAggregate> CompletePitch(
            GameSaveAggregate current,
            CompletePitchSessionCommand command,
            string commandId)
        {
            var resume = current.PitchResume;
            var report = command.Report;
            if (resume == null || !string.Equals(resume.GameId, report.GameId, StringComparison.Ordinal))
                return Failure("pitch.session_mismatch");
            if (resume.CareerKind == PitchCareerKind.Daily) return Failure("daily.retired");
            if (resume.CommittedPitch != null) return Failure("pitch.committed_result_pending");
            if (resume.ConsumedPitchIds.Count == 0)
                return Failure("pitch.authoritative_pitch_required");
            if (!resume.AwaitingCompletion)
                return Failure("pitch.session_not_terminal");
            if (report.Pitches <= 0 || report.Batters < 0 || report.Batters > resume.MaximumBatters ||
                report.Outs < 0 || report.Strikeouts < 0 || report.Walks < 0 ||
                report.Hits < 0 || report.RunsAllowed < 0 || report.ExpectedDamage < 0 ||
                report.HomeRuns.HasValue && report.HomeRuns.Value < 0 ||
                report.RivalStrikeouts < 0 || report.RivalStrikeouts > report.Strikeouts ||
                report.ActualDamage < 0 || report.RecommendationAccepted < 0 ||
                report.RecommendationAccepted > report.Pitches ||
                !ValidReportMetrics(report))
            {
                return Failure("pitch.report_invalid");
            }
            if (report.Batters < resume.CompletedBatters)
                return Failure("pitch.report_before_checkpoint");
            if (report.Batters != resume.CompletedBatters ||
                resume.AccumulatedReport == null ||
                !SamePitchReport(report, resume.AccumulatedReport))
            {
                return Failure("pitch.report_checkpoint_mismatch");
            }
            var highSchool = current.HighSchool;
            var pro = current.Pro;
            ApplicationStage stage;
            switch (resume.CareerKind)
            {
                case PitchCareerKind.Tutorial:
                    if (highSchool == null || highSchool.Phase != HighSchoolPhase.Prologue ||
                        !string.Equals(highSchool.CareerId, resume.CareerId, StringComparison.Ordinal))
                    {
                        return Failure("pitch.career_mismatch");
                    }
                    var tutorialBefore = highSchool;
                    var schoolSelection = _highSchool.Apply(
                        highSchool,
                        new HighSchoolAction("complete_prologue"));
                    if (!ValidHighSchoolAdvance(tutorialBefore, schoolSelection) ||
                        schoolSelection.Phase != HighSchoolPhase.SchoolSelection ||
                        !SamePerformance(tutorialBefore.Performance, schoolSelection.Performance))
                    {
                        return Failure("pitch.tutorial_completion_invalid");
                    }
                    highSchool = CopyTutorialState(
                        schoolSelection,
                        completed: true,
                        attemptCount: tutorialBefore.TutorialAttemptCount);
                    stage = StageFor(highSchool);
                    break;
                case PitchCareerKind.HighSchool:
                    if (highSchool == null ||
                        !string.Equals(highSchool.CareerId, resume.CareerId, StringComparison.Ordinal))
                        return Failure("pitch.career_mismatch");
                    var highSchoolBefore = highSchool;
                    highSchool = _highSchool.ApplyPitchResult(highSchool, report);
                    if (!ValidHighSchoolAdvance(highSchoolBefore, highSchool))
                        return Failure("high_school.port_invalid");
                    stage = StageFor(highSchool);
                    break;
                case PitchCareerKind.Pro:
                    if (pro == null || !string.Equals(pro.ProCareerId, resume.CareerId, StringComparison.Ordinal))
                        return Failure("pitch.career_mismatch");
                    var proBefore = pro;
                    pro = _pro.ApplyPitchResult(pro, report);
                    if (!ValidProAdvance(proBefore, pro)) return Failure("pro.port_invalid");
                    stage = StageFor(pro);
                    break;
                case PitchCareerKind.Daily:
                    return Failure("daily.retired");
                default:
                    return Failure("pitch.kind_invalid");
            }

            var meta = resume.CareerKind == PitchCareerKind.Tutorial ||
                       resume.CareerKind == PitchCareerKind.HighSchool && highSchool?.IsChallengeRun == true
                ? current.Meta
                : ApplyPitchMeta(current.Meta, resume.CareerKind, report, command.CompletedAt, commandId);
            var pending = new PendingPitchCompletion(
                "pitch-result:" + report.GameId,
                resume.CareerKind,
                resume.CareerId,
                report,
                command.CompletedAt.ToUnixTimeSeconds());
            return Success(current.Commit(
                commandId,
                stage: stage,
                highSchool: highSchool,
                pro: pro,
                meta: meta,
                clearPitchResume: true,
                pendingPitchCompletion: pending));
        }

        private static TransitionResult<GameSaveAggregate> AcknowledgePitch(
            GameSaveAggregate current,
            AcknowledgePitchResultCommand command,
            string commandId)
        {
            if (current.PendingPitchCompletion == null ||
                !string.Equals(
                    current.PendingPitchCompletion.CompletionId,
                    command.CompletionId,
                    StringComparison.Ordinal))
            {
                return Failure("pitch.completion_mismatch");
            }
            return Success(current.Commit(commandId, clearPendingPitchCompletion: true));
        }

        private static TransitionResult<GameSaveAggregate> AbandonPitch(
            GameSaveAggregate current,
            AbandonPitchSessionCommand command,
            string commandId)
        {
            if (current.PitchResume == null ||
                !string.Equals(current.PitchResume.GameId, command.GameId, StringComparison.Ordinal))
            {
                return Failure("pitch.session_mismatch");
            }
            if (current.PitchResume.CareerKind == PitchCareerKind.Daily)
                return Success(current.Commit(commandId, clearPitchResume: true));
            if (current.PitchResume.CommittedPitch != null)
                return Failure("pitch.committed_result_pending");
            if (current.PitchResume.AwaitingCompletion)
                return Failure("pitch.completion_required");
            if (current.PitchResume.CareerKind == PitchCareerKind.Tutorial)
                return Failure("pitch.tutorial_cannot_abandon");
            return Success(current.Commit(commandId, clearPitchResume: true));
        }

        private static bool ValidAccumulatedReport(
            PitchResumeState resume,
            int completedBatters,
            PitchGameReport report,
            PitchSessionMetricsState expectedMetrics = null)
        {
            // Legacy callers may checkpoint only the opaque kernel state. New production callers
            // also persist the typed cumulative report, which is validated when supplied.
            if (report == null) return true;
            var prior = resume.AccumulatedReport;
            return string.Equals(report.GameId, resume.GameId, StringComparison.Ordinal) &&
                report.Batters == completedBatters && report.Pitches > 0 &&
                report.Outs >= 0 && report.Strikeouts >= 0 && report.Walks >= 0 &&
                report.Hits >= 0 && report.RunsAllowed >= 0 &&
                (!report.HomeRuns.HasValue || report.HomeRuns.Value >= 0) &&
                (prior == null ||
                 report.Pitches >= prior.Pitches && report.Batters >= prior.Batters &&
                 report.Outs >= prior.Outs && report.Strikeouts >= prior.Strikeouts &&
                 report.Walks >= prior.Walks && report.Hits >= prior.Hits &&
                (!prior.HomeRuns.HasValue ||
                 report.HomeRuns.HasValue && report.HomeRuns.Value >= prior.HomeRuns.Value) &&
                report.RunsAllowed >= prior.RunsAllowed &&
                report.RivalStrikeouts >= prior.RivalStrikeouts &&
                report.SequenceMasteryCount >= prior.SequenceMasteryCount &&
                report.ExpectedDamage >= prior.ExpectedDamage &&
                report.ActualDamage >= prior.ActualDamage &&
                 report.RecommendationAccepted >= prior.RecommendationAccepted) &&
                (expectedMetrics == null || ReportMatchesMetrics(report, expectedMetrics));
        }

        private static bool SamePitchReport(PitchGameReport left, PitchGameReport right)
        {
            return left != null && right != null &&
                string.Equals(left.GameId, right.GameId, StringComparison.Ordinal) &&
                left.Pitches == right.Pitches && left.Batters == right.Batters &&
                left.Outs == right.Outs && left.Strikeouts == right.Strikeouts &&
                left.Walks == right.Walks && left.Hits == right.Hits &&
                left.HomeRuns == right.HomeRuns &&
                left.RunsAllowed == right.RunsAllowed &&
                left.SequenceMasteryCount == right.SequenceMasteryCount &&
                left.ExpectedDamage == right.ExpectedDamage &&
                left.ActualDamage == right.ActualDamage &&
                left.RecommendationAccepted == right.RecommendationAccepted &&
                left.DirectDeliveryCount == right.DirectDeliveryCount &&
                left.DeliveryScoreTotal == right.DeliveryScoreTotal &&
                left.BestDeliveryScore == right.BestDeliveryScore &&
                left.PerfectDeliveryCount == right.PerfectDeliveryCount &&
                left.RivalStrikeouts == right.RivalStrikeouts &&
                left.AbilityMomentCount == right.AbilityMomentCount &&
                left.AbilityMomentTypes.SequenceEqual(
                    right.AbilityMomentTypes,
                    StringComparer.Ordinal);
        }

        private static bool SamePerformance(
            CareerPerformanceReadModel left,
            CareerPerformanceReadModel right)
        {
            return left != null && right != null &&
                left.ImportantGames == right.ImportantGames &&
                left.Pitches == right.Pitches && left.Outs == right.Outs &&
                left.Strikeouts == right.Strikeouts && left.Walks == right.Walks &&
                left.Hits == right.Hits && left.RunsAllowed == right.RunsAllowed;
        }

        private static bool SameRatings(
            PitcherRatingsReadModel left,
            PitcherRatingsReadModel right)
        {
            return left != null && right != null &&
                left.Stuff == right.Stuff && left.Command == right.Command &&
                left.Movement == right.Movement && left.Stamina == right.Stamina;
        }

        private static bool ValidCommittedMetrics(
            PitchSessionMetricsState currentMetrics,
            Baseball.Core.Pitching.PitchSequencePitch sequencePitch,
            Baseball.Core.Pitching.PitchSequenceTag? sequenceTag,
            PitchDeliveryMetricState delivery,
            Baseball.Core.Pitching.PlateAppearanceContext sequenceContext,
            Baseball.Core.Pitching.RivalMemorySnapshot sequenceRivalMemory)
        {
            if (sequenceTag.HasValue && sequencePitch == null) return false;
            if (sequenceTag.HasValue && !Enum.IsDefined(
                    typeof(Baseball.Core.Pitching.PitchSequenceTag), sequenceTag.Value)) return false;
            if (sequencePitch != null &&
                (sequencePitch.ExpectedVelocityKph <= 0 ||
                 sequencePitch.Zone.Row < 0 || sequencePitch.Zone.Row > 2 ||
                 sequencePitch.Zone.Column < 0 || sequencePitch.Zone.Column > 2)) return false;
            if (sequencePitch != null)
            {
                if (sequenceContext == null) return false;
                var evaluated = Baseball.Core.Pitching.PitchSequenceEvaluator.Evaluate(
                    currentMetrics?.RecentSequencePitches ??
                        Array.Empty<Baseball.Core.Pitching.PitchSequencePitch>(),
                    sequenceContext,
                    sequencePitch,
                    sequenceRivalMemory);
                if (evaluated?.Tag != sequenceTag) return false;
            }
            else if (sequenceContext != null || sequenceRivalMemory != null)
            {
                return false;
            }
            return delivery == null ||
                delivery.ReleaseAccuracy >= 0 && delivery.ReleaseAccuracy <= 1000 &&
                delivery.AimAccuracy >= 0 && delivery.AimAccuracy <= 1000;
        }

        private static bool TryAbilityMomentType(
            Baseball.Core.Domain.PitcherSnapshot pitcher,
            PitchAbilityMomentEvidence evidence,
            Baseball.Core.Pitching.PitchSequencePitch sequencePitch,
            Baseball.Core.Pitching.PlateAppearanceContext sequenceContext,
            out string abilityMomentType)
        {
            abilityMomentType = null;
            if (pitcher == null || evidence == null || evidence.Call == null || evidence.PreResultContext == null ||
                evidence.Execution == null || sequencePitch == null || sequenceContext == null ||
                !Enum.IsDefined(typeof(Baseball.Core.Domain.PitchOutcome), evidence.Outcome) ||
                evidence.Execution.ExecutionQuality < 0 || evidence.Execution.ExecutionQuality > 1000 ||
                evidence.Call.PitchType != sequencePitch.PitchType ||
                evidence.Call.Zone != sequencePitch.Zone ||
                evidence.Call.ZoneIntent != sequencePitch.Intent ||
                evidence.Outcome != sequencePitch.Outcome ||
                !SameContext(evidence.PreResultContext, sequenceContext))
            {
                return false;
            }
            try
            {
                var readout = Baseball.Core.Pitching.PitchAbilityRules.Readout(
                    pitcher,
                    evidence.Call,
                    evidence.PreResultContext);
                var moment = Baseball.Core.Pitching.PitchAbilityRules.Moment(
                    evidence.Outcome,
                    evidence.Execution,
                    readout);
                abilityMomentType = moment.HasValue
                    ? Baseball.Core.Pitching.PitchAbilityWire.Value(moment.Value)
                    : null;
                return true;
            }
            catch (ArgumentException)
            {
                return false;
            }
            catch (InvalidOperationException)
            {
                return false;
            }
        }

        private static bool SameContext(
            Baseball.Core.Pitching.PlateAppearanceContext left,
            Baseball.Core.Pitching.PlateAppearanceContext right)
        {
            return left != null && right != null &&
                string.Equals(left.PlateAppearanceId, right.PlateAppearanceId, StringComparison.Ordinal) &&
                left.Revision == right.Revision && left.Inning == right.Inning &&
                left.Outs == right.Outs && left.Balls == right.Balls &&
                left.Strikes == right.Strikes && left.PitchNumber == right.PitchNumber &&
                left.ScoreDifferential == right.ScoreDifferential &&
                left.Leverage == right.Leverage && left.Fatigue == right.Fatigue;
        }

        private static bool ValidReportMetrics(PitchGameReport report)
        {
            return (!report.HomeRuns.HasValue ||
                    report.HomeRuns.Value >= 0 && report.HomeRuns.Value <= report.Hits) &&
                report.DirectDeliveryCount >= 0 && report.PerfectDeliveryCount >= 0 &&
                report.RivalStrikeouts >= 0 && report.RivalStrikeouts <= report.Strikeouts &&
                report.AbilityMomentCount >= 0 && report.AbilityMomentCount <= report.Pitches &&
                report.AbilityMomentTypes.Count <= report.AbilityMomentCount &&
                report.AbilityMomentTypes.All(Baseball.Core.Pitching.PitchAbilityWire.IsValid) &&
                report.PerfectDeliveryCount <= report.DirectDeliveryCount &&
                report.DeliveryScoreTotal >= 0 &&
                report.DeliveryScoreTotal <= report.DirectDeliveryCount * 1000 &&
                report.BestDeliveryScore >= 0 && report.BestDeliveryScore <= 1000 &&
                (report.DirectDeliveryCount != 0 ||
                 report.DeliveryScoreTotal == 0 && report.BestDeliveryScore == 0 &&
                 report.PerfectDeliveryCount == 0);
        }

        private static bool ReportMatchesMetrics(
            PitchGameReport report,
            PitchSessionMetricsState metrics)
        {
            return report.SequenceMasteryCount == metrics.SequenceMasteryCount &&
                report.DirectDeliveryCount == metrics.DirectDeliveryCount &&
                report.DeliveryScoreTotal == metrics.DeliveryScoreTotal &&
                report.BestDeliveryScore == metrics.BestDeliveryScore &&
                report.PerfectDeliveryCount == metrics.PerfectDeliveryCount &&
                report.AbilityMomentCount == metrics.AbilityMomentCount &&
                report.AbilityMomentTypes.SequenceEqual(
                    metrics.AbilityMomentTypes,
                    StringComparer.Ordinal);
        }

        private static bool IsTerminalPitchSession(
            PitchResumeState resume,
            int completedBatters,
            PitchGameReport report,
            int consumedPitchCount)
        {
            if (completedBatters >= resume.MaximumBatters) return true;
            if (resume.Scenario?.MaximumPitches is int maximumPitches &&
                consumedPitchCount >= maximumPitches) return true;
            if (report == null) return false;
            var initialOuts = resume.Scenario?.GameState?.InningState?.Outs ?? 0;
            return initialOuts + report.Outs >= 3;
        }

        private static bool ValidHighSchoolChoice(
            HighSchoolCareerReadModel current,
            HighSchoolAction action)
        {
            switch (action.Kind)
            {
                case "choose_school":
                    return ChoiceMatchesWhenPresent(current.SchoolChoices, action.Value);
                case "train":
                case "train_block":
                    var training = (action.Value ?? string.Empty).Split(':');
                    if (training.Length != 2 && training.Length != 3) return false;
                    var breakingBall = string.Equals(training[0], "breaking_ball", StringComparison.Ordinal);
                    var targetValid = training.Length == 3
                        ? breakingBall && ChoiceMatchesWhenPresent(current.TrainingPitchChoices, training[2])
                        : !breakingBall || current.TrainingPitchChoices.Count == 0;
                    return targetValid &&
                        ChoiceMatchesWhenPresent(current.TrainingFocusChoices, training[0]) &&
                        ChoiceMatchesWhenPresent(current.TrainingIntensityChoices, training[1]);
                case "relationship":
                    return ChoiceMatchesWhenPresent(current.RelationshipChoices, action.Value);
                case "awakening":
                    return ChoiceMatchesWhenPresent(current.AwakeningChoices, action.Value);
                case "select_signature_legacy":
                    return current.LegacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                        ChoiceMatchesWhenPresent(current.SignatureLegacyChoices, action.Value);
                case "select_legacy":
                    if (current.LegacySelectionMode != LegacySelectionMode.Memories) return false;
                    if (current.LegacyMemoryChoices.Count == 0) return true;
                    var selected = (action.Value ?? string.Empty)
                        .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                    return selected.Length == current.MemorySlots &&
                        selected.Distinct(StringComparer.Ordinal).Count() == selected.Length &&
                        selected.All(value => ChoiceMatches(current.LegacyMemoryChoices, value));
                default:
                    return true;
            }
        }

        private static bool ValidProChoice(ProCareerReadModel current, ProCareerAction action)
        {
            if (current.Phase == ProCareerPhase.ContractOffer) return false;
            if (current.WeekPlanChoices.Count == 0 && current.SeasonDecision == null &&
                current.OffseasonChoices.Count == 0)
            {
                return true;
            }
            switch (current.Phase)
            {
                case ProCareerPhase.WeeklyPlan:
                    return (string.Equals(action.Kind, "advance_week", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "plan_week", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "advance_segment", StringComparison.Ordinal)) &&
                        ValidProWeekPayload(current, action.Value);
                case ProCareerPhase.SeasonDecision:
                    return (string.Equals(action.Kind, "season_decision", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "resolve_season_decision", StringComparison.Ordinal)) &&
                        current.SeasonDecision != null &&
                        ChoiceMatches(current.SeasonDecision.Choices, action.Value);
                case ProCareerPhase.SeasonReview:
                    return string.Equals(action.Kind, "review_season", StringComparison.Ordinal);
                case ProCareerPhase.Offseason:
                case ProCareerPhase.RetirementDecision:
                    if (string.Equals(action.Kind, "retire", StringComparison.Ordinal)) return true;
                    return (string.Equals(action.Kind, "offseason", StringComparison.Ordinal) ||
                            string.Equals(action.Kind, "continue_career", StringComparison.Ordinal)) &&
                        ChoiceMatchesWhenPresent(current.OffseasonChoices, action.Value);
                default:
                    return false;
            }
        }

        private static bool ValidProWeekPayload(ProCareerReadModel current, string payload)
        {
            var parts = (payload ?? string.Empty)
                .Split(new[] { '|' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 1 || parts.Length > 2 ||
                !ChoiceMatchesWhenPresent(current.WeekPlanChoices, parts[0]))
            {
                return false;
            }
            var movement = string.Equals(parts[0], "develop_movement", StringComparison.Ordinal);
            if (parts.Length == 2)
                return movement && ChoiceMatchesWhenPresent(current.DevelopmentPitchChoices, parts[1]);
            return !movement || current.DevelopmentPitchChoices.Count == 0;
        }

        private static bool ChoiceMatchesWhenPresent(
            IReadOnlyList<CareerChoiceReadModel> choices,
            string payload)
        {
            return choices == null || choices.Count == 0 || ChoiceMatches(choices, payload);
        }

        private static bool ChoiceMatches(
            IReadOnlyList<CareerChoiceReadModel> choices,
            string payload)
        {
            return !string.IsNullOrWhiteSpace(payload) && choices.Any(value =>
                value.Enabled && (string.Equals(value.Id, payload, StringComparison.Ordinal) ||
                                  string.Equals(value.Payload, payload, StringComparison.Ordinal)));
        }

        private static TransitionResult<GameSaveAggregate> ConfigureWeekly(
            GameSaveAggregate current,
            ConfigureWeeklyProgramCommand command,
            string commandId)
        {
            var weekly = WeeklyProgramRules.Configure(
                current.Meta.Weekly,
                command.Eligibility,
                current.InstallId,
                command.ObservedAt);
            return Success(current.Commit(commandId, meta: current.Meta.With(weekly: weekly)));
        }

        private static TransitionResult<GameSaveAggregate> RecordWeekly(
            GameSaveAggregate current,
            RecordWeeklyProgressCommand command,
            string commandId)
        {
            if (!WeeklyTaskKinds.All.Contains(command.Kind, StringComparer.Ordinal) ||
                command.Amount <= 0 || string.IsNullOrWhiteSpace(command.ReceiptId))
            {
                return Failure("weekly.progress_invalid");
            }
            if (string.Equals(
                    command.Kind,
                    WeeklyTaskKinds.DailyInningCompleted,
                    StringComparison.Ordinal))
            {
                return Failure("daily.retired");
            }
            var weekly = WeeklyProgramRules.Record(
                current.Meta.Weekly,
                command.Kind,
                command.Amount,
                command.ReceiptId,
                command.OccurredAt);
            var daily = command.CountsAsBaseball
                ? DailyStreakRules.RecordBaseball(current.Meta.Daily, command.OccurredAt)
                : current.Meta.Daily;
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(weekly: weekly, daily: daily)));
        }

        private static TransitionResult<GameSaveAggregate> CompleteDaily(
            GameSaveAggregate current,
            CompleteDailyInningCommand command,
            string commandId)
        {
            return Failure("daily.retired");
        }

        private static TransitionResult<GameSaveAggregate> ClaimWeekly(
            GameSaveAggregate current,
            ClaimWeeklyRewardCommand command,
            string commandId)
        {
            var program = current.Meta.Weekly.Program;
            if (program == null || !program.RewardReady) return Failure("weekly.reward_not_ready");
            var rewardId = "weekly-" + program.WeekKey;
            var alreadyCredited = current.Meta.CreditedRewardIds.Contains(rewardId, StringComparer.Ordinal);
            var weekly = WeeklyProgramRules.Claim(current.Meta.Weekly, command.ClaimedAt);
            if (ReferenceEquals(weekly, current.Meta.Weekly)) return Failure("weekly.reward_not_ready");
            var meta = current.Meta.With(
                soulBalance: alreadyCredited
                    ? current.Meta.SoulBalance
                    : current.Meta.SoulBalance + WeeklyProgramRules.RewardSoul,
                soulLifetimeEarned: alreadyCredited
                    ? current.Meta.SoulLifetimeEarned
                    : current.Meta.SoulLifetimeEarned + WeeklyProgramRules.RewardSoul,
                automaticSoulEarned: alreadyCredited
                    ? current.Meta.AutomaticSoulEarned
                    : current.Meta.AutomaticSoulEarned + WeeklyProgramRules.RewardSoul,
                creditedRewardIds: alreadyCredited
                    ? current.Meta.CreditedRewardIds
                    : current.Meta.CreditedRewardIds.Concat(new[] { rewardId }).ToArray(),
                weekly: weekly);
            return Success(current.Commit(commandId, meta: meta));
        }

        private static TransitionResult<GameSaveAggregate> UnlockAchievements(
            GameSaveAggregate current,
            UnlockAchievementsCommand command,
            string commandId)
        {
            var achievements = AchievementRules.Unlock(
                current.Meta.Achievements,
                command.AchievementIds);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(achievements: achievements)));
        }

        private static TransitionResult<GameSaveAggregate> AcknowledgeAchievement(
            GameSaveAggregate current,
            AcknowledgeAchievementCommand command,
            string commandId)
        {
            if (string.IsNullOrWhiteSpace(command.AchievementId))
                return Failure("achievement.id_invalid");
            var achievements = AchievementRules.Acknowledge(
                current.Meta.Achievements,
                command.AchievementId);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(achievements: achievements)));
        }

        private static TransitionResult<GameSaveAggregate> MarkAnalyticsReceipt(
            GameSaveAggregate current,
            MarkAnalyticsReceiptCommand command,
            string commandId)
        {
            if (!AnalyticsReceiptRules.IsValidScope(command.ScopeId))
                return Failure("analytics.scope_invalid");
            if (!Enum.IsDefined(typeof(AnalyticsReceiptRetention), command.Retention))
                return Failure("analytics.retention_invalid");
            if (current.AnalyticsReceipts.Contains(command.ScopeId))
                return Failure("analytics.already_marked");
            if (command.Retention == AnalyticsReceiptRetention.Lifetime &&
                current.AnalyticsReceipts.Records.Count(value =>
                    value.Retention == AnalyticsReceiptRetention.Lifetime) >=
                AnalyticsReceiptState.MaximumLifetimeReceipts)
            {
                return Failure("analytics.lifetime_capacity");
            }
            var receipts = AnalyticsReceiptRules.Mark(
                current.AnalyticsReceipts,
                command.ScopeId,
                command.RecordedAt,
                command.Retention);
            return Success(current.Commit(
                commandId,
                analyticsReceipts: receipts));
        }

        private static TransitionResult<GameSaveAggregate> SetNextRunIntent(
            GameSaveAggregate current,
            SetNextRunIntentCommand command,
            string commandId)
        {
            if (string.IsNullOrWhiteSpace(command.Intent.PledgeId) ||
                !RunPledgeRules.IsKnownCurrentId(command.Intent.PledgeId) ||
                command.Intent.SourceLifeNumber <= 0 ||
                command.Intent.SourceLifeNumber > current.Meta.LifeNumber ||
                string.IsNullOrWhiteSpace(command.Intent.Reason))
            {
                return Failure("next_run_intent.invalid");
            }
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(nextRunIntent: command.Intent)));
        }

        private static TransitionResult<GameSaveAggregate> SetReturnPlan(
            GameSaveAggregate current,
            SetReturnPlanCommand command,
            string commandId)
        {
            if (!ReturnPlanRules.IsValid(command.Plan))
            {
                return Failure("return_plan.invalid");
            }
            var plan = ReturnPlanRules.CarryingReceipt(
                command.Plan,
                current.Meta.ReturnPlan);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(returnPlan: plan)));
        }

        private static TransitionResult<GameSaveAggregate> PrepareReturnPlan(
            GameSaveAggregate current,
            PrepareReturnPlanCommand command,
            string commandId)
        {
            if (command.DevelopmentRulesVersion <= 0)
                return Failure("return_plan.rules_version_invalid");
            var plan = ReturnPlanRules.PrepareForNextReturn(
                current,
                current.InstallId,
                command.DevelopmentRulesVersion,
                command.PreparedAt);
            if (plan == null) return Failure("return_plan.ineligible");
            var receipts = current.AnalyticsReceipts;
            var receiptScope = ReturnPlanRules.EligibleReceiptScope(plan);
            if (receiptScope != null && !receipts.Contains(receiptScope))
            {
                receipts = AnalyticsReceiptRules.Mark(
                    receipts,
                    receiptScope,
                    command.PreparedAt,
                    AnalyticsReceiptRetention.Scoped);
            }
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(returnPlan: plan),
                analyticsReceipts: receipts));
        }

        private static TransitionResult<GameSaveAggregate> CompleteReturnPlanInteraction(
            GameSaveAggregate current,
            CompleteReturnPlanInteractionCommand command,
            string commandId)
        {
            var plan = current.Meta.ReturnPlan;
            if (plan == null) return Failure("return_plan.missing");
            var handled = ReturnPlanRules.MarkWelcomeHandled(plan, command.HandledAt);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(
                    returnPlan: plan.WithDismissed(command.Dismissed),
                    returnWelcomeHandled: handled)));
        }

        private static TransitionResult<GameSaveAggregate> DismissReturnPlan(
            GameSaveAggregate current,
            DismissReturnPlanCommand command,
            string commandId)
        {
            var currentPlan = current.Meta.ReturnPlan;
            if (currentPlan == null) return Failure("return_plan.missing");
            var dismissed = currentPlan.WithDismissed(true);
            var handled = command.HandledAt.HasValue
                ? ReturnPlanRules.MarkWelcomeHandled(currentPlan, command.HandledAt.Value)
                : current.Meta.ReturnWelcomeHandled;
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(
                    returnPlan: dismissed,
                    returnWelcomeHandled: handled)));
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

        private TransitionResult<GameSaveAggregate> RetirePro(
            GameSaveAggregate current,
            RetireProCareerCommand command,
            string commandId)
        {
            var pro = current.Pro;
            if (pro == null) return Failure("retirement.pro_missing");
            if (pro.Phase != ProCareerPhase.Completed)
            {
                var before = pro;
                pro = _pro.Apply(pro, new ProCareerAction("retire"));
                if (!ValidProAdvance(before, pro) || pro.Phase != ProCareerPhase.Completed)
                    return Failure("retirement.port_invalid");
            }
            if (pro.Origin == ProCareerOrigin.HighSchool &&
                (current.HighSchool == null ||
                 !string.Equals(
                     pro.SourceHighSchoolCareerId,
                     current.HighSchool.CareerId,
                     StringComparison.Ordinal) ||
                 !string.Equals(pro.PlayerId, current.HighSchool.PlayerId, StringComparison.Ordinal)))
            {
                return Failure("retirement.source_mismatch");
            }

            var highSchool = pro.Origin == ProCareerOrigin.HighSchool ? current.HighSchool : null;
            var alreadyCredited = current.Meta.CreditedProCareerIds.Contains(
                pro.ProCareerId,
                StringComparer.Ordinal);
            var bonus = alreadyCredited ? 0 : MetaProgressState.ProSoulBonus(pro);
            var credited = alreadyCredited
                ? current.Meta.CreditedProCareerIds
                : current.Meta.CreditedProCareerIds.Concat(new[] { pro.ProCareerId }).ToArray();
            var achievements = AchievementRules.Unlock(
                current.Meta.Achievements,
                AchievementRules.FromPro(pro));
            var meta = current.Meta.With(
                soulBalance: current.Meta.SoulBalance + bonus,
                soulLifetimeEarned: current.Meta.SoulLifetimeEarned + bonus,
                creditedProCareerIds: credited,
                achievements: achievements);

            if (highSchool == null)
            {
                return Success(current.Commit(
                    commandId,
                    stage: current.HighSchool == null
                        ? ApplicationStage.Setup
                        : StageFor(current.HighSchool),
                    clearPro: true,
                    meta: meta,
                    clearPitchResume: true,
                    clearPendingPitchCompletion: true));
            }

            if (alreadyCredited && highSchool.Phase == HighSchoolPhase.Legacy &&
                highSchool.FrozenSignatureLegacyCandidates.Count == 3)
            {
                return Failure("retirement.legacy_selection_pending");
            }
            if (highSchool.Phase == HighSchoolPhase.Completed)
            {
                var before = highSchool;
                highSchool = _highSchool.Apply(highSchool, new HighSchoolAction("open_legacy"));
                if (!ValidHighSchoolAdvance(before, highSchool) ||
                    highSchool.Phase != HighSchoolPhase.Legacy)
                {
                    return Failure("retirement.legacy_open_invalid");
                }
            }
            if (highSchool.Phase != HighSchoolPhase.Legacy)
                return Failure("retirement.high_school_not_completed");
            if (!(_pro is IProCareerLegacyPort legacyPort))
                return Failure("retirement.legacy_port_missing");
            var candidates = legacyPort.CreateLegacyCandidates(highSchool, pro)?.ToArray();
            if (candidates == null || candidates.Length != 3 ||
                candidates.Select(value => value?.Id).Distinct(StringComparer.Ordinal).Count() != 3 ||
                candidates.Any(value => value == null ||
                    string.IsNullOrWhiteSpace(value.Id) ||
                    string.IsNullOrWhiteSpace(value.Title) ||
                    string.IsNullOrWhiteSpace(value.Detail) ||
                    string.IsNullOrWhiteSpace(value.EvidenceSummary)))
            {
                return Failure("retirement.legacy_candidates_invalid");
            }
            highSchool = CopySignatureLegacyState(highSchool, candidates, null);
            return Success(current.Commit(
                commandId,
                stage: ApplicationStage.Legacy,
                highSchool: highSchool,
                pro: pro,
                meta: meta,
                clearPitchResume: true));
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
                stage: ApplicationStage.BetweenLives,
                clearHighSchool: true,
                clearPro: true,
                meta: meta,
                clearPitchResume: true,
                clearPendingPitchCompletion: true));
        }

        private static TransitionResult<GameSaveAggregate> DeleteSave(
            GameSaveAggregate current,
            string commandId)
        {
            return Success(current.Commit(
                commandId,
                stage: ApplicationStage.Deleted,
                clearHighSchool: true,
                clearPro: true,
                clearPitchResume: true,
                clearPendingPitchCompletion: true,
                deleted: true));
        }

        private static MetaProgressState ApplyPitchMeta(
            MetaProgressState current,
            PitchCareerKind kind,
            PitchGameReport report,
            DateTimeOffset completedAt,
            string commandId)
        {
            if (kind == PitchCareerKind.Daily) return current;
            var daily = DailyStreakRules.RecordBaseball(current.Daily, completedAt);
            var playedReceipt = commandId + ":played-day";
            var weekly = WeeklyProgramRules.Record(
                current.Weekly,
                WeeklyTaskKinds.PlayedOnTwoDays,
                1,
                playedReceipt,
                completedAt);
            var task = kind == PitchCareerKind.HighSchool
                ? WeeklyTaskKinds.ImportantGamesCompleted
                : null;
            if (task != null)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    task,
                    1,
                    commandId + ":game",
                    completedAt);
            }
            if (report.SequenceMasteryCount > 0)
            {
                weekly = WeeklyProgramRules.Record(
                    weekly,
                    WeeklyTaskKinds.SequenceMasteryTriggered,
                    report.SequenceMasteryCount,
                    commandId + ":sequence",
                    completedAt);
            }
            var achievements = AchievementRules.Unlock(
                current.Achievements,
                AchievementRules.FromPitch(report));
            return current.With(daily: daily, weekly: weekly, achievements: achievements);
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
                value.LifeDetail);
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
                value.LifeDetail);
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
                lifeDetail: value.LifeDetail);
        }

        private static bool ValidStartedHighSchool(HighSchoolCareerReadModel value, int lifeNumber)
        {
            return value != null && !string.IsNullOrWhiteSpace(value.CareerId) &&
                !string.IsNullOrWhiteSpace(value.NextSeed) && value.LifeNumber == lifeNumber &&
                value.Ratings != null && value.Performance != null;
        }

        private static bool ValidHighSchoolAdvance(
            HighSchoolCareerReadModel before,
            HighSchoolCareerReadModel after)
        {
            return after != null &&
                string.Equals(before.CareerId, after.CareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                after.CoreRevision > before.CoreRevision &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.Performance != null;
        }

        private static bool ValidHighSchoolReservation(
            HighSchoolCareerReadModel before,
            HighSchoolCareerReadModel after)
        {
            return after != null &&
                string.Equals(before.CareerId, after.CareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                after.CoreRevision == before.CoreRevision &&
                after.Phase == before.Phase &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.Performance != null;
        }

        private static bool ValidTutorialReservation(
            HighSchoolCareerReadModel before,
            HighSchoolCareerReadModel after)
        {
            return after != null &&
                string.Equals(before.CareerId, after.CareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                string.Equals(before.NextSeed, after.NextSeed, StringComparison.Ordinal) &&
                string.Equals(before.CoreStateJson, after.CoreStateJson, StringComparison.Ordinal) &&
                after.CoreRevision == before.CoreRevision && after.Phase == before.Phase &&
                after.TutorialAttemptCount == before.TutorialAttemptCount + 1 &&
                after.TutorialCompleted == before.TutorialCompleted &&
                after.Ratings != null && after.Performance != null;
        }

        private static bool ValidStartedPro(ProCareerReadModel value, ProCareerOrigin origin)
        {
            var validInitialPhase = origin == ProCareerOrigin.HighSchool
                ? value?.Phase == ProCareerPhase.ContractOffer && value.ContractOffer != null
                : value?.Phase == ProCareerPhase.WeeklyPlan && value.CoreRevision > 0;
            return value != null && validInitialPhase && value.Origin == origin &&
                !string.IsNullOrWhiteSpace(value.ProCareerId) &&
                !string.IsNullOrWhiteSpace(value.PlayerId) &&
                !string.IsNullOrWhiteSpace(value.NextSeed) &&
                value.Ratings != null && value.CurrentSeason != null;
        }

        private static bool ValidProAdvance(ProCareerReadModel before, ProCareerReadModel after)
        {
            return after != null && after.Origin == before.Origin &&
                string.Equals(before.ProCareerId, after.ProCareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                string.Equals(
                    before.SourceHighSchoolCareerId,
                    after.SourceHighSchoolCareerId,
                    StringComparison.Ordinal) &&
                after.CoreRevision > before.CoreRevision &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.CurrentSeason != null;
        }

        private static bool ValidProReservation(ProCareerReadModel before, ProCareerReadModel after)
        {
            return after != null && after.Origin == before.Origin &&
                string.Equals(before.ProCareerId, after.ProCareerId, StringComparison.Ordinal) &&
                string.Equals(before.PlayerId, after.PlayerId, StringComparison.Ordinal) &&
                string.Equals(
                    before.SourceHighSchoolCareerId,
                    after.SourceHighSchoolCareerId,
                    StringComparison.Ordinal) &&
                after.CoreRevision == before.CoreRevision && after.Phase == before.Phase &&
                !string.IsNullOrWhiteSpace(after.NextSeed) &&
                after.Ratings != null && after.CurrentSeason != null;
        }

        private static ApplicationStage StageFor(HighSchoolCareerReadModel state)
        {
            if (state.Phase == HighSchoolPhase.Draft ||
                state.Draft?.Resolved == true && state.Draft.Drafted &&
                state.Phase == HighSchoolPhase.Completed)
            {
                return ApplicationStage.Draft;
            }
            if (state.Phase == HighSchoolPhase.Legacy || state.Phase == HighSchoolPhase.Completed)
                return ApplicationStage.Legacy;
            return ApplicationStage.HighSchool;
        }

        private static ApplicationStage StageFor(ProCareerReadModel state)
        {
            return state.Phase == ProCareerPhase.RetirementDecision ||
                   state.Phase == ProCareerPhase.Completed
                ? ApplicationStage.Retirement
                : ApplicationStage.Pro;
        }

        private static TransitionResult<GameSaveAggregate> Success(GameSaveAggregate value)
        {
            return TransitionResult<GameSaveAggregate>.Success(value);
        }

        private static TransitionResult<GameSaveAggregate> Failure(string code)
        {
            return TransitionResult<GameSaveAggregate>.Failure(code);
        }
    }
}
