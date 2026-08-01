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

    /// 타구가 있으면 "인플레이 아웃" 대신 타구 종류로 말한다(QA P2-4).
    /// 엔진 용어는 정확하지만 야구 팬의 언어가 아니다.
    static func outcome(_ outcome: PitchOutcome, battedBall: BattedBall?) -> String {
        guard outcome == .inPlayOut, let ball = battedBall else { return Self.outcome(outcome) }
        if ball.launchAngleTenthsDegrees < 100 { return "땅볼 아웃" }
        if ball.launchAngleTenthsDegrees < 250 { return "직선타 아웃" }
        return "뜬공 아웃"
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
    /// 등판 중단(진행 파기). nil이면 중단 버튼을 그리지 않는다 — 튜토리얼 불펜에는 없다.
    var onAbort: (() -> Void)? = nil
    /// 연습 타석(프롤로그 불펜). 기록에 안 남는 판에 '각성의 전조 +2' 같은
    /// 정산을 그리면 첫 5분에 거짓 영수증을 발행하는 셈이다.
    var isPractice = false
    /// 연습 타석 다시 던지기. 배우는 자리는 한 번에 끝내라고 강요하지 않는다.
    var onRetry: (() -> Void)? = nil

    @State private var confirmingAbort = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 승부 장면 높이. 고정 320은 접근성 글자 크기에서 판정 텍스트가 잘린다(3차 패널 P1).
    @ScaledMetric(relativeTo: .body) private var dramaHeight: CGFloat = 320
    @State private var replayProgress: Double = 1
    @AppStorage("baseball.pitch.autoRelease") private var autoRelease = false
    /// 생애 최고 구속(0.1km/h). 회차를 넘어 쌓인다 — 갱신은 그 자체로 하이라이트다.
    @AppStorage("baseball.bestVelocityTenths") private var bestVelocityTenths = 0
    /// 방금 공이 승부구(풀카운트·2아웃 2스트라이크)였는가. 던지는 순간 잡아 둔다 —
    /// 결과가 반영되면 카운트가 이미 넘어가 있어 되짚을 수 없다.
    @State private var wasClutch = false
    /// 방금 공이 생애 최고 구속을 갈아치웠는가.
    @State private var wasVelocityRecord = false
    private var audio: GameAudio { .shared }

    /// 지금 던지면 승부구인가 — 풀카운트, 또는 2아웃에서 2스트라이크.
    private var isClutchNow: Bool {
        session.context.strikes == 2 && (session.context.balls == 3 || session.context.outs == 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.scenario.headline).eyebrowStyle(BaseballTheme.milestone)
                Spacer()
                // 탈출구 없는 전체 화면은 함정이다. 파기는 확인을 거친다.
                if onAbort != nil {
                    Button("중단") { confirmingAbort = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .accessibilityIdentifier("pitch.abort")
                }
            }
            .confirmationDialog(
                isPractice ? "연습을 끝낼까요?" : "등판을 중단할까요?",
                isPresented: $confirmingAbort,
                titleVisibility: .visible
            ) {
                Button(isPractice ? "연습을 끝낸다" : "이닝을 버리고 중단한다",
                       role: isPractice ? nil : .destructive) { onAbort?() }
                // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                Button("계속 던진다") { confirmingAbort = false }
            } message: {
                Text(isPractice
                     ? "연습은 기록에 남지 않습니다. 바로 다음으로 넘어갑니다."
                     : "지금까지 던진 이 이닝은 사라집니다. 다음 마운드는 새 이닝입니다.")
            }
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .background(BaseballTheme.surface)
            ScoreboardBar(session: session)
            // 코치 스트립은 스크롤 밖 고정이다. 스크롤 콘텐츠에 넣었더니 투구 직후
            // 자동 스크롤이 화면 밖으로 밀어내 3구 스크립트가 1행짜리가 됐다(3차 패널 P0).
            if isPractice, session.stage == .ready,
               session.pitches < 3 || (session.context.strikes >= 2 && session.pitches < 6) {
                bullpenCoachStrip
            }
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
                    // 승부구 슬로모(2.6초)는 연출이 끝난 뒤에 되돌아간다. 모션 축소도
                    // 결과를 읽을 1.2초는 남긴다 — 접근성 설정이 피드백을 삭제하면 안 된다.
                    let delay = reduceMotion ? 1.2 : (wasClutch ? 2.9 : 1.7)
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
            // 생애 최고 구속 갱신. 첫 공은 기준선만 잡고 조용히 지나간다 —
            // 0에서의 갱신은 신기록이 아니라 첫 기록이다.
            if !isPractice, let velocity = session.lastResult?.snapshot.execution.velocityTenthsKPH {
                wasVelocityRecord = bestVelocityTenths > 0 && velocity > bestVelocityTenths
                if velocity > bestVelocityTenths { bestVelocityTenths = velocity }
            } else {
                wasVelocityRecord = false
            }
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

    /// 첫 불펜 3구 스크립트 — 공마다 코치가 할 일 하나를 짚는다.
    /// 첫 공의 진짜 난관은 구종이 아니라 릴리스 미터다(구종·코스는 포수가 골라 둔다) —
    /// 그래서 ①은 미터부터 가르친다.
    private var bullpenCoachStrip: some View {
        let line: String
        if session.pitches == 0 {
            line = "① 길게 눌러 와인드업 — 미터가 가운데 초록에 올 때 떼자. 구종과 코스는 포수가 골라 뒀다."
        } else if session.context.strikes >= 2 {
            line = "③ 결정구 — 상대가 약한 구종으로 유인하자. 존을 살짝 벗어나도 방망이가 나온다."
        } else {
            line = "② 같은 곳에 두 번은 없다 — 구종이나 코스를 바꿔 타자의 눈을 흔들자."
        }
        return HStack(alignment: .top, spacing: 8) {
            Text("코치")
                .font(.caption.weight(.heavy))
                .foregroundStyle(BaseballTheme.milestone)
            Text(line)
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BaseballMetrics.gutter)
        .padding(.vertical, 7)
        .background(BaseballTheme.surfaceRaised)
        .accessibilityIdentifier("pitch.coach")
    }

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
                .frame(height: dramaHeight)
                .frame(maxWidth: .infinity)
                .background(BaseballTheme.fieldNight, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
                // 홈런과 이닝을 끝낸 삼진에만 스탬프가 찍힌다. 이 장면이 곧 공유용
                // 스크린샷이다. 매 공마다 찍으면 그건 스탬프가 아니라 배경이 된다.
                .overlay {
                    if let kind = HighlightStamp.kind(
                        outcome: result.snapshot.outcome,
                        plateResult: result.snapshot.result,
                        inningEnded: result.snapshot.inningTransition?.inningEnded ?? false,
                        landingDistanceTenthsMeters: result.snapshot.fieldingResolution?.landingDistanceTenthsMeters,
                        consecutiveStrikeouts: session.consecutiveStrikeouts,
                        runsScored: result.snapshot.runsScored,
                        isVelocityRecord: wasVelocityRecord
                    ) {
                        HighlightStamp(kind: kind, velocityTenthsKPH: result.snapshot.execution.velocityTenthsKPH)
                            .id(result.snapshot.revision)
                    }
                }
                // 승부구 배지 — 슬로모션이 왜 걸렸는지 화면이 말해 준다.
                .overlay(alignment: .topLeading) {
                    if wasClutch, replayProgress < 1 {
                        Text("승부구")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(BaseballTheme.milestone)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(BaseballTheme.canvas.opacity(0.8), in: Capsule())
                            .overlay(Capsule().stroke(BaseballTheme.milestone, lineWidth: 1))
                            .padding(10)
                            .transition(.opacity)
                    }
                }
                .id(Self.dramaAnchor)

                BaseballCard(title: PitchCopy.outcome(result.snapshot.outcome, battedBall: result.snapshot.battedBall), tone: tone(for: result.snapshot.outcome)) {
                    VStack(alignment: .leading, spacing: 6) {
                        // 기질 특성 발동 — 보정은 전부 공개된다. 숨은 조작은 이 게임에 없다.
                        if session.lastTraitFired, let trait = session.trait {
                            Text("『\(trait.title)』 발동 — \(trait.activationLine)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BaseballTheme.milestone)
                        }
                        if let verdict = session.lastDelivery.flatMap(DeliveryControl.verdict) {
                            Text(verdict.text)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(verdict.tone.accent)
                        }
                        Text(result.snapshot.shortFeedback).font(.subheadline.weight(.semibold))
                        Text(result.snapshot.detailFeedback).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        let execution = result.snapshot.execution
                        let inZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
                        HStack(alignment: .center, spacing: 10) {
                            Text(String(format: "%.1f", Double(execution.velocityTenthsKPH) / 10))
                                .font(BaseballType.heroNumeral)
                                .foregroundStyle(BaseballTheme.action)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 2) {
                                // 커브 99.8km/h는 구종 없이는 오해를 부른다(QA P2-5).
                                Text(session.pitchLog.last.map { "\(PitchCopy.pitch($0.call.pitchType)) · km/h" } ?? "km/h")
                                    .eyebrowStyle(BaseballTheme.textTertiary)
                                Text(inZone ? "존 안" : "존 밖")
                                    .font(BaseballType.scoreboard)
                                    .foregroundStyle(inZone ? BaseballTheme.positive : BaseballTheme.warning)
                            }
                            Spacer()
                            // 방금 공이 존 어디로 갔는지. 승부 장면은 흐르고 지나가므로
                            // "어디 갔는지"의 답은 여기 남는다 — 목표는 링, 실제는 점.
                            ZoneMiniMap(execution: execution)
                        }
                    }
                }
            }
        }
    }

    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 정산 — 이 이닝이 남긴 것을 하나씩 걸어 준다. 요약 한 줄로 끝나면
            // 던진 15분이 문장 하나로 접힌다. 획득이 보여야 다음 등판을 누른다.
            // 연습 타석은 예외 — 기록에 안 남는 판의 정산은 거짓말이다.
            if isPractice {
                BaseballCard(title: "몸이 풀렸습니다", tone: .raised) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("방금 배운 것 — 미터는 가운데에서 떼고, 코스는 포수 사인을 참고하되 내 공을 던진다.")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("연습은 기록에 남지 않습니다. 이제 3년이 시작됩니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                }
                if let onRetry {
                    Button("한 번 더 던지기") { onRetry() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.action)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        .background(BaseballTheme.actionSoft, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("pitch.retry")
                }
            } else {
                InningSettlementCard(session: session)
            }
            BaseballCard(title: "이닝 종료", tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(session.pitches)구 · \(session.strikeouts)탈삼진 · \(session.walks)볼넷"
                         + (session.hitByPitches > 0 ? " · \(session.hitByPitches)사구" : "")
                         + " · \(session.runsAllowed)실점")
                        .font(.title3.bold().monospacedDigit())
                    Text(session.actualDamage <= session.expectedDamage + 150
                        ? "구종과 코스를 고른 과정이 좋았다는 평가를 받습니다."
                        : "결과와 별개로 구종 순서를 다시 맞춰야 합니다.")
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            if !isPractice, let analysis = session.lastResult?.postgameAnalysis {
                PostgameAnalysisCard(analysis: analysis)
            }
            BaseballCard(title: "투구 기록") {
                VStack(alignment: .leading, spacing: 6) {
                    // 타석마다 1로 돌아가는 번호는 목록이 깨진 것처럼 보인다(QA P2-6) —
                    // 등판 통산 순번으로 매기고, 타석 안 번호는 세부에 남는다.
                    ForEach(Array(session.pitchLog.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary).frame(width: 18, alignment: .trailing)
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

        // 노림과 힘을 한 카드로 — 결정부가 한 화면에 들어와야 "어디에 던지는지 보이는
        // 상태로 던지기"가 성립한다(QA P1-6). 4단 카드의 크롬 높이가 그 화면을 밀어냈다.
        BaseballCard(title: "노림 · 힘 배분") {
            VStack(alignment: .leading, spacing: 8) {
                OptionRow(items: ZoneIntent.options(for: session.selectedZone), selection: session.selectedIntent) { intent in
                    session.selectedIntent = intent
                } label: { PitchCopy.intent($0) }
                Text(PitchCopy.intentDetail(session.selectedIntent, zone: session.selectedZone))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                OptionRow(items: PitchIntensity.allCases, selection: session.selectedIntensity) { intensity in
                    session.selectedIntensity = intensity
                } label: { PitchCopy.intensity($0) }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 8) {
            switch session.stage {
            case .ready:
                DeliveryControl(
                    fatigue: session.context.fatigue,
                    autoRelease: autoRelease,
                    onDeliver: { delivery in
                        wasClutch = isClutchNow
                        session.throwPitch(delivery: delivery)
                    },
                    onMeterEdge: { audio.play(.uiSelect) }
                )
                // 미터 제스처가 버거운 손을 위한 출구가 설정 화면에만 있으면
                // 정작 미터 앞에서 막힌 사람이 못 찾는다 — 그 자리에서 켠다.
                Toggle(isOn: $autoRelease) {
                    Text("자동 릴리스 — 탭 한 번으로 중립 투구")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                .controlSize(.mini)
                .tint(BaseballTheme.action)
                .accessibilityIdentifier("pitch.autoRelease")
            case .betweenBatters:
                PrimaryPill(title: "다음 타자", identifier: "pitch.nextBatter") {
                    session.advanceToNextBatter()
                }
            case .finished, .failed:
                PrimaryPill(title: isPractice ? "3년을 시작한다" : "경기 결과 반영",
                            identifier: "pitch.finish", action: onFinish)
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
            // 장면은 건너뛰어도 소리의 박자는 남긴다 — 전부 겹치면 죽 소리가 된다.
            // 비행을 기다릴 필요만 없으니 간격을 압축한다(충돌 → 콜 → 관중).
            for (index, cue) in session.lastCues.enumerated() {
                let delay = 0.28 * Double(min(index, 3))
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { audio.play(cue) }
            }
            return
        }
        replayProgress = 0
        // 승부구는 슬로모션 — 같은 1.6초면 승부구가 승부구로 안 읽힌다. 소리 박자도
        // 같은 배율로 늘어져야 심판이 공보다 빨라지지 않는다.
        let tempo = wasClutch ? 1.625 : 1.0
        withAnimation(.linear(duration: 1.6 * tempo)) { replayProgress = 1 }

        // 릴리스는 바로, 물리적 충돌(포구·타격)은 공이 도착하는 순간(0.58 × 1.6초)에.
        // 그 뒤는 실제 야구의 박자다 — 포구, 한 박 쉬고 심판 콜, 또 한 박 뒤에 관중.
        // 전에는 포구와 콜이 같은 순간에 겹쳐서 심판이 공보다 빨랐다.
        let cues = session.lastCues
        if let release = cues.first { audio.play(release) }
        // 3타자 연속 삼진부터는 축하음이 함성 위에 얹힌다. 풀콜(1.32~3.2초)이 끝나고
        // 함성이 부풀어 있는 자리다. 매 삼진마다 울리면 3연속이 아무것도 아니게 된다.
        if session.consecutiveStrikeouts >= 3, session.lastResult?.snapshot.result == .strikeout {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8 * tempo) { audio.play(.milestone) }
        }
        for (index, cue) in cues.dropFirst().enumerated() {
            // 삼진 풀콜은 반 박 더 뜸을 들인다 — 심판이 펀치아웃 동작과 함께 지르는 그 사이.
            let delay = if cue == .umpireStrikeout { 1.32 * tempo } else {
                switch index {
                case 0: 0.92 * tempo
                case 1: 1.18 * tempo
                default: 1.5 * tempo
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { audio.play(cue) }
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
                        + "\(session.strikeouts)K \(session.walks)BB"
                        + (session.hitByPitches > 0 ? " \(session.hitByPitches)사구" : "")
                        + " \(session.runsAllowed)실점 · \(session.pitches)구"
                )
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

    /// 문자열 연결이 길면 타입체커가 무너진다 — 조각을 배열로 모아 한 번에 붙인다.
    private var accessibilitySummary: String {
        var parts: [String] = []
        parts.append("\(scoreText). \(session.context.inning)회 \(session.context.outs)아웃")
        parts.append("볼 \(session.context.balls) 스트라이크 \(session.context.strikes)")
        parts.append("피로 \(session.context.fatigue)")
        parts.append("주자 \(RunnerDiamond.voiceOverLabel(session.gameState.runners))")
        if session.pitches > 0 {
            parts.append("이번 등판 \(session.strikeouts)탈삼진 \(session.walks)볼넷 \(session.runsAllowed)실점")
        }
        if let stakes {
            parts.append(stakes)
        }
        return parts.joined(separator: ", ")
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
    /// 보이스오버용 주자 설명. 시각 다이아몬드의 정보를 말로 옮긴다.
    static func voiceOverLabel(_ runners: BaserunnerStateSnapshot) -> String {
        var bases: [String] = []
        if runners.firstOccupied { bases.append("1루") }
        if runners.secondOccupied { bases.append("2루") }
        if runners.thirdOccupied { bases.append("3루") }
        return bases.isEmpty ? "없음" : bases.joined(separator: "·")
    }

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
                                // 1구짜리 표본에 "0.0%"는 정보가 아니라 소음이다(QA P2-7).
                                Text(breakdown.pitches < 5
                                     ? "존 \(breakdown.zoneRate * breakdown.pitches / 1_000)/\(breakdown.pitches)"
                                     : "존 \(PitchCopy.rate(breakdown.zoneRate)) · 헛스윙 \(PitchCopy.rate(breakdown.whiffRate)) · 강타 \(PitchCopy.rate(breakdown.hardHitRate))")
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

    @State private var showsScouting = false

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

                // 사인 고정 — 켜면 포수 추천이 다음 공에서 내 선택을 덮지 않는다.
                // "이 타자한테는 낮은 슬라이더로 민다"는 의도가 매 투구 2~4탭 없이 살아남는다.
                Toggle(isOn: Binding(get: { session.holdCall }, set: { session.holdCall = $0 })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("내 배합 유지").font(.footnote.weight(.semibold))
                        Text("포수 사인이 내 선택을 덮어쓰지 않습니다.")
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
                            Text("상대 분석 · \(PitchCopy.scoutBand(report.band))")
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
                        Text(report.band == "trusted"
                            ? "약점은 \(PitchCopy.pitch(report.estimatedWeakness)) · \(PitchCopy.zone(report.estimatedColdZone, batSide: session.batter.batSide))로 굳어졌습니다."
                            : "아직 추정입니다. 약점은 \(PitchCopy.pitch(report.estimatedWeakness)) · \(PitchCopy.zone(report.estimatedColdZone, batSide: session.batter.batSide)) 근처로 보입니다.")
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
private struct ZoneMiniMap: View {
    let execution: PitchExecution

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
            abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500 ? "존 안에 들어간 공" : "존을 벗어난 공"
        )
    }
}

/// 삼진 현수막. 이번 등판에서 잡은 삼진이 K 한 장씩으로 걸린다 — 새 K는 튀어나오며 등장한다.
private struct KBanner: View {
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(count, 12), id: \.self) { index in
                Text("K")
                    .font(.system(size: 15, weight: .black, design: .rounded))
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
        .accessibilityLabel("탈삼진 \(count)개")
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
private struct InningSettlementCard: View {
    let session: PitchSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    /// 이 이닝이 남긴 것들. 커널 규칙(recordImportantGame의 전조 적립)과 같은 식이라
    /// 화면이 약속한 것과 코어가 주는 것이 어긋나지 않는다.
    private var rewards: [(icon: String, text: String, tone: Color)] {
        var items: [(String, String, Color)] = []
        if session.strikeouts > 0 {
            items.append(("flame.fill", "탈삼진 \(session.strikeouts)개", BaseballTheme.action))
        }
        if session.runsAllowed == 0 {
            items.append(("shield.fill", "무실점 이닝", BaseballTheme.positive))
        }
        let sparkGain = (session.runsAllowed == 0 || session.strikeouts >= 4 ? 2 : 0)
            + (session.actualDamage <= session.expectedDamage ? 1 : 0)
        if sparkGain > 0 {
            items.append(("sparkles", "각성의 전조 +\(sparkGain)", BaseballTheme.milestone))
        }
        if session.consecutiveStrikeouts >= 3 {
            items.append(("bolt.fill", "\(session.consecutiveStrikeouts)타자 연속 삼진", BaseballTheme.milestone))
        }
        if items.isEmpty {
            items.append(("book.fill", "다음 등판의 배합 수업", BaseballTheme.textSecondary))
        }
        return items
    }

    var body: some View {
        BaseballCard(title: "이 이닝이 남긴 것", tone: .raised) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(rewards.enumerated()), id: \.offset) { index, reward in
                    HStack(spacing: 8) {
                        Image(systemName: reward.icon).foregroundStyle(reward.tone)
                        Text(reward.text)
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
