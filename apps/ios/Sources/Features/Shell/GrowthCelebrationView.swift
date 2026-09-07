import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// 능력이 올랐을 때만 나타나는 성장 카드. 올라간 값과 "다음 단계까지 얼마"를 함께 보여 줘서
/// 숫자 증가가 무슨 뜻인지 사다리 위에서 읽히게 한다.
enum GrowthStageContext {
    case highSchool
    case pro
}

struct GrowthCelebrationView: View {
    let gains: [AbilityGain]
    var jackpot: Bool = false
    var stageContext: GrowthStageContext = .highSchool
    var fatigue: Int? = nil
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var showsDetails = false
    @State private var appeared = false
    private var milestone: AbilityGain? { gains.first { $0.ability == .command && PitchReleaseWindow.crossesMilestone(before: $0.before, after: $0.after) } }
    private var primary: AbilityGain? { milestone ?? gains.max { ($0.after - $0.before) < ($1.after - $1.before) } }
    private var notable: Bool { milestone != nil || jackpot }
    private var accent: Color { notable ? BaseballTheme.milestone : BaseballTheme.action }
    private var headline: String {
        if milestone != nil { return copyResolver.resolve(.localizable("loop.growth.milestone")) }
        guard let primary else { return copyResolver.resolve(.growthTitle) }
        return copyResolver.resolve(.localizable("loop.growth.row"), arguments: [.userText(copyResolver.resolve(primary.ability.displayCopyToken)),
            .integer(AbilityDisplayScale.displayRating(primary.before)), .integer(AbilityDisplayScale.displayRating(primary.after))])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: notable ? "sparkles" : "arrow.up.right").foregroundStyle(accent).accessibilityHidden(true)
                Text(verbatim: headline).font(notable ? .title3.weight(.bold) : .headline).foregroundStyle(accent)
                Spacer(minLength: 0)
                Button(copyResolver.resolve(.growthClose), action: onDismiss).frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
            if let milestone { ControlWindowPreview(command: milestone.after, beforeCommand: milestone.before, showsLegend: false, titleKey: "loop.growth.base-window") }
            if jackpot { Text(verbatim: copyResolver.resolve(.growthJackpotTitle)).font(BaseballType.annotation).foregroundStyle(BaseballTheme.milestone) }
            if let fatigue { Text(verbatim: GrowthConditionCopy.line(fatigue: fatigue, change: 0, resolver: copyResolver)).detailStyle() }
            Button(copyResolver.resolve(.localizable("mobile.core.growth-details"))) { showsDetails.toggle() }
                .font(BaseballType.annotation).frame(minHeight: BaseballMetrics.minimumTapTarget)
            if showsDetails {
                ForEach(gains) { gain in
                    Text(verbatim: HighSchoolPresentation.localizedTrainingGainRow(gain, resolver: copyResolver)).detailStyle()
                }
                if milestone == nil, let command = gains.first(where: { $0.ability == .command }) {
                    ControlWindowPreview(command: command.after, beforeCommand: command.before, titleKey: "loop.growth.base-window")
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(notable ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surface,
            in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
        .opacity(appeared || reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(notable && !reduceMotion ? .easeOut(duration: 0.3) : nil) { appeared = true }
            if notable { GameAudio.shared.play(.milestone) }
        }
        .accessibilityElement(children: .contain)
    }
}
