/// Transient presentation metadata for the high-school important-game card.
///
/// The scenario catalog remains the source of the shipped Korean content and the simulation
/// still reads the same array in the same order. This registry contains only stable IDs and
/// ephemeral copy tokens, so looking up a card cannot alter a save, commitment, event hash, or
/// RNG stream.

public struct ImportantGameScenarioCopyDescriptor: Equatable, Sendable {
    public let scenarioID: String
    public let isKnownScenario: Bool
    public let titleToken: CopyToken
    public let narrativeToken: CopyToken

    public init(
        scenarioID: String,
        isKnownScenario: Bool,
        titleToken: CopyToken,
        narrativeToken: CopyToken
    ) {
        self.scenarioID = scenarioID
        self.isKnownScenario = isKnownScenario
        self.titleToken = titleToken
        self.narrativeToken = narrativeToken
    }
}

public enum ImportantGamePresentationCatalog {
    /// Presentation inventory order intentionally follows the authored scenario array. It is not
    /// consulted by scenario selection and therefore cannot change gameplay ordering.
    public static let scenarioIDs: [String] = HighSchoolContentCatalog.scenarios.map(\.id)

    public static let scenarioDescriptors: [ImportantGameScenarioCopyDescriptor] = scenarioIDs.map {
        descriptor(for: $0)
    }

    public static func descriptor(for scenarioID: String) -> ImportantGameScenarioCopyDescriptor {
        let isKnown = scenarioIDs.contains(scenarioID)
        return ImportantGameScenarioCopyDescriptor(
            scenarioID: scenarioID,
            isKnownScenario: isKnown,
            titleToken: isKnown
                ? .importantGameScenarioTitle(scenarioID: scenarioID)
                : .importantGameScenarioFallbackTitle(),
            narrativeToken: isKnown
                ? .importantGameScenarioNarrative(scenarioID: scenarioID)
                : .importantGameScenarioFallbackNarrative()
        )
    }
}

public extension PresentationCopyKey {
    static func importantGameScenarioTitle(scenarioID: String) -> String {
        stableID(family: .importantGame, id: scenarioID, slot: "title")
    }

    static func importantGameScenarioNarrative(scenarioID: String) -> String {
        stableID(family: .importantGame, id: scenarioID, slot: "narrative")
    }

    static func importantGameScenarioFallbackTitle() -> String {
        stableID(family: .importantGame, id: "fallback", slot: "title")
    }

    static func importantGameScenarioFallbackNarrative() -> String {
        stableID(family: .importantGame, id: "fallback", slot: "narrative")
    }
}

public extension CopyToken {
    static func importantGameScenarioTitle(scenarioID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.importantGameScenarioTitle(scenarioID: scenarioID))
    }

    static func importantGameScenarioNarrative(scenarioID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.importantGameScenarioNarrative(scenarioID: scenarioID))
    }

    static func importantGameScenarioFallbackTitle() -> CopyToken {
        CopyToken(key: PresentationCopyKey.importantGameScenarioFallbackTitle())
    }

    static func importantGameScenarioFallbackNarrative() -> CopyToken {
        CopyToken(key: PresentationCopyKey.importantGameScenarioFallbackNarrative())
    }
}

public extension ImportantGameScenarioContent {
    var titleCopyToken: CopyToken { .importantGameScenarioTitle(scenarioID: id) }
    var narrativeCopyToken: CopyToken { .importantGameScenarioNarrative(scenarioID: id) }
}
