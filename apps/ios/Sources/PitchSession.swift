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
    private let entryTotalOuts: Int
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
    private(set) var walks = 0
    private(set) var runsAllowed = 0
    private(set) var expectedDamage = 0
    private(set) var actualDamage = 0
    private(set) var recommendationAccepted = 0

    /// 플레이어가 고른 사인. 매 투구 준비마다 포수 추천으로 초기화된다.
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
        self.entryTotalOuts = (scenario.gameState.inningState?.inning ?? scenario.inning).advanced(by: -1) * 3
            + (scenario.gameState.inningState?.outs ?? scenario.outs)
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
        prepare()
    }

    /// 다음 타자의 첫 투구를 준비한다. 타석이 끝난 뒤에만 의미가 있다.
    func advanceToNextBatter() {
        guard case .betweenBatters = stage else { return }
        batterIndex += 1
        // 라이벌 기억은 투수-타자 조합 하나에 묶여 있다. 타자가 바뀌면 버려야 코어가
        // matchupID 불일치로 거부하지 않는다.
        rivalMemory = nil
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
            let result = try engine.submitPitch(
                .init(
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
                ),
                delivery: delivery
            )
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

    /// 이번 등판에서 실제로 잡은 아웃카운트.
    ///
    /// 예전에는 이 값을 넘기지 않아 코어가 이닝을 `투구수 / 5`로 어림했다. 삼진을 많이 잡아
    /// 투구수가 늘면 던지지도 않은 이닝이 성적에 붙었다.
    var outsRecorded: Int {
        let inning = gameState.inningState?.inning ?? context.inning
        let outs = gameState.inningState?.outs ?? context.outs
        return max(0, (inning - 1) * 3 + outs - entryTotalOuts)
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
        lastResult = result
        seed = result.nextSeed
        gameState = result.gameState
        gameLog = result.gameLog
        rivalMemory = result.rivalMemory

        let snapshot = result.snapshot
        lastCues = GameAudioMapping.cues(for: snapshot)
        pitches += 1
        strikeouts += snapshot.result == .strikeout ? 1 : 0
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
