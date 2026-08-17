import SwiftUI
import SimulationCore

// MARK: - 부품

/// 퍼펙트 릴리스가 방금 공의 결과 위에서 터지는 짧은 축하 레이어.
///
/// 입력 패드 안에 두면 SwiftUI가 같은 위치의 다음 DeliveryControl에 상태를 재사용한다. 화면
/// 오버레이로 분리하면 타석 종료로 footer가 사라져도 수명이 유지되고, 패드 문구와 겹치지 않는다.
struct PerfectReleaseCelebration: View {
    let title: String
    let reduceMotion: Bool

    @State private var progress: CGFloat = 0

    private var fadingOpacity: Double {
        let value = Double(progress)
        guard value > 0.82 else { return 1 }
        return max(0, (1 - value) / 0.18)
    }

    private var remainingOpacity: Double {
        max(0, 1 - Double(progress))
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(
                x: geometry.size.width / 2,
                y: min(max(geometry.size.height * 0.55, 220), geometry.size.height - 190)
            )

            ZStack {
                RadialGradient(
                    colors: [
                        BaseballTheme.milestone.opacity(reduceMotion ? 0.34 : 0.52 * remainingOpacity),
                        BaseballTheme.milestone.opacity(reduceMotion ? 0.1 : 0.14 * remainingOpacity),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 150
                )
                .frame(width: 300, height: 300)
                .position(center)

                if !reduceMotion {
                    Circle()
                        .stroke(BaseballTheme.milestone.opacity(0.9 * remainingOpacity), lineWidth: 4)
                        .frame(width: 82 + 190 * progress, height: 82 + 190 * progress)
                        .position(center)

                    Circle()
                        .stroke(
                            BaseballTheme.fieldChalk.opacity(0.62 * remainingOpacity),
                            style: StrokeStyle(lineWidth: 2, dash: [5, 7])
                        )
                        .frame(width: 52 + 122 * progress, height: 52 + 122 * progress)
                        .rotationEffect(.degrees(70 * Double(progress)))
                        .position(center)

                    ForEach(0..<8, id: \.self) { index in
                        Capsule()
                            .fill(BaseballTheme.milestone.opacity(0.86 * remainingOpacity))
                            .frame(width: 4, height: 20)
                            .offset(y: -58 - 42 * progress)
                            .rotationEffect(.degrees(Double(index) * 45))
                            .position(center)
                    }
                }

                Label {
                    Text(verbatim: title)
                } icon: {
                    Image(systemName: "target")
                }
                    .font(.title2.weight(.black))
                    .foregroundStyle(BaseballTheme.canvas)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(BaseballTheme.milestone, in: Capsule())
                    .overlay(Capsule().stroke(BaseballTheme.fieldChalk.opacity(0.7), lineWidth: 1))
                    .shadow(color: BaseballTheme.milestone.opacity(0.52), radius: 16)
                    .scaleEffect(reduceMotion ? 1 : 0.78 + 0.28 * progress)
                    .offset(y: reduceMotion ? 0 : -24 * progress)
                    .opacity(reduceMotion ? 1 : fadingOpacity)
                    .position(center)
                    .accessibilityLabel(Text(verbatim: title))
                    .accessibilityIdentifier("pitch.perfectEffect")
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            // 삽입 프레임을 먼저 그린 뒤 1로 보낸다. 0→1을 같은 트랜잭션에서 처리하면
            // SwiftUI가 시작 상태를 합쳐 버려 섬광이 아예 보이지 않을 수 있다.
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: PerfectReleaseFeedback.animationDuration)) {
                    progress = 1
                }
            }
        }
    }
}

/// 지금 경기가 어떤 상황인지.
///
/// 예전에는 이닝·볼카운트·주자·피로만 있었다. **점수가 없었다.** 야구에서 지금 이기고 있는지
/// 지고 있는지보다 중요한 정보는 없는데, 모델에는 `scoreDifferential`이 있으면서 화면에는
/// 나오지 않았다. 그래서 "8회 2아웃"을 봐도 이 공이 무거운지 가벼운지 판단할 수가 없었다.
///
/// 지금은 점수 차를 가장 크게 놓고, 그 아래에 이닝·아웃·볼카운트·주자를 붙인다. 그리고 이
/// 승부가 얼마나 중요한지(`leverage`)를 말로 한 줄 적는다 — 숫자는 사람에게 무게를 전달하지
/// 못한다.
struct ScoreboardBar: View {
    let session: PitchSession
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 점수 차를 읽는 말. 부호만으로는 어느 쪽이 앞서는지 헷갈린다.
    private var scoreText: String {
        let difference = session.context.scoreDifferential
        return switch difference {
        case 0: copyResolver.resolve(.scoreboardTied)
        case 1...: copyResolver.resolve(.scoreboardAhead, arguments: [.integer(difference)])
        default: copyResolver.resolve(.scoreboardBehind, arguments: [.integer(-difference)])
        }
    }

    private var scoreTone: Color {
        switch session.context.scoreDifferential {
        case 0: BaseballTheme.textPrimary
        case 1...: BaseballTheme.positive
        default: BaseballTheme.negative
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: scoreText)
                    .font(BaseballType.scoreboard)
                    .foregroundStyle(scoreTone)
                Text(verbatim: GameFormatters.inningLabel(
                    inning: session.context.inning,
                    language: copyResolver.language
                ))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
                // 아웃카운트는 숫자 대신 점으로. 야구 중계의 문법이고, 흘깃 봐도 읽힌다.
                CountPips(label: "OUT", filled: session.context.outs, total: 2, tone: BaseballTheme.negative)
                Spacer()
                // 중요도는 화면 맨 위 배지가 맡는다 — 같은 말을 두 줄에 적지 않는다.
            }
            HStack(spacing: 14) {
                CountPips(label: "B", filled: session.context.balls, total: 3, tone: BaseballTheme.warning)
                CountPips(label: "S", filled: session.context.strikes, total: 2, tone: BaseballTheme.action)
                // 주자는 다이아몬드 하나로만 두면 26pt짜리 회색 마름모 셋이라, 이 이닝이
                // 무사 만루인지 2사 주자 없음인지가 눈에 안 들어온다. 야구 팬이 실제로
                // 쓰는 말("2사 만루")을 그림 옆에 붙인다.
                RunnerDiamond(runners: session.gameState.runners)
                Text(verbatim: Self.situationLine(
                    outs: session.context.outs,
                    runners: session.gameState.runners,
                    language: copyResolver.language
                ))
                    .font(.footnote.weight(.heavy))
                    // 스코어보드는 한 줄 고정이다. 긴 로케일·큰 글자에서 상황 문구가
                    // 옆 요소를 밀어 화면 밖으로 나가느니 줄여서라도 한 줄에 남긴다.
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(session.gameState.runners.firstOccupied
                                     || session.gameState.runners.secondOccupied
                                     || session.gameState.runners.thirdOccupied
                                     ? BaseballTheme.warning : BaseballTheme.textSecondary)
                    .accessibilityHidden(true)
                Spacer()
                HStack(spacing: 6) {
                    Text(verbatim: copyResolver.resolve(.scoreboardFatigue)).eyebrowStyle(BaseballTheme.textTertiary)
                    Text("\(session.context.fatigue)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(
                            session.context.fatigue >= 70 ? BaseballTheme.warning : BaseballTheme.textSecondary
                        )
                }
            }
            // 이번 등판에서 내가 지금까지 한 것. 예전에는 이닝이 끝난 뒤에만 보여 줘서,
            // 던지는 동안에는 몇 개를 잡았고 몇 점을 줬는지 알 수 없었다. 선발로 6이닝을
            // 던지는 중이라면 그게 지금 가장 알고 싶은 숫자다.
            if session.pitches > 0 {
                Text(verbatim: session.hitByPitches > 0
                    ? copyResolver.resolve(.scoreboardLineWithHBP, arguments: [
                        .userText(GameFormatters.innings(outs: session.outsRecorded, language: copyResolver.language)),
                        .integer(session.strikeouts), .integer(session.walks), .integer(session.hitByPitches),
                        .integer(session.runsAllowed), .integer(session.pitches),
                    ])
                    : copyResolver.resolve(.scoreboardLine, arguments: [
                        .userText(GameFormatters.innings(outs: session.outsRecorded, language: copyResolver.language)),
                        .integer(session.strikeouts), .integer(session.walks),
                        .integer(session.runsAllowed), .integer(session.pitches),
                    ]))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textTertiary)
            }
            // 삼진 현수막 — 고교야구 백스톱에 K가 한 장씩 걸리듯 쌓인다.
            // 숫자 "3K"는 정보고, K·K·K는 자랑이다. 하나 잡을 때마다 줄이 자란다.
            if session.strikeouts > 0 {
                KBanner(count: session.strikeouts)
            }
        }
        .padding(.horizontal, BaseballMetrics.gutter)
        .padding(.vertical, 10)
        .background(BaseballTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(BaseballTheme.action.opacity(0.6)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    /// "2사 만루" 같은 한 마디. 야구를 아는 사람이 상황을 읽는 최소 단위다.
    static func situationLine(outs: Int, runners: BaserunnerStateSnapshot) -> String {
        let outsText = "\(min(2, max(0, outs)))사"
        let occupied = [runners.firstOccupied, runners.secondOccupied, runners.thirdOccupied]
        switch occupied {
        case [false, false, false]: return "\(outsText) 주자 없음"
        case [true, true, true]: return "\(outsText) 만루"
        default:
            let bases = zip(occupied, ["1루", "2루", "3루"])
                .filter(\.0).map(\.1).joined(separator: "·")
            return "\(outsText) \(bases)"
        }
    }

    static func situationLine(
        outs: Int,
        runners: BaserunnerStateSnapshot,
        language: AppLanguage
    ) -> String {
        guard language != .korean else { return situationLine(outs: outs, runners: runners) }
        let safeOuts = min(2, max(0, outs))
        let occupied = [runners.firstOccupied, runners.secondOccupied, runners.thirdOccupied]

        if language == .japanese {
            let runnerText: String
            switch occupied {
            case [false, false, false]: runnerText = "走者なし"
            case [true, true, true]: runnerText = "満塁"
            default:
                let bases = zip(occupied, ["一塁", "二塁", "三塁"])
                    .filter(\.0).map(\.1).joined(separator: "・")
                runnerText = "走者 \(bases)"
            }
            return "\(safeOuts)アウト・\(runnerText)"
        }

        let runnerText: String
        switch occupied {
        case [false, false, false]: runnerText = "bases empty"
        case [true, true, true]: runnerText = "bases loaded"
        default:
            let bases = zip(occupied, ["first", "second", "third"])
                .filter(\.0).map(\.1).joined(separator: " and ")
            runnerText = "runner on \(bases)"
        }
        return "\(safeOuts) \(safeOuts == 1 ? "out" : "outs") · \(runnerText)"
    }

    /// 문자열 연결이 길면 타입체커가 무너진다 — 조각을 배열로 모아 한 번에 붙인다.
    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append(copyResolver.resolve(.scoreboardAccessibility, arguments: [
            .userText(scoreText),
            .userText(GameFormatters.inningLabel(inning: session.context.inning, language: copyResolver.language)),
            .userText(Self.situationLine(outs: session.context.outs, runners: session.gameState.runners, language: copyResolver.language)),
            .integer(session.context.balls), .integer(session.context.strikes), .integer(session.context.fatigue),
            .userText(RunnerDiamond.voiceOverLabel(session.gameState.runners, language: copyResolver.language)),
        ]))
        parts.append(StakesBadge.localizedLabel(session.context.leverage, resolver: copyResolver))
        if session.pitches > 0 {
            parts.append(copyResolver.resolve(.scoreboardOuting, arguments: [
                .integer(session.strikeouts), .integer(session.walks), .integer(session.runsAllowed),
            ]))
        }
        return parts.joined(separator: ", ")
    }
}

/// 이 승부의 무게. 레버리지 숫자(0~1000)는 사람에게 아무 뜻도 전달하지 못한다 —
/// 등급 이름과 색, 그리고 채워지는 눈금 셋으로 옮긴다.
///
/// 이 배지가 화면 맨 위 경기 이름 옆에 있어야, 마운드에 오르기 전에 "이건 흘려도 되는
/// 이닝인가, 여기서 끝나는 이닝인가"가 정해진다. 무게를 모르면 전력투구를 언제 쓸지도 못 고른다.
struct StakesBadge: View {
    let leverage: Int
    @Environment(\.gameCopyResolver) private var copyResolver

    static func label(_ leverage: Int) -> String {
        switch leverage {
        case 900...: "여기서 끝난다"
        case 780..<900: "승부처"
        case 620..<780: "흐름이 갈린다"
        default: "일상적인 이닝"
        }
    }

    static func localizedLabel(_ leverage: Int, resolver: GameCopyResolver) -> String {
        let key: PitchUICopyKey = switch leverage {
        case 900...: .stakesMaximum
        case 780..<900: .stakesHigh
        case 620..<780: .stakesSwing
        default: .stakesRoutine
        }
        return resolver.resolve(key)
    }

    static func level(_ leverage: Int) -> Int {
        switch leverage {
        case 900...: 3
        case 780..<900: 2
        case 620..<780: 1
        default: 0
        }
    }

    private var tone: Color {
        switch Self.level(leverage) {
        case 3: BaseballTheme.negative
        case 2: BaseballTheme.milestone
        case 1: BaseballTheme.warning
        default: BaseballTheme.textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(verbatim: copyResolver.resolve(.stakesLabel)).font(.caption2.weight(.semibold)).foregroundStyle(BaseballTheme.textTertiary)
            Text(verbatim: Self.localizedLabel(leverage, resolver: copyResolver))
                .font(.caption.weight(.heavy))
                .foregroundStyle(tone)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < Self.level(leverage) ? tone : BaseballTheme.border.opacity(0.35))
                        .frame(width: 12, height: 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tone.opacity(Self.level(leverage) >= 2 ? 0.14 : 0.06),
                    in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copyResolver.resolve(
            .stakesAccessibility,
            arguments: [.userText(Self.localizedLabel(leverage, resolver: copyResolver))]
        ))
        .accessibilityIdentifier("pitch.stakes")
    }
}

struct CountPips: View {
    let label: String
    let filled: Int
    let total: Int
    let tone: Color

    var body: some View {
        HStack(spacing: 4) {
            // localization-safe: symbol
            Text(label).font(BaseballType.scoreboardLabel).foregroundStyle(BaseballTheme.textTertiary)
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? tone : BaseballTheme.border.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

struct RunnerDiamond: View {
    /// 보이스오버용 주자 설명. 시각 다이아몬드의 정보를 말로 옮긴다.
    static func voiceOverLabel(_ runners: BaserunnerStateSnapshot) -> String {
        var bases: [String] = []
        if runners.firstOccupied { bases.append("1루") }
        if runners.secondOccupied { bases.append("2루") }
        if runners.thirdOccupied { bases.append("3루") }
        return bases.isEmpty ? "없음" : bases.joined(separator: "·")
    }

    static func voiceOverLabel(_ runners: BaserunnerStateSnapshot, language: AppLanguage) -> String {
        guard language != .korean else { return voiceOverLabel(runners) }
        if language == .japanese {
            var bases: [String] = []
            if runners.firstOccupied { bases.append("一塁") }
            if runners.secondOccupied { bases.append("二塁") }
            if runners.thirdOccupied { bases.append("三塁") }
            return bases.isEmpty ? "なし" : bases.joined(separator: "、")
        }
        var bases: [String] = []
        if runners.firstOccupied { bases.append("first") }
        if runners.secondOccupied { bases.append("second") }
        if runners.thirdOccupied { bases.append("third") }
        return bases.isEmpty ? "none" : bases.joined(separator: ", ")
    }

    let runners: BaserunnerStateSnapshot

    var body: some View {
        ZStack {
            base(occupied: runners.secondOccupied).offset(y: -11)
            base(occupied: runners.thirdOccupied).offset(x: -11)
            base(occupied: runners.firstOccupied).offset(x: 11)
        }
        .frame(width: 34, height: 30)
        .accessibilityHidden(true)
    }

    private func base(occupied: Bool) -> some View {
        Rectangle()
            // 채워진 베이스는 위험 신호다. 이전의 마일스톤 금색은 "좋은 것"으로 읽혔다 —
            // 마운드에 선 사람에게 주자는 좋은 것이 아니다.
            .fill(occupied ? BaseballTheme.warning : BaseballTheme.border.opacity(0.3))
            .frame(width: 11, height: 11)
            .rotationEffect(.degrees(45))
    }
}

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

/// 이닝이 끝난 뒤의 분석. 무엇을 잘했고 무엇이 읽혔는지.
///
/// 커널이 최근 투구 창에서 이미 계산해 두는 값만 쓴다 — 새 난수를 소비하지 않는다.
struct PostgameAnalysisCard: View {
    let analysis: PostgameAnalysisSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.analysisTitle)) {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: copyResolver.resolve(.analysisSample, arguments: [
                    .userText(PitchCopy.localized(analysis.confidence, resolver: copyResolver)),
                    .integer(analysis.sampleSize),
                ]))
                    .eyebrowStyle(BaseballTheme.textTertiary)

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

                let pattern = PitchPresentation.analysisPattern(analysis, resolver: copyResolver)
                if !pattern.isEmpty {
                    Text(verbatim: pattern)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let growth = PitchPresentation.analysisGrowth(analysis, resolver: copyResolver)
                if !growth.isEmpty {
                    Text(verbatim: growth)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.positive)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !analysis.pitchBreakdowns.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(analysis.pitchBreakdowns, id: \.pitchType) { breakdown in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(verbatim: PitchCopy.localized(breakdown.pitchType, resolver: copyResolver))
                                    .font(.footnote.weight(.bold))
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
                                    .font(.caption.monospacedDigit())
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

struct StrikeZoneGrid: View {
    let selected: PitchZone
    let recommended: PitchZone
    /// 타자가 강한 칸·약한 칸. 격자에 칠해 두지 않으면 유저는 9칸을 매번 고민하면서도
    /// 무엇이 다른지 모른다. 추정이 없는 상황(스카우팅 리포트 없음)에서는 nil이다.
    var hotZone: PitchZone? = nil
    var coldZone: PitchZone? = nil
    /// 코스 이름을 읽어 줄 기준. 좌타자면 몸쪽·바깥쪽이 뒤집힌다.
    var batSide: BatSide = .right
    let onSelect: (PitchZone) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { column in
                            cell(row: row, column: column)
                        }
                    }
                }
            }
            // 표적 기호가 무엇을 뜻하는지 한 줄로 못 박는다. 아이콘만으로는 읽히지 않는다.
            Label(copyResolver.resolve(.zoneRecommended), systemImage: "target")
                .font(.caption)
                .foregroundStyle(BaseballTheme.information)
            if hotZone != nil || coldZone != nil {
                HStack(spacing: 10) {
                    Label(copyResolver.resolve(.zoneHot), systemImage: "square.fill")
                        .foregroundStyle(BaseballTheme.warning)
                    Label(copyResolver.resolve(.zoneCold), systemImage: "square.fill")
                        .foregroundStyle(BaseballTheme.positive)
                }
                .font(.caption2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(copyResolver.resolve(.zoneLegendAccessibility))
            }
        }
    }

    private func cell(row: Int, column: Int) -> some View {
        let zone = PitchZone(row: row, column: column)
        let isSelected = zone == selected
        let isRecommended = zone == recommended
        let isHot = zone == hotZone
        let isCold = zone == coldZone
        return Button {
            onSelect(zone)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? BaseballTheme.selection.opacity(0.35) : BaseballTheme.surfaceRaised)
                // 색은 선택 표시를 덮지 않을 만큼만 옅게 깐다 — 어느 칸을 골랐는지가 먼저다.
                if isHot || isCold {
                    RoundedRectangle(cornerRadius: 6)
                        .fill((isHot ? BaseballTheme.warning : BaseballTheme.positive).opacity(0.22))
                }
                if isRecommended {
                    Image(systemName: "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.information)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: BaseballMetrics.minimumTapTarget)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            PitchCopy.localized(zone, batSide: batSide, resolver: copyResolver)
                + (isRecommended ? copyResolver.resolve(.zoneCellRecommended) : "")
                + (isHot ? copyResolver.resolve(.zoneCellHot) : isCold ? copyResolver.resolve(.zoneCellCold) : "")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 값 몇 개 중 하나를 고르는 가로 줄. Picker보다 조작 영역이 크고 설명을 붙이기 쉽다.
struct OptionRow<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    let onSelect: (Item) -> Void
    let label: (Item) -> String

    /// 접근성 글자 크기에서는 가로 3분할이 "구종 이름 두 글자 + …"가 된다 —
    /// 결정부가 읽히지 않으면 게임이 잠긴다. AX 크기부터는 세로로 눕힌다(3차 패널 P1).
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        items: [Item],
        selection: Item,
        onSelect: @escaping (Item) -> Void,
        label: @escaping (Item) -> String
    ) {
        self.items = items
        self.selection = selection
        self.onSelect = onSelect
        self.label = label
    }

    var body: some View {
        layout {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    // localization-safe: resolved-copy
                    Text(label(item))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .background(
                    item == selection ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item == selection ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6), lineWidth: item == selection ? 2 : 1)
                }
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func layout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 6) { content() }
        } else {
            HStack(spacing: 6) { content() }
        }
    }
}

/// 방금 공의 위치 요약 — 3×3 존 위에 목표(점선 링)와 실제 도달점(점).
///
/// 승부 장면(PitchDramaView)은 1.6초 재생으로 흐르고 지나간다. "그래서 공이 어디로
/// 갔는데?"의 답이 화면 어디에도 남지 않아서, 존을 벗어난 공이 어느 쪽으로 얼마나
/// 빠졌는지 알 수 없었다. 이 미니맵은 결과 카드에 상시로 남는다.
struct ZoneMiniMap: View {
    let execution: PitchExecution
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Canvas { context, size in
            // 좌표계 ±800(존은 ±500). 존 밖 실투도 어느 쪽으로 빠졌는지 보인다.
            func place(_ x: Int, _ y: Int) -> CGPoint {
                let cx = min(780, max(-780, x))
                let cy = min(780, max(-780, y))
                return CGPoint(
                    x: size.width / 2 + CGFloat(cx) / 800 * size.width / 2,
                    y: size.height / 2 - CGFloat(cy) / 800 * size.height / 2
                )
            }
            let topLeft = place(-500, 500)
            let bottomRight = place(500, -500)
            let zone = CGRect(x: topLeft.x, y: topLeft.y,
                              width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
            context.fill(Path(zone), with: .color(BaseballTheme.fieldChalk.opacity(0.05)))
            context.stroke(Path(zone), with: .color(BaseballTheme.border), lineWidth: 1)
            for i in 1...2 {
                let x = zone.minX + zone.width * CGFloat(i) / 3
                let y = zone.minY + zone.height * CGFloat(i) / 3
                var vertical = Path(); vertical.move(to: CGPoint(x: x, y: zone.minY)); vertical.addLine(to: CGPoint(x: x, y: zone.maxY))
                var horizontal = Path(); horizontal.move(to: CGPoint(x: zone.minX, y: y)); horizontal.addLine(to: CGPoint(x: zone.maxX, y: y))
                context.stroke(vertical, with: .color(BaseballTheme.border.opacity(0.4)), lineWidth: 0.5)
                context.stroke(horizontal, with: .color(BaseballTheme.border.opacity(0.4)), lineWidth: 0.5)
            }
            // 목표 — 포수가 미트를 댄 자리.
            let target = place(execution.targetX, execution.targetY)
            context.stroke(
                Path(ellipseIn: CGRect(x: target.x - 5, y: target.y - 5, width: 10, height: 10)),
                with: .color(BaseballTheme.textTertiary),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )
            // 실제 — 공이 지나간 자리.
            let actual = place(execution.actualX, execution.actualY)
            let inZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
            context.fill(
                Path(ellipseIn: CGRect(x: actual.x - 4, y: actual.y - 4, width: 8, height: 8)),
                with: .color(inZone ? BaseballTheme.positive : BaseballTheme.warning)
            )
        }
        .frame(width: 64, height: 64)
        .background(BaseballTheme.fieldNight, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(
            copyResolver.resolve(
                abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500 ? .zoneMiniIn : .zoneMiniOut
            )
        )
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
                        Image(systemName: reward.icon).foregroundStyle(reward.tone)
                        Text(verbatim: reward.text)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(reward.tone)
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
