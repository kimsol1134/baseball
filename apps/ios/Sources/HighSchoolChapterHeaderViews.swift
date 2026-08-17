import SwiftUI
import SimulationCore

// MARK: - 머리말

struct ChapterHeader: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int
    @State private var windExpanded = false
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 되돌릴 수 없는 순간에만 전용 그림을 준다. 나머지는 야간 구장 한 장으로 통일한다 —
    /// 모든 화면에 다른 그림이 있으면 어느 것도 특별하지 않다(DOC-19 §7.5).
    static func art(for phase: HighSchoolCareerPhase) -> KeyArt {
        switch phase {
        case .prologue: .careerIntro
        case .schoolSelection: .schoolCrossroads
        case .awakening: .awakening
        case .draft: .draftDay
        case .legacy: .reincarnation
        default: .stadiumNight
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.tightSpacing) {
            let chapterCopy = state.chapter.copyDescriptor
            let actTitle = copyResolver.resolve(chapterCopy.actTitleToken)
            let season = copyResolver.resolve(chapterCopy.seasonToken)
            let eyebrow = copyResolver.resolve(
                lifeNumber > 1 ? AppCopyKey.chapterHeaderEyebrowRepeat : AppCopyKey.chapterHeaderEyebrowFirst,
                arguments: lifeNumber > 1
                    ? [.integer(lifeNumber), .userText(actTitle), .integer(state.chapter.schoolYear), .userText(season)]
                    : [.userText(actTitle), .integer(state.chapter.schoolYear), .userText(season)]
            )
            KeyArtHeader(
                art: Self.art(for: state.phase),
                // 1회차에는 회차 표시를 하지 않는다. 처음 하는 사람에게 "1회차"는 아무 뜻이 없고,
                // 반복하는 게임이라는 사실은 한 번 죽어 봐야 의미가 생긴다.
                eyebrow: eyebrow,
                title: state.school.map {
                    copyResolver.resolve(
                        AppCopyKey.chapterHeaderTitle,
                        arguments: [
                            .userText(HighSchoolPresentation.localizedSchoolName(
                                $0, rawRegion: state.identity.region, resolver: copyResolver
                            )),
                            .userText(copyResolver.resolve(chapterCopy.titleToken)),
                        ]
                    )
                } ?? copyResolver.resolve(chapterCopy.titleToken)
            )
            HStack(spacing: 10) {
                // 주인공의 얼굴. 게임에서 가장 자주 보는 화면인데 정작 주인공이 없었다.
                // 1학년(챕터 1~3)은 앳된 얼굴, 2학년부터는 에이스 얼굴 — 성장이 눈에 보인다.
                PortraitView(seed: state.identity.portraitSeed, role: .player, size: 46,
                             playerStage: state.chapter.schoolYear <= 1 ? .freshman : .ace)
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricTeamTrust), value: "\(state.relationshipTrust)")
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricTraining), value: "\(state.totalTrainingsCompleted)")
            }
            if state.phase != .prologue {
                let wind = CareerWindPresentationCatalog.descriptor(for: state.careerWind)
                let windTitle = copyResolver.resolve(wind.titleToken)
                let windDetail = copyResolver.resolve(wind.detailToken)
                let effects = wind.effectDescriptors.map { copyResolver.resolve($0.token) }
                let windAction = copyResolver.resolve(
                    windExpanded ? AppCopyKey.chapterWindCollapse : AppCopyKey.chapterWindExpand
                )
                Button { windExpanded.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                        // localization-safe: resolved-copy
                        Text(windTitle)
                            .font(.caption.weight(.bold))
                        Spacer(minLength: 0)
                        Image(systemName: windExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(BaseballTheme.information)
                    .padding(.horizontal, 10)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .background(BaseballTheme.surfaceRaised, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.wind.chip")
                .accessibilityLabel(
                    copyResolver.resolve(
                        AppCopyKey.chapterWindAccessibility,
                        arguments: [.userText(windTitle), .userText(windAction)]
                    )
                )

                if windExpanded {
                    VStack(alignment: .leading, spacing: 3) {
                        // localization-safe: resolved-copy
                        Text(windDetail)
                        ForEach(Array(effects.enumerated()), id: \.offset) { _, effect in
                            Text(copyResolver.resolve(
                                AppCopyKey.chapterWindEffect,
                                arguments: [.userText(effect)]
                            ))
                        }
                        if effects.isEmpty {
                            Text(copyResolver.resolve(AppCopyKey.prologueWindNeutralExplanation))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// 직전 행동의 결과 한 줄. 매 단계 뜨는 서사 문구라 면을 두지 않는다.
///
/// 좌측 강조 레일을 쓰지 않는다. 이 배너는 화면을 넘길 때마다 뜨는 것이라, 왼쪽에 색 막대를
/// 세우면 그 장치가 게임 내내 반복되어 "어디서 본 듯한" 인상을 만든다(DOC-19 §7.2).
/// 좋고 나쁨은 눈썹 한 줄과 글자색으로만 알린다 — 카드가 쓰는 것과 같은 언어다.
struct SummaryBanner: View {
    let summary: String
    let cue: MobileCareerStore.FeedbackCue
    @Environment(\.gameCopyResolver) private var copyResolver

    private var accent: Color {
        switch cue {
        case .setback: BaseballTheme.negative
        case .growth: BaseballTheme.action
        case .success: BaseballTheme.positive
        case .neutral: BaseballTheme.textTertiary
        }
    }

    /// 무슨 일이 있었는지를 한 낱말로. 색만으로는 색각 이상이 있는 사람에게 전달되지 않는다.
    private var label: String {
        HighSchoolPresentation.localizedSummaryCue(cue, resolver: copyResolver)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // localization-safe: resolved-copy
            Text(label).eyebrowStyle(accent)
            // localization-safe: resolved-copy
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(summary)")
    }
}
