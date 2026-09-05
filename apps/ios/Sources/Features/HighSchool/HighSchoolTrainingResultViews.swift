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

    private var grew: Bool { receipt.gains.contains { $0.after > $0.before } }
    private var accent: Color {
        if receipt.bloom != nil || receipt.jackpot { return BaseballTheme.milestone }
        return grew ? BaseballTheme.action : BaseballTheme.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: receipt.bloom != nil ? "sparkles"
                      : grew ? "arrow.up.right.circle.fill" : "checkmark.circle")
                    .foregroundStyle(accent)
                Text(HighSchoolPresentation.localizedTrainingResultTitle(receipt, resolver: copyResolver))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(accent)
                if receipt.opportunityHit {
                    Text(copyResolver.resolve(AppCopyKey.trainingResultOpportunityBadge))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(BaseballTheme.milestone)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(BaseballTheme.milestone.opacity(0.22), in: Capsule())
                }
                Spacer(minLength: 0)
                Button(copyResolver.resolve(AppCopyKey.trainingResultDismiss), action: onDismiss)
                    .font(BaseballType.detail.weight(.bold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.training.result.dismiss")
            }

            // 오른 값이 주인공이다. 큰 글자 한 줄이면 스치듯 봐도 읽힌다.
            Text(HighSchoolPresentation.localizedTrainingResultHeadline(receipt, resolver: copyResolver))
                .font(.title3.weight(.heavy))
                .foregroundStyle(grew ? accent : BaseballTheme.textSecondary)
                .accessibilityIdentifier("hs.training.result.headline")

            if !compact {
                let risen = receipt.gains.filter { $0.after > $0.before }
                if risen.isEmpty {
                    StatTile(
                        label: copyResolver.resolve(AppCopyKey.trainingResultNoGain),
                        value: "0",
                        caption: copyResolver.resolve(AppCopyKey.trainingResultNoGain),
                        tone: BaseballTheme.textTertiary
                    )
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(risen) { gain in
                            if gain.ability == .command {
                                Text(verbatim: HighSchoolPresentation.localizedTrainingGainRow(gain, resolver: copyResolver))
                                    .font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(accent)
                            } else {
                            StatTile(
                                label: copyResolver.resolve(gain.ability.displayCopyToken),
                                value: "\(AbilityDisplayScale.displayRating(gain.after))",
                                previousValue: "\(AbilityDisplayScale.displayRating(gain.before))",
                                caption: nil,
                                tone: accent,
                                animatesChange: true
                            )
                            }
                        }
                    }
                }

                if let bloom = receipt.bloom {
                    Text(HighSchoolPresentation.localizedTrainingResultBloom(bloom, resolver: copyResolver))
                        .proseLeadStyle()
                }
            }

            if let commandGain = receipt.gains.first(where: { $0.ability == .command }), commandGain.after != commandGain.before {
                ControlWindowPreview(command: commandGain.after, beforeCommand: commandGain.before, compact: compact)
            }
            if let learning = receipt.pitchLearning {
                GameCopyText(
                    AppCopyKey.trainingResultPitchLearning,
                    arguments: [
                        .userText(PitchCopy.localized(learning.pitchType, resolver: copyResolver)),
                        .integer(learning.practiceCreditsAfter - learning.practiceCreditsBefore),
                        .integer(learning.practiceCreditsAfter),
                        .integer(CareerDisplayRules.pitchLearningPracticeCap),
                    ]
                )
                .font(BaseballType.annotation.weight(.semibold).monospacedDigit())
                .foregroundStyle(
                    learning.justCompleted || learning.justUnlockedForGames
                        ? BaseballTheme.milestone : BaseballTheme.information
                )
                .accessibilityIdentifier("hs.training.result.pitchLearning")
            }

            if !compact {
                if let primary = receipt.gains.filter({ $0.after > $0.before }).max(by: { ($0.after - $0.before) < ($1.after - $1.before) }) {
                    let key: String = switch primary.ability {
                    case .stuff: "mobile.polish.growth-stuff"
                    case .command: "mobile.polish.growth-command"
                    case .movement: "mobile.polish.growth-movement"
                    case .stamina: "mobile.polish.growth-stamina"
                    }
                    Text(verbatim: copyResolver.resolve(.localizable(key))).font(BaseballType.detail.weight(.semibold))
                }
                DisclosureGroup(copyResolver.resolve(.localizable("mobile.polish.training-details"))) {
                    Text(HighSchoolPresentation.localizedTrainingResultDetail(receipt, resolver: copyResolver)).detailStyle()
                }

                // 피로는 훈련의 가격이다. 결과와 같은 자리에서 보여야 다음 강도를 고를 수 있다.
                EffectChip(
                    text: HighSchoolPresentation.localizedTrainingFatigue(receipt, resolver: copyResolver),
                    tone: receipt.fatigueAfter >= 70 ? .cost : .neutral,
                    systemImage: "battery.50"
                )
            }
        }
        .padding(compact ? 10 : BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (receipt.bloom != nil || receipt.jackpot
             ? BaseballTheme.milestone.opacity(0.14)
             : grew ? BaseballTheme.actionSoft : BaseballTheme.surface),
            in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(accent, lineWidth: receipt.bloom != nil || receipt.jackpot ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hs.training.result")
        .onAppear {
            if receipt.bloom != nil || receipt.jackpot { GameAudio.shared.play(.milestone) }
        }
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
