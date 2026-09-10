import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct RelationshipCard: View {
    let state: HighSchoolCareerSnapshot
    let onRespond: (RelationshipResponse) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var event: CareerEventContent? {
        state.currentRelationshipEvent
    }

    private var eventCopy: RelationshipCardCopyDescriptor? {
        event.map(RelationshipPresentationCatalog.cardDescriptor(for:))
    }

    private var portraitSeed: (seed: String, role: AvatarFace.Role)? {
        guard let event else { return nil }
        return HighSchoolPresentation.relationshipPortraitSeed(category: event.category, state: state)
    }

    private var band: RelationshipVoiceCatalog.TrustBand {
        guard let event else { return .mid }
        return HighSchoolPresentation.relationshipTrustBand(
            for: event,
            manager: state.managerTrust ?? state.relationshipTrust,
            catcher: state.catcherTrust ?? state.relationshipTrust,
            rival: state.rivalTrust ?? state.relationshipTrust,
            resolver: copyResolver
        )
    }

    private var windEffect: String? {
        guard let category = event?.category else { return nil }
        return HighSchoolPresentation.localizedRelationshipWindLine(
            category: category,
            wind: state.careerWind,
            resolver: copyResolver
        )
    }

    var body: some View {
        // 프로 시즌 대화와 같은 무대를 쓴다. 한 게임 안에서 대화가 두 모양이면
        // 그건 한 게임이 아니다.
        ConversationStage(
            eyebrow: copyResolver.resolve(AppCopyKey.conversationEyebrow),
            portrait: portraitSeed.map { .init(seed: $0.seed, role: $0.role) },
            sceneArtAsset: portraitSeed == nil ? event.map { "SceneArt-\($0.category)" } : nil,
            roleLabel: speakerLabel,
            speakerName: visibleName,
            situation: eventTitle,
            line: sceneLine,
            headerAccessibilityText: headerAccessibility
        ) {
            if let windEffect {
                EffectChip(text: windEffect, tone: .neutral, systemImage: "wind")
            }
            if let echoSource {
                Text(verbatim: echoSource).detailStyle()
            }
            GameCopyText(coreToken: .relationshipPrompt())
                .font(.headline)
                .foregroundStyle(BaseballTheme.textPrimary)
            ForEach(RelationshipResponse.allCases, id: \.self) { response in
                let choice = choiceCopy(for: response)
                // 설명을 카드 위에 적는다. 예전에는 보조 기술에만 남아 있어서, 고르기
                // 전에는 대가가 보이지 않았다.
                ConversationChoiceCard(
                    title: choice.visibleLine,
                    detail: choice.accessibilityDetail,
                    chips: [],
                    identifier: "hs.response.\(response.rawValue)",
                    accessibilityText: HighSchoolPresentation.localizedRelationshipChoiceAccessibility(
                        title: choice.visibleLine,
                        detail: choice.accessibilityDetail,
                        resolver: copyResolver
                    )
                ) {
                    onRespond(response)
                }
            }
        }
        .accessibilityIdentifier("hs.relationship")
        .onAppear {
            guard let event, event.category == "rebirth" else { return }
            let recent = state.rebirthEcho?.recentEventIDs?.contains(event.id) == true
            CareerTelemetry.logOnce(
                .rebirthEchoSeen,
                scope: "rebirth-echo:\(state.careerID):\(event.id):\(state.relationshipsCompleted)",
                properties: [
                    "event_id": event.id,
                    "life_number": state.lifeNumber,
                    "source_life_number": state.rebirthEcho?.previousLifeNumber ?? 0,
                    "had_arm_warning": state.rebirthEcho?.hadArmWarning ?? false,
                    "had_runs_allowed": state.rebirthEcho?.hasRunsAllowedFact ?? false,
                    "has_inherited_power": state.rebirthEcho?.hasInheritedPower ?? false,
                    "was_recent": recent,
                ]
            )
        }
    }

    private var eventTitle: String? {
        event.map { HighSchoolPresentation.localizedRelationshipEventTitle($0, resolver: copyResolver) }
    }

    private var headerAccessibility: String? {
        guard let scene else { return nil }
        return HighSchoolPresentation.localizedRelationshipEventAccessibility(
            speaker: speakerLabel ?? "",
            name: visibleName ?? "",
            title: eventTitle ?? "",
            primaryText: [scene.visibleLine, echoSource].compactMap { $0 }.joined(separator: " "),
            summary: scene.accessibilitySummary,
            resolver: copyResolver
        )
    }

    private var speakerLabel: String? {
        eventCopy.map { copyResolver.resolve($0.event.speakerLabelToken) }
    }

    /// 사람이 아닌 화자(집·취재·팬·몸 상태…)는 이름을 지어내지 않는다.
    private var visibleName: String? {
        guard let event else { return nil }
        switch event.category {
        case "coach":
            return state.school.map {
                HighSchoolPresentation.localizedSchoolCastName(
                    $0, rawRegion: state.identity.region, role: .coach, resolver: copyResolver
                )
            }
        case "catcher":
            return state.school.map {
                HighSchoolPresentation.localizedSchoolCastName(
                    $0, rawRegion: state.identity.region, role: .catcher, resolver: copyResolver
                )
            }
        case "rival":
            return HighSchoolPresentation.localizedRivalName(state.rival, resolver: copyResolver)
        default:
            return nil
        }
    }

    private var scene: RelationshipCardPresentationPolicy.Scene? {
        guard let event else { return nil }
        return RelationshipCardPresentationPolicy.scene(
            quote: HighSchoolPresentation.localizedRelationshipQuote(
                event: event, band: band, playerName: state.identity.name, resolver: copyResolver
            ),
            summary: HighSchoolPresentation.localizedRelationshipEventSummary(event, resolver: copyResolver)
        )
    }

    /// 손으로 쓴 대사가 있으면 그 한 줄이 장면 본문이다. 요약을 다시 보이지 않아
    /// 같은 상황을 두 번 읽게 하지 않는다.
    private var sceneLine: String {
        scene?.visibleLine ?? ""
    }

    private var echoSource: String? {
        guard event?.category == "rebirth" else { return nil }
        return state.rebirthEcho?.previousPlayerName.map {
            copyResolver.resolve(LegacyUICopyKey.rebirthEchoSource, arguments: [.userText($0)])
        }
    }

    private func choiceCopy(for response: RelationshipResponse) -> RelationshipCardPresentationPolicy.Choice {
        let title = event.map {
            HighSchoolPresentation.localizedRelationshipChoiceTitle(
                event: $0, response: response, resolver: copyResolver
            )
        } ?? copyResolver.resolve(.relationshipFallbackChoiceTitle(response: response))
        let detail = event.map {
            HighSchoolPresentation.localizedRelationshipChoiceDetail(
                event: $0, response: response, resolver: copyResolver
            )
        } ?? copyResolver.resolve(.relationshipFallbackChoiceDetail(response: response))
        return RelationshipCardPresentationPolicy.choice(title: title, detail: detail)
    }
}

/// 관계 카드의 시각 정보량과 접근성 정보량을 각각 정한다.
///
/// 순수 규칙으로 두어 대사/요약과 선택/설명이 다시 동시 노출되는 회귀를
/// 뷰를 실행하지 않고도 검증할 수 있게 한다.
enum RelationshipCardPresentationPolicy {
    struct Scene: Equatable {
        let visibleLine: String
        let accessibilitySummary: String
    }

    struct Choice: Equatable {
        let visibleLine: String
        let accessibilityDetail: String
    }

    static func scene(quote: String, summary: String) -> Scene {
        let hasAuthoredQuote = !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Scene(
            visibleLine: hasAuthoredQuote ? quote : summary,
            accessibilitySummary: hasAuthoredQuote ? summary : ""
        )
    }

    static func choice(title: String, detail: String) -> Choice {
        Choice(visibleLine: title, accessibilityDetail: detail)
    }
}

struct ImportantGameCard: View {
    let state: HighSchoolCareerSnapshot
    /// Structured counts are formatted at the presentation boundary. The persisted ledger and
    /// its Codable shape remain unchanged.
    let rivalLedger: RivalLedger
    var showsStartAction = true
    let onStart: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 8챕터 — 이 회차에서 그를 상대하는 마지막 마운드다.
    private var isFinalShowdown: Bool { state.chapter.number == 8 }

    private var rivalName: String {
        HighSchoolPresentation.localizedRivalName(state.rival, resolver: copyResolver)
    }

    private var rivalArchetype: String {
        HighSchoolPresentation.localizedRivalArchetype(state.rival, resolver: copyResolver)
    }

    private var rivalSignature: String? {
        HighSchoolPresentation.localizedRivalSignature(state.rival, resolver: copyResolver)
    }

    private var rivalMatchup: String? {
        HighSchoolPresentation.localizedImportantGameCareerMatchup(
            rivalLedger,
            resolver: copyResolver
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if let scenario = state.currentGameScenario {
                let title = HighSchoolPresentation.localizedImportantGameScenarioTitle(
                    scenario,
                    resolver: copyResolver
                )
                let situation = HighSchoolPresentation.localizedImportantGameSituation(
                    scenario,
                    resolver: copyResolver
                )
                let narrative = HighSchoolPresentation.localizedImportantGameScenarioNarrative(
                    scenario,
                    resolver: copyResolver
                )
                BaseballCard(title: title, tone: .milestone) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: situation)
                            .proseLeadStyle()
                            .monospacedDigit()
                        Text(verbatim: narrative)
                            .proseStyle(BaseballTheme.textSecondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedImportantGameScenarioAccessibility(
                    title: title,
                    situation: situation,
                    narrative: narrative,
                    resolver: copyResolver
                )))
            }
            let opponentTitle = HighSchoolPresentation.localizedImportantGameOpponentTitle(
                isFinalShowdown: isFinalShowdown,
                resolver: copyResolver
            )
            BaseballCard(title: opponentTitle, tone: .warning) {
                VStack(alignment: .leading, spacing: 8) {
                    AvatarRow(
                        seed: HighSchoolPresentation.importantGameRivalPortraitSeed(state.rival),
                        role: .rival,
                        name: rivalName,
                        caption: rivalArchetype,
                        size: 48
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedImportantGameRivalAccessibility(
                        name: rivalName,
                        archetype: rivalArchetype,
                        signature: rivalSignature,
                        resolver: copyResolver
                    )))
                    if let rivalSignature {
                        Text(verbatim: rivalSignature)
                            .detailStyle()
                            .monospacedDigit()
                    }
                    // 쌓인 역사. 전적이 있어야 이 타석이 서사가 된다.
                    if let rivalMatchup {
                        Text(verbatim: rivalMatchup)
                            .detailStyle(BaseballTheme.textPrimary)
                            .monospacedDigit()
                    }
                    if isFinalShowdown {
                        Text(verbatim: HighSchoolPresentation.localizedImportantGameFinalShowdownBody(
                            resolver: copyResolver
                        ))
                            .detailStyle()
                    }
                }
            }
            if showsStartAction {
            PrimaryButton(
                title: HighSchoolPresentation.localizedImportantGameStartAction(resolver: copyResolver),
                identifier: "hs.game.start",
                action: onStart
            )
            }
        }
    }
}

/// 각성 스킬트리.
///
/// 회차당 세 번뿐인 선택을 낱장 카드 세 장으로 보여 주면, 세 번이 서로 아무 관계가 없어
/// "이 선수를 이렇게 만들었다"가 남지 않는다. 트리는 그 셋을 한 줄기로 묶는다 — 뿌리를
/// 찍으면 그 갈래의 다음 가지가 열리고, 세 번으로 **한 갈래를 끝까지 파거나 여러 갈래를
/// 얕게 가져가거나**를 고르게 된다.
///
/// 잠긴 가지도 **지운다기보다 보여 준다.** 앞으로 갈 수 있는 길이 보여야 지금의 한 번이
/// 결정처럼 느껴진다. 잠긴 이유(무엇을 먼저 찍어야 하는지)를 그 자리에 적는다.
///
