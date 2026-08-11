using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Application.Commands
{
    public abstract class GameCommand
    {
    }

    public sealed class EnterSetupCommand : GameCommand
    {
    }

    public sealed class StartHighSchoolCareerCommand : GameCommand
    {
        public StartHighSchoolCareerCommand(StartHighSchoolCareerRequest request)
        {
            Request = request ?? throw new ArgumentNullException(nameof(request));
        }

        public StartHighSchoolCareerRequest Request { get; }
    }

    public sealed class StartQuickRebirthCommand : GameCommand
    {
        public StartQuickRebirthCommand(
            string entryPoint = "quick_rebirth",
            DateTimeOffset? startedAt = null)
        {
            EntryPoint = string.IsNullOrWhiteSpace(entryPoint) ? "quick_rebirth" : entryPoint;
            StartedAt = startedAt ?? DateTimeOffset.UnixEpoch;
        }

        public string EntryPoint { get; }
        public DateTimeOffset StartedAt { get; }
    }

    public sealed class EndChallengeRunCommand : GameCommand
    {
    }

    public sealed class UpdateGameSettingsCommand : GameCommand
    {
        public UpdateGameSettingsCommand(
            bool? autoReleaseEnabled = null,
            bool? soundEnabled = null,
            bool? musicEnabled = null,
            bool? hapticsEnabled = null,
            bool? notificationsEnabled = null,
            bool? highContrastEnabled = null,
            bool? reducedMotionEnabled = null)
        {
            AutoReleaseEnabled = autoReleaseEnabled;
            SoundEnabled = soundEnabled;
            MusicEnabled = musicEnabled;
            HapticsEnabled = hapticsEnabled;
            NotificationsEnabled = notificationsEnabled;
            HighContrastEnabled = highContrastEnabled;
            ReducedMotionEnabled = reducedMotionEnabled;
        }

        public bool? AutoReleaseEnabled { get; }
        public bool? SoundEnabled { get; }
        public bool? MusicEnabled { get; }
        public bool? HapticsEnabled { get; }
        public bool? NotificationsEnabled { get; }
        public bool? HighContrastEnabled { get; }
        public bool? ReducedMotionEnabled { get; }

        public bool HasChanges =>
            AutoReleaseEnabled.HasValue || SoundEnabled.HasValue || MusicEnabled.HasValue ||
            HapticsEnabled.HasValue || NotificationsEnabled.HasValue ||
            HighContrastEnabled.HasValue || ReducedMotionEnabled.HasValue;
    }

    public sealed class AdvanceHighSchoolCommand : GameCommand
    {
        public AdvanceHighSchoolCommand(HighSchoolAction action, DateTimeOffset occurredAt)
        {
            Action = action ?? throw new ArgumentNullException(nameof(action));
            OccurredAt = occurredAt;
        }

        public HighSchoolAction Action { get; }
        public DateTimeOffset OccurredAt { get; }
    }

    public sealed class ChoosePledgeCommand : GameCommand
    {
        public ChoosePledgeCommand(string pledgeId, DateTimeOffset chosenAt)
        {
            PledgeId = pledgeId;
            ChosenAt = chosenAt;
        }

        /// <summary>Null or empty means the player explicitly skipped the pledge.</summary>
        public string PledgeId { get; }
        public DateTimeOffset ChosenAt { get; }
    }

    public sealed class EnterProFromDraftCommand : GameCommand
    {
    }

    /// <summary>
    /// Explicitly declines a resolved draft offer and opens legacy selection. This is separate
    /// from generic high-school actions so the decision has its own durable command receipt.
    /// </summary>
    public sealed class DeclineProCareerCommand : GameCommand
    {
    }

    /// <summary>
    /// Leaves the optional bullpen tutorial without recording a tutorial completion or any
    /// pitching progression, then atomically opens school selection.
    /// </summary>
    public sealed class SkipTutorialCommand : GameCommand
    {
    }

    public sealed class SignProContractCommand : GameCommand
    {
    }

    public sealed class StartDirectProCommand : GameCommand
    {
        public StartDirectProCommand(StartDirectProRequest request)
        {
            Request = request ?? throw new ArgumentNullException(nameof(request));
        }

        public StartDirectProRequest Request { get; }
    }

    public sealed class AdvanceProCommand : GameCommand
    {
        public AdvanceProCommand(ProCareerAction action, DateTimeOffset occurredAt)
        {
            Action = action ?? throw new ArgumentNullException(nameof(action));
            OccurredAt = occurredAt;
        }

        public ProCareerAction Action { get; }
        public DateTimeOffset OccurredAt { get; }
    }

    public sealed class BeginPitchSessionCommand : GameCommand
    {
        public BeginPitchSessionCommand(
            string gameId,
            PitchCareerKind careerKind,
            string scenarioId,
            int maximumBatters,
            DateTimeOffset startedAt)
        {
            GameId = gameId;
            CareerKind = careerKind;
            ScenarioId = scenarioId;
            MaximumBatters = maximumBatters;
            StartedAt = startedAt;
        }

        public string GameId { get; }
        public PitchCareerKind CareerKind { get; }
        public string ScenarioId { get; }
        public int MaximumBatters { get; }
        public DateTimeOffset StartedAt { get; }
    }

    public sealed class CheckpointPitchSessionCommand : GameCommand
    {
        public CheckpointPitchSessionCommand(
            string gameId,
            int completedBatters,
            string checkpointJson,
            PitchGameReport accumulatedReport = null)
        {
            GameId = gameId;
            CompletedBatters = completedBatters;
            CheckpointJson = checkpointJson;
            AccumulatedReport = accumulatedReport;
        }

        public string GameId { get; }
        public int CompletedBatters { get; }
        public string CheckpointJson { get; }
        public PitchGameReport AccumulatedReport { get; }
    }

    public sealed class CommitPitchResultCommand : GameCommand
    {
        public CommitPitchResultCommand(
            string gameId,
            string pitchId,
            int batterIndex,
            string eventHash,
            string kernelResultJson,
            string presentationJson,
            DateTimeOffset committedAt,
            PitchSequencePitch sequencePitch = null,
            PitchSequenceTag? sequenceTag = null,
            PitchDeliveryMetricState delivery = null,
            PlateAppearanceContext sequenceContext = null,
            RivalMemorySnapshot sequenceRivalMemory = null,
            PitchAbilityMomentEvidence abilityMomentEvidence = null)
        {
            GameId = gameId;
            PitchId = pitchId;
            BatterIndex = batterIndex;
            EventHash = eventHash;
            KernelResultJson = kernelResultJson;
            PresentationJson = presentationJson;
            CommittedAt = committedAt;
            SequencePitch = sequencePitch ?? SequenceFrom(abilityMomentEvidence);
            SequenceTag = sequenceTag;
            Delivery = delivery;
            SequenceContext = sequenceContext ?? abilityMomentEvidence?.PreResultContext;
            SequenceRivalMemory = sequenceRivalMemory;
            AbilityMomentEvidence = abilityMomentEvidence;
        }

        public string GameId { get; }
        public string PitchId { get; }
        public int BatterIndex { get; }
        public string EventHash { get; }
        public string KernelResultJson { get; }
        public string PresentationJson { get; }
        public DateTimeOffset CommittedAt { get; }
        public PitchSequencePitch SequencePitch { get; }
        public PitchSequenceTag? SequenceTag { get; }
        public PitchDeliveryMetricState Delivery { get; }
        /// <summary>Pre-result context used by Application to verify SequenceTag.</summary>
        public PlateAppearanceContext SequenceContext { get; }
        public RivalMemorySnapshot SequenceRivalMemory { get; }
        /// <summary>Authoritative inputs; Application derives the durable Core moment wire.</summary>
        public PitchAbilityMomentEvidence AbilityMomentEvidence { get; }

        private static PitchSequencePitch SequenceFrom(PitchAbilityMomentEvidence evidence)
        {
            if (evidence?.Call == null || evidence.Execution == null) return null;
            return new PitchSequencePitch(
                evidence.Call.PitchType,
                evidence.Call.Zone,
                evidence.Call.ZoneIntent,
                Math.Max(1, evidence.Execution.VelocityTenthsKph / 10),
                evidence.Outcome);
        }
    }

    public sealed class PitchAbilityMomentEvidence
    {
        public PitchAbilityMomentEvidence(
            PitchCall call,
            PlateAppearanceContext preResultContext,
            PitchOutcome outcome,
            PitchExecution execution)
        {
            Call = call;
            PreResultContext = preResultContext;
            Outcome = outcome;
            Execution = execution;
        }

        public PitchCall Call { get; }
        public PlateAppearanceContext PreResultContext { get; }
        public PitchOutcome Outcome { get; }
        public PitchExecution Execution { get; }
    }

    public sealed class ConsumeCommittedPitchResultCommand : GameCommand
    {
        public ConsumeCommittedPitchResultCommand(
            string gameId,
            string pitchId,
            int completedBatters,
            string checkpointJson,
            PitchGameReport accumulatedReport = null,
            bool sessionCompleted = false)
        {
            GameId = gameId;
            PitchId = pitchId;
            CompletedBatters = completedBatters;
            CheckpointJson = checkpointJson;
            AccumulatedReport = accumulatedReport;
            SessionCompleted = sessionCompleted;
        }

        public string GameId { get; }
        public string PitchId { get; }
        public int CompletedBatters { get; }
        public string CheckpointJson { get; }
        public PitchGameReport AccumulatedReport { get; }
        public bool SessionCompleted { get; }
    }

    public sealed class CompletePitchSessionCommand : GameCommand
    {
        public CompletePitchSessionCommand(PitchGameReport report, DateTimeOffset completedAt)
        {
            Report = report ?? throw new ArgumentNullException(nameof(report));
            CompletedAt = completedAt;
        }

        public PitchGameReport Report { get; }
        public DateTimeOffset CompletedAt { get; }
    }

    /// <summary>
    /// Replaces a finished practice attempt before it is accepted. No Core career seed or result
    /// is consumed; the application-owned attempt counter produces a fresh playable seed.
    /// </summary>
    public sealed class RetryTutorialPitchCommand : GameCommand
    {
        public RetryTutorialPitchCommand(
            string currentGameId,
            string nextGameId,
            string scenarioId,
            DateTimeOffset startedAt)
        {
            CurrentGameId = currentGameId;
            NextGameId = nextGameId;
            ScenarioId = scenarioId;
            StartedAt = startedAt;
        }

        public string CurrentGameId { get; }
        public string NextGameId { get; }
        public string ScenarioId { get; }
        public DateTimeOffset StartedAt { get; }
    }

    public sealed class AcknowledgePitchResultCommand : GameCommand
    {
        public AcknowledgePitchResultCommand(string completionId)
        {
            CompletionId = completionId;
        }

        public string CompletionId { get; }
    }

    public sealed class AbandonPitchSessionCommand : GameCommand
    {
        public AbandonPitchSessionCommand(string gameId)
        {
            GameId = gameId;
        }

        public string GameId { get; }
    }

    public sealed class ConfigureWeeklyProgramCommand : GameCommand
    {
        public ConfigureWeeklyProgramCommand(
            WeeklyEligibility eligibility,
            DateTimeOffset observedAt)
        {
            Eligibility = eligibility ?? throw new ArgumentNullException(nameof(eligibility));
            ObservedAt = observedAt;
        }

        public WeeklyEligibility Eligibility { get; }
        public DateTimeOffset ObservedAt { get; }
    }

    public sealed class RecordWeeklyProgressCommand : GameCommand
    {
        public RecordWeeklyProgressCommand(
            string kind,
            int amount,
            string receiptId,
            DateTimeOffset occurredAt,
            bool countsAsBaseball = false)
        {
            Kind = kind;
            Amount = amount;
            ReceiptId = receiptId;
            OccurredAt = occurredAt;
            CountsAsBaseball = countsAsBaseball;
        }

        public string Kind { get; }
        public int Amount { get; }
        public string ReceiptId { get; }
        public DateTimeOffset OccurredAt { get; }
        public bool CountsAsBaseball { get; }
    }

    public sealed class ClaimWeeklyRewardCommand : GameCommand
    {
        public ClaimWeeklyRewardCommand(DateTimeOffset claimedAt)
        {
            ClaimedAt = claimedAt;
        }

        public DateTimeOffset ClaimedAt { get; }
    }

    public sealed class UnlockAchievementsCommand : GameCommand
    {
        public UnlockAchievementsCommand(IReadOnlyList<string> achievementIds)
        {
            AchievementIds = (achievementIds ?? Array.Empty<string>()).ToArray();
        }

        public IReadOnlyList<string> AchievementIds { get; }
    }

    public sealed class AcknowledgeAchievementCommand : GameCommand
    {
        public AcknowledgeAchievementCommand(string achievementId)
        {
            AchievementId = achievementId;
        }

        public string AchievementId { get; }
    }

    /// <summary>
    /// Persists a one-shot analytics receipt. The caller may emit to the analytics SDK only after
    /// this command is Applied; DomainRejected and PersistenceFailed both mean do not emit.
    /// </summary>
    public sealed class MarkAnalyticsReceiptCommand : GameCommand
    {
        public MarkAnalyticsReceiptCommand(
            string scopeId,
            DateTimeOffset recordedAt,
            AnalyticsReceiptRetention retention = AnalyticsReceiptRetention.Lifetime)
        {
            ScopeId = scopeId;
            RecordedAt = recordedAt;
            Retention = retention;
        }

        public string ScopeId { get; }
        public DateTimeOffset RecordedAt { get; }
        public AnalyticsReceiptRetention Retention { get; }
    }

    public sealed class SetNextRunIntentCommand : GameCommand
    {
        public SetNextRunIntentCommand(NextRunIntentState intent)
        {
            Intent = intent ?? throw new ArgumentNullException(nameof(intent));
        }

        public NextRunIntentState Intent { get; }
    }

    public sealed class SetReturnPlanCommand : GameCommand
    {
        public SetReturnPlanCommand(ReturnPlanState plan)
        {
            Plan = plan ?? throw new ArgumentNullException(nameof(plan));
        }

        public ReturnPlanState Plan { get; }
    }

    /// <summary>Builds the eligible plan and frozen experiment receipt from the saved aggregate.</summary>
    public sealed class PrepareReturnPlanCommand : GameCommand
    {
        public PrepareReturnPlanCommand(DateTimeOffset preparedAt, int developmentRulesVersion)
        {
            PreparedAt = preparedAt;
            DevelopmentRulesVersion = developmentRulesVersion;
        }

        public DateTimeOffset PreparedAt { get; }
        public int DevelopmentRulesVersion { get; }
    }

    /// <summary>Persists same-day welcome suppression for both a card tap and a dismissal.</summary>
    public sealed class CompleteReturnPlanInteractionCommand : GameCommand
    {
        public CompleteReturnPlanInteractionCommand(bool dismissed, DateTimeOffset handledAt)
        {
            Dismissed = dismissed;
            HandledAt = handledAt;
        }

        public bool Dismissed { get; }
        public DateTimeOffset HandledAt { get; }
    }

    public sealed class DismissReturnPlanCommand : GameCommand
    {
        public DismissReturnPlanCommand(DateTimeOffset? handledAt = null)
        {
            HandledAt = handledAt;
        }

        public DateTimeOffset? HandledAt { get; }
    }

    public sealed class ArchiveHighSchoolLifeCommand : GameCommand
    {
        public ArchiveHighSchoolLifeCommand(
            IReadOnlyList<string> memories,
            DateTimeOffset completedAt)
        {
            Memories = (memories ?? Array.Empty<string>()).ToArray();
            CompletedAt = completedAt;
        }

        public IReadOnlyList<string> Memories { get; }
        public DateTimeOffset CompletedAt { get; }
    }

    /// <summary>
    /// Selects the offered legacy and archives its reward in one durable aggregate revision.
    /// Exactly one of SignatureLegacyId or the required memory-card list is accepted by mode.
    /// </summary>
    public sealed class FinalizeHighSchoolLegacyCommand : GameCommand
    {
        public FinalizeHighSchoolLegacyCommand(
            IReadOnlyList<string> memories,
            string signatureLegacyId,
            DateTimeOffset completedAt)
        {
            Memories = (memories ?? Array.Empty<string>()).ToArray();
            SignatureLegacyId = signatureLegacyId;
            CompletedAt = completedAt;
        }

        public IReadOnlyList<string> Memories { get; }
        public string SignatureLegacyId { get; }
        public DateTimeOffset CompletedAt { get; }
    }

    public sealed class RetireProCareerCommand : GameCommand
    {
        public RetireProCareerCommand(DateTimeOffset completedAt)
        {
            CompletedAt = completedAt;
        }

        public DateTimeOffset CompletedAt { get; }
    }

    public sealed class BeginRebirthCommand : GameCommand
    {
        public BeginRebirthCommand(DateTimeOffset startedAt)
        {
            StartedAt = startedAt;
        }

        public DateTimeOffset StartedAt { get; }
    }

    public sealed class DeleteSaveCommand : GameCommand
    {
    }
}
