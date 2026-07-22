import Foundation

public enum FieldingSector: String, Codable, Sendable {
    case infield
    case outfield
    case fence
}

public enum DefenseImpact: String, Codable, Sendable {
    case helpedPitcher = "helped_pitcher"
    case neutral
    case hurtPitcher = "hurt_pitcher"
}

public enum AnalysisConfidenceBand: String, Codable, Sendable {
    case low
    case developing
    case reliable
}

public enum FielderPosition: String, Codable, CaseIterable, Sendable {
    case pitcher
    case catcher
    case firstBase = "first_base"
    case secondBase = "second_base"
    case thirdBase = "third_base"
    case shortstop
    case leftField = "left_field"
    case centerField = "center_field"
    case rightField = "right_field"
}

public enum HalfInning: String, Codable, Sendable {
    case top
    case bottom
}

public struct FielderSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let position: FielderPosition
    public let range: Int
    public let glove: Int
    public let arm: Int

    public init(
        id: String,
        name: String,
        position: FielderPosition,
        range: Int,
        glove: Int,
        arm: Int
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.range = range
        self.glove = glove
        self.arm = arm
    }
}

public struct DefenseSnapshot: Codable, Equatable, Sendable {
    public let infield: Int
    public let outfield: Int
    public let arm: Int
    public let fielders: [FielderSnapshot]?

    public init(
        infield: Int,
        outfield: Int,
        arm: Int,
        fielders: [FielderSnapshot]? = nil
    ) {
        self.infield = infield
        self.outfield = outfield
        self.arm = arm
        self.fielders = fielders
    }

    public func fielder(at position: FielderPosition) -> FielderSnapshot? {
        fielders?.first { $0.position == position }
    }
}

public struct ParkSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let hitFactor: Int
    public let homeRunFactor: Int

    public init(id: String, name: String, hitFactor: Int, homeRunFactor: Int) {
        self.id = id
        self.name = name
        self.hitFactor = hitFactor
        self.homeRunFactor = homeRunFactor
    }
}

public struct BaserunnerStateSnapshot: Codable, Equatable, Sendable {
    public let firstOccupied: Bool
    public let secondOccupied: Bool
    public let thirdOccupied: Bool
    public let leadRunnerSpeed: Int

    public init(
        firstOccupied: Bool,
        secondOccupied: Bool,
        thirdOccupied: Bool,
        leadRunnerSpeed: Int
    ) {
        self.firstOccupied = firstOccupied
        self.secondOccupied = secondOccupied
        self.thirdOccupied = thirdOccupied
        self.leadRunnerSpeed = leadRunnerSpeed
    }

    public static let empty = BaserunnerStateSnapshot(
        firstOccupied: false,
        secondOccupied: false,
        thirdOccupied: false,
        leadRunnerSpeed: 50
    )

    public var occupiedCount: Int {
        [firstOccupied, secondOccupied, thirdOccupied].filter { $0 }.count
    }
}

public struct InningStateSnapshot: Codable, Equatable, Sendable {
    public let inning: Int
    public let half: HalfInning
    public let outs: Int

    public init(inning: Int, half: HalfInning, outs: Int) {
        self.inning = inning
        self.half = half
        self.outs = outs
    }
}

public struct GameStateSnapshot: Codable, Equatable, Sendable {
    public let defense: DefenseSnapshot
    public let park: ParkSnapshot
    public let runners: BaserunnerStateSnapshot
    public let runsAllowed: Int
    public let inningState: InningStateSnapshot?

    public init(
        defense: DefenseSnapshot,
        park: ParkSnapshot,
        runners: BaserunnerStateSnapshot,
        runsAllowed: Int,
        inningState: InningStateSnapshot? = nil
    ) {
        self.defense = defense
        self.park = park
        self.runners = runners
        self.runsAllowed = runsAllowed
        self.inningState = inningState
    }

    public static let standard = GameStateSnapshot(
        defense: DefenseSnapshot(infield: 50, outfield: 50, arm: 50),
        park: ParkSnapshot(
            id: "neutral-park",
            name: "중립 구장",
            hitFactor: 1_000,
            homeRunFactor: 1_000
        ),
        runners: .empty,
        runsAllowed: 0,
        inningState: nil
    )
}

public struct FieldingResolutionSnapshot: Codable, Equatable, Sendable {
    public let neutralOutcome: PitchOutcome
    public let finalOutcome: PitchOutcome
    public let sector: FieldingSector
    public let difficulty: Int
    public let defenseRating: Int
    public let defenseAdjustment: Int
    public let parkAdjustment: Int
    public let impact: DefenseImpact
    public let fielderPosition: FielderPosition?
    public let fielderName: String?
    public let landingDistanceTenthsMeters: Int?
    public let hangTimeMilliseconds: Int?
    public let apexHeightTenthsMeters: Int?
    /// Flat 3D series in groups of [timeMs, lateralTenthsCM, forwardTenthsCM, heightTenthsCM].
    public let ballFlightSeries: [Int]?
    public let shortExplanation: String

    public init(
        neutralOutcome: PitchOutcome,
        finalOutcome: PitchOutcome,
        sector: FieldingSector,
        difficulty: Int,
        defenseRating: Int,
        defenseAdjustment: Int,
        parkAdjustment: Int,
        impact: DefenseImpact,
        fielderPosition: FielderPosition? = nil,
        fielderName: String? = nil,
        landingDistanceTenthsMeters: Int? = nil,
        hangTimeMilliseconds: Int? = nil,
        apexHeightTenthsMeters: Int? = nil,
        ballFlightSeries: [Int]? = nil,
        shortExplanation: String
    ) {
        self.neutralOutcome = neutralOutcome
        self.finalOutcome = finalOutcome
        self.sector = sector
        self.difficulty = difficulty
        self.defenseRating = defenseRating
        self.defenseAdjustment = defenseAdjustment
        self.parkAdjustment = parkAdjustment
        self.impact = impact
        self.fielderPosition = fielderPosition
        self.fielderName = fielderName
        self.landingDistanceTenthsMeters = landingDistanceTenthsMeters
        self.hangTimeMilliseconds = hangTimeMilliseconds
        self.apexHeightTenthsMeters = apexHeightTenthsMeters
        self.ballFlightSeries = ballFlightSeries
        self.shortExplanation = shortExplanation
    }
}

public struct StealAttemptSnapshot: Codable, Equatable, Sendable {
    public let fromBase: Int
    public let toBase: Int
    public let runnerSpeed: Int
    public let catcherArm: Int
    public let succeeded: Bool
    public let shortExplanation: String

    public init(
        fromBase: Int,
        toBase: Int,
        runnerSpeed: Int,
        catcherArm: Int,
        succeeded: Bool,
        shortExplanation: String
    ) {
        self.fromBase = fromBase
        self.toBase = toBase
        self.runnerSpeed = runnerSpeed
        self.catcherArm = catcherArm
        self.succeeded = succeeded
        self.shortExplanation = shortExplanation
    }
}

public struct InningTransitionSnapshot: Codable, Equatable, Sendable {
    public let before: InningStateSnapshot
    public let after: InningStateSnapshot
    public let outsRecorded: Int
    public let doublePlayCompleted: Bool
    public let inningEnded: Bool
    public let shortExplanation: String

    public init(
        before: InningStateSnapshot,
        after: InningStateSnapshot,
        outsRecorded: Int,
        doublePlayCompleted: Bool,
        inningEnded: Bool,
        shortExplanation: String
    ) {
        self.before = before
        self.after = after
        self.outsRecorded = outsRecorded
        self.doublePlayCompleted = doublePlayCompleted
        self.inningEnded = inningEnded
        self.shortExplanation = shortExplanation
    }
}

public struct BaserunnerAdvanceSnapshot: Codable, Equatable, Sendable {
    public let before: BaserunnerStateSnapshot
    public let after: BaserunnerStateSnapshot
    public let runsScored: Int
    public let shortExplanation: String

    public init(
        before: BaserunnerStateSnapshot,
        after: BaserunnerStateSnapshot,
        runsScored: Int,
        shortExplanation: String
    ) {
        self.before = before
        self.after = after
        self.runsScored = runsScored
        self.shortExplanation = shortExplanation
    }
}

public struct PitchAnalysisEntry: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let wasInZone: Bool
    public let batterSwung: Bool
    public let outcome: PitchOutcome
    public let selectionQuality: SelectionQuality
    public let executionQuality: Int
    public let contactQuality: Int?
    public let expectedDamage: Int
    public let actualDamage: Int
    public let recommendationAccepted: Bool

    public init(
        pitchType: PitchType,
        wasInZone: Bool,
        batterSwung: Bool,
        outcome: PitchOutcome,
        selectionQuality: SelectionQuality,
        executionQuality: Int,
        contactQuality: Int?,
        expectedDamage: Int,
        actualDamage: Int,
        recommendationAccepted: Bool
    ) {
        self.pitchType = pitchType
        self.wasInZone = wasInZone
        self.batterSwung = batterSwung
        self.outcome = outcome
        self.selectionQuality = selectionQuality
        self.executionQuality = executionQuality
        self.contactQuality = contactQuality
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
        self.recommendationAccepted = recommendationAccepted
    }
}

public struct GameLogSnapshot: Codable, Equatable, Sendable {
    public let gameID: String
    public let revision: UInt64
    public let totalPitches: Int
    public let entries: [PitchAnalysisEntry]

    public init(
        gameID: String,
        revision: UInt64,
        totalPitches: Int,
        entries: [PitchAnalysisEntry]
    ) {
        self.gameID = gameID
        self.revision = revision
        self.totalPitches = totalPitches
        self.entries = entries
    }
}

public struct PitchAnalysisBreakdown: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let pitches: Int
    public let zoneRate: Int
    public let whiffRate: Int
    public let hardHitRate: Int
    public let expectedDamage: Int

    public init(
        pitchType: PitchType,
        pitches: Int,
        zoneRate: Int,
        whiffRate: Int,
        hardHitRate: Int,
        expectedDamage: Int
    ) {
        self.pitchType = pitchType
        self.pitches = pitches
        self.zoneRate = zoneRate
        self.whiffRate = whiffRate
        self.hardHitRate = hardHitRate
        self.expectedDamage = expectedDamage
    }
}

public struct PostgameAnalysisSnapshot: Codable, Equatable, Sendable {
    public let sampleSize: Int
    public let confidence: AnalysisConfidenceBand
    public let zoneRate: Int
    public let whiffRate: Int
    public let hardHitRate: Int
    public let averageSelectionQuality: Int
    public let averageExecutionQuality: Int
    public let expectedDamage: Int
    public let actualDamage: Int
    public let pitchBreakdowns: [PitchAnalysisBreakdown]
    public let patternWarning: String
    public let growthSignal: String

    public init(
        sampleSize: Int,
        confidence: AnalysisConfidenceBand,
        zoneRate: Int,
        whiffRate: Int,
        hardHitRate: Int,
        averageSelectionQuality: Int,
        averageExecutionQuality: Int,
        expectedDamage: Int,
        actualDamage: Int,
        pitchBreakdowns: [PitchAnalysisBreakdown],
        patternWarning: String,
        growthSignal: String
    ) {
        self.sampleSize = sampleSize
        self.confidence = confidence
        self.zoneRate = zoneRate
        self.whiffRate = whiffRate
        self.hardHitRate = hardHitRate
        self.averageSelectionQuality = averageSelectionQuality
        self.averageExecutionQuality = averageExecutionQuality
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
        self.pitchBreakdowns = pitchBreakdowns
        self.patternWarning = patternWarning
        self.growthSignal = growthSignal
    }
}

public struct BallInPlayEngine: Sendable {
    public init() {}

    public func resolve(
        _ battedBall: BattedBall,
        gameState: GameStateSnapshot,
        seed: UInt64,
        ordinal: Int
    ) -> FieldingResolutionSnapshot {
        let neutralOutcome = outcome(for: battedBall.contactQuality)
        let sector: FieldingSector
        if battedBall.launchAngleTenthsDegrees < 90 {
            sector = .infield
        } else if neutralOutcome == .homeRun
            || (battedBall.contactQuality >= 700
                && (150...350).contains(battedBall.launchAngleTenthsDegrees)) {
            sector = .fence
        } else {
            sector = .outfield
        }
        let fielderPosition = position(
            for: sector,
            direction: battedBall.directionTenthsDegrees
        )
        let fielder = gameState.defense.fielder(at: fielderPosition)
        let aggregateRating = sector == .infield
            ? gameState.defense.infield
            : gameState.defense.outfield
        let defenseRating = fielder.map { ($0.range * 6 + $0.glove * 4) / 10 }
            ?? aggregateRating
        let defenseScale = sector == .fence ? 1 : 4
        let defenseAdjustment = -(defenseRating - 50) * defenseScale
        let hitAdjustment = (gameState.park.hitFactor - 1_000) / 3
        let homeRunAdjustment = neutralOutcome == .homeRun || battedBall.contactQuality >= 720
            ? (gameState.park.homeRunFactor - 1_000) / 2
            : 0
        let parkAdjustment = hitAdjustment + homeRunAdjustment
        var generator = SplitMix64(
            seed: seed ^ 0x4649_454c_44 ^ (UInt64(ordinal) &* 0x9E37_79B9)
        )
        let randomRange = sector == .fence ? 81 : 241
        let randomAdjustment = generator.nextInt(upperBound: randomRange) - randomRange / 2
        let adjustedQuality = clamp(
            battedBall.contactQuality + defenseAdjustment + parkAdjustment + randomAdjustment,
            0,
            1_000
        )
        let rawFinalOutcome = outcome(for: adjustedQuality)
        let finalOutcome: PitchOutcome
        switch (sector, rawFinalOutcome) {
        case (.infield, .double), (.infield, .homeRun): finalOutcome = .single
        case (.outfield, .homeRun): finalOutcome = .double
        default: finalOutcome = rawFinalOutcome
        }
        let impact = impactFrom(neutral: neutralOutcome, final: finalOutcome)
        let explanation: String
        switch impact {
        case .helpedPitcher:
            explanation = fielder.map {
                "\($0.name)의 수비 범위와 첫발이 안타성 타구의 결과를 낮췄습니다."
            } ?? "수비 위치와 첫발이 안타성 타구의 결과를 낮췄습니다."
        case .hurtPitcher:
            explanation = parkAdjustment >= 60
                ? "구장 환경이 타구를 더 위험한 결과로 키웠습니다."
                : fielder.map {
                    "\($0.name)의 수비 범위를 벗어난 타구가 더 큰 결과로 이어졌습니다."
                } ?? "수비 범위를 벗어난 타구가 더 큰 결과로 이어졌습니다."
        case .neutral:
            explanation = abs(parkAdjustment) >= 60
                ? "구장 효과가 있었지만 최종 결과 단계는 바뀌지 않았습니다."
                : fielder.map {
                    "\($0.name) 앞 타구가 예상한 중립 결과로 이어졌습니다."
                } ?? "타구 질이 예상한 중립 결과로 이어졌습니다."
        }
        let flight = ballFlight(for: battedBall, sector: sector)
        return FieldingResolutionSnapshot(
            neutralOutcome: neutralOutcome,
            finalOutcome: finalOutcome,
            sector: sector,
            difficulty: clamp(1_000 - battedBall.contactQuality + abs(randomAdjustment), 0, 1_000),
            defenseRating: defenseRating,
            defenseAdjustment: defenseAdjustment,
            parkAdjustment: parkAdjustment,
            impact: impact,
            fielderPosition: fielderPosition,
            fielderName: fielder?.name,
            landingDistanceTenthsMeters: flight.distanceTenthsMeters,
            hangTimeMilliseconds: flight.hangTimeMilliseconds,
            apexHeightTenthsMeters: flight.apexHeightTenthsMeters,
            ballFlightSeries: flight.series,
            shortExplanation: explanation
        )
    }

    private func ballFlight(
        for battedBall: BattedBall,
        sector: FieldingSector
    ) -> (distanceTenthsMeters: Int, hangTimeMilliseconds: Int, apexHeightTenthsMeters: Int, series: [Int]) {
        let speedMetersPerSecond = Double(battedBall.exitVelocityTenthsKPH) / 36.0
        let launchDegrees = Double(battedBall.launchAngleTenthsDegrees) / 10.0
        let launchRadians = max(2.0, min(42.0, launchDegrees)) * .pi / 180.0
        let projectileCarry = speedMetersPerSecond * speedMetersPerSecond
            * sin(2.0 * launchRadians) / 9.81 * 0.68
        let groundCarry = 10.0 + speedMetersPerSecond * 0.48
            + Double(battedBall.contactQuality) / 85.0
        let rawDistance = launchDegrees < 9.0 ? groundCarry : projectileCarry
        let distanceMeters: Double
        switch sector {
        case .infield:
            distanceMeters = min(42.0, max(12.0, rawDistance))
        case .outfield:
            distanceMeters = min(104.0, max(48.0, rawDistance))
        case .fence:
            distanceMeters = min(140.0, max(105.0, rawDistance))
        }
        let rawHangTime = launchDegrees < 9.0
            ? 0.55 + distanceMeters / 48.0
            : 2.0 * speedMetersPerSecond * sin(launchRadians) / 9.81 * 0.82
        let hangTimeMilliseconds = Int((min(5.6, max(0.55, rawHangTime)) * 1_000.0).rounded())
        let rawApex = speedMetersPerSecond * speedMetersPerSecond
            * pow(sin(launchRadians), 2.0) / (2.0 * 9.81) * 0.72
        let apexMeters = launchDegrees < 9.0
            ? min(1.2, max(0.15, launchDegrees / 8.0))
            : min(32.0, max(1.5, rawApex))
        let directionRadians = Double(battedBall.directionTenthsDegrees) / 10.0 * .pi / 180.0
        let series = (0...20).flatMap { index -> [Int] in
            let progress = Double(index) / 20.0
            let travelledMeters = distanceMeters * progress
            let heightMeters = max(0.0, 4.0 * apexMeters * progress * (1.0 - progress))
            return [
                hangTimeMilliseconds * index / 20,
                Int((sin(directionRadians) * travelledMeters * 1_000.0).rounded()),
                Int((cos(directionRadians) * travelledMeters * 1_000.0).rounded()),
                Int((heightMeters * 1_000.0).rounded())
            ]
        }
        return (
            distanceTenthsMeters: Int((distanceMeters * 10.0).rounded()),
            hangTimeMilliseconds: hangTimeMilliseconds,
            apexHeightTenthsMeters: Int((apexMeters * 10.0).rounded()),
            series: series
        )
    }

    private func position(for sector: FieldingSector, direction: Int) -> FielderPosition {
        switch sector {
        case .infield:
            switch direction {
            case ..<(-180): return .thirdBase
            case -180..<0: return .shortstop
            case 0..<180: return .secondBase
            default: return .firstBase
            }
        case .outfield, .fence:
            switch direction {
            case ..<(-150): return .leftField
            case -150..<150: return .centerField
            default: return .rightField
            }
        }
    }

    private func outcome(for quality: Int) -> PitchOutcome {
        switch quality {
        case ..<500: return .inPlayOut
        case 500..<690: return .single
        case 690..<790: return .double
        default: return .homeRun
        }
    }

    private func impactFrom(neutral: PitchOutcome, final: PitchOutcome) -> DefenseImpact {
        let neutralValue = outcomeValue(neutral)
        let finalValue = outcomeValue(final)
        if finalValue < neutralValue { return .helpedPitcher }
        if finalValue > neutralValue { return .hurtPitcher }
        return .neutral
    }

    private func outcomeValue(_ outcome: PitchOutcome) -> Int {
        switch outcome {
        case .inPlayOut: return 0
        case .single: return 1
        case .double: return 2
        case .homeRun: return 3
        default: return 0
        }
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

public struct BaserunnerEngine: Sendable {
    public init() {}

    public func advance(
        _ runners: BaserunnerStateSnapshot,
        outcome: PitchOutcome,
        plateAppearanceResult: PlateAppearanceResult,
        defense: DefenseSnapshot,
        seed: UInt64,
        doublePlayCompleted: Bool = false
    ) -> BaserunnerAdvanceSnapshot {
        let after: BaserunnerStateSnapshot
        let runs: Int
        var generator = SplitMix64(seed: seed ^ 0x5255_4e4e_4552)
        switch plateAppearanceResult {
        case .strikeout:
            after = runners
            runs = 0
        case .inPlayOut:
            after = doublePlayCompleted
                ? BaserunnerStateSnapshot(
                    firstOccupied: false,
                    secondOccupied: runners.secondOccupied,
                    thirdOccupied: runners.thirdOccupied,
                    leadRunnerSpeed: runners.leadRunnerSpeed
                )
                : runners
            runs = 0
        case .walk:
            let forcedRun = runners.firstOccupied && runners.secondOccupied && runners.thirdOccupied
            after = BaserunnerStateSnapshot(
                firstOccupied: true,
                secondOccupied: runners.secondOccupied || runners.firstOccupied,
                thirdOccupied: runners.thirdOccupied || (runners.firstOccupied && runners.secondOccupied),
                leadRunnerSpeed: runners.leadRunnerSpeed
            )
            runs = forcedRun ? 1 : 0
        case .hit:
            switch outcome {
            case .single:
                let secondScores = runners.secondOccupied
                    && extraBaseSucceeds(
                        speed: runners.leadRunnerSpeed,
                        arm: defense.arm,
                        roll: generator.nextInt(upperBound: 1_000),
                        threshold: 500
                    )
                let firstTakesThird = runners.firstOccupied && !runners.secondOccupied
                    && extraBaseSucceeds(
                        speed: runners.leadRunnerSpeed,
                        arm: defense.arm,
                        roll: generator.nextInt(upperBound: 1_000),
                        threshold: 650
                    )
                let thirdOccupied = (runners.secondOccupied && !secondScores) || firstTakesThird
                after = BaserunnerStateSnapshot(
                    firstOccupied: true,
                    secondOccupied: runners.firstOccupied && !firstTakesThird,
                    thirdOccupied: thirdOccupied,
                    leadRunnerSpeed: 50
                )
                runs = (runners.thirdOccupied ? 1 : 0) + (secondScores ? 1 : 0)
            case .double:
                let firstScores = runners.firstOccupied
                    && extraBaseSucceeds(
                        speed: runners.leadRunnerSpeed,
                        arm: defense.arm,
                        roll: generator.nextInt(upperBound: 1_000),
                        threshold: 540
                    )
                after = BaserunnerStateSnapshot(
                    firstOccupied: false,
                    secondOccupied: true,
                    thirdOccupied: runners.firstOccupied && !firstScores,
                    leadRunnerSpeed: 50
                )
                runs = (runners.secondOccupied ? 1 : 0)
                    + (runners.thirdOccupied ? 1 : 0)
                    + (firstScores ? 1 : 0)
            case .homeRun:
                after = .empty
                runs = runners.occupiedCount + 1
            default:
                after = runners
                runs = 0
            }
        }
        let explanation: String
        if runs > 0 {
            explanation = "주자 진루로 \(runs)점을 허용했습니다."
        } else if after != runners {
            explanation = "타석 결과에 따라 주자 배치가 바뀌었습니다."
        } else {
            explanation = "주자 배치는 유지됐습니다."
        }
        return BaserunnerAdvanceSnapshot(
            before: runners,
            after: after,
            runsScored: runs,
            shortExplanation: explanation
        )
    }

    public func resolveSteal(
        _ runners: BaserunnerStateSnapshot,
        defense: DefenseSnapshot,
        context: PlateAppearanceContext,
        seed: UInt64
    ) -> (
        attempt: StealAttemptSnapshot?,
        runnersAfter: BaserunnerStateSnapshot,
        outsRecorded: Int
    ) {
        guard context.outs <= 1 else { return (nil, runners, 0) }
        let fromBase: Int
        let toBase: Int
        if runners.secondOccupied && !runners.thirdOccupied {
            fromBase = 2
            toBase = 3
        } else if runners.firstOccupied && !runners.secondOccupied {
            fromBase = 1
            toBase = 2
        } else {
            return (nil, runners, 0)
        }
        let catcherArm = defense.fielder(at: .catcher)?.arm ?? defense.arm
        var generator = SplitMix64(
            seed: seed ^ 0x5354_4541_4c ^ (UInt64(context.pitchNumber) &* 0x9E37_79B9)
        )
        let attemptChance = clamp(
            55 + (runners.leadRunnerSpeed - 50) * 3 + context.leverage / 20,
            20,
            260
        )
        guard generator.nextInt(upperBound: 1_000) < attemptChance else {
            return (nil, runners, 0)
        }
        let successChance = clamp(
            650 + (runners.leadRunnerSpeed - catcherArm) * 7,
            280,
            900
        )
        let succeeded = generator.nextInt(upperBound: 1_000) < successChance
        let after: BaserunnerStateSnapshot
        if fromBase == 1 {
            after = BaserunnerStateSnapshot(
                firstOccupied: false,
                secondOccupied: succeeded,
                thirdOccupied: runners.thirdOccupied,
                leadRunnerSpeed: runners.leadRunnerSpeed
            )
        } else {
            after = BaserunnerStateSnapshot(
                firstOccupied: runners.firstOccupied,
                secondOccupied: false,
                thirdOccupied: succeeded,
                leadRunnerSpeed: runners.leadRunnerSpeed
            )
        }
        let explanation = succeeded
            ? "\(fromBase)루 주자가 스타트를 끊어 \(toBase)루 도루에 성공했습니다."
            : "포수가 빠른 송구로 \(fromBase)루 주자의 도루를 저지했습니다."
        return (
            StealAttemptSnapshot(
                fromBase: fromBase,
                toBase: toBase,
                runnerSpeed: runners.leadRunnerSpeed,
                catcherArm: catcherArm,
                succeeded: succeeded,
                shortExplanation: explanation
            ),
            after,
            succeeded ? 0 : 1
        )
    }

    private func extraBaseSucceeds(speed: Int, arm: Int, roll: Int, threshold: Int) -> Bool {
        roll + (speed - arm) * 8 >= threshold
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

public struct InningStateEngine: Sendable {
    public init() {}

    public func resolve(
        context: PlateAppearanceContext,
        gameState: GameStateSnapshot,
        plateAppearanceResult: PlateAppearanceResult?,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        runners: BaserunnerStateSnapshot,
        stealOuts: Int,
        seed: UInt64
    ) -> InningTransitionSnapshot {
        let before = gameState.inningState ?? InningStateSnapshot(
            inning: context.inning,
            half: .bottom,
            outs: context.outs
        )
        let ordinaryOut = plateAppearanceResult == .strikeout
            || plateAppearanceResult == .inPlayOut
        var doublePlayCompleted = false
        if plateAppearanceResult == .inPlayOut,
           let battedBall,
           battedBall.launchAngleTenthsDegrees < 90,
           runners.firstOccupied,
           before.outs + stealOuts <= 1 {
            let pivot = pivotFielder(defense: gameState.defense, fielding: fielding)
            let doublePlayChance = clamp(
                470
                    + ((pivot?.glove ?? gameState.defense.infield) - 50) * 5
                    + ((pivot?.arm ?? gameState.defense.arm) - 50) * 3
                    - max(0, battedBall.contactQuality - 450) / 2,
                180,
                820
            )
            var generator = SplitMix64(seed: seed ^ 0x444f_5542_4c45)
            doublePlayCompleted = generator.nextInt(upperBound: 1_000) < doublePlayChance
        }
        let outsFromBall = ordinaryOut ? 1 + (doublePlayCompleted ? 1 : 0) : 0
        let outsRecorded = min(3 - before.outs, stealOuts + outsFromBall)
        let totalOuts = before.outs + outsRecorded
        let inningEnded = totalOuts >= 3
        let after: InningStateSnapshot
        if inningEnded {
            after = before.half == .top
                ? InningStateSnapshot(inning: before.inning, half: .bottom, outs: 0)
                : InningStateSnapshot(inning: before.inning + 1, half: .top, outs: 0)
        } else {
            after = InningStateSnapshot(
                inning: before.inning,
                half: before.half,
                outs: totalOuts
            )
        }
        let explanation: String
        if doublePlayCompleted && inningEnded {
            explanation = "땅볼 병살로 아웃 두 개를 잡아 공수를 전환했습니다."
        } else if doublePlayCompleted {
            explanation = "내야진이 땅볼을 병살로 연결해 아웃 두 개를 기록했습니다."
        } else if inningEnded {
            explanation = "세 번째 아웃을 잡아 공수가 전환됐습니다."
        } else if outsRecorded > 0 {
            explanation = "이번 플레이에서 \(outsRecorded)아웃을 기록했습니다."
        } else {
            explanation = "아웃카운트는 유지됐습니다."
        }
        return InningTransitionSnapshot(
            before: before,
            after: after,
            outsRecorded: outsRecorded,
            doublePlayCompleted: doublePlayCompleted,
            inningEnded: inningEnded,
            shortExplanation: explanation
        )
    }

    private func pivotFielder(
        defense: DefenseSnapshot,
        fielding: FieldingResolutionSnapshot?
    ) -> FielderSnapshot? {
        if let position = fielding?.fielderPosition,
           position == .shortstop || position == .secondBase,
           let fielder = defense.fielder(at: position) {
            return fielder
        }
        return [defense.fielder(at: .shortstop), defense.fielder(at: .secondBase)]
            .compactMap { $0 }
            .max { ($0.glove + $0.arm) < ($1.glove + $1.arm) }
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

public struct GameAnalysisEngine: Sendable {
    public static let maximumEntries = 120

    public init() {}

    public func validate(_ log: GameLogSnapshot?) throws {
        guard let log else { return }
        guard !log.gameID.isEmpty,
              log.totalPitches >= log.entries.count,
              log.entries.count <= Self.maximumEntries else {
            throw SimulationError.invalidGameLog("game log metadata is inconsistent")
        }
        for entry in log.entries {
            guard (0...1_000).contains(entry.executionQuality),
                  entry.contactQuality.map({ (0...1_000).contains($0) }) ?? true,
                  entry.expectedDamage >= 0,
                  entry.actualDamage >= 0 else {
                throw SimulationError.invalidGameLog("an analysis entry is outside the valid range")
            }
        }
    }

    public func record(
        _ log: GameLogSnapshot?,
        gameID: String,
        pitchType: PitchType,
        wasInZone: Bool,
        batterSwung: Bool,
        outcome: PitchOutcome,
        plateAppearanceResult: PlateAppearanceResult?,
        selectionQuality: SelectionQuality,
        executionQuality: Int,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        recommendationAccepted: Bool
    ) -> GameLogSnapshot {
        let current = log ?? GameLogSnapshot(
            gameID: gameID,
            revision: 0,
            totalPitches: 0,
            entries: []
        )
        let entry = PitchAnalysisEntry(
            pitchType: pitchType,
            wasInZone: wasInZone,
            batterSwung: batterSwung,
            outcome: outcome,
            selectionQuality: selectionQuality,
            executionQuality: executionQuality,
            contactQuality: battedBall?.contactQuality,
            expectedDamage: damageValue(fielding?.neutralOutcome ?? outcome, result: plateAppearanceResult),
            actualDamage: damageValue(outcome, result: plateAppearanceResult),
            recommendationAccepted: recommendationAccepted
        )
        return GameLogSnapshot(
            gameID: current.gameID,
            revision: current.revision + 1,
            totalPitches: current.totalPitches + 1,
            entries: Array((current.entries + [entry]).suffix(Self.maximumEntries))
        )
    }

    public func analyze(_ log: GameLogSnapshot) -> PostgameAnalysisSnapshot {
        let entries = log.entries
        let swings = entries.filter(\.batterSwung)
        let contacts = entries.filter { $0.contactQuality != nil }
        let pitchBreakdowns = PitchType.allCases.compactMap { pitchType -> PitchAnalysisBreakdown? in
            let matching = entries.filter { $0.pitchType == pitchType }
            guard !matching.isEmpty else { return nil }
            let matchingSwings = matching.filter(\.batterSwung)
            let matchingContacts = matching.filter { $0.contactQuality != nil }
            return PitchAnalysisBreakdown(
                pitchType: pitchType,
                pitches: matching.count,
                zoneRate: rate(matching.filter(\.wasInZone).count, matching.count),
                whiffRate: rate(
                    matching.filter { $0.outcome == .swingingStrike }.count,
                    matchingSwings.count
                ),
                hardHitRate: rate(
                    matchingContacts.filter { ($0.contactQuality ?? 0) >= 650 }.count,
                    matchingContacts.count
                ),
                expectedDamage: matching.reduce(0) { $0 + $1.expectedDamage }
            )
        }
        let topPitch = pitchBreakdowns.max { $0.pitches < $1.pitches }
        let patternWarning: String
        if entries.count < 6 {
            patternWarning = "아직 본 공이 적습니다. 6구부터 반복되는 승부를 짚어 줍니다."
        } else if let topPitch, topPitch.pitches * 100 >= entries.count * 55 {
            patternWarning = "\(pitchName(topPitch.pitchType)) 비중이 55%를 넘어 반복 노출을 점검해야 합니다."
        } else {
            patternWarning = "구종 사용이 한쪽으로 치우치지 않았습니다."
        }
        let averageExecution = average(entries.map(\.executionQuality))
        let hardHitRate = rate(
            contacts.filter { ($0.contactQuality ?? 0) >= 650 }.count,
            contacts.count
        )
        let averageSelection = average(entries.map { selectionScore($0.selectionQuality) })
        let growthSignal: String
        if averageExecution < 600 {
            growthSignal = "우선 훈련 후보: 같은 릴리스 반복과 코스 실행"
        } else if hardHitRate >= 300 {
            growthSignal = "우선 훈련 후보: 약한 타구 유도와 변화구 완성도"
        } else if averageSelection < 650 {
            growthSignal = "우선 훈련 후보: 카운트별 구종 설계"
        } else {
            growthSignal = "다음 훈련: 현재 구종 선택과 코스 재현을 유지"
        }
        let confidence: AnalysisConfidenceBand
        switch entries.count {
        case ..<8: confidence = .low
        case 8..<20: confidence = .developing
        default: confidence = .reliable
        }
        return PostgameAnalysisSnapshot(
            sampleSize: entries.count,
            confidence: confidence,
            zoneRate: rate(entries.filter(\.wasInZone).count, entries.count),
            whiffRate: rate(entries.filter { $0.outcome == .swingingStrike }.count, swings.count),
            hardHitRate: hardHitRate,
            averageSelectionQuality: averageSelection,
            averageExecutionQuality: averageExecution,
            expectedDamage: entries.reduce(0) { $0 + $1.expectedDamage },
            actualDamage: entries.reduce(0) { $0 + $1.actualDamage },
            pitchBreakdowns: pitchBreakdowns,
            patternWarning: patternWarning,
            growthSignal: growthSignal
        )
    }

    private func damageValue(_ outcome: PitchOutcome, result: PlateAppearanceResult?) -> Int {
        if result == .walk { return 330 }
        switch outcome {
        case .single: return 470
        case .double: return 780
        case .homeRun: return 1_400
        default: return 0
        }
    }

    private func selectionScore(_ quality: SelectionQuality) -> Int {
        switch quality {
        case .poor: return 250
        case .risky: return 450
        case .good: return 700
        case .excellent: return 900
        }
    }

    private func rate(_ numerator: Int, _ denominator: Int) -> Int {
        denominator == 0 ? 0 : numerator * 1_000 / denominator
    }

    private func average(_ values: [Int]) -> Int {
        values.isEmpty ? 0 : values.reduce(0, +) / values.count
    }

    private func pitchName(_ pitchType: PitchType) -> String {
        switch pitchType {
        case .fourSeam: return "포심"
        case .slider: return "슬라이더"
        case .curveball: return "커브"
        case .changeup: return "체인지업"
        }
    }
}
