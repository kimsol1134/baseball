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

    static func localized(_ zone: PitchZone, batSide: BatSide = .right, resolver: GameCopyResolver) -> String {
        PitchPresentation.zone(zone, batSide: batSide, resolver: resolver)
    }

    /// 타석에 선 쪽. 좌우 플래툰은 커널이 이미 계산하는데 화면에 표기가 없었다.
    static func batSide(_ side: BatSide) -> String {
        side == .left ? "좌타" : "우타"
    }

    static func localized(_ side: BatSide, resolver: GameCopyResolver) -> String {
        resolver.resolve(side.displayCopyToken)
    }

    static func pitch(_ type: PitchType) -> String {
        switch type {
        case .fourSeam: "포심"
        case .slider: "슬라이더"
        case .curveball: "커브"
        case .changeup: "체인지업"
        }
    }

    static func localized(_ type: PitchType, resolver: GameCopyResolver) -> String {
        resolver.resolve(type.displayCopyToken)
    }

    static func intent(_ intent: ZoneIntent) -> String {
        switch intent {
        case .strike: "존 안으로"
        case .edge: "존 경계"
        case .chase: "존 밖 유인"
        }
    }

    static func localized(_ intent: ZoneIntent, resolver: GameCopyResolver) -> String {
        resolver.resolve(intent.displayCopyToken)
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

    static func localizedIntentDetail(
        _ intent: ZoneIntent,
        zone: PitchZone,
        resolver: GameCopyResolver
    ) -> String {
        PitchPresentation.intentDetail(intent, zone: zone, resolver: resolver)
    }

    static func intensity(_ intensity: PitchIntensity) -> String {
        switch intensity {
        case .controlled: "힘 빼고"
        case .normal: "보통"
        case .maxEffort: "전력"
        }
    }

    static func localized(_ intensity: PitchIntensity, resolver: GameCopyResolver) -> String {
        resolver.resolve(intensity.displayCopyToken)
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

    static func localized(
        _ outcome: PitchOutcome,
        battedBall: BattedBall? = nil,
        resolver: GameCopyResolver
    ) -> String {
        // The legacy Korean overload retains the more specific batted-ball wording. The closed
        // outcome token is the language-neutral fallback for English and other supported locales.
        if resolver.language == .korean {
            return Self.outcome(outcome, battedBall: battedBall)
        }
        return resolver.resolve(outcome.displayCopyToken)
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

    static func localized(_ band: RivalAdaptationBand, resolver: GameCopyResolver) -> String {
        PitchPresentation.adaptation(band, resolver: resolver)
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

    static func localized(_ band: AnalysisConfidenceBand, resolver: GameCopyResolver) -> String {
        PitchPresentation.confidence(band, resolver: resolver)
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


    static func localizedScoutBand(_ band: String, resolver: GameCopyResolver) -> String {
        PitchPresentation.scoutBand(band, resolver: resolver)
    }
}

/// 현재 선수 능력과 구종 프로필이 실제 투구 판정에 들어가는 값의 번역.
/// 숫자는 `PitchAbilityRules`가 엔진 식에서 직접 주고, 화면은 야구 말로만 바꾼다.
enum PitchBuildCopy {
    static func velocity(_ tenthsKPH: Int) -> String {
        String(format: "%.1f", Double(tenthsKPH) / 10)
    }

    static func moment(_ kind: PitchAbilityKind, readout: PitchAbilityReadout) -> String {
        switch kind {
        case .power:
            "키운 구위가 살아난 공 · 구위 \(readout.stuffRating) · 헛스윙 \(readout.whiffRating)"
        case .command:
            "키운 제구가 살아난 공 · 코스 \(readout.commandRating)"
        case .movement:
            "키운 변화가 살아난 공 · 움직임 \(readout.movementRating) · 범타 \(readout.weakContactRating)"
        case .stamina:
            "키운 체력이 버틴 공 · 피로 \(readout.rawFatigue)→\(readout.effectiveFatigue)"
        }
    }

    static func localizedMoment(
        _ kind: PitchAbilityKind,
        readout: PitchAbilityReadout,
        resolver: GameCopyResolver
    ) -> String {
        PitchPresentation.abilityMoment(kind, readout: readout, resolver: resolver)
    }

    static func accessibilitySummary(_ readout: PitchAbilityReadout) -> String {
        "기준 구속 \(velocity(readout.nominalVelocityTenthsKPH))킬로미터, "
            + "코스 \(readout.commandRating), 움직임 \(readout.movementRating), "
            + "체력 \(readout.staminaRating), 피로 \(readout.rawFatigue)에서 체감 \(readout.effectiveFatigue), "
            + "한 구 팔 부담 \(readout.fatigueCost). \(synergy(readout))"
    }

    static func localizedAccessibilitySummary(_ readout: PitchAbilityReadout, resolver: GameCopyResolver) -> String {
        PitchPresentation.buildSummary(readout, resolver: resolver)
    }

    static func identity(_ readout: PitchAbilityReadout) -> PitcherBuildIdentity {
        PitchAbilityRules.identity(for: readout)
    }

    static func synergy(_ readout: PitchAbilityReadout) -> String {
        switch identity(readout) {
        case .power:
            readout.pitchType == .fourSeam
                ? "강속구형 시너지 · 포심 구속과 헛스윙을 살립니다."
                : "강속구형 보조구 · 포심과의 속도 차를 만듭니다."
        case .command: "정밀 제구형 시너지 · 노린 코스에 붙이는 공입니다."
        case .movement:
            readout.pitchType == .fourSeam
                ? "변화구형 연결구 · 결정구를 위한 포심입니다."
                : "변화구형 시너지 · 움직임과 범타를 살립니다."
        case .stamina: "이닝 소화형 시너지 · 누적 피로 \(readout.effectiveFatigue)로 억제 중입니다."
        }
    }

    static func localizedSynergy(_ readout: PitchAbilityReadout, resolver: GameCopyResolver) -> String {
        PitchPresentation.buildSynergy(readout, resolver: resolver)
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
    @State private var moundHeartbeat = MoundHeartbeatController()
    /// 직전 악재의 불규칙 박동은 해당 투구 번호에서 한 번만 소비한다. 앱이 백그라운드에서
    /// 돌아오거나 같은 ready 상태를 다시 구성해도 안타/볼넷 충격을 재생하지 않는다.
    @State private var irregularEpisodePitchCount: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameCopyResolver) private var copyResolver
    /// 승부 장면 높이. 고정 320은 접근성 글자 크기에서 판정 텍스트가 잘린다(3차 패널 P1).
    @ScaledMetric(relativeTo: .body) private var dramaHeight: CGFloat = 320
    @State private var replayProgress: Double = 1
    @AppStorage("baseball.pitch.autoRelease") private var autoRelease = false
    /// 생애 최고 구속(0.1km/h). 회차를 넘어 쌓인다 — 갱신은 그 자체로 하이라이트다.
    @AppStorage("baseball.bestVelocityTenths") private var bestVelocityTenths = 0
    /// 등판 평균 릴리스의 개인 최고. 릴리스는 결과를 가장 크게 흔드는 조작인데,
    /// 지금까지 **늘고 있다는 증거가 화면 어디에도 없었다.** 어제보다 나아진 숫자 하나가
    /// 내일 다시 켤 이유가 된다.
    @AppStorage("baseball.bestDeliveryAverage") private var bestDeliveryAverage = 0
    /// 등판 하나에서 세운 헛스윙 개인 최고. 3년 육성의 값어치는 RA9로는 한 등판에
    /// 0.18실점 차이라 눈에 안 보인다(실측). 반면 "헛스윙 5개"는 그 자리에서 세어진다 —
    /// 키운 구위·변화가 **오늘 손에 잡히는 형태**로 돌아오는 자리가 필요하다.
    @AppStorage("baseball.bestWhiffsInOuting") private var bestWhiffsInOuting = 0
    /// 등판이 끝나는 순간의 "이게 개인 최고인가"를 굳혀 둔다.
    ///
    /// `@AppStorage`에 새 최고를 쓰면 뷰가 무효화되고 body가 다시 평가된다. 그때는 이미
    /// 저장값이 갱신돼 `isRecord`가 false가 되므로, 축하 배지가 **같은 프레임에 사라졌다**.
    /// 저장은 되고 축하만 없는 셈이라, 오늘 넣은 "나아지고 있다는 증거"가 한 순간도
    /// 화면에 남지 않았다. 판정을 한 번만 하고 화면은 그 스냅숏을 읽는다.
    @State private var outingRecords: OutingRecords?

    /// 등판 정산에서 쓰는 굳힌 판정.
    private struct OutingRecords: Equatable {
        let whiffs: Int
        let isWhiffRecord: Bool
        let deliveryAverage: Int?
        let isDeliveryRecord: Bool
        let previousDeliveryBest: Int
    }
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

    /// Legacy test seam. New callers use `MoundTensionModel` through the full input boundary
    /// below; this keeps the existing situation tests focused on the same monotonic rule.
    static func tension(
        leverage: Int,
        runners: BaserunnerStateSnapshot,
        balls: Int,
        strikes: Int,
        outs: Int
    ) -> Double {
        MoundTensionModel.tension(for: MoundTensionInput(
            officialGame: true,
            leverage: leverage,
            runners: runners,
            balls: balls,
            strikes: strikes,
            outs: outs,
            fatigue: 0,
            batterThreat: 50,
            recentAdverseEvent: false,
            composure: MoundComposureInput(command: 0, stamina: 0)
        ))
    }

    private var recentAdverseEvent: Bool {
        guard let snapshot = session.lastResult?.snapshot else { return false }
        if snapshot.result == .walk || snapshot.outcome == .hitByPitch { return true }
        let outcome = snapshot.outcome
        switch outcome {
        case .single, .double, .triple, .homeRun: return true
        default: return false
        }
    }

    private var moundTensionInput: MoundTensionInput {
        MoundTensionInput(
            officialGame: !isPractice,
            leverage: session.context.leverage,
            runners: session.gameState.runners,
            balls: session.context.balls,
            strikes: session.context.strikes,
            outs: session.context.outs,
            fatigue: session.context.fatigue,
            batterThreat: MoundTensionModel.batterThreat(
                contact: session.batter.contact,
                discipline: session.batter.discipline,
                power: session.batter.power
            ),
            recentAdverseEvent: recentAdverseEvent,
            composure: session.scenario.moundComposure
        )
    }

    private var currentTension: Double {
        guard case .ready = session.stage else { return 0 }
        return MoundTensionModel.tension(for: moundTensionInput)
    }

    private var heartbeatSeed: UInt64 { MoundTensionModel.seed(from: session.scenario.id) }

    private func startMoundHeartbeat(includeEntry: Bool) {
        guard !isPractice, scenePhase == .active, case .ready = session.stage else {
            stopMoundHeartbeat()
            return
        }

        let tension = includeEntry
            ? MoundTensionModel.entryTension(rawTension: currentTension, officialGame: true)
            : currentTension
        guard tension > 0 else {
            stopMoundHeartbeat()
            return
        }

        let shouldUseIrregularEpisode = !includeEntry
            && recentAdverseEvent
            && irregularEpisodePitchCount != session.pitchLog.count
        if shouldUseIrregularEpisode {
            irregularEpisodePitchCount = session.pitchLog.count
        }

        stopMoundHeartbeat()
        moundHeartbeat.start(
            tension: tension,
            seed: heartbeatSeed,
            includeEntry: includeEntry,
            adverseEpisode: shouldUseIrregularEpisode
        ) { event in
            Haptics.shared.heartbeatBeat(tension: event.tension, irregular: event.isIrregular)
            GameAudio.shared.playHeartbeat(tension: event.tension, irregular: event.isIrregular)
        }
    }

    private func stopMoundHeartbeat() {
        moundHeartbeat.stop()
        audio.stopHeartbeat()
        Haptics.shared.stopHeartbeat()
        Haptics.shared.stopWindUp()
    }

    /// 빠른 진행은 저위험 타석에서만 연다. 득점 기대가 크게 흔들리는 승부처나
    /// 풀카운트/2스트라이크는 이 게임의 핵심이므로 한 구씩 직접 던진다.
    static func canFastForwardCurrentBatter(
        isPractice: Bool,
        totalPitches: Int,
        leverage: Int,
        balls: Int,
        strikes: Int
    ) -> Bool {
        !isPractice && totalPitches > 0 && leverage < 780 && balls < 3 && strikes < 2
    }

    private var canFastForwardCurrentBatter: Bool {
        Self.canFastForwardCurrentBatter(
            isPractice: isPractice,
            totalPitches: session.pitches,
            leverage: session.context.leverage,
            balls: session.context.balls,
            strikes: session.context.strikes
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                // **어떤 경기인지 먼저 말한다.**
                //
                // 예전에는 경기 이름이 눈썹 글자 한 줄이었고 무게는 어디에도 없었다. 그래서
                // 3년 내내 "그냥 또 한 이닝"으로 읽혔다 — 마지막 여름의 결승과 1학년 봄의
                // 연습경기가 화면에서 구분되지 않으면, 이 게임이 파는 긴장이 성립하지 않는다.
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: PitchPresentation.scenarioHeadline(session.scenario, resolver: copyResolver))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: PitchPresentation.scenarioDetail(session.scenario, resolver: copyResolver))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pitch.scenario")
                Spacer(minLength: 8)
                StakesBadge(leverage: session.context.leverage)
                // 탈출구 없는 전체 화면은 함정이다. 파기는 확인을 거친다.
                if onAbort != nil {
                    Button(copyResolver.resolve(.abort)) { confirmingAbort = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .accessibilityIdentifier("pitch.abort")
                }
            }
            .confirmationDialog(
                copyResolver.resolve(isPractice ? .abortPracticeTitle : .abortGameTitle),
                isPresented: $confirmingAbort,
                titleVisibility: .visible
            ) {
                Button(copyResolver.resolve(isPractice ? .abortPracticeConfirm : .abortGameConfirm),
                       role: isPractice ? nil : .destructive) { onAbort?() }
                // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                Button(copyResolver.resolve(.abortContinue)) { confirmingAbort = false }
            } message: {
                Text(verbatim: copyResolver.resolve(isPractice ? .abortPracticeMessage : .abortGameMessage))
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
            startMoundHeartbeat(includeEntry: false)
        }
        .onAppear {
            audio.start()
            audio.crowdIntensity = GameAudioMapping.crowdIntensity(leverage: session.scenario.leverage)
            // 마운드에서는 관중과 심판이 음악이다. 패드는 화면을 나갈 때 돌아온다.
            audio.musicIntensity = 0
            Haptics.shared.prepare()
            startMoundHeartbeat(includeEntry: true)
        }
        .onDisappear {
            audio.crowdIntensity = 0.15
            audio.musicIntensity = 0.5
            // 마운드를 떠나면 반드시 멈춘다 — 화면 밖에서 계속 뛰는 진동·소리는 고장이다.
            stopMoundHeartbeat()
        }
        // 등판이 끝나는 **그 순간 한 번만** 판정하고 저장한다. body 안에서 판정하면
        // 저장이 곧바로 판정을 뒤집어 축하 배지가 같은 프레임에 사라진다.
        .onChange(of: session.pitchLog.count) { _, _ in
            sealOutingRecordsIfFinished()
        }
        .onAppear { sealOutingRecordsIfFinished() }
        .onChange(of: session.stage) { _, stage in
            switch stage {
            case .ready: startMoundHeartbeat(includeEntry: false)
            default: stopMoundHeartbeat()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startMoundHeartbeat(includeEntry: false)
            } else {
                // Backgrounding must cancel both the stored schedule and any in-flight windup.
                stopMoundHeartbeat()
            }
        }
    }

    // MARK: - 구성

    /// 첫 불펜 3구 스크립트 — 공마다 코치가 할 일 하나를 짚는다.
    /// 첫 공의 진짜 난관은 구종이 아니라 릴리스 미터다(구종·코스는 포수가 골라 둔다) —
    /// 그래서 ①은 미터부터 가르친다.
    private var bullpenCoachStrip: some View {
        let line: String
        if session.pitches == 0 {
            line = copyResolver.resolve(.coachFirst)
        } else if session.context.strikes >= 2 {
            line = copyResolver.resolve(.coachPutAway)
        } else {
            line = copyResolver.resolve(.coachSecond)
        }
        return HStack(alignment: .top, spacing: 8) {
            Text(verbatim: copyResolver.resolve(.coachLabel))
                .font(.caption.weight(.heavy))
                .foregroundStyle(BaseballTheme.milestone)
            Text(verbatim: line)
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
        BaseballCard(title: copyResolver.resolve(.matchupTitle), tone: .raised) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(verbatim: PitchPresentation.batterName(session.batter, resolver: copyResolver)).font(.headline)
                    Text(PitchCopy.localized(session.batter.batSide, resolver: copyResolver))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BaseballTheme.actionInk)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(BaseballTheme.action, in: Capsule())
                }
                Text(verbatim: copyResolver.resolve(
                    .matchupStats,
                    arguments: [.integer(session.batter.contact), .integer(session.batter.discipline), .integer(session.batter.power)]
                ))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                // 시나리오 설명은 화면 맨 위 상황 머리글이 맡는다 — 같은 문장을 두 번 적으면
                // 둘 다 안 읽힌다.
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var stage: some View {
        switch session.stage {
        case .failed:
            BaseballCard(title: copyResolver.resolve(.stateFailedTitle), tone: .negative) {
                Text(verbatim: copyResolver.resolve(.stateFailedBody)).font(.subheadline)
            }
        case .finished:
            // 이닝을 끝낸 공도 장면부터 보여 준다.
            //
            // 예전에는 `.finished`에서 곧바로 정리 화면으로 갈아 끼웠다. 마지막 아웃을 잡은
            // 공은 **화면에 한 번도 나오지 않고** 사라졌다 — 가장 중요한 한 구가 유일하게
            // 보이지 않는 공이었다. 타석이 이어질 때와 같은 순서(장면 → 정리)로 맞춘다.
            lastPitchPanel
            resultSummary
        case .betweenBatters:
            lastPitchPanel
            BaseballCard(title: copyResolver.resolve(.statePlateEndedTitle), tone: .positive) {
                Text(verbatim: copyResolver.resolve(.statePlateEndedBody)).font(.subheadline)
            }
        case .ready:
            if let preparation = session.preparation {
                lastPitchPanel
                AdaptationBar(adaptation: preparation.rivalAdaptation, batSide: session.batter.batSide)
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
                    sequenceMoment: session.lastSequenceMoment,
                    batSide: session.batter.batSide,
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
                // 퍼펙트 릴리스 — 던진 손이 만든 결과라 승부 장면 위에 남는다.
                // 결과가 안타든 삼진이든, 정확히 가운데에서 뗀 사실은 그 자체로 보상이다.
                .overlay(alignment: .topTrailing) {
                    if session.lastDelivery?.isPerfectRelease == true {
                        Label(copyResolver.resolve(.badgePerfectRelease), systemImage: "target")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(BaseballTheme.canvas)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(BaseballTheme.milestone, in: Capsule())
                            .padding(10)
                            .accessibilityIdentifier("pitch.perfectRelease")
                    }
                }
                // 승부구 배지 — 슬로모션이 왜 걸렸는지 화면이 말해 준다.
                .overlay(alignment: .topLeading) {
                    if wasClutch, replayProgress < 1 {
                        Text(verbatim: copyResolver.resolve(.badgeClutch))
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

                BaseballCard(title: PitchCopy.localized(
                    result.snapshot.outcome,
                    battedBall: result.snapshot.battedBall,
                    resolver: copyResolver
                ), tone: tone(for: result.snapshot.outcome)) {
                    VStack(alignment: .leading, spacing: 6) {
                        // 기질 특성 발동 — 보정은 전부 공개된다. 숨은 조작은 이 게임에 없다.
                        if session.lastTraitFired, let trait = session.trait {
                            Text(verbatim: PitchPresentation.trait(trait, resolver: copyResolver))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BaseballTheme.milestone)
                        }
                        if let verdict = session.lastDelivery.flatMap({ DeliveryControl.localizedVerdict($0, resolver: copyResolver) }) {
                            Text(verbatim: verdict.text)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(verdict.tone.accent)
                        }
                        // 무엇을 놓쳤는지 짚어 준다. 평균 한 덩어리로는 다음 공에서
                        // 무엇을 고쳐야 하는지 알 수 없다.
                        if let hint = session.lastDelivery.flatMap({ DeliveryControl.localizedCoachingHint($0, resolver: copyResolver) }) {
                            Text(verbatim: hint)
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .accessibilityIdentifier("pitch.deliveryHint")
                        }
                        Text(verbatim: PitchPresentation.shortFeedback(result.snapshot, resolver: copyResolver))
                            .font(.subheadline.weight(.semibold))
                        Text(verbatim: PitchPresentation.detailFeedback(result.snapshot, resolver: copyResolver))
                            .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        if let moment = session.lastAbilityMoment,
                           let readout = session.lastAbilityReadout {
                            Label(PitchBuildCopy.localizedMoment(moment, readout: readout, resolver: copyResolver), systemImage: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BaseballTheme.milestone)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("pitch.abilityMoment")
                        }
                        if let moment = session.lastSequenceMoment {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(copyResolver.resolve(
                                    .badgeSequence,
                                    arguments: [.userText(PitchPresentation.sequenceTitle(moment.tag, resolver: copyResolver))]
                                ), systemImage: "brain.head.profile")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BaseballTheme.information)
                                // 같은 유형은 첫 발동에만 이유를 풀어 말한다. 이후에는
                                // 승부 장면의 짧은 배지만 남겨 투구 흐름을 끊지 않는다.
                                if session.sequenceMoments.filter({ $0.tag == moment.tag }).count == 1 {
                                    Text(verbatim: PitchPresentation.sequenceDetail(moment.tag, resolver: copyResolver))
                                        .font(.caption)
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        let execution = result.snapshot.execution
                        let inZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
                        HStack(alignment: .center, spacing: 10) {
                            Text(verbatim: GameFormatters.velocity(
                                tenthsKPH: execution.velocityTenthsKPH,
                                language: copyResolver.language
                            ))
                                .font(BaseballType.heroNumeral)
                                .foregroundStyle(BaseballTheme.action)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 2) {
                                // 커브 99.8km/h는 구종 없이는 오해를 부른다(QA P2-5).
                                Text(verbatim: session.pitchLog.last.map {
                                    PitchCopy.localized($0.call.pitchType, resolver: copyResolver)
                                } ?? "")
                                    .eyebrowStyle(BaseballTheme.textTertiary)
                                Text(verbatim: copyResolver.resolve(inZone ? .zoneIn : .zoneOut))
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
                BaseballCard(title: copyResolver.resolve(.practiceReadyTitle), tone: .raised) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: copyResolver.resolve(.practiceLesson))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: copyResolver.resolve(.practiceNotRecorded))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                }
                if let onRetry {
                    Button(copyResolver.resolve(.practiceRetry)) { onRetry() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.action)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        .background(BaseballTheme.actionSoft, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("pitch.retry")
                }
            } else {
                InningSettlementCard(session: session)
            }
            BaseballCard(title: copyResolver.resolve(.inningEndTitle), tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: session.hitByPitches > 0
                         ? copyResolver.resolve(.inningLineWithHBP, arguments: [
                            .integer(session.pitches), .integer(session.strikeouts), .integer(session.walks),
                            .integer(session.hitByPitches), .integer(session.runsAllowed),
                         ])
                         : copyResolver.resolve(.inningLine, arguments: [
                            .integer(session.pitches), .integer(session.strikeouts),
                            .integer(session.walks), .integer(session.runsAllowed),
                         ]))
                        .font(.title3.bold().monospacedDigit())
                    Text(verbatim: copyResolver.resolve(
                        session.actualDamage <= session.expectedDamage + 150 ? .inningProcessGood : .inningProcessReview
                    ))
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            if !isPractice, let analysis = session.lastResult?.postgameAnalysis {
                PostgameAnalysisCard(analysis: analysis)
            }
            BaseballCard(title: copyResolver.resolve(.pitchLogTitle)) {
                VStack(alignment: .leading, spacing: 6) {
                    // 타석마다 1로 돌아가는 번호는 목록이 깨진 것처럼 보인다(QA P2-6) —
                    // 등판 통산 순번으로 매기고, 타석 안 번호는 세부에 남는다.
                    ForEach(Array(session.pitchLog.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary).frame(width: 18, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim:
                                    "\(PitchCopy.localized(entry.call.pitchType, resolver: copyResolver)) · "
                                        + "\(PitchCopy.localized(entry.call.zone, batSide: session.batter.batSide, resolver: copyResolver)) · "
                                        + "\(PitchCopy.localized(entry.outcome, resolver: copyResolver))"
                                )
                                    .font(.footnote.weight(.semibold))
                                Text(verbatim: PitchPresentation.shortFeedback(
                                    entry.outcome,
                                    legacy: entry.shortFeedback,
                                    resolver: copyResolver
                                )).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                                if let moment = entry.sequenceMoment {
                                    Label(PitchPresentation.sequenceTitle(moment.tag, resolver: copyResolver), systemImage: "brain.head.profile")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(BaseballTheme.information)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder private func controls(preparation: PitchPreparation) -> some View {
        BaseballCard(title: copyResolver.resolve(.selectionPitchTitle)) {
            VStack(alignment: .leading, spacing: 10) {
                OptionRow(items: session.repertoire, selection: session.selectedPitchType) { type in
                    session.choosePitchType(type)
                } label: { PitchCopy.localized($0, resolver: copyResolver) }
                PitchBuildCompactReadoutView(readout: session.selectedAbilityReadout)
                if PitchAbilityFeedbackExperiment.isVisible {
                    Divider()
                    PitchBuildReadoutView(readout: session.selectedAbilityReadout)
                }
            }
        }

        BaseballCard(title: copyResolver.resolve(
            .selectionZoneTitle,
            arguments: [.userText(PitchCopy.localized(
                session.selectedZone,
                batSide: session.batter.batSide,
                resolver: copyResolver
            ))]
        )) {
            StrikeZoneGrid(
                selected: session.selectedZone,
                recommended: preparation.primaryRecommendation.call.zone,
                hotZone: preparation.scoutingReport?.estimatedHotZone,
                coldZone: preparation.scoutingReport?.estimatedColdZone,
                batSide: session.batter.batSide,
                onSelect: { zone in
                    session.chooseZone(zone)
                }
            )
        }

        // 노림과 힘을 한 카드로 — 결정부가 한 화면에 들어와야 "어디에 던지는지 보이는
        // 상태로 던지기"가 성립한다(QA P1-6). 4단 카드의 크롬 높이가 그 화면을 밀어냈다.
        BaseballCard(title: copyResolver.resolve(.selectionPlanTitle)) {
            VStack(alignment: .leading, spacing: 8) {
                OptionRow(items: ZoneIntent.options(for: session.selectedZone), selection: session.selectedIntent) { intent in
                    session.chooseIntent(intent)
                } label: { PitchCopy.localized($0, resolver: copyResolver) }
                Text(verbatim: PitchCopy.localizedIntentDetail(
                    session.selectedIntent,
                    zone: session.selectedZone,
                    resolver: copyResolver
                ))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                OptionRow(items: PitchIntensity.allCases, selection: session.selectedIntensity) { intensity in
                    session.chooseIntensity(intensity)
                } label: { PitchCopy.localized($0, resolver: copyResolver) }
            }
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 8) {
            switch session.stage {
            case .ready:
                DeliveryControl(
                    fatigue: session.context.fatigue,
                    pitchType: session.selectedPitchType,
                    velocityTenthsKPH: session.selectedAbilityReadout.nominalVelocityTenthsKPH,
                    autoRelease: autoRelease,
                    tension: currentTension,
                    hapticsEnabled: audio.hapticsEnabled,
                    heartbeatSignal: moundHeartbeat.signal,
                    disturbanceSeed: heartbeatSeed,
                    onDeliver: { delivery in
                        wasClutch = isClutchNow
                        session.throwPitch(delivery: delivery)
                    },
                    onRelease: { stopMoundHeartbeat() },
                    onMeterEdge: { audio.play(.uiSelect) }
                )
                // 미터 제스처가 버거운 손을 위한 출구가 설정 화면에만 있으면
                // 정작 미터 앞에서 막힌 사람이 못 찾는다 — 그 자리에서 켠다.
                Toggle(isOn: $autoRelease) {
                    Text(verbatim: copyResolver.resolve(.autoRelease))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                .controlSize(.mini)
                .tint(BaseballTheme.action)
                .accessibilityIdentifier("pitch.autoRelease")
                if canFastForwardCurrentBatter {
                    Button {
                        wasClutch = false
                        _ = session.fastForwardCurrentBatter()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: copyResolver.resolve(.fastForwardTitle))
                                .font(.subheadline.weight(.semibold))
                            Text(verbatim: copyResolver.resolve(.fastForwardBody))
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("pitch.fastForwardBatter")
                }
            case .betweenBatters:
                PrimaryPill(title: copyResolver.resolve(.nextBatter), identifier: "pitch.nextBatter") {
                    session.advanceToNextBatter()
                }
            case .finished, .failed:
                // 이 등판에서 손이 얼마나 정확했는가. 연습(불펜)에서도 보여 준다 —
                // 배우는 자리야말로 나아지는 것이 보여야 한다.
                // 오늘 이 선수가 무엇을 해냈는가 — 키운 능력이 숫자로 돌아오는 자리.
                if let records = outingRecords, records.whiffs > 0 || session.strikeouts > 0 {
                    let whiffs = records.whiffs
                    let isWhiffRecord = records.isWhiffRecord
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        outingStat(copyResolver.resolve(.statWhiffs), "\(whiffs)", highlight: isWhiffRecord)
                        outingStat(copyResolver.resolve(.statStrikeouts), "\(session.strikeouts)", highlight: false)
                        if bestVelocityTenths > 0 {
                            outingStat(copyResolver.resolve(.statTopVelocity),
                                       GameFormatters.velocity(tenthsKPH: bestVelocityTenths, language: copyResolver.language),
                                       highlight: wasVelocityRecord)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("pitch.outingStats")
                    if isWhiffRecord {
                        Text(verbatim: copyResolver.resolve(.statWhiffRecord))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
                if let records = outingRecords, let average = records.deliveryAverage {
                    let isRecord = records.isDeliveryRecord
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(verbatim: copyResolver.resolve(.statReleaseTitle))
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text("\(average)")
                                .font(.title3.weight(.heavy).monospacedDigit())
                                .foregroundStyle(isRecord ? BaseballTheme.milestone : BaseballTheme.textPrimary)
                            if isRecord {
                                Text(verbatim: copyResolver.resolve(.statPersonalBest))
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.canvas)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(BaseballTheme.milestone, in: Capsule())
                            }
                        }
                        Text(verbatim: isRecord
                             ? copyResolver.resolve(.statReleaseBest, arguments: [.integer(session.deliveryScores.count)])
                             : copyResolver.resolve(.statReleaseCompare, arguments: [
                                .integer(session.deliveryScores.count), .integer(records.previousDeliveryBest),
                             ]))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pitch.deliveryAverage")
                }
                PrimaryPill(title: copyResolver.resolve(isPractice ? .startCareer : .finishOuting),
                            identifier: "pitch.finish", action: onFinish)
            }
        }
        .padding(BaseballMetrics.gutter)
        .background(BaseballTheme.surface)
    }

    /// 등판이 끝났으면 개인 최고 판정을 한 번 굳히고 저장한다.
    private func sealOutingRecordsIfFinished() {
        guard outingRecords == nil else { return }
        guard case .finished = session.stage else { return }
        let whiffs = session.pitchLog.filter { $0.outcome == .swingingStrike }.count
        let average = session.averageDeliveryScore
        let sealed = OutingRecords(
            whiffs: whiffs,
            isWhiffRecord: whiffs > bestWhiffsInOuting,
            deliveryAverage: average,
            isDeliveryRecord: average.map { $0 > bestDeliveryAverage } ?? false,
            previousDeliveryBest: bestDeliveryAverage
        )
        outingRecords = sealed
        if sealed.isWhiffRecord { bestWhiffsInOuting = whiffs }
        if sealed.isDeliveryRecord, let average { bestDeliveryAverage = average }
    }

    /// 등판 정산의 한 칸. 값이 주인공이고 이름은 아래에 작게 둔다.
    private func outingStat(_ title: String, _ value: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // localization-safe: numeric
            Text(value)
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(highlight ? BaseballTheme.milestone : BaseballTheme.textPrimary)
            // localization-safe: resolved-copy
            Text(title)
                .font(.caption2)
                .foregroundStyle(BaseballTheme.textTertiary)
        }
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
        guard language == .english else { return situationLine(outs: outs, runners: runners) }
        let safeOuts = min(2, max(0, outs))
        let occupied = [runners.firstOccupied, runners.secondOccupied, runners.thirdOccupied]
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

private struct CountPips: View {
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

private struct RunnerDiamond: View {
    /// 보이스오버용 주자 설명. 시각 다이아몬드의 정보를 말로 옮긴다.
    static func voiceOverLabel(_ runners: BaserunnerStateSnapshot) -> String {
        var bases: [String] = []
        if runners.firstOccupied { bases.append("1루") }
        if runners.secondOccupied { bases.append("2루") }
        if runners.thirdOccupied { bases.append("3루") }
        return bases.isEmpty ? "없음" : bases.joined(separator: "·")
    }

    static func voiceOverLabel(_ runners: BaserunnerStateSnapshot, language: AppLanguage) -> String {
        guard language == .english else { return voiceOverLabel(runners) }
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
private struct PitchBuildCompactReadoutView: View {
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
private struct PitchBuildReadoutView: View {
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
private enum PitchAbilityFeedbackExperiment {
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
private struct AdaptationBar: View {
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
private struct PostgameAnalysisCard: View {
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

private struct CatcherCard: View {
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
private struct ZoneMiniMap: View {
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
private struct KBanner: View {
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
private struct InningSettlementCard: View {
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
