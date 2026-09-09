import Foundation

/// What a pitcher keeps from lives that were actually finished.
///
/// The old rebirth reward raised opponents by the rebirth count, so a second life met a stronger
/// league with the same pitcher — the reward read as a penalty. This replaces that: finished lives
/// leave learned fundamentals on the *player*, applied once at creation.
///
/// It counts completed, archived lives rather than `lifeNumber`, so abandoning a run and starting
/// over cannot farm it, and it is independent of the chosen legacy family — switching families
/// never erases experience that was already earned.
public enum HighSchoolRebirthGrowthRules {
    /// +3 per completed life for the first four, then +1, capped at +16.
    public static func bonus(completedLives: Int) -> Int {
        switch completedLives {
        case ..<1: return 0
        case ...4: return completedLives * 3
        default: return min(16, 12 + completedLives - 4)
        }
    }

    /// Applies the bonus to base ratings and to every pitch profile. Ratings stay inside the
    /// stored 80 ceiling and velocity inside 160.0km/h.
    public static func apply(_ pitcher: PitcherSnapshot, completedLives: Int) -> PitcherSnapshot {
        let bonus = bonus(completedLives: completedLives)
        guard bonus > 0 else { return pitcher }
        func bump(_ value: Int) -> Int { min(80, value + bonus) }
        return PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: bump(pitcher.stuff),
            command: bump(pitcher.command),
            movement: bump(pitcher.movement),
            stamina: bump(pitcher.stamina),
            pitchProfiles: pitcher.pitchProfiles?.map { profile in
                PitchProfileSnapshot(
                    pitchType: profile.pitchType,
                    role: profile.role,
                    velocityTenthsKPH: min(1_600, profile.velocityTenthsKPH + bonus * 3),
                    control: bump(profile.control),
                    command: bump(profile.command),
                    movement: bump(profile.movement),
                    whiff: bump(profile.whiff),
                    weakContact: bump(profile.weakContact),
                    fatigueCost: profile.fatigueCost,
                    availability: profile.availability
                )
            },
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
    }
}
