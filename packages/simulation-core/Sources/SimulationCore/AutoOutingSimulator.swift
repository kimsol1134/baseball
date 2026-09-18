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

    /// Which balance pass the pitch kernel runs for these outings. `.legacy` keeps the frozen
    /// fixture path; callers on newer career rules pass `.school` or `.professional`.
    public let balance: PitchBalanceRules
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
        /// 자책점. 실책과 승계 주자를 가려내는 원장이 있는 프로 경로에서만 값이 있다.
        /// 원장 없이 돌린 등판은 `nil` — 추정하지 않는다.
        public var earnedRuns: Int?

        public init() {}
    }

    public init(balance: PitchBalanceRules = .legacy) {
        self.balance = balance
    }

    /// 값 범위를 자른다. 이 파일 안에서만 쓰는 지역 도우미다.
    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(upper, max(lower, value))
    }

    /// 회·초말·아웃을 한 줄의 절대 아웃 수로 편다. 초가 끝나면 같은 회의 말(아웃 0)로
    /// 넘어가므로, 초말을 무시하면 초의 세 번째 아웃이 통째로 사라진다 — 경기당 이닝의
    /// 약 1/6이 유실되어 "5.2이닝 19K" 같은 불가능한 기록의 원인이 됐다.
    private func absoluteOuts(_ state: InningStateSnapshot) -> Int {
        (state.inning - 1) * 6 + (state.half == .bottom ? 3 : 0) + state.outs
    }

    /// - Parameter batterOffset: 상대 타선의 세 능력치(컨택·선구·장타) 기준선 보정.
    ///   프로 리그 평균이 0이고, 고교는 음수를 준다. 이 인자 하나로 리그 수준을 표현한다.
    /// - Parameter callPolicy: `.perfect`는 기존과 같은 시드 스트림을 유지한다.
    ///   다른 정책만 타석당 한 번 추가 난수를 쓴다.
    /// - Parameter diverseScouting: 약점·존을 아키타입 해시 표로 펼친다. 기본값은 false라
    ///   v8 커리어와 픽스처 경로의 RNG 소비가 그대로다. 기존 `nextInt` 호출은 켠 뒤에도
    ///   같은 순서·횟수로 나간다.
    public func simulate(
        pitcher: PitcherSnapshot,
        startingFatigue: Int,
        outsTarget: Int,
        pitchCap: Int,
        batterOffset: Int = 0,
        callPolicy: AutoCallPolicy = .perfect,
        baseSeed: UInt64,
        diverseScouting: Bool = false,
        delivery: PitchDelivery? = nil,
        fullStart: Bool = false,
        priorOuts: Int = 0,
        priorPitches: Int = 0,
        priorRuns: Int = 0
    ) -> Line {
        // 프로 자동 등판의 포수는 안드로이드와 같은 코스 선택 규칙을 쓴다(버전 3).
        // v10·고교는 이미 배포된 계산이므로 버전 1 그대로다.
        let engine = PitchKernelEngine(
            recommendationEngine: CatcherRecommendationEngine(
                rules: CatcherSignRules(
                    version: balance.isProfessional
                        ? CatcherSignRules.scoutingTargetVersion
                        : CatcherSignRules.fixtureSafeVersion
                )
            ),
            balance: balance
        )
        var rng = SplitMix64(seed: baseSeed)
        var line = Line()
        let fielders = FielderPosition.allCases.map {
            FielderSnapshot(id: "week-\($0.rawValue)", name: $0.rawValue, position: $0, range: 50, glove: 50, arm: 50)
        }
        var inningState = InningStateSnapshot(
            inning: fullStart ? priorOuts / 3 + 1 : 1, half: .top, outs: 0
        )
        var runners = BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 52)
        var runsOnBoard = 0
        var carriedGameLog = GameLogSnapshot(
            gameID: "week-outing", revision: 0, totalPitches: priorPitches, entries: []
        )
        var currentFatigue = clamp(startingFatigue, 0, 95)
        var benchMemory: RivalMemorySnapshot?
        var paIndex = 0
        // 자책점 원장은 프로 경로에서만 돈다. 나머지 경로는 원장을 만들지 않으므로 이 등판의
        // 자책점은 '없음'으로 남는다. 원장이 커널이 보고한 주자와 어긋나면 그 자리에서
        // 버린다 — 어긋난 원장으로 계산한 자책점은 틀린 숫자이고, 틀린 숫자보다 '모른다'가 낫다.
        var scoring: PitchRunLedger? = balance.isProfessional ? PitchRunLedger() : nil
        var lastGameState: GameStateSnapshot?
        var lastSeed = String(baseSeed)
        // 선발 목표(6이닝 이상)에서만 체력 특화의 '한 타자 더'를 실제 아웃과 투구 수로
        // 보상한다. 불펜 역할은 원래 맡은 이닝이 짧으므로 같은 보너스를 적용하지 않는다.
        // 완투 경로에서는 목표 아웃과 투구 상한이 아니라 감독의 교체 판단이 등판을 끝낸다.
        // 체력 특화의 '한 타자 더'는 목표가 고정된 경로에서만 의미가 있으므로 여기서는 빠진다.
        let extensionOuts = !fullStart && outsTarget >= 18
            ? PitchAbilityRules.starterExtensionOuts(pitcher: pitcher)
            : 0
        let effectiveOutsTarget = fullStart ? 27 - priorOuts : outsTarget + extensionOuts
        let effectivePitchCap = fullStart ? 125 - priorPitches : pitchCap + extensionOuts * 4
        while line.outs < effectiveOutsTarget && line.pitches < effectivePitchCap && paIndex < 60 {
            if fullStart, !ProOutingUsageRules.canContinue(
                pitcher: pitcher,
                outs: line.outs + priorOuts,
                pitches: line.pitches + priorPitches,
                fatigue: currentFatigue,
                runs: line.runsAllowed + priorRuns,
                starter: true
            ) { break }
            paIndex += 1
            // 리그 평균 타자는 아홉 타석이 전부 같은 타석이었다. 프로 재조정 경로에서는
            // 실제 타순을 세운다. 평균 타자의 난수는 그대로 뽑아 두어 두 경로의 난수 소비
            // 순서가 어긋나지 않게 한다.
            let averageBatter = BatterSnapshot(
                id: "week-batter-\(paIndex)", name: "상대 타선",
                contact: clamp(50 + batterOffset + rng.nextInt(upperBound: 9) - 4, 20, 80),
                discipline: clamp(50 + batterOffset + rng.nextInt(upperBound: 7) - 3, 20, 80),
                power: clamp(50 + batterOffset + rng.nextInt(upperBound: 9) - 4, 20, 80),
                batSide: rng.nextInt(upperBound: 100) < 32 ? .left : .right
            )
            let batter = balance.isProfessional
                ? ProfessionalLineup.batter(teamKey: "lineup-\(baseSeed)", turn: paIndex, offset: batterOffset)
                : averageBatter
            // 강점과 약점 코스는 서로 마주 보게 잡는다.
            //
            // 예전에는 둘을 각각 무작위로 뽑아서 **11%의 타자가 강점과 약점이 같은 칸**이었다.
            // 그러면 포수가 약점인 줄 알고 타자가 가장 잘 치는 코스를 요구한다 — 실제
            // 스카우팅에서는 있을 수 없는 일이고, 자동 등판의 피안타율만 실제 야구보다
            // 높아지는 원인이었다.
            let hotZone = PitchZone(row: rng.nextInt(upperBound: 3), column: rng.nextInt(upperBound: 3))
            let coldZone = PitchZone(row: 2 - hotZone.row, column: 2 - hotZone.column)
            let weaknessDraw = rng.nextInt(upperBound: 2)
            let chaseTendency = clamp(48 + rng.nextInt(upperBound: 9) - 4, 20, 80)
            let scouting: BatterScoutingSnapshot
            if diverseScouting {
                let seedToken = "\(batter.id)|\(baseSeed)"
                let archetypes = BatterScoutingArchetype.allCases
                let archetype = archetypes[
                    Int(StableHash.fnv1a64Value(seedToken + "|archetype") % UInt64(archetypes.count))
                ]
                let profile = BatterScoutingProfileRules.profile(
                    archetype: archetype,
                    seedToken: seedToken
                )
                let mixedWeakness: [PitchType] = [.slider, .changeup, .curveball, .fourSeam]
                let hashBit = Int(StableHash.fnv1a64Value(seedToken + "|mix") % 2)
                scouting = BatterScoutingSnapshot(
                    hotZone: profile.hotZone,
                    coldZone: profile.coldZone,
                    pitchStrength: profile.pitchStrength,
                    pitchWeakness: mixedWeakness[weaknessDraw + hashBit * 2],
                    chaseTendency: chaseTendency
                )
            } else {
                scouting = BatterScoutingSnapshot(
                    hotZone: hotZone,
                    // 한가운데가 강점이면 대칭점도 한가운데다. 그때만 낮은 바깥쪽으로 민다.
                    coldZone: coldZone == hotZone ? PitchZone(row: 2, column: 0) : coldZone,
                    pitchStrength: .fourSeam,
                    pitchWeakness: weaknessDraw == 0 ? .slider : .changeup,
                    chaseTendency: chaseTendency
                )
            }
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
            let missThisPA: Bool
            if callPolicy == .perfect {
                missThisPA = false
            } else {
                let threshold = callPolicy == .slump ? 35 : 18
                missThisPA = rng.nextInt(upperBound: 100) < threshold
            }
            let outsBefore = absoluteOuts(inningState)
            while true {
                let call = missThisPA
                    ? preparation.alternativeRecommendation.call
                    : preparation.primaryRecommendation.call
                guard let result = try? engine.submitPitch(SubmitPitchParams(
                    seed: seed, pitcher: pitcher, batter: batter, scouting: scouting,
                    context: context, preparationToken: preparation.preparationToken,
                    call: call,
                    rivalMemory: paMemory, gameState: gameState, gameLog: gameLog
                ), delivery: delivery) else { return line }
                if let ledger = scoring {
                    scoring = try? ledger.advance(result.snapshot)
                }
                lastGameState = result.gameState
                lastSeed = result.nextSeed
                paMemory = result.rivalMemory
                benchMemory = result.rivalMemory
                gameState = result.gameState
                gameLog = result.gameLog
                line.pitches += 1
                currentFatigue = clamp(result.snapshot.fatigueAfterPitch, 0, 95)
                if let paResult = result.snapshot.result {
                    if paResult == .strikeout { line.strikeouts += 1 }
                    // 사구는 볼넷이 아니다. 거친 타석의 결과지 제구가 만든 출루가 아니라서
                    // BB/9에 섞이면 제구를 잘못 읽는다.
                    if paResult == .walk,
                       !(balance.isProfessional && result.snapshot.outcome == .hitByPitch) {
                        line.walks += 1
                    }
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
                    let outsAfter = absoluteOuts(inningState)
                    line.outs += max(0, outsAfter - outsBefore)
                    // 한 경기를 이어 던지는 경로에서는 회차를 실제 아웃 수로 되돌려 놓는다.
                    // 그러지 않으면 초말 전환이 아홉 회를 넘겨 버린다.
                    if fullStart {
                        inningState = InningStateSnapshot(
                            inning: min(9, (line.outs + priorOuts) / 3 + 1),
                            half: .top,
                            outs: (line.outs + priorOuts) % 3
                        )
                    }
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
        // 등판이 끝날 때 남긴 주자는 아직 이 투수의 책임이다. 남은 이닝을 리그 평균 구원
        // 투수로 마저 돌려 그 주자들이 홈을 밟았는지만 본다.
        if var ledger = scoring {
            if let lastGameState {
                ledger = settleReliefRuns(
                    engine: engine, game: lastGameState, ledger: ledger, seed: lastSeed
                )
            }
            line.runsAllowed = ledger.runs
            line.earnedRuns = ledger.earnedRuns
        }
        return line
    }
}
