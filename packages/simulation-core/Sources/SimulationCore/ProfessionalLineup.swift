import Foundation

/// A stable opposing batting order for professional games.
///
/// League-average batters made every plate appearance the same one: the ninth hitter was as hard
/// as the third. A real order has a top that gets on base, a middle that drives the ball and a
/// bottom the pitcher can work through — that shape is what makes "who is up" a question worth
/// asking, and it is what puts strikeouts back where they belong.
///
/// The order is a function of the team key alone, so it does not follow the player's ability or
/// rebirth count, and the same team fields the same nine every time.
public enum ProfessionalLineup {
    private static let contact = [57, 60, 60, 48, 52, 48, 47, 43, 45]
    private static let discipline = [59, 56, 58, 54, 48, 48, 46, 45, 48]
    private static let power = [43, 44, 61, 69, 60, 53, 45, 42, 40]

    public static func batter(teamKey: String, turn: Int, offset: Int = 0) -> BatterSnapshot {
        let spot = ((turn - 1) % 9 + 9) % 9
        func rating(_ base: Int, _ skill: String) -> Int {
            let jitter = Int(StableHash.fnv1a64Value("\(teamKey):\(spot):\(skill)") % 11) - 5
            return min(80, max(20, base + offset + jitter))
        }
        return BatterSnapshot(
            id: "\(teamKey):lineup:\(spot + 1)",
            name: "상대 \(spot + 1)번 타자",
            contact: rating(contact[spot], "contact"),
            discipline: rating(discipline[spot], "discipline"),
            power: rating(power[spot], "power"),
            batSide: StableHash.fnv1a64Value("\(teamKey):\(spot):side") % 100 < 35 ? .left : .right
        )
    }
}
