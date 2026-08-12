/// Presentation-only verdict identity for the chapter review card.
///
/// The selection rules mirror the existing card exactly. These IDs and tokens are ephemeral and
/// are never included in a snapshot, RNG seed, event hash, or state commitment.
public enum ChapterReviewVerdictID: String, CaseIterable, Sendable {
    case noOfficialGames = "no-official-games"
    case walklessStrikeouts = "walkless-strikeouts"
    case strikeoutsOutpaceWalks = "strikeouts-outpace-walks"
    case processOverNumbers = "process-over-numbers"
}

public struct ChapterReviewVerdictCopyDescriptor: Equatable, Sendable {
    public let id: ChapterReviewVerdictID
    public let token: CopyToken

    public init(id: ChapterReviewVerdictID, token: CopyToken) {
        self.id = id
        self.token = token
    }
}

public enum ChapterReviewPresentationCatalog {
    /// Inventory order is fixed to the four authored verdict variants. It is not gameplay order.
    public static let verdictDescriptors: [ChapterReviewVerdictCopyDescriptor] =
        ChapterReviewVerdictID.allCases.map {
            ChapterReviewVerdictCopyDescriptor(id: $0, token: .chapterReviewVerdict($0))
        }

    public static func descriptor(for performance: CareerPerformanceSnapshot) -> ChapterReviewVerdictCopyDescriptor {
        let id: ChapterReviewVerdictID
        if performance.importantGamesCompleted == 0 {
            id = .noOfficialGames
        } else if performance.walks == 0 && performance.strikeouts >= 2 {
            id = .walklessStrikeouts
        } else if performance.strikeouts > performance.walks * 2 {
            id = .strikeoutsOutpaceWalks
        } else {
            id = .processOverNumbers
        }
        return verdictDescriptors.first { $0.id == id }!
    }
}

public extension PresentationCopyKey {
    static func chapterReviewVerdict(_ verdict: ChapterReviewVerdictID) -> String {
        stableID(
            family: .chapterReview,
            id: "verdict.\(verdict.rawValue)",
            slot: "sentence"
        )
    }
}

public extension CopyToken {
    static func chapterReviewVerdict(_ verdict: ChapterReviewVerdictID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterReviewVerdict(verdict))
    }
}
