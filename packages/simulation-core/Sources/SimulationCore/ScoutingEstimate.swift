import Foundation

/// Turns a *true* batter scouting report into the **estimated** view the catcher reasons from
/// and the UI displays. The estimate is a hypothesis that can miss the truth when confidence is
/// low and sharpens toward it as the pitcher observes the batter. Physics, the batter's plan and
/// `selectionQuality` never see the estimate — they always use the true report — so per ADR-005
/// low reliability changes only *what is shown and recommended*, never the resolved result.
///
/// Everything here is a deterministic, integer-only function of the true report, the effective
/// reliability and a per-matchup seed derived from the pitcher/batter identity (never the pitch
/// seed), which is what keeps `preparePitch`/`submitPitch` in agreement and keeps the catcher
/// blind to the hidden per-pitch plan.
public enum ScoutingEstimate {
    /// At or above this confidence the report is the unvarnished truth and the catcher's
    /// recommendation carries no reliability penalty. Also the decode/`init` default, so every
    /// pre-existing caller and save (which never set a reliability) behaves exactly as before.
    public static let trustedReliability = 60

    /// Confidence a scouting report gains per pitch already thrown to this batter…
    static let observationPitchGain = 5
    /// …and per completed plate appearance against them (a full look is worth several pitches).
    static let observationRematchGain = 12
    /// Ceiling on the observation-driven gain (baseline alone still decides where it starts).
    static let observationBonusCap = 100
    /// Catcher-confidence lost per reliability point below `trustedReliability`.
    static let confidencePenaltyPerPoint = 6
    /// Floor the reliability penalty cannot push a recommendation's confidence below.
    static let confidenceFloor = 180
    /// Width (in rating points) of the chase-tendency uncertainty band at zero reliability.
    static let chaseUncertaintyScale = 12
    /// Reliability at/above which the report is shown as a firming read rather than a guess.
    static let developingReliability = 40

    /// Effective reliability = difficulty baseline lifted by how much the pitcher has already
    /// seen this batter. Deterministic and monotonic in the observation counts, so a report can
    /// only sharpen with more looks, never blur.
    public static func effectiveReliability(baseline: Int, memory: RivalMemorySnapshot?) -> Int {
        let pitchesSeen = memory?.totalPitchesSeen ?? 0
        let rematches = memory?.plateAppearancesSeen ?? 0
        let bonus = min(
            observationBonusCap,
            pitchesSeen * observationPitchGain + rematches * observationRematchGain
        )
        return clamp(baseline + bonus, 0, 100)
    }

    /// How much to shave off a catcher recommendation's confidence for an unreliable read.
    public static func confidencePenalty(reliability: Int) -> Int {
        max(0, trustedReliability - reliability) * confidencePenaltyPerPoint
    }

    /// Applies the reliability penalty to a raw confidence, never below the floor or above the raw.
    public static func adjustedConfidence(_ raw: Int, reliability: Int) -> Int {
        min(raw, max(confidenceFloor, raw - confidencePenalty(reliability: reliability)))
    }

    /// Stable per-matchup seed. Derived only from durable identity — never the per-pitch seed —
    /// so the estimate (and the recommendation built from it) cannot leak the hidden plan.
    public static func matchupSeed(pitcherID: String, batterID: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in "\(pitcherID)|\(batterID)|scouting".utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// The estimated report the catcher reasons from. At/above `trustedReliability` it is exactly
    /// the truth (so the whole feature is a no-op at full confidence); below it, individual facts
    /// stay decoyed until reliability crosses each fact's own reveal threshold, and the chase read
    /// interpolates toward the truth — a monotonic convergence as observations accumulate.
    public static func estimatedScouting(
        truth: BatterScoutingSnapshot,
        reliability: Int,
        matchupSeed: UInt64
    ) -> BatterScoutingSnapshot {
        guard reliability < trustedReliability else { return truth }
        var generator = SplitMix64(seed: matchupSeed)

        // Per-fact reveal thresholds, all strictly below `trustedReliability` so the guard above
        // remains the single source of the "== truth" guarantee.
        let weaknessThreshold = 30 + generator.nextInt(upperBound: 29) // 30...58
        let coldZoneThreshold = 24 + generator.nextInt(upperBound: 35) // 24...58
        let hotZoneThreshold = 24 + generator.nextInt(upperBound: 35)  // 24...58

        let decoyWeakness = pitchDecoy(excluding: truth.pitchWeakness, generator: &generator)
        let decoyColdZone = zoneDecoy(of: truth.coldZone, generator: &generator)
        let decoyHotZone = zoneDecoy(of: truth.hotZone, generator: &generator)
        let chaseMagnitude = 6 + generator.nextInt(upperBound: 9) // 6...14
        let chaseOffset = generator.nextInt(upperBound: 2) == 0 ? -chaseMagnitude : chaseMagnitude

        let estimatedWeakness = reliability >= weaknessThreshold ? truth.pitchWeakness : decoyWeakness
        let estimatedColdZone = reliability >= coldZoneThreshold ? truth.coldZone : decoyColdZone
        let estimatedHotZone = reliability >= hotZoneThreshold ? truth.hotZone : decoyHotZone
        let gap = max(0, trustedReliability - reliability)
        let estimatedChase = clamp(
            truth.chaseTendency + chaseOffset * gap / trustedReliability,
            20,
            80
        )

        return BatterScoutingSnapshot(
            hotZone: estimatedHotZone,
            coldZone: estimatedColdZone,
            pitchStrength: truth.pitchStrength,
            pitchWeakness: estimatedWeakness,
            chaseTendency: estimatedChase,
            reliability: reliability
        )
    }

    /// The player-facing summary of the read: the effective confidence, how much has been seen,
    /// and the current (estimated) hypothesis with an uncertainty band that closes to zero once
    /// the report is trusted.
    public static func report(
        estimate: BatterScoutingSnapshot,
        effectiveReliability: Int,
        observationCount: Int
    ) -> ScoutingReportSnapshot {
        let band: String
        if effectiveReliability >= trustedReliability {
            band = "trusted"
        } else if effectiveReliability >= developingReliability {
            band = "developing"
        } else {
            band = "low"
        }
        let margin = max(0, trustedReliability - effectiveReliability) * chaseUncertaintyScale / trustedReliability
        return ScoutingReportSnapshot(
            reliability: effectiveReliability,
            observationCount: observationCount,
            band: band,
            estimatedWeakness: estimate.pitchWeakness,
            estimatedColdZone: estimate.coldZone,
            estimatedStrength: estimate.pitchStrength,
            estimatedHotZone: estimate.hotZone,
            estimatedChaseTendency: estimate.chaseTendency,
            chaseTendencyMargin: margin
        )
    }

    private static func pitchDecoy(
        excluding truth: PitchType,
        generator: inout SplitMix64
    ) -> PitchType {
        let options = PitchType.allCases.filter { $0 != truth }
        return options[generator.nextInt(upperBound: options.count)]
    }

    private static func zoneDecoy(
        of truth: PitchZone,
        generator: inout SplitMix64
    ) -> PitchZone {
        var candidates: [PitchZone] = []
        for deltaRow in -1...1 {
            for deltaColumn in -1...1 where !(deltaRow == 0 && deltaColumn == 0) {
                let row = truth.row + deltaRow
                let column = truth.column + deltaColumn
                if (0...2).contains(row), (0...2).contains(column) {
                    candidates.append(PitchZone(row: row, column: column))
                }
            }
        }
        return candidates[generator.nextInt(upperBound: candidates.count)]
    }

    private static func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
