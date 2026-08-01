import Foundation
import Observation
import SimulationCore

/// 중요 경기 한 이닝을 실제로 던지는 세션.
///
/// 이전 구현은 선택지 3개에 고정된 `ImportantInningReport` 상수를 돌려주어 선수 능력치도,
/// 상대도, 난수도 결과에 영향을 주지 않았다. 이 세션은 공유 코어의 `PitchKernelEngine`으로
/// 한 구씩 실제 판정을 내고, 그 결과를 누적해 리포트를 만든다(계획 문서 §2.2).
@MainActor
@Observable
final class PitchSession {
    enum Stage: Equatable {
        /// 다음 투구를 기다린다.
        case ready
        /// 타석이 끝났고 다음 타자를 기다린다.
        case betweenBatters(String)
        /// 이닝이 끝났다. 리포트가 확정됐다.
        case finished
        case failed(String)
    }

    private let engine = PitchKernelEngine()
    let scenario: PitchScenario

    private(set) var stage: Stage = .ready
    private(set) var batterIndex = 0
    private(set) var seed: String
    private(set) var context: PlateAppearanceContext
    private(set) var gameState: GameStateSnapshot
    /// 등판을 시작한 시점의 누적 아웃카운트. 실제로 몇 아웃을 잡았는지를 재려면 기준점이 필요하다.
    private(set) var gameLog: GameLogSnapshot
    private(set) var rivalMemory: RivalMemorySnapshot?
    private(set) var scouting: BatterScoutingSnapshot
    private(set) var preparation: PitchPreparation?
    private(set) var lastResult: PitchKernelResult?
    private(set) var pitchLog: [PitchLogEntry] = []
    /// 직전 투구가 내야 할 소리. 화면이 읽어 재생한다. 세션이 직접 소리를 내지 않으므로
    /// 유닛 테스트가 오디오 엔진을 켜지 않는다.
    private(set) var lastCues: [GameAudioCue] = []
    /// 직전 투구의 릴리스 품질. 손맛 판정을 화면에 보여 주는 데 쓴다.
    private(set) var lastDelivery: PitchDelivery?
    /// 이번 이닝에 나온 릴리스 관련 업적. 이닝이 끝날 때 한 번에 기록한다.
    private(set) var bestDeliveryAchievements: [Achievement] = []

    /// 누적 중인 리포트 필드. 타석이 끝날 때마다 갱신된다.
    private(set) var pitches = 0
    private(set) var strikeouts = 0
    /// 타자 연속 삼진. 이닝이 바뀌어도 등판 안에서는 이어진다 — 실제 "○타자 연속 삼진"
    /// 기록이 그렇게 센다. 삼진이 아닌 타석 결과가 나오면 끊긴다.
    private(set) var consecutiveStrikeouts = 0
    /// 기질 특성. 성격이 굳은 회차의 세션에만 실린다 — nil이면 판정이 완전히 같다.
    var trait: PersonalityTrait?
    /// 방금 공에서 특성이 발동했는가. 커널과 같은 조건식(fires)을 같은 입력으로
    /// 평가한다 — 발동은 배지로 공개된다. 숨은 보정은 이 게임에 없다.
    private(set) var lastTraitFired = false
    private(set) var walks = 0
    private(set) var runsAllowed = 0
    private(set) var expectedDamage = 0
    private(set) var actualDamage = 0
    private(set) var recommendationAccepted = 0

    /// 사인 고정 — 켜면 포수 추천이 내 선택을 덮어쓰지 않는다.
    /// 기본은 꺼짐(추천으로 채움): 인지 부하가 가장 낮은 경로가 초보의 경로다.
    /// 내 배합을 유지하고 싶은 순간 한 번의 토글로 의도가 살아남는다.
    var holdCall = false
    /// 플레이어가 고른 사인. 매 투구 준비마다 포수 추천으로 초기화된다(고정 시 유지).
    var selectedPitchType: PitchType = .fourSeam
    var selectedZone = PitchZone(row: 1, column: 1)
    var selectedIntent: ZoneIntent = .strike
    var selectedIntensity: PitchIntensity = .normal

    struct PitchLogEntry: Identifiable {
        let id = UUID()
        let pitchNumber: Int
        let call: PitchCall
        let outcome: PitchOutcome
        let shortFeedback: String
        let acceptedRecommendation: Bool
    }

    /// 타석이 끝날 때마다 불린다. 스토어가 여기서 진행을 디스크에 남긴다 —
    /// 이 게임의 유일한 실제 플레이 구간이 전화 한 통에 증발하면 안 된다.
    var onCheckpoint: ((PitchSession) -> Void)?

    /// 타석 경계의 저장용 스냅샷. 공 하나 단위가 아니라 타석 단위라
    /// 리트라이 스커밍이 열리지 않고 상태량도 작다.
    struct ResumeState: Codable, Equatable {
        var scenarioID: String
        var seed: String
        var batterIndex: Int
        /// "between"(다음 타자 대기) 또는 "finished"(결과 반영 대기).
        var stageKind: String
        var stageMessage: String?
        var fatigue: Int
        var gameState: GameStateSnapshot
        var gameLog: GameLogSnapshot
        var rivalMemory: RivalMemorySnapshot?
        var pitches: Int
        var strikeouts: Int
        var consecutiveStrikeouts: Int
        var walks: Int
        var runsAllowed: Int
        var expectedDamage: Int
        var actualDamage: Int
        var recommendationAccepted: Int
        var outsRecorded: Int
        var rivalOutcomes: [PlateAppearanceResult]
    }

    /// 지금 상태의 저장 스냅샷. 타석이 끝난 순간(대기/종료)에만 값이 있다.
    func resumeState() -> ResumeState? {
        let kind: String
        let message: String?
        switch stage {
        case .betweenBatters(let text): kind = "between"; message = text
        case .finished: kind = "finished"; message = nil
        default: return nil
        }
        return ResumeState(
            scenarioID: scenario.id, seed: seed, batterIndex: batterIndex,
            stageKind: kind, stageMessage: message, fatigue: context.fatigue,
            gameState: gameState, gameLog: gameLog, rivalMemory: rivalMemory,
            pitches: pitches, strikeouts: strikeouts, consecutiveStrikeouts: consecutiveStrikeouts,
            walks: walks, runsAllowed: runsAllowed,
            expectedDamage: expectedDamage, actualDamage: actualDamage,
            recommendationAccepted: recommendationAccepted, outsRecorded: outsRecorded,
            rivalOutcomes: rivalOutcomes
        )
    }

    /// 저장된 타석 경계에서 이어 던진다. 시나리오가 같은 스냅샷에서 재구성됐다는
    /// 전제(id 일치)는 호출자가 검사한다.
    func restore(from resume: ResumeState) {
        seed = resume.seed
        batterIndex = resume.batterIndex
        gameState = resume.gameState
        gameLog = resume.gameLog
        rivalMemory = resume.rivalMemory
        pitches = resume.pitches
        strikeouts = resume.strikeouts
        consecutiveStrikeouts = resume.consecutiveStrikeouts
        walks = resume.walks
        runsAllowed = resume.runsAllowed
        expectedDamage = resume.expectedDamage
        actualDamage = resume.actualDamage
        recommendationAccepted = resume.recommendationAccepted
        outsRecorded = resume.outsRecorded
        rivalOutcomes = resume.rivalOutcomes
        context = PlateAppearanceContext(
            plateAppearanceID: "\(scenario.id)-b\(batterIndex)",
            revision: context.revision, inning: gameState.inningState?.inning ?? context.inning,
            outs: gameState.inningState?.outs ?? context.outs, balls: 0, strikes: 0,
            pitchNumber: 1, scoreDifferential: scenario.scoreDifferential,
            leverage: scenario.leverage, fatigue: resume.fatigue
        )
        stage = resume.stageKind == "finished"
            ? .finished
            : .betweenBatters(resume.stageMessage ?? "타석이 끝났습니다. 이어서 던집니다.")
    }

    private var pitcher: PitcherSnapshot { scenario.pitcher }
    var batter: BatterSnapshot { scenario.lineup[min(batterIndex, scenario.lineup.count - 1)] }
    var pitcherName: String { scenario.pitcher.name }
    var repertoire: [PitchType] {
        scenario.pitcher.pitchProfiles.map { $0.map(\.pitchType) } ?? PitchType.allCases
    }

    init(scenario: PitchScenario, seed: String) {
        self.scenario = scenario
        self.seed = seed
        self.scouting = scenario.scouting
        self.gameState = scenario.gameState
        self.gameLog = GameLogSnapshot(gameID: scenario.id, revision: 0, totalPitches: 0, entries: [])
        self.context = PlateAppearanceContext(
            plateAppearanceID: "\(scenario.id)-b0",
            revision: 0,
            inning: scenario.inning,
            outs: scenario.outs,
            balls: 0,
            strikes: 0,
            pitchNumber: 1,
            scoreDifferential: scenario.scoreDifferential,
            leverage: scenario.leverage,
            fatigue: scenario.fatigue
        )
    }

    convenience init(state: ProCareerSnapshot, seed: String) {
        self.init(scenario: .pro(state: state), seed: seed)
    }

    convenience init(highSchool state: HighSchoolCareerSnapshot, seed: String) {
        self.init(scenario: .highSchool(state: state), seed: seed)
    }

    // MARK: - 진행

    func start() {
        guard preparation == nil else { return }
        // 등판 하나가 곧 하나의 매치업이다. 시나리오 id를 벤치 식별자로 쓴다.
        rivalMemory = RivalMemoryEngine().benchMemory(pitcher: pitcher, benchID: scenario.id)
        prepare()
    }

    /// 다음 타자의 첫 투구를 준비한다. 타석이 끝난 뒤에만 의미가 있다.
    func advanceToNextBatter() {
        guard case .betweenBatters = stage else { return }
        batterIndex += 1
        // **기억을 버리지 않는다.** 상대 벤치가 등판 전체를 지켜본다.
        //
        // 예전에는 여기서 `rivalMemory = nil`이었다. 기억이 투수-타자 한 쌍에 묶여 있어
        // 안 버리면 커널이 거부했기 때문이다. 그 결과 학습이 한 타석 안에서만 일어나
        // 적응도가 420에서 하드캡됐고, "완전히 읽힘"과 포수의 반복 경고는 도달할 수 없는
        // 죽은 코드였다 — 이 게임이 파는 "같은 공을 반복하면 읽힌다"가 실제 승부에서
        // 성립하지 않았다는 뜻이다. 지금은 벤치 스코프라 타자가 바뀌어도 이어진다.
        // 직전 타자의 결과를 지운다. 안 지우면 새 타자와 붙는 화면에 "안타"가 그대로 떠
        // 있어서, 방금 그 공에 맞은 것처럼 보인다. 승부 장면·판정·소리 모두 같은 문제다.
        lastResult = nil
        lastCues = []
        lastDelivery = nil
        stage = .ready
        prepare()
    }

    func throwPitch(delivery: PitchDelivery? = nil) {
        guard case .ready = stage, let preparation else { return }
        let call = PitchCall(
            pitchType: selectedPitchType,
            zone: selectedZone,
            zoneIntent: selectedIntent,
            intensity: selectedIntensity
        )
        do {
            var params = SubmitPitchParams(
                seed: seed,
                pitcher: pitcher,
                batter: batter,
                scouting: scouting,
                context: context,
                preparationToken: preparation.preparationToken,
                call: call,
                rivalMemory: rivalMemory,
                gameState: gameState,
                gameLog: gameLog
            )
            params.trait = trait
            lastTraitFired = trait.map { $0.fires(context: context, runners: gameState.runners) } ?? false
            let result = try engine.submitPitch(params, delivery: delivery)
            lastDelivery = delivery
            for achievement in AchievementRules.fromDelivery(delivery)
            where !bestDeliveryAchievements.contains(achievement) {
                bestDeliveryAchievements.append(achievement)
            }
            absorb(result, call: call)
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    /// 이번 등판에서 실제로 잡은 아웃카운트. 매 투구의 차이로 누적한다.
    ///
    /// 예전에는 이 값을 넘기지 않아 코어가 이닝을 `투구수 / 5`로 어림했다. 그다음에는
    /// 최종 상태에서 역산했는데, 이닝을 막아내면 초가 말(아웃 0)로 넘어가며 **막 잡은
    /// 3아웃이 통째로 사라졌다** — 잘 던질수록 이닝이 기록되지 않아 RA/9가 부풀고
    /// 화면에 "0.0이닝"이 찍혔다.
    private(set) var outsRecorded = 0
    /// 숙적(라이벌)을 상대한 타석 결과들. 고교 중요 경기의 1번 타자가 언제나 그다 —
    /// 통산 상대 전적은 스토어가 회차 단위로 쌓는다.
    private(set) var rivalOutcomes: [PlateAppearanceResult] = []

    /// 회·초말·아웃을 한 줄의 절대 아웃 수로 편다. 초가 끝나면 말의 아웃 0으로 리셋되므로,
    /// 회·아웃만 보면 이닝 종료 순간의 아웃이 사라진다.
    static func totalOuts(_ state: InningStateSnapshot?) -> Int {
        guard let state else { return 0 }
        return (state.inning - 1) * 6 + (state.half == .bottom ? 3 : 0) + state.outs
    }

    /// 지금까지 던진 결과로 프로 커리어에 넘길 리포트를 만든다.
    func report(scenarioNumber: Int) -> ImportantInningReport {
        ImportantInningReport(
            scenarioNumber: scenarioNumber,
            pitches: pitches,
            strikeouts: strikeouts,
            walks: walks,
            runsAllowed: runsAllowed,
            expectedDamage: expectedDamage,
            actualDamage: actualDamage,
            recommendationAccepted: recommendationAccepted,
            outs: outsRecorded,
            // 절대 점수 배분은 코어의 일이다. 화면은 등판 시점의 점수 차만 알려 준다.
            scoreDifferentialAtEntry: scenario.scoreDifferential
        )
    }

    // MARK: - 내부

    private func absorb(_ result: PitchKernelResult, call: PitchCall) {
        let outsBefore = Self.totalOuts(gameState.inningState)
        lastResult = result
        seed = result.nextSeed
        gameState = result.gameState
        gameLog = result.gameLog
        rivalMemory = result.rivalMemory
        outsRecorded += max(0, Self.totalOuts(result.gameState.inningState) - outsBefore)

        let snapshot = result.snapshot
        lastCues = GameAudioMapping.cues(for: snapshot)
        pitches += 1
        strikeouts += snapshot.result == .strikeout ? 1 : 0
        if let plateResult = snapshot.result {
            consecutiveStrikeouts = plateResult == .strikeout ? consecutiveStrikeouts + 1 : 0
            // 라이벌 타석이 끝났다. batterIndex는 아직 이 타자를 가리킨다.
            if scenario.id.hasPrefix("hs-"), batter.id == scenario.lineup.first?.id {
                rivalOutcomes.append(plateResult)
            }
        }
        walks += snapshot.result == .walk ? 1 : 0
        runsAllowed += snapshot.runsScored
        recommendationAccepted += snapshot.recommendationAccepted ? 1 : 0
        if let entry = result.gameLog.entries.last {
            expectedDamage += entry.expectedDamage
            actualDamage += entry.actualDamage
        }
        pitchLog.append(
            PitchLogEntry(
                pitchNumber: context.pitchNumber,
                call: call,
                outcome: snapshot.outcome,
                shortFeedback: snapshot.shortFeedback,
                acceptedRecommendation: snapshot.recommendationAccepted
            )
        )

        if let next = result.nextPreparation {
            // 타석이 이어진다. 코어가 만들어 준 다음 준비를 그대로 쓴다.
            context = Self.nextContext(from: context, snapshot: snapshot, gameState: result.gameState)
            preparation = next
            applyRecommendation(next)
            stage = .ready
            return
        }

        let inningEnded = snapshot.inningTransition?.inningEnded ?? false
        let reachedCap = batterIndex + 1 >= min(scenario.maximumBatters, scenario.lineup.count)
        if inningEnded || reachedCap {
            stage = .finished
            preparation = nil
        } else {
            stage = .betweenBatters(snapshot.shortFeedback)
            preparation = nil
        }
        onCheckpoint?(self)
    }

    private func prepare() {
        let inning = gameState.inningState?.inning ?? context.inning
        let outs = gameState.inningState?.outs ?? context.outs
        context = PlateAppearanceContext(
            plateAppearanceID: "\(scenario.id)-b\(batterIndex)",
            revision: context.revision,
            inning: inning,
            outs: outs,
            balls: 0,
            strikes: 0,
            pitchNumber: 1,
            scoreDifferential: scenario.scoreDifferential,
            leverage: scenario.leverage,
            fatigue: context.fatigue
        )
        do {
            let prepared = try engine.preparePitch(
                .init(
                    seed: seed,
                    pitcher: pitcher,
                    batter: batter,
                    scouting: scouting,
                    context: context,
                    rivalMemory: rivalMemory,
                    gameState: gameState,
                    gameLog: gameLog
                )
            )
            preparation = prepared
            applyRecommendation(prepared)
            stage = .ready
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    private func applyRecommendation(_ preparation: PitchPreparation) {
        guard !holdCall else { return }
        let call = preparation.primaryRecommendation.call
        selectedPitchType = call.pitchType
        selectedZone = call.zone
        selectedIntent = call.zoneIntent
        selectedIntensity = call.intensity
    }

    /// 타석이 이어질 때 코어가 내부에서 쓴 것과 같은 다음 컨텍스트를 재구성한다.
    private static func nextContext(
        from context: PlateAppearanceContext,
        snapshot: PlateAppearanceSnapshot,
        gameState: GameStateSnapshot
    ) -> PlateAppearanceContext {
        PlateAppearanceContext(
            plateAppearanceID: context.plateAppearanceID,
            revision: snapshot.revision,
            inning: gameState.inningState?.inning ?? context.inning,
            outs: gameState.inningState?.outs ?? context.outs,
            balls: snapshot.balls,
            strikes: snapshot.strikes,
            pitchNumber: context.pitchNumber + 1,
            scoreDifferential: context.scoreDifferential,
            leverage: context.leverage,
            fatigue: snapshot.fatigueAfterPitch
        )
    }

}
