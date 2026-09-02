import Foundation
import SimulationCore
import BaseballIOSDomain

/// Builds share-card models from snapshots. Views pass the result to `CareerShareButton`.
enum CareerSharePresentation {
    static func retirement(
        state: ProCareerSnapshot,
        stamp: CareerDisplayRules.ChallengeStamp?,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel {
        let totals = careerTotals(state.careerStats)
        let ra9 = GameFormatters.ra9(
            runsAllowed: totals.runs,
            outs: totals.outs,
            language: resolver.language
        )
        let whip = GameFormatters.whip(
            hits: totals.hits,
            walks: totals.walks,
            outs: totals.outs,
            language: resolver.language
        )
        let honors = state.journeyState?.retirementHonors ?? []
        var badges: [String] = honors.compactMap { honor in
            switch honor.kind {
            case .retiredNumber, .hallOfFame, .nationalGold:
                return ProCareerPresentation.honorTitle(honor.kind, resolver: resolver)
            default:
                return nil
            }
        }
        if let tierTitle = legacyTierTitle(state: state, resolver: resolver) {
            badges.append(tierTitle)
        }
        let seasons = max(state.careerStats.count, 1)
        return CareerShareCardModel(
            kind: .retirement,
            playerName: state.identity.name,
            portraitSeed: state.identity.portraitSeed,
            throwingHand: throwingHand(state.pitcher.throwingHand, resolver: resolver),
            isPro: true,
            headline: resolver.resolve(ShareUICopyKey.headlineRetirement),
            detail: ProRetirementCopy.identityLine(
                teamName: ProCareerPresentation.teamName(state.team, resolver: resolver),
                seasons: state.careerStats.count,
                resolver: resolver
            ),
            stats: [
                CareerShareStat(
                    label: resolver.resolve(ProUICopyKey.totalsRecord),
                    value: GameLineFormat.record(wins: totals.wins, losses: totals.losses, saves: totals.saves)
                ),
                CareerShareStat(label: resolver.resolve(ProUICopyKey.totalsRA9), value: ra9),
                CareerShareStat(
                    label: resolver.resolve(ProUICopyKey.totalsStrikeouts),
                    value: "\(totals.strikeouts)"
                ),
                CareerShareStat(label: resolver.resolve(ProUICopyKey.totalsWHIP), value: whip),
                CareerShareStat(
                    label: resolver.resolve(ProUICopyKey.totalsSeasons),
                    value: "\(state.careerStats.count)"
                ),
            ],
            badges: badges,
            stamp: stamp,
            summary: resolver.resolve(
                ShareUICopyKey.summaryRetirement,
                arguments: [.userText(state.identity.name), .integer(seasons)]
            ),
            season: state.season,
            hasMedal: honors.contains(where: { $0.kind == .nationalGold })
        )
    }

    static func draft(
        result: DraftResultSnapshot,
        name: String,
        portraitSeed: String,
        throwingHand: ThrowingHand,
        games: Int,
        strikeouts: Int,
        runsAllowed: Int,
        outs: Int?,
        stamp: CareerDisplayRules.ChallengeStamp?,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel {
        let drafted = result.outcome == .drafted
        let teamName = result.team.map {
            HighSchoolConclusionPresentation.localizedTeamName($0, resolver: resolver)
        }
        var stats: [CareerShareStat] = []
        if drafted {
            stats.append(
                CareerShareStat(
                    label: resolver.resolve(ShareUICopyKey.draftRound),
                    value: "\(result.round ?? 0)"
                )
            )
            stats.append(
                CareerShareStat(
                    label: resolver.resolve(ShareUICopyKey.draftPick),
                    value: "\(result.overallPick ?? 0)"
                )
            )
        }
        stats.append(
            CareerShareStat(
                label: resolver.resolve(AppCopyKey.conclusionLifeCardGames),
                value: "\(games)"
            )
        )
        stats.append(
            CareerShareStat(
                label: resolver.resolve(ProUICopyKey.totalsRA9),
                value: GameFormatters.ra9(
                    runsAllowed: runsAllowed,
                    outs: outs ?? 0,
                    language: resolver.language
                )
            )
        )
        stats.append(
            CareerShareStat(
                label: resolver.resolve(AppCopyKey.conclusionLifeCardStrikeouts),
                value: "\(strikeouts)"
            )
        )
        stats.append(
            CareerShareStat(
                label: resolver.resolve(ShareUICopyKey.draftGrade),
                value: "\(result.evaluationScore)"
            )
        )
        var badges: [String] = []
        if let teamName { badges.append(teamName) }
        badges.append(
            HighSchoolConclusionPresentation.localizedDraftProjectedRange(
                result.projectedRange,
                resolver: resolver
            )
        )
        let summary: String
        if drafted {
            summary = resolver.resolve(
                ShareUICopyKey.summaryDraft,
                arguments: [
                    .userText(name),
                    .integer(result.round ?? 0),
                    .integer(result.overallPick ?? 0),
                ]
            )
        } else {
            summary = resolver.resolve(
                ShareUICopyKey.summaryDraftUndrafted,
                arguments: [.userText(name)]
            )
        }
        return CareerShareCardModel(
            kind: .draft,
            playerName: name,
            portraitSeed: portraitSeed,
            throwingHand: self.throwingHand(throwingHand, resolver: resolver),
            isPro: drafted,
            headline: resolver.resolve(
                drafted ? ShareUICopyKey.headlineDraft : ShareUICopyKey.headlineDraftUndrafted
            ),
            detail: teamName ?? resolver.resolve(ShareUICopyKey.headlineDraftUndrafted),
            stats: stats,
            badges: badges,
            stamp: stamp,
            summary: summary,
            season: 0,
            hasMedal: false
        )
    }

    static func draft(
        result: DraftResultSnapshot,
        record: LifeRecord,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel {
        draft(
            result: result,
            name: record.playerName,
            portraitSeed: record.portraitSeed,
            throwingHand: .right,
            games: record.games,
            strikeouts: record.strikeouts,
            runsAllowed: record.runsAllowed,
            outs: record.outs,
            stamp: CareerDisplayRules.challengeStamp(
                highSchoolCareerID: record.careerID,
                lifeNumber: record.lifeNumber
            ),
            resolver: resolver
        )
    }

    static func draft(
        result: DraftResultSnapshot,
        state: HighSchoolCareerSnapshot,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel {
        draft(
            result: result,
            name: state.identity.name,
            portraitSeed: state.identity.portraitSeed,
            throwingHand: state.identity.throwingHand,
            games: state.performance.importantGamesCompleted,
            strikeouts: state.performance.strikeouts,
            runsAllowed: state.performance.runsAllowed,
            outs: state.performance.outs,
            stamp: CareerDisplayRules.challengeStamp(highSchoolCareerID: state.careerID),
            resolver: resolver
        )
    }

    static func recordMilestone(
        state: ProCareerSnapshot,
        stamp: CareerDisplayRules.ChallengeStamp?,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel? {
        guard let raw = state.milestones.last, isShareableMilestone(raw) else { return nil }
        let title = ProCareerPresentation.milestone(raw, resolver: resolver)
        return record(
            headline: resolver.resolve(ShareUICopyKey.headlineRecord),
            detail: title,
            stats: [
                CareerShareStat(
                    label: resolver.resolve(ProUICopyKey.totalsGames),
                    value: "\(careerTotals(state.careerStats).games + state.currentStats.games)"
                ),
                CareerShareStat(
                    label: resolver.resolve(ProUICopyKey.totalsStrikeouts),
                    value: "\(careerTotals(state.careerStats).strikeouts + state.currentStats.strikeouts)"
                ),
            ],
            badges: [title],
            state: state,
            stamp: stamp,
            resolver: resolver
        )
    }

    static func recordQS(
        followUp: ProDecisionFollowUp,
        state: ProCareerSnapshot,
        stamp: CareerDisplayRules.ChallengeStamp?,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel? {
        guard let qualityStarts = followUp.qualityStarts else { return nil }
        var stats = [
            CareerShareStat(
                label: resolver.resolve(ShareUICopyKey.recordQS),
                value: "\(qualityStarts)"
            ),
        ]
        if let runs = followUp.runsAllowed {
            stats.append(
                CareerShareStat(
                    label: resolver.resolve(ShareUICopyKey.recordRuns),
                    value: "\(runs)"
                )
            )
        }
        let summary = ProCareerPresentation.followUpSummary(followUp, resolver: resolver)
        return record(
            headline: resolver.resolve(ShareUICopyKey.headlineRecord),
            detail: summary,
            stats: stats,
            badges: [resolver.resolve(followUp.type.displayCopyToken)],
            state: state,
            stamp: stamp,
            resolver: resolver
        )
    }

    static func national(
        state: ProCareerSnapshot,
        tournament: ProNationalTournamentState,
        stamp: CareerDisplayRules.ChallengeStamp?,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel {
        let medal = ProNationalTeamCopy.resultTitle(tournament.result, resolver: resolver)
        var stats: [CareerShareStat] = [
            CareerShareStat(
                label: resolver.resolve(ShareUICopyKey.headlineNational),
                value: medal
            ),
        ]
        var badges = [medal]
        if tournament.exempted {
            let exempted = resolver.resolve(ShareUICopyKey.nationalExempted)
            stats.append(
                CareerShareStat(
                    label: resolver.resolve(ProUICopyKey.nationalTeamResultExempted),
                    value: exempted
                )
            )
            badges.append(exempted)
        }
        var detail = medal
        if let final = tournament.finalLine {
            let opponent = resolver.resolve(
                .gameContent(CareerDisplayRules.nationalOpponentNameKey(final.opponentID))
            )
            detail = resolver.resolve(
                ShareUICopyKey.nationalFinal,
                arguments: [
                    .userText(opponent),
                    .integer(final.teamRuns),
                    .integer(final.opponentRuns),
                ]
            )
        }
        return CareerShareCardModel(
            kind: .national,
            playerName: state.identity.name,
            portraitSeed: state.identity.portraitSeed,
            throwingHand: throwingHand(state.pitcher.throwingHand, resolver: resolver),
            isPro: true,
            headline: resolver.resolve(ShareUICopyKey.headlineNational),
            detail: detail,
            stats: stats,
            badges: badges,
            stamp: stamp,
            summary: resolver.resolve(
                ShareUICopyKey.summaryNational,
                arguments: [.userText(state.identity.name), .userText(medal)]
            ),
            season: state.season,
            hasMedal: tournament.result == .gold
                || tournament.result == .silver
                || tournament.result == .bronze
        )
    }

    static func isShareableMilestone(_ raw: String) -> Bool {
        raw.hasPrefix("프로 통산") && (raw.hasSuffix("경기") || raw.hasSuffix("탈삼진"))
    }

    private static func record(
        headline: String,
        detail: String,
        stats: [CareerShareStat],
        badges: [String],
        state: ProCareerSnapshot,
        stamp: CareerDisplayRules.ChallengeStamp?,
        resolver: GameCopyResolver
    ) -> CareerShareCardModel {
        CareerShareCardModel(
            kind: .record,
            playerName: state.identity.name,
            portraitSeed: state.identity.portraitSeed,
            throwingHand: throwingHand(state.pitcher.throwingHand, resolver: resolver),
            isPro: true,
            headline: headline,
            detail: detail,
            stats: stats,
            badges: badges,
            stamp: stamp,
            summary: resolver.resolve(
                ShareUICopyKey.summaryRecord,
                arguments: [.userText(state.identity.name), .userText(detail)]
            ),
            season: state.season,
            hasMedal: false
        )
    }

    private static func throwingHand(_ hand: ThrowingHand, resolver: GameCopyResolver) -> String {
        resolver.resolve(hand == .left ? AppCopyKey.handLeft : AppCopyKey.handRight)
    }

    private static func careerTotals(
        _ seasons: [ProSeasonStats]
    ) -> (games: Int, outs: Int, strikeouts: Int, wins: Int, losses: Int, saves: Int, runs: Int, hits: Int, walks: Int) {
        seasons.reduce((0, 0, 0, 0, 0, 0, 0, 0, 0)) {
            (
                $0.0 + $1.games,
                $0.1 + $1.inningsOuts,
                $0.2 + $1.strikeouts,
                $0.3 + $1.wins,
                $0.4 + $1.losses,
                $0.5 + $1.saves,
                $0.6 + $1.runsAllowed,
                $0.7 + $1.hits,
                $0.8 + $1.walks
            )
        }
    }

    private static func legacyTierTitle(
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        let records = MobileCareerStore.teamCareerRecords(for: state)
        let projection = MobileCareerStore.teamLegacyProjection(
            teamID: state.team.id,
            records: records,
            rulesVersion: state.journeyState?.rulesVersion ?? 1
        )
        guard let tier = projection.tier else { return nil }
        let key: ProUICopyKey = switch tier {
        case .newFace: .directionTierNewFace
        case .supportingPillar: .directionTierSupportingPillar
        case .corePlayer: .directionTierCorePlayer
        case .clubAce: .directionTierClubAce
        case .clubSymbol: .directionTierClubSymbol
        case .retiredNumberCandidate: .directionTierRetiredNumber
        }
        return resolver.resolve(key)
    }
}
