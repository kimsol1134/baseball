import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolPresentation {
    /// The scenario's title and narrative are resolved by ID. Legacy title/narrative fields are
    /// deliberately never used as visible fallback text.
    static func localizedImportantGameScenarioTitle(
        _ scenario: ImportantGameScenarioContent,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ImportantGamePresentationCatalog.descriptor(for: scenario.id).titleToken)
    }

    static func localizedImportantGameScenarioNarrative(
        _ scenario: ImportantGameScenarioContent,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(ImportantGamePresentationCatalog.descriptor(for: scenario.id).narrativeToken)
    }

    static func localizedImportantGameSituation(
        _ scenario: ImportantGameScenarioContent,
        resolver: GameCopyResolver
    ) -> String {
        let safeOuts = max(0, scenario.outs)
        let inning = GameFormatters.inningLabel(inning: scenario.inning, language: resolver.language)
        let key: GameCopyKey
        var arguments: [LocalizedCopyArgument] = [.userText(inning)]
        switch safeOuts {
        case 0:
            key = AppCopyKey.importantGameSituationZero
        case 1:
            key = AppCopyKey.importantGameSituationOne
        default:
            key = AppCopyKey.importantGameSituationMany
            arguments.append(.integer(safeOuts))
        }
        return resolver.resolve(key, arguments: arguments)
    }

    static func localizedImportantGameScenarioAccessibility(
        title: String,
        situation: String,
        narrative: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.importantGameScenarioAccessibility,
            arguments: [.userText(title), .userText(situation), .userText(narrative)]
        )
    }

    static func localizedImportantGameOpponentTitle(
        isFinalShowdown: Bool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            isFinalShowdown
                ? AppCopyKey.importantGameFinalShowdownTitle
                : AppCopyKey.importantGameOpponentTitle
        )
    }

    static func localizedImportantGameFinalShowdownBody(
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(AppCopyKey.importantGameFinalShowdownBody)
    }

    static func localizedImportantGameCareerMatchup(
        _ ledger: RivalLedger,
        resolver: GameCopyResolver
    ) -> String? {
        guard ledger.plateAppearances > 0 else { return nil }
        return resolver.resolve(
            AppCopyKey.importantGameCareerMatchup,
            arguments: [
                .integer(ledger.plateAppearances),
                .integer(ledger.strikeouts),
                .integer(ledger.hits),
            ]
        )
    }

    static func localizedImportantGameRivalAccessibility(
        name: String,
        archetype: String,
        signature: String?,
        resolver: GameCopyResolver
    ) -> String {
        let key = signature == nil
            ? AppCopyKey.importantGameRivalAccessibility
            : AppCopyKey.importantGameRivalAccessibilitySignature
        var arguments: [LocalizedCopyArgument] = [.userText(name), .userText(archetype)]
        if let signature {
            arguments.append(.userText(signature))
        }
        return resolver.resolve(
            key,
            arguments: arguments
        )
    }

    static func localizedImportantGameStartAction(resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.importantGameStartAction)
    }

    /// The raw legacy name is retained only as a deterministic portrait seed. It is never passed
    /// to a visible label or accessibility value.
    static func importantGameRivalPortraitSeed(_ rival: RivalSnapshot) -> String {
        rival.name
    }

    static func localizedChallengeOutcome(
        _ outcome: DraftOutcome?,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            outcome == .drafted
                ? AppCopyKey.challengeEndOutcomeDrafted
                : AppCopyKey.challengeEndOutcomeUndrafted
        )
    }

    static func localizedRelationshipWindLine(
        category: String,
        wind: CareerWind,
        resolver: GameCopyResolver
    ) -> String? {
        let target = HighSchoolCareerEngine.relationshipTarget(forEventCategory: category)
        let descriptor = RelationshipPresentationCatalog.windDescriptor(for: wind, target: target)
        guard !descriptor.effectTokens.isEmpty else { return nil }
        let title = resolver.resolve(descriptor.careerWind.titleToken)
        let effects = descriptor.effectTokens.map(resolver.resolve).joined(separator: " · ")
        return resolver.resolve(.relationshipWindLine(title: title, effects: effects))
    }

    static func localizedRelationshipEventAccessibility(
        speaker: String,
        name: String,
        title: String,
        primaryText: String,
        summary: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .relationshipAccessibilityEvent(
                speaker: speaker,
                name: name,
                title: title,
                primaryText: primaryText,
                summary: summary
            )
        )
    }

    static func localizedRelationshipChoiceAccessibility(
        title: String,
        detail: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(.relationshipAccessibilityChoice(title: title, detail: detail))
    }

    static func descriptorForRival(_ rival: RivalSnapshot) -> RivalPresentationCopyDescriptor {
        RivalPresentationCatalog.descriptor(for: rival.id)
    }
}
