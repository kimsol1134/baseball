import SwiftUI
import SimulationCore
import BaseballIOSDomain

// MARK: - 훈련 결과

struct HighSchoolArmHealthResultCard: View {
    let receipt: HighSchoolArmHealthReceipt
    @Environment(\.gameCopyResolver) private var copyResolver

    private var title: String {
        HighSchoolPresentation.localizedArmHealth(receipt.healthAfter, resolver: copyResolver).label
    }

    private var cause: String {
        switch receipt.cause {
        case .outingLoad:
            copyResolver.resolve(AppCopyKey.armHealthResultOuting, arguments: [
                .integer(receipt.pitches),
                .integer(receipt.fatigueBefore),
                .integer(receipt.riskAfter - receipt.riskBefore),
            ])
        case .pushThrough:
            copyResolver.resolve(AppCopyKey.armHealthResultPushThrough)
        case .rehab:
            copyResolver.resolve(AppCopyKey.armHealthResultRehab, arguments: [
                .integer(max(0, receipt.riskBefore - receipt.riskAfter)),
            ])
        }
    }

    private var nextAction: String {
        if receipt.recoveryRemaining > 0 {
            return copyResolver.resolve(AppCopyKey.armHealthResultNextRecovery, arguments: [
                .integer(receipt.recoveryRemaining),
            ])
        }
        return copyResolver.resolve(AppCopyKey.armHealthResultNextManage)
    }

    var body: some View {
        BaseballCard(title: title, tone: receipt.healthAfter == .warning ? .negative : .warning) {
            VStack(alignment: .leading, spacing: 6) {
                // 결과 한 줄이 먼저, 다음 행동이 그 아래. 둘 다 읽는 문장이라 본문 크기다.
                Text(verbatim: cause).proseLeadStyle()
                Text(verbatim: nextAction).detailStyle(BaseballTheme.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hs.armHealth.result")
    }
}

/// 방금 끝난 훈련이 무엇을 남겼는지, 누른 자리에서 그대로 읽히는 카드.
///
/// 목록의 **주 행동 바로 위**에 선다(`content` 참고). 화면 아래 고정 패널로도 만들어 봤지만
/// 그 방식은 화면 하단을 통째로 점유해 아래 카드의 조작을 가렸다 — UI 스모크가 훈련
/// 버튼을 못 찾고 회차가 그 자리에서 멈췄다. 흐름 안의 카드면 결과와 다음 행동이 세로로
/// 이어져, 스크롤 없이 읽고 그대로 다음 훈련을 누른다.
///
/// 첫 도착 화면에서 성장의 전후를 강조하고 다음 행동 뒤에는 `compact`로 접는다.
/// 닫기 버튼은 어느 쪽이든 유지한다.
///
/// 성장이 0인 훈련도 여기 뜬다. 안 오른 것도 결과이고, 아무것도 안 뜨는 것이 가장 나쁘다.
struct TrainingResultPanel: View {
    let receipt: TrainingReceipt
    var compact: Bool = false
    let onDismiss: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var showsDetails = false

    private var commandMilestone: AbilityGain? {
        receipt.gains.first { $0.ability == .command && PitchReleaseWindow.crossesMilestone(before: $0.before, after: $0.after) }
    }
    private var primary: AbilityGain? {
        commandMilestone ?? receipt.gains.max { ($0.after - $0.before) < ($1.after - $1.before) }
    }
    private var grew: Bool { receipt.gains.contains { $0.after > $0.before } }
    private var notable: Bool { commandMilestone != nil || receipt.bloom != nil || receipt.jackpot }
    private var accent: Color { notable ? BaseballTheme.milestone : grew ? BaseballTheme.action : BaseballTheme.textSecondary }
    private var headline: String {
        if commandMilestone != nil { return copyResolver.resolve(.localizable("loop.growth.milestone")) }
        guard let gain = primary else { return HighSchoolPresentation.localizedTrainingResultHeadline(receipt, resolver: copyResolver) }
        return copyResolver.resolve(.localizable("loop.growth.row"), arguments: [
            .userText(copyResolver.resolve(gain.ability.displayCopyToken)),
            .integer(AbilityDisplayScale.displayRating(gain.before)), .integer(AbilityDisplayScale.displayRating(gain.after))])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: notable ? "sparkles" : grew ? "arrow.up.right" : "checkmark")
                    .foregroundStyle(accent).accessibilityHidden(true)
                Text(verbatim: headline)
                    .font(notable && !compact ? .title3.weight(.bold) : .headline)
                    .foregroundStyle(accent)
                    .accessibilityIdentifier("hs.training.result.headline")
                Spacer(minLength: 0)
                Button(copyResolver.resolve(AppCopyKey.trainingResultDismiss), action: onDismiss)
                    .font(BaseballType.detail).frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.training.result.dismiss")
            }
            if !compact, let commandMilestone {
                ControlWindowPreview(command: commandMilestone.after, beforeCommand: commandMilestone.before,
                    showsLegend: false, titleKey: "loop.growth.base-window")
            }
            if !compact, let bloom = receipt.bloom {
                Text(HighSchoolPresentation.localizedTrainingResultBloom(bloom, resolver: copyResolver)).detailStyle()
            } else if receipt.jackpot {
                Text(HighSchoolPresentation.localizedTrainingResultTitle(receipt, resolver: copyResolver))
                    .font(BaseballType.annotation).foregroundStyle(BaseballTheme.milestone)
            }
            // Permanent growth and the current cost remain separate even after changing phase.
            Text(verbatim: GrowthConditionCopy.line(fatigue: receipt.fatigueAfter, change: receipt.fatigueChange, resolver: copyResolver))
                .font(BaseballType.detail).foregroundStyle(receipt.fatigueChange > 0 ? BaseballTheme.warning : BaseballTheme.textSecondary)
                .accessibilityIdentifier("hs.training.result.condition")
            if let learning = receipt.pitchLearning {
                GameCopyText(AppCopyKey.trainingResultPitchLearning, arguments: [
                    .userText(PitchCopy.localized(learning.pitchType, resolver: copyResolver)),
                    .integer(learning.practiceCreditsAfter - learning.practiceCreditsBefore),
                    .integer(learning.practiceCreditsAfter), .integer(CareerDisplayRules.pitchLearningPracticeCap)])
                    .font(BaseballType.annotation).foregroundStyle(learning.justCompleted || learning.justUnlockedForGames ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    .accessibilityIdentifier("hs.training.result.pitchLearning")
            }
            Button(copyResolver.resolve(.localizable("loop.growth.details"))) { showsDetails.toggle() }
                .font(BaseballType.annotation).frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.training.result.details")
            if showsDetails {
                ForEach(receipt.gains) { gain in
                    Text(verbatim: HighSchoolPresentation.localizedTrainingGainRow(gain, resolver: copyResolver)).detailStyle()
                }
                if commandMilestone == nil, let gain = receipt.gains.first(where: { $0.ability == .command }) {
                    ControlWindowPreview(command: gain.after, beforeCommand: gain.before, titleKey: "loop.growth.base-window")
                }
                Text(verbatim: copyResolver.resolve(.localizable("loop.condition.explanation"))).detailStyle()
                Text(HighSchoolPresentation.localizedTrainingResultDetail(receipt, resolver: copyResolver)).detailStyle()
            }
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notable ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surface,
            in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hs.training.result")
        .onChange(of: receipt) { _, _ in showsDetails = false }
        .onAppear { if notable && !compact { GameAudio.shared.play(.milestone) } }
    }
}

/// Explicitly describes current condition; the growth comparison itself uses a fixed condition.
enum GrowthConditionCopy {
    static func line(fatigue: Int, change: Int, resolver: GameCopyResolver) -> String {
        let key = change > 0 ? "loop.condition.up" : change < 0 ? "loop.condition.down" : "loop.condition.current"
        return resolver.resolve(.localizable(key), arguments: change == 0 ? [.integer(fatigue)] : [.integer(fatigue), .integer(change)])
    }
}

/// 복귀 알림 권유. 정직하게 무엇을 언제 보내는지 적고, 거절도 한 탭이다.
struct ReminderNudgeCard: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let title = copyResolver.resolve(AppCopyKey.reminderNudgeTitle)
        let body = copyResolver.resolve(AppCopyKey.reminderNudgeBody)
        let enable = copyResolver.resolve(AppCopyKey.reminderNudgeEnable)
        let decline = copyResolver.resolve(AppCopyKey.reminderNudgeDecline)
        let accessibility = copyResolver.resolve(
            AppCopyKey.reminderNudgeAccessibility,
            arguments: [
                .userText(title), .userText(body),
                .userText(enable), .userText(decline),
            ]
        )
        BaseballCard(title: title, tone: .raised) {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: body)
                    .detailStyle()
                HStack(spacing: 10) {
                    PrimaryPill(title: enable, identifier: "hs.reminder.enable", action: onEnable)
                    Button { onDismiss() } label: {
                        Text(verbatim: decline)
                    }
                        .font(BaseballType.detail.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .accessibilityIdentifier("hs.reminder.decline")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: accessibility))
        .onAppear {
            CareerTelemetry.logOnce(.reminderOfferShown, ["source": "after_first_game"])
        }
    }
}
