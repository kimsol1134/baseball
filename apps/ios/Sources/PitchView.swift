import SwiftUI
import SimulationCore

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
    /// 릴리스 뒤 결과 촉감과 다음 심박을 한 task로 묶는다. 새 와인드업·화면 이탈·백그라운드가
    /// 오면 id가 사라지며 남은 피드백이 취소되어 이전 공이 새 공의 손맛을 침범하지 않는다.
    @State private var scheduledPitchFeedback: ScheduledPitchFeedback?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameCopyResolver) private var copyResolver
    /// 승부 장면 높이. 고정 320은 접근성 글자 크기에서 판정 텍스트가 잘린다(3차 패널 P1).
    @ScaledMetric(relativeTo: .body) private var dramaHeight: CGFloat = 320
    @State private var replayProgress: Double = 1
    /// 입력 패드가 아니라 투구 화면이 소유한다. 다음 공·다음 타자 상태로 바뀌어도 방금 공의
    /// 축하가 끝까지 남고, 새 입력 안내와 같은 뷰 계층에서 섞이지 않는다.
    @State private var perfectReleaseCelebrationID: UUID?
    @AppStorage(PitchControlPreferences.autoReleaseKey)
    private var autoRelease = PitchControlPreferences.defaultAutoRelease
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

    private struct ScheduledPitchFeedback: Equatable, Identifiable {
        let id: UUID
        let pitchCount: Int
        /// nil은 볼·파울처럼 결과 햅틱을 의도적으로 생략하거나 퍼펙트 패턴을 보존하는 공이다.
        let outcomeSuccess: Bool?
        let resultDelay: TimeInterval
        let heartbeatDelay: TimeInterval
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

    private func cancelScheduledPitchFeedback() {
        scheduledPitchFeedback = nil
    }

    private func schedulePitchFeedback() {
        let outcomeSuccess: Bool?
        if PerfectReleaseFeedback.shouldPlayOutcomeHaptic(after: session.lastDelivery),
           let outcome = session.lastResult?.snapshot.outcome {
            outcomeSuccess = PitchCopy.hapticSuccess(outcome)
        } else {
            outcomeSuccess = nil
        }

        scheduledPitchFeedback = ScheduledPitchFeedback(
            id: UUID(),
            pitchCount: session.pitchLog.count,
            outcomeSuccess: outcomeSuccess,
            resultDelay: PitchFeedbackTimeline.resultHapticDelay(
                reduceMotion: reduceMotion,
                isClutch: wasClutch
            ),
            heartbeatDelay: PitchFeedbackTimeline.heartbeatResumeDelay(
                reduceMotion: reduceMotion,
                isClutch: wasClutch
            )
        )
    }

    /// 결과 햅틱을 포구·타격에 붙이고, 충분한 정적 뒤에 다음 심박을 다시 올린다.
    @MainActor
    private func runScheduledPitchFeedback(_ feedback: ScheduledPitchFeedback) async {
        var elapsed: TimeInterval = 0
        if let success = feedback.outcomeSuccess {
            guard await waitForPitchFeedback(feedback.resultDelay),
                  scheduledPitchFeedback?.id == feedback.id else { return }
            Haptics.shared.outcome(success: success)
            elapsed = feedback.resultDelay
        }

        guard await waitForPitchFeedback(feedback.heartbeatDelay - elapsed),
              scheduledPitchFeedback?.id == feedback.id else { return }

        if session.pitchLog.count == feedback.pitchCount,
           !isPractice,
           scenePhase == .active,
           case .ready = session.stage {
            startMoundHeartbeat(includeEntry: false)
        }
        if scheduledPitchFeedback?.id == feedback.id {
            scheduledPitchFeedback = nil
        }
    }

    private func waitForPitchFeedback(_ seconds: TimeInterval) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(nanoseconds: PitchFeedbackTimeline.nanoseconds(seconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    /// 축하음과 자동 소멸을 오버레이의 task 수명에 묶는다. 화면을 떠나거나 새 퍼펙트가
    /// 들어오면 이전 task가 취소되어 늦은 소리·늦은 상태 변경이 남지 않는다.
    @MainActor
    private func runPerfectReleaseFeedback(id: UUID) async {
        let lifetime = PerfectReleaseFeedback.lifetimeNanoseconds(reduceMotion: reduceMotion)
        do {
            try await Task.sleep(nanoseconds: PerfectReleaseFeedback.accentSoundDelayNanoseconds)
        } catch {
            return
        }
        guard perfectReleaseCelebrationID == id else { return }
        audio.play(.milestone)

        do {
            try await Task.sleep(
                nanoseconds: lifetime - PerfectReleaseFeedback.accentSoundDelayNanoseconds
            )
        } catch {
            return
        }
        guard perfectReleaseCelebrationID == id else { return }
        perfectReleaseCelebrationID = nil
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
                    let delay = PitchFeedbackTimeline.heartbeatResumeDelay(
                        reduceMotion: reduceMotion,
                        isClutch: wasClutch
                    )
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
        // 화면 단위 축하 레이어. footer의 stage 교체와 독립되어 다음 공 안내에 잔상이 붙지 않는다.
        .overlay {
            if let celebrationID = perfectReleaseCelebrationID {
                PerfectReleaseCelebration(
                    title: copyResolver.resolve(.deliveryNowPerfect),
                    reduceMotion: reduceMotion
                )
                .id(celebrationID)
                .task { await runPerfectReleaseFeedback(id: celebrationID) }
            }
        }
        // 스코어보드 바가 상단을 맡는다. 내비게이션 제목은 같은 정보를 두 번 말한다.
        .toolbar(.hidden, for: .navigationBar)
        // 승부 중에는 탭 바를 숨긴다. 이닝 중간에 다른 탭으로 빠져나가면 세션 상태가
        // 화면에서 사라지고, 주력 장면의 몰입도 끊긴다.
        .toolbar(.hidden, for: .tabBar)
        .task(id: scheduledPitchFeedback?.id) {
            guard let feedback = scheduledPitchFeedback else { return }
            await runScheduledPitchFeedback(feedback)
        }
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
            // 결과는 공이 도착한 순간에, 다음 심박은 리플레이가 끝난 뒤에 온다. 즉시 연달아
            // 울리면 릴리스·결과·심박이 한 덩어리 진동이 되어 무엇을 잘했는지 읽히지 않는다.
            schedulePitchFeedback()
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
            cancelScheduledPitchFeedback()
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
            case .ready:
                if scheduledPitchFeedback == nil {
                    startMoundHeartbeat(includeEntry: false)
                }
            default: stopMoundHeartbeat()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if scheduledPitchFeedback == nil {
                    startMoundHeartbeat(includeEntry: false)
                }
            } else {
                // Backgrounding must cancel both the stored schedule and any in-flight windup.
                cancelScheduledPitchFeedback()
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
                // 준비가 계산되는 아주 짧은 순간만 보여야 한다. 어두운 캔버스 위의 무표정
                // ProgressView는 "투구 후 검은 화면" 리뷰의 얼굴이었다 — 글자를 붙이고,
                // 오래 남으면 감시 이벤트로 신고한다.
                ProgressView {
                    Text(verbatim: copyResolver.resolve(.statePreparing))
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .stallWatchdog("pitch_preparation_missing")
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
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("pitch.deliveryHint")
                        }
                        Text(verbatim: PitchPresentation.shortFeedback(result.snapshot, resolver: copyResolver))
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: PitchPresentation.detailFeedback(result.snapshot, resolver: copyResolver))
                            .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                        if delivery.isPerfectRelease {
                            perfectReleaseCelebrationID = UUID()
                        }
                    },
                    onWindUp: { cancelScheduledPitchFeedback() },
                    onRelease: {
                        cancelScheduledPitchFeedback()
                        stopMoundHeartbeat()
                    },
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
                        cancelScheduledPitchFeedback()
                        stopMoundHeartbeat()
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
                    cancelScheduledPitchFeedback()
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
                let delay = PitchFeedbackTimeline.reducedMotionCueInterval * Double(min(index, 3))
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { audio.play(cue) }
            }
            return
        }
        replayProgress = 0
        // 승부구는 슬로모션 — 같은 1.6초면 승부구가 승부구로 안 읽힌다. 소리 박자도
        // 같은 배율로 늘어져야 심판이 공보다 빨라지지 않는다.
        let tempo = PitchFeedbackTimeline.tempo(isClutch: wasClutch)
        withAnimation(.linear(duration: PitchFeedbackTimeline.standardReplayDuration * tempo)) {
            replayProgress = 1
        }

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
                case 0: PitchFeedbackTimeline.resultHapticDelay(
                    reduceMotion: false,
                    isClutch: wasClutch
                )
                case 1: 1.18 * tempo
                default: 1.5 * tempo
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { audio.play(cue) }
        }
    }
}

