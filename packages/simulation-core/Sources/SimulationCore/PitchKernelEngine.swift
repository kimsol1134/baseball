import Foundation

public struct CatcherRecommendationEngine: Sendable {
    public init() {}

    public func recommend(
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        adaptation: RivalAdaptationSnapshot? = nil
    ) -> (primary: CatcherRecommendation, alternative: CatcherRecommendation) {
        let twoStrikes = context.strikes == 2
        let protectZone = context.balls == 3
        let desiredPitch = recommendedPrimaryPitch(pitcher: pitcher, desired: scouting.pitchWeakness)
        let repetitionAvoided = (adaptation?.level ?? 0) >= 500
            && adaptation?.detectedPitch == desiredPitch
        let primaryPitch = repetitionAvoided
            ? recommendedAlternativePitch(
                pitcher: pitcher,
                excluding: desiredPitch,
                legacyDesired: desiredPitch == .fourSeam ? .slider : .fourSeam
            )
            : desiredPitch
        let primaryProfile = pitcher.profile(for: primaryPitch)
        let primary = CatcherRecommendation(
            call: PitchCall(
                pitchType: primaryPitch,
                zone: scouting.coldZone,
                zoneIntent: protectZone ? .strike : (twoStrikes ? .chase : .edge),
                intensity: protectZone || primaryProfile?.role == .development ? .controlled : .normal
            ),
            confidence: clamp(
                520
                    + (pitcher.command - 50) * 4
                    + ((primaryProfile?.command ?? 50) - 50) * 2
                    + (batter.discipline < 50 ? 45 : 0),
                350,
                850
            ),
            reasonCodes: [
                repetitionAvoided
                    ? "rival.pattern_detected"
                    : primaryPitch == scouting.pitchWeakness
                    ? "scouting.pitch_weakness"
                    : "arsenal.best_available",
                "scouting.cold_zone",
                twoStrikes ? "count.two_strikes" : "count.standard"
            ]
        )

        let alternativePitch = repetitionAvoided
            ? desiredPitch
            : recommendedAlternativePitch(
                pitcher: pitcher,
                excluding: primaryPitch,
                legacyDesired: scouting.pitchWeakness == .fourSeam ? .slider : .fourSeam
            )
        let mirroredZone = PitchZone(
            row: 2 - scouting.hotZone.row,
            column: 2 - scouting.hotZone.column
        )
        let alternativeZone = mirroredZone == scouting.hotZone
            ? PitchZone(row: 0, column: 2)
            : mirroredZone
        let alternative = CatcherRecommendation(
            call: PitchCall(
                pitchType: alternativePitch,
                zone: alternativeZone,
                zoneIntent: protectZone ? .strike : .edge,
                intensity: context.fatigue >= 60 ? .controlled : .normal
            ),
            confidence: clamp(430 + (pitcher.stuff - 50) * 3, 300, 760),
            reasonCodes: [
                "scouting.avoid_hot_zone",
                "sequence.change_speed",
                protectZone ? "count.avoid_walk" : "count.alternative"
            ]
        )
        return (primary, alternative)
    }

    private func recommendedPrimaryPitch(
        pitcher: PitcherSnapshot,
        desired: PitchType
    ) -> PitchType {
        guard let profiles = pitcher.pitchProfiles,
              let desiredProfile = pitcher.profile(for: desired) else {
            return desired
        }
        if desiredProfile.role != .development || profileScore(desiredProfile) >= 145 {
            return desired
        }
        return profiles
            .filter { $0.role != .development }
            .max { profileScore($0) < profileScore($1) }?
            .pitchType ?? desired
    }

    private func recommendedAlternativePitch(
        pitcher: PitcherSnapshot,
        excluding primary: PitchType,
        legacyDesired: PitchType
    ) -> PitchType {
        guard let profiles = pitcher.pitchProfiles else { return legacyDesired }
        return profiles
            .filter { $0.pitchType != primary && $0.role != .development }
            .max { profileScore($0) < profileScore($1) }?
            .pitchType ?? legacyDesired
    }

    private func profileScore(_ profile: PitchProfileSnapshot) -> Int {
        profile.command + profile.whiff + profile.weakContact
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}

public struct PitchKernelEngine: Sendable {
    private enum BatterApproach: String {
        case patient
        case aggressive
        case protect
        case power
    }

    private struct BatterPlan {
        let expectedPitch: PitchType
        let expectedZone: PitchZone
        let approach: BatterApproach
        let commitment: String
    }

    private let recommendationEngine: CatcherRecommendationEngine
    private let rivalMemoryEngine: RivalMemoryEngine
    private let ballInPlayEngine: BallInPlayEngine
    private let baserunnerEngine: BaserunnerEngine
    private let gameAnalysisEngine: GameAnalysisEngine

    public init(
        recommendationEngine: CatcherRecommendationEngine = CatcherRecommendationEngine(),
        rivalMemoryEngine: RivalMemoryEngine = RivalMemoryEngine(),
        ballInPlayEngine: BallInPlayEngine = BallInPlayEngine(),
        baserunnerEngine: BaserunnerEngine = BaserunnerEngine(),
        gameAnalysisEngine: GameAnalysisEngine = GameAnalysisEngine()
    ) {
        self.recommendationEngine = recommendationEngine
        self.rivalMemoryEngine = rivalMemoryEngine
        self.ballInPlayEngine = ballInPlayEngine
        self.baserunnerEngine = baserunnerEngine
        self.gameAnalysisEngine = gameAnalysisEngine
    }

    public func preparePitch(_ params: PreparePitchParams) throws -> PitchPreparation {
        let seed = try validate(params)
        let adaptation = rivalMemoryEngine.analyze(params.rivalMemory, context: params.context)
        let plan = commitBatterPlan(params: params, adaptation: adaptation, seed: seed)
        let recommendations = recommendationEngine.recommend(
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            adaptation: adaptation
        )
        let token = preparationToken(
            params: params,
            planCommitment: plan.commitment,
            primary: recommendations.primary,
            alternative: recommendations.alternative
        )
        return PitchPreparation(
            seed: params.seed,
            revision: params.context.revision,
            pitchNumber: params.context.pitchNumber,
            preparationToken: token,
            planCommitment: plan.commitment,
            primaryRecommendation: recommendationSnapshot(recommendations.primary),
            alternativeRecommendation: recommendationSnapshot(recommendations.alternative),
            rivalAdaptation: adaptation
        )
    }

    public func submitPitch(_ params: SubmitPitchParams) throws -> PitchKernelResult {
        let prepareParams = PreparePitchParams(
            seed: params.seed,
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            rivalMemory: params.rivalMemory,
            gameState: params.gameState,
            gameLog: params.gameLog
        )
        let seed = try validate(prepareParams)
        try validate(call: params.call, pitcher: params.pitcher)
        let adaptation = rivalMemoryEngine.analyze(params.rivalMemory, context: params.context)
        let plan = commitBatterPlan(params: prepareParams, adaptation: adaptation, seed: seed)
        let recommendations = recommendationEngine.recommend(
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: params.scouting,
            context: params.context,
            adaptation: adaptation
        )
        let expectedToken = preparationToken(
            params: prepareParams,
            planCommitment: plan.commitment,
            primary: recommendations.primary,
            alternative: recommendations.alternative
        )
        guard params.preparationToken == expectedToken else {
            throw SimulationError.invalidPreparationToken
        }

        let execution = executePitch(params: params, seed: seed)
        let wasInZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
        let planPitchMatched = plan.expectedPitch == params.call.pitchType
        let planZoneMatched = zonesAreNear(plan.expectedZone, params.call.zone)
        let neutralResolution = resolvePitch(
            params: params,
            plan: plan,
            execution: execution,
            wasInZone: wasInZone,
            adaptation: adaptation,
            seed: seed
        )
        let currentGameState = params.gameState ?? .standard
        let fieldingResolution = neutralResolution.battedBall.map {
            ballInPlayEngine.resolve(
                $0,
                gameState: currentGameState,
                seed: seed,
                ordinal: params.context.pitchNumber
            )
        }
        let outcome = fieldingResolution?.finalOutcome ?? neutralResolution.outcome
        let batterSwung = outcome != .ball && outcome != .calledStrike
        let selection = selectionQuality(
            call: params.call,
            pitcher: params.pitcher,
            scouting: params.scouting,
            context: params.context,
            adaptation: adaptation
        )
        let recommendationAccepted = params.call == recommendations.primary.call
        let state = advanceCount(
            context: params.context,
            outcome: outcome
        )
        let nextSeed = deriveNextSeed(seed)
        let revision = params.context.revision + 1
        let fatigueAfterPitch = min(
            100,
            params.context.fatigue
                + fatigueCost(params.call.intensity, profile: params.pitcher.profile(for: params.call.pitchType))
        )
        let updatedMemory = rivalMemoryEngine.record(
            params.rivalMemory,
            pitcher: params.pitcher,
            batter: params.batter,
            context: params.context,
            call: params.call,
            outcome: outcome,
            plateAppearanceEnded: state.result != nil
        )
        let baserunnerAdvance = state.result.map {
            baserunnerEngine.advance(
                currentGameState.runners,
                outcome: outcome,
                plateAppearanceResult: $0,
                defense: currentGameState.defense,
                seed: seed
            )
        }
        let updatedGameState = GameStateSnapshot(
            defense: currentGameState.defense,
            park: currentGameState.park,
            runners: baserunnerAdvance?.after ?? currentGameState.runners,
            runsAllowed: currentGameState.runsAllowed + (baserunnerAdvance?.runsScored ?? 0)
        )
        let updatedGameLog = gameAnalysisEngine.record(
            params.gameLog,
            gameID: params.gameLog?.gameID ?? "game-\(params.pitcher.id)",
            pitchType: params.call.pitchType,
            wasInZone: wasInZone,
            batterSwung: batterSwung,
            outcome: outcome,
            plateAppearanceResult: state.result,
            selectionQuality: selection,
            executionQuality: execution.executionQuality,
            battedBall: neutralResolution.battedBall,
            fielding: fieldingResolution,
            recommendationAccepted: recommendationAccepted
        )
        let postgameAnalysis = gameAnalysisEngine.analyze(updatedGameLog)
        let adaptationContext = PlateAppearanceContext(
            plateAppearanceID: params.context.plateAppearanceID,
            revision: revision,
            inning: params.context.inning,
            outs: params.context.outs,
            balls: state.result == nil ? state.balls : 0,
            strikes: state.result == nil ? state.strikes : 0,
            pitchNumber: state.result == nil ? params.context.pitchNumber + 1 : 1,
            scoreDifferential: params.context.scoreDifferential,
            leverage: params.context.leverage,
            fatigue: fatigueAfterPitch
        )
        let updatedAdaptation = rivalMemoryEngine.analyze(
            updatedMemory,
            context: adaptationContext
        )
        let reasonCodes = resolutionReasons(
            outcome: outcome,
            wasInZone: wasInZone,
            planPitchMatched: planPitchMatched,
            planZoneMatched: planZoneMatched,
            selectionQuality: selection,
            executionQuality: execution.executionQuality,
            adaptation: adaptation,
            fielding: fieldingResolution
        )
        let feedback = feedback(
            outcome: outcome,
            selection: selection,
            execution: execution,
            planPitchMatched: planPitchMatched,
            planZoneMatched: planZoneMatched,
            battedBall: neutralResolution.battedBall,
            adaptation: adaptation,
            fielding: fieldingResolution,
            baserunnerAdvance: baserunnerAdvance
        )

        var events: [PitchKernelEvent] = []
        events.append(
            PitchKernelEvent(
                eventType: "batter_plan_committed",
                sequence: events.count,
                planCommitment: plan.commitment
            )
        )
        events.append(
            PitchKernelEvent(
                eventType: "catcher_recommendations_generated",
                sequence: events.count,
                primaryRecommendation: recommendations.primary,
                alternativeRecommendation: recommendations.alternative,
                reasonCodes: recommendations.primary.reasonCodes
            )
        )
        events.append(
            PitchKernelEvent(
                eventType: "pitch_call_committed",
                sequence: events.count,
                call: params.call
            )
        )
        events.append(
            PitchKernelEvent(
                eventType: "pitch_executed",
                sequence: events.count,
                execution: execution,
                reasonCodes: executionReasonCodes(execution.executionQuality)
            )
        )
        events.append(
            PitchKernelEvent(
                eventType: "pitch_resolved",
                sequence: events.count,
                outcome: outcome,
                reasonCodes: reasonCodes
            )
        )
        if let battedBall = neutralResolution.battedBall {
            events.append(
                PitchKernelEvent(
                    eventType: "batted_ball_created",
                    sequence: events.count,
                    battedBall: battedBall,
                    reasonCodes: ["contact.quality.\(contactBand(battedBall.contactQuality))"]
                )
            )
        }
        if let fieldingResolution {
            events.append(
                PitchKernelEvent(
                    eventType: "fielding_resolved",
                    sequence: events.count,
                    fieldingResolution: fieldingResolution,
                    reasonCodes: [
                        "fielding.\(fieldingResolution.sector.rawValue)",
                        "fielding.impact.\(fieldingResolution.impact.rawValue)"
                    ]
                )
            )
        }
        events.append(
            PitchKernelEvent(
                eventType: "rival_memory_updated",
                sequence: events.count,
                rivalAdaptation: updatedAdaptation,
                reasonCodes: [
                    "rival.adaptation.\(updatedAdaptation.band.rawValue)",
                    "rival.evidence.\(updatedAdaptation.evidenceCount)"
                ]
            )
        )
        if let plateAppearanceResult = state.result {
            if let baserunnerAdvance {
                events.append(
                    PitchKernelEvent(
                        eventType: "baserunners_advanced",
                        sequence: events.count,
                        baserunnerAdvance: baserunnerAdvance,
                        reasonCodes: ["runs_scored.\(baserunnerAdvance.runsScored)"]
                    )
                )
            }
            events.append(
                PitchKernelEvent(
                    eventType: "plate_appearance_ended",
                    sequence: events.count,
                    plateAppearanceResult: plateAppearanceResult,
                    reasonCodes: ["plate_appearance.\(plateAppearanceResult.rawValue)"]
                )
            )
        }
        events.append(
            PitchKernelEvent(
                eventType: "game_analysis_updated",
                sequence: events.count,
                postgameAnalysis: postgameAnalysis,
                reasonCodes: [
                    "analysis.confidence.\(postgameAnalysis.confidence.rawValue)",
                    "analysis.sample.\(postgameAnalysis.sampleSize)"
                ]
            )
        )

        let snapshot = PlateAppearanceSnapshot(
            revision: revision,
            balls: state.balls,
            strikes: state.strikes,
            pitchNumber: params.context.pitchNumber,
            ended: state.result != nil,
            result: state.result,
            outcome: outcome,
            selectionQuality: selection,
            recommendationAccepted: recommendationAccepted,
            fatigueAfterPitch: fatigueAfterPitch,
            execution: execution,
            battedBall: neutralResolution.battedBall,
            fieldingResolution: fieldingResolution,
            runnersAfter: updatedGameState.runners,
            runsScored: baserunnerAdvance?.runsScored ?? 0,
            reasonCodes: reasonCodes,
            shortFeedback: feedback.short,
            detailFeedback: feedback.detail,
            accessibilitySummary: "\(feedback.short) \(feedback.detail)"
        )

        let nextPreparation: PitchPreparation?
        if state.result == nil {
            nextPreparation = try preparePitch(
                PreparePitchParams(
                    seed: nextSeed,
                    pitcher: params.pitcher,
                    batter: params.batter,
                    scouting: params.scouting,
                    context: adaptationContext,
                    rivalMemory: updatedMemory,
                    gameState: params.gameState == nil ? nil : updatedGameState,
                    gameLog: params.gameLog == nil ? nil : updatedGameLog
                )
            )
        } else {
            nextPreparation = nil
        }

        let eventHash = StableHash.fnv1a64(
            [
                params.seed,
                plan.commitment,
                canonical(params.call),
                canonical(params.pitcher.profile(for: params.call.pitchType)),
                String(execution.targetX),
                String(execution.targetY),
                String(execution.actualX),
                String(execution.actualY),
                String(execution.velocityTenthsKPH),
                outcome.rawValue,
                String(state.balls),
                String(state.strikes),
                state.result?.rawValue ?? "active",
                canonical(updatedMemory),
                String(updatedAdaptation.level),
                canonical(updatedGameState),
                canonical(updatedGameLog),
                nextSeed
            ].joined(separator: "|")
        )
        return PitchKernelResult(
            revision: revision,
            nextSeed: nextSeed,
            events: events,
            snapshot: snapshot,
            nextPreparation: nextPreparation,
            rivalMemory: updatedMemory,
            rivalAdaptation: updatedAdaptation,
            gameState: updatedGameState,
            gameLog: updatedGameLog,
            postgameAnalysis: postgameAnalysis,
            eventHash: eventHash
        )
    }

    private func validate(_ params: PreparePitchParams) throws -> UInt64 {
        guard let seed = UInt64(params.seed) else {
            throw SimulationError.invalidSeed(params.seed)
        }
        let ratings = [
            ("pitcher.stuff", params.pitcher.stuff),
            ("pitcher.command", params.pitcher.command),
            ("pitcher.movement", params.pitcher.movement),
            ("pitcher.stamina", params.pitcher.stamina),
            ("batter.contact", params.batter.contact),
            ("batter.discipline", params.batter.discipline),
            ("batter.power", params.batter.power)
        ]
        for (field, value) in ratings where !(20...80).contains(value) {
            throw SimulationError.invalidRating(field: field, value: value)
        }
        if let profiles = params.pitcher.pitchProfiles {
            guard !profiles.isEmpty else {
                throw SimulationError.invalidPitchProfile("pitchProfiles cannot be empty")
            }
            guard Set(profiles.map { $0.pitchType.rawValue }).count == profiles.count else {
                throw SimulationError.invalidPitchProfile("pitch types must be unique")
            }
            for profile in profiles {
                let profileRatings = [
                    ("control", profile.control),
                    ("command", profile.command),
                    ("movement", profile.movement),
                    ("whiff", profile.whiff),
                    ("weakContact", profile.weakContact)
                ]
                guard profileRatings.allSatisfy({ (20...80).contains($0.1) }) else {
                    throw SimulationError.invalidPitchProfile(
                        "\(profile.pitchType.rawValue) ratings must be between 20 and 80"
                    )
                }
                guard (1_000...1_700).contains(profile.velocityTenthsKPH) else {
                    throw SimulationError.invalidPitchProfile(
                        "\(profile.pitchType.rawValue) velocity must be between 100.0 and 170.0 km/h"
                    )
                }
                guard (0...3).contains(profile.fatigueCost) else {
                    throw SimulationError.invalidPitchProfile(
                        "\(profile.pitchType.rawValue) fatigueCost must be between 0 and 3"
                    )
                }
            }
        }
        guard isValidZone(params.scouting.hotZone), isValidZone(params.scouting.coldZone) else {
            throw SimulationError.invalidScouting("hot and cold zones must be within the 3x3 grid")
        }
        guard (20...80).contains(params.scouting.chaseTendency) else {
            throw SimulationError.invalidScouting("chaseTendency must be between 20 and 80")
        }
        try rivalMemoryEngine.validate(
            params.rivalMemory,
            pitcher: params.pitcher,
            batter: params.batter
        )
        if let gameState = params.gameState {
            let defenseRatings = [
                gameState.defense.infield,
                gameState.defense.outfield,
                gameState.defense.arm,
                gameState.runners.leadRunnerSpeed
            ]
            guard defenseRatings.allSatisfy({ (20...80).contains($0) }),
                  !gameState.park.id.isEmpty,
                  !gameState.park.name.isEmpty,
                  (700...1_300).contains(gameState.park.hitFactor),
                  (700...1_300).contains(gameState.park.homeRunFactor),
                  (0...99).contains(gameState.runsAllowed) else {
                throw SimulationError.invalidGameState("defense, park, runner, or score values are out of range")
            }
        }
        try gameAnalysisEngine.validate(params.gameLog)
        let context = params.context
        guard !context.plateAppearanceID.isEmpty,
              (1...20).contains(context.inning),
              (0...2).contains(context.outs),
              (0...3).contains(context.balls),
              (0...2).contains(context.strikes),
              context.pitchNumber >= 1,
              (0...1_000).contains(context.leverage),
              (0...100).contains(context.fatigue) else {
            throw SimulationError.invalidPlateAppearance("one or more fields are out of range")
        }
        return seed
    }

    private func validate(call: PitchCall, pitcher: PitcherSnapshot) throws {
        guard isValidZone(call.zone) else {
            throw SimulationError.invalidZone(row: call.zone.row, column: call.zone.column)
        }
        if pitcher.pitchProfiles != nil, pitcher.profile(for: call.pitchType) == nil {
            throw SimulationError.invalidPitchProfile(
                "\(call.pitchType.rawValue) is not in this pitcher's repertoire"
            )
        }
    }

    private func isValidZone(_ zone: PitchZone) -> Bool {
        (0...2).contains(zone.row) && (0...2).contains(zone.column)
    }

    private func commitBatterPlan(
        params: PreparePitchParams,
        adaptation: RivalAdaptationSnapshot,
        seed: UInt64
    ) -> BatterPlan {
        var generator = SplitMix64(
            seed: derivedSeed(seed, domain: 0x504c_414e, ordinal: params.context.pitchNumber)
        )
        var pitchWeights: [(pitchType: PitchType, weight: Int)] = [
            (.fourSeam, 340),
            (.slider, 260),
            (.changeup, 200),
            (.curveball, 200)
        ]
        if let detectedPitch = adaptation.detectedPitch,
           let index = pitchWeights.firstIndex(where: { $0.pitchType == detectedPitch }) {
            pitchWeights[index].weight += adaptation.level * 2
        }
        let totalPitchWeight = pitchWeights.reduce(0) { $0 + $1.weight }
        var pitchRoll = generator.nextInt(upperBound: totalPitchWeight)
        var expectedPitch = PitchType.fourSeam
        for candidate in pitchWeights {
            if pitchRoll < candidate.weight {
                expectedPitch = candidate.pitchType
                break
            }
            pitchRoll -= candidate.weight
        }

        let expectedZone: PitchZone
        if let detectedZone = adaptation.detectedZone,
           generator.nextInt(upperBound: 100) < min(78, 32 + adaptation.level / 18) {
            expectedZone = detectedZone
        } else if generator.nextInt(upperBound: 100) < 45 {
            expectedZone = params.scouting.hotZone
        } else {
            expectedZone = PitchZone(
                row: generator.nextInt(upperBound: 3),
                column: generator.nextInt(upperBound: 3)
            )
        }
        let approach: BatterApproach
        if params.context.strikes == 2 {
            approach = .protect
        } else if params.context.balls == 3 {
            approach = .patient
        } else {
            approach = generator.nextInt(upperBound: 100) < 55 ? .aggressive : .power
        }
        let commitment = StableHash.fnv1a64(
            [
                params.context.plateAppearanceID,
                String(params.context.pitchNumber),
                expectedPitch.rawValue,
                String(expectedZone.row),
                String(expectedZone.column),
                approach.rawValue,
                String(generator.next())
            ].joined(separator: "|")
        )
        return BatterPlan(
            expectedPitch: expectedPitch,
            expectedZone: expectedZone,
            approach: approach,
            commitment: commitment
        )
    }

    private func preparationToken(
        params: PreparePitchParams,
        planCommitment: String,
        primary: CatcherRecommendation,
        alternative: CatcherRecommendation
    ) -> String {
        StableHash.fnv1a64(
            [
                "pitch-preparation-v1",
                params.seed,
                params.context.plateAppearanceID,
                String(params.context.revision),
                String(params.context.pitchNumber),
                String(params.context.balls),
                String(params.context.strikes),
                canonical(params.pitcher),
                canonical(params.rivalMemory),
                canonical(params.gameState),
                canonical(params.gameLog),
                planCommitment,
                canonical(primary.call),
                canonical(alternative.call)
            ].joined(separator: "|")
        )
    }

    private func executePitch(params: SubmitPitchParams, seed: UInt64) -> PitchExecution {
        var generator = SplitMix64(
            seed: derivedSeed(seed, domain: 0x4558_4543, ordinal: params.context.pitchNumber)
        )
        let target = targetCoordinates(for: params.call)
        let intensityPenalty: Int
        let velocityBonus: Int
        switch params.call.intensity {
        case .controlled:
            intensityPenalty = -70
            velocityBonus = -18
        case .normal:
            intensityPenalty = 0
            velocityBonus = 0
        case .maxEffort:
            intensityPenalty = 130
            velocityBonus = 32
        }
        let profile = params.pitcher.profile(for: params.call.pitchType)
        let commandRating = profile.map {
            (params.pitcher.command * 4 + $0.control * 4 + $0.command * 2) / 10
        } ?? params.pitcher.command
        let effectiveCommand = clamp(
            commandRating * 10 - params.context.fatigue * 2 - intensityPenalty,
            100,
            900
        )
        let spread = clamp(520 - effectiveCommand / 2, 70, 470)
        var offsetX = generator.nextInt(upperBound: spread * 2 + 1) - spread
        var offsetY = generator.nextInt(upperBound: spread * 2 + 1) - spread
        let wildChance = clamp(
            8 + params.context.fatigue / 10 + (params.call.intensity == .maxEffort ? 4 : 0)
                - (commandRating - 50) / 4,
            3,
            20
        )
        if generator.nextInt(upperBound: 100) < wildChance {
            let wildOffset = 240 + generator.nextInt(upperBound: 321)
            if generator.nextInt(upperBound: 2) == 0 {
                offsetX += generator.nextInt(upperBound: 2) == 0 ? -wildOffset : wildOffset
            } else {
                offsetY += generator.nextInt(upperBound: 2) == 0 ? -wildOffset : wildOffset
            }
        }
        let executionQuality = clamp(
            1_000 - abs(offsetX) - abs(offsetY) + effectiveCommand / 5,
            0,
            1_000
        )
        let baseVelocity: Int
        let horizontalBreak: Int
        let verticalBreak: Int
        switch params.call.pitchType {
        case .fourSeam:
            baseVelocity = 1_420
            horizontalBreak = 70
            verticalBreak = 160
        case .slider:
            baseVelocity = 1_275
            horizontalBreak = -145
            verticalBreak = 35
        case .curveball:
            baseVelocity = 1_165
            horizontalBreak = -65
            verticalBreak = -185
        case .changeup:
            baseVelocity = 1_285
            horizontalBreak = 105
            verticalBreak = -45
        }
        let velocity = (profile?.velocityTenthsKPH ?? baseVelocity + (params.pitcher.stuff - 50) * 4)
            + velocityBonus
            - params.context.fatigue
            + generator.nextInt(upperBound: 21) - 10
        let movementScale = (profile?.movement ?? params.pitcher.movement) - 50
        return PitchExecution(
            targetX: target.x,
            targetY: target.y,
            actualX: target.x + offsetX,
            actualY: target.y + offsetY,
            velocityTenthsKPH: velocity,
            horizontalBreakTenthsCM: horizontalBreak + movementScale * 2,
            verticalBreakTenthsCM: verticalBreak + movementScale * 2,
            executionQuality: executionQuality
        )
    }

    private func resolvePitch(
        params: SubmitPitchParams,
        plan: BatterPlan,
        execution: PitchExecution,
        wasInZone: Bool,
        adaptation: RivalAdaptationSnapshot,
        seed: UInt64
    ) -> (outcome: PitchOutcome, battedBall: BattedBall?) {
        var generator = SplitMix64(
            seed: derivedSeed(seed, domain: 0x5245_534f, ordinal: params.context.pitchNumber)
        )
        let pitchMatched = plan.expectedPitch == params.call.pitchType
        let zoneMatched = zonesAreNear(plan.expectedZone, params.call.zone)
        let patternRecognitionBonus = (pitchMatched ? adaptation.level / 6 : 0)
            + (zoneMatched ? adaptation.level / 10 : 0)
        let recognitionBonus = (pitchMatched ? 95 : -65)
            + (zoneMatched ? 70 : -35)
            + patternRecognitionBonus
        let approachSwingBonus: Int
        switch plan.approach {
        case .patient: approachSwingBonus = -150
        case .aggressive: approachSwingBonus = 120
        case .protect: approachSwingBonus = 80
        case .power: approachSwingBonus = 35
        }
        let swingChance = clamp(
            (wasInZone ? 610 : 110)
                + params.scouting.chaseTendency * (wasInZone ? 1 : 4)
                - params.batter.discipline * 2
                + recognitionBonus
                + approachSwingBonus,
            25,
            960
        )
        let batterSwung = generator.nextInt(upperBound: 1_000) < swingChance
        if !batterSwung {
            return (wasInZone ? .calledStrike : .ball, nil)
        }

        let profile = params.pitcher.profile(for: params.call.pitchType)
        let pitchDifficulty: Int
        if let profile {
            pitchDifficulty = (params.pitcher.stuff - 50) * 2
                + (profile.whiff - 50) * 3
                + (profile.movement - 50) * 2
                + max(0, execution.executionQuality - 500) / 2
        } else {
            pitchDifficulty = (params.pitcher.stuff - 50) * 6
                + (params.pitcher.movement - 50) * 5
                + max(0, execution.executionQuality - 500) / 2
        }
        let contactChance = clamp(
            560
                + (params.batter.contact - 50) * 8
                + (pitchMatched ? 100 : -80)
                + (zoneMatched ? 55 : -40)
                + (pitchMatched ? adaptation.level / 5 : 0)
                - pitchDifficulty,
            70,
            930
        )
        guard generator.nextInt(upperBound: 1_000) < contactChance else {
            return (.swingingStrike, nil)
        }

        let foulChance = clamp(
            230 + ((profile?.movement ?? params.pitcher.movement) - params.batter.contact) * 3,
            120,
            390
        )
        if generator.nextInt(upperBound: 1_000) < foulChance {
            return (.foul, nil)
        }

        let contactQuality = clamp(
            430
                + (params.batter.power - 50) * 7
                + (params.batter.contact - 50) * 4
                + (pitchMatched ? 90 : -70)
                + (zoneMatched ? 45 : -35)
                + (pitchMatched ? adaptation.level / 8 : 0)
                - ((profile?.weakContact ?? 50) - 50) * 2
                - max(0, execution.executionQuality - 500) / 3
                + generator.nextInt(upperBound: 301) - 150,
            0,
            1_000
        )
        let battedBall = BattedBall(
            exitVelocityTenthsKPH: 1_050 + contactQuality / 2,
            launchAngleTenthsDegrees: -50 + generator.nextInt(upperBound: 430),
            directionTenthsDegrees: -450 + generator.nextInt(upperBound: 901),
            contactQuality: contactQuality
        )
        let outcome: PitchOutcome
        switch contactQuality {
        case ..<500: outcome = .inPlayOut
        case 500..<690: outcome = .single
        case 690..<790: outcome = .double
        default: outcome = .homeRun
        }
        return (outcome, battedBall)
    }

    private func advanceCount(
        context: PlateAppearanceContext,
        outcome: PitchOutcome
    ) -> (balls: Int, strikes: Int, result: PlateAppearanceResult?) {
        switch outcome {
        case .ball:
            if context.balls == 3 { return (3, context.strikes, .walk) }
            return (context.balls + 1, context.strikes, nil)
        case .calledStrike, .swingingStrike:
            if context.strikes == 2 { return (context.balls, 2, .strikeout) }
            return (context.balls, context.strikes + 1, nil)
        case .foul:
            return (context.balls, min(2, context.strikes + 1), nil)
        case .inPlayOut:
            return (context.balls, context.strikes, .inPlayOut)
        case .single, .double, .homeRun:
            return (context.balls, context.strikes, .hit)
        }
    }

    private func selectionQuality(
        call: PitchCall,
        pitcher: PitcherSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        adaptation: RivalAdaptationSnapshot
    ) -> SelectionQuality {
        var score = 500
        if call.pitchType == scouting.pitchWeakness { score += 170 }
        if call.pitchType == scouting.pitchStrength { score -= 190 }
        if call.zone == scouting.coldZone { score += 130 }
        if call.zone == scouting.hotZone { score -= 170 }
        if context.strikes == 2, call.zoneIntent == .chase { score += 90 }
        if context.balls == 3, call.zoneIntent == .chase { score -= 260 }
        if context.fatigue >= 60, call.intensity == .maxEffort { score -= 140 }
        if call.zoneIntent == .edge { score += 35 }
        if let profile = pitcher.profile(for: call.pitchType) {
            if profile.role == .primary { score += 45 }
            if profile.role == .development { score -= 120 }
            if call.zoneIntent == .edge { score += (profile.command - 50) * 3 }
            if call.zoneIntent == .chase { score += (profile.whiff - 50) * 2 }
        }
        if adaptation.detectedPitch == call.pitchType {
            score -= adaptation.level / 3
        }
        if adaptation.detectedZone == call.zone {
            score -= adaptation.level / 5
        }
        switch score {
        case ..<340: return .poor
        case 340..<540: return .risky
        case 540..<740: return .good
        default: return .excellent
        }
    }

    private func targetCoordinates(for call: PitchCall) -> (x: Int, y: Int) {
        var x = (call.zone.column - 1) * 330
        var y = (1 - call.zone.row) * 330
        switch call.zoneIntent {
        case .strike:
            x = x * 7 / 10
            y = y * 7 / 10
        case .edge:
            break
        case .chase:
            if abs(x) >= abs(y), x != 0 {
                x = x > 0 ? 650 : -650
            } else if y != 0 {
                y = y > 0 ? 650 : -650
            } else {
                y = -650
            }
        }
        return (x, y)
    }

    private func recommendationSnapshot(
        _ recommendation: CatcherRecommendation
    ) -> CatcherRecommendationSnapshot {
        let pitchName = pitchDisplayName(recommendation.call.pitchType)
        let zoneName = zoneDisplayName(recommendation.call.zone)
        let intent: String
        switch recommendation.call.zoneIntent {
        case .strike: intent = "존 안"
        case .edge: intent = "경계"
        case .chase: intent = "유인구"
        }
        let shortReason: String
        if recommendation.reasonCodes.contains("rival.pattern_detected") {
            shortReason = "라이벌이 반복 구종을 읽고 있어 \(zoneName) \(pitchName)으로 패턴을 바꿉니다."
        } else if recommendation.reasonCodes.contains("scouting.pitch_weakness") {
            shortReason = "타자의 약점인 \(zoneName) \(pitchName)\(pitchObjectParticle(recommendation.call.pitchType)) \(intent)로 공략합니다."
        } else {
            shortReason = "강한 코스를 피해 \(zoneName) \(pitchName)으로 타이밍을 바꿉니다."
        }
        return CatcherRecommendationSnapshot(
            call: recommendation.call,
            confidence: recommendation.confidence,
            reasonCodes: recommendation.reasonCodes,
            shortReason: shortReason
        )
    }

    private func feedback(
        outcome: PitchOutcome,
        selection: SelectionQuality,
        execution: PitchExecution,
        planPitchMatched: Bool,
        planZoneMatched: Bool,
        battedBall: BattedBall?,
        adaptation: RivalAdaptationSnapshot,
        fielding: FieldingResolutionSnapshot?,
        baserunnerAdvance: BaserunnerAdvanceSnapshot?
    ) -> (short: String, detail: String) {
        let short: String
        switch outcome {
        case .ball: short = "타자가 골라내 볼이 됐습니다."
        case .calledStrike: short = "ABS가 스트라이크를 선언했습니다."
        case .swingingStrike: short = "타자의 배트를 끌어내 헛스윙을 만들었습니다."
        case .foul: short = "타자가 걷어내 파울이 됐습니다."
        case .inPlayOut: short = "약한 타구를 유도해 아웃을 만들었습니다."
        case .single: short = "타구가 수비 사이를 빠져나가 단타가 됐습니다."
        case .double: short = "강한 타구가 외야를 갈라 2루타가 됐습니다."
        case .homeRun: short = "정타를 허용해 홈런이 됐습니다."
        }
        let planText: String
        switch (planPitchMatched, planZoneMatched) {
        case (true, true): planText = "타자가 구종과 코스를 모두 예상했습니다"
        case (true, false): planText = "구종은 읽혔지만 코스는 노림수를 벗어났습니다"
        case (false, true): planText = "코스는 예상 범위였지만 구종으로 타이밍을 흔들었습니다"
        case (false, false): planText = "구종과 코스 모두 타자의 노림수를 벗어났습니다"
        }
        let contactText = battedBall.map {
            " 타구 속도는 \(String(format: "%.1f", Double($0.exitVelocityTenthsKPH) / 10))km/h였습니다."
        } ?? ""
        let adaptationText = adaptation.band == .lockedOn && (planPitchMatched || planZoneMatched)
            ? " 라이벌이 이전 대결의 반복을 활용했습니다."
            : ""
        let fieldingText = fielding.map { " \($0.shortExplanation)" } ?? ""
        let runnerText = baserunnerAdvance.map { " \($0.shortExplanation)" } ?? ""
        let detail = "선택은 \(selectionDisplayName(selection)), 실행 품질은 \(execution.executionQuality)입니다. \(planText).\(adaptationText)\(contactText)\(fieldingText)\(runnerText)"
        return (short, detail)
    }

    private func resolutionReasons(
        outcome: PitchOutcome,
        wasInZone: Bool,
        planPitchMatched: Bool,
        planZoneMatched: Bool,
        selectionQuality: SelectionQuality,
        executionQuality: Int,
        adaptation: RivalAdaptationSnapshot,
        fielding: FieldingResolutionSnapshot?
    ) -> [String] {
        var reasons = [
            "outcome.\(outcome.rawValue)",
            wasInZone ? "abs.in_zone" : "abs.out_of_zone",
            planPitchMatched ? "batter_plan.pitch_matched" : "batter_plan.pitch_missed",
            planZoneMatched ? "batter_plan.zone_matched" : "batter_plan.zone_missed",
            "selection.\(selectionQuality.rawValue)",
            executionReasonCodes(executionQuality)[0]
        ]
        if adaptation.detectedPitch != nil || adaptation.detectedZone != nil {
            reasons.append("rival.pattern.\(adaptation.band.rawValue)")
        }
        if let fielding {
            reasons.append("fielding.impact.\(fielding.impact.rawValue)")
            if abs(fielding.parkAdjustment) >= 60 {
                reasons.append("park.material_adjustment")
            }
        }
        return reasons
    }

    private func executionReasonCodes(_ quality: Int) -> [String] {
        switch quality {
        case ..<350: return ["execution.missed_target"]
        case 350..<600: return ["execution.location_vulnerable"]
        case 600..<800: return ["execution.near_target"]
        default: return ["execution.precise"]
        }
    }

    private func canonical(_ call: PitchCall) -> String {
        [
            call.pitchType.rawValue,
            String(call.zone.row),
            String(call.zone.column),
            call.zoneIntent.rawValue,
            call.intensity.rawValue
        ].joined(separator: ":")
    }

    private func canonical(_ pitcher: PitcherSnapshot) -> String {
        let profiles = pitcher.pitchProfiles?
            .sorted { $0.pitchType.rawValue < $1.pitchType.rawValue }
            .map { canonical(Optional($0)) }
            .joined(separator: ",") ?? "legacy"
        return [
            pitcher.id,
            String(pitcher.stuff),
            String(pitcher.command),
            String(pitcher.movement),
            String(pitcher.stamina),
            profiles
        ].joined(separator: ":")
    }

    private func canonical(_ profile: PitchProfileSnapshot?) -> String {
        guard let profile else { return "legacy" }
        return [
            profile.pitchType.rawValue,
            profile.role.rawValue,
            String(profile.velocityTenthsKPH),
            String(profile.control),
            String(profile.command),
            String(profile.movement),
            String(profile.whiff),
            String(profile.weakContact),
            String(profile.fatigueCost)
        ].joined(separator: ":")
    }

    private func canonical(_ memory: RivalMemorySnapshot?) -> String {
        guard let memory else { return "no-rival-memory" }
        let observations = memory.recentObservations.map {
            [
                $0.pitchType.rawValue,
                String($0.zone.row),
                String($0.zone.column),
                $0.zoneIntent.rawValue,
                String($0.balls),
                String($0.strikes),
                $0.outcome.rawValue
            ].joined(separator: ":")
        }.joined(separator: ",")
        return [
            memory.matchupID,
            String(memory.revision),
            String(memory.plateAppearancesSeen),
            String(memory.totalPitchesSeen),
            observations
        ].joined(separator: "|")
    }

    private func canonical(_ state: GameStateSnapshot?) -> String {
        guard let state else { return "standard-game-state" }
        return [
            String(state.defense.infield),
            String(state.defense.outfield),
            String(state.defense.arm),
            state.park.id,
            String(state.park.hitFactor),
            String(state.park.homeRunFactor),
            state.runners.firstOccupied ? "1" : "0",
            state.runners.secondOccupied ? "1" : "0",
            state.runners.thirdOccupied ? "1" : "0",
            String(state.runners.leadRunnerSpeed),
            String(state.runsAllowed)
        ].joined(separator: ":")
    }

    private func canonical(_ log: GameLogSnapshot?) -> String {
        guard let log else { return "empty-game-log" }
        let entries = log.entries.map {
            [
                $0.pitchType.rawValue,
                $0.wasInZone ? "1" : "0",
                $0.batterSwung ? "1" : "0",
                $0.outcome.rawValue,
                $0.selectionQuality.rawValue,
                String($0.executionQuality),
                String($0.contactQuality ?? -1),
                String($0.expectedDamage),
                String($0.actualDamage),
                $0.recommendationAccepted ? "1" : "0"
            ].joined(separator: ":")
        }.joined(separator: ",")
        return [
            log.gameID,
            String(log.revision),
            String(log.totalPitches),
            entries
        ].joined(separator: "|")
    }

    private func zonesAreNear(_ first: PitchZone, _ second: PitchZone) -> Bool {
        abs(first.row - second.row) + abs(first.column - second.column) <= 1
    }

    private func deriveNextSeed(_ seed: UInt64) -> String {
        var generator = SplitMix64(seed: seed)
        _ = generator.next()
        return String(generator.state)
    }

    private func derivedSeed(_ seed: UInt64, domain: UInt64, ordinal: Int) -> UInt64 {
        var generator = SplitMix64(seed: seed ^ domain ^ (UInt64(ordinal) &* 0x9E37_79B9))
        return generator.next()
    }

    private func fatigueCost(
        _ intensity: PitchIntensity,
        profile: PitchProfileSnapshot?
    ) -> Int {
        if let profile {
            let intensityModifier: Int
            switch intensity {
            case .controlled: intensityModifier = -1
            case .normal: intensityModifier = 0
            case .maxEffort: intensityModifier = 1
            }
            return max(0, profile.fatigueCost + intensityModifier)
        }
        switch intensity {
        case .controlled: return 0
        case .normal: return 1
        case .maxEffort: return 2
        }
    }

    private func contactBand(_ quality: Int) -> String {
        switch quality {
        case ..<350: return "weak"
        case 350..<650: return "average"
        default: return "hard"
        }
    }

    private func pitchDisplayName(_ pitchType: PitchType) -> String {
        switch pitchType {
        case .fourSeam: return "포심"
        case .slider: return "슬라이더"
        case .curveball: return "커브"
        case .changeup: return "체인지업"
        }
    }

    private func pitchObjectParticle(_ pitchType: PitchType) -> String {
        switch pitchType {
        case .fourSeam, .changeup: return "을"
        case .slider, .curveball: return "를"
        }
    }

    private func zoneDisplayName(_ zone: PitchZone) -> String {
        let vertical = ["높은", "가운데", "낮은"][zone.row]
        let horizontal = ["몸쪽", "가운데", "바깥쪽"][zone.column]
        return vertical == "가운데" && horizontal == "가운데"
            ? "가운데"
            : "\(vertical) \(horizontal)"
    }

    private func selectionDisplayName(_ quality: SelectionQuality) -> String {
        switch quality {
        case .poor: return "위험했습니다"
        case .risky: return "다소 위험했습니다"
        case .good: return "좋았습니다"
        case .excellent: return "매우 좋았습니다"
        }
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
