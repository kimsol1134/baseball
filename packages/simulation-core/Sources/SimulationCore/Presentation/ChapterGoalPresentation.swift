/// Presentation-only descriptor for one of the four deterministic chapter-goal frames.
public struct ChapterGoalCopyDescriptor: Equatable, Sendable {
    public let frame: ChapterGoal.Frame
    public let titleToken: CopyToken
    public let detailToken: CopyToken

    public init(
        frame: ChapterGoal.Frame,
        titleToken: CopyToken,
        detailToken: CopyToken
    ) {
        self.frame = frame
        self.titleToken = titleToken
        self.detailToken = detailToken
    }
}

public enum ChapterGoalPresentationCatalog {
    /// Exactly the four goal frames emitted by `ChapterGoal.goal`.
    public static let descriptors: [ChapterGoalCopyDescriptor] = ChapterGoal.Frame.allCases.map {
        ChapterGoalCopyDescriptor(
            frame: $0,
            titleToken: .chapterGoalTitle($0),
            detailToken: .chapterGoalDetail($0)
        )
    }

    public static func descriptor(for goal: ChapterGoal.Goal) -> ChapterGoalCopyDescriptor {
        descriptors.first { $0.frame == goal.frame }!
    }
}

public extension PresentationCopyKey {
    static func chapterGoalTitle(_ frame: ChapterGoal.Frame) -> String {
        stableID(family: .chapterGoal, id: frame.rawValue, slot: "title")
    }

    static func chapterGoalDetail(_ frame: ChapterGoal.Frame) -> String {
        stableID(family: .chapterGoal, id: frame.rawValue, slot: "detail")
    }
}

public extension CopyToken {
    static func chapterGoalTitle(_ frame: ChapterGoal.Frame) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterGoalTitle(frame))
    }

    static func chapterGoalDetail(_ frame: ChapterGoal.Frame) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterGoalDetail(frame))
    }

    static func chapterGoalDetail(_ frame: ChapterGoal.Frame, targetStrikeouts: Int) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.chapterGoalDetail(frame),
            arguments: [.integer(targetStrikeouts)]
        )
    }
}
