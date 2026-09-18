import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// 프로 시즌 대화 한 장면.
///
/// 예전에는 키아트 배너 + 작은 선택 카드 + 확인 알럿이었다. 세 가지가 문제였다.
/// 1. 말을 거는 사람이 없었다. 라이벌 분석도 포수 배합도 같은 야구장 사진이었다.
/// 2. 칩은 **선언된 효과**를 읽었다. 80에 닿은 능력의 "+1"이 이득처럼 보였고, 신구종
///    실전이 구종을 다듬는 일과 주간 2지선다가 남기는 3주 약속은 어디에도 없었다.
/// 3. 확인이 알럿이었다. iOS 26에서는 그마저 팝오버로 떠 취소가 잘렸다.
///
/// 지금은 84pt 초상 + 풀카드 셋 + 같은 화면 아래의 확인 버튼이고, 칩은
/// `ProConversationPresentation.preview`가 **같은 시드로 커널을 돌려** 만든 값이다.
/// 미리보기는 상태를 쓰지 않는다 — 고르기만 해서는 명령이 0회다.
struct ProSeasonDecisionView: View {
    let career: MobileCareerStore
    let decision: ProSeasonDecision
    @State private var selectedChoiceID: String?
    @State private var seenContentID: String = ""
    @Environment(\.gameCopyResolver) private var copyResolver

    private var role: ProConversationRole? {
        ProConversationPresentation.role(for: decision.type)
    }

    private var teamID: String { career.state?.team.id ?? "" }

    private var selectedChoice: ProSeasonDecisionChoice? {
        decision.choices.first { $0.id == selectedChoiceID }
    }

    /// 주간 화면이 피로 타일을 경고색으로 바꾸는 기준과 같다. "강하게 더 던진다"의 피로 +14가
    /// 이 선을 넘기면 결정 카드에서 바로 부상 위험이 보여야 한다(페르소나 보고서 §3 P2).
    static let injuryRiskFatigueThreshold = 70

    static func projectsInjuryRisk(_ choice: ProSeasonDecisionChoice, currentFatigue: Int?) -> Bool {
        guard let currentFatigue, choice.effect.fatigueDelta > 0 else { return false }
        return currentFatigue + choice.effect.fatigueDelta >= injuryRiskFatigueThreshold
    }

    var body: some View {
        ConversationStage(
            eyebrow: ProDecisionCopy.eyebrow(
                season: decision.season,
                week: decision.week,
                resolver: copyResolver,
                weekly: decision.type.isWeeklyBinaryDecision
            ),
            portrait: role.map {
                .init(seed: ProPeoplePresentation.seed(teamID: teamID, role: $0),
                      role: ProPeoplePresentation.portraitRole($0))
            },
            roleLabel: role.map { ProPeoplePresentation.roleLabel($0, resolver: copyResolver) },
            speakerName: role.map {
                ProPeoplePresentation.name(teamID: teamID, role: $0, resolver: copyResolver)
            },
            situation: role.map {
                ProPeoplePresentation.personality(teamID: teamID, role: $0, resolver: copyResolver)
            },
            line: ProCareerPresentation.decisionTitle(decision, resolver: copyResolver)
        ) {
            Text(verbatim: copyResolver.resolve(.decisionSelectPrompt))
                .font(.headline)
                .foregroundStyle(BaseballTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(decision.choices) { choice in
                choiceCard(choice)
            }

            Text(verbatim: copyResolver.resolve(.decisionPreviewCaption))
                .detailStyle(BaseballTheme.textTertiary)

            // 원문 산문은 펼침으로 남긴다. 장면 본문을 두 번 읽게 하지 않는다.
            ProgressiveDisclosure(
                contentID: seenContentID,
                title: copyResolver.resolve(AppCopyKey.conversationSceneDisclosure),
                summary: "",
                important: false,
                startsCollapsed: true
            ) {
                VStack(alignment: .leading, spacing: 6) {
                    GlossaryText(
                        text: ProCareerPresentation.decisionDetail(decision, resolver: copyResolver),
                        font: BaseballType.prose
                    )
                    if !decision.type.isWeeklyBinaryDecision {
                        Text(verbatim: ProCareerPresentation.decisionTiming(for: decision, resolver: copyResolver))
                            .detailStyle(BaseballTheme.textTertiary)
                    }
                }
            }
            .accessibilityIdentifier("pro.seasonDecision.narrativeToggle")

            // 비가역 경고. 아이콘만 경고색, 문장은 읽는 글 색.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(BaseballType.detail)
                    .foregroundStyle(BaseballTheme.warning)
                    .accessibilityHidden(true)
                Text(verbatim: copyResolver.resolve(.decisionWarning))
                    .detailStyle()
            }
            .accessibilityElement(children: .combine)

            PrimaryPill(
                title: copyResolver.resolve(.decisionConfirmAction),
                identifier: "pro.seasonDecision.confirm",
                enabled: selectedChoice != nil
            ) {
                guard let selectedChoice else { return }
                career.applySeasonDecision(decisionID: decision.id, choiceID: selectedChoice.id)
            }
        }
        .padding(.bottom, 28)
        .background(BaseballTheme.canvas)
        .accessibilityIdentifier("pro.seasonDecision")
        .onAppear {
            seenContentID = "pro.decision.\(decision.type.rawValue).v2"
            SeenContentStore.markSeen(seenContentID)
        }
    }

    @ViewBuilder
    private func choiceCard(_ choice: ProSeasonDecisionChoice) -> some View {
        let chips = previewChips(for: choice)
        ConversationChoiceCard(
            title: ProCareerPresentation.choiceTitle(choice, resolver: copyResolver),
            detail: ProCareerPresentation.choiceDetail(choice, resolver: copyResolver),
            chips: chips,
            timingLines: timingLines(for: choice),
            isSelected: selectedChoiceID == choice.id,
            identifier: "pro.seasonDecision.choice.\(choice.id)",
            accessibilityText: [
                ProCareerPresentation.choiceTitle(choice, resolver: copyResolver),
                chips.map(\.text).joined(separator: " · "),
            ].joined(separator: ", ")
        ) {
            // 고르는 일은 명령이 아니다. 확정은 아래 버튼 한 번뿐이다.
            selectedChoiceID = choice.id
        }
    }

    /// 커널에게 물어본 결과. 커널이 거부하는 선택지는 선언된 효과로 물러선다 —
    /// 자격이 없는 광고 촬영처럼 애초에 눌러도 안 되는 선택이다.
    private func previewChips(for choice: ProSeasonDecisionChoice) -> [ConversationChip] {
        var chips: [ConversationChip]
        if let result = career.result,
           let outcome = ProConversationPresentation.preview(
            engine: career.engine,
            state: result.snapshot,
            seed: result.nextSeed,
            decisionID: decision.id,
            choiceID: choice.id
           ) {
            chips = ProCareerPresentation.conversationChips(outcome, resolver: copyResolver)
        } else {
            chips = ProCareerPresentation.effectChips(
                choice.effect,
                journeyEffect: choice.journeyEffect,
                resolver: copyResolver
            ).map { ConversationChip(id: $0.id, text: $0.text, tone: $0.tone) }
        }
        if Self.projectsInjuryRisk(choice, currentFatigue: career.state?.fatigue) {
            chips.append(ConversationChip(
                id: "injury-risk",
                text: copyResolver.resolve(.decisionChipInjuryRisk),
                tone: .risk,
                systemImage: "exclamationmark.triangle.fill"
            ))
        }
        return chips
    }

    private func timingLines(for choice: ProSeasonDecisionChoice) -> [(systemImage: String, text: String)] {
        guard decision.type.isWeeklyBinaryDecision else { return [] }
        var lines: [(systemImage: String, text: String)] = [
            ("bolt.fill", copyResolver.resolve(.decisionFollowUpImmediate)),
        ]
        if let later = ProCareerPresentation.choiceFollowUpLine(choice, resolver: copyResolver) {
            lines.append(("arrow.turn.down.right", later))
        }
        return lines
    }

    static func accessibilityLabel(
        for choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
    ) -> String {
        ProDecisionCopy.accessibilityLabel(for: choice, resolver: resolver)
    }
}

/// 선택이 남긴 변화. **같은 무대 위에** 남는다 — 결과를 보려고 화면을 옮기지 않는다.
struct ProSeasonDecisionResultView: View {
    let career: MobileCareerStore
    let receipt: ProSeasonDecisionReceipt
    @Environment(\.gameCopyResolver) private var copyResolver

    private var role: ProConversationRole? {
        ProConversationPresentation.role(for: receipt.type)
    }

    var body: some View {
        ConversationStage(
            eyebrow: copyResolver.resolve(AppCopyKey.conversationResultEyebrow),
            portrait: role.map {
                .init(seed: ProPeoplePresentation.seed(teamID: receipt.teamID, role: $0),
                      role: ProPeoplePresentation.portraitRole($0))
            },
            roleLabel: role.map { ProPeoplePresentation.roleLabel($0, resolver: copyResolver) },
            speakerName: role.map {
                ProPeoplePresentation.name(teamID: receipt.teamID, role: $0, resolver: copyResolver)
            },
            situation: nil,
            line: receiptChoiceTitle
        ) {
            Text(verbatim: copyResolver.resolve(.decisionResultLine))
                .font(.headline)
                .foregroundStyle(BaseballTheme.textPrimary)
            EffectChipFlow {
                ForEach(ProCareerPresentation.conversationChips(receipt.outcome, resolver: copyResolver)) { chip in
                    EffectChip(text: chip.text, tone: chip.tone, systemImage: chip.systemImage)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pro.seasonDecision.result.effects")
            PrimaryPill(
                title: copyResolver.resolve(.decisionResultContinue),
                identifier: "pro.seasonDecision.result.continue"
            ) {
                career.acknowledgeSeasonDecisionReceipt()
            }
        }
        .padding(.bottom, 28)
        .background(BaseballTheme.canvas)
        .accessibilityIdentifier("pro.seasonDecision.result")
    }

    private var receiptChoiceTitle: String {
        ProCareerPresentation.decisionRecordTitle(
            ProDecisionRecord(
                decisionID: receipt.decisionID,
                type: receipt.type,
                season: 0,
                week: 0,
                choiceID: receipt.choiceID,
                choiceTitle: receipt.choiceTitle,
                effect: .init()
            ),
            resolver: copyResolver
        )
    }
}
