using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Platform.Analytics;
using Baseball.Platform.Crash;
using Baseball.Platform.Notifications;

namespace Baseball.Presentation.Shell
{
    public sealed partial class ProductionBaseballShellRuntime
    {
        private readonly HashSet<string> _analyticsReceiptsInFlight =
            new HashSet<string>(StringComparer.Ordinal);
        private bool _coldStartAnalyticsObserved;
        private ShellRoute? _lastAnalyticsRoute;

        private async Task LogSuccessfulActionAsync(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after,
            CancellationToken cancellationToken)
        {
            string careerScope = CareerScope(before ?? after);
            bool countsTowardHighSchoolProgress =
                CareerAnalyticsEligibility.CountsTowardHighSchoolProgress(before, after);

            switch (actionId)
            {
                case "enter_setup":
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.OnboardingStarted,
                        new Dictionary<string, object>(StringComparer.Ordinal),
                        AnalyticsReceiptRetention.Lifetime,
                        cancellationToken,
                        "install");
                    return;
                case "start_high_school":
                case "quick_rebirth":
                case "quick_rebirth_from_recap":
                    if (after?.HighSchool?.IsChallengeRun == true) break;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.OnboardingCompleted,
                        new Dictionary<string, object>(StringComparer.Ordinal),
                        AnalyticsReceiptRetention.Lifetime,
                        cancellationToken,
                        "install");
                    if ((after?.HighSchool?.LifeNumber ?? 1) > 1)
                    {
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.RebirthStarted,
                            RebirthProperties(actionId, before, after),
                            AnalyticsReceiptRetention.Scoped,
                            cancellationToken,
                            CareerScope(after),
                            "life-" + after.HighSchool.LifeNumber);
                    }
                    if (!string.IsNullOrWhiteSpace(after?.HighSchool?.EquippedSignatureLegacyId))
                    {
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.SignatureLegacyEquipped,
                            SignatureEquippedProperties(after),
                            AnalyticsReceiptRetention.Scoped,
                            cancellationToken,
                            CareerScope(after),
                            "signature-equipped");
                    }
                    if (actionId == "quick_rebirth_from_recap")
                    {
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.RecapContinueTapped,
                            RecapContinueProperties(before, "quick_rebirth"),
                            AnalyticsReceiptRetention.Scoped,
                            cancellationToken,
                            careerScope,
                            "quick-rebirth");
                    }
                    break;
                case "choose_pledge":
                case "skip_pledge":
                    RunPledgeCatalogReadModel pledgeCatalog = RunPledgeRules.Project(after);
                    RunPledgeReadModel pledge = pledgeCatalog.Selected;
                    bool recommended = RunPledgeAnalyticsPolicy.WasRecommended(
                        before?.Meta?.NextRunIntent,
                        pledge?.Id);
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.RunPledgeSelected,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["pledge_id"] = pledge?.Id ?? "none",
                            ["tier"] = pledge?.TierId ?? "none",
                            ["life_number"] = after?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                            ["recommended"] = recommended,
                        },
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope);
                    if (pledge != null && recommended)
                    {
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.NextRunIntentApplied,
                            new Dictionary<string, object>(StringComparer.Ordinal)
                            {
                                ["pledge_id"] = pledge.Id,
                                ["life_number"] = after?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                            },
                            AnalyticsReceiptRetention.Scoped,
                            cancellationToken,
                            careerScope,
                            "next-intent");
                    }
                    break;
                case "save_next_run_intent":
                    NextRunIntentState savedIntent = after?.Meta?.NextRunIntent;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.NextRunIntentSaved,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["pledge_id"] = savedIntent?.PledgeId ?? "none",
                            ["source_life_number"] = savedIntent?.SourceLifeNumber ?? before?.Meta?.LifeNumber ?? 1,
                        },
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope,
                        "next-intent");
                    break;
                case "resolve_pro_decision":
                    string[] decision = (GetChoice("pro_season_decision") ?? string.Empty)
                        .Split(new[] { '|' }, 2);
                    string decisionId = decision.Length > 0 && !string.IsNullOrWhiteSpace(decision[0])
                        ? decision[0]
                        : before?.Pro?.SeasonDecision?.Id ?? "unknown";
                    string decisionChoiceId = decision.Length > 1 && !string.IsNullOrWhiteSpace(decision[1])
                        ? decision[1]
                        : "unknown";
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.ProSeasonDecisionSelected,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["decision_id"] = decisionId,
                            ["choice_id"] = decisionChoiceId,
                            ["season"] = before?.Pro?.Season ?? 1,
                            ["week"] = before?.Pro?.Week ?? 1,
                        },
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope,
                        "season-" + Math.Max(1, before?.Pro?.Season ?? 1),
                        decisionId);
                    break;
                case "retire_pro":
                    if (ProRetirementAnalyticsPolicy.TryProject(before, after, out var proLegacy))
                    {
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.ProLegacyRecorded,
                            new Dictionary<string, object>(StringComparer.Ordinal)
                            {
                                ["life_number"] = proLegacy.LifeNumber,
                                ["pro_seasons"] = proLegacy.ProSeasons,
                                ["soul_bonus"] = proLegacy.SoulBonus,
                                ["has_signature_candidates"] = proLegacy.HasSignatureCandidates,
                            },
                            AnalyticsReceiptRetention.Scoped,
                            cancellationToken,
                            before.Pro.ProCareerId,
                            "pro-legacy");
                    }
                    break;
                case "finalize_high_school_legacy":
                    await EmitLegacySettlementAnalyticsAsync(before, after, careerScope, cancellationToken);
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.LifeCompleted,
                        LifeCompletedProperties(before, after),
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope,
                        "life-completed");
                    break;
                case "begin_rebirth":
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.RecapContinueTapped,
                        RecapContinueProperties(before, "customize"),
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope);
                    break;
                case "claim_weekly":
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.WeeklyProgramCompleted,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["week_key"] = before?.Meta?.Weekly?.Program?.WeekKey ?? "unknown",
                            ["completed_tasks"] = before?.Meta?.Weekly?.Program?.CompletedCount ?? 0,
                            ["perfect"] = before?.Meta?.Weekly?.Program?.IsPerfect == true,
                        },
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        before?.Meta?.Weekly?.Program?.WeekKey ?? "weekly");
                    break;
                case "open_return_plan":
                case "dismiss_return_plan":
                    ReturnPlanState welcome = WelcomeReturnPlan(before, DateTimeOffset.UtcNow);
                    if (welcome == null) break;
                    AnalyticsEvent returnEvent = actionId == "open_return_plan"
                        ? AnalyticsEvent.ReturnPlanTapped
                        : AnalyticsEvent.ReturnPlanDismissed;
                    await EmitDurableOnceAsync(
                        returnEvent,
                        ReturnPlanProperties(welcome, DateTimeOffset.UtcNow),
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        welcome?.ReceiptId ?? careerScope,
                        welcome?.SavedDayKey ?? "legacy");
                    break;
                case "train":
                    if (!countsTowardHighSchoolProgress) break;
                    await EmitTrainingAnalyticsAsync(
                        after,
                        after?.HighSchool?.LastTraining == null
                            ? Array.Empty<TrainingResultReadModel>()
                            : new[] { after.HighSchool.LastTraining },
                        careerScope,
                        cancellationToken);
                    break;
                case "train_block":
                    if (!countsTowardHighSchoolProgress) break;
                    await EmitTrainingAnalyticsAsync(
                        after,
                        after?.HighSchool?.LastTrainingBlock?.Sessions ??
                            Array.Empty<TrainingResultReadModel>(),
                        careerScope,
                        cancellationToken);
                    break;
                case "advance_chapter":
                    if (!countsTowardHighSchoolProgress) break;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.ChapterAdvanced,
                        ChapterProperties(after),
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope,
                        "chapter-" + (after?.HighSchool?.ChapterNumber ?? 0));
                    break;
                case "resolve_draft":
                    if (!countsTowardHighSchoolProgress) break;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.DraftResolved,
                        DraftProperties(after),
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        careerScope,
                        "draft");
                    break;
                case "sign_pro_contract":
                case "start_direct_pro":
                    string proStartScope = actionId == "start_direct_pro" &&
                        !string.IsNullOrWhiteSpace(after?.Pro?.ProCareerId)
                            ? after.Pro.ProCareerId
                            : careerScope;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.ProCareerStarted,
                        ProStartedProperties(actionId, before, after),
                        AnalyticsReceiptRetention.Scoped,
                        cancellationToken,
                        proStartScope,
                        "pro-start");
                    break;
            }

            await EmitPhaseTransitionAnalyticsAsync(before, after, cancellationToken);
        }

        private async Task EmitTrainingAnalyticsAsync(
            GameSaveAggregate after,
            IReadOnlyList<TrainingResultReadModel> sessions,
            string careerScope,
            CancellationToken cancellationToken)
        {
            foreach (TrainingResultReadModel training in sessions ?? Array.Empty<TrainingResultReadModel>())
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.CareerTrainingCompleted,
                    TrainingProperties(after, training),
                    AnalyticsReceiptRetention.Scoped,
                    cancellationToken,
                    careerScope,
                    "training-" + training.Number);
            }
        }

        private static IReadOnlyDictionary<string, object> TrainingProperties(
            GameSaveAggregate after,
            TrainingResultReadModel training)
        {
            HighSchoolCareerReadModel career = after?.HighSchool;
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["life_number"] = career?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                ["act_number"] = ActNumber(career?.ChapterNumber ?? 0),
                ["focus_id"] = training?.Focus ?? "unknown",
                ["intensity_id"] = training?.Intensity ?? "unknown",
                ["target_pitch_id"] = string.IsNullOrWhiteSpace(training?.TargetPitch)
                    ? "all"
                    : training.TargetPitch,
                ["growth_points"] = training?.Growth ?? 0,
                ["fatigue_delta"] = training?.FatigueChange ?? 0,
            };
        }

        private static IReadOnlyDictionary<string, object> ChapterProperties(GameSaveAggregate after)
        {
            int chapter = after?.HighSchool?.ChapterNumber ?? 0;
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["chapter"] = chapter,
                ["act_number"] = ActNumber(chapter),
            };
        }

        private static IReadOnlyDictionary<string, object> DraftProperties(GameSaveAggregate after)
        {
            DraftReadModel draft = after?.HighSchool?.Draft;
            int chapter = after?.HighSchool?.ChapterNumber ?? 8;
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["drafted"] = draft?.Drafted == true,
                ["score"] = draft?.EvaluationScore ?? 0,
                ["life_number"] = after?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                ["act_number"] = ActNumber(chapter),
            };
        }

        private static IReadOnlyDictionary<string, object> ProStartedProperties(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            DraftReadModel draft = before?.HighSchool?.Draft;
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["round"] = draft?.Round ?? 0,
                ["evaluation"] = draft?.EvaluationScore ?? 0,
                ["life_number"] = before?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                ["source"] = actionId == "sign_pro_contract" ? "high_school_draft" : "direct_setup",
            };
        }

        private static IReadOnlyDictionary<string, object> RebirthProperties(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["life_number"] = after?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                ["entry_point"] = actionId == "quick_rebirth_from_recap"
                    ? "recap"
                    : actionId == "quick_rebirth" ? "quick_rebirth" : "setup_flow",
                ["selected_legacy_id"] = after?.HighSchool?.EquippedSignatureLegacyId ??
                    before?.Meta?.EquippedSignatureLegacyId ??
                    "pre_feature_memory_bridge",
                ["inheritance_rules_version"] = 2,
                ["soul_total"] = after?.Meta?.AutomaticSoulEarned ?? 0,
                ["soul_wallet"] = after?.Meta?.SoulBalance ?? 0,
                ["soul_lifetime_earned"] = after?.Meta?.SoulLifetimeEarned ?? 0,
                ["soul_applied"] = AppliedSoul(after?.Meta?.AutomaticSoulEarned ?? 0),
            };
        }

        private static IReadOnlyDictionary<string, object> RecapContinueProperties(
            GameSaveAggregate before,
            string entryPath)
        {
            var record = LatestLifeRecord(before);
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["life_number"] = record?.LifeNumber ?? before?.Meta?.LifeNumber ?? 1,
                ["drafted"] = record?.Drafted == true,
                ["entry_path"] = entryPath,
                ["has_suggested_intent"] = record?.SuggestedNextRunIntent != null,
                ["intent_saved"] = before?.Meta?.NextRunIntent != null,
            };
        }

        private static IReadOnlyDictionary<string, object> LifeCompletedProperties(
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            var record = LatestLifeRecord(after);
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["life_number"] = record?.LifeNumber ?? before?.HighSchool?.LifeNumber ?? 1,
                ["act_number"] = 4,
                ["drafted"] = record?.Drafted == true,
                ["evaluation"] = record?.DraftEvaluation ?? 0,
                ["trainings"] = before?.HighSchool?.LastTraining?.Number ?? 0,
                ["important_games"] = record?.HighSchoolPerformance?.ImportantGames ?? 0,
                ["pitches"] = record?.HighSchoolPerformance?.Pitches ?? 0,
                ["legacy_id"] = after?.Meta?.EquippedSignatureLegacyId ?? "pre_feature_memory_bridge",
                ["legacy_rules_version"] = (int)Baseball.Core.HighSchool.CareerSignatureLegacyRulesVersion.V1,
                ["unlocked_legacy_count"] = after?.Meta?.UnlockedSignatureLegacyIds?.Count ?? 0,
                ["inheritance_rules_version"] = 2,
                ["soul_total"] = after?.Meta?.AutomaticSoulEarned ?? 0,
                ["soul_wallet"] = after?.Meta?.SoulBalance ?? 0,
                ["soul_lifetime_earned"] = after?.Meta?.SoulLifetimeEarned ?? 0,
                ["soul_applied"] = AppliedSoul(after?.Meta?.AutomaticSoulEarned ?? 0),
            };
        }

        private static int ActNumber(int chapter) =>
            chapter <= 0 ? 0 : Math.Min(4, Math.Max(1, (chapter + 1) / 2));

        private static IReadOnlyDictionary<string, object> SignatureOptionsProperties(
            GameSaveAggregate state)
        {
            IReadOnlyList<Baseball.Application.Commands.CareerChoiceReadModel> choices =
                state?.HighSchool?.SignatureLegacyChoices ??
                Array.Empty<Baseball.Application.Commands.CareerChoiceReadModel>();
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["life_number"] = state?.HighSchool?.LifeNumber ?? state?.Meta?.LifeNumber ?? 1,
                ["drafted"] = state?.HighSchool?.Draft?.Drafted == true,
                ["includes_pro_career"] = state?.Pro != null,
                ["option_ids"] = string.Join(",", choices
                    .Select(option => option.Payload)
                    .Where(value => !string.IsNullOrWhiteSpace(value))
                    .Distinct(StringComparer.Ordinal)
                    .OrderBy(value => value, StringComparer.Ordinal)),
            };
        }

        private static IReadOnlyDictionary<string, object> SignatureSelectedProperties(
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            string selectedId = after?.Meta?.EquippedSignatureLegacyId ??
                before?.HighSchool?.SelectedSignatureLegacyId ?? "unknown";
            TrySignatureDefinition(selectedId, out Baseball.Core.HighSchool.CareerSignatureLegacy definition);
            var record = LatestLifeRecord(after);
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["legacy_id"] = selectedId,
                ["family"] = definition?.Family.ToString().ToLowerInvariant() ?? "unknown",
                ["life_number"] = record?.LifeNumber ?? before?.HighSchool?.LifeNumber ?? 1,
                ["drafted"] = record?.Drafted == true,
                ["rating_growth"] = SignatureRatingGrowth(definition, before?.HighSchool),
                ["includes_pro_career"] = (record?.ProSeasons ?? 0) > 0,
                ["pro_seasons"] = record?.ProSeasons ?? 0,
            };
        }

        private static IReadOnlyDictionary<string, object> SignatureEquippedProperties(
            GameSaveAggregate after)
        {
            string selectedId = after?.HighSchool?.EquippedSignatureLegacyId ?? "unknown";
            TrySignatureDefinition(selectedId, out Baseball.Core.HighSchool.CareerSignatureLegacy definition);
            Baseball.Core.HighSchool.CareerSignatureLegacyEffect effect = definition?.Effect;
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["legacy_id"] = selectedId,
                ["family"] = definition?.Family.ToString().ToLowerInvariant() ?? "unknown",
                ["life_number"] = after?.HighSchool?.LifeNumber ?? after?.Meta?.LifeNumber ?? 1,
                ["total_rating_bonus"] = effect == null
                    ? 0
                    : effect.Stuff + effect.Command + effect.Movement + effect.Stamina,
                ["inheritance_rules_version"] = 2,
                ["soul_total"] = after?.Meta?.AutomaticSoulEarned ?? 0,
                ["soul_wallet"] = after?.Meta?.SoulBalance ?? 0,
                ["soul_lifetime_earned"] = after?.Meta?.SoulLifetimeEarned ?? 0,
                ["soul_applied"] = AppliedSoul(after?.Meta?.AutomaticSoulEarned ?? 0),
            };
        }

        private static bool TrySignatureDefinition(
            string id,
            out Baseball.Core.HighSchool.CareerSignatureLegacy definition)
        {
            foreach (Baseball.Core.HighSchool.CareerSignatureLegacyId value in
                Enum.GetValues(typeof(Baseball.Core.HighSchool.CareerSignatureLegacyId)))
            {
                if (!string.Equals(
                        Baseball.Core.HighSchool.CareerSignatureLegacyWire.Value(value),
                        id,
                        StringComparison.Ordinal)) continue;
                definition = Baseball.Core.HighSchool.CareerSignatureLegacy.Definition(value);
                return true;
            }
            definition = null;
            return false;
        }

        private static int AppliedSoul(int total) =>
            Baseball.Core.HighSchool.HighSchoolCareerEngine.AppliedInheritance(
                total,
                Baseball.Core.HighSchool.SoulInheritanceRulesVersion.V2);

        private static LifeArchiveRecord LatestLifeRecord(GameSaveAggregate state) =>
            state?.Meta?.LifeArchive
                ?.OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();

        private static int SignatureRatingGrowth(
            Baseball.Core.HighSchool.CareerSignatureLegacy definition,
            HighSchoolCareerReadModel career)
        {
            if (definition == null || career?.Ratings == null) return 0;
            Baseball.Core.Catalogs.PitcherPresetSnapshot preset =
                Baseball.Core.Catalogs.PitcherPresetCatalog.All.FirstOrDefault(value =>
                    string.Equals(value.Id, career.PresetId, StringComparison.Ordinal));
            if (preset == null) return 0;
            int stuff = Math.Max(0, career.Ratings.Stuff - preset.Pitcher.Stuff);
            int command = Math.Max(0, career.Ratings.Command - preset.Pitcher.Command);
            int movement = Math.Max(0, career.Ratings.Movement - preset.Pitcher.Movement);
            int stamina = Math.Max(0, career.Ratings.Stamina - preset.Pitcher.Stamina);
            switch (definition.Family)
            {
                case Baseball.Core.HighSchool.CareerSignatureLegacyFamily.Power: return stuff;
                case Baseball.Core.HighSchool.CareerSignatureLegacyFamily.Command: return command;
                case Baseball.Core.HighSchool.CareerSignatureLegacyFamily.Breaking: return movement;
                case Baseball.Core.HighSchool.CareerSignatureLegacyFamily.Endurance: return stamina;
                case Baseball.Core.HighSchool.CareerSignatureLegacyFamily.Gamecraft: return command + movement;
                default: return command;
            }
        }

        private async Task EmitLegacySettlementAnalyticsAsync(
            GameSaveAggregate before,
            GameSaveAggregate after,
            string careerScope,
            CancellationToken cancellationToken)
        {
            var archived = LatestLifeRecord(after);
            if (archived?.PledgeId != null)
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.RunPledgeResolved,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["pledge_id"] = archived.PledgeId,
                        ["achieved"] = archived.PledgeAchieved == true,
                        ["progress_ratio"] = (archived.PledgeProgressRatioPermille ?? 0) / 1000d,
                        ["reward_permille"] = archived.PledgeRewardPermille ?? 0,
                    },
                    AnalyticsReceiptRetention.Scoped,
                    cancellationToken,
                    careerScope,
                    "pledge-result");
            }
            if (before?.HighSchool?.LegacySelectionMode == LegacySelectionMode.SignatureLegacy)
            {
                await EmitDurableOnceAsync(
                    AnalyticsEvent.SignatureLegacySelected,
                    SignatureSelectedProperties(before, after),
                    AnalyticsReceiptRetention.Scoped,
                    cancellationToken,
                    careerScope,
                    "signature-selected");
            }
        }

        private async Task<bool> EmitDurableOnceAsync(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> properties,
            AnalyticsReceiptRetention retention,
            CancellationToken cancellationToken,
            params string[] stableScopeParts)
        {
            GameApplicationStore store = _store;
            if (store == null || stableScopeParts == null || stableScopeParts.Length == 0)
                return false;
            string scope;
            try
            {
                scope = AnalyticsReceiptRules.Scope(analyticsEvent.Value(), stableScopeParts);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "analytics_scope");
                return false;
            }
            if (!_analyticsReceiptsInFlight.Add(scope)) return false;
            try
            {
                for (var attempt = 0; attempt < 2; attempt++)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    GameSaveAggregate current = store.Current;
                    if (current.AnalyticsReceipts.Contains(scope)) return false;
                    DispatchResult<GameSaveAggregate> result = await store.DispatchAsync(
                        new CommandEnvelope<GameCommand>(
                            "analytics:" + scope,
                            current.Revision,
                            new MarkAnalyticsReceiptCommand(scope, DateTimeOffset.UtcNow, retention)),
                        cancellationToken);
                    if (result.Status == DispatchStatus.Applied)
                    {
                        SafeLog(analyticsEvent, properties);
                        return true;
                    }
                    if (result.Status == DispatchStatus.AlreadyApplied ||
                        result.Status == DispatchStatus.DomainRejected &&
                        string.Equals(result.ErrorCode, "analytics.already_marked", StringComparison.Ordinal))
                    {
                        return false;
                    }
                    if (result.Status != DispatchStatus.StaleRevision) return false;
                }
            }
            catch (OperationCanceledException)
            {
                return false;
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "analytics_receipt");
            }
            finally
            {
                _analyticsReceiptsInFlight.Remove(scope);
            }
            return false;
        }

        private async void DrainPendingReminderOpen()
        {
            AndroidReminderService reminders = AndroidReminderService.Instance;
            GameApplicationStore store = _store;
            if (_reminderOpenInFlight || _reminderNavigationReceiptInFlight ||
                !string.IsNullOrWhiteSpace(_externalRouteReminderToken) ||
                reminders == null || store == null ||
                !reminders.TryPeekReminderOpen(out ReminderOpenRequest request)) return;

            string analyticsScope;
            string navigationScope;
            try
            {
                analyticsScope = AnalyticsReceiptRules.Scope(
                    AnalyticsEvent.ReminderOpened.Value(),
                    request.StableTokenHash);
                navigationScope = AnalyticsReceiptRules.Scope(
                    ReminderOpenReceiptPolicy.NavigationReceiptEventId,
                    request.StableTokenHash);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "reminder_open_scope");
                return;
            }

            ReminderOpenReceiptAction beforeAction = ReminderOpenReceiptPolicy.BeforeDispatch(
                _status == ShellRuntimeStatus.Ready,
                store.IsBusy,
                store.Current.AnalyticsReceipts.Contains(analyticsScope),
                store.Current.AnalyticsReceipts.Contains(navigationScope));
            if (beforeAction == ReminderOpenReceiptAction.Wait) return;
            if (beforeAction == ReminderOpenReceiptAction.CompleteHandled)
            {
                reminders.CompleteReminderOpen(request.StableTokenHash);
                return;
            }
            if (beforeAction == ReminderOpenReceiptAction.PresentNavigation)
            {
                PresentReminderNavigation(request);
                return;
            }

            _reminderOpenInFlight = true;
            try
            {
                AndroidReminderIntent intent = request.Intent;
                bool emitted = await EmitDurableOnceAsync(
                    AnalyticsEvent.ReminderOpened,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["destination"] = intent.Destination,
                        ["reason"] = intent.Reason,
                        ["experiment_id"] = intent.ExperimentId,
                        ["variant"] = intent.Variant,
                        ["plan_receipt"] = intent.Receipt,
                        ["saved_day_key"] = intent.SavedDayKey,
                        ["development_rules_version"] = intent.DevelopmentRulesVersion,
                    },
                    AnalyticsReceiptRetention.Scoped,
                    CancellationToken.None,
                    request.StableTokenHash);
                ReminderOpenReceiptAction afterAction = ReminderOpenReceiptPolicy.AfterAnalyticsDispatch(
                    emitted,
                    store.Current.AnalyticsReceipts.Contains(analyticsScope),
                    store.Current.AnalyticsReceipts.Contains(navigationScope));
                if (afterAction == ReminderOpenReceiptAction.PresentNavigation)
                {
                    PresentReminderNavigation(request);
                    return;
                }
                if (afterAction == ReminderOpenReceiptAction.CompleteHandled)
                {
                    reminders.CompleteReminderOpen(request.StableTokenHash);
                }
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "reminder_open_receipt");
                // Preserve the pending Platform request; a later Ready/idle transition retries it.
            }
            finally
            {
                _reminderOpenInFlight = false;
            }
        }

        private void PresentReminderNavigation(ReminderOpenRequest request)
        {
            if (request == null || !string.IsNullOrWhiteSpace(_externalRouteReminderToken)) return;
            _externalRoute = ReminderDestinationRoute(request.Intent.Destination);
            _externalRouteReminderToken = request.StableTokenHash;
            Changed?.Invoke();
        }

        private async void ConfirmReminderNavigation(string stableTokenHash)
        {
            GameApplicationStore store = _store;
            if (_reminderNavigationReceiptInFlight || store == null ||
                _status != ShellRuntimeStatus.Ready || store.IsBusy ||
                string.IsNullOrWhiteSpace(stableTokenHash)) return;

            string navigationScope;
            try
            {
                navigationScope = AnalyticsReceiptRules.Scope(
                    ReminderOpenReceiptPolicy.NavigationReceiptEventId,
                    stableTokenHash);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "reminder_navigation_scope");
                return;
            }

            _reminderNavigationReceiptInFlight = true;
            bool confirmed = false;
            try
            {
                confirmed = await EnsureDurableReceiptAsync(
                    navigationScope,
                    AnalyticsReceiptRetention.Scoped,
                    CancellationToken.None);
                if (ReminderOpenReceiptPolicy.CanCompletePlatformRequest(confirmed))
                    AndroidReminderService.Instance?.CompleteReminderOpen(stableTokenHash);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "reminder_navigation_receipt");
            }
            finally
            {
                _reminderNavigationReceiptInFlight = false;
                if (confirmed) DrainPendingReminderOpen();
            }
        }

        private async Task<bool> EnsureDurableReceiptAsync(
            string scope,
            AnalyticsReceiptRetention retention,
            CancellationToken cancellationToken)
        {
            GameApplicationStore store = _store;
            if (store == null || string.IsNullOrWhiteSpace(scope)) return false;
            if (!_analyticsReceiptsInFlight.Add(scope))
                return store.Current.AnalyticsReceipts.Contains(scope);
            try
            {
                for (var attempt = 0; attempt < 2; attempt++)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    GameSaveAggregate current = store.Current;
                    if (current.AnalyticsReceipts.Contains(scope)) return true;
                    DispatchResult<GameSaveAggregate> result = await store.DispatchAsync(
                        new CommandEnvelope<GameCommand>(
                            "analytics:" + scope,
                            current.Revision,
                            new MarkAnalyticsReceiptCommand(scope, DateTimeOffset.UtcNow, retention)),
                        cancellationToken);
                    if (result.Status == DispatchStatus.Applied ||
                        result.Status == DispatchStatus.AlreadyApplied ||
                        result.Status == DispatchStatus.DomainRejected &&
                        string.Equals(result.ErrorCode, "analytics.already_marked", StringComparison.Ordinal))
                    {
                        return true;
                    }
                    if (result.Status != DispatchStatus.StaleRevision) return false;
                }
            }
            catch (OperationCanceledException)
            {
                return false;
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "durable_receipt");
            }
            finally
            {
                _analyticsReceiptsInFlight.Remove(scope);
            }
            return false;
        }

        private async Task EmitPhaseTransitionAnalyticsAsync(
            GameSaveAggregate before,
            GameSaveAggregate after,
            CancellationToken cancellationToken)
        {
            if (!PhaseTransitionAnalyticsPolicy.IsEntered(before, after)) return;
            HighSchoolCareerReadModel career = after.HighSchool;
            await EmitDurableOnceAsync(
                AnalyticsEvent.PhaseEntered,
                new Dictionary<string, object>(StringComparer.Ordinal)
                {
                    ["phase"] = ReturnPlanRules.PhaseWire(career.Phase),
                    ["chapter"] = career.ChapterNumber,
                    ["act_number"] = ActNumber(career.ChapterNumber),
                    ["life_number"] = career.LifeNumber,
                },
                AnalyticsReceiptRetention.Scoped,
                cancellationToken,
                CareerScope(after),
                ReturnPlanRules.PhaseWire(career.Phase),
                career.ChapterNumber.ToString(),
                "transition-" + after.Revision);
        }

        private async void ObserveRouteAnalytics(ShellRoute route, GameSaveAggregate state)
        {
            if (state == null || _disposed) return;
            try
            {
                WeeklyProgramState weeklyProgram = state.Meta.Weekly.Program;
                if (route == ShellRoute.Weekly && weeklyProgram == null) return;
                bool routeExposed = !_lastAnalyticsRoute.HasValue || _lastAnalyticsRoute.Value != route;
                _lastAnalyticsRoute = route;
                string careerScope = CareerScope(state);
                if (routeExposed && route == ShellRoute.Weekly)
                {
                    SafeLog(
                        AnalyticsEvent.WeeklyProgramOpened,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["week_key"] = weeklyProgram.WeekKey,
                            ["source"] = "records",
                            ["completed_tasks"] = weeklyProgram.CompletedCount,
                        });
                }
                if (route == ShellRoute.Opening)
                {
                    ReturnPlanState welcome = WelcomeReturnPlan(state, DateTimeOffset.UtcNow);
                    if (welcome != null)
                    {
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.ReturnPlanShown,
                            ReturnPlanProperties(welcome, DateTimeOffset.UtcNow),
                            AnalyticsReceiptRetention.Scoped,
                            CancellationToken.None,
                            welcome.ReceiptId ?? careerScope,
                            welcome.SavedDayKey ?? "legacy");
                    }
                }
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "route_analytics");
            }
        }

        public async void OnContentVisible(ShellRoute route, string contentId, string instanceId)
        {
            GameSaveAggregate state = _store?.Current;
            if (state == null || _disposed || string.IsNullOrWhiteSpace(contentId) ||
                string.IsNullOrWhiteSpace(instanceId)) return;
            try
            {
                string careerScope = CareerScope(state);
                if (string.Equals(contentId, "hs-career-wind", StringComparison.Ordinal) &&
                    (route == ShellRoute.Prologue || route == ShellRoute.HighSchoolOverview) &&
                    state.HighSchool != null)
                {
                    Baseball.Core.HighSchool.CareerWind wind = Baseball.Core.HighSchool.CareerWind.For(
                        state.HighSchool.CareerId,
                        Baseball.Core.HighSchool.CareerRulesVersion.V2);
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.CareerWindSeen,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["wind_id"] = wind.Id,
                            ["rules_version"] = (int)wind.RulesVersion,
                        },
                        AnalyticsReceiptRetention.Scoped,
                        CancellationToken.None,
                        careerScope);
                    return;
                }

                if (string.Equals(contentId, "hs-player-heartline", StringComparison.Ordinal))
                {
                    PlayerHeartlineViewModel heartline =
                        PlayerHeartlinePresentationPolicy.Project(route, state.HighSchool);
                    if (heartline == null) return;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.PlayerHeartlineSeen,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["branch_id"] = heartline.BranchId,
                            ["life_number"] = state.HighSchool.LifeNumber,
                            ["phase"] = ReturnPlanRules.PhaseWire(state.HighSchool.Phase),
                        },
                        AnalyticsReceiptRetention.Scoped,
                        CancellationToken.None,
                        careerScope,
                        heartline.BranchId);
                    return;
                }

                if (string.Equals(contentId, "player-legacy-letter", StringComparison.Ordinal))
                {
                    if (route == ShellRoute.RunRecap)
                    {
                        LifeArchiveRecord recapRecord = LatestLifeRecord(state);
                        if (recapRecord == null) return;
                        await EmitDurableOnceAsync(
                            AnalyticsEvent.PlayerLegacySeen,
                            new Dictionary<string, object>(StringComparer.Ordinal)
                            {
                                ["source"] = "recap",
                                ["life_number"] = recapRecord.LifeNumber,
                                ["drafted"] = recapRecord.Drafted,
                                ["has_frozen_legacy"] = recapRecord.PlayerLegacy != null,
                            },
                            AnalyticsReceiptRetention.Scoped,
                            CancellationToken.None,
                            recapRecord.LifeId ?? "life-" + recapRecord.LifeNumber,
                            "recap");
                        return;
                    }
                    LifeArchiveRecord record =
                        StoreBaseballCareerReadModel.PreviousPlayerLegacyFor(route, state);
                    if (record == null) return;
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.PlayerLegacySeen,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["source"] = "next_life",
                            ["life_number"] = record.LifeNumber,
                            ["drafted"] = record.Drafted,
                            ["has_frozen_legacy"] = record.PlayerLegacy != null,
                        },
                        AnalyticsReceiptRetention.Scoped,
                        CancellationToken.None,
                        "next_life",
                        state.HighSchool?.CareerId ?? "career",
                        record.LifeId ?? "life-" + record.LifeNumber);
                    return;
                }

                if (string.Equals(contentId, "choice:legacy_signature", StringComparison.Ordinal) &&
                    route == ShellRoute.RunRecap &&
                    state.HighSchool?.LegacySelectionMode == LegacySelectionMode.SignatureLegacy &&
                    state.HighSchool.SignatureLegacyChoices.Count > 0)
                {
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.SignatureLegacyOptionsSeen,
                        SignatureOptionsProperties(state),
                        AnalyticsReceiptRetention.Scoped,
                        CancellationToken.None,
                        careerScope,
                        "signature-options");
                    return;
                }

                if (string.Equals(contentId, "reminder-opt-in", StringComparison.Ordinal) &&
                    _readModel.ShouldShowReminderNudge(route, state))
                {
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.ReminderOfferShown,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["source"] = "after_first_game",
                        },
                        AnalyticsReceiptRetention.Lifetime,
                        CancellationToken.None,
                        "install");
                    return;
                }

                const string archivePrefix = "archive-life-";
                if (route == ShellRoute.LifeArchive &&
                    contentId.StartsWith(archivePrefix, StringComparison.Ordinal))
                {
                    await EmitLifeArchiveVisibleAsync(contentId.Substring(archivePrefix.Length));
                }
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "content_visible_analytics");
            }
        }

        public async void OnLifeArchiveVisible(string lifeNumber)
        {
            try
            {
                await EmitLifeArchiveVisibleAsync(lifeNumber);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "archive_visible_analytics");
            }
        }

        private async Task EmitLifeArchiveVisibleAsync(string lifeNumber)
        {
            if (_store == null || _disposed ||
                !int.TryParse(lifeNumber, out int parsedLifeNumber)) return;
            LifeArchiveRecord record = _store.Current.Meta.LifeArchive.FirstOrDefault(value =>
                value != null && value.LifeNumber == parsedLifeNumber);
            if (record == null) return;
            await EmitDurableOnceAsync(
                AnalyticsEvent.PlayerLegacySeen,
                new Dictionary<string, object>(StringComparer.Ordinal)
                {
                    ["source"] = "archive",
                    ["life_number"] = record.LifeNumber,
                    ["drafted"] = record.Drafted,
                    ["has_frozen_legacy"] = record.PlayerLegacy != null,
                },
                AnalyticsReceiptRetention.Scoped,
                CancellationToken.None,
                record.LifeId ?? "life-" + record.LifeNumber,
                "archive");
        }

        private void OnSessionEndPrepared(SessionEndReturnReadModel value)
        {
            if (value == null || _disposed) return;
            var sessionProperties = new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["return_eligible"] = value.ReturnEligible,
                ["return_destination"] = value.ReturnDestination,
                ["return_reason"] = value.ReturnReason,
                ["plan_receipt"] = value.PlanReceipt,
                ["experiment_id"] = value.ExperimentId,
                ["variant"] = value.Variant,
                ["development_rules_version"] = value.DevelopmentRulesVersion,
                ["minutes"] = value.Minutes,
                ["life_number"] = value.LifeNumber,
                ["games"] = value.Games,
                ["important_games_total"] = value.ImportantGamesTotal,
                ["phase"] = value.Phase,
                ["act_number"] = value.ActNumber,
                ["lives_finished"] = value.LivesFinished,
            };
            if (value.ShouldEmitReturnEligible)
            {
                var eligibleProperties = new Dictionary<string, object>(StringComparer.Ordinal)
                {
                    ["destination"] = value.ReturnDestination,
                    ["reason"] = value.ReturnReason,
                    ["plan_receipt"] = value.PlanReceipt,
                    ["experiment_id"] = value.ExperimentId,
                    ["variant"] = value.Variant,
                    ["saved_day_key"] = value.SavedDayKey,
                    ["return_day_key"] = value.ReturnDayKey,
                    ["day_gap"] = value.DayGap,
                    ["development_rules_version"] = value.DevelopmentRulesVersion,
                };
                SafeLog(AnalyticsEvent.ReturnPlanEligible, eligibleProperties);
            }
            SafeLog(AnalyticsEvent.SessionEnded, sessionProperties);
        }

        private async void ObserveReturnPlanOpen(string launchType)
        {
            GameApplicationStore store = _store;
            if (store == null || _disposed) return;
            try
            {
                ReturnPlanAnalyticsReadModel analytics = await RuntimeReturnPlanAnalytics
                    .ReserveNextDayOpenAsync(store, launchType, DateTimeOffset.UtcNow, CancellationToken.None);
                if (analytics == null) return;
                IReadOnlyDictionary<string, object> properties = ReturnPlanProperties(analytics);
                SafeLog(AnalyticsEvent.ReturnPlanNextDayOpen, properties);
                if (string.Equals(launchType, "cold", StringComparison.Ordinal))
                {
                    await EmitDurableOnceAsync(
                        AnalyticsEvent.ReturnPlanColdStart,
                        properties,
                        AnalyticsReceiptRetention.Scoped,
                        CancellationToken.None,
                        analytics.ExperimentId,
                        analytics.PlanReceipt,
                        analytics.ReturnDayKey);
                }
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "return_plan_open_analytics");
            }
        }

        private static ReturnPlanState WelcomeReturnPlan(GameSaveAggregate state, DateTimeOffset now)
            => ReturnPlanPresentationPolicy.Welcome(state, now);

        private static IReadOnlyDictionary<string, object> ReturnPlanProperties(
            ReturnPlanState plan,
            DateTimeOffset now)
        {
            ReturnPlanAnalyticsReadModel value = ReturnPlanRules.Analytics(plan, now);
            return value == null
                ? new Dictionary<string, object>(StringComparer.Ordinal)
                {
                    ["destination"] = "unknown",
                    ["reason"] = "unknown",
                    ["plan_receipt"] = "legacy",
                    ["experiment_id"] = "legacy",
                    ["variant"] = "legacy",
                    ["saved_day_key"] = "legacy",
                    ["return_day_key"] = SeoulGameCalendar.DayKey(now),
                    ["day_gap"] = -1,
                    ["development_rules_version"] = 0,
                }
                : ReturnPlanProperties(value);
        }

        private static IReadOnlyDictionary<string, object> ReturnPlanProperties(
            ReturnPlanAnalyticsReadModel value)
        {
            var properties = new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["destination"] = value.Destination,
                ["reason"] = value.Reason,
                ["plan_receipt"] = value.PlanReceipt,
                ["experiment_id"] = value.ExperimentId,
                ["variant"] = value.Variant,
                ["saved_day_key"] = value.SavedDayKey,
                ["return_day_key"] = value.ReturnDayKey,
                ["day_gap"] = value.DayGap,
                ["development_rules_version"] = value.DevelopmentRulesVersion,
            };
            if (!string.IsNullOrWhiteSpace(value.LaunchType))
                properties["launch_type"] = value.LaunchType;
            return properties;
        }

        private static string CareerScope(GameSaveAggregate state)
        {
            return state?.Pro?.ProCareerId ?? state?.HighSchool?.CareerId ??
                "life-" + Math.Max(1, state?.Meta?.LifeNumber ?? 1);
        }

        private static string RatioBand(int? ratioPermille)
        {
            int value = ratioPermille ?? 0;
            return value >= 1000 ? "complete" : value >= 500 ? "half_plus" : "under_half";
        }
    }
}
