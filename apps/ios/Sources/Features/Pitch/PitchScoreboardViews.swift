import SwiftUI
import SimulationCore
import BaseballIOSDomain

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
                    .font(BaseballType.annotation.weight(.heavy))
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
                .font(BaseballType.detail.monospacedDigit())
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
                .font(BaseballType.annotation.weight(.heavy))
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
