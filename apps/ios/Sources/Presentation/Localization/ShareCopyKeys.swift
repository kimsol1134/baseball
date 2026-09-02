import Foundation
import BaseballIOSDomain

/// Static copy for career share cards. Challenge codes and player names are typed arguments.
enum ShareUICopyKey: String, CaseIterable, Sendable {
    case action = "share.card.action"
    case previewTitle = "share.card.preview.title"
    case previewShare = "share.card.preview.share"
    case renderFailed = "share.card.render-failed"
    case storeBadge = "share.card.store-badge"
    case stamp = "share.card.stamp"
    case bodyChallenge = "share.card.body.challenge"
    case summaryRetirement = "share.card.summary.retirement"
    case summaryDraft = "share.card.summary.draft"
    case summaryDraftUndrafted = "share.card.summary.draft-undrafted"
    case summaryRecord = "share.card.summary.record"
    case summaryNational = "share.card.summary.national"
    case headlineRetirement = "share.card.headline.retirement"
    case headlineDraft = "share.card.headline.draft"
    case headlineDraftUndrafted = "share.card.headline.draft-undrafted"
    case headlineRecord = "share.card.headline.record"
    case headlineNational = "share.card.headline.national"
    case draftRound = "share.card.draft.round"
    case draftPick = "share.card.draft.pick"
    case draftGrade = "share.card.draft.grade"
    case recordQS = "share.card.record.qs"
    case recordRuns = "share.card.record.runs"
    case nationalFinal = "share.card.national.final"
    case nationalExempted = "share.card.national.exempted"
}

extension ShareUICopyKey {
    var gameCopyKey: GameCopyKey { .localizable(rawValue) }
}

extension GameCopyResolver {
    func resolve(_ key: ShareUICopyKey, arguments: [LocalizedCopyArgument] = []) -> String {
        resolve(key.gameCopyKey, arguments: arguments)
    }
}

extension AppCopyKey {
    static let shareKeys = ShareUICopyKey.allCases.map(\.gameCopyKey)
}
