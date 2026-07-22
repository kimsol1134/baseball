import Foundation

public enum ZoneIntent: String, Codable, CaseIterable, Sendable {
    case strike
    case edge
    case chase
}

public struct PitchCall: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let zone: PitchZone
    public let zoneIntent: ZoneIntent
    public let intensity: PitchIntensity

    public init(
        pitchType: PitchType,
        zone: PitchZone,
        zoneIntent: ZoneIntent,
        intensity: PitchIntensity
    ) {
        self.pitchType = pitchType
        self.zone = zone
        self.zoneIntent = zoneIntent
        self.intensity = intensity
    }
}

public struct BatterScoutingSnapshot: Codable, Equatable, Sendable {
    public let hotZone: PitchZone
    public let coldZone: PitchZone
    public let pitchStrength: PitchType
    public let pitchWeakness: PitchType
    public let chaseTendency: Int

    public init(
        hotZone: PitchZone,
        coldZone: PitchZone,
        pitchStrength: PitchType,
        pitchWeakness: PitchType,
        chaseTendency: Int
    ) {
        self.hotZone = hotZone
        self.coldZone = coldZone
        self.pitchStrength = pitchStrength
        self.pitchWeakness = pitchWeakness
        self.chaseTendency = chaseTendency
    }
}

public struct PlateAppearanceContext: Codable, Equatable, Sendable {
    public let plateAppearanceID: String
    public let revision: UInt64
    public let inning: Int
    public let outs: Int
    public let balls: Int
    public let strikes: Int
    public let pitchNumber: Int
    public let scoreDifferential: Int
    public let leverage: Int
    public let fatigue: Int

    public init(
        plateAppearanceID: String,
        revision: UInt64,
        inning: Int,
        outs: Int,
        balls: Int,
        strikes: Int,
        pitchNumber: Int,
        scoreDifferential: Int,
        leverage: Int,
        fatigue: Int
    ) {
        self.plateAppearanceID = plateAppearanceID
        self.revision = revision
        self.inning = inning
        self.outs = outs
        self.balls = balls
        self.strikes = strikes
        self.pitchNumber = pitchNumber
        self.scoreDifferential = scoreDifferential
        self.leverage = leverage
        self.fatigue = fatigue
    }
}

public struct PreparePitchParams: Codable, Equatable, Sendable {
    public let seed: String
    public let pitcher: PitcherSnapshot
    public let batter: BatterSnapshot
    public let scouting: BatterScoutingSnapshot
    public let context: PlateAppearanceContext
    public let rivalMemory: RivalMemorySnapshot?
    public let gameState: GameStateSnapshot?
    public let gameLog: GameLogSnapshot?

    public init(
        seed: String,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext
    ) {
        self.init(
            seed: seed,
            pitcher: pitcher,
            batter: batter,
            scouting: scouting,
            context: context,
            rivalMemory: nil,
            gameState: nil,
            gameLog: nil
        )
    }

    public init(
        seed: String,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        rivalMemory: RivalMemorySnapshot?,
        gameState: GameStateSnapshot? = nil,
        gameLog: GameLogSnapshot? = nil
    ) {
        self.seed = seed
        self.pitcher = pitcher
        self.batter = batter
        self.scouting = scouting
        self.context = context
        self.rivalMemory = rivalMemory
        self.gameState = gameState
        self.gameLog = gameLog
    }
}

public struct SubmitPitchParams: Codable, Equatable, Sendable {
    public let seed: String
    public let pitcher: PitcherSnapshot
    public let batter: BatterSnapshot
    public let scouting: BatterScoutingSnapshot
    public let context: PlateAppearanceContext
    public let preparationToken: String
    public let call: PitchCall
    public let rivalMemory: RivalMemorySnapshot?
    public let gameState: GameStateSnapshot?
    public let gameLog: GameLogSnapshot?

    public init(
        seed: String,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        preparationToken: String,
        call: PitchCall
    ) {
        self.init(
            seed: seed,
            pitcher: pitcher,
            batter: batter,
            scouting: scouting,
            context: context,
            preparationToken: preparationToken,
            call: call,
            rivalMemory: nil,
            gameState: nil,
            gameLog: nil
        )
    }

    public init(
        seed: String,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        preparationToken: String,
        call: PitchCall,
        rivalMemory: RivalMemorySnapshot?,
        gameState: GameStateSnapshot? = nil,
        gameLog: GameLogSnapshot? = nil
    ) {
        self.seed = seed
        self.pitcher = pitcher
        self.batter = batter
        self.scouting = scouting
        self.context = context
        self.preparationToken = preparationToken
        self.call = call
        self.rivalMemory = rivalMemory
        self.gameState = gameState
        self.gameLog = gameLog
    }
}

public struct CatcherRecommendation: Codable, Equatable, Sendable {
    public let call: PitchCall
    public let confidence: Int
    public let reasonCodes: [String]

    public init(call: PitchCall, confidence: Int, reasonCodes: [String]) {
        self.call = call
        self.confidence = confidence
        self.reasonCodes = reasonCodes
    }
}

public struct CatcherRecommendationSnapshot: Codable, Equatable, Sendable {
    public let call: PitchCall
    public let confidence: Int
    public let reasonCodes: [String]
    public let shortReason: String

    public init(
        call: PitchCall,
        confidence: Int,
        reasonCodes: [String],
        shortReason: String
    ) {
        self.call = call
        self.confidence = confidence
        self.reasonCodes = reasonCodes
        self.shortReason = shortReason
    }
}

public struct PitchPreparation: Codable, Equatable, Sendable {
    public let seed: String
    public let revision: UInt64
    public let pitchNumber: Int
    public let preparationToken: String
    public let planCommitment: String
    public let primaryRecommendation: CatcherRecommendationSnapshot
    public let alternativeRecommendation: CatcherRecommendationSnapshot
    public let rivalAdaptation: RivalAdaptationSnapshot

    public init(
        seed: String,
        revision: UInt64,
        pitchNumber: Int,
        preparationToken: String,
        planCommitment: String,
        primaryRecommendation: CatcherRecommendationSnapshot,
        alternativeRecommendation: CatcherRecommendationSnapshot,
        rivalAdaptation: RivalAdaptationSnapshot
    ) {
        self.seed = seed
        self.revision = revision
        self.pitchNumber = pitchNumber
        self.preparationToken = preparationToken
        self.planCommitment = planCommitment
        self.primaryRecommendation = primaryRecommendation
        self.alternativeRecommendation = alternativeRecommendation
        self.rivalAdaptation = rivalAdaptation
    }
}

public enum SelectionQuality: String, Codable, Sendable {
    case poor
    case risky
    case good
    case excellent
}

public enum PlateAppearanceResult: String, Codable, Sendable {
    case strikeout
    case walk
    case inPlayOut = "in_play_out"
    case hit
}

public struct PitchExecution: Codable, Equatable, Sendable {
    public let targetX: Int
    public let targetY: Int
    public let actualX: Int
    public let actualY: Int
    public let velocityTenthsKPH: Int
    public let horizontalBreakTenthsCM: Int
    public let verticalBreakTenthsCM: Int
    public let executionQuality: Int
    public let flightTimeMilliseconds: Int?
    public let trajectoryControlX: Int?
    public let trajectoryControlY: Int?
    /// Flat 3D series in groups of [timeMs, lateralTenthsCM, forwardTenthsCM, heightTenthsCM].
    public let trajectorySeries: [Int]?

    public init(
        targetX: Int,
        targetY: Int,
        actualX: Int,
        actualY: Int,
        velocityTenthsKPH: Int,
        horizontalBreakTenthsCM: Int,
        verticalBreakTenthsCM: Int,
        executionQuality: Int,
        flightTimeMilliseconds: Int? = nil,
        trajectoryControlX: Int? = nil,
        trajectoryControlY: Int? = nil,
        trajectorySeries: [Int]? = nil
    ) {
        self.targetX = targetX
        self.targetY = targetY
        self.actualX = actualX
        self.actualY = actualY
        self.velocityTenthsKPH = velocityTenthsKPH
        self.horizontalBreakTenthsCM = horizontalBreakTenthsCM
        self.verticalBreakTenthsCM = verticalBreakTenthsCM
        self.executionQuality = executionQuality
        self.flightTimeMilliseconds = flightTimeMilliseconds
        self.trajectoryControlX = trajectoryControlX
        self.trajectoryControlY = trajectoryControlY
        self.trajectorySeries = trajectorySeries
    }
}

public struct BattedBall: Codable, Equatable, Sendable {
    public let exitVelocityTenthsKPH: Int
    public let launchAngleTenthsDegrees: Int
    public let directionTenthsDegrees: Int
    public let contactQuality: Int

    public init(
        exitVelocityTenthsKPH: Int,
        launchAngleTenthsDegrees: Int,
        directionTenthsDegrees: Int,
        contactQuality: Int
    ) {
        self.exitVelocityTenthsKPH = exitVelocityTenthsKPH
        self.launchAngleTenthsDegrees = launchAngleTenthsDegrees
        self.directionTenthsDegrees = directionTenthsDegrees
        self.contactQuality = contactQuality
    }
}

public struct PitchKernelEvent: Codable, Equatable, Sendable {
    public let eventType: String
    public let sequence: Int
    public let planCommitment: String?
    public let primaryRecommendation: CatcherRecommendation?
    public let alternativeRecommendation: CatcherRecommendation?
    public let call: PitchCall?
    public let execution: PitchExecution?
    public let outcome: PitchOutcome?
    public let battedBall: BattedBall?
    public let fieldingResolution: FieldingResolutionSnapshot?
    public let baserunnerAdvance: BaserunnerAdvanceSnapshot?
    public let stealAttempt: StealAttemptSnapshot?
    public let inningTransition: InningTransitionSnapshot?
    public let plateAppearanceResult: PlateAppearanceResult?
    public let rivalAdaptation: RivalAdaptationSnapshot?
    public let postgameAnalysis: PostgameAnalysisSnapshot?
    public let reasonCodes: [String]

    public init(
        eventType: String,
        sequence: Int,
        planCommitment: String? = nil,
        primaryRecommendation: CatcherRecommendation? = nil,
        alternativeRecommendation: CatcherRecommendation? = nil,
        call: PitchCall? = nil,
        execution: PitchExecution? = nil,
        outcome: PitchOutcome? = nil,
        battedBall: BattedBall? = nil,
        fieldingResolution: FieldingResolutionSnapshot? = nil,
        baserunnerAdvance: BaserunnerAdvanceSnapshot? = nil,
        stealAttempt: StealAttemptSnapshot? = nil,
        inningTransition: InningTransitionSnapshot? = nil,
        plateAppearanceResult: PlateAppearanceResult? = nil,
        rivalAdaptation: RivalAdaptationSnapshot? = nil,
        postgameAnalysis: PostgameAnalysisSnapshot? = nil,
        reasonCodes: [String] = []
    ) {
        self.eventType = eventType
        self.sequence = sequence
        self.planCommitment = planCommitment
        self.primaryRecommendation = primaryRecommendation
        self.alternativeRecommendation = alternativeRecommendation
        self.call = call
        self.execution = execution
        self.outcome = outcome
        self.battedBall = battedBall
        self.fieldingResolution = fieldingResolution
        self.baserunnerAdvance = baserunnerAdvance
        self.stealAttempt = stealAttempt
        self.inningTransition = inningTransition
        self.plateAppearanceResult = plateAppearanceResult
        self.rivalAdaptation = rivalAdaptation
        self.postgameAnalysis = postgameAnalysis
        self.reasonCodes = reasonCodes
    }
}

public struct PlateAppearanceSnapshot: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let balls: Int
    public let strikes: Int
    public let pitchNumber: Int
    public let ended: Bool
    public let result: PlateAppearanceResult?
    public let outcome: PitchOutcome
    public let selectionQuality: SelectionQuality
    public let recommendationAccepted: Bool
    public let fatigueAfterPitch: Int
    public let execution: PitchExecution
    public let battedBall: BattedBall?
    public let fieldingResolution: FieldingResolutionSnapshot?
    public let runnersBefore: BaserunnerStateSnapshot?
    public let runnersAfter: BaserunnerStateSnapshot
    public let runsScored: Int
    public let stealAttempt: StealAttemptSnapshot?
    public let inningTransition: InningTransitionSnapshot?
    public let reasonCodes: [String]
    public let shortFeedback: String
    public let detailFeedback: String
    public let accessibilitySummary: String

    public init(
        revision: UInt64,
        balls: Int,
        strikes: Int,
        pitchNumber: Int,
        ended: Bool,
        result: PlateAppearanceResult?,
        outcome: PitchOutcome,
        selectionQuality: SelectionQuality,
        recommendationAccepted: Bool,
        fatigueAfterPitch: Int,
        execution: PitchExecution,
        battedBall: BattedBall?,
        fieldingResolution: FieldingResolutionSnapshot? = nil,
        runnersBefore: BaserunnerStateSnapshot? = nil,
        runnersAfter: BaserunnerStateSnapshot = .empty,
        runsScored: Int = 0,
        stealAttempt: StealAttemptSnapshot? = nil,
        inningTransition: InningTransitionSnapshot? = nil,
        reasonCodes: [String],
        shortFeedback: String,
        detailFeedback: String,
        accessibilitySummary: String
    ) {
        self.revision = revision
        self.balls = balls
        self.strikes = strikes
        self.pitchNumber = pitchNumber
        self.ended = ended
        self.result = result
        self.outcome = outcome
        self.selectionQuality = selectionQuality
        self.recommendationAccepted = recommendationAccepted
        self.fatigueAfterPitch = fatigueAfterPitch
        self.execution = execution
        self.battedBall = battedBall
        self.fieldingResolution = fieldingResolution
        self.runnersBefore = runnersBefore
        self.runnersAfter = runnersAfter
        self.runsScored = runsScored
        self.stealAttempt = stealAttempt
        self.inningTransition = inningTransition
        self.reasonCodes = reasonCodes
        self.shortFeedback = shortFeedback
        self.detailFeedback = detailFeedback
        self.accessibilitySummary = accessibilitySummary
    }
}

public struct PitchKernelResult: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let nextSeed: String
    public let events: [PitchKernelEvent]
    public let snapshot: PlateAppearanceSnapshot
    public let nextPreparation: PitchPreparation?
    public let rivalMemory: RivalMemorySnapshot
    public let rivalAdaptation: RivalAdaptationSnapshot
    public let gameState: GameStateSnapshot
    public let gameLog: GameLogSnapshot
    public let postgameAnalysis: PostgameAnalysisSnapshot
    public let eventHash: String

    public init(
        revision: UInt64,
        nextSeed: String,
        events: [PitchKernelEvent],
        snapshot: PlateAppearanceSnapshot,
        nextPreparation: PitchPreparation?,
        rivalMemory: RivalMemorySnapshot,
        rivalAdaptation: RivalAdaptationSnapshot,
        gameState: GameStateSnapshot,
        gameLog: GameLogSnapshot,
        postgameAnalysis: PostgameAnalysisSnapshot,
        eventHash: String
    ) {
        self.revision = revision
        self.nextSeed = nextSeed
        self.events = events
        self.snapshot = snapshot
        self.nextPreparation = nextPreparation
        self.rivalMemory = rivalMemory
        self.rivalAdaptation = rivalAdaptation
        self.gameState = gameState
        self.gameLog = gameLog
        self.postgameAnalysis = postgameAnalysis
        self.eventHash = eventHash
    }
}
