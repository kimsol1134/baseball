import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolPresentation {
    static func localizedChapterReviewTitle(
        _ chapter: CareerChapterSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let chapterCopy = CareerChapterPresentationCatalog.descriptor(for: chapter)
        return resolver.resolve(
            AppCopyKey.chapterReviewCardTitle,
            arguments: [.userText(resolver.resolve(chapterCopy.titleToken))]
        )
    }

    static func localizedChapterReviewVerdict(
        _ performance: CareerPerformanceSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ChapterReviewPresentationCatalog.descriptor(for: performance).token)
    }

    static func localizedChapterReviewStatLine(
        _ performance: CareerPerformanceSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.chapterReviewStatLine,
            arguments: [
                .integer(performance.importantGamesCompleted),
                .integer(performance.strikeouts),
                .integer(performance.walks),
            ]
        )
    }

    static func localizedChapterReviewGrowthEmpty(
        trainingCount: Int,
        resolver: GameCopyResolver
    ) -> String {
        if trainingCount == 0 {
            return resolver.resolve(AppCopyKey.chapterReviewGrowthEmptyNoTraining)
        }
        return resolver.resolve(
            AppCopyKey.chapterReviewGrowthEmptyWithTraining,
            arguments: [.integer(trainingCount)]
        )
    }

    static func localizedChapterReviewGrowthSummary(
        trainingCount: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.chapterReviewGrowthSummary,
            arguments: [.integer(trainingCount)]
        )
    }

    /// Sorts the persisted raw gain map exactly as the pre-migration card did, then localizes
    /// each stable ability identity. In particular, localized labels never participate in sort.
    static func localizedChapterReviewGainRows(
        _ gains: [String: Int],
        resolver: GameCopyResolver
    ) -> [ChapterReviewGainRow] {
        gains.sorted { $0.value > $1.value }.map { rawLabel, delta in
            let ability: TalentAbility? = switch rawLabel {
            case "구위": .stuff
            case "제구": .command
            case "변화구": .movement
            case "체력": .stamina
            default: nil
            }
            return ChapterReviewGainRow(
                id: ability?.rawValue ?? "legacy.\(rawLabel)",
                label: ability.map { resolver.resolve($0.displayCopyToken) }
                    ?? (resolver.language == .korean ? rawLabel : GameCopyResolver.unavailableText),
                delta: delta
            )
        }
    }

    static func localizedChapterReviewRivalLine(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        let descriptor = RivalPresentationCatalog.descriptor(for: rival.id)
        guard descriptor.isKnownRival || !rival.name.isEmpty else { return nil }
        return resolver.resolve(
            AppCopyKey.chapterReviewNextStoryRival,
            arguments: [.userText(localizedRivalName(rival, resolver: resolver))]
        )
    }

    // MARK: - Tournament card

    static func localizedTournamentName(
        chapterNumber: Int,
        resolver: GameCopyResolver
    ) -> String {
        guard let descriptor = TournamentPresentationCatalog.tournamentNameDescriptor(for: chapterNumber) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedTournamentRound(
        rawRound: String,
        resolver: GameCopyResolver
    ) -> String {
        guard let descriptor = TournamentPresentationCatalog.roundDescriptor(for: rawRound) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedTournamentOpponentSchool(
        rawSchoolName: String,
        resolver: GameCopyResolver
    ) -> String {
        guard let descriptor = TournamentPresentationCatalog.opponentSchoolDescriptor(for: rawSchoolName) else {
            return GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedTournamentAceStart(
        round: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.tournamentAceStart,
            arguments: [.userText(localizedTournamentRound(rawRound: round, resolver: resolver))]
        )
    }

    // MARK: - Chapter goal card

    static func localizedChapterGoalTitle(
        _ goal: ChapterGoal.Goal,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ChapterGoalPresentationCatalog.descriptor(for: goal).titleToken)
    }

    static func localizedChapterGoalDetail(
        _ goal: ChapterGoal.Goal,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = ChapterGoalPresentationCatalog.descriptor(for: goal)
        return resolver.resolve(
            .chapterGoalDetail(descriptor.frame, targetStrikeouts: goal.targetStrikeouts)
        )
    }

    static func localizedChapterGoalProgress(
        progress: Int,
        targetStrikeouts: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.chapterGoalProgress,
            arguments: [.integer(progress), .integer(targetStrikeouts)]
        )
    }
}
