import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// 이닝이 끝난 뒤의 분석. 무엇을 잘했고 무엇이 읽혔는지.
///
/// 커널이 최근 투구 창에서 이미 계산해 두는 값만 쓴다 — 새 난수를 소비하지 않는다.
struct PostgameAnalysisCard: View {
    let analysis: PostgameAnalysisSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.analysisTitle)) {
            VStack(alignment: .leading, spacing: 12) {
                // 결과 한 줄이 먼저(성장 신호 또는 패턴 경고), 표본 크기와 숫자는 그 아래.
                let pattern = PitchPresentation.analysisPattern(analysis, resolver: copyResolver)
                let growth = PitchPresentation.analysisGrowth(analysis, resolver: copyResolver)
                if !growth.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BaseballTheme.positive)
                            .accessibilityHidden(true)
                        Text(verbatim: growth).proseLeadStyle()
                    }
                }
                if !pattern.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BaseballTheme.warning)
                            .accessibilityHidden(true)
                        Text(verbatim: pattern)
                            .proseLeadStyle()
                    }
                }
                Text(verbatim: copyResolver.resolve(.analysisSample, arguments: [
                    .userText(PitchCopy.localized(analysis.confidence, resolver: copyResolver)),
                    .integer(analysis.sampleSize),
                ]))
                    .font(BaseballType.annotation.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)

                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.analysisZoneRate), value: PitchCopy.rate(analysis.zoneRate))
                    Metric(title: copyResolver.resolve(.analysisWhiffRate), value: PitchCopy.rate(analysis.whiffRate), tone: .positive)
                    Metric(title: copyResolver.resolve(.analysisHardHitRate), value: PitchCopy.rate(analysis.hardHitRate), tone: .warning)
                }
                HStack(spacing: 10) {
                    Metric(title: copyResolver.resolve(.analysisCommand), value: "\(analysis.averageExecutionQuality)")
                    Metric(title: copyResolver.resolve(.analysisExpectedDamage), value: String(format: "%.2f", Double(analysis.expectedDamage) / 1_000))
                    Metric(
                        title: copyResolver.resolve(.analysisActualDamage),
                        value: String(format: "%.2f", Double(analysis.actualDamage) / 1_000),
                        tone: analysis.actualDamage > analysis.expectedDamage ? .negative : .positive
                    )
                }

                if !analysis.pitchBreakdowns.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(analysis.pitchBreakdowns, id: \.pitchType) { breakdown in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(verbatim: PitchCopy.localized(breakdown.pitchType, resolver: copyResolver))
                                    .font(BaseballType.detail.weight(.bold))
                                    .frame(width: 64, alignment: .leading)
                                Spacer(minLength: 4)
                                // 1구짜리 표본에 "0.0%"는 정보가 아니라 소음이다(QA P2-7).
                                Text(verbatim: breakdown.pitches < 5
                                     ? copyResolver.resolve(.analysisBreakdownSmall, arguments: [
                                        .integer(breakdown.pitches),
                                        .integer(breakdown.zoneRate * breakdown.pitches / 1_000),
                                        .integer(breakdown.pitches),
                                     ])
                                     : copyResolver.resolve(.analysisBreakdown, arguments: [
                                        .integer(breakdown.pitches), .userText(PitchCopy.rate(breakdown.zoneRate)),
                                        .userText(PitchCopy.rate(breakdown.whiffRate)),
                                        .userText(PitchCopy.rate(breakdown.hardHitRate)),
                                     ]))
                                    .font(BaseballType.annotation.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}

/// 삼진 현수막. 이번 등판에서 잡은 삼진이 K 한 장씩으로 걸린다 — 새 K는 튀어나오며 등장한다.
struct KBanner: View {
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(count, 12), id: \.self) { index in
                Text("K")
                    .font(BaseballType.strikeoutMark)
                    .foregroundStyle(index % 3 == 2 ? BaseballTheme.milestone : BaseballTheme.action)
                    .scaleEffect(index < shown ? 1 : 2.2)
                    .opacity(index < shown ? 1 : 0)
            }
            if count > 12 {
                Text("+\(count - 12)")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement()
        .accessibilityLabel(copyResolver.resolve(.strikeoutAccessibility, arguments: [.integer(count)]))
        .onAppear { shown = reduceMotion ? count : max(0, count - 1); pop() }
        .onChange(of: count) { _, _ in pop() }
    }

    private func pop() {
        guard !reduceMotion else { shown = count; return }
        // 새 K는 심판 콜이 끝난 뒤에 걸린다(슬로모 풀콜 최대 ~2.15초). 결과보다 빠른 자랑은 스포일러다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { shown = count }
        }
    }
}

/// 이닝 정산 — 획득이 한 줄씩 튀어나오며 걸린다.
///
/// 슬롯이 하나씩 열리는 정산은 로그라이트의 기본 문법이다: 무엇을 얻었는지가
/// 순서대로 몸에 걸려야 "이번 판이 남는 장사였는지"를 손이 기억한다.
struct InningSettlementCard: View {
    let session: PitchSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var revealed = 0

    /// 이 이닝이 남긴 것들. 커널 규칙(recordImportantGame의 전조 적립)과 같은 식이라
    /// 화면이 약속한 것과 코어가 주는 것이 어긋나지 않는다.
    private var rewards: [(icon: String, text: String, tone: Color)] {
        var items: [(String, String, Color)] = []
        if session.strikeouts > 0 {
            items.append(("flame.fill", copyResolver.resolve(
                .settlementStrikeouts,
                arguments: [.integer(session.strikeouts)]
            ), BaseballTheme.action))
        }
        if session.runsAllowed == 0 {
            items.append(("shield.fill", copyResolver.resolve(.settlementScoreless), BaseballTheme.positive))
        }
        let sparkGain = (session.runsAllowed == 0 || session.strikeouts >= 4 ? 2 : 0)
            + (session.actualDamage <= session.expectedDamage ? 1 : 0)
        if sparkGain > 0 {
            items.append(("sparkles", copyResolver.resolve(.settlementSpark, arguments: [.integer(sparkGain)]), BaseballTheme.milestone))
        }
        if session.consecutiveStrikeouts >= 3 {
            items.append(("bolt.fill", copyResolver.resolve(
                .settlementStrikeoutStreak,
                arguments: [.integer(session.consecutiveStrikeouts)]
            ), BaseballTheme.milestone))
        }
        if session.sequenceMasteryCount > 0 {
            var seen = Set<PitchSequenceTag>()
            let tagTitles = session.sequenceMoments.compactMap { moment -> String? in
                seen.insert(moment.tag).inserted
                    ? PitchPresentation.sequenceTitle(moment.tag, resolver: copyResolver)
                    : nil
            }
            items.append((
                "brain.head.profile",
                copyResolver.resolve(.settlementSequence, arguments: [
                    .integer(session.sequenceMasteryCount),
                    .userText(tagTitles.joined(separator: " · ")),
                ]),
                BaseballTheme.information
            ))
        }
        if items.isEmpty {
            items.append(("book.fill", copyResolver.resolve(.settlementNextLesson), BaseballTheme.textSecondary))
        }
        return items
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.settlementTitle), tone: .raised) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rewards.enumerated()), id: \.offset) { index, reward in
                    HStack(spacing: 8) {
                        // 색은 아이콘에만. 획득 문장 전체를 칠하면 줄마다 다른 색 글씨가 된다.
                        Image(systemName: reward.icon).foregroundStyle(reward.tone)
                        Text(verbatim: reward.text)
                            .proseLeadStyle()
                        Spacer(minLength: 0)
                    }
                    .scaleEffect(index < revealed ? 1 : 0.7, anchor: .leading)
                    .opacity(index < revealed ? 1 : 0)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { revealed = rewards.count; return }
            for index in 0..<rewards.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + 0.45 * Double(index)) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { revealed = index + 1 }
                    if index > 0 { Haptics.shared.outcome(success: true) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
