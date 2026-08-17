import SwiftUI
import SimulationCore

struct ImportantGameIntro: View {
    let state: ProCareerSnapshot
    let onStart: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: state.level == .major ? .proStadiumTunnel : .stadiumNight,
                eyebrow: copyResolver.resolve(
                    .importantEyebrow,
                    arguments: [.integer(state.season), .integer(state.week)]
                ),
                title: state.level == .major
                    ? copyResolver.resolve(.importantMajorTitle)
                    : state.managerTrust < 55
                        ? copyResolver.resolve(.importantMinorOpportunityTitle)
                        : copyResolver.resolve(.importantMinorRoleTitle),
                accent: BaseballTheme.milestone
            )

            if let rival = state.currentRival {
                let rivalCopy = ProCareerPresentation.rival(rival, resolver: copyResolver)
                BaseballCard(title: copyResolver.resolve(.importantOpponent), tone: .milestone) {
                    HStack(alignment: .top, spacing: 10) {
                        // 고교 라이벌 카드와 같은 문법 — 상대에게 얼굴이 있어야 승부다.
                        PortraitView(seed: rival.name, role: .rival, size: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(rivalCopy.name) · \(rivalCopy.teamName)").font(.headline)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.profile).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            // localization-safe: resolved-copy
                            Text(rivalCopy.record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            BaseballCard(title: copyResolver.resolve(.importantMyStatus)) {
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.importantFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                    Metric(title: copyResolver.resolve(.importantManagerTrust), value: "\(state.managerTrust)")
                    Metric(title: copyResolver.resolve(.importantCatcherTrust), value: "\(state.catcherTrust)")
                }
            }

            Text(copyResolver.resolve(.importantBody))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)

            PrimaryPill(title: copyResolver.resolve(.importantAction), identifier: "pro.game.start", action: onStart)
        }
    }
}

/// 오프시즌 네 갈래.
///
/// 예전에는 "현재 구단에 남기" 하나였다. 코어는 잔류·군 복무·FA·은퇴를 전부 받는데
/// 화면이 하나만 냈으니, 한국 야구 커리어의 큰 갈림길 두 개(군 복무·FA)가 게임에
/// 존재하지 않았던 셈이다.
///
/// 자격은 화면이 먼저 계산해 잠근다. 못 누를 버튼을 내고 코어의 오류 문자열로 규칙을
