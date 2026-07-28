import Foundation

public struct CatcherRecommendationEngine: Sendable {
    public init() {}

    /// `scouting` here is the *estimated* read, and `reliability` (0–100) is how much to trust it.
    /// A low reliability both feeds a possibly-wrong estimate and shaves the stated confidence, so
    /// a shaky report reads as a hedge, not a certainty. `reliability` defaults to fully trusted so
    /// direct callers are unchanged.
    public func recommend(
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        scouting: BatterScoutingSnapshot,
        context: PlateAppearanceContext,
        adaptation: RivalAdaptationSnapshot? = nil,
        reliability: Int = 100,
        gameState: GameStateSnapshot? = nil,
        lastPitch: PitchAnalysisEntry? = nil
    ) -> (primary: CatcherRecommendation, alternative: CatcherRecommendation) {
        let twoStrikes = context.strikes == 2
        let protectZone = context.balls == 3
        let situation = SignSituation(context: context, gameState: gameState, lastPitch: lastPitch)
        let desiredPitch = recommendedPrimaryPitch(pitcher: pitcher, desired: scouting.pitchWeakness)
        let repetitionAvoided = (adaptation?.level ?? 0) >= 500
            && adaptation?.detectedPitch == desiredPitch
        // 라이벌이 패턴을 읽었거나, 상황상 같은 공을 되풀이하면 안 될 때 구종을 바꾼다.
        let mustChangePitch = repetitionAvoided
            || (situation.avoidsRepeat && lastPitch?.pitchType == desiredPitch)
        let primaryPitch = mustChangePitch
            ? recommendedAlternativePitch(
                pitcher: pitcher,
                excluding: desiredPitch,
                legacyDesired: desiredPitch == .fourSeam ? .slider : .fourSeam
            )
            : desiredPitch
        let primaryProfile = pitcher.profile(for: primaryPitch)
        // 약점 코스가 기준점이고, 상황이 그 위에서 한 칸씩 민다. 스카우팅의 가치는 그대로다.
        let primaryZone = situation.shift(scouting.coldZone)
        let primary = CatcherRecommendation(
            call: PitchCall(
                pitchType: primaryPitch,
                zone: primaryZone,
                // 밀린 코스가 한복판이면 "존 끝"은 뜻을 잃는다. 목표 좌표가 한복판 그대로라
                // 포수가 아무것도 요구하지 않는 사인을 내는 셈이었다.
                zoneIntent: ZoneIntent.clamped(
                    situation.zoneIntent(protectZone: protectZone, twoStrikes: twoStrikes),
                    for: primaryZone
                ),
                intensity: situation.demandsControl || protectZone || primaryProfile?.role == .development
                    ? .controlled
                    : .normal
            ),
            confidence: ScoutingEstimate.adjustedConfidence(
                clamp(
                    520
                        + (pitcher.command - 50) * 4
                        + ((primaryProfile?.command ?? 50) - 50) * 2
                        + (batter.discipline < 50 ? 45 : 0),
                    350,
                    850
                ),
                reliability: reliability
            ),
            reasonCodes: [
                repetitionAvoided
                    ? "rival.pattern_detected"
                    : mustChangePitch
                    ? "sequence.avoid_repeat"
                    : primaryPitch == scouting.pitchWeakness
                    ? "scouting.pitch_weakness"
                    : "arsenal.best_available",
                "scouting.cold_zone",
                situation.countCode
            ] + situation.extraReasonCodes
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
                zoneIntent: ZoneIntent.clamped(protectZone ? .strike : .edge, for: alternativeZone),
                intensity: context.fatigue >= 60 ? .controlled : .normal
            ),
            confidence: ScoutingEstimate.adjustedConfidence(
                clamp(430 + (pitcher.stuff - 50) * 3, 300, 760),
                reliability: reliability
            ),
            reasonCodes: [
                "scouting.avoid_hot_zone",
                "sequence.change_speed",
                protectZone ? "count.avoid_walk" : "count.alternative"
            ]
        )
        return (primary, alternative)
    }

    /// 무엇을 던질지 고른다. **타자의 약점과 투수가 실제로 던질 수 있는 공을 저울질한다.**
    ///
    /// 예전에는 약점 구종을 거의 무조건 요구했다 — 개발 중인 구종일 때만 피했다. 그래서
    /// 던질 줄도 모르는 체인지업이 약점이면 계속 체인지업을 요구했고, 포수가 투수를 안 보는
    /// 것처럼 보였다. 실제 포수는 "이 타자가 약한 공"과 "이 투수가 제일 잘 던지는 공" 사이에서
    /// 고른다. 약점을 노리는 값어치를 점수로 매겨 주무기와 비교한다.
    private func recommendedPrimaryPitch(
        pitcher: PitcherSnapshot,
        desired: PitchType
    ) -> PitchType {
        guard let profiles = pitcher.pitchProfiles, !profiles.isEmpty else { return desired }

        /// 약점을 찌를 때 얹어 주는 값. 이만큼 못 미치는 주무기라면 약점을 노린다.
        /// 90은 세 항목 합계(command+whiff+weakContact) 기준이라 항목당 30 차이에 해당한다.
        let weaknessBonus = 90

        func value(_ profile: PitchProfileSnapshot) -> Int {
            var score = profileScore(profile)
            if profile.pitchType == desired { score += weaknessBonus }
            // 아직 만들고 있는 구종은 승부처에서 쓰지 않는다.
            if profile.role == .development { score -= 120 }
            return score
        }

        return profiles.max { value($0) < value($1) }?.pitchType ?? desired
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

    /// 노린 코스에 얼마나 붙었는지를 말로 옮긴다.
    ///
    /// 예전에는 "코스 정확도는 610/1000입니다"라고만 적었다. 610이 좋은 건지 나쁜 건지
    /// 알 방법이 없어서 숫자가 그냥 지나간다. 무엇을 재는 값인지도 이름에 담는다 —
    /// 이건 공이 목표에서 얼마나 벗어났는지이지 구위나 제구 능력치가 아니다.
    static func executionBand(_ quality: Int) -> String {
        switch quality {
        case 850...: "그대로 꽂혔습니다"
        case 700..<850: "거의 붙었습니다"
        case 520..<700: "조금 벗어났습니다"
        case 350..<520: "많이 벗어났습니다"
        default: "손에서 빠졌습니다"
        }
    }

    private enum BatterApproach: String {
        case patient
        case aggressive
        case protect
        case power
    }

    /// How the batter's read of the *game situation* (base/out state, leverage) shifts their
    /// plate approach. Every field is a signed, bounded nudge to a swing or contact tendency —
    /// never to the physical result of a pitch. It is sealed inside the `BatterPlan` and
    /// consumed only through it, so per ADR-005 the situation can change what the batter
    /// *intends*, while the execution and resolution of any given plan stay situation-blind.
    private struct SituationalBias {
        /// Added to the swing chance on pitches inside the zone (+ = attacks strikes).
        let zoneSwingShift: Int
        /// Added to the swing chance on pitches outside the zone (+ = expands / chases).
        let chaseShift: Int
        /// Added to the contact chance once the batter swings (+ = shortens up, fewer whiffs).
        let contactShift: Int
        /// Added to the foul chance on contact (+ = fights pitches off).
        let foulShift: Int
        /// One public, spoiler-free line describing the situational approach, or "" when neutral.
        let note: String
    }

    private struct BatterPlan {
        let expectedPitch: PitchType
        let expectedZone: PitchZone
        let approach: BatterApproach
        let bias: SituationalBias
        let commitment: String
    }

    private let recommendationEngine: CatcherRecommendationEngine
    private let rivalMemoryEngine: RivalMemoryEngine
    private let ballInPlayEngine: BallInPlayEngine
    private let baserunnerEngine: BaserunnerEngine
    private let inningStateEngine: InningStateEngine
    private let gameAnalysisEngine: GameAnalysisEngine

    public init(
        recommendationEngine: CatcherRecommendationEngine = CatcherRecommendationEngine(),
        rivalMemoryEngine: RivalMemoryEngine = RivalMemoryEngine(),
        ballInPlayEngine: BallInPlayEngine = BallInPlayEngine(),
        baserunnerEngine: BaserunnerEngine = BaserunnerEngine(),
        inningStateEngine: InningStateEngine = InningStateEngine(),
        gameAnalysisEngine: GameAnalysisEngine = GameAnalysisEngine()
    ) {
        self.recommendationEngine = recommendationEngine
        self.rivalMemoryEngine = rivalMemoryEngine
        self.ballInPlayEngine = ballInPlayEngine
        self.baserunnerEngine = baserunnerEngine
        self.inningStateEngine = inningStateEngine
        self.gameAnalysisEngine = gameAnalysisEngine
    }

    public func preparePitch(_ params: PreparePitchParams) throws -> PitchPreparation {
        let seed = try validate(params)
        let adaptation = rivalMemoryEngine.analyze(params.rivalMemory, context: params.context)
        let plan = commitBatterPlan(params: params, adaptation: adaptation, seed: seed)
        // The catcher reasons from the *estimated* read (which can miss the truth at low
        // confidence); the batter plan above and every physics/judgment path keep the true report.
        let read = scoutingRead(params: params)
        let recommendations = recommendationEngine.recommend(
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: read.estimate,
            context: params.context,
            adaptation: adaptation,
            reliability: read.reliability,
            gameState: params.gameState,
            lastPitch: params.gameLog?.entries.last
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
            primaryRecommendation: recommendationSnapshot(
                recommendations.primary,
                situationNote: plan.bias.note
            ),
            alternativeRecommendation: recommendationSnapshot(recommendations.alternative),
            rivalAdaptation: adaptation,
            scoutingReport: ScoutingEstimate.report(
                estimate: read.estimate,
                effectiveReliability: read.reliability,
                observationCount: params.rivalMemory?.totalPitchesSeen ?? 0
            )
        )
    }

    /// Effective reliability + estimated read for a preparation, derived only from the true report,
    /// the observation counts and the durable pitcher/batter identity. Shared by `preparePitch` and
    /// `submitPitch` so both agree on the recommendation (and therefore on the preparation token).
    private func scoutingRead(
        params: PreparePitchParams
    ) -> (reliability: Int, estimate: BatterScoutingSnapshot) {
        let reliability = ScoutingEstimate.effectiveReliability(
            baseline: params.scouting.reliability,
            memory: params.rivalMemory
        )
        let estimate = ScoutingEstimate.estimatedScouting(
            truth: params.scouting,
            reliability: reliability,
            matchupSeed: ScoutingEstimate.matchupSeed(
                pitcherID: params.pitcher.id,
                batterID: params.batter.id
            )
        )
        return (reliability, estimate)
    }

    public func submitPitch(_ params: SubmitPitchParams) throws -> PitchKernelResult {
        try submitPitch(params, delivery: nil)
    }

    /// - Parameter delivery: How well the player physically executed the throw. `nil` — the default
    ///   every pre-delivery caller gets — reproduces the previous behaviour exactly, and so does
    ///   `PitchDelivery.neutral`.
    public func submitPitch(
        _ params: SubmitPitchParams,
        delivery: PitchDelivery?
    ) throws -> PitchKernelResult {
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
        try validate(delivery: delivery)
        let adaptation = rivalMemoryEngine.analyze(params.rivalMemory, context: params.context)
        let plan = commitBatterPlan(params: prepareParams, adaptation: adaptation, seed: seed)
        let read = scoutingRead(params: prepareParams)
        let recommendations = recommendationEngine.recommend(
            pitcher: params.pitcher,
            batter: params.batter,
            scouting: read.estimate,
            context: params.context,
            adaptation: adaptation,
            reliability: read.reliability,
            gameState: params.gameState,
            lastPitch: params.gameLog?.entries.last
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

        let execution = executePitch(params: params, delivery: delivery, seed: seed)
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
        let stealResolution = baserunnerEngine.resolveSteal(
            currentGameState.runners,
            defense: currentGameState.defense,
            context: params.context,
            seed: seed
        )
        let inningTransition = inningStateEngine.resolve(
            context: params.context,
            gameState: currentGameState,
            plateAppearanceResult: state.result,
            battedBall: neutralResolution.battedBall,
            fielding: fieldingResolution,
            runners: stealResolution.runnersAfter,
            stealOuts: stealResolution.outsRecorded,
            seed: seed
        )
        let appearanceSessionEnded = state.result != nil || inningTransition.inningEnded
        let baserunnerAdvance = state.result.map {
            baserunnerEngine.advance(
                stealResolution.runnersAfter,
                outcome: outcome,
                plateAppearanceResult: $0,
                defense: currentGameState.defense,
                seed: seed,
                doublePlayCompleted: inningTransition.doublePlayCompleted,
                battedBall: neutralResolution.battedBall,
                fielding: fieldingResolution,
                inningEnded: inningTransition.inningEnded
            )
        }
        let runnersAfterPlay = inningTransition.inningEnded
            ? BaserunnerStateSnapshot.empty
            : baserunnerAdvance?.after ?? stealResolution.runnersAfter
        let updatedGameState = GameStateSnapshot(
            defense: currentGameState.defense,
            park: currentGameState.park,
            runners: runnersAfterPlay,
            runsAllowed: currentGameState.runsAllowed + (baserunnerAdvance?.runsScored ?? 0),
            inningState: inningTransition.after
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
            inning: inningTransition.after.inning,
            outs: inningTransition.after.outs,
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
            baserunnerAdvance: baserunnerAdvance,
            stealAttempt: stealResolution.attempt,
            inningTransition: inningTransition
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
        if let stealAttempt = stealResolution.attempt {
            events.append(
                PitchKernelEvent(
                    eventType: "steal_attempt_resolved",
                    sequence: events.count,
                    stealAttempt: stealAttempt,
                    reasonCodes: [
                        stealAttempt.succeeded ? "steal.success" : "steal.caught",
                        "steal.\(stealAttempt.fromBase)_to_\(stealAttempt.toBase)"
                    ]
                )
            )
        }
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
        if inningTransition.outsRecorded > 0 || inningTransition.inningEnded {
            events.append(
                PitchKernelEvent(
                    eventType: inningTransition.inningEnded
                        ? "half_inning_ended"
                        : "outs_recorded",
                    sequence: events.count,
                    inningTransition: inningTransition,
                    reasonCodes: [
                        "outs.recorded.\(inningTransition.outsRecorded)",
                        inningTransition.doublePlayCompleted
                            ? "defense.double_play"
                            : "defense.standard_out"
                    ]
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
            ended: appearanceSessionEnded,
            result: state.result,
            outcome: outcome,
            selectionQuality: selection,
            recommendationAccepted: recommendationAccepted,
            fatigueAfterPitch: fatigueAfterPitch,
            execution: execution,
            battedBall: neutralResolution.battedBall,
            fieldingResolution: fieldingResolution,
            runnersBefore: currentGameState.runners,
            runnersAfter: updatedGameState.runners,
            runsScored: baserunnerAdvance?.runsScored ?? 0,
            stealAttempt: stealResolution.attempt,
            inningTransition: inningTransition,
            reasonCodes: reasonCodes,
            shortFeedback: feedback.short,
            detailFeedback: feedback.detail,
            accessibilitySummary: "\(feedback.short) \(feedback.detail)"
        )

        let nextPreparation: PitchPreparation?
        if !appearanceSessionEnded {
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

        // A delivery only enters the hash when one was supplied, so pre-delivery callers and the
        // golden fixture keep the exact hash they had before this field existed.
        let deliveryComponent = delivery.map {
            "|delivery:\($0.releaseAccuracy):\($0.aimAccuracy)"
        } ?? ""
        let eventHash = StableHash.fnv1a64(
            [
                params.seed,
                plan.commitment,
                canonical(params.call) + deliveryComponent,
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
        guard (0...100).contains(params.scouting.reliability) else {
            throw SimulationError.invalidScouting("reliability must be between 0 and 100")
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
            if let fielders = gameState.defense.fielders {
                guard fielders.count <= FielderPosition.allCases.count,
                      Set(fielders.map(\.position)).count == fielders.count,
                      fielders.allSatisfy({
                          !$0.id.isEmpty
                              && !$0.name.isEmpty
                              && (20...80).contains($0.range)
                              && (20...80).contains($0.glove)
                              && (20...80).contains($0.arm)
                      }) else {
                    throw SimulationError.invalidGameState("fielder positions or ratings are invalid")
                }
            }
            if let inningState = gameState.inningState {
                guard (1...20).contains(inningState.inning),
                      (0...2).contains(inningState.outs),
                      inningState.inning == params.context.inning,
                      inningState.outs == params.context.outs else {
                    throw SimulationError.invalidGameState("inning state does not match the plate appearance context")
                }
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

    private func validate(delivery: PitchDelivery?) throws {
        guard let delivery else { return }
        guard (0...1_000).contains(delivery.releaseAccuracy),
              (0...1_000).contains(delivery.aimAccuracy) else {
            throw SimulationError.invalidPitchDelivery("release and aim accuracy must be between 0 and 1000")
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
        if let index = pitchWeights.firstIndex(where: { $0.pitchType == adaptation.leanPitch }) {
            pitchWeights[index].weight += adaptation.pitchReadStrength * 2
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
        if adaptation.zoneReadStrength > 0,
           generator.nextInt(upperBound: 100) < min(60, 12 + adaptation.zoneReadStrength / 6) {
            expectedZone = adaptation.leanZone
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
        // The situational read is a pure function of the public state (base/out/leverage/count)
        // and consumes no randomness, so the plan's RNG stream — and every fixture that depends
        // on it — is unchanged; only the sealed swing-tendency nudges below are new.
        let bias = situationalBias(
            context: params.context,
            runners: params.gameState?.runners ?? .empty,
            discipline: params.batter.discipline
        )
        let commitment = StableHash.fnv1a64(
            [
                params.context.plateAppearanceID,
                String(params.context.pitchNumber),
                expectedPitch.rawValue,
                String(expectedZone.row),
                String(expectedZone.column),
                approach.rawValue,
                String(bias.zoneSwingShift),
                String(bias.chaseShift),
                String(bias.contactShift),
                String(bias.foulShift),
                String(generator.next())
            ].joined(separator: "|")
        )
        return BatterPlan(
            expectedPitch: expectedPitch,
            expectedZone: expectedZone,
            approach: approach,
            bias: bias,
            commitment: commitment
        )
    }

    /// Turns the public game situation into bounded swing/contact-tendency shifts. This is the
    /// batter *reading the moment* — attacking with a runner to drive in, working the count in a
    /// low-stakes empty-base spot, and letting the stakes amplify their own discipline. It never
    /// touches pitch physics or result probabilities directly: the shifts flow only through the
    /// sealed plan and are deliberately conservative (Phase 1-2 handles the wider recalibration).
    private func situationalBias(
        context: PlateAppearanceContext,
        runners: BaserunnerStateSnapshot,
        discipline: Int
    ) -> SituationalBias {
        let scoringPosition = runners.secondOccupied || runners.thirdOccupied
        let basesEmpty = runners.occupiedCount == 0
        let driveInRun = scoringPosition && context.outs < 2
        let patientSpot = basesEmpty && context.leverage < 400

        var zoneSwingShift = 0
        var chaseShift = 0
        var contactShift = 0
        var foulShift = 0

        if driveInRun {
            // Runner in scoring position with an out to give: shorten up, put it in play.
            zoneSwingShift += 40
            chaseShift += 20
            contactShift += 25
            foulShift += 35
        }
        if patientSpot {
            // Nobody on and nothing riding on it: make the pitcher work.
            zoneSwingShift -= 30
            chaseShift -= 40
        }
        // Leverage amplifies the batter's *own* discipline (focus), not the outcome: a
        // disciplined hitter chases less as the stakes climb, a free-swinger a touch more.
        // This is exactly zero at league-average discipline (50), so leverage on its own can
        // never move the plan — the guarantee the ADR-005 execution/resolution tests rely on.
        let leverageOverNeutral = max(0, context.leverage - 500)
        chaseShift -= (discipline - 50) * leverageOverNeutral / 250

        let note: String
        if driveInRun {
            note = "득점권이라 타자가 컨택 위주로 적극적입니다."
        } else if patientSpot {
            note = "주자가 없어 타자가 공을 신중히 고릅니다."
        } else if context.leverage >= 750 {
            note = "중요한 승부라 타자의 집중력이 올라갑니다."
        } else {
            note = ""
        }

        return SituationalBias(
            zoneSwingShift: zoneSwingShift,
            chaseShift: chaseShift,
            contactShift: contactShift,
            foulShift: foulShift,
            note: note
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

    private func executePitch(
        params: SubmitPitchParams,
        delivery: PitchDelivery?,
        seed: UInt64
    ) -> PitchExecution {
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
        // Player delivery. Applied *after* every RNG draw above as pure arithmetic, so no existing
        // path changes its generator consumption, and a neutral (or absent) delivery is the exact
        // identity — `offset * 1_000 / 1_000 == offset`, `+ 0` on quality and velocity. That keeps
        // the golden fixture and every pre-delivery caller byte-identical (see the determinism
        // rules in docs/IOS_TOP_TIER_PLAN.md §3.2).
        let aimShift = (delivery?.aimAccuracy ?? 500) - 500
        let releaseShift = (delivery?.releaseAccuracy ?? 500) - 500
        // Steady aim pulls the miss back toward the target by up to 24%; a shaky one pushes it out.
        let aimScalePermille = 1_000 - aimShift * 240 / 500
        offsetX = offsetX * aimScalePermille / 1_000
        offsetY = offsetY * aimScalePermille / 1_000
        // A clean release is worth ±120 of execution quality — deliberately smaller than the spread
        // that command ratings produce, so timing sharpens ability instead of replacing it.
        let releaseQualityBonus = releaseShift * 120 / 500
        let executionQuality = clamp(
            1_000 - abs(offsetX) - abs(offsetY) + effectiveCommand / 5 + releaseQualityBonus,
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
            // ±1.0 km/h from the release. Small, but it is the number the player watches after a
            // delivery they felt good about. Zero at neutral.
            + releaseShift * 10 / 500
        let movementScale = (profile?.movement ?? params.pitcher.movement) - 50
        let actualX = target.x + offsetX
        let actualY = target.y + offsetY
        let horizontalMovement = horizontalBreak + movementScale * 2
        let verticalMovement = verticalBreak + movementScale * 2
        // A baseball loses roughly 8–10% of its speed over the 18.44 m trip.
        // Quadratic drag has the closed-form distance x = ln(1 + k v0 t) / k;
        // using a baseball-sized drag constant gives us a physically timed replay
        // without changing the pitch-resolution inputs.
        let releaseSpeedMetersPerSecond = Double(velocity) / 36.0
        let dragPerMeter = 0.0053
        let flightSeconds = (exp(dragPerMeter * 18.44) - 1.0)
            / (dragPerMeter * releaseSpeedMetersPerSecond)
        let flightTimeMilliseconds = max(330, min(620, Int((flightSeconds * 1_000.0).rounded())))
        let plateLateralTenthsCM = Double(actualX) * 432.0 / 500.0
        let plateHeightTenthsCM = 750.0 + Double(actualY) * 250.0 / 500.0
        let durationSeconds = Double(flightTimeMilliseconds) / 1_000.0
        let horizontalBreakMeters = Double(horizontalMovement) / 1_000.0
        let verticalBreakMeters = Double(verticalMovement) / 1_000.0
        let plateLateralMeters = plateLateralTenthsCM / 1_000.0
        let plateHeightMeters = plateHeightTenthsCM / 1_000.0
        let noSpinPlateLateral = plateLateralMeters - horizontalBreakMeters
        let noSpinPlateHeight = plateHeightMeters - verticalBreakMeters
        let initialLateralVelocity = noSpinPlateLateral / durationSeconds
        let initialVerticalVelocity = (
            noSpinPlateHeight - 1.85 + 0.5 * 9.81 * durationSeconds * durationSeconds
        ) / durationSeconds
        let trajectorySeries = (0...24).flatMap { index -> [Int] in
            let timeProgress = Double(index) / 24.0
            let elapsedSeconds = durationSeconds * timeProgress
            let travelledProgress = log(1.0 + dragPerMeter * releaseSpeedMetersPerSecond * elapsedSeconds)
                / (dragPerMeter * 18.44)
            // Magnus displacement accumulates with t². This preserves the same
            // resolved plate location while producing the late separation that
            // distinguishes a slider from a four-seam fastball.
            let magnusProgress = timeProgress * timeProgress
            let lateralMeters = initialLateralVelocity * elapsedSeconds
                + horizontalBreakMeters * magnusProgress
            let heightMeters = 1.85
                + initialVerticalVelocity * elapsedSeconds
                - 0.5 * 9.81 * elapsedSeconds * elapsedSeconds
                + verticalBreakMeters * magnusProgress
            return [
                flightTimeMilliseconds * index / 24,
                Int((lateralMeters * 1_000.0).rounded()),
                Int((18_440.0 * (1.0 - travelledProgress)).rounded()),
                Int((heightMeters * 1_000.0).rounded())
            ]
        }
        let controlSampleOffset = 15 * 4
        let trajectoryControlX = Int((
            Double(trajectorySeries[controlSampleOffset + 1]) * 500.0 / 432.0
        ).rounded())
        let controlHeightTenthsCM = Double(trajectorySeries[controlSampleOffset + 3])
        let trajectoryControlY = Int((
            (controlHeightTenthsCM - 750.0) * 500.0 / 250.0
        ).rounded())
        return PitchExecution(
            targetX: target.x,
            targetY: target.y,
            actualX: actualX,
            actualY: actualY,
            velocityTenthsKPH: velocity,
            horizontalBreakTenthsCM: horizontalMovement,
            verticalBreakTenthsCM: verticalMovement,
            executionQuality: executionQuality,
            flightTimeMilliseconds: flightTimeMilliseconds,
            trajectoryControlX: trajectoryControlX,
            trajectoryControlY: trajectoryControlY,
            trajectorySeries: trajectorySeries
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
        let cappedAdaptation = min(RivalMemoryEngine.resolveDamageCap, adaptation.level)
        let patternRecognitionBonus = (pitchMatched ? cappedAdaptation / 6 : 0)
            + (zoneMatched ? cappedAdaptation / 10 : 0)
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
        let situationalSwingShift = wasInZone
            ? plan.bias.zoneSwingShift
            : plan.bias.chaseShift
        let swingChance = clamp(
            (wasInZone ? 640 : 110)
                + params.scouting.chaseTendency * (wasInZone ? 1 : 4)
                - params.batter.discipline * 2
                + recognitionBonus
                + approachSwingBonus
                + situationalSwingShift,
            25,
            960
        )
        let batterSwung = generator.nextInt(upperBound: 1_000) < swingChance
        if !batterSwung {
            if !wasInZone,
               let hitByPitch = hitByPitchOutcome(
                   call: params.call,
                   execution: execution,
                   pitcherHand: params.pitcher.throwingHand,
                   batSide: params.batter.batSide,
                   generator: &generator
               ) {
                return (hitByPitch, nil)
            }
            return (wasInZone ? .calledStrike : .ball, nil)
        }

        let profile = params.pitcher.profile(for: params.call.pitchType)
        let ratingDifficulty: Int
        if let profile {
            ratingDifficulty = (params.pitcher.stuff - 50) * 2
                + (profile.whiff - 50) * 3
                + (profile.movement - 50) * 2
                + max(0, execution.executionQuality - 500) / 2
        } else {
            ratingDifficulty = (params.pitcher.stuff - 50) * 6
                + (params.pitcher.movement - 50) * 5
                + max(0, execution.executionQuality - 500) / 2
        }
        let velocityEdge = clamp((execution.velocityTenthsKPH - 1_370) / 4, -45, 70)
        let pitchDifficulty = ratingDifficulty + velocityEdge
        let platoonContact = platoonContactBonus(
            pitcherHand: params.pitcher.throwingHand,
            batSide: params.batter.batSide,
            pitchType: params.call.pitchType
        )
        let contactChance = clamp(
            720
                + (params.batter.contact - 50) * 6
                + (pitchMatched ? 90 : -70)
                + (zoneMatched ? 50 : -35)
                + (pitchMatched ? cappedAdaptation / 5 : 0)
                + plan.bias.contactShift
                + platoonContact
                - pitchDifficulty,
            120,
            940
        )
        guard generator.nextInt(upperBound: 1_000) < contactChance else {
            return (.swingingStrike, nil)
        }

        let foulChance = clamp(
            470 + ((profile?.movement ?? params.pitcher.movement) - params.batter.contact) * 3
                + plan.bias.foulShift,
            260,
            620
        )
        if generator.nextInt(upperBound: 1_000) < foulChance {
            return (.foul, nil)
        }

        let contactQuality = clamp(
            430
                + (params.batter.power - 50) * 3
                + (params.batter.contact - 50) * 2
                + (pitchMatched ? 90 : -70)
                + (zoneMatched ? 45 : -35)
                + (pitchMatched ? cappedAdaptation / 8 : 0)
                - ((profile?.weakContact ?? 50) - 50) * 2
                - max(0, execution.executionQuality - 500) / 3
                + generator.nextInt(upperBound: 301) - 150,
            0,
            1_000
        )
        let exitVelocity = clamp(
            1_000
                + contactQuality * 3 / 4
                + (params.batter.power - 50) * 6
                + generator.nextInt(upperBound: 181) - 90,
            700,
            1_900
        )
        let launchAngle = clamp(
            -100 + generator.nextInt(upperBound: 521) + (contactQuality - 450) / 8,
            -150,
            520
        )
        let battedQuality = Self.battedQuality(
            exitVelocity: exitVelocity,
            launchAngle: launchAngle
        )
        let battedBall = BattedBall(
            exitVelocityTenthsKPH: exitVelocity,
            launchAngleTenthsDegrees: launchAngle,
            directionTenthsDegrees: -450 + generator.nextInt(upperBound: 901),
            contactQuality: battedQuality
        )
        // 수비 판정 전의 중립 결과. 최종 결과는 `FieldingResolver`가 같은 표로 다시 정한다.
        return (BattedBallBands.outcome(for: battedQuality), battedBall)
    }

    /// How far past the inside edge (toward the batter) an unswung pitch must miss to threaten the
    /// hands, and the per-candidate chance it actually plunks the batter. Tuned so a hit-by-pitch
    /// lands near the real ~1% of plate appearances; see `tools/check-balance.mjs`.
    static let hitByPitchInsideThreshold = 1_000
    static let hitByPitchBaseChance = 120
    static let hitByPitchInsideCallBonus = 60

    /// Whether the batter effectively stands in the left-handed box against this pitcher. A switch
    /// hitter always takes the platoon-favored side (opposite the pitcher's throwing hand).
    private func batsLeftEffectively(batSide: BatSide, pitcherHand: ThrowingHand) -> Bool {
        switch batSide {
        case .left: return true
        case .right: return false
        case .switchHitter: return pitcherHand == .right
        }
    }

    /// The platoon read: a bounded, RNG-free additive nudge to the batter's contact chance. It is
    /// exactly zero in a same-hand matchup — so every same-hand fixture, including the decode-default
    /// RHP-vs-RHB one, resolves byte-for-byte as before — and gives the opposite-hand batter a small
    /// contact edge that is largest on breaking balls and smallest on the changeup (the pitch that
    /// itself thrives against opposite-handed hitters). The batter's opposite-hand edge is the exact
    /// mirror of the pitcher's same-hand breaking-ball whiff edge (ADR-005: it shifts a tendency,
    /// never the physics or a drawn result).
    private func platoonContactBonus(
        pitcherHand: ThrowingHand,
        batSide: BatSide,
        pitchType: PitchType
    ) -> Int {
        let batsLeft = batsLeftEffectively(batSide: batSide, pitcherHand: pitcherHand)
        let sameHand = batsLeft == (pitcherHand == .left)
        guard !sameHand else { return 0 }
        switch pitchType {
        case .slider, .curveball: return 42
        case .fourSeam: return 24
        case .changeup: return 14
        }
    }

    /// A pitch the batter doesn't swing at that sails far enough into their own side of the plate to
    /// hit them. Only ever reached from the no-swing / out-of-zone branch (the pitch was already a
    /// ball), and it draws from the local generator only once the location is a genuine inside miss,
    /// so it can never perturb another pitch's stream and leaves every non-inside ball unchanged.
    private func hitByPitchOutcome(
        call: PitchCall,
        execution: PitchExecution,
        pitcherHand: ThrowingHand,
        batSide: BatSide,
        generator: inout SplitMix64
    ) -> PitchOutcome? {
        let batsLeft = batsLeftEffectively(batSide: batSide, pitcherHand: pitcherHand)
        // Inside is the batter's own side of the plate: positive X for a lefty, negative for a righty.
        let insideMiss = batsLeft ? execution.actualX : -execution.actualX
        guard insideMiss >= Self.hitByPitchInsideThreshold else { return nil }
        // Working the inside corner on purpose is the risk/reward: a called inside location lifts it.
        let calledInside = batsLeft ? (call.zone.column == 2) : (call.zone.column == 0)
        let chance = Self.hitByPitchBaseChance + (calledInside ? Self.hitByPitchInsideCallBonus : 0)
        return generator.nextInt(upperBound: 1_000) < chance ? .hitByPitch : nil
    }

    /// 타구 결과 해석용 품질 스칼라. 결과의 원인은 (EV, LA)이며 이 값은 그 요약이다.
    /// 배럴(EV 154km/h 이상 & LA 17~34도)만 홈런 밴드에 도달할 수 있고,
    /// 담장 경계는 구장 팩터·수비 보정이 GameSituation에서 최종 결정한다.
    static func battedQuality(exitVelocity: Int, launchAngle: Int) -> Int {
        let laFit: Int
        if launchAngle < 90 {
            laFit = 30 + max(0, launchAngle + 150) / 5
        } else {
            let lineFit = 240 - abs(launchAngle - 170) * 7 / 10
            let popPenalty = launchAngle > 340 ? launchAngle - 340 : 0
            laFit = max(0, lineFit - popPenalty)
        }
        let rawBase = exitVelocity * 7 / 10 + laFit - 600
        let base = max(0, min(758, rawBase))
        let isBarrel = exitVelocity >= 1_470 && (170...340).contains(launchAngle)
        guard isBarrel else { return base }
        let barrelQuality = 765 + (exitVelocity - 1_470) / 3 + (90 - abs(launchAngle - 250)) / 3
        return max(700, min(940, barrelQuality))
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
        case .single, .double, .triple, .homeRun:
            return (context.balls, context.strikes, .hit)
        case .hitByPitch:
            // A hit-by-pitch reaches base and forces runners exactly like a walk, so it shares the
            // coarse `.walk` plate-appearance bucket (which keeps `PlateAppearanceResult` — and the
            // front-end union that mirrors it — unchanged). The `.hitByPitch` outcome above is what
            // distinguishes it for feedback, scoring records, and CLI aggregation.
            return (context.balls, context.strikes, .walk)
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
        _ recommendation: CatcherRecommendation,
        situationNote: String = ""
    ) -> CatcherRecommendationSnapshot {
        let pitchName = pitchDisplayName(recommendation.call.pitchType)
        let zoneName = zoneDisplayName(recommendation.call.zone)
        let intent: String
        switch recommendation.call.zoneIntent {
        case .strike: intent = "존 안"
        case .edge: intent = "존 끝"
        case .chase: intent = "존 밖 유인"
        }
        let baseReason: String
        if recommendation.reasonCodes.contains("rival.pattern_detected") {
            baseReason = "라이벌이 반복 구종을 읽고 있어 \(zoneName) \(pitchName)으로 패턴을 바꿉니다."
        } else if recommendation.reasonCodes.contains("sequence.avoid_repeat") {
            baseReason = "방금 그 공에 타이밍이 맞았습니다. \(zoneName) \(pitchName)으로 바꿉니다."
        } else if recommendation.reasonCodes.contains("scouting.pitch_weakness") {
            baseReason = "타자의 약점인 \(zoneName) \(pitchName)\(pitchObjectParticle(recommendation.call.pitchType)) \(intent)로 공략합니다."
        } else {
            baseReason = "강한 코스를 피해 \(zoneName) \(pitchName)으로 타이밍을 바꿉니다."
        }
        // 왜 지금 이 코스인지. 카운트와 주자는 사인의 절반을 결정하는데, 예전에는 화면에
        // 한 글자도 나오지 않아서 포수가 늘 같은 곳을 부르는 것처럼 보였다.
        let situationReason: String? = if recommendation.reasonCodes.contains("count.avoid_walk") {
            "볼넷을 줄 수 없어 존 안으로 넣습니다."
        } else if recommendation.reasonCodes.contains("count.pitcher_behind") {
            "카운트가 몰려 유인보다 스트라이크가 먼저입니다."
        } else if recommendation.reasonCodes.contains("count.pitcher_ahead") {
            "여유가 있으니 존 밖으로 빼서 헛스윙을 노립니다."
        } else if recommendation.reasonCodes.contains("count.first_pitch") {
            "초구 스트라이크를 선점합니다."
        } else {
            nil
        }
        let runnerReason: String? = if recommendation.reasonCodes.contains("runners.double_play_setup") {
            "1루 주자가 있어 낮게 던져 병살을 노립니다."
        } else if recommendation.reasonCodes.contains("runners.suppress_sacrifice_fly") {
            "3루 주자가 있어 뜬공이 나올 높은 공을 피합니다."
        } else {
            nil
        }
        // The situational note is derived only from the public base/out/leverage state, so it
        // reads the moment without leaking the batter's sealed pitch/zone guess.
        let shortReason = [baseReason, situationReason, runnerReason, situationNote.isEmpty ? nil : situationNote]
            .compactMap { $0 }
            .joined(separator: " ")
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
        baserunnerAdvance: BaserunnerAdvanceSnapshot?,
        stealAttempt: StealAttemptSnapshot?,
        inningTransition: InningTransitionSnapshot
    ) -> (short: String, detail: String) {
        var short: String
        switch outcome {
        case .ball: short = "타자가 골라내 볼이 됐습니다."
        case .calledStrike: short = "심판이 스트라이크를 선언했습니다."
        case .swingingStrike: short = "타자의 배트를 끌어내 헛스윙을 만들었습니다."
        case .foul: short = "타자가 걷어내 파울이 됐습니다."
        case .inPlayOut: short = "약한 타구를 유도해 아웃을 만들었습니다."
        case .single: short = "타구가 수비 사이를 빠져나가 단타가 됐습니다."
        case .double: short = "강한 타구가 외야를 갈라 2루타가 됐습니다."
        case .triple: short = "타구가 외야 구석을 완전히 갈라 3루타가 됐습니다."
        case .homeRun: short = "정타를 허용해 홈런이 됐습니다."
        case .hitByPitch: short = "몸에 맞는 공으로 타자가 걸어 나갔습니다."
        }
        // An out that still plates a runner is a sacrifice fly — a deep fly the runner tags up on.
        if outcome == .inPlayOut, (baserunnerAdvance?.runsScored ?? 0) > 0 {
            short = "깊은 희생플라이로 3루 주자가 홈을 밟았습니다."
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
        let stealText = stealAttempt.map { " \($0.shortExplanation)" } ?? ""
        let inningText = inningTransition.outsRecorded > 0
            ? " \(inningTransition.shortExplanation)"
            : ""
        // 밴드 문구만 쓴다. 원시 수치(700/1000)는 내부 단위라 사용자 화면에 새면 안 된다 —
        // 실제로 스토어 스크린샷에 "(1000/1000)"이 찍혀 나간 적이 있다.
        let detail = "공 선택은 \(selectionDisplayName(selection)), 노린 코스에는 \(Self.executionBand(execution.executionQuality)). \(planText).\(adaptationText)\(contactText)\(fieldingText)\(stealText)\(runnerText)\(inningText)"
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
        let fielders = state.defense.fielders?
            .sorted { $0.position.rawValue < $1.position.rawValue }
            .map {
                [
                    $0.id,
                    $0.position.rawValue,
                    String($0.range),
                    String($0.glove),
                    String($0.arm)
                ].joined(separator: ":")
            }
            .joined(separator: ",") ?? "aggregate-defense"
        let inning = state.inningState.map {
            "\($0.inning):\($0.half.rawValue):\($0.outs)"
        } ?? "context-inning"
        return [
            String(state.defense.infield),
            String(state.defense.outfield),
            String(state.defense.arm),
            fielders,
            state.park.id,
            String(state.park.hitFactor),
            String(state.park.homeRunFactor),
            state.runners.firstOccupied ? "1" : "0",
            state.runners.secondOccupied ? "1" : "0",
            state.runners.thirdOccupied ? "1" : "0",
            String(state.runners.leadRunnerSpeed),
            String(state.runsAllowed),
            inning
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
