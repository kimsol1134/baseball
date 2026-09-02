import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ProSeasonDecisionView: View {
    let career: MobileCareerStore
    let decision: ProSeasonDecision
    @State private var pendingChoice: ProSeasonDecisionChoice?
    /// 같은 유형의 결정을 한 번 본 뒤에는 서사를 접는다("한 번 본 글 접어두기" 리뷰).
    /// 선택지의 효과 요약과 확인 대화상자의 전체 설명은 접힘과 무관하게 항상 보인다.
    @State private var condensesNarrative = false
    @State private var narrativeExpanded = false
    @AppStorage(CopyDensity.storageKey) private var densityRaw = CopyDensity.automatic.rawValue
    @Environment(\.gameCopyResolver) private var copyResolver

    private var decisionTitle: String {
        ProCareerPresentation.decisionTitle(decision, resolver: copyResolver)
    }

    private var seenContentID: String { "pro.decision.\(decision.type.rawValue).v1" }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: .stadiumNight,
                eyebrow: ProDecisionCopy.eyebrow(
                    season: decision.season,
                    week: decision.week,
                    resolver: copyResolver,
                    weekly: decision.type.isWeeklyBinaryDecision
                ),
                title: decisionTitle,
                accent: BaseballTheme.milestone
            )

            if !(condensesNarrative && !narrativeExpanded) {
                GlossaryText(
                    text: ProCareerPresentation.decisionDetail(decision, resolver: copyResolver),
                    font: .subheadline,
                    color: BaseballTheme.textSecondary
                )
            }
            if condensesNarrative {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { narrativeExpanded.toggle() }
                } label: {
                    Label(
                        copyResolver.resolve(
                            narrativeExpanded
                                ? MetaUICopyKey.disclosureHintCollapse
                                : MetaUICopyKey.disclosureHintExpand
                        ),
                        systemImage: narrativeExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pro.seasonDecision.narrativeToggle")
            }

            ForEach(decision.choices) { choice in
                VStack(alignment: .leading, spacing: 7) {
                    Button { pendingChoice = choice } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(ProCareerPresentation.choiceTitle(choice, resolver: copyResolver))
                                    .font(.headline)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right.circle.fill")
                                    .foregroundStyle(BaseballTheme.selection)
                            }
                            Label(ProCareerPresentation.combinedEffect(
                                choice.effect,
                                journeyEffect: choice.journeyEffect,
                                resolver: copyResolver
                            ), systemImage: "plusminus.circle")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BaseballTheme.information)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("pro.seasonDecision.effect.\(choice.id)")
                            if decision.type.isWeeklyBinaryDecision {
                                Label(
                                    copyResolver.resolve(.decisionFollowUpImmediate),
                                    systemImage: "bolt.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                if let later = ProCareerPresentation.choiceFollowUpLine(choice, resolver: copyResolver) {
                                    Label(later, systemImage: "arrow.turn.down.right")
                                        .font(.caption)
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            } else {
                                Label(
                                    ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver),
                                    systemImage: decision.type == .mediaOpportunity ? "bolt.fill" : "arrow.turn.down.right"
                                )
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.accessibilityLabel(for: choice, resolver: copyResolver))
                    .accessibilityHint(copyResolver.resolve(.decisionHint))
                    .accessibilityIdentifier("pro.seasonDecision.choice.\(choice.id)")
                    if !(condensesNarrative && !narrativeExpanded) {
                        GlossaryText(
                            text: ProCareerPresentation.choiceDetail(choice, resolver: copyResolver),
                            font: .footnote,
                            color: BaseballTheme.textSecondary
                        )
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                        .stroke(BaseballTheme.border, lineWidth: 1)
                }
            }

            Label(copyResolver.resolve(.decisionWarning), systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(BaseballTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 28)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pro.seasonDecision")
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BaseballTheme.canvas)
        .onAppear {
            let density = CopyDensity(rawValue: densityRaw) ?? .automatic
            switch density {
            case .expanded: condensesNarrative = false
            case .compact: condensesNarrative = true
            case .automatic: condensesNarrative = SeenContentStore.contains(seenContentID)
            }
            SeenContentStore.markSeen(seenContentID)
        }
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
                Text(ProDecisionCopy.confirmMessage(
                    detail: ProCareerPresentation.choiceDetail(pendingChoice, resolver: copyResolver),
                    effect: ProCareerPresentation.combinedEffect(
                        pendingChoice.effect,
                        journeyEffect: pendingChoice.journeyEffect,
                        resolver: copyResolver
                    ),
                    timing: ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver),
                    resolver: copyResolver
                ))
            }
        }
    }

    static func accessibilityLabel(
        for choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
    ) -> String {
        ProDecisionCopy.accessibilityLabel(for: choice, resolver: resolver)
    }
}

