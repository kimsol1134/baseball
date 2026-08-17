import SwiftUI
import SimulationCore

struct ResultBanner: View {
    let summary: String
    let cue: MobileCareerStore.FeedbackCue

    private var tone: BaseballCardTone {
        switch cue {
        case .setback: .negative
        case .growth: .milestone
        default: .positive
        }
    }

    private var symbol: String {
        switch cue {
        case .setback: "exclamationmark.triangle.fill"
        case .growth: "arrow.up.right.circle.fill"
        default: "checkmark.seal.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tone.accent).font(.footnote)
            // localization-safe: resolved-copy
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

struct CareerSummary: View {
    let career: MobileCareerStore
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        List {
            if let state = career.state {
                Section(copyResolver.resolve(.summaryPlayer)) {
                    LabeledContent(copyResolver.resolve(.summaryName), value: state.identity.name)
                    LabeledContent(
                        copyResolver.resolve(.summaryTeam),
                        value: ProCareerPresentation.teamName(state.team, resolver: copyResolver)
                    )
                    LabeledContent(copyResolver.resolve(.summaryLevel), value: copyResolver.resolve(state.level.displayCopyToken))
                    LabeledContent(copyResolver.resolve(.summaryRole), value: copyResolver.resolve(state.role.displayCopyToken))
                }
                Section(copyResolver.resolve(.summaryAbility)) {
                    AbilityGaugeView(label: copyResolver.resolve(.summaryStuff), value: state.pitcher.stuff)
                    AbilityGaugeView(label: copyResolver.resolve(.summaryCommand), value: state.pitcher.command)
                    AbilityGaugeView(label: copyResolver.resolve(.summaryMovement), value: state.pitcher.movement)
                    AbilityGaugeView(label: copyResolver.resolve(.summaryStamina), value: state.pitcher.stamina)
                }
                Section(copyResolver.resolve(.summaryMilestones)) {
                    ForEach(Array(state.milestones.suffix(6).reversed()), id: \.self) { milestone in
                        Label(
                            ProCareerPresentation.milestone(milestone, resolver: copyResolver),
                            systemImage: milestone == state.milestones.last ? "star.fill" : "circle.fill"
                        )
                            .foregroundStyle(milestone == state.milestones.last ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    }
                }
                if let decisions = state.decisionHistory, !decisions.isEmpty {
                    Section(copyResolver.resolve(.summaryDecisions)) {
                        ForEach(Array(decisions.suffix(7).reversed())) { decision in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ProCareerPresentation.decisionRecordTitle(decision, resolver: copyResolver))
                                    .font(.subheadline.weight(.semibold))
                                Text(copyResolver.resolve(
                                    .summaryDecisionLine,
                                    arguments: [
                                        .integer(decision.season),
                                        .integer(decision.week),
                                        .userText(ProCareerPresentation.combinedEffect(
                                            decision.effect,
                                            journeyEffect: decision.journeyEffect,
                                            resolver: copyResolver
                                        )),
                                    ]
                                ))
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BaseballTheme.canvas)
        .navigationTitle(copyResolver.resolve(.summaryNavigation))
    }
}

/// 시즌의 초반·중반·막바지에 멈추는 갈림길. 선택지는 효과와 비용을 코어가 계산한 숫자 그대로

struct ActionCard: View {
    let title: String
    let copy: String
    let button: String
    let identifier: String?
    let action: () -> Void

    init(
        title: String,
        copy: String,
        button: String,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.copy = copy
        self.button = button
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        BaseballCard(title: title, tone: .raised) {
            VStack(alignment: .leading, spacing: 12) {
                // localization-safe: resolved-copy
                Text(copy).font(.subheadline)
                PrimaryPill(title: button, identifier: identifier, action: action)
            }
        }
    }
}
