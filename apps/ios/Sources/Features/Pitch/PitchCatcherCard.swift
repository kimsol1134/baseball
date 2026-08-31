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

    private var cardTitle: String {
        if matchesRecommendation { return copyResolver.resolve(.catcherSynced) }
        if matchesAlternative { return copyResolver.resolve(.catcherAlternative) }
        return copyResolver.resolve(session.holdCall ? .catcherManual : .catcherMatches)
    }

    private var catcherBond: String {
        switch session.scenario.catcherTrust {
        case 75...: copyResolver.resolve(.catcherBondOneBreath)
        case 55...: copyResolver.resolve(.catcherBondAligned)
        case 35...: copyResolver.resolve(.catcherBondLearning)
        default: copyResolver.resolve(.catcherBondCrossed)
        }
    }

    private var selectedCallSummary: String {
        "\(PitchCopy.localized(session.selectedPitchType, resolver: copyResolver)) · "
            + "\(PitchCopy.localized(session.selectedZone, batSide: session.batter.batSide, resolver: copyResolver)) · "
            + "\(PitchCopy.localized(session.selectedIntent, resolver: copyResolver)) · "
            + PitchCopy.localized(session.selectedIntensity, resolver: copyResolver)
    }

    private var selectedConfidence: Int? {
        let value: Int
        if matchesAlternative {
            value = preparation.alternativeRecommendation.confidence
        } else if matchesRecommendation {
            value = preparation.primaryRecommendation.confidence
        } else {
            return nil
        }
        return max(0, min(100, value / 10))
    }

    private func riskText(_ recommendation: CatcherRecommendationSnapshot) -> String {
        switch recommendation.call.zoneIntent {
        case .chase: copyResolver.resolve(.catcherRiskMiss)
        case .edge: copyResolver.resolve(.catcherRiskWalk)
        case .strike: copyResolver.resolve(.catcherRiskDamage)
        }
    }

    @ViewBuilder
    private func recommendationButton(
        title: PitchUICopyKey,
        recommendation: CatcherRecommendationSnapshot,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        let call = recommendation.call
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(verbatim: copyResolver.resolve(title))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected ? BaseballTheme.positive : BaseballTheme.information)
                    Spacer()
                    Text(verbatim: copyResolver.resolve(.catcherConfidence, arguments: [
                        .integer(max(0, min(100, recommendation.confidence / 10))),
                        .integer(session.scenario.catcherTrust), .userText(catcherBond),
                    ]))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
                }
                Text(verbatim:
                    "\(PitchCopy.localized(call.pitchType, resolver: copyResolver)) · "
                        + "\(PitchCopy.localized(call.zone, batSide: session.batter.batSide, resolver: copyResolver)) · "
                        + "\(PitchCopy.localized(call.zoneIntent, resolver: copyResolver))"
                )
                .font(.subheadline.weight(.semibold))
                Text(verbatim: PitchPresentation.catcherReason(recommendation, resolver: copyResolver))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                Label(riskText(recommendation), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.warning)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(verbatim: copyResolver.resolve(.catcherSelected)).eyebrowStyle(BaseballTheme.textTertiary)
                Text(verbatim: selectedCallSummary)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(session.holdCall ? BaseballTheme.action : BaseballTheme.positive)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pitch.selectedCall")
                if let selectedConfidence {
                    Text(verbatim: copyResolver.resolve(.catcherConfidence, arguments: [
                        .integer(selectedConfidence),
                        .integer(session.scenario.catcherTrust), .userText(catcherBond),
                    ]))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                }

                Divider()

                Text(verbatim: copyResolver.resolve(.catcherProposal)).eyebrowStyle(BaseballTheme.textTertiary)
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
                        Text(verbatim: copyResolver.resolve(.catcherHold)).font(.footnote.weight(.semibold))
                        Text(verbatim: copyResolver.resolve(.catcherHoldBody))
                            .font(.caption2).foregroundStyle(BaseballTheme.textTertiary)
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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BaseballTheme.information)
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
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        // 노릴 곳만 말하고 피할 곳을 감추면, 실점을 가장 크게 가르는
                        // 정보의 절반이 화면 밖에 남는다. 강점 구종과 hot zone을 같이 적는다.
                        if let strength = report.estimatedStrength, let hot = report.estimatedHotZone {
                            Label(
                                copyResolver.resolve(.catcherScoutAvoid, arguments: [
                                    .userText(PitchCopy.localized(strength, resolver: copyResolver)),
                                    .userText(PitchCopy.localized(hot, batSide: session.batter.batSide, resolver: copyResolver)),
                                ]),
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BaseballTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("pitch.scouting.avoid")
                        }
                    }
                }

                if session.holdCall || (!matchesRecommendation && !matchesAlternative) {
                    Button(copyResolver.resolve(.catcherAccept)) { session.acceptCatcherRecommendation() }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("pitch.acceptCatcherCall")
                }
            }
        }
    }
}
