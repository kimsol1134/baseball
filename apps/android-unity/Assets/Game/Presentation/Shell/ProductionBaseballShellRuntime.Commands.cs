using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Core.Catalogs;
using Baseball.Platform.Analytics;
using Baseball.Platform.Configuration;
using Baseball.Platform.Crash;
using Baseball.Platform.Haptics;
using Baseball.Platform.Identity;
using Baseball.Platform.Notifications;
using Baseball.Platform.Review;
using Baseball.Platform.Share;
using Baseball.Presentation.Pitch;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    public sealed partial class ProductionBaseballShellRuntime
    {
        public async Task<ShellActionResult> ExecuteAsync(
            ShellRoute route,
            ScreenActionViewModel action,
            CancellationToken cancellationToken)
        {
            if (action == null) throw new ArgumentNullException(nameof(action));
            if (!action.IsEnabled)
            {
                return ShellActionResult.Failure(
                    string.IsNullOrWhiteSpace(action.DisabledReason)
                        ? action.Hint
                        : action.DisabledReason);
            }
            if (action.Id == "runtime_retry")
            {
                return await RetryStartupAsync(cancellationToken);
            }
            if (action.Id.StartsWith("navigate_", StringComparison.Ordinal))
            {
                return ShellActionResult.Success(action.Target);
            }
            if (_status != ShellRuntimeStatus.Ready || _store == null)
                return ShellActionResult.Failure("저장 데이터를 불러온 뒤 다시 시도해 주세요.");
            if (_store.IsBusy) return ShellActionResult.Failure("다른 저장 작업을 처리하고 있습니다.");

            if (action.Id == "share_life_card") return await ShareLifeCardAsync(null, cancellationToken);
            if (action.Id == "share_career_code") return ShareCareerCode(cancellationToken);
            if (action.Id == "reset_save") return await ResetAsync(cancellationToken);
            if (action.Id == "enable_reminder_nudge")
            {
                AndroidReminderService reminders = AndroidReminderService.Instance;
                if (reminders?.IsInstallBound != true)
                    return ShellActionResult.Failure(NotificationsUnavailableReason);
                reminders.RequestEnabled(true, "after_first_game");
                return ShellActionResult.Success(null, "Android 알림 권한 결과를 확인하고 있습니다.");
            }
            if (action.Id == "dismiss_reminder_nudge")
            {
                AndroidReminderService reminders = AndroidReminderService.Instance;
                if (reminders?.IsInstallBound != true)
                    return ShellActionResult.Failure(NotificationsUnavailableReason);
                reminders.DeclineOptIn();
                return ShellActionResult.Success(null, "복귀 알림 권유를 닫았습니다.");
            }

            GameSaveAggregate before = _store.Current;
            GameCommand command = CreateCommand(action.Id, before);
            if (command == null)
            {
                if (action.Id == "start_high_school" &&
                    !SetupSeedInputPolicy.IsValid(_seedInput))
                    return ShellActionResult.Failure(SetupSeedInputPolicy.InvalidMessage);
                return ShellActionResult.Failure("아직 실제 게임 명령과 연결되지 않은 기능입니다.");
            }
            string commandId = "ui:" + action.Id + ":" + before.Revision + ":" + (++_commandSequence);
            var envelope = new CommandEnvelope<GameCommand>(commandId, before.Revision, command);
            DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(envelope, cancellationToken);
            if (!result.IsSuccess)
            {
                return ShellActionResult.Failure(KoreanFailure(result));
            }

            QueueTrainingCelebration(action.Id, before, result.State);
            TryRequestReviewForAction(action.Id, before, result.State);
            await LogSuccessfulActionAsync(
                action.Id,
                command,
                before,
                result.State,
                cancellationToken);
            return ShellActionResult.Success(DestinationAfterCommand(action), "저장했습니다.");
        }

        private static void TryRequestReviewForAction(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            try
            {
                ReviewPromptReason? reason = ReviewMomentPolicy.ReasonAfter(actionId, before, after);
                if (reason.HasValue) TryRequestReview(reason.Value);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "review_prompt");
            }
        }

        private static void TryRequestReview(ReviewPromptReason reason)
        {
            try
            {
                PlayReviewPrompt.TryRequest(reason, DateTimeOffset.UtcNow);
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "review_prompt");
            }
        }
    }
}
