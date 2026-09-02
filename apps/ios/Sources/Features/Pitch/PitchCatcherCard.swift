import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct CatcherCard: View {
    let preparation: PitchPreparation
    let session: PitchSession

    @State private var showsScouting = false
    @Environment(\.gameCopyResolver) private var copyResolver

    private func matches(_ call: PitchCall) -> Bool {
        return call.pitchType == session.selectedPitchType
            && call.zone == session.selectedZone
            && call.zoneIntent == session.selectedIntent
            && call.intensity == session.selectedIntensity
    }

    private var matchesRecommendation: Bool { matches(preparation.primaryRecommendation.call) }
    private var matchesAlternative: Bool { matches(preparation.alternativeRecommendation.call) }

    /// 카드 눈썹은 하나다. 예전의 "포수 사인 · 연동 중" 상태 줄과 안쪽 눈썹 두 개("지금 던질 공",
    /// "포수 제안")는 같은 공을 세 번 이름 붙였다(1.2.9 가독성 교정).
    private var cardTitle: String {
        if matchesRecommendation || matchesAlternative { return copyResolver.resolve(.catcherProposal) }
        return copyResolver.resolve(.catcherManual)
    }

    private var catcherBond: String {
        switch session.scenario.catcherTrust {
        case 75...: copyResolver.resolve(.catcherBondOneBreath)
        case 55...: copyResolver.resolve(.catcherBondAligned)
        case 35...: copyResolver.resolve(.catcherBondLearning)
        default: copyResolver.resolve(.catcherBondCrossed)
        }
    }

    /// 지금 던질 공. 화면에서 이 사인은 여기 한 번만 적힌다.
    private var selectedCallSummary: String {
        "\(PitchCopy.localized(session.selectedPitchType, resolver: copyResolver)) · "
            + "\(PitchCopy.localized(session.selectedZone, batSide: session.batter.batSide, resolver: copyResolver)) · "
            + "\(PitchCopy.localized(session.selectedIntent, resolver: copyResolver)) · "
            + PitchCopy.localized(session.selectedIntensity, resolver: copyResolver)
    }

    private func callSummary(_ call: PitchCall) -> String {
        "\(PitchCopy.localized(call.pitchType, resolver: copyResolver)) · "
            + "\(PitchCopy.localized(call.zone, batSide: session.batter.batSide, resolver: copyResolver)) · "
            + PitchCopy.localized(call.zoneIntent, resolver: copyResolver)
    }

    /// 사인의 근거를 보여 줄 제안. 직접 고른 배합이면 1안의 근거를 보여 준다 —
    /// 포수가 왜 다른 공을 원했는지가 곧 비교 기준이다.
    private var explainedRecommendation: CatcherRecommendationSnapshot {
        matchesAlternative ? preparation.alternativeRecommendation : preparation.primaryRecommendation
    }

    private var selectedConfidence: Int? {
        guard matchesRecommendation || matchesAlternative else { return nil }
        return max(0, min(100, explainedRecommendation.confidence / 10))
    }

    private func riskText(_ recommendation: CatcherRecommendationSnapshot) -> String {
        switch recommendation.call.zoneIntent {
        case .chase: copyResolver.resolve(.catcherRiskMiss)
        case .edge: copyResolver.resolve(.catcherRiskWalk)
        case .strike: copyResolver.resolve(.catcherRiskDamage)
        }
    }

    /// 1안·2안 선택. 고른 안의 사인은 위 리드 줄이 말하므로 여기서는 이름만 남기고,
    /// 고르지 않은 안만 무엇이 다른지 한 줄 덧붙인다 — 같은 사인을 두 번 적지 않는다.
    @ViewBuilder
    private func recommendationButton(
        title: PitchUICopyKey,
        recommendation: CatcherRecommendationSnapshot,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: copyResolver.resolve(title))
                    .font(BaseballType.detail.weight(.semibold))
                    .foregroundStyle(selected ? BaseballTheme.positive : BaseballTheme.textPrimary)
                if !selected {
                    Text(verbatim: callSummary(recommendation.call))
                        .font(BaseballType.annotation)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
            .background(
                selected ? BaseballTheme.positive.opacity(0.10) : BaseballTheme.surface,
                in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(selected ? BaseballTheme.positive : BaseballTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    var body: some View {
        // 현재 선택과 포수 제안을 한 면에서 비교한다. 무엇을 던지는지와 누구의 판단인지가
        // 떨어져 있으면, 플레이어는 기본값으로 던지고도 자기 선택이라고 느끼기 어렵다.
        BaseballCard(title: cardTitle) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: selectedCallSummary)
                    .proseLeadStyle()
                    .accessibilityIdentifier("pitch.selectedCall")
                EffectChipFlow {
                    if let selectedConfidence {
                        EffectChip(
                            text: copyResolver.resolve(.catcherChipConfidence, arguments: [.integer(selectedConfidence)]),
                            tone: .neutral
                        )
                    }
                    EffectChip(
                        text: copyResolver.resolve(.catcherChipTrust, arguments: [
                            .integer(session.scenario.catcherTrust), .userText(catcherBond),
                        ]),
                        tone: .neutral
                    )
                }

                // 근거 세 줄은 접어 둔다. 사인 한 줄과 칩만 보고도 던질 수 있어야 하고,
                // 왜 이 공인지는 궁금한 사람이 한 번 편다.
                ProgressiveDisclosure(
                    contentID: "pitch.sign.rationale",
                    title: copyResolver.resolve(.catcherRationaleTitle),
                    summary: PitchPresentation.catcherReason(explainedRecommendation, resolver: copyResolver)
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: PitchPresentation.catcherReason(explainedRecommendation, resolver: copyResolver))
                            .detailStyle()
                        EffectChip(text: riskText(explainedRecommendation), tone: .cost, systemImage: "exclamationmark.triangle")
                    }
                }

                recommendationButton(
                    title: .catcherPrimary,
                    recommendation: preparation.primaryRecommendation,
                    selected: matchesRecommendation,
                    identifier: "pitch.acceptPrimaryCall",
                    action: session.acceptCatcherRecommendation
                )
                recommendationButton(
                    title: .catcherAlternative,
                    recommendation: preparation.alternativeRecommendation,
                    selected: matchesAlternative,
                    identifier: "pitch.acceptAlternativeCall",
                    action: session.acceptCatcherAlternativeRecommendation
                )

                // 사인 고정 — 켜면 포수 추천이 다음 공에서 내 선택을 덮지 않는다.
                // "이 타자한테는 낮은 슬라이더로 민다"는 의도가 매 투구 2~4탭 없이 살아남는다.
                Toggle(isOn: Binding(
                    get: { session.holdCall },
                    set: { keepsOwnCall in
                        if keepsOwnCall {
                            session.holdCall = true
                        } else {
                            session.acceptCatcherRecommendation()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: copyResolver.resolve(.catcherHold))
                            .font(BaseballType.detail.weight(.semibold))
                        Text(verbatim: copyResolver.resolve(.catcherHoldBody))
                            .detailStyle(BaseballTheme.textTertiary)
                    }
                }
                .tint(BaseballTheme.action)
                .accessibilityIdentifier("pitch.holdCall")

                // 분석은 접어 둔다 — 결정 한 번에 300자를 읽히면 손맛이 성립하지
                // 않는다(QA P1-6). 궁금한 사람만 한 탭으로 편다.
                if let report = preparation.scoutingReport {
                    Button {
                        showsScouting.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: copyResolver.resolve(
                                .catcherScout,
                                arguments: [.userText(PitchCopy.localizedScoutBand(report.band, resolver: copyResolver))]
                            ))
                                .font(BaseballType.detail.weight(.semibold))
                                .foregroundStyle(BaseballTheme.textSecondary)
                            Image(systemName: showsScouting ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pitch.scouting.toggle")
                    if showsScouting {
                        Text(verbatim: copyResolver.resolve(
                            report.band == "trusted" ? .catcherScoutTrusted : .catcherScoutEstimate,
                            arguments: [
                                .userText(PitchCopy.localized(report.estimatedWeakness, resolver: copyResolver)),
                                .userText(PitchCopy.localized(
                                    report.estimatedColdZone,
                                    batSide: session.batter.batSide,
                                    resolver: copyResolver
                                )),
                            ]
                        ))
                            .detailStyle()
                        // 노릴 곳만 말하고 피할 곳을 감추면, 실점을 가장 크게 가르는
                        // 정보의 절반이 화면 밖에 남는다. 강점 구종과 hot zone을 같이 적는다.
                        if let strength = report.estimatedStrength, let hot = report.estimatedHotZone {
                            EffectChip(
                                text: copyResolver.resolve(.catcherScoutAvoid, arguments: [
                                    .userText(PitchCopy.localized(strength, resolver: copyResolver)),
                                    .userText(PitchCopy.localized(hot, batSide: session.batter.batSide, resolver: copyResolver)),
                                ]),
                                tone: .cost,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .accessibilityIdentifier("pitch.scouting.avoid")
                        }
                    }
                }

                if session.holdCall || (!matchesRecommendation && !matchesAlternative) {
                    Button(copyResolver.resolve(.catcherAccept)) { session.acceptCatcherRecommendation() }
                    .font(BaseballType.detail.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("pitch.acceptCatcherCall")
                }
            }
        }
    }
}
