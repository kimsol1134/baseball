import SwiftUI

/// 본편에 붙는 한 줄 요약. 자세한 기록과 보상은 기록 탭에서 다룬다.
struct WeeklyProgramSummaryRow: View {
    let store: WeeklyProgramStore

    @Environment(\.gameCopyResolver) private var copyResolver

    @ViewBuilder var body: some View {
        if let program = store.program {
            let summary = copyResolver.resolve(
                .weeklyProgramTitle,
                arguments: [.integer(program.completedCount), .integer(program.tasks.count)]
            )
            let status = copyResolver.resolve(
                program.claimed ? .weeklyClaimed : program.isRewardReady ? .weeklyRewardReady : .weeklyProgramProgress
            )
            let accessibilityKey: MetaUICopyKey = program.claimed
                ? .weeklySummaryAccessibilityClaimed
                : program.isRewardReady
                    ? .weeklySummaryAccessibilityReady
                    : .weeklySummaryAccessibilityProgress
            HStack(spacing: 8) {
                Image(systemName: program.isRewardReady ? "seal.fill" : "book.closed.fill")
                    .foregroundStyle(program.isRewardReady ? BaseballTheme.milestone : BaseballTheme.information)
                Text(verbatim: summary)
                    .font(.footnote.weight(.bold))
                Spacer(minLength: 0)
                Text(verbatim: status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                copyResolver.resolve(accessibilityKey, arguments: [.userText(summary)])
            )
            .accessibilityIdentifier("weekly.summary")
        }
    }
}

/// 기록 탭 안의 주간 야구 노트 상세와 도장 보관함.
struct WeeklyProgramView: View {
    let store: WeeklyProgramStore
    let highSchool: HighSchoolCareerStore

    @Environment(\.gameCopyResolver) private var copyResolver

    static func openedProperties(program: WeeklyProgram, source: String = "records") -> [String: Any] {
        [
            "week_key": program.weekKey,
            "source": source,
            "completed_tasks": program.completedCount,
        ]
    }

    var body: some View {
        Group {
            if let program = store.program {
                BaseballCard(
                    title: copyResolver.resolve(
                        .weeklyProgramTitle,
                        arguments: [.integer(program.completedCount), .integer(program.tasks.count)]
                    ),
                    tone: program.isRewardReady ? .milestone : .raised
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(verbatim: copyResolver.resolve(.weeklyInstructions))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(program.tasks) { task in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompleted ? BaseballTheme.positive : BaseballTheme.textTertiary)
                                    Text(verbatim: MetaPresentation.weeklyTaskTitle(task.kind, resolver: copyResolver))
                                        .font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 0)
                                    Text("\(task.boundedProgress)/\(task.target)")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                ProgressView(value: Double(task.boundedProgress), total: Double(task.target))
                                    .tint(task.isCompleted ? BaseballTheme.positive : BaseballTheme.information)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(
                                copyResolver.resolve(
                                    task.isCompleted ? .weeklyTaskAccessibilityComplete : .weeklyTaskAccessibility,
                                    arguments: [
                                        .userText(MetaPresentation.weeklyTaskTitle(task.kind, resolver: copyResolver)),
                                        .integer(task.boundedProgress),
                                        .integer(task.target),
                                    ]
                                )
                            )
                        }

                        if let next = program.nextRewardTask {
                            Label {
                                Text(
                                    verbatim: copyResolver.resolve(
                                        .weeklyOneForStamp,
                                        arguments: [
                                            .userText(MetaPresentation.weeklyTaskNextAction(next.kind, resolver: copyResolver)),
                                        ]
                                    )
                                )
                            } icon: {
                                Image(systemName: "arrow.forward.circle")
                            }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BaseballTheme.information)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let remaining = program.soleRemainingTask, program.isRewardReady {
                            Label {
                                Text(
                                    verbatim: copyResolver.resolve(
                                        .weeklyOneForPerfect,
                                        arguments: [
                                            .userText(MetaPresentation.weeklyTaskNextAction(remaining.kind, resolver: copyResolver)),
                                        ]
                                    )
                                )
                            } icon: {
                                Image(systemName: "star.circle")
                            }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BaseballTheme.milestone)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let reward = store.claimableReward {
                            PrimaryPill(
                                title: copyResolver.resolve(
                                    .weeklyClaimAction,
                                    arguments: [.integer(reward.soulPoints)]
                                ),
                                identifier: "weekly.claim"
                            ) {
                                guard highSchool.acceptExternalSoulReward(
                                    id: reward.id,
                                    soulPoints: reward.soulPoints
                                ) else { return }
                                guard store.markClaimed() else { return }
                                Haptics.shared.outcome(success: true)
                            }
                        } else if program.claimed {
                            Label {
                                Text(
                                    verbatim: copyResolver.resolve(
                                        program.isPerfect ? .weeklyStampPerfect : .weeklyStampComplete
                                    )
                                )
                            } icon: {
                                Image(systemName: "seal.fill")
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                        }
                    }
                }
                .accessibilityIdentifier("weekly.program")
                .onAppear {
                    GameAnalytics.log(.weeklyProgramOpened, Self.openedProperties(program: program))
                }
            }

            if !store.stamps.isEmpty {
                BaseballCard(title: copyResolver.resolve(.weeklyVault)) {
                    VStack(spacing: 8) {
                        ForEach(store.stamps.prefix(12)) { stamp in
                            HStack(spacing: 8) {
                                Image(systemName: stamp.perfect ? "seal.fill" : "seal")
                                    .foregroundStyle(stamp.perfect ? BaseballTheme.milestone : BaseballTheme.information)
                                VStack(alignment: .leading, spacing: 1) {
                                    // localization-safe: stable-id
                                    Text(stamp.weekKey)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    Text(
                                        verbatim: stamp.perfect
                                            ? copyResolver.resolve(.weeklyStampLinePerfect)
                                            : copyResolver.resolve(
                                                .weeklyStampLine,
                                                arguments: [.integer(stamp.completedTaskCount)]
                                            )
                                    )
                                        .font(.caption)
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                Spacer(minLength: 0)
                                if stamp.perfect {
                                    Text(verbatim: copyResolver.resolve(.weeklyPerfectBadge))
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(BaseballTheme.milestone)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .overlay(Capsule().stroke(BaseballTheme.milestone, lineWidth: 1))
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityIdentifier("weekly.stamps")
            }
        }
    }
}
