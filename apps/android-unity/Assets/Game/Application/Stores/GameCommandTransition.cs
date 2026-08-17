using System;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;

namespace Baseball.Application.Stores
{
    public sealed partial class GameCommandTransition : IStateTransition<GameSaveAggregate, GameCommand>
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
                    case SuspendPitchSessionCommand value:
                        return SuspendPitch(current, value, commandId);
                    case AbandonPitchSessionCommand value:
                        return AbandonPitch(current, value, commandId);
                    case ConfigureWeeklyProgramCommand value:
                        return ConfigureWeekly(current, value, commandId);
                    case RecordWeeklyProgressCommand value:
                        return RecordWeekly(current, value, commandId);
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
