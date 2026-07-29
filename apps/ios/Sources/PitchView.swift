import SwiftUI
import SimulationCore

enum PitchCopy {
    static let zoneLabels = [
        "높은 몸쪽", "높은 가운데", "높은 바깥쪽",
        "가운데 몸쪽", "가운데", "가운데 바깥쪽",
        "낮은 몸쪽", "낮은 가운데", "낮은 바깥쪽"
    ]

    /// 코스 이름. **몸쪽·바깥쪽은 타자 기준이라 좌타자에게는 뒤집힌다.**
    ///
    /// 라벨 표가 우타 기준으로 고정돼 있었다. 좌타자를 상대할 때 화면은 몸쪽을 바깥쪽이라
    /// 부르고 있었고, 이 게임에서 코스는 판정의 절반이라 그 표기가 틀리면 플레이어가
    /// 배우는 규칙 자체가 틀린다.
    static func zone(_ zone: PitchZone, batSide: BatSide = .right) -> String {
        let column = batSide == .left ? 2 - zone.column : zone.column
        let index = zone.row * 3 + column
        return zoneLabels.indices.contains(index) ? zoneLabels[index] : "알 수 없는 코스"
    }

    /// 타석에 선 쪽. 좌우 플래툰은 커널이 이미 계산하는데 화면에 표기가 없었다.
    static func batSide(_ side: BatSide) -> String {
        side == .left ? "좌타" : "우타"
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

    /// 노림 설명은 코스에 따라 달라진다.
    ///
    /// "볼 유도"를 한복판에서 고르면 공은 낮은 쪽으로 빠진다 — 커널이 그렇게 던진다.
    /// 화면이 그 말을 안 하면 플레이어는 한복판에 볼을 던진다고 읽는다.
    static func intentDetail(_ intent: ZoneIntent, zone: PitchZone) -> String {
        switch intent {
        case .strike: "스트라이크 확률이 높고 맞을 위험도 함께 커집니다."
        case .edge: "경계를 노려 배트를 늦추지만 제구 난도가 높습니다."
        case .chase:
            ZoneIntent.options(for: zone).count == 2
                ? "한복판에서는 낮은 쪽으로 빼는 공이 됩니다. 헛스윙을 노리는 대신 볼이 될 확률이 큽니다."
                : "고른 코스 바깥으로 빼서 헛스윙을 노리는 대신 볼이 될 확률이 큽니다."
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

    /// 손으로 구분할 결과. `nil`이면 진동하지 않는다.
    ///
    /// 파울과 볼은 아무것도 결정하지 않은 공이다. 매 투구마다 울리면 진동은 신호가 아니라
    /// 소음이 되고, 정말 중요한 공(삼진·피안타)에서 손이 알아채지 못한다.
    static func hapticSuccess(_ outcome: PitchOutcome) -> Bool? {
        switch outcome {
        case .calledStrike, .swingingStrike, .inPlayOut: true
        case .single, .double, .triple, .homeRun, .hitByPitch: false
        case .ball, .foul: nil
        }
    }

    /// 타자가 내 투구를 얼마나 읽었는가. 이 게임의 전략적 정체성("같은 공을 반복하면
    /// 읽힌다")인데 iOS에는 이 값이 화면에 한 번도 나오지 않았다.
    static func adaptation(_ band: RivalAdaptationBand) -> String {
        switch band {
        case .noData: "아직 못 읽음"
        case .watching: "지켜보는 중"
        case .learning: "읽어 가는 중"
        case .lockedOn: "완전히 읽힘"
        }
    }

    static func adaptationTone(_ band: RivalAdaptationBand) -> Color {
        switch band {
        case .noData, .watching: BaseballTheme.positive
        case .learning: BaseballTheme.warning
        case .lockedOn: BaseballTheme.negative
        }
    }

    static func confidence(_ band: AnalysisConfidenceBand) -> String {
        switch band {
        case .low: "표본이 적습니다"
        case .developing: "쌓이는 중"
        case .reliable: "믿을 만합니다"
        }
    }

    /// 천분율을 백분율 문구로. 코어는 전부 ‰로 준다.
    static func rate(_ permille: Int) -> String {
        String(format: "%.1f%%", Double(permille) / 10)
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
            // 던진 뒤 결과로 저절로 올라간다.
            //
            // 와인드업 패드는 화면 맨 아래에 있고 승부 장면은 그 위에 있다. 손을 떼는
            // 순간 결과가 화면 밖에서 재생돼서, 스크롤을 직접 올려야 무슨 일이 있었는지
            // 볼 수 있었다. 던지는 자리와 보는 자리가 다르면 손맛이 성립하지 않는다.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        matchupCard
                        stage
                    }
                    .padding(BaseballMetrics.gutter)
                }
                .onChange(of: session.pitchLog.count) { _, count in
                    guard count > 0 else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
                        proxy.scrollTo(Self.dramaAnchor, anchor: .top)
                    }
                    // 결과를 본 다음에는 **결정하는 자리로 되돌린다.**
                    //
                    // 예전에는 승부 장면에서 멈췄다. 배합을 바꾸려면 매번 스크롤을 내려야
                    // 했고, 그래서 적응 경고("같은 공이 읽히고 있습니다")를 보고도 그 자리에서
                    // 손을 쓸 수 없었다 — 경고를 보고 배합을 바꾸는 것이 이 게임의 학습
                    // 루프인데 그 두 동작 사이에 스크롤이 끼어 있었다.
                    let delay = reduceMotion ? 0.0 : 1.7
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        guard case .ready = session.stage else { return }
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                            proxy.scrollTo(Self.controlsAnchor, anchor: .top)
                        }
                    }
                }
            }
            footer
        }
        .background(BaseballTheme.canvas)
        // 스코어보드 바가 상단을 맡는다. 내비게이션 제목은 같은 정보를 두 번 말한다.
        .toolbar(.hidden, for: .navigationBar)
        // 승부 중에는 탭 바를 숨긴다. 이닝 중간에 다른 탭으로 빠져나가면 세션 상태가
        // 화면에서 사라지고, 주력 장면의 몰입도 끊긴다.
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: session.pitchLog.count) { _, _ in
            replay()
            // 결과를 손으로도 알려 준다. 화면을 안 보고 있어도 방금 그 공이 잡은 공인지
            // 맞은 공인지 구분된다.
            if let outcome = session.lastResult?.snapshot.outcome,
               let success = PitchCopy.hapticSuccess(outcome) {
                Haptics.shared.outcome(success: success)
            }
        }
        .onAppear {
            audio.start()
            audio.crowdIntensity = GameAudioMapping.crowdIntensity(leverage: session.scenario.leverage)
            // 마운드에서는 관중과 심판이 음악이다. 패드는 화면을 나갈 때 돌아온다.
            audio.musicIntensity = 0
        }
        .onDisappear {
            audio.crowdIntensity = 0.15
            audio.musicIntensity = 0.5
        }
    }

    // MARK: - 구성

    private var matchupCard: some View {
        BaseballCard(title: "타석", tone: .raised) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(session.batter.name).font(.headline)
                    Text(PitchCopy.batSide(session.batter.batSide))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BaseballTheme.actionInk)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(BaseballTheme.action, in: Capsule())
                }
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
            // 이닝을 끝낸 공도 장면부터 보여 준다.
            //
            // 예전에는 `.finished`에서 곧바로 정리 화면으로 갈아 끼웠다. 마지막 아웃을 잡은
            // 공은 **화면에 한 번도 나오지 않고** 사라졌다 — 가장 중요한 한 구가 유일하게
            // 보이지 않는 공이었다. 타석이 이어질 때와 같은 순서(장면 → 정리)로 맞춘다.
            lastPitchPanel
            resultSummary
        case .betweenBatters(let feedback):
            lastPitchPanel
            BaseballCard(title: "타석 종료", tone: .positive) {
                Text(feedback).font(.subheadline)
            }
        case .ready:
            if let preparation = session.preparation {
                lastPitchPanel
                AdaptationBar(adaptation: preparation.rivalAdaptation)
                    .id(Self.controlsAnchor)
                CatcherCard(preparation: preparation, session: session)
                controls(preparation: preparation)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    /// 던진 뒤 이 지점으로 스크롤한다.
    static let dramaAnchor = "pitch.drama"
    /// 결과를 보고 난 뒤 되돌아오는 지점. 다음 배합을 고르는 자리다.
    static let controlsAnchor = "pitch.controls"

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
                // 홈런과 이닝을 끝낸 삼진에만 스탬프가 찍힌다. 이 장면이 곧 공유용
                // 스크린샷이다. 매 공마다 찍으면 그건 스탬프가 아니라 배경이 된다.
                .overlay {
                    if let kind = HighlightStamp.kind(
                        outcome: result.snapshot.outcome,
                        plateResult: result.snapshot.result,
                        inningEnded: result.snapshot.inningTransition?.inningEnded ?? false,
                        landingDistanceTenthsMeters: result.snapshot.fieldingResolution?.landingDistanceTenthsMeters
                    ) {
                        HighlightStamp(kind: kind, velocityTenthsKPH: result.snapshot.execution.velocityTenthsKPH)
                            .id(result.snapshot.revision)
                    }
                }
                .id(Self.dramaAnchor)

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
            if let analysis = session.lastResult?.postgameAnalysis {
                PostgameAnalysisCard(analysis: analysis)
            }
            BaseballCard(title: "투구 기록") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(session.pitchLog) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(entry.pitchNumber)").font(.caption.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary).frame(width: 18, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(PitchCopy.pitch(entry.call.pitchType)) · \(PitchCopy.zone(entry.call.zone, batSide: session.batter.batSide)) · \(PitchCopy.outcome(entry.outcome))")
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

        BaseballCard(title: "코스 · \(PitchCopy.zone(session.selectedZone, batSide: session.batter.batSide))") {
            StrikeZoneGrid(
                selected: session.selectedZone,
                recommended: preparation.primaryRecommendation.call.zone,
                batSide: session.batter.batSide,
                onSelect: { zone in
                    session.selectedZone = zone
                    // 한복판으로 옮기면 "존 경계"는 뜻을 잃는다. 고른 채로 두면 아무 일도
                    // 하지 않는 노림으로 던지게 되므로 성립하는 노림으로 되돌린다.
                    session.selectedIntent = ZoneIntent.clamped(session.selectedIntent, for: zone)
                }
            )
        }

        BaseballCard(title: "노림") {
            VStack(alignment: .leading, spacing: 8) {
                OptionRow(items: ZoneIntent.options(for: session.selectedZone), selection: session.selectedIntent) { intent in
                    session.selectedIntent = intent
                } label: { PitchCopy.intent($0) }
                Text(PitchCopy.intentDetail(session.selectedIntent, zone: session.selectedZone))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            // 이번 등판에서 내가 지금까지 한 것. 예전에는 이닝이 끝난 뒤에만 보여 줘서,
            // 던지는 동안에는 몇 개를 잡았고 몇 점을 줬는지 알 수 없었다. 선발로 6이닝을
            // 던지는 중이라면 그게 지금 가장 알고 싶은 숫자다.
            if session.pitches > 0 {
                Text(
                    "\(session.outsRecorded / 3).\(session.outsRecorded % 3)이닝 · "
                        + "\(session.strikeouts)K \(session.walks)BB \(session.runsAllowed)실점 · \(session.pitches)구"
                )
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textTertiary)
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

/// 타자가 내 투구를 얼마나 읽었는가.
///
/// 커널이 매 투구마다 계산하는데 iOS 화면에는 없었다. 그래서 "같은 공을 반복하면 읽힌다"는
/// 이 게임의 전략적 정체성을 플레이어가 **존재조차 알 수 없었고**, 투구가 "324개 중 하나
/// 고르기"로 남아 반복 플레이의 학습 곡선이 생기지 않았다(품질 평가 §4.1, 결격 5).
///
/// 매 투구 위에 뜨는 것이라 카드 면을 두지 않는다. 막대 하나와 경고 한 줄이면 된다.
private struct AdaptationBar: View {
    let adaptation: RivalAdaptationSnapshot

    /// 적응도는 0–900 눈금이다.
    private var progress: Double { min(1, Double(adaptation.level) / 900) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("타자가 내 공을 읽는 정도").eyebrowStyle(BaseballTheme.textTertiary)
                Spacer()
                Text(PitchCopy.adaptation(adaptation.band))
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
            if !adaptation.warning.isEmpty {
                Text(adaptation.warning)
                    .font(.caption)
                    .foregroundStyle(PitchCopy.adaptationTone(adaptation.band))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "타자가 내 공을 읽는 정도 \(PitchCopy.adaptation(adaptation.band))"
                + (adaptation.warning.isEmpty ? "" : ". \(adaptation.warning)")
        )
    }
}

/// 이닝이 끝난 뒤의 분석. 무엇을 잘했고 무엇이 읽혔는지.
///
/// 커널이 최근 투구 창에서 이미 계산해 두는 값만 쓴다 — 새 난수를 소비하지 않는다.
private struct PostgameAnalysisCard: View {
    let analysis: PostgameAnalysisSnapshot

    var body: some View {
        BaseballCard(title: "이 등판 분석") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(PitchCopy.confidence(analysis.confidence)) · \(analysis.sampleSize)구")
                    .eyebrowStyle(BaseballTheme.textTertiary)

                HStack(spacing: 10) {
                    Metric(title: "존 통과", value: PitchCopy.rate(analysis.zoneRate))
                    Metric(title: "헛스윙", value: PitchCopy.rate(analysis.whiffRate), tone: .positive)
                    Metric(title: "강한 타구", value: PitchCopy.rate(analysis.hardHitRate), tone: .warning)
                }
                HStack(spacing: 10) {
                    Metric(title: "코스 정확도", value: "\(analysis.averageExecutionQuality)")
                    Metric(title: "예상 위험", value: String(format: "%.2f", Double(analysis.expectedDamage) / 1_000))
                    Metric(
                        title: "실제 위험",
                        value: String(format: "%.2f", Double(analysis.actualDamage) / 1_000),
                        tone: analysis.actualDamage > analysis.expectedDamage ? .negative : .positive
                    )
                }

                if !analysis.patternWarning.isEmpty {
                    Text(analysis.patternWarning)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !analysis.growthSignal.isEmpty {
                    Text(analysis.growthSignal)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.positive)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !analysis.pitchBreakdowns.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(analysis.pitchBreakdowns, id: \.pitchType) { breakdown in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(PitchCopy.pitch(breakdown.pitchType))
                                    .font(.footnote.weight(.bold))
                                    .frame(width: 64, alignment: .leading)
                                Text("\(breakdown.pitches)구")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textTertiary)
                                Spacer()
                                Text("존 \(PitchCopy.rate(breakdown.zoneRate)) · 헛스윙 \(PitchCopy.rate(breakdown.whiffRate)) · 강타 \(PitchCopy.rate(breakdown.hardHitRate))")
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
                Text("\(PitchCopy.pitch(call.pitchType)) · \(PitchCopy.zone(call.zone, batSide: session.batter.batSide)) · \(PitchCopy.intent(call.zoneIntent))")
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
                        ? "약점은 \(PitchCopy.pitch(report.estimatedWeakness)) · \(PitchCopy.zone(report.estimatedColdZone, batSide: session.batter.batSide))로 굳어졌습니다."
                        : "아직 추정입니다. 약점은 \(PitchCopy.pitch(report.estimatedWeakness)) · \(PitchCopy.zone(report.estimatedColdZone, batSide: session.batter.batSide)) 근처로 보입니다.")
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
    /// 코스 이름을 읽어 줄 기준. 좌타자면 몸쪽·바깥쪽이 뒤집힌다.
    var batSide: BatSide = .right
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
        .accessibilityLabel(PitchCopy.zone(zone, batSide: batSide) + (isRecommended ? ", 포수 추천" : ""))
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
