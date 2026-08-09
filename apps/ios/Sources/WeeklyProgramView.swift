import SwiftUI

/// 본편의 오늘의 이닝 입구 바로 아래에 붙는 한 줄. 새 탭을 만들지 않고 이번 주의
/// 방향만 보여 주며, 자세한 기록과 보상은 기록 탭에서 다룬다.
struct WeeklyProgramSummaryRow: View {
    let store: WeeklyProgramStore

    @ViewBuilder var body: some View {
        if let program = store.program {
            HStack(spacing: 8) {
                Image(systemName: program.isRewardReady ? "seal.fill" : "book.closed.fill")
                    .foregroundStyle(program.isRewardReady ? BaseballTheme.milestone : BaseballTheme.information)
                Text(store.summaryLine)
                    .font(.footnote.weight(.bold))
                Spacer(minLength: 0)
                Text(program.claimed ? "도장 완료" : program.isRewardReady ? "보상 준비" : "3개 중 2개")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(store.summaryLine), \(program.claimed ? "주간 도장 받음" : program.isRewardReady ? "보상 받을 수 있음" : "세 목표 중 두 목표를 달성하면 완료")")
            .accessibilityIdentifier("weekly.summary")
        }
    }
}

/// 기록 탭 안의 주간 야구 노트 상세와 도장 보관함.
struct WeeklyProgramView: View {
    let store: WeeklyProgramStore
    let highSchool: HighSchoolCareerStore
    var onOpenDailyInning: (() -> Void)? = nil

    static func openedProperties(program: WeeklyProgram, source: String = "records") -> [String: Any] {
        [
            "week_key": program.weekKey,
            "source": source,
            "completed_tasks": program.completedCount,
        ]
    }

    static func showsDailyLaunch(program: WeeklyProgram) -> Bool {
        program.tasks.contains { $0.kind == .dailyInningCompleted && !$0.isCompleted }
    }

    var body: some View {
        Group {
            if let program = store.program {
                BaseballCard(title: "이번 주 야구 노트 · \(program.completedCount)/\(program.tasks.count)", tone: program.isRewardReady ? .milestone : .raised) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("세 가지 중 두 가지만 마치면 됩니다. 놓친 주와 남은 목표에는 벌점이 없습니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(program.tasks) { task in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.isCompleted ? BaseballTheme.positive : BaseballTheme.textTertiary)
                                    Text(task.kind.title)
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
                            .accessibilityLabel("\(task.kind.title), \(task.boundedProgress)/\(task.target)\(task.isCompleted ? ", 완료" : "")")
                        }

                        if let next = program.nextRewardTask {
                            Label("도장까지 하나 · \(next.kind.nextAction)", systemImage: "arrow.forward.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BaseballTheme.information)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let remaining = program.soleRemainingTask, program.isRewardReady {
                            Label("완주까지 하나 · \(remaining.kind.nextAction)", systemImage: "star.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BaseballTheme.milestone)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if Self.showsDailyLaunch(program: program), let onOpenDailyInning {
                            Button(action: onOpenDailyInning) {
                                Label("오늘의 이닝 던지기", systemImage: "figure.baseball")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint("오늘의 이닝을 열어 주간 목표에 도전합니다.")
                            .accessibilityIdentifier("weekly.openDailyInning")
                        }

                        if let reward = store.claimableReward {
                            PrimaryPill(
                                title: "주간 기록 도장 받기 · 야구혼 +\(reward.soulPoints)",
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
                            Label(
                                program.isPerfect ? "주간 기록 도장 · 완주" : "주간 기록 도장 · 완료",
                                systemImage: "seal.fill"
                            )
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
                BaseballCard(title: "주간 도장 보관함") {
                    VStack(spacing: 8) {
                        ForEach(store.stamps.prefix(12)) { stamp in
                            HStack(spacing: 8) {
                                Image(systemName: stamp.perfect ? "seal.fill" : "seal")
                                    .foregroundStyle(stamp.perfect ? BaseballTheme.milestone : BaseballTheme.information)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stamp.weekKey)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    Text(stamp.perfect ? "3/3 완주" : "\(stamp.completedTaskCount)/3 완료")
                                        .font(.caption)
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                Spacer(minLength: 0)
                                if stamp.perfect {
                                    Text("완주")
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
