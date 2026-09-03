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

    /// 주간 화면이 피로 타일을 경고색으로 바꾸는 기준과 같다. "강하게 더 던진다"의 피로 +14가
    /// 이 선을 넘기면 결정 카드에서 바로 부상 위험이 보여야 한다(페르소나 보고서 §3 P2).
    static let injuryRiskFatigueThreshold = 70

    static func projectsInjuryRisk(_ choice: ProSeasonDecisionChoice, currentFatigue: Int?) -> Bool {
        guard let currentFatigue, choice.effect.fatigueDelta > 0 else { return false }
        return currentFatigue + choice.effect.fatigueDelta >= injuryRiskFatigueThreshold
    }

    private func injuryRiskLabel(for choice: ProSeasonDecisionChoice) -> String? {
        Self.projectsInjuryRisk(choice, currentFatigue: career.state?.fatigue)
            ? copyResolver.resolve(.decisionChipInjuryRisk)
            : nil
    }

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
                    font: BaseballType.prose
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

            // 효과가 언제 드러나는지는 선택지마다 같으므로 카드 밖에 한 번만 적는다.
            // 3주 결정은 선택지별 후속 문장이 달라 카드 안에 남긴다.
            if !decision.type.isWeeklyBinaryDecision {
                Text(ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver))
                    .detailStyle(BaseballTheme.textTertiary)
            }

            ForEach(decision.choices) { choice in
                VStack(alignment: .leading, spacing: 8) {
                    Button { pendingChoice = choice } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(ProCareerPresentation.choiceTitle(choice, resolver: copyResolver))
                                    .font(.headline)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right.circle.fill")
                                    .foregroundStyle(BaseballTheme.selection)
                            }
                            // 이득 칩과 비용 칩을 색으로 가른다. "구위 +1 · 피로 +12" 한 문장에
                            // 섞여 있던 비용이 주황 칩으로 따로 선다.
                            EffectChipFlow {
                                ForEach(ProCareerPresentation.effectChips(
                                    choice.effect,
                                    journeyEffect: choice.journeyEffect,
                                    resolver: copyResolver
                                )) { chip in
                                    EffectChip(text: chip.text, tone: chip.tone)
                                }
                                if let risk = injuryRiskLabel(for: choice) {
                                    EffectChip(text: risk, tone: .risk, systemImage: "exclamationmark.triangle.fill")
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(Text(verbatim: [
                                ProCareerPresentation.combinedEffect(
                                    choice.effect,
                                    journeyEffect: choice.journeyEffect,
                                    resolver: copyResolver
                                ),
                                injuryRiskLabel(for: choice),
                            ].compactMap { $0 }.joined(separator: " · ")))
                            .accessibilityIdentifier("pro.seasonDecision.effect.\(choice.id)")
                            if decision.type.isWeeklyBinaryDecision {
                                Label(
                                    copyResolver.resolve(.decisionFollowUpImmediate),
                                    systemImage: "bolt.fill"
                                )
                                .font(BaseballType.annotation)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                if let later = ProCareerPresentation.choiceFollowUpLine(choice, resolver: copyResolver) {
                                    Label(later, systemImage: "arrow.turn.down.right")
                                        .detailStyle()
                                }
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
                            font: BaseballType.detail
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

            // 비가역 경고. 아이콘만 경고색, 문장은 읽는 글 색.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(BaseballType.detail)
                    .foregroundStyle(BaseballTheme.warning)
                Text(copyResolver.resolve(.decisionWarning))
                    .detailStyle()
            }
            .accessibilityElement(children: .combine)
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
        // confirmationDialog는 iOS 26에서 팝오버로 떠 취소가 안 보였고, 본문이 카드 내용을
        // 전부 되풀이했다. 알럿은 제목(선택지) + 효과 한 줄 + 비가역 한 줄 + 취소 버튼으로 끝난다.
        .alert(
            pendingChoice.map { ProCareerPresentation.choiceTitle($0, resolver: copyResolver) }
                ?? copyResolver.resolve(.decisionConfirmTitle),
            isPresented: Binding(
                get: { pendingChoice != nil },
                set: { if !$0 { pendingChoice = nil } }
            )
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
