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
    }
}
