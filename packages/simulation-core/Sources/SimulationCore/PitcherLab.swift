import Foundation

public enum TrainingFocus: String, Codable, CaseIterable, Sendable {
    case velocity
    case command
    case breakingBall = "breaking_ball"
    case stamina
    case recovery
    case gamePlanning = "game_planning"
}

public enum TrainingIntensity: String, Codable, CaseIterable, Sendable {
    case light
    case standard
    case intensive
}

public enum TrainingReactionBand: String, Codable, Sendable {
    case muted
    case steady
    case strong
    case breakthrough
}

public enum PitcherLabPhase: String, Codable, Sendable {
    case training
    case importantInning = "important_inning"
    case relationship
    case awakening
    case scouting
    case reflection
    case completed
}

public enum RelationshipChoice: String, Codable, CaseIterable, Sendable {
    case trustCatcher = "trust_catcher"
    case assertOwnPlan = "assert_own_plan"
}

public enum AwakeningID: String, Codable, CaseIterable, Sendable {
    case explosiveFastball = "explosive_fastball"
    case pinpointEdge = "pinpoint_edge"
    case disappearingBreaker = "disappearing_breaker"
    case ironArm = "iron_arm"
    case calmUnderPressure = "calm_under_pressure"
    case batterySync = "battery_sync"
    case risingFourSeam = "rising_four_seam"
    case sinkerTunnel = "sinker_tunnel"
    case frozenChangeup = "frozen_changeup"
    case sweepingSlider = "sweeping_slider"
    case curveballClock = "curveball_clock"
    case repeatableRelease = "repeatable_release"
    case pickoffRhythm = "pickoff_rhythm"
    case twoStrikePlan = "two_strike_plan"
    case firstPitchStrike = "first_pitch_strike"
    case trafficController = "traffic_controller"
    case lateInningReserve = "late_inning_reserve"
    case scoutComposure = "scout_composure"
}

public enum SoulDomain: String, Codable, CaseIterable, Sendable {
    case body
    case technique
    case game
}

public enum MemoryCardID: String, Codable, CaseIterable, Sendable {
    case velocityBlueprint = "velocity_blueprint"
    case fingertipMemory = "fingertip_memory"
    case catcherNotebook = "catcher_notebook"
    case rivalNotebook = "rival_notebook"
    case recoveryRoutine = "recovery_routine"
    case pressureRehearsal = "pressure_rehearsal"
    case firstPitchMap = "first_pitch_map"
    case twoStrikeSequence = "two_strike_sequence"
    case fatigueDiary = "fatigue_diary"
    case mechanicsVideo = "mechanics_video"
    case schoolPlaybook = "school_playbook"
    case coachLetter = "coach_letter"
    case draftReport = "draft_report"
    case stadiumEcho = "stadium_echo"
    case teamFirstPromise = "team_first_promise"
    case failureScorebook = "failure_scorebook"
    case winterProgram = "winter_program"
    case bullpenCompass = "bullpen_compass"
}

public enum ScoutingGrade: String, Codable, Sendable {
    case undrafted
    case follow
    case draftable
    case elite
}

public struct PotentialRangeSnapshot: Codable, Equatable, Sendable {
    public let metric: String
    public let current: Int
    public let lowerBound: Int
    public let upperBound: Int
    public let confidence: Int

    public init(metric: String, current: Int, lowerBound: Int, upperBound: Int, confidence: Int) {
        self.metric = metric
        self.current = current
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.confidence = confidence
    }
}

public struct DevelopmentSignalsSnapshot: Codable, Equatable, Sendable {
    public let velocity: Int
    public let command: Int
    public let breakingBall: Int
    public let stamina: Int
    public let recovery: Int
    public let gamePlanning: Int

    public init(
        velocity: Int = 0,
        command: Int = 0,
        breakingBall: Int = 0,
        stamina: Int = 0,
        recovery: Int = 0,
        gamePlanning: Int = 0
    ) {
        self.velocity = velocity
        self.command = command
        self.breakingBall = breakingBall
        self.stamina = stamina
        self.recovery = recovery
        self.gamePlanning = gamePlanning
    }

    public func value(for focus: TrainingFocus) -> Int {
        switch focus {
        case .velocity: return velocity
        case .command: return command
        case .breakingBall: return breakingBall
        case .stamina: return stamina
        case .recovery: return recovery
        case .gamePlanning: return gamePlanning
        }
    }

    public func replacing(_ focus: TrainingFocus, with value: Int) -> DevelopmentSignalsSnapshot {
        DevelopmentSignalsSnapshot(
            velocity: focus == .velocity ? value : velocity,
            command: focus == .command ? value : command,
            breakingBall: focus == .breakingBall ? value : breakingBall,
            stamina: focus == .stamina ? value : stamina,
            recovery: focus == .recovery ? value : recovery,
            gamePlanning: focus == .gamePlanning ? value : gamePlanning
        )
    }
}

public struct TrainingSessionSnapshot: Codable, Equatable, Sendable {
    public let sessionNumber: Int
    public let focus: TrainingFocus
    public let intensity: TrainingIntensity
    public let reaction: TrainingReactionBand
    public let signalGained: Int
    public let ratingPointsGained: Int
    public let readinessBefore: Int
    public let readinessAfter: Int
    public let fatigueBefore: Int
    public let fatigueAfter: Int
    public let observedClue: String
    public let shortFeedback: String

    public init(
        sessionNumber: Int,
        focus: TrainingFocus,
        intensity: TrainingIntensity,
        reaction: TrainingReactionBand,
        signalGained: Int,
        ratingPointsGained: Int,
        readinessBefore: Int,
        readinessAfter: Int,
        fatigueBefore: Int,
        fatigueAfter: Int,
        observedClue: String,
        shortFeedback: String
    ) {
        self.sessionNumber = sessionNumber
        self.focus = focus
        self.intensity = intensity
        self.reaction = reaction
        self.signalGained = signalGained
        self.ratingPointsGained = ratingPointsGained
        self.readinessBefore = readinessBefore
        self.readinessAfter = readinessAfter
        self.fatigueBefore = fatigueBefore
        self.fatigueAfter = fatigueAfter
        self.observedClue = observedClue
        self.shortFeedback = shortFeedback
    }
}

public struct ImportantInningReport: Codable, Equatable, Sendable {
    public let scenarioNumber: Int
    public let pitches: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let expectedDamage: Int
    public let actualDamage: Int
    public let recommendationAccepted: Int

    public init(
        scenarioNumber: Int,
        pitches: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        expectedDamage: Int,
        actualDamage: Int,
        recommendationAccepted: Int
    ) {
        self.scenarioNumber = scenarioNumber
        self.pitches = pitches
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
        self.recommendationAccepted = recommendationAccepted
    }
}

public struct LabPerformanceSnapshot: Codable, Equatable, Sendable {
    public let importantInningsCompleted: Int
    public let pitches: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let expectedDamage: Int
    public let actualDamage: Int
    public let recommendationAccepted: Int

    public init(
        importantInningsCompleted: Int = 0,
        pitches: Int = 0,
        strikeouts: Int = 0,
        walks: Int = 0,
        runsAllowed: Int = 0,
        expectedDamage: Int = 0,
        actualDamage: Int = 0,
        recommendationAccepted: Int = 0
    ) {
        self.importantInningsCompleted = importantInningsCompleted
        self.pitches = pitches
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
        self.recommendationAccepted = recommendationAccepted
    }

    public func adding(_ report: ImportantInningReport) -> LabPerformanceSnapshot {
        LabPerformanceSnapshot(
            importantInningsCompleted: importantInningsCompleted + 1,
            pitches: pitches + report.pitches,
            strikeouts: strikeouts + report.strikeouts,
            walks: walks + report.walks,
            runsAllowed: runsAllowed + report.runsAllowed,
            expectedDamage: expectedDamage + report.expectedDamage,
            actualDamage: actualDamage + report.actualDamage,
            recommendationAccepted: recommendationAccepted + report.recommendationAccepted
        )
    }
}

public struct ScoutingEvaluationSnapshot: Codable, Equatable, Sendable {
    public let grade: ScoutingGrade
    public let score: Int
    public let strengths: [String]
    public let concerns: [String]
    public let summary: String

    public init(
        grade: ScoutingGrade,
        score: Int,
        strengths: [String],
        concerns: [String],
        summary: String
    ) {
        self.grade = grade
        self.score = score
        self.strengths = strengths
        self.concerns = concerns
        self.summary = summary
    }
}

public struct LegacySelectionSnapshot: Codable, Equatable, Sendable {
    public let soulDomain: SoulDomain
    public let memoryCard: MemoryCardID
    public let soulPointsGranted: Int
    public let unlockedSchoolID: String
    public let unlockedCoachID: String
    public let summary: String

    public init(
        soulDomain: SoulDomain,
        memoryCard: MemoryCardID,
        soulPointsGranted: Int,
        unlockedSchoolID: String,
        unlockedCoachID: String,
        summary: String
    ) {
        self.soulDomain = soulDomain
        self.memoryCard = memoryCard
        self.soulPointsGranted = soulPointsGranted
        self.unlockedSchoolID = unlockedSchoolID
        self.unlockedCoachID = unlockedCoachID
        self.summary = summary
    }
}

public struct PitcherLabSnapshot: Codable, Equatable, Sendable {
    public let runID: String
    public let revision: UInt64
    public let lifeNumber: Int
    public let presetID: String
    public let phase: PitcherLabPhase
    public let pitcher: PitcherSnapshot
    public let trainingSessionsCompleted: Int
    public let relationshipEventsCompleted: Int
    public let selectedAwakenings: [AwakeningID]
    public let awakeningOptions: [AwakeningID]
    public let readiness: Int
    public let fatigue: Int
    public let catcherTrust: Int
    public let developmentSignals: DevelopmentSignalsSnapshot
    public let potentialRanges: [PotentialRangeSnapshot]
    public let performance: LabPerformanceSnapshot
    public let lastTraining: TrainingSessionSnapshot?
    public let scoutingEvaluation: ScoutingEvaluationSnapshot?
    public let legacyOptions: [MemoryCardID]
    public let legacySelection: LegacySelectionSnapshot?
    public let stateCommitment: String

    public init(
        runID: String,
        revision: UInt64,
        lifeNumber: Int,
        presetID: String,
        phase: PitcherLabPhase,
        pitcher: PitcherSnapshot,
        trainingSessionsCompleted: Int,
        relationshipEventsCompleted: Int,
        selectedAwakenings: [AwakeningID],
        awakeningOptions: [AwakeningID],
        readiness: Int,
        fatigue: Int,
        catcherTrust: Int,
        developmentSignals: DevelopmentSignalsSnapshot,
        potentialRanges: [PotentialRangeSnapshot],
        performance: LabPerformanceSnapshot,
        lastTraining: TrainingSessionSnapshot?,
        scoutingEvaluation: ScoutingEvaluationSnapshot?,
        legacyOptions: [MemoryCardID],
        legacySelection: LegacySelectionSnapshot?,
        stateCommitment: String
    ) {
        self.runID = runID
        self.revision = revision
        self.lifeNumber = lifeNumber
        self.presetID = presetID
        self.phase = phase
        self.pitcher = pitcher
        self.trainingSessionsCompleted = trainingSessionsCompleted
        self.relationshipEventsCompleted = relationshipEventsCompleted
        self.selectedAwakenings = selectedAwakenings
        self.awakeningOptions = awakeningOptions
        self.readiness = readiness
        self.fatigue = fatigue
        self.catcherTrust = catcherTrust
        self.developmentSignals = developmentSignals
        self.potentialRanges = potentialRanges
        self.performance = performance
        self.lastTraining = lastTraining
        self.scoutingEvaluation = scoutingEvaluation
        self.legacyOptions = legacyOptions
        self.legacySelection = legacySelection
        self.stateCommitment = stateCommitment
    }
}

public struct StartPitcherLabParams: Codable, Equatable, Sendable {
    public let seed: String
    public let presetID: String
    public let playerName: String?
    public let lifeNumber: Int
    public let inheritedSoulPoints: Int
    public let inheritedSoulDomain: SoulDomain?
    public let inheritedMemory: MemoryCardID?
    public let creationAllocation: CreationAllocationSnapshot?

    public init(
        seed: String,
        presetID: String,
        lifeNumber: Int = 1,
        inheritedSoulPoints: Int = 0,
        inheritedSoulDomain: SoulDomain? = nil,
        inheritedMemory: MemoryCardID? = nil,
        creationAllocation: CreationAllocationSnapshot? = nil
    ) {
        self.seed = seed
        self.presetID = presetID
        self.playerName = nil
        self.lifeNumber = lifeNumber
        self.inheritedSoulPoints = inheritedSoulPoints
        self.inheritedSoulDomain = inheritedSoulDomain
        self.inheritedMemory = inheritedMemory
        self.creationAllocation = creationAllocation
    }

    public init(
        seed: String,
        presetID: String,
        playerName: String,
        lifeNumber: Int = 1,
        inheritedSoulPoints: Int = 0,
        inheritedSoulDomain: SoulDomain? = nil,
        inheritedMemory: MemoryCardID? = nil,
        creationAllocation: CreationAllocationSnapshot? = nil
    ) {
        self.seed = seed
        self.presetID = presetID
        self.playerName = playerName
        self.lifeNumber = lifeNumber
        self.inheritedSoulPoints = inheritedSoulPoints
        self.inheritedSoulDomain = inheritedSoulDomain
        self.inheritedMemory = inheritedMemory
        self.creationAllocation = creationAllocation
    }
}

public struct CreationAllocationSnapshot: Codable, Equatable, Sendable {
    public let stuff: Int
    public let command: Int
    public let movement: Int
    public let stamina: Int

    public init(stuff: Int, command: Int, movement: Int, stamina: Int) {
        self.stuff = stuff
        self.command = command
        self.movement = movement
        self.stamina = stamina
    }

    public var total: Int { stuff + command + movement + stamina }

    public static let balanced = CreationAllocationSnapshot(
        stuff: 2,
        command: 1,
        movement: 1,
        stamina: 1
    )
}

public struct CommitTrainingParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: PitcherLabSnapshot
    public let focus: TrainingFocus
    public let intensity: TrainingIntensity

    public init(seed: String, state: PitcherLabSnapshot, focus: TrainingFocus, intensity: TrainingIntensity) {
        self.seed = seed
        self.state = state
        self.focus = focus
        self.intensity = intensity
    }
}

public struct RecordImportantInningParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: PitcherLabSnapshot
    public let report: ImportantInningReport

    public init(seed: String, state: PitcherLabSnapshot, report: ImportantInningReport) {
        self.seed = seed
        self.state = state
        self.report = report
    }
}

public struct ChooseRelationshipParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: PitcherLabSnapshot
    public let choice: RelationshipChoice

    public init(seed: String, state: PitcherLabSnapshot, choice: RelationshipChoice) {
        self.seed = seed
        self.state = state
        self.choice = choice
    }
}

public struct ChooseAwakeningParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: PitcherLabSnapshot
    public let awakening: AwakeningID

    public init(seed: String, state: PitcherLabSnapshot, awakening: AwakeningID) {
        self.seed = seed
        self.state = state
        self.awakening = awakening
    }
}

public struct FinalizeScoutingParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: PitcherLabSnapshot

    public init(seed: String, state: PitcherLabSnapshot) {
        self.seed = seed
        self.state = state
    }
}

public struct SelectLegacyParams: Codable, Equatable, Sendable {
    public let seed: String
    public let state: PitcherLabSnapshot
    public let soulDomain: SoulDomain
    public let memoryCard: MemoryCardID

    public init(seed: String, state: PitcherLabSnapshot, soulDomain: SoulDomain, memoryCard: MemoryCardID) {
        self.seed = seed
        self.state = state
        self.soulDomain = soulDomain
        self.memoryCard = memoryCard
    }
}

public struct PitcherLabEvent: Codable, Equatable, Sendable {
    public let eventType: String
    public let sequence: Int
    public let training: TrainingSessionSnapshot?
    public let importantInning: ImportantInningReport?
    public let relationshipChoice: RelationshipChoice?
    public let awakening: AwakeningID?
    public let scouting: ScoutingEvaluationSnapshot?
    public let legacy: LegacySelectionSnapshot?
    public let reasonCodes: [String]

    public init(
        eventType: String,
        sequence: Int,
        training: TrainingSessionSnapshot? = nil,
        importantInning: ImportantInningReport? = nil,
        relationshipChoice: RelationshipChoice? = nil,
        awakening: AwakeningID? = nil,
        scouting: ScoutingEvaluationSnapshot? = nil,
        legacy: LegacySelectionSnapshot? = nil,
        reasonCodes: [String] = []
    ) {
        self.eventType = eventType
        self.sequence = sequence
        self.training = training
        self.importantInning = importantInning
        self.relationshipChoice = relationshipChoice
        self.awakening = awakening
        self.scouting = scouting
        self.legacy = legacy
        self.reasonCodes = reasonCodes
    }
}

public struct PitcherLabResult: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let nextSeed: String
    public let events: [PitcherLabEvent]
    public let snapshot: PitcherLabSnapshot
    public let eventHash: String

    public init(
        revision: UInt64,
        nextSeed: String,
        events: [PitcherLabEvent],
        snapshot: PitcherLabSnapshot,
        eventHash: String
    ) {
        self.revision = revision
        self.nextSeed = nextSeed
        self.events = events
        self.snapshot = snapshot
        self.eventHash = eventHash
    }
}

private enum HiddenGrowthTrait: Int, CaseIterable {
    case velocityBody
    case breakingLearner
    case mechanicsResponder
    case gameTranslator
    case recoveryGift
    case pressureAdapter

    var matchingFocus: TrainingFocus {
        switch self {
        case .velocityBody: return .velocity
        case .breakingLearner: return .breakingBall
        case .mechanicsResponder: return .command
        case .gameTranslator: return .gamePlanning
        case .recoveryGift: return .recovery
        case .pressureAdapter: return .stamina
        }
    }
}

public struct PitcherLabEngine: Sendable {
    public init() {}

    public func start(_ params: StartPitcherLabParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        guard let preset = PitcherPresetCatalog.all.first(where: { $0.id == params.presetID }) else {
            throw SimulationError.invalidPitcherLab("unknown pitcher preset")
        }
        guard (1...99).contains(params.lifeNumber), (0...20).contains(params.inheritedSoulPoints) else {
            throw SimulationError.invalidPitcherLab("life number or inherited soul points are invalid")
        }
        let allocation = params.creationAllocation ?? .balanced
        guard allocation.total == 5,
              [allocation.stuff, allocation.command, allocation.movement, allocation.stamina]
                .allSatisfy({ (0...5).contains($0) }) else {
            throw SimulationError.invalidPitcherLab("creation allocation must spend exactly five points")
        }
        let runID = "lab-\(params.seed)-life-\(params.lifeNumber)"
        let trait = hiddenTrait(runID: runID, seed: seed)
        let playerName = params.playerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? preset.pitcher.name
        guard (1...12).contains(playerName.count) else {
            throw SimulationError.invalidPitcherLab("player name must contain between one and twelve characters")
        }
        let namedPitcher = PitcherSnapshot(
            id: preset.pitcher.id,
            name: playerName,
            stuff: preset.pitcher.stuff,
            command: preset.pitcher.command,
            movement: preset.pitcher.movement,
            stamina: preset.pitcher.stamina,
            pitchProfiles: preset.pitcher.pitchProfiles
        )
        let createdPitcher = applyCreationAllocation(allocation, to: namedPitcher)
        let inheritedPitcher = applyInheritance(
            to: createdPitcher,
            soulPoints: params.inheritedSoulPoints,
            soulDomain: params.inheritedSoulDomain,
            memory: params.inheritedMemory
        )
        let base = PitcherLabSnapshot(
            runID: runID,
            revision: 0,
            lifeNumber: params.lifeNumber,
            presetID: params.presetID,
            phase: .training,
            pitcher: inheritedPitcher,
            trainingSessionsCompleted: 0,
            relationshipEventsCompleted: 0,
            selectedAwakenings: [],
            awakeningOptions: [],
            readiness: 72,
            fatigue: 8,
            catcherTrust: 50,
            developmentSignals: DevelopmentSignalsSnapshot(),
            potentialRanges: potentialRanges(
                pitcher: inheritedPitcher,
                trait: trait,
                sessions: 0,
                seed: seed
            ),
            performance: LabPerformanceSnapshot(),
            lastTraining: nil,
            scoutingEvaluation: nil,
            legacyOptions: [],
            legacySelection: nil,
            stateCommitment: ""
        )
        let snapshot = signed(base)
        return makeResult(
            seed: seed,
            snapshot: snapshot,
            events: [PitcherLabEvent(eventType: "pitcher_lab_started", sequence: 0)]
        )
    }

    public func commitTraining(_ params: CommitTrainingParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, expectedPhase: .training)
        guard params.state.trainingSessionsCompleted < 6 else {
            throw SimulationError.invalidPitcherLab("all six training sessions are already complete")
        }
        let trait = hiddenTrait(runID: params.state.runID, seed: runSeed(from: params.state.runID))
        let sessionNumber = params.state.trainingSessionsCompleted + 1
        var generator = SplitMix64(seed: seed ^ 0x5452_4149_4e49_4e47 ^ UInt64(sessionNumber))
        let intensityBase: Int
        let fatigueCost: Int
        switch params.intensity {
        case .light: intensityBase = 125; fatigueCost = 5
        case .standard: intensityBase = 190; fatigueCost = 11
        case .intensive: intensityBase = 255; fatigueCost = 20
        }
        let traitBonus = trait.matchingFocus == params.focus ? 135 : 0
        let readinessModifier = (params.state.readiness - 50) * 2
        let fatiguePenalty = max(0, params.state.fatigue - 35) * 2
        let repeatCount = recentRepeatCount(params.state, focus: params.focus)
        let repeatModifier = repeatCount == 0 ? 20 : repeatCount == 1 ? 55 : -45
        let randomModifier = generator.nextInt(upperBound: 81) - 40
        let signalGained = clamp(
            intensityBase + traitBonus + readinessModifier - fatiguePenalty + repeatModifier + randomModifier,
            60,
            520
        )
        let totalSignal = params.state.developmentSignals.value(for: params.focus) + signalGained
        let ratingPoints = totalSignal / 500
        let signals = params.state.developmentSignals.replacing(params.focus, with: totalSignal % 500)
        let pitcher = applyGrowth(to: params.state.pitcher, focus: params.focus, points: ratingPoints)
        let recoveryBonus = params.focus == .recovery ? 18 + (trait == .recoveryGift ? 8 : 0) : 0
        let fatigueAfter = clamp(params.state.fatigue + fatigueCost - recoveryBonus, 0, 100)
        let readinessCost = params.intensity == .intensive ? 12 : params.intensity == .standard ? 6 : 2
        let readinessAfter = clamp(
            params.state.readiness - readinessCost + (params.focus == .recovery ? 16 : 0),
            20,
            100
        )
        let reaction = reactionBand(signalGained)
        let training = TrainingSessionSnapshot(
            sessionNumber: sessionNumber,
            focus: params.focus,
            intensity: params.intensity,
            reaction: reaction,
            signalGained: signalGained,
            ratingPointsGained: ratingPoints,
            readinessBefore: params.state.readiness,
            readinessAfter: readinessAfter,
            fatigueBefore: params.state.fatigue,
            fatigueAfter: fatigueAfter,
            observedClue: clue(for: reaction, focus: params.focus),
            shortFeedback: trainingFeedback(
                focus: params.focus,
                reaction: reaction,
                ratingPoints: ratingPoints
            )
        )
        let nextPhase: PitcherLabPhase = sessionNumber == 2 || sessionNumber == 4
            ? .importantInning
            : sessionNumber == 3
                ? .relationship
                : sessionNumber == 5 || sessionNumber == 6
                    ? .awakening
                    : .training
        let options = nextPhase == .awakening
            ? awakeningOptions(state: params.state, seed: seed, ordinal: sessionNumber)
            : []
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: nextPhase,
            pitcher: pitcher,
            trainingSessionsCompleted: sessionNumber,
            awakeningOptions: options,
            readiness: readinessAfter,
            fatigue: fatigueAfter,
            developmentSignals: signals,
            potentialRanges: potentialRanges(
                pitcher: pitcher,
                trait: trait,
                sessions: sessionNumber,
                seed: runSeed(from: params.state.runID)
            ),
            lastTraining: training
        )
        return makeResult(
            seed: seed,
            snapshot: signed(updated),
            events: [
                PitcherLabEvent(
                    eventType: "training_session_resolved",
                    sequence: 0,
                    training: training,
                    reasonCodes: [
                        "training.focus.\(params.focus.rawValue)",
                        "training.reaction.\(reaction.rawValue)"
                    ]
                )
            ]
        )
    }

    public func recordImportantInning(_ params: RecordImportantInningParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, expectedPhase: .importantInning)
        let expectedScenario = params.state.performance.importantInningsCompleted + 1
        guard params.report.scenarioNumber == expectedScenario,
              (1...200).contains(params.report.pitches),
              params.report.strikeouts >= 0,
              params.report.walks >= 0,
              (0...20).contains(params.report.runsAllowed),
              params.report.expectedDamage >= 0,
              params.report.actualDamage >= 0,
              (0...params.report.pitches).contains(params.report.recommendationAccepted) else {
            throw SimulationError.invalidPitcherLab("important inning report is invalid or out of order")
        }
        let performance = params.state.performance.adding(params.report)
        let nextPhase: PitcherLabPhase = expectedScenario == 3 ? .scouting : .training
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: nextPhase,
            readiness: clamp(params.state.readiness - 8, 20, 100),
            fatigue: clamp(params.state.fatigue + max(2, params.report.pitches / 4), 0, 100),
            performance: performance
        )
        return makeResult(
            seed: seed,
            snapshot: signed(updated),
            events: [
                PitcherLabEvent(
                    eventType: "important_inning_completed",
                    sequence: 0,
                    importantInning: params.report,
                    reasonCodes: ["important_inning.\(expectedScenario)"]
                )
            ]
        )
    }

    public func chooseRelationship(_ params: ChooseRelationshipParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, expectedPhase: .relationship)
        guard params.state.relationshipEventsCompleted < 2 else {
            throw SimulationError.invalidPitcherLab("both catcher relationship events are complete")
        }
        let eventNumber = params.state.relationshipEventsCompleted + 1
        let trustChange = params.choice == .trustCatcher ? 12 : -7
        let nextPhase: PitcherLabPhase = eventNumber == 1 ? .training : .training
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: nextPhase,
            relationshipEventsCompleted: eventNumber,
            catcherTrust: clamp(params.state.catcherTrust + trustChange, 0, 100)
        )
        return makeResult(
            seed: seed,
            snapshot: signed(updated),
            events: [
                PitcherLabEvent(
                    eventType: "catcher_relationship_changed",
                    sequence: 0,
                    relationshipChoice: params.choice,
                    reasonCodes: ["catcher.trust.\(trustChange >= 0 ? "up" : "down")"]
                )
            ]
        )
    }

    public func chooseAwakening(_ params: ChooseAwakeningParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, expectedPhase: .awakening)
        guard params.state.awakeningOptions.contains(params.awakening),
              !params.state.selectedAwakenings.contains(params.awakening),
              params.state.selectedAwakenings.count < 2 else {
            throw SimulationError.invalidPitcherLab("awakening is not currently available")
        }
        let awakenings = params.state.selectedAwakenings + [params.awakening]
        let pitcher = applyAwakening(params.awakening, to: params.state.pitcher)
        let nextPhase: PitcherLabPhase = awakenings.count == 1 ? .relationship : .importantInning
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: nextPhase,
            pitcher: pitcher,
            selectedAwakenings: awakenings,
            awakeningOptions: []
        )
        return makeResult(
            seed: seed,
            snapshot: signed(updated),
            events: [
                PitcherLabEvent(
                    eventType: "awakening_granted",
                    sequence: 0,
                    awakening: params.awakening,
                    reasonCodes: ["awakening.\(params.awakening.rawValue)"]
                )
            ]
        )
    }

    public func finalizeScouting(_ params: FinalizeScoutingParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, expectedPhase: .scouting)
        guard params.state.performance.importantInningsCompleted == 3 else {
            throw SimulationError.invalidPitcherLab("three important innings are required")
        }
        let evaluation = scoutingEvaluation(for: params.state)
        let legacyOptions = memoryOptions(for: params.state, seed: seed)
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: .reflection,
            scoutingEvaluation: evaluation,
            legacyOptions: legacyOptions
        )
        return makeResult(
            seed: seed,
            snapshot: signed(updated),
            events: [
                PitcherLabEvent(
                    eventType: "scouting_evaluation_completed",
                    sequence: 0,
                    scouting: evaluation,
                    reasonCodes: ["scouting.grade.\(evaluation.grade.rawValue)"]
                )
            ]
        )
    }

    public func selectLegacy(_ params: SelectLegacyParams) throws -> PitcherLabResult {
        let seed = try validatedSeed(params.seed)
        try validate(params.state, expectedPhase: .reflection)
        guard params.state.legacyOptions.contains(params.memoryCard) else {
            throw SimulationError.invalidPitcherLab("memory card is not currently available")
        }
        let legacy = LegacySelectionSnapshot(
            soulDomain: params.soulDomain,
            memoryCard: params.memoryCard,
            soulPointsGranted: 2,
            unlockedSchoolID: params.state.lifeNumber == 1 ? "school-data-lab" : "school-river-tech",
            unlockedCoachID: params.state.lifeNumber == 1 ? "coach-analyst-han" : "coach-mechanics-kim",
            summary: "\(soulLabel(params.soulDomain)) 훈련으로 얻은 능력과 ‘\(memoryLabel(params.memoryCard))’을 다음 선수에게 넘깁니다."
        )
        let updated = replacing(
            params.state,
            revision: params.state.revision + 1,
            phase: .completed,
            legacySelection: legacy
        )
        return makeResult(
            seed: seed,
            snapshot: signed(updated),
            events: [
                PitcherLabEvent(
                    eventType: "life_completed",
                    sequence: 0,
                    legacy: legacy,
                    reasonCodes: [
                        "soul.\(params.soulDomain.rawValue)",
                        "memory.\(params.memoryCard.rawValue)"
                    ]
                )
            ]
        )
    }

    private func validatedSeed(_ value: String) throws -> UInt64 {
        guard let seed = UInt64(value) else { throw SimulationError.invalidSeed(value) }
        return seed
    }

    private func validate(_ state: PitcherLabSnapshot, expectedPhase: PitcherLabPhase) throws {
        guard state.phase == expectedPhase else {
            throw SimulationError.invalidPitcherLab("expected \(expectedPhase.rawValue), got \(state.phase.rawValue)")
        }
        guard state.stateCommitment == commitment(for: state),
              (0...6).contains(state.trainingSessionsCompleted),
              (0...2).contains(state.relationshipEventsCompleted),
              (0...100).contains(state.readiness),
              (0...100).contains(state.fatigue),
              (0...100).contains(state.catcherTrust) else {
            throw SimulationError.invalidPitcherLab("state commitment or counters are invalid")
        }
    }

    private func hiddenTrait(runID: String, seed: UInt64) -> HiddenGrowthTrait {
        let hash = UInt64(StableHash.fnv1a64(runID), radix: 16) ?? 0
        var generator = SplitMix64(seed: seed ^ hash ^ 0x4752_4f57_5448)
        return HiddenGrowthTrait(rawValue: generator.nextInt(upperBound: HiddenGrowthTrait.allCases.count))!
    }

    private func runSeed(from runID: String) -> UInt64 {
        let parts = runID.split(separator: "-")
        return parts.count >= 2 ? UInt64(parts[1]) ?? 0 : 0
    }

    private func potentialRanges(
        pitcher: PitcherSnapshot,
        trait: HiddenGrowthTrait,
        sessions: Int,
        seed: UInt64
    ) -> [PotentialRangeSnapshot] {
        let values: [(TrainingFocus, String, Int)] = [
            (.velocity, "stuff", pitcher.stuff),
            (.command, "command", pitcher.command),
            (.breakingBall, "movement", pitcher.movement),
            (.stamina, "stamina", pitcher.stamina)
        ]
        return values.enumerated().map { index, entry in
            var generator = SplitMix64(seed: seed ^ UInt64(index + 1) ^ 0x504f_5445_4e54)
            let traitBonus = trait.matchingFocus == entry.0 ? 8 : 0
            let uncertainty = max(3, 9 - sessions)
            let centerCeiling = clamp(entry.2 + 8 + traitBonus + generator.nextInt(upperBound: 7), 20, 80)
            return PotentialRangeSnapshot(
                metric: entry.1,
                current: entry.2,
                lowerBound: clamp(entry.2 + 2, 20, 80),
                upperBound: clamp(centerCeiling + uncertainty / 2, 20, 80),
                confidence: clamp(280 + sessions * 90, 0, 900)
            )
        }
    }

    private func recentRepeatCount(_ state: PitcherLabSnapshot, focus: TrainingFocus) -> Int {
        state.lastTraining?.focus == focus ? 1 : 0
    }

    private func reactionBand(_ signal: Int) -> TrainingReactionBand {
        switch signal {
        case ..<160: return .muted
        case ..<270: return .steady
        case ..<390: return .strong
        default: return .breakthrough
        }
    }

    private func clue(for reaction: TrainingReactionBand, focus: TrainingFocus) -> String {
        switch reaction {
        case .muted: return "몸이 자극을 받아들이는 데 시간이 더 필요해 보입니다."
        case .steady: return "반복할수록 같은 동작을 이어 가는 힘이 좋아집니다."
        case .strong: return "\(focusLabel(focus)) 훈련에서 동작이 예상보다 빠르게 안정됐습니다."
        case .breakthrough: return "코치가 같은 훈련을 계속하자고 할 만큼 동작이 빠르게 좋아졌습니다."
        }
    }

    private func trainingFeedback(
        focus: TrainingFocus,
        reaction: TrainingReactionBand,
        ratingPoints: Int
    ) -> String {
        let growth = ratingPoints > 0 ? " 실제 능력치가 \(ratingPoints)포인트 상승했습니다." : " 능력치는 그대로지만 다음 상승까지 훈련량이 쌓였습니다."
        return "\(focusLabel(focus)) 훈련 효과가 \(reactionLabel(reaction)) 편이었습니다.\(growth)"
    }

    private func applyGrowth(to pitcher: PitcherSnapshot, focus: TrainingFocus, points: Int) -> PitcherSnapshot {
        guard points > 0 else { return pitcher }
        let profiles = pitcher.pitchProfiles?.map { profile in
            PitchProfileSnapshot(
                pitchType: profile.pitchType,
                role: profile.role,
                velocityTenthsKPH: clamp(profile.velocityTenthsKPH + (focus == .velocity ? points * 5 : 0), 1_000, 1_700),
                control: clamp(profile.control + (focus == .command ? points : 0), 20, 80),
                command: clamp(profile.command + (focus == .command || focus == .gamePlanning ? points : 0), 20, 80),
                movement: clamp(profile.movement + (focus == .breakingBall && profile.pitchType != .fourSeam ? points * 2 : 0), 20, 80),
                whiff: clamp(profile.whiff + (focus == .breakingBall && profile.pitchType != .fourSeam ? points : 0), 20, 80),
                weakContact: profile.weakContact,
                fatigueCost: focus == .stamina && points > 1 ? max(0, profile.fatigueCost - 1) : profile.fatigueCost
            )
        }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: clamp(pitcher.stuff + (focus == .velocity ? points : 0), 20, 80),
            command: clamp(pitcher.command + (focus == .command || focus == .gamePlanning ? points : 0), 20, 80),
            movement: clamp(pitcher.movement + (focus == .breakingBall ? points : 0), 20, 80),
            stamina: clamp(pitcher.stamina + (focus == .stamina || focus == .recovery ? points : 0), 20, 80),
            pitchProfiles: profiles
        )
    }

    private func applyInheritance(
        to pitcher: PitcherSnapshot,
        soulPoints: Int,
        soulDomain: SoulDomain?,
        memory: MemoryCardID?
    ) -> PitcherSnapshot {
        guard soulPoints > 0 || memory != nil else { return pitcher }
        let soulFocus: TrainingFocus
        switch soulDomain {
        case .body: soulFocus = .velocity
        case .technique: soulFocus = .command
        case .game, .none: soulFocus = .gamePlanning
        }
        var inherited = applyGrowth(to: pitcher, focus: soulFocus, points: soulPoints)
        guard memory != nil else { return inherited }
        let memoryFocus: TrainingFocus
        switch memory {
        case .velocityBlueprint: memoryFocus = .velocity
        case .fingertipMemory: memoryFocus = .breakingBall
        case .recoveryRoutine: memoryFocus = .recovery
        case .fatigueDiary, .winterProgram: memoryFocus = .recovery
        case .mechanicsVideo, .coachLetter: memoryFocus = .command
        case .bullpenCompass: memoryFocus = .stamina
        case .catcherNotebook, .rivalNotebook, .pressureRehearsal, .firstPitchMap,
             .twoStrikeSequence, .schoolPlaybook, .draftReport, .stadiumEcho,
             .teamFirstPromise, .failureScorebook, .none: memoryFocus = .gamePlanning
        }
        inherited = applyGrowth(to: inherited, focus: memoryFocus, points: 2)
        return inherited
    }

    private func applyCreationAllocation(
        _ allocation: CreationAllocationSnapshot,
        to pitcher: PitcherSnapshot
    ) -> PitcherSnapshot {
        var updated = applyGrowth(to: pitcher, focus: .velocity, points: allocation.stuff)
        updated = applyGrowth(to: updated, focus: .command, points: allocation.command)
        updated = applyGrowth(to: updated, focus: .breakingBall, points: allocation.movement)
        return applyGrowth(to: updated, focus: .stamina, points: allocation.stamina)
    }

    private func awakeningOptions(state: PitcherLabSnapshot, seed: UInt64, ordinal: Int) -> [AwakeningID] {
        var candidates = AwakeningID.allCases.filter { !state.selectedAwakenings.contains($0) }
        var generator = SplitMix64(seed: seed ^ UInt64(ordinal) ^ 0x4157_414b_454e)
        for index in candidates.indices.reversed() where index > 0 {
            candidates.swapAt(index, generator.nextInt(upperBound: index + 1))
        }
        return Array(candidates.prefix(2))
    }

    private func applyAwakening(_ awakening: AwakeningID, to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        let focus: TrainingFocus
        switch awakening {
        case .explosiveFastball, .risingFourSeam: focus = .velocity
        case .pinpointEdge, .batterySync, .repeatableRelease, .firstPitchStrike: focus = .command
        case .disappearingBreaker, .sinkerTunnel, .frozenChangeup, .sweepingSlider, .curveballClock: focus = .breakingBall
        case .ironArm, .lateInningReserve: focus = .stamina
        case .calmUnderPressure, .pickoffRhythm, .twoStrikePlan, .trafficController, .scoutComposure: focus = .gamePlanning
        }
        return applyGrowth(to: pitcher, focus: focus, points: 2)
    }

    private func scoutingEvaluation(for state: PitcherLabSnapshot) -> ScoutingEvaluationSnapshot {
        let ratingAverage = (
            state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        ) / 4
        let performance = state.performance
        let runPenalty = performance.runsAllowed * 28
        let walkPenalty = performance.walks * 12
        let strikeoutBonus = performance.strikeouts * 15
        let processBonus = max(-120, min(120, (performance.expectedDamage - performance.actualDamage) / 8))
        let score = clamp(ratingAverage * 10 + strikeoutBonus + processBonus - runPenalty - walkPenalty, 0, 1_000)
        let grade: ScoutingGrade
        switch score {
        case ..<500: grade = .undrafted
        case ..<620: grade = .follow
        case ..<760: grade = .draftable
        default: grade = .elite
        }
        var strengths: [String] = []
        if state.pitcher.stuff >= 65 { strengths.append("타자를 밀어붙이는 직구") }
        if state.pitcher.command >= 65 { strengths.append("원하는 코스에 꾸준히 던지는 제구") }
        if state.pitcher.movement >= 65 { strengths.append("헛스윙을 잡는 변화구 움직임") }
        if state.pitcher.stamina >= 65 { strengths.append("선발 투수의 체력") }
        if strengths.isEmpty { strengths.append("공의 위력·제구·변화구·체력의 균형") }
        var concerns: [String] = []
        if performance.walks >= 3 { concerns.append("위기에서 늘어나는 볼넷") }
        if performance.runsAllowed >= 5 { concerns.append("실점 억제의 기복") }
        if state.fatigue >= 70 { concerns.append("누적 피로 관리") }
        if concerns.isEmpty { concerns.append("긴 경기에서도 같은 투구를 이어 갈 수 있는지") }
        return ScoutingEvaluationSnapshot(
            grade: grade,
            score: score,
            strengths: strengths,
            concerns: concerns,
            summary: "세 번의 중요 이닝과 여섯 번의 훈련 기록을 바탕으로 구단 평가에서 ‘\(scoutingLabel(grade))’ 등급을 받았습니다."
        )
    }

    private func focusLabel(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: return "직구 구속"
        case .command: return "제구"
        case .breakingBall: return "변화구"
        case .stamina: return "선발 체력"
        case .recovery: return "휴식과 회복"
        case .gamePlanning: return "타자 상대법"
        }
    }

    private func reactionLabel(_ reaction: TrainingReactionBand) -> String {
        switch reaction {
        case .muted: return "낮은"
        case .steady: return "보통인"
        case .strong: return "큰"
        case .breakthrough: return "매우 큰"
        }
    }

    private func soulLabel(_ domain: SoulDomain) -> String {
        switch domain {
        case .body: return "몸"
        case .technique: return "기술"
        case .game: return "경기 경험"
        }
    }

    private func memoryLabel(_ memory: MemoryCardID) -> String {
        switch memory {
        case .velocityBlueprint: return "직구 구속 훈련법"
        case .fingertipMemory: return "손끝의 기억"
        case .catcherNotebook: return "포수의 노트"
        case .rivalNotebook: return "라이벌 노트"
        case .recoveryRoutine: return "회복 방법"
        case .pressureRehearsal: return "압박의 예행연습"
        case .firstPitchMap: return "초구 지도"
        case .twoStrikeSequence: return "2스트라이크 구종 순서"
        case .fatigueDiary: return "피로 일지"
        case .mechanicsVideo: return "투구 동작 교정 영상"
        case .schoolPlaybook: return "학교에서 배운 승부법"
        case .coachLetter: return "코치의 편지"
        case .draftReport: return "구단 평가표"
        case .stadiumEcho: return "구장의 메아리"
        case .teamFirstPromise: return "팀을 위한 약속"
        case .failureScorebook: return "실패의 스코어북"
        case .winterProgram: return "겨울 훈련표"
        case .bullpenCompass: return "불펜의 나침반"
        }
    }

    private func scoutingLabel(_ grade: ScoutingGrade) -> String {
        switch grade {
        case .undrafted: return "미지명 예상"
        case .follow: return "더 지켜봄"
        case .draftable: return "지명 가능"
        case .elite: return "상위 순번 유력"
        }
    }

    private func memoryOptions(for state: PitcherLabSnapshot, seed: UInt64) -> [MemoryCardID] {
        var candidates: [MemoryCardID] = []
        if state.pitcher.stuff >= state.pitcher.movement { candidates.append(.velocityBlueprint) }
        if state.pitcher.movement >= state.pitcher.command { candidates.append(.fingertipMemory) }
        if state.catcherTrust >= 55 { candidates.append(.catcherNotebook) }
        if state.performance.actualDamage > state.performance.expectedDamage { candidates.append(.rivalNotebook) }
        if state.fatigue >= 55 { candidates.append(.recoveryRoutine) }
        candidates.append(.pressureRehearsal)
        let unique = candidates.reduce(into: [MemoryCardID]()) { values, item in
            if !values.contains(item) { values.append(item) }
        }
        if unique.count >= 2 { return Array(unique.prefix(2)) }
        var generator = SplitMix64(seed: seed ^ 0x4d45_4d4f_5259)
        let fallback = MemoryCardID.allCases.filter { !unique.contains($0) }
        return unique + [fallback[generator.nextInt(upperBound: fallback.count)]]
    }

    private func signed(_ state: PitcherLabSnapshot) -> PitcherLabSnapshot {
        replacing(state, stateCommitment: commitment(for: state))
    }

    private func commitment(for state: PitcherLabSnapshot) -> String {
        let profile = state.pitcher.pitchProfiles?.map {
            "\($0.pitchType.rawValue):\($0.velocityTenthsKPH):\($0.control):\($0.command):\($0.movement):\($0.whiff):\($0.fatigueCost)"
        }.joined(separator: ",") ?? "none"
        let ratings = "\(state.pitcher.stuff):\(state.pitcher.command):\(state.pitcher.movement):\(state.pitcher.stamina)"
        let signals = "\(state.developmentSignals.velocity):\(state.developmentSignals.command):\(state.developmentSignals.breakingBall):\(state.developmentSignals.stamina):\(state.developmentSignals.recovery):\(state.developmentSignals.gamePlanning)"
        let performance = "\(state.performance.importantInningsCompleted):\(state.performance.pitches):\(state.performance.strikeouts):\(state.performance.walks):\(state.performance.runsAllowed):\(state.performance.expectedDamage):\(state.performance.actualDamage):\(state.performance.recommendationAccepted)"
        let potential = state.potentialRanges.map {
            "\($0.metric):\($0.current):\($0.lowerBound):\($0.upperBound):\($0.confidence)"
        }.joined(separator: ",")
        let lastTraining = state.lastTraining.map {
            "\($0.sessionNumber):\($0.focus.rawValue):\($0.intensity.rawValue):\($0.reaction.rawValue):\($0.signalGained):\($0.ratingPointsGained):\($0.readinessAfter):\($0.fatigueAfter)"
        } ?? "no-training"
        let scouting = state.scoutingEvaluation.map { "\($0.grade.rawValue):\($0.score)" }
            ?? "no-scouting"
        let legacy = state.legacySelection.map {
            "\($0.soulDomain.rawValue):\($0.memoryCard.rawValue)"
        } ?? "no-legacy"
        let canonical = [
            state.runID,
            String(state.revision),
            String(state.lifeNumber),
            state.presetID,
            state.phase.rawValue,
            String(state.trainingSessionsCompleted),
            String(state.relationshipEventsCompleted),
            state.selectedAwakenings.map(\.rawValue).joined(separator: ","),
            state.awakeningOptions.map(\.rawValue).joined(separator: ","),
            String(state.readiness),
            String(state.fatigue),
            String(state.catcherTrust),
            ratings,
            profile,
            signals,
            potential,
            lastTraining,
            performance,
            scouting,
            state.legacyOptions.map(\.rawValue).joined(separator: ","),
            legacy
        ].joined(separator: "|")
        return StableHash.fnv1a64(canonical)
    }

    private func makeResult(
        seed: UInt64,
        snapshot: PitcherLabSnapshot,
        events: [PitcherLabEvent]
    ) -> PitcherLabResult {
        var generator = SplitMix64(seed: seed)
        let nextSeed = String(generator.next())
        let eventHash = StableHash.fnv1a64([
            String(seed),
            snapshot.stateCommitment,
            events.map(\.eventType).joined(separator: ","),
            nextSeed
        ].joined(separator: "|"))
        return PitcherLabResult(
            revision: snapshot.revision,
            nextSeed: nextSeed,
            events: events,
            snapshot: snapshot,
            eventHash: eventHash
        )
    }

    private func replacing(
        _ state: PitcherLabSnapshot,
        revision: UInt64? = nil,
        phase: PitcherLabPhase? = nil,
        pitcher: PitcherSnapshot? = nil,
        trainingSessionsCompleted: Int? = nil,
        relationshipEventsCompleted: Int? = nil,
        selectedAwakenings: [AwakeningID]? = nil,
        awakeningOptions: [AwakeningID]? = nil,
        readiness: Int? = nil,
        fatigue: Int? = nil,
        catcherTrust: Int? = nil,
        developmentSignals: DevelopmentSignalsSnapshot? = nil,
        potentialRanges: [PotentialRangeSnapshot]? = nil,
        performance: LabPerformanceSnapshot? = nil,
        lastTraining: TrainingSessionSnapshot? = nil,
        scoutingEvaluation: ScoutingEvaluationSnapshot? = nil,
        legacyOptions: [MemoryCardID]? = nil,
        legacySelection: LegacySelectionSnapshot? = nil,
        stateCommitment: String? = nil
    ) -> PitcherLabSnapshot {
        PitcherLabSnapshot(
            runID: state.runID,
            revision: revision ?? state.revision,
            lifeNumber: state.lifeNumber,
            presetID: state.presetID,
            phase: phase ?? state.phase,
            pitcher: pitcher ?? state.pitcher,
            trainingSessionsCompleted: trainingSessionsCompleted ?? state.trainingSessionsCompleted,
            relationshipEventsCompleted: relationshipEventsCompleted ?? state.relationshipEventsCompleted,
            selectedAwakenings: selectedAwakenings ?? state.selectedAwakenings,
            awakeningOptions: awakeningOptions ?? state.awakeningOptions,
            readiness: readiness ?? state.readiness,
            fatigue: fatigue ?? state.fatigue,
            catcherTrust: catcherTrust ?? state.catcherTrust,
            developmentSignals: developmentSignals ?? state.developmentSignals,
            potentialRanges: potentialRanges ?? state.potentialRanges,
            performance: performance ?? state.performance,
            lastTraining: lastTraining ?? state.lastTraining,
            scoutingEvaluation: scoutingEvaluation ?? state.scoutingEvaluation,
            legacyOptions: legacyOptions ?? state.legacyOptions,
            legacySelection: legacySelection ?? state.legacySelection,
            stateCommitment: stateCommitment ?? ""
        )
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
