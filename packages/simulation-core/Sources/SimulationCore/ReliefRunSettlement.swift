import Foundation

/// Finish the half-inning the departing pitcher left behind.
///
/// A pitcher who walks off with runners on second and third has not finished being answerable for
/// them. Whether those two score is decided by a reliever the player never controls, and simply
/// stranding them (or scoring them all) would let a pitcher's earned-run average be set by where
/// their outing happened to be cut off rather than by how they pitched.
///
/// So the inning is played out with a league-average reliever, and only one question is asked of
/// it: did the runners *already on base* come home? Everything the replacement does on their own
/// account — their outs, their hits, their walks, the runners they put on — is stripped back out.
/// The departing pitcher inherits none of it.
func settleReliefRuns(
    engine: PitchKernelEngine,
    game: GameStateSnapshot,
    ledger: PitchRunLedger,
    seed: String
) -> PitchRunLedger {
    guard ledger.bases.contains(where: { $0 > 0 }), game.runners.occupiedCount > 0 else {
        return ledger
    }
    var state = game
    var scoring = ledger
    var nextSeed = seed
    var turn = 1
    var context = PlateAppearanceContext(
        plateAppearanceID: "relief:outing-v2",
        revision: 0,
        inning: game.inningState?.inning ?? 1,
        outs: game.inningState?.outs ?? 0,
        balls: 0,
        strikes: 0,
        pitchNumber: 1,
        scoreDifferential: 0,
        leverage: 500,
        fatigue: 10
    )
    let replacement = PitcherSnapshot(
        id: "relief", name: "구원 투수", stuff: 55, command: 55, movement: 55, stamina: 55
    )
    let scouting = BatterScoutingSnapshot(
        hotZone: PitchZone(row: 1, column: 1),
        coldZone: PitchZone(row: 2, column: 0),
        pitchStrength: .fourSeam,
        pitchWeakness: .slider,
        chaseTendency: 45
    )
    // 한 이닝이 240타석 가도록 끝나지 않는 일은 없다. 그래도 상한을 두는 이유는 커널이
    // 예상 밖의 상태를 돌려줄 때 무한히 도는 대신 지금까지의 원장을 돌려주기 위해서다.
    for _ in 0..<240 {
        let batter = ProfessionalLineup.batter(teamKey: "relief-\(seed)", turn: turn)
        guard let prepared = try? engine.preparePitch(PreparePitchParams(
            seed: nextSeed, pitcher: replacement, batter: batter, scouting: scouting,
            context: context, rivalMemory: nil, gameState: state, gameLog: nil
        )) else { return scoring }
        guard let submitted = try? engine.submitPitch(SubmitPitchParams(
            seed: nextSeed, pitcher: replacement, batter: batter, scouting: scouting,
            context: context, preparationToken: prepared.preparationToken,
            call: prepared.primaryRecommendation.call,
            rivalMemory: nil, gameState: state, gameLog: nil
        )) else { return scoring }
        let snapshot = submitted.snapshot
        let before = scoring
        guard let advanced = try? scoring.advance(snapshot) else { return scoring }
        scoring = advanced
        // Whoever the replacement put on belongs to the replacement. A home run also drives the
        // batter themselves in, so that one run comes back off the departing pitcher's line;
        // anyone else who is now standing on a base is reassigned to the reliever.
        if snapshot.result == .hit || snapshot.result == .walk || snapshot.result == .reachedOnError {
            if snapshot.outcome == .homeRun {
                scoring = PitchRunLedger(
                    bases: scoring.bases,
                    runs: scoring.runs - 1,
                    earnedRuns: scoring.earnedRuns - (scoring.earnedRuns > before.earnedRuns ? 1 : 0),
                    inheritedScored: scoring.inheritedScored,
                    virtualOuts: scoring.virtualOuts
                )
            } else {
                let base: Int
                switch snapshot.outcome {
                case .double: base = 1
                case .triple: base = 2
                default: base = 0
                }
                scoring = PitchRunLedger(
                    bases: scoring.bases.enumerated().map { index, owner in
                        index == base && owner > 0 ? (owner == 2 ? -2 : -1) : owner
                    },
                    runs: scoring.runs,
                    earnedRuns: scoring.earnedRuns,
                    inheritedScored: scoring.inheritedScored,
                    virtualOuts: scoring.virtualOuts
                )
            }
        }
        // "Inherited" now counts the replacement's own runners as well. The departing pitcher's
        // entry-time count is the one that means anything, so it is restored each time.
        scoring = PitchRunLedger(
            bases: scoring.bases,
            runs: scoring.runs,
            earnedRuns: scoring.earnedRuns,
            inheritedScored: before.inheritedScored,
            virtualOuts: scoring.virtualOuts
        )
        let inningEnded = snapshot.inningTransition?.inningEnded ?? false
        if inningEnded || !scoring.bases.contains(where: { $0 > 0 }) {
            return scoring
        }
        state = submitted.gameState
        nextSeed = submitted.nextSeed
        if snapshot.ended { turn += 1 }
        context = PlateAppearanceContext(
            plateAppearanceID: context.plateAppearanceID,
            revision: submitted.revision,
            inning: context.inning,
            outs: state.inningState?.outs ?? context.outs,
            balls: snapshot.ended ? 0 : snapshot.balls,
            strikes: snapshot.ended ? 0 : snapshot.strikes,
            pitchNumber: snapshot.ended ? 1 : context.pitchNumber + 1,
            scoreDifferential: context.scoreDifferential,
            leverage: context.leverage,
            fatigue: snapshot.fatigueAfterPitch
        )
    }
    return scoring
}
