import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// 모든 플레이어에게 보이는 한 줄 성장 피드백. 훈련에서 올린 수치가 지금 고른 공의
/// 구속·움직임·코스·부담으로 어떻게 번역됐는지 스크롤을 늘리지 않고 알려 준다.
struct PitchBuildCompactReadoutView: View {
    let readout: PitchAbilityReadout
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: copyResolver.resolve(.buildCompact, arguments: [
                .userText(GameFormatters.velocity(
                    tenthsKPH: readout.nominalVelocityTenthsKPH,
                    language: copyResolver.language
                )),
                .integer(readout.movementRating), .integer(readout.commandRating),
                .integer(readout.effectiveFatigue),
            ]))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(BaseballTheme.milestone)
            Text(verbatim: PitchBuildCopy.localizedSynergy(readout, resolver: copyResolver))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(PitchBuildCopy.localizedAccessibilitySummary(readout, resolver: copyResolver))
        .accessibilityIdentifier("pitch.buildSummary")
    }
}

/// QA 플래그에서 여는 상세 수치. 제품 화면은 위의 한 줄 요약만 항상 보여 준다.
/// 별도 카드 면을 더 만들지 않고 구종 카드 안에 들어가 결정 흐름을 늘리지 않는다.
struct PitchBuildReadoutView: View {
    let readout: PitchAbilityReadout
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                GridRow {
                    metric(copyResolver.resolve(.buildVelocity), GameFormatters.velocity(
                        tenthsKPH: readout.nominalVelocityTenthsKPH,
                        language: copyResolver.language
                    ))
                    metric(copyResolver.resolve(.buildCommandMetric), "\(readout.commandRating)")
                }
                GridRow {
                    metric(copyResolver.resolve(.buildMovementMetric), "\(readout.movementRating)")
                    metric(copyResolver.resolve(.buildStaminaMetric), "\(readout.staminaRating) · \(readout.effectiveFatigue)")
                }
            }
            Text(verbatim: copyResolver.resolve(.buildFatigueCost, arguments: [
                .integer(readout.fatigueCost),
                .userText(PitchBuildCopy.localizedSynergy(readout, resolver: copyResolver)),
            ]))
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PitchBuildCopy.localizedAccessibilitySummary(readout, resolver: copyResolver))
        .accessibilityIdentifier("pitch.buildReadout")
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(verbatim: label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
            Text(verbatim: value)
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(BaseballTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 상세 수치 그리드만 여는 QA 관문. 핵심 성장 피드백은 한 줄 요약과 결과 배지로 항상 보이며,
/// 이 플래그는 작은 화면에서 상세 그리드까지 함께 펼쳤을 때의 레이아웃을 검증한다.
enum PitchAbilityFeedbackExperiment {
    static var isVisible: Bool {
        ProcessInfo.processInfo.arguments.contains(BaseballApp.pitchAbilityFeedbackLaunchArgument)
    }
}

/// 타자가 내 투구를 얼마나 읽었는가.
///
/// 커널이 매 투구마다 계산하는데 iOS 화면에는 없었다. 그래서 "같은 공을 반복하면 읽힌다"는
/// 이 게임의 전략적 정체성을 플레이어가 **존재조차 알 수 없었고**, 투구가 "324개 중 하나
/// 고르기"로 남아 반복 플레이의 학습 곡선이 생기지 않았다(품질 평가 §4.1, 결격 5).
///
/// 매 투구 위에 뜨는 것이라 카드 면을 두지 않는다. 막대 하나와 경고 한 줄이면 된다.
struct AdaptationBar: View {
    let adaptation: RivalAdaptationSnapshot
    let batSide: BatSide
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 적응도는 0–900 눈금이다.
    private var progress: Double { min(1, Double(adaptation.level) / 900) }
    private var warning: String {
        PitchPresentation.adaptationWarning(adaptation, batSide: batSide, resolver: copyResolver)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: copyResolver.resolve(.adaptationTitle)).eyebrowStyle(BaseballTheme.textTertiary)
                Spacer()
                Text(verbatim: PitchCopy.localized(adaptation.band, resolver: copyResolver))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PitchCopy.adaptationTone(adaptation.band))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    Capsule()
                        .fill(PitchCopy.adaptationTone(adaptation.band))
                        .frame(width: max(2, proxy.size.width * progress))
                }
            }
            .frame(height: 6)
            if !warning.isEmpty {
                Text(verbatim: warning)
                    .font(.caption)
                    .foregroundStyle(PitchCopy.adaptationTone(adaptation.band))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copyResolver.resolve(.adaptationAccessibility, arguments: [
            .userText(PitchCopy.localized(adaptation.band, resolver: copyResolver)),
            .userText(warning),
        ]))
    }
}
