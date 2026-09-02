/// Single source for career-total game and strikeout milestone thresholds.
///
/// Weekly news lines and settlement recognitions used to hard-code the same arrays
/// in two places. Callers must keep the Korean milestone string and recognition
/// `contentID` byte-identical to the values that shipped before this unification.
public enum ProCareerMilestoneRules {
    public static let gameMarks = [50, 100, 300]
    public static let strikeoutMarks = [50, 100, 200, 500]

    public static func gamesLine(_ mark: Int) -> String {
        "프로 통산 \(mark)경기"
    }

    public static func strikeoutsLine(_ mark: Int) -> String {
        "프로 통산 \(mark)탈삼진"
    }

    public static func gamesContentID(_ mark: Int) -> String {
        "pro.milestone.career.games.\(mark)"
    }

    public static func strikeoutsContentID(_ mark: Int) -> String {
        "pro.milestone.career.strikeouts.\(mark)"
    }

    public static func nextMark(current: Int, marks: [Int]) -> (mark: Int, completed: Bool) {
        if let next = marks.first(where: { current < $0 }) {
            return (next, false)
        }
        return (max(marks.last ?? 1, 1), true)
    }
}
