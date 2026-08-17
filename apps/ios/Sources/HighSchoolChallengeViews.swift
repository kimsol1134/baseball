import SwiftUI
import SimulationCore

// MARK: - Challenge 마감

/// challenge 모드의 끝 — 기록·계승 어디에도 반영되지 않는 판이므로 결과만 정직하게
/// 보여 주고 닫는다. 공유 카드의 "이 시드로 지명 가능?"에 대한 답이 이 화면이다.
struct ChallengeEndCard: View {
    let state: HighSchoolCareerSnapshot
    let onClose: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var outcomeTitle: String {
        HighSchoolPresentation.localizedChallengeOutcome(
            state.draftResult?.outcome,
            resolver: copyResolver
        )
    }

    var body: some View {
        let eyebrow = copyResolver.resolve(AppCopyKey.challengeEndEyebrow)
        let score = copyResolver.resolve(
            AppCopyKey.challengeEndScore,
            arguments: [.integer(state.draftResult?.evaluationScore ?? 0)]
        )
        let stats = copyResolver.resolve(
            AppCopyKey.challengeEndStats,
            arguments: [
                .integer(state.performance.importantGamesCompleted),
                .integer(state.performance.strikeouts),
                .integer(state.performance.walks),
                .integer(state.performance.runsAllowed),
            ]
        )
        let disclaimer = copyResolver.resolve(AppCopyKey.challengeEndDisclaimer)
        let closeAction = copyResolver.resolve(AppCopyKey.challengeEndCTA)
        let accessibility = copyResolver.resolve(
            AppCopyKey.challengeEndAccessibility,
            arguments: [
                .userText(eyebrow), .userText(outcomeTitle), .userText(score),
                .userText(stats), .userText(disclaimer),
            ]
        )
        let closeHint = copyResolver.resolve(AppCopyKey.challengeEndCloseHint)
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text(verbatim: eyebrow).eyebrowStyle(BaseballTheme.milestone)
            BaseballCard(title: outcomeTitle,
                         tone: state.draftResult?.outcome == .drafted ? .milestone : .raised) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: score)
                        .font(.title3.weight(.heavy).monospacedDigit())
                    Text(verbatim: stats)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            Text(verbatim: disclaimer)
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: closeAction, identifier: "hs.challenge.close", action: onClose)
                .accessibilityHint(Text(verbatim: closeHint))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: accessibility))
        .accessibilityIdentifier("hs.challenge.end")
    }
}
