import SwiftUI
import SimulationCore

struct ProSeasonDecisionView: View {
    let career: MobileCareerStore
    let decision: ProSeasonDecision
    @State private var pendingChoice: ProSeasonDecisionChoice?
    @Environment(\.gameCopyResolver) private var copyResolver

    private var decisionTitle: String {
        ProCareerPresentation.decisionTitle(decision, resolver: copyResolver)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: copyResolver.resolve(
                    .decisionEyebrow,
                    arguments: [.integer(decision.season), .integer(decision.week)]
                ),
                title: decisionTitle,
                accent: BaseballTheme.milestone
            )

            Text(ProCareerPresentation.decisionDetail(decision, resolver: copyResolver))
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(decision.choices) { choice in
                Button { pendingChoice = choice } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(ProCareerPresentation.choiceTitle(choice, resolver: copyResolver))
                                .font(.headline)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(BaseballTheme.selection)
                        }
                        Text(ProCareerPresentation.choiceDetail(choice, resolver: copyResolver))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(ProCareerPresentation.combinedEffect(
                            choice.effect,
                            journeyEffect: choice.journeyEffect,
                            resolver: copyResolver
                        ), systemImage: "plusminus.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(
                            ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver),
                            systemImage: decision.type == .mediaOpportunity ? "bolt.fill" : "arrow.turn.down.right"
                        )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                    .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.accessibilityLabel(for: choice, resolver: copyResolver))
                .accessibilityHint(copyResolver.resolve(.decisionHint))
                .accessibilityIdentifier("pro.seasonDecision.choice.\(choice.id)")
            }

            Label(copyResolver.resolve(.decisionWarning), systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(BaseballTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.seasonDecision")
        .confirmationDialog(
            pendingChoice.map { ProCareerPresentation.choiceTitle($0, resolver: copyResolver) }
                ?? copyResolver.resolve(.decisionConfirmTitle),
            isPresented: Binding(
                get: { pendingChoice != nil },
                set: { if !$0 { pendingChoice = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(copyResolver.resolve(.decisionConfirmAction)) {
                guard let pendingChoice else { return }
                career.applySeasonDecision(decisionID: decision.id, choiceID: pendingChoice.id)
                self.pendingChoice = nil
            }
            .accessibilityIdentifier("pro.seasonDecision.confirm")
            Button(copyResolver.resolve(.decisionConfirmCancel), role: .cancel) { pendingChoice = nil }
        } message: {
            if let pendingChoice {
                Text(copyResolver.resolve(
                    .decisionConfirmMessage,
                    arguments: [
                        .userText(ProCareerPresentation.choiceDetail(pendingChoice, resolver: copyResolver)),
                        .userText(ProCareerPresentation.combinedEffect(
                            pendingChoice.effect,
                            journeyEffect: pendingChoice.journeyEffect,
                            resolver: copyResolver
                        )),
                        .userText(ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver)),
                    ]
                ))
            }
        }
    }

    static func accessibilityLabel(
        for choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
    ) -> String {
        resolver.resolve(
            ProUICopyKey.decisionAccessibility,
            arguments: [
                .userText(ProCareerPresentation.choiceTitle(choice, resolver: resolver)),
                .userText(ProCareerPresentation.choiceDetail(choice, resolver: resolver)),
                .userText(ProCareerPresentation.combinedEffect(
                    choice.effect,
                    journeyEffect: choice.journeyEffect,
                    resolver: resolver
                )),
                .userText(ProCareerPresentation.decisionTiming(for: choice, resolver: resolver)),
            ]
        )
    }
}

