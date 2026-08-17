import SwiftUI
import SimulationCore

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
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 대화가 이 화면의 주인공이다. 예전에는 요약 한 줄이 작은 글씨로 붙고 선택지가
            // 화면을 채워서, 무슨 일이 일어났는지보다 버튼 세 개가 먼저 눈에 들어왔다.
            if let event, let eventCopy {
                let speaker = copyResolver.resolve(eventCopy.event.speakerLabelToken)
                let title = HighSchoolPresentation.localizedRelationshipEventTitle(
                    event,
                    resolver: copyResolver
                )
                let summary = HighSchoolPresentation.localizedRelationshipEventSummary(
                    event,
                    resolver: copyResolver
                )
                let quote = HighSchoolPresentation.localizedRelationshipQuote(
                    event: event,
                    band: band,
                    playerName: state.identity.name,
                    resolver: copyResolver
                )
                let scene = RelationshipCardPresentationPolicy.scene(
                    quote: quote,
                    summary: summary
                )
                let echoSource = event.category == "rebirth"
                    ? state.rebirthEcho?.previousPlayerName.map {
                        copyResolver.resolve(
                            LegacyUICopyKey.rebirthEchoSource,
                            arguments: [.userText($0)]
                        )
                    }
                    : nil
                let visibleName: String? = switch event.category {
                case "coach":
                    state.school.map {
                        HighSchoolPresentation.localizedSchoolCastName(
                            $0,
                            rawRegion: state.identity.region,
                            role: .coach,
                            resolver: copyResolver
                        )
                    }
                case "catcher":
                    state.school.map {
                        HighSchoolPresentation.localizedSchoolCastName(
                            $0,
                            rawRegion: state.identity.region,
                            role: .catcher,
                            resolver: copyResolver
                        )
                    }
                case "rival":
                    HighSchoolPresentation.localizedRivalName(state.rival, resolver: copyResolver)
                default:
                    nil
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if let portrait = portraitSeed {
                            PortraitView(seed: portrait.seed, role: portrait.role, size: 44)
                        } else {
                            // 사람이 아닌 화자(집·취재·팬·몸 상태…)는 얼굴 대신 상황 그림.
                            // 없는 인물을 지어내지 않으면서 빈 자리도 남기지 않는다.
                            ArtThumb(assetName: "SceneArt-\(event.category)", size: 44, cornerRadius: 8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: speaker).eyebrowStyle(BaseballTheme.information)
                            if let visibleName {
                                Text(verbatim: visibleName).font(.subheadline.weight(.bold))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    Text(verbatim: title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    // 손으로 쓴 대사가 있으면 그 한 줄이 장면 본문이다. 요약을 다시
                    // 보이지 않아 같은 상황을 두 번 읽게 하지 않는다. 대사가 없는 옛
                    // 이벤트만 요약을 본문으로 쓴다.
                    Text(verbatim: scene.visibleLine)
                        .font(.body)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let echoSource {
                        Text(verbatim: echoSource)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedRelationshipEventAccessibility(
                    speaker: speaker,
                    name: visibleName ?? "",
                    title: title,
                    primaryText: [scene.visibleLine, echoSource].compactMap { $0 }.joined(separator: " "),
                    summary: scene.accessibilitySummary,
                    resolver: copyResolver
                )))
            }
            if let windEffect {
                Label {
                    Text(verbatim: windEffect)
                } icon: {
                    Image(systemName: "wind")
                }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.information)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GameCopyText(coreToken: .relationshipPrompt()).font(.headline)
            ForEach(RelationshipResponse.allCases, id: \.self) { response in
                let choiceTitle = event.map {
                    HighSchoolPresentation.localizedRelationshipChoiceTitle(
                        event: $0,
                        response: response,
                        resolver: copyResolver
                    )
                } ?? copyResolver.resolve(.relationshipFallbackChoiceTitle(response: response))
                let choiceDetail = event.map {
                    HighSchoolPresentation.localizedRelationshipChoiceDetail(
                        event: $0,
                        response: response,
                        resolver: copyResolver
                    )
                } ?? copyResolver.resolve(.relationshipFallbackChoiceDetail(response: response))
                let choice = RelationshipCardPresentationPolicy.choice(
                    title: choiceTitle,
                    detail: choiceDetail
                )
                Button { onRespond(response) } label: {
                    Text(verbatim: choice.visibleLine)
                        .font(.subheadline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: BaseballMetrics.minimumTapTarget,
                        alignment: .leading
                    )
                    .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedRelationshipChoiceAccessibility(
                    title: choice.visibleLine,
                    detail: choice.accessibilityDetail,
                    resolver: copyResolver
                )))
                .accessibilityIdentifier("hs.response.\(response.rawValue)")
            }
        }
        .onAppear {
            guard let event, event.category == "rebirth" else { return }
            let recent = state.rebirthEcho?.recentEventIDs?.contains(event.id) == true
            GameAnalytics.logOnce(
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
    let rivalLedger: HighSchoolCareerStore.RivalLedger
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
                            .font(.subheadline.bold().monospacedDigit())
                        Text(verbatim: narrative)
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    // 쌓인 역사. 전적이 있어야 이 타석이 서사가 된다.
                    if let rivalMatchup {
                        Text(verbatim: rivalMatchup)
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    if isFinalShowdown {
                        Text(verbatim: HighSchoolPresentation.localizedImportantGameFinalShowdownBody(
                            resolver: copyResolver
                        ))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            PrimaryButton(
                title: HighSchoolPresentation.localizedImportantGameStartAction(resolver: copyResolver),
                identifier: "hs.game.start",
                action: onStart
            )
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
