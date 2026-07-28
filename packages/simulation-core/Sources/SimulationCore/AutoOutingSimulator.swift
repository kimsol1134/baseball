import Foundation

/// 플레이어가 개입하지 않는 등판을 실제 투구 커널로 돌린다.
///
/// **왜 별도 타입인가**: 프로 주간 등판이 쓰던 것을 고교 자동 경기와 밸런스 CLI가 함께 쓴다.
/// 세 곳이 각자 흉내 낸 시뮬레이션을 갖게 되면 밸런스를 한 번에 볼 수 없고, 화면에 나오는
/// 성적이 어디서 나왔는지 추적할 수 없다. 하나만 두고 상대 타선 강도만 인자로 받는다.
///
/// 여기서 나오는 성적은 **근사가 아니다** — 매 타석을 `PitchKernelEngine`에 통과시킨다.
/// 그래서 자동으로 흘러간 경기와 직접 던진 경기가 같은 규칙 위에 있다.
public struct AutoOutingSimulator: Sendable {
    /// 등판 하나의 원시 집계.
    public struct Line: Equatable, Sendable {
        public var outs = 0
        public var strikeouts = 0
        public var walks = 0
        public var runsAllowed = 0
        public var pitches = 0
        public var hits = 0
        public var homeRuns = 0
        /// 장타 분해. 실점이 안타 수와 어긋날 때 원인이 장타 부족인지 보려면 이 숫자가 있어야 한다.
        public var doubles = 0
        public var triples = 0

        public init() {}
    }

    public init() {}

    /// 값 범위를 자른다. 이 파일 안에서만 쓰는 지역 도우미다.
    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(upper, max(lower, value))
    }

    /// - Parameter batterOffset: 상대 타선의 세 능력치(컨택·선구·장타) 기준선 보정.
    ///   프로 리그 평균이 0이고, 고교는 음수를 준다. 이 인자 하나로 리그 수준을 표현한다.
    public func simulate(
        pitcher: PitcherSnapshot,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        batterOffset: Int = 0,
        baseSeed: UInt64
    ) -> Line {
        let engine = PitchKernelEngine()
        var rng = SplitMix64(seed: baseSeed)
        var line = Line()
        let fielders = FielderPosition.allCases.map {
            FielderSnapshot(id: "week-\($0.rawValue)", name: $0.rawValue, position: $0, range: 50, glove: 50, arm: 50)
        }
        var inningState = InningStateSnapshot(inning: 1, half: .top, outs: 0)
        var runners = BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 52)
        var runsOnBoard = 0
        var carriedGameLog = GameLogSnapshot(gameID: "week-outing", revision: 0, totalPitches: 0, entries: [])
        var currentFatigue = clamp(startingFatigue, 0, 95)
        var benchMemory: RivalMemorySnapshot?
        var paIndex = 0
        while line.outs < outsTarget && line.pitches < pitchCap && paIndex < 60 {
            paIndex += 1
            let batter = BatterSnapshot(
                id: "week-batter-\(paIndex)", name: "상대 타선",
                contact: clamp(50 + batterOffset + rng.nextInt(upperBound: 9) - 4, 20, 80),
                discipline: clamp(50 + batterOffset + rng.nextInt(upperBound: 7) - 3, 20, 80),
                power: clamp(50 + batterOffset + rng.nextInt(upperBound: 9) - 4, 20, 80),
                batSide: rng.nextInt(upperBound: 100) < 32 ? .left : .right
            )
            // 강점과 약점 코스는 서로 마주 보게 잡는다.
            //
            // 예전에는 둘을 각각 무작위로 뽑아서 **11%의 타자가 강점과 약점이 같은 칸**이었다.
            // 그러면 포수가 약점인 줄 알고 타자가 가장 잘 치는 코스를 요구한다 — 실제
            // 스카우팅에서는 있을 수 없는 일이고, 자동 등판의 피안타율만 실제 야구보다
            // 높아지는 원인이었다.
            let hotZone = PitchZone(row: rng.nextInt(upperBound: 3), column: rng.nextInt(upperBound: 3))
            let coldZone = PitchZone(row: 2 - hotZone.row, column: 2 - hotZone.column)
            let scouting = BatterScoutingSnapshot(
                hotZone: hotZone,
                // 한가운데가 강점이면 대칭점도 한가운데다. 그때만 낮은 바깥쪽으로 민다.
                coldZone: coldZone == hotZone ? PitchZone(row: 2, column: 0) : coldZone,
                pitchStrength: .fourSeam,
                pitchWeakness: rng.nextInt(upperBound: 2) == 0 ? .slider : .changeup,
                chaseTendency: clamp(48 + rng.nextInt(upperBound: 9) - 4, 20, 80)
            )
            var gameState = GameStateSnapshot(
                defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50, fielders: fielders),
                park: ParkSnapshot(id: "league-week-park", name: "리그 구장", hitFactor: 1_000, homeRunFactor: 1_000),
                runners: runners, runsAllowed: runsOnBoard, inningState: inningState
            )
            var gameLog = carriedGameLog
            var context = PlateAppearanceContext(
                plateAppearanceID: "week-pa-\(paIndex)", revision: 0,
                inning: inningState.inning, outs: inningState.outs,
                balls: 0, strikes: 0, pitchNumber: 1,
                scoreDifferential: 0, leverage: 500, fatigue: currentFatigue
            )
            var seed = String(max(1, rng.next() >> 1))
            // 자동 등판도 사람이 던지는 등판과 같은 규칙을 쓴다. 상대 벤치가 등판 전체를
            // 지켜보므로 기억이 타석을 넘어 이어진다 — 두 경로가 다른 규칙 위에 있으면
            // 화면에 나오는 성적이 어디서 나왔는지 추적할 수 없다.
            if benchMemory == nil {
                benchMemory = RivalMemoryEngine().benchMemory(pitcher: pitcher, benchID: "outing")
            }
            var paMemory: RivalMemorySnapshot? = benchMemory
            guard var preparation = try? engine.preparePitch(PreparePitchParams(
                seed: seed, pitcher: pitcher, batter: batter, scouting: scouting,
                context: context, rivalMemory: paMemory, gameState: gameState, gameLog: gameLog
            )) else { break }
            let outsBefore = (inningState.inning - 1) * 3 + inningState.outs
            while true {
                guard let result = try? engine.submitPitch(SubmitPitchParams(
                    seed: seed, pitcher: pitcher, batter: batter, scouting: scouting,
                    context: context, preparationToken: preparation.preparationToken,
                    call: preparation.primaryRecommendation.call,
                    rivalMemory: paMemory, gameState: gameState, gameLog: gameLog
                )) else { return line }
                paMemory = result.rivalMemory
                benchMemory = result.rivalMemory
                gameState = result.gameState
                gameLog = result.gameLog
                line.pitches += 1
                currentFatigue = clamp(result.snapshot.fatigueAfterPitch, 0, 95)
                if let paResult = result.snapshot.result {
                    if paResult == .strikeout { line.strikeouts += 1 }
                    if paResult == .walk { line.walks += 1 }
                    if paResult == .hit {
                        line.hits += 1
                        switch result.snapshot.outcome {
                        case .homeRun: line.homeRuns += 1
                        case .triple: line.triples += 1
                        case .double: line.doubles += 1
                        default: break
                        }
                    }
                }
                if result.snapshot.ended {
                    line.runsAllowed += result.snapshot.runsScored
                    runsOnBoard = result.gameState.runsAllowed
                    carriedGameLog = result.gameLog
                    inningState = result.gameState.inningState ?? inningState
                    runners = result.gameState.runners
                    let outsAfter = (inningState.inning - 1) * 3 + inningState.outs
                    line.outs += max(0, outsAfter - outsBefore)
                    break
                }
                seed = result.nextSeed
                context = PlateAppearanceContext(
                    plateAppearanceID: context.plateAppearanceID,
                    revision: result.revision,
                    inning: result.gameState.inningState?.inning ?? context.inning,
                    outs: result.gameState.inningState?.outs ?? context.outs,
                    balls: result.snapshot.balls,
                    strikes: result.snapshot.strikes,
                    pitchNumber: context.pitchNumber + 1,
                    scoreDifferential: context.scoreDifferential,
                    leverage: context.leverage,
                    fatigue: currentFatigue
                )
                guard let nextPreparation = result.nextPreparation else { return line }
                preparation = nextPreparation
            }
        }
        return line
    }
}
