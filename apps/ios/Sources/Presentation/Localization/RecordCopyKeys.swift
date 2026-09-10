import Foundation
import BaseballIOSDomain

/// Static copy for the Records tab. Dynamic names and career data are supplied as typed values.
enum RecordUICopyKey: String, CaseIterable, Sendable {
    case navigation = "record.navigation"
    case empty = "record.empty"
    case archivedPlayer = "record.archive.last-player"

    case highSchoolHeader = "record.high-school.header"
    case appearances = "record.high-school.appearances"
    case pitchedInnings = "record.high-school.pitched-innings"
    case pitches = "record.high-school.pitches"
    case strikeouts = "record.high-school.strikeouts"
    case walks = "record.high-school.walks"
    case runs = "record.high-school.runs"
    case fanInterest = "record.high-school.fan-interest"
    case scoutTemperament = "record.high-school.scout-temperament"
    case personalityTitle = "record.high-school.personality-title"
    case personalityTrait = "record.high-school.personality-trait"
    case personalityRule = "record.high-school.personality-rule"
    case currentAbility = "record.current-ability"
    case currentAbilityBuild = "record.current-ability.build"
    case stuff = "record.ability.stuff"
    case command = "record.ability.command"
    case movement = "record.ability.movement"
    case stamina = "record.ability.stamina"
    case statsEmptyTitle = "record.high-school.stats-empty.title"
    case statsEmptyBody = "record.high-school.stats-empty.body"
    case highSchoolMetrics = "record.high-school.metrics"
    case gameRecord = "record.high-school.game-record"
    case gameRecordEmpty = "record.high-school.game-record.empty"
    case highSchoolGames = "record.high-school.games"
    case awakenings = "record.high-school.awakenings"
    case latestNews = "record.high-school.latest-news"
    case noNews = "record.high-school.no-news"

    case seasonMetrics = "record.pro.season-metrics"
    case seasonOutings = "record.pro.season-outings"
    case careerSeasons = "record.pro.career-seasons"
    case careerPostseasonLine = "record.pro.career-postseason-line"
    case careerPostseasonDirectLine = "record.pro.career-postseason-direct-line"
    case seasonLabel = "record.pro.season-label"
    case seasonLine = "record.pro.season-line"
    case awards = "record.pro.awards"
    case noAwards = "record.pro.no-awards"
    case milestones = "record.pro.milestones"
    case noMilestones = "record.pro.no-milestones"
    case hallOfFame = "record.pro.hall-of-fame"
    case goalBoardTitle = "record.goal-board.title"
    case goalBoardProgress = "record.goal-board.progress"
    case goalBoardCompleted = "record.goal-board.completed"
    case goalBoardConditions = "record.goal-board.conditions"
    case advancementTitle = "record.advancement.title"
    case advancementRemaining = "record.advancement.remaining"
    case advancementUnlocked = "record.advancement.unlocked"
    case advancementLockedAccessibility = "record.advancement.locked-accessibility"
    case seasonComparisonTitle = "record.season-comparison.title"
    case seasonComparisonSeasons = "record.season-comparison.seasons"
    case seasonComparisonHeadline = "record.season-comparison.headline"
    case seasonComparisonSteady = "record.season-comparison.steady"
    case seasonComparisonUnknown = "record.season-comparison.unknown"
    case saberTitle = "record.saber.title"
    case saberIP = "record.saber.ip"
    case saberRA9 = "record.saber.ra9"
    case saberFIP = "record.saber.fip"
    case saberKPercent = "record.saber.k-percent"
    case saberBBPercent = "record.saber.bb-percent"
    case saberWHIP = "record.saber.whip"
    case saberWAR = "record.saber.war"
    case saberSeason = "record.saber.season"
    case saberSeasonHeader = "record.saber.season-header"
    case saberCareer = "record.saber.career"
    case saberGlossary = "record.saber.glossary"
    case decisionHistory = "record.pro.decision-history"
    case decisionDate = "record.pro.decision-date"
    case decisionAccessibility = "record.pro.decision-accessibility"

    case directOuting = "record.game-log.direct-outing"
    case week = "record.game-log.week"
    case role = "record.game-log.role"
    case showRecent = "record.game-log.show-recent"
    case showAll = "record.game-log.show-all"

    case achievements = "record.achievements.title"
    case achievementsBody = "record.achievements.body"
}

extension RecordUICopyKey {
    var gameCopyKey: GameCopyKey { .localizable(rawValue) }
}

extension GameCopyResolver {
    func resolve(_ key: RecordUICopyKey, arguments: [LocalizedCopyArgument] = []) -> String {
        resolve(key.gameCopyKey, arguments: arguments)
    }
}

extension AppCopyKey {
    static let recordKeys = RecordUICopyKey.allCases.map(\.gameCopyKey)
}
