import SwiftUI
import SimulationCore
import BaseballIOSDomain

// MARK: - 머리말

struct ChapterHeader: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int
    /// 고교 3년 내내 보이는 드래프트 거리. nil이면 줄을 그리지 않는다.
    var forecast: DraftForecastSnapshot? = nil
    /// 국면 화면이 자기 키아트를 그릴 때(각성) 머리말은 눈썹+제목 한 덩어리로 줄인다 —
    /// 그림 두 장이 겹쳐 서면 어느 쪽도 무대가 아니다.
    var compact = false
    var onForecastTap: (() -> Void)? = nil
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
            let title = state.school.map {
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
            if compact {
                VStack(alignment: .leading, spacing: 4) {
                    // localization-safe: resolved-copy
                    Text(eyebrow).eyebrowStyle(BaseballTheme.action)
                    // localization-safe: resolved-copy
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("hs.chapter.header.compact")
            } else {
            KeyArtHeader(
                art: Self.art(for: state.phase),
                // 1회차에는 회차 표시를 하지 않는다. 처음 하는 사람에게 "1회차"는 아무 뜻이 없고,
                // 반복하는 게임이라는 사실은 한 번 죽어 봐야 의미가 생긴다.
                eyebrow: eyebrow,
                title: title
            )
            HStack(alignment: .top, spacing: 10) {
                // 주인공의 얼굴. 게임에서 가장 자주 보는 화면인데 정작 주인공이 없었다.
                // 1학년(챕터 1~3)은 앳된 얼굴, 2학년부터는 에이스 얼굴 — 성장이 눈에 보인다.
                PortraitView(seed: state.identity.portraitSeed, role: .player, size: 46,
                             playerStage: state.chapter.schoolYear <= 1 ? .freshman : .ace)
                Metric(
                    title: copyResolver.resolve(AppCopyKey.chapterMetricFatigue),
                    value: "\(state.fatigue)",
                    tone: CareerDisplayRules.highSchoolFatigueBand(fatigue: state.fatigue) == .normal
                        ? .standard : .warning,
                    caption: copyResolver.resolve(
                        CareerDisplayRules.highSchoolFatigueBand(fatigue: state.fatigue).copyKey
                    )
                )
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricTeamTrust), value: "\(state.relationshipTrust)")
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricTraining), value: "\(state.totalTrainingsCompleted)")
            }
            // 드래프트 거리는 1학년 봄부터 보인다. 3년을 닫고 나서야 "당락선 66"을
            // 처음 보면 지명 실패가 허무하다(페르소나 보고서 §2-3, §4-2).
            if state.phase != .prologue, let forecast {
                Button(action: { onForecastTap?() }) {
                    EffectChip(
                        text: copyResolver.resolve(
                            AppCopyKey.chapterHeaderDraftForecast,
                            arguments: [.integer(forecast.score), .integer(forecast.threshold)]
                        ),
                        tone: Self.forecastTone(score: forecast.score, threshold: forecast.threshold),
                        systemImage: "flag.checkered"
                    )
                }
                .buttonStyle(.plain)
                .disabled(onForecastTap == nil)
                .accessibilityIdentifier("hs.chapter.draftForecast")
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
                    .detailStyle()
                    .accessibilityElement(children: .combine)
                }
            }
            }
        }
    }

    /// 당락선 위면 이득, 10점 안쪽이면 비용(아직 닿을 수 있다), 그 아래면 위험.
    static func forecastTone(score: Int, threshold: Int) -> EffectChip.Tone {
        if score >= threshold { return .gain }
        if score >= threshold - 10 { return .cost }
        return .risk
    }
}

/// 직전 행동의 결과 한 줄. 매 단계 뜨는 서사 문구라 면을 두지 않는다.
///
/// 좌측 강조 레일을 쓰지 않는다. 이 배너는 화면을 넘길 때마다 뜨는 것이라, 왼쪽에 색 막대를
/// 세우면 그 장치가 게임 내내 반복되어 "어디서 본 듯한" 인상을 만든다(DOC-19 §7.2).
/// 좋고 나쁨은 눈썹 한 줄과 글자색으로만 알린다 — 카드가 쓰는 것과 같은 언어다.
struct SummaryBanner: View {
    let summary: String
    let cue: FeedbackCue
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
        // "성과 / 결과 한 줄"처럼 눈썹이 본문보다 많던 화면을 줄인다(1.2.9 가독성 교정).
        // 중립이면 문장만, 좋고 나쁨이 있으면 낱말 하나를 색으로 앞에 붙인다.
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if cue != .neutral {
                // localization-safe: resolved-copy
                Text(verbatim: "\(label) ·")
                    .font(BaseballType.annotation.weight(.bold))
                    .foregroundStyle(accent)
            }
            // localization-safe: resolved-copy
            Text(summary)
                .detailStyle(BaseballTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(summary)")
    }
}
