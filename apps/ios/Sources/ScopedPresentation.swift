import Foundation
import SimulationCore

/// iOS-only resolver for the ephemeral community-buzz values. SimulationCore supplies stable
/// IDs and numbers; this boundary is the only place that turns them into localized sentences.
enum CommunityBuzzPresentation {
    static func localizedReaction(
        _ line: CommunityBuzzReactionLine,
        resolver: GameCopyResolver
    ) -> String {
        var arguments: [LocalizedCopyArgument] = []
        if line.templateID.isNickname {
            guard let nicknameID = line.nicknameID,
                  let descriptor = NicknamePresentationCatalog.descriptor(for: nicknameID) else {
                return GameCopyResolver.unavailableText
            }
            let title = resolver.resolve(descriptor.titleToken)
            guard title != GameCopyResolver.unavailableText else {
                return GameCopyResolver.unavailableText
            }
            arguments.append(.userText(title))
        }
        if let numericArgument = line.numericArgument {
            arguments.append(.integer(numericArgument))
        }
        return resolver.resolve(
            GameCopyKey.gameContent(line.templateID.copyKey),
            arguments: arguments
        )
    }

    static func localizedNews(
        _ line: CommunityBuzzRivalNewsLine,
        resolver: GameCopyResolver
    ) -> String {
        guard let name = localizedRivalName(line.prospect, resolver: resolver),
              let schoolID = line.prospect.rivalSchoolID,
              let school = ProspectRankingPresentationCatalog.schoolDescriptor(for: schoolID) else {
            return GameCopyResolver.unavailableText
        }
        let schoolName = resolver.resolve(school.token)
        guard schoolName != GameCopyResolver.unavailableText else {
            return GameCopyResolver.unavailableText
        }
        var arguments: [LocalizedCopyArgument] = [
            .userText(name),
            .userText(schoolName),
        ]
        if let numericArgument = line.numericArgument {
            arguments.append(.integer(numericArgument))
        }
        return resolver.resolve(
            GameCopyKey.gameContent(line.templateID.copyKey),
            arguments: arguments
        )
    }

    static func localizedRivalName(
        _ identity: ProspectRanking.PresentationIdentity,
        resolver: GameCopyResolver
    ) -> String? {
        guard let surnameID = identity.surnameID,
              let givenNameID = identity.givenNameID else {
            return nil
        }
        let surname = resolver.resolve(
            ProspectRankingPresentationCatalog.surnameDescriptor(for: surnameID).token
        )
        let givenName = resolver.resolve(
            ProspectRankingPresentationCatalog.givenNameDescriptor(for: givenNameID).token
        )
        guard surname != GameCopyResolver.unavailableText,
              givenName != GameCopyResolver.unavailableText else {
            return nil
        }
        return resolver.language == .korean
            ? surname + givenName
            : givenName + " " + surname
    }
}

/// iOS-only resolver for the bounded prospect-ranking and draft-forecast surfaces.
enum ProspectRankingPresentation {
    struct ResolvedEntry: Identifiable, Equatable {
        let rank: Int
        let name: String
        let school: String
        let identityLine: String
        let tag: String
        let isPlayer: Bool

        var id: Int { rank }
    }

    static func board(
        state: HighSchoolCareerSnapshot,
        resolver: GameCopyResolver
    ) -> [ResolvedEntry] {
        let schoolID = state.school?.id
        let region = SchoolRegionID.strictLookup(rawRegion: state.identity.region)
        let rawSchool = state.school?.name ?? "학교 미정"
        let entries = ProspectRanking.presentationBoard(
            careerID: state.careerID,
            playerName: state.identity.name,
            playerSchool: rawSchool,
            playerSchoolID: schoolID,
            playerRegion: region,
            performance: state.performance
        )
        return entries.map {
            resolvedEntry(
                $0,
                playerSchoolID: schoolID,
                playerRegion: region,
                rawPlayerSchool: rawSchool,
                resolver: resolver
            )
        }
    }

    static func resolvedEntry(
        _ entry: ProspectRanking.Entry,
        playerSchoolID: SchoolID? = nil,
        playerRegion: SchoolRegionID? = nil,
        rawPlayerSchool: String = "학교 미정",
        resolver: GameCopyResolver
    ) -> ResolvedEntry {
        let name: String
        let school: String
        let tag: String
        if entry.isPlayer {
            // User-authored names are the one intentional verbatim exception.
            name = entry.name
            school = localizedPlayerSchool(
                schoolID: playerSchoolID,
                region: playerRegion,
                rawSchool: rawPlayerSchool,
                resolver: resolver
            )
            tag = resolver.resolve(AppCopyKey.prospectRankingPlayerTag)
        } else if let identity = entry.presentationIdentity,
                  let rivalName = CommunityBuzzPresentation.localizedRivalName(
                    identity,
                    resolver: resolver
                  ),
                  let rivalSchoolID = identity.rivalSchoolID,
                  let schoolDescriptor = ProspectRankingPresentationCatalog.schoolDescriptor(
                    for: rivalSchoolID
                  ) {
            name = rivalName
            school = resolver.resolve(schoolDescriptor.token)
            tag = identity.scoutTagID.map {
                resolver.resolve(ProspectRankingPresentationCatalog.scoutTagDescriptor(for: $0).token)
            } ?? GameCopyResolver.unavailableText
        } else if resolver.language == .korean {
            // The generated identity is present on the current path. This preserves exact Korean
            // output for a defensive legacy Entry while English still has a neutral boundary.
            name = entry.name
            school = entry.school
            tag = entry.tag
        } else {
            name = GameCopyResolver.unavailableText
            school = GameCopyResolver.unavailableText
            tag = GameCopyResolver.unavailableText
        }

        let identityLine = resolver.resolve(
            AppCopyKey.prospectRankingRowIdentity,
            arguments: [.userText(name), .userText(school)]
        )
        return ResolvedEntry(
            rank: entry.rank,
            name: name,
            school: school,
            identityLine: identityLine,
            tag: tag,
            isPlayer: entry.isPlayer
        )
    }

    static func localizedPlayerSchool(
        schoolID: SchoolID?,
        region: SchoolRegionID?,
        rawSchool: String,
        resolver: GameCopyResolver
    ) -> String {
        guard let schoolID, let region else {
            return resolver.language == .korean ? rawSchool : GameCopyResolver.unavailableText
        }
        return resolver.resolve(
            CopyToken.schoolSelectionDescriptor(region: region, schoolID: schoolID).schoolNameToken
        )
    }

    static func localizedForecastBand(
        _ forecast: HighSchoolCareerEngine.DraftForecastSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard let presentation = forecast.presentation,
              let descriptor = DraftForecastPresentationCatalog.bandDescriptors.first(
                where: { $0.id == presentation.bandID }
              ) else {
            return resolver.language == .korean ? forecast.band : GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func localizedForecastTeam(
        _ forecast: HighSchoolCareerEngine.DraftForecastSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard let presentation = forecast.presentation,
              let descriptor = DraftTeamPresentationCatalog.descriptor(
                for: presentation.interestedTeamID
              ) else {
            return resolver.language == .korean
                ? forecast.interestedTeam
                : GameCopyResolver.unavailableText
        }
        return resolver.resolve(descriptor.token)
    }

    static func forecastDetailArguments(
        _ forecast: HighSchoolCareerEngine.DraftForecastSnapshot,
        resolver: GameCopyResolver
    ) -> [LocalizedCopyArgument] {
        let team = localizedForecastTeam(forecast, resolver: resolver)
        let displayedTeam = resolver.language == .korean
            ? team + KoreanCopy.particle(team, final: "이", open: "가")
            : team
        return [
            .integer(forecast.score),
            .integer(forecast.threshold),
            .userText(displayedTeam),
        ]
    }
}
