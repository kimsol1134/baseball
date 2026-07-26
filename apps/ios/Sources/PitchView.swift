import SwiftUI
import SimulationCore

enum PitchCopy {
    static let zoneLabels = [
        "높은 몸쪽", "높은 가운데", "높은 바깥쪽",
        "가운데 몸쪽", "가운데", "가운데 바깥쪽",
        "낮은 몸쪽", "낮은 가운데", "낮은 바깥쪽"
    ]

    static func zone(_ zone: PitchZone) -> String {
        let index = zone.row * 3 + zone.column
        return zoneLabels.indices.contains(index) ? zoneLabels[index] : "알 수 없는 코스"
    }

    static func pitch(_ type: PitchType) -> String {
        switch type {
        case .fourSeam: "포심"
        case .slider: "슬라이더"
        case .curveball: "커브"
        case .changeup: "체인지업"
        }
    }

    static func intent(_ intent: ZoneIntent) -> String {
        switch intent {
        case .strike: "존 안으로"
        case .edge: "존 경계"
        case .chase: "존 밖 유인"
        }
    }

    static func intentDetail(_ intent: ZoneIntent) -> String {
        switch intent {
        case .strike: "스트라이크 확률이 높고 맞을 위험도 함께 커집니다."
        case .edge: "경계를 노려 배트를 늦추지만 제구 난도가 높습니다."
        case .chase: "헛스윙을 노리는 대신 볼이 될 확률이 큽니다."
        }
    }

    static func intensity(_ intensity: PitchIntensity) -> String {
        switch intensity {
        case .controlled: "힘 빼고"
        case .normal: "보통"
        case .maxEffort: "전력"
        }
    }

    static func outcome(_ outcome: PitchOutcome) -> String {
        switch outcome {
        case .ball: "볼"
        case .calledStrike: "루킹 스트라이크"
        case .swingingStrike: "헛스윙"
        case .foul: "파울"
        case .inPlayOut: "인플레이 아웃"
        case .single: "안타"
        case .double: "2루타"
        case .triple: "3루타"
        case .homeRun: "홈런"
        case .hitByPitch: "몸에 맞는 공"
        }
    }

    static func plateResult(_ result: PlateAppearanceResult) -> String {
        switch result {
        case .strikeout: "삼진"
        case .walk: "볼넷"
        case .inPlayOut: "아웃"
        case .hit: "피안타"
        }
    }

    static func scoutBand(_ band: String) -> String {
        switch band {
        case "trusted": "확실한 분석"
        case "developing": "쌓이는 중"
        default: "아직 감"
        }
    }
}

/// 중요 경기 승부 화면. App Store 스크린샷의 주력 화면이다(계획 문서 §2.3).
struct PitchView: View {
    let session: PitchSession
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var replayProgress: Double = 1
    @AppStorage("baseball.pitch.autoRelease") private var autoRelease = false
    private var audio: GameAudio { .shared }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.scenario.headline).eyebrowStyle(BaseballTheme.milestone)
                Spacer()
            }
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .background(BaseballTheme.surface)
            ScoreboardBar(session: session)
            ScrollView {
                VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                    matchupCard
                    stage
                }
                .padding(BaseballMetrics.gutter)
            }
            footer
        }
        .background(BaseballTheme.canvas)
        // 스코어보드 바가 상단을 맡는다. 내비게이션 제목은 같은 정보를 두 번 말한다.
        .toolbar(.hidden, for: .navigationBar)
        // 승부 중에는 탭 바를 숨긴다. 이닝 중간에 다른 탭으로 빠져나가면 세션 상태가
        // 화면에서 사라지고, 주력 장면의 몰입도 끊긴다.
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: session.pitchLog.count) { _, _ in replay() }
        .onAppear {
            audio.start()
            audio.crowdIntensity = GameAudioMapping.crowdIntensity(leverage: session.scenario.leverage)
        }
        .onDisappear { audio.crowdIntensity = 0.15 }
    }

    // MARK: - 구성

    private var matchupCard: some View {
        BaseballCard(title: "타석", tone: .raised) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.batter.name).font(.headline)
                Text("공 맞히기 \(session.batter.contact) · 볼 고르기 \(session.batter.discipline) · 장타력 \(session.batter.power)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                Text(session.scenario.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var stage: some View {
        switch session.stage {
        case .failed(let message):
            BaseballCard(title: "승부를 진행할 수 없습니다", tone: .negative) {
                Text(message).font(.subheadline)
            }
        case .finished:
            resultSummary
        case .betweenBatters(let feedback):
            BaseballCard(title: "타석 종료", tone: .positive) {
                Text(feedback).font(.subheadline)
            }
            lastPitchPanel
        case .ready:
            if let preparation = session.preparation {
                lastPitchPanel
                CatcherCard(preparation: preparation, session: session)
                controls(preparation: preparation)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private var lastPitchPanel: some View {
        if let result = session.lastResult {
            VStack(alignment: .leading, spacing: 10) {
                PitchDramaView(
                    execution: result.snapshot.execution,
                    outcome: result.snapshot.outcome,
                    battedBall: result.snapshot.battedBall,
                    fielding: result.snapshot.fieldingResolution,
                    progress: replayProgress
                )
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .background(BaseballTheme.fieldNight, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))

                BaseballCard(title: PitchCopy.outcome(result.snapshot.outcome), tone: tone(for: result.snapshot.outcome)) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let verdict = session.lastDelivery.flatMap(DeliveryControl.verdict) {
                            Text(verdict.text)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(verdict.tone.accent)
                        }
                        Text(result.snapshot.shortFeedback).font(.subheadline.weight(.semibold))
                        Text(result.snapshot.detailFeedback).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        let execution = result.snapshot.execution
                        let inZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(String(format: "%.1f", Double(execution.velocityTenthsKPH) / 10))
                                .font(BaseballType.heroNumeral)
                                .foregroundStyle(BaseballTheme.action)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("km/h").eyebrowStyle(BaseballTheme.textTertiary)
                                Text(inZone ? "존 안" : "존 밖")
                                    .font(BaseballType.scoreboard)
                                    .foregroundStyle(inZone ? BaseballTheme.positive : BaseballTheme.warning)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: "이닝 종료", tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(session.pitches)구 · \(session.strikeouts)탈삼진 · \(session.walks)볼넷 · \(session.runsAllowed)실점")
                        .font(.title3.bold().monospacedDigit())
                    Text(session.actualDamage <= session.expectedDamage + 150
                        ? "구종과 코스를 고른 과정이 좋았다는 평가를 받습니다."
                        : "결과와 별개로 구종 순서를 다시 맞춰야 합니다.")
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            BaseballCard(title: "투구 기록") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(session.pitchLog) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(entry.pitchNumber)").font(.caption.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary).frame(width: 18, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(PitchCopy.pitch(entry.call.pitchType)) · \(PitchCopy.zone(entry.call.zone)) · \(PitchCopy.outcome(entry.outcome))")
                                    .font(.footnote.weight(.semibold))
                                Text(entry.shortFeedback).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder private func controls(preparation: PitchPreparation) -> some View {
        BaseballCard(title: "구종") {
            OptionRow(items: session.repertoire, selection: session.selectedPitchType) { type in
                session.selectedPitchType = type
            } label: { PitchCopy.pitch($0) }
        }

        BaseballCard(title: "코스 · \(PitchCopy.zone(session.selectedZone))") {
            StrikeZoneGrid(
                selected: session.selectedZone,
                recommended: preparation.primaryRecommendation.call.zone,
                onSelect: { session.selectedZone = $0 }
            )
        }

        BaseballCard(title: "노림") {
            VStack(alignment: .leading, spacing: 8) {
                OptionRow(items: ZoneIntent.allCases, selection: session.selectedIntent) { intent in
                    session.selectedIntent = intent
                } label: { PitchCopy.intent($0) }
                Text(PitchCopy.intentDetail(session.selectedIntent))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
        }

        BaseballCard(title: "힘 배분") {
            OptionRow(items: PitchIntensity.allCases, selection: session.selectedIntensity) { intensity in
                session.selectedIntensity = intensity
            } label: { PitchCopy.intensity($0) }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 8) {
            switch session.stage {
            case .ready:
                DeliveryControl(
                    fatigue: session.context.fatigue,
                    autoRelease: autoRelease,
                    onDeliver: { session.throwPitch(delivery: $0) },
                    onMeterEdge: { audio.play(.uiSelect) }
                )
            case .betweenBatters:
                PrimaryPill(title: "다음 타자", identifier: "pitch.nextBatter") {
                    session.advanceToNextBatter()
                }
            case .finished, .failed:
                PrimaryPill(title: "경기 결과 반영", identifier: "pitch.finish", action: onFinish)
            }
        }
        .padding(BaseballMetrics.gutter)
        .background(BaseballTheme.surface)
    }

    private func tone(for outcome: PitchOutcome) -> BaseballCardTone {
        switch outcome {
        case .swingingStrike, .calledStrike, .inPlayOut: .positive
        case .ball, .foul, .hitByPitch: .warning
        case .single, .double, .triple, .homeRun: .negative
        }
    }

    /// 승부 장면 재생. 릴리스 → 비행 → 스윙 → 임팩트 → 판정이 한 호흡에 들어가야 하므로
    /// 예전 0.75초로는 자리가 없다. 소리도 장면의 박자에 맞춰 나눠 낸다.
    private func replay() {
        guard !reduceMotion else {
            replayProgress = 1
            for cue in session.lastCues { audio.play(cue) }
            return
        }
        replayProgress = 0
        withAnimation(.linear(duration: 1.6)) { replayProgress = 1 }

        // 릴리스는 바로, 나머지는 공이 도착하는 순간(0.58 × 1.6초)에 맞춘다.
        let cues = session.lastCues
        if let release = cues.first { audio.play(release) }
        let impact = cues.dropFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            for cue in impact.prefix(2) { audio.play(cue) }
        }
        // 관중은 판정이 읽힌 뒤에 반응한다.
        if impact.count > 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                for cue in impact.dropFirst(2) { audio.play(cue) }
            }
        }
    }
}

// MARK: - 부품

/// 지금 경기가 어떤 상황인지.
///
/// 예전에는 이닝·볼카운트·주자·피로만 있었다. **점수가 없었다.** 야구에서 지금 이기고 있는지
/// 지고 있는지보다 중요한 정보는 없는데, 모델에는 `scoreDifferential`이 있으면서 화면에는
/// 나오지 않았다. 그래서 "8회 2아웃"을 봐도 이 공이 무거운지 가벼운지 판단할 수가 없었다.
///
/// 지금은 점수 차를 가장 크게 놓고, 그 아래에 이닝·아웃·볼카운트·주자를 붙인다. 그리고 이
/// 승부가 얼마나 중요한지(`leverage`)를 말로 한 줄 적는다 — 숫자는 사람에게 무게를 전달하지
/// 못한다.
private struct ScoreboardBar: View {
    let session: PitchSession

    /// 점수 차를 읽는 말. 부호만으로는 어느 쪽이 앞서는지 헷갈린다.
    private var scoreText: String {
        let difference = session.context.scoreDifferential
        return switch difference {
        case 0: "동점"
        case 1...: "\(difference)점 앞섬"
        default: "\(-difference)점 뒤짐"
        }
    }

    private var scoreTone: Color {
        switch session.context.scoreDifferential {
        case 0: BaseballTheme.textPrimary
        case 1...: BaseballTheme.positive
        default: BaseballTheme.negative
        }
    }

    /// 이 승부의 무게. 레버리지 숫자를 그대로 보여 주면 아무 뜻도 전달되지 않는다.
    private var stakes: String? {
        switch session.context.leverage {
        case 900...: "여기서 끝난다"
        case 780..<900: "승부처"
        case 620..<780: "흐름이 갈린다"
        default: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(scoreText)
                    .font(BaseballType.scoreboard)
                    .foregroundStyle(scoreTone)
                Text("\(session.context.inning)회 \(session.context.outs)아웃")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
                Spacer()
                if let stakes {
                    Text(stakes).eyebrowStyle(BaseballTheme.action)
                }
            }
            HStack(spacing: 14) {
                CountPips(label: "B", filled: session.context.balls, total: 3, tone: BaseballTheme.warning)
                CountPips(label: "S", filled: session.context.strikes, total: 2, tone: BaseballTheme.action)
                RunnerDiamond(runners: session.gameState.runners)
                Spacer()
                HStack(spacing: 6) {
                    Text("피로").eyebrowStyle(BaseballTheme.textTertiary)
                    Text("\(session.context.fatigue)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(
                            session.context.fatigue >= 70 ? BaseballTheme.warning : BaseballTheme.textSecondary
                        )
                }
            }
        }
        .padding(.horizontal, BaseballMetrics.gutter)
        .padding(.vertical, 10)
        .background(BaseballTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(BaseballTheme.action.opacity(0.6)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(scoreText). \(session.context.inning)회 \(session.context.outs)아웃, "
                + "볼 \(session.context.balls) 스트라이크 \(session.context.strikes), "
                + "피로 \(session.context.fatigue)"
                + (stakes.map { ". \($0)" } ?? "")
        )
    }
}

private struct CountPips: View {
    let label: String
    let filled: Int
    let total: Int
    let tone: Color

    var body: some View {
        HStack(spacing: 4) {
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

private struct RunnerDiamond: View {
    let runners: BaserunnerStateSnapshot

    var body: some View {
        ZStack {
            base(occupied: runners.secondOccupied).offset(y: -8)
            base(occupied: runners.thirdOccupied).offset(x: -8)
            base(occupied: runners.firstOccupied).offset(x: 8)
        }
        .frame(width: 26, height: 22)
        .accessibilityHidden(true)
    }

    private func base(occupied: Bool) -> some View {
        Rectangle()
            .fill(occupied ? BaseballTheme.milestone : BaseballTheme.border.opacity(0.35))
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
    }
}

private struct CatcherCard: View {
    let preparation: PitchPreparation
    let session: PitchSession

    private var matchesRecommendation: Bool {
        let call = preparation.primaryRecommendation.call
        return call.pitchType == session.selectedPitchType
            && call.zone == session.selectedZone
            && call.zoneIntent == session.selectedIntent
            && call.intensity == session.selectedIntensity
    }

    var body: some View {
        // 매 투구마다 뜨는 정보라 면을 두지 않는다(A안: 의미색이 붙은 것만 면을 갖는다).
        // 사인을 따르는지 여부는 눈썹 글자색으로만 알린다.
        BaseballCard(title: matchesRecommendation ? "포수 사인 · 사인대로" : "포수 사인 · 수정함") {
            VStack(alignment: .leading, spacing: 8) {
                let call = preparation.primaryRecommendation.call
                Text("\(PitchCopy.pitch(call.pitchType)) · \(PitchCopy.zone(call.zone)) · \(PitchCopy.intent(call.zoneIntent))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(matchesRecommendation ? BaseballTheme.positive : BaseballTheme.warning)
                Text(preparation.primaryRecommendation.shortReason)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let report = preparation.scoutingReport {
                    Divider()
                    Text("상대 분석 · \(PitchCopy.scoutBand(report.band))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BaseballTheme.information)
                    Text(report.band == "trusted"
                        ? "약점은 \(PitchCopy.pitch(report.estimatedWeakness)) · \(PitchCopy.zone(report.estimatedColdZone))로 굳어졌습니다."
                        : "아직 추정입니다. 약점은 \(PitchCopy.pitch(report.estimatedWeakness)) · \(PitchCopy.zone(report.estimatedColdZone)) 근처로 보입니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !matchesRecommendation {
                    Button("사인대로 맞추기") {
                        let call = preparation.primaryRecommendation.call
                        session.selectedPitchType = call.pitchType
                        session.selectedZone = call.zone
                        session.selectedIntent = call.zoneIntent
                        session.selectedIntensity = call.intensity
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                }
            }
        }
    }
}

struct StrikeZoneGrid: View {
    let selected: PitchZone
    let recommended: PitchZone
    let onSelect: (PitchZone) -> Void

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
            Label("포수가 요구한 코스", systemImage: "target")
                .font(.caption)
                .foregroundStyle(BaseballTheme.information)
        }
    }

    private func cell(row: Int, column: Int) -> some View {
        let zone = PitchZone(row: row, column: column)
        let isSelected = zone == selected
        let isRecommended = zone == recommended
        return Button {
            onSelect(zone)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? BaseballTheme.selection.opacity(0.35) : BaseballTheme.surfaceRaised)
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
        .accessibilityLabel(PitchCopy.zone(zone) + (isRecommended ? ", 포수 추천" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 값 몇 개 중 하나를 고르는 가로 줄. Picker보다 조작 영역이 크고 설명을 붙이기 쉽다.
private struct OptionRow<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    let onSelect: (Item) -> Void
    let label: (Item) -> String

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
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    Text(label(item))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
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
}
