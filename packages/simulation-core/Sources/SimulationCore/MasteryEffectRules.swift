import Foundation

/// Shared, fixed-point mastery math.  Storage remains on the validated 20–80 contract; these
/// helpers are used only while calculating a pitch or a fatigue forecast.
public enum MasteryEffectRules {
    public static let maximumBonusPermille = 120

    /// Diminishing-return mastery bonus: 120 * level / (level + 24), in permille.
    public static func bonusPermille(level: Int) -> Int {
        guard level > 0 else { return 0 }
        let safeLevel = min(Int64(AbilityMasterySnapshot.technicalMaximum), Int64(level))
        let numerator = Int64(maximumBonusPermille) * safeLevel
        let denominator = safeLevel + 24
        return Int(min(Int64(maximumBonusPermille), numerator / denominator))
    }

    /// Fixed-point rounding for a positive contribution.  Negative or zero contributions are not
    /// amplified: mastery should improve the part of an ability formula it owns, never turn a
    /// weakness into a second penalty.
    public static func bonusForContribution(_ contribution: Int, level: Int) -> Int {
        guard contribution > 0 else { return 0 }
        let bonus = Int64(bonusPermille(level: level))
        let safeContribution = min(Int64(AbilityMasterySnapshot.technicalMaximum), Int64(contribution))
        let product = safeContribution * bonus
        return Int((product + 500) / 1_000)
    }

    public static func adjustedContribution(_ contribution: Int, level: Int) -> Int {
        contribution + bonusForContribution(contribution, level: level)
    }

    /// Applies mastery to a bounded ability contribution without allowing an intermediate integer
    /// overflow.  The result is intentionally not persisted as a pitcher rating.
    public static func adjustedRating(_ rating: Int, level: Int) -> Int {
        guard rating > 0 else { return rating }
        let bonus = Int64(bonusPermille(level: level))
        let product = Int64(rating) * bonus
        let delta = (product + 500) / 1_000
        let value = Int64(rating) + delta
        return Int(min(Int64(Int.max), max(Int64(Int.min), value)))
    }

    public static func displayName(for ability: TalentAbility) -> String {
        switch ability {
        case .stuff: "강속구 숙련"
        case .command: "코스 숙련"
        case .movement: "결정구 숙련"
        case .stamina: "이닝 숙련"
        }
    }

    /// The milestone levels get special UI treatment; all other levels stay a compact result row.
    public static func isMilestone(_ level: Int) -> Bool {
        level == 1 || level == 5 || level == 10 || (level >= 20 && level % 10 == 0)
    }

    public static func milestoneLabel(_ level: Int) -> String? {
        isMilestone(level) ? "Lv.\(level)" : nil
    }

    public static func levelBand(_ level: Int) -> String {
        switch level {
        case ...0: "none"
        case 1...4: "1_4"
        case 5...9: "5_9"
        case 10...24: "10_24"
        case 25...49: "25_49"
        case 50...99: "50_99"
        default: "100_plus"
        }
    }
}
