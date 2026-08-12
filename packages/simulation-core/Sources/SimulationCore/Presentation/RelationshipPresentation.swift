/// Semantic presentation metadata for the high-school relationship card.
///
/// The relationship engine still owns the Codable event and trust values, and
/// `RelationshipVoiceCatalog` still owns the shipped Korean source content. These descriptors
/// are transient lookup plans only: they carry stable IDs and typed tokens, never localized
/// sentences, and therefore cannot affect save encoding, event commitments, RNG, or ordering.

public struct RelationshipQuoteCopyDescriptor: Equatable, Sendable {
    public let eventID: String
    public let trustBand: RelationshipVoiceCatalog.TrustBand
    public let token: CopyToken

    public init(eventID: String, trustBand: RelationshipVoiceCatalog.TrustBand, token: CopyToken) {
        self.eventID = eventID
        self.trustBand = trustBand
        self.token = token
    }
}

public struct RelationshipChoiceCopyDescriptor: Equatable, Sendable {
    public let scopeID: String
    public let response: RelationshipResponse
    public let titleToken: CopyToken
    public let detailToken: CopyToken

    public init(
        scopeID: String,
        response: RelationshipResponse,
        titleToken: CopyToken,
        detailToken: CopyToken
    ) {
        self.scopeID = scopeID
        self.response = response
        self.titleToken = titleToken
        self.detailToken = detailToken
    }
}

public struct RelationshipEventCopyDescriptor: Equatable, Sendable {
    public let eventID: String
    public let categoryID: String
    public let isKnownEvent: Bool
    public let titleToken: CopyToken
    public let summaryToken: CopyToken
    public let categoryLabelToken: CopyToken
    public let speakerLabelToken: CopyToken

    public init(
        eventID: String,
        categoryID: String,
        isKnownEvent: Bool,
        titleToken: CopyToken,
        summaryToken: CopyToken,
        categoryLabelToken: CopyToken,
        speakerLabelToken: CopyToken
    ) {
        self.eventID = eventID
        self.categoryID = categoryID
        self.isKnownEvent = isKnownEvent
        self.titleToken = titleToken
        self.summaryToken = summaryToken
        self.categoryLabelToken = categoryLabelToken
        self.speakerLabelToken = speakerLabelToken
    }
}

public struct RelationshipCardCopyDescriptor: Equatable, Sendable {
    public let event: RelationshipEventCopyDescriptor
    public let sceneSpeaker: RelationshipVoiceCatalog.Speaker
    public let quoteDescriptors: [RelationshipQuoteCopyDescriptor]
    public let choiceDescriptors: [RelationshipChoiceCopyDescriptor]

    public init(
        event: RelationshipEventCopyDescriptor,
        sceneSpeaker: RelationshipVoiceCatalog.Speaker,
        quoteDescriptors: [RelationshipQuoteCopyDescriptor],
        choiceDescriptors: [RelationshipChoiceCopyDescriptor]
    ) {
        self.event = event
        self.sceneSpeaker = sceneSpeaker
        self.quoteDescriptors = quoteDescriptors
        self.choiceDescriptors = choiceDescriptors
    }
}

public struct RivalPresentationCopyDescriptor: Equatable, Sendable {
    public let rivalID: String
    public let isKnownRival: Bool
    public let nameToken: CopyToken
    public let archetypeToken: CopyToken
    public let signatureToken: CopyToken

    public init(
        rivalID: String,
        isKnownRival: Bool,
        nameToken: CopyToken,
        archetypeToken: CopyToken,
        signatureToken: CopyToken
    ) {
        self.rivalID = rivalID
        self.isKnownRival = isKnownRival
        self.nameToken = nameToken
        self.archetypeToken = archetypeToken
        self.signatureToken = signatureToken
    }
}

public struct RelationshipWindCopyDescriptor: Equatable, Sendable {
    public let target: RelationshipTarget
    public let careerWind: CareerWindCopyDescriptor
    public let favoredEffectToken: CopyToken?
    public let lossEffectToken: CopyToken?

    public init(
        target: RelationshipTarget,
        careerWind: CareerWindCopyDescriptor,
        favoredEffectToken: CopyToken?,
        lossEffectToken: CopyToken?
    ) {
        self.target = target
        self.careerWind = careerWind
        self.favoredEffectToken = favoredEffectToken
        self.lossEffectToken = lossEffectToken
    }

    public var effectTokens: [CopyToken] {
        [favoredEffectToken, lossEffectToken].compactMap { $0 }
    }
}

public extension PresentationCopyKey {
    static func relationshipPrompt() -> String {
        stableID(family: .relationship, id: "prompt", slot: "title")
    }

    static func relationshipCategoryLabel(categoryID: String) -> String {
        stableID(family: .relationship, id: "category.\(categoryID)", slot: "label")
    }

    static func relationshipSpeakerLabel(categoryID: String) -> String {
        stableID(family: .relationship, id: "category.\(categoryID)", slot: "speaker")
    }

    static func relationshipCategoryChoiceTitle(
        categoryID: String,
        response: RelationshipResponse
    ) -> String {
        stableID(
            family: .relationship,
            id: "category.\(categoryID)",
            slot: "choice.\(response.rawValue).title"
        )
    }

    static func relationshipCategoryChoiceDetail(
        categoryID: String,
        response: RelationshipResponse
    ) -> String {
        stableID(
            family: .relationship,
            id: "category.\(categoryID)",
            slot: "choice.\(response.rawValue).detail"
        )
    }

    static func relationshipFallbackEventTitle() -> String {
        stableID(family: .relationship, id: "fallback.event", slot: "title")
    }

    static func relationshipFallbackEventSummary() -> String {
        stableID(family: .relationship, id: "fallback.event", slot: "summary")
    }

    static func relationshipFallbackQuote() -> String {
        stableID(family: .relationship, id: "fallback", slot: "quote")
    }

    static func relationshipFallbackChoiceTitle(response: RelationshipResponse) -> String {
        stableID(
            family: .relationship,
            id: "fallback",
            slot: "choice.\(response.rawValue).title"
        )
    }

    static func relationshipFallbackChoiceDetail(response: RelationshipResponse) -> String {
        stableID(
            family: .relationship,
            id: "fallback",
            slot: "choice.\(response.rawValue).detail"
        )
    }

    static func relationshipAccessibilityEvent() -> String {
        stableID(family: .relationship, id: "accessibility", slot: "event")
    }

    static func relationshipAccessibilityChoice() -> String {
        stableID(family: .relationship, id: "accessibility", slot: "choice")
    }

    static func relationshipWindLine() -> String {
        stableID(family: .relationship, id: "wind", slot: "line")
    }

    static func relationshipWindFavoredEffect(target: RelationshipTarget) -> String {
        stableID(
            family: .relationship,
            id: "wind.favored.\(target.rawValue)",
            slot: "effect"
        )
    }

    static func relationshipWindLossEffect() -> String {
        stableID(family: .relationship, id: "wind.loss", slot: "effect")
    }

    static func rivalArchetype(rivalID: String) -> String {
        stableID(family: .rival, id: rivalID, slot: "archetype")
    }

    static func rivalSignature(rivalID: String) -> String {
        stableID(family: .rival, id: rivalID, slot: "signature")
    }

    static func rivalFallbackName() -> String {
        stableID(family: .rival, id: "fallback", slot: "name")
    }

    static func rivalFallbackArchetype() -> String {
        stableID(family: .rival, id: "fallback", slot: "archetype")
    }

    static func rivalFallbackSignature() -> String {
        stableID(family: .rival, id: "fallback", slot: "signature")
    }
}

public extension CopyToken {
    static func relationshipPrompt() -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipPrompt())
    }

    static func relationshipCategoryLabel(categoryID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipCategoryLabel(categoryID: categoryID))
    }

    static func relationshipSpeakerLabel(categoryID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipSpeakerLabel(categoryID: categoryID))
    }

    static func relationshipCategoryChoiceTitle(
        categoryID: String,
        response: RelationshipResponse
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipCategoryChoiceTitle(
                categoryID: categoryID,
                response: response
            )
        )
    }

    static func relationshipCategoryChoiceDetail(
        categoryID: String,
        response: RelationshipResponse
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipCategoryChoiceDetail(
                categoryID: categoryID,
                response: response
            )
        )
    }

    static func relationshipFallbackEventTitle() -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipFallbackEventTitle())
    }

    static func relationshipFallbackEventSummary() -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipFallbackEventSummary())
    }

    static func relationshipFallbackQuote(playerName: String? = nil) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipFallbackQuote(),
            arguments: playerName.map { [.userText($0)] } ?? []
        )
    }

    static func relationshipFallbackChoiceTitle(response: RelationshipResponse) -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipFallbackChoiceTitle(response: response))
    }

    static func relationshipFallbackChoiceDetail(response: RelationshipResponse) -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipFallbackChoiceDetail(response: response))
    }

    static func relationshipAccessibilityEvent(
        speaker: String,
        name: String,
        title: String,
        primaryText: String,
        summary: String
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipAccessibilityEvent(),
            arguments: [.userText(speaker), .userText(name), .userText(title), .userText(primaryText), .userText(summary)]
        )
    }

    static func relationshipAccessibilityChoice(title: String, detail: String) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipAccessibilityChoice(),
            arguments: [.userText(title), .userText(detail)]
        )
    }

    static func relationshipWindLine(title: String, effects: String) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipWindLine(),
            arguments: [.userText(title), .userText(effects)]
        )
    }

    static func relationshipWindFavoredEffect(
        target: RelationshipTarget,
        bonus: Int
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipWindFavoredEffect(target: target),
            arguments: [.integer(bonus)]
        )
    }

    static func relationshipWindLossEffect(penalty: Int) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.relationshipWindLossEffect(),
            arguments: [.integer(penalty)]
        )
    }

    static func rivalArchetype(rivalID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.rivalArchetype(rivalID: rivalID))
    }

    static func rivalSignature(rivalID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.rivalSignature(rivalID: rivalID))
    }

    static func rivalFallbackName() -> CopyToken {
        CopyToken(key: PresentationCopyKey.rivalFallbackName())
    }

    static func rivalFallbackArchetype() -> CopyToken {
        CopyToken(key: PresentationCopyKey.rivalFallbackArchetype())
    }

    static func rivalFallbackSignature() -> CopyToken {
        CopyToken(key: PresentationCopyKey.rivalFallbackSignature())
    }
}

public enum RivalPresentationCatalog {
    public static let rivalIDs = [
        "rival-seo", "rival-lee", "rival-park", "rival-kang",
        "rival-yoon", "rival-choi", "rival-home-run", "rival-speed",
    ]

    public static let descriptors: [RivalPresentationCopyDescriptor] = rivalIDs.map {
        descriptor(for: $0)
    }

    public static func descriptor(for rivalID: String) -> RivalPresentationCopyDescriptor {
        let isKnown = rivalIDs.contains(rivalID)
        return RivalPresentationCopyDescriptor(
            rivalID: rivalID,
            isKnownRival: isKnown,
            nameToken: isKnown ? .rivalName(rivalID: rivalID) : .rivalFallbackName(),
            archetypeToken: isKnown ? .rivalArchetype(rivalID: rivalID) : .rivalFallbackArchetype(),
            signatureToken: isKnown ? .rivalSignature(rivalID: rivalID) : .rivalFallbackSignature()
        )
    }
}

public enum RelationshipPresentationCatalog {
    public static let trustBands: [RelationshipVoiceCatalog.TrustBand] = [.low, .mid, .high]

    private static let knownEventIDSet = Set(
        HighSchoolContentCatalog.relationshipEvents.map(\.id)
    )
    private static let knownCategoryIDSet = Set(
        HighSchoolContentCatalog.relationshipEvents.map(\.category)
    )

    /// This is a presentation inventory, not an event-selection list. Its order follows the
    /// existing authored event arrays and does not feed any engine iteration.
    public static let eventDescriptors: [RelationshipEventCopyDescriptor] =
        HighSchoolContentCatalog.relationshipEvents.map {
            eventDescriptor(eventID: $0.id, categoryID: $0.category)
        }

    public static let eventIDs = eventDescriptors.map(\.eventID)

    public static let categoryIDs: [String] = {
        var seen = Set<String>()
        return HighSchoolContentCatalog.relationshipEvents.compactMap { event in
            seen.insert(event.category).inserted ? event.category : nil
        }
    }()

    public static let sceneIDs = RelationshipVoiceCatalog.scenes.keys.sorted()
    public static let categorySceneIDs = RelationshipVoiceCatalog.categoryScenes.keys.sorted()

    public static let quoteDescriptors: [RelationshipQuoteCopyDescriptor] =
        sceneIDs.flatMap { eventID in
            trustBands.map {
                RelationshipQuoteCopyDescriptor(
                    eventID: eventID,
                    trustBand: $0,
                    token: .relationshipQuote(eventID: eventID, trustBand: $0)
                )
            }
        }

    public static let choiceDescriptors: [RelationshipChoiceCopyDescriptor] =
        sceneIDs.flatMap { eventID in
            RelationshipResponse.allCases.map { response in
                RelationshipChoiceCopyDescriptor(
                    scopeID: eventID,
                    response: response,
                    titleToken: .relationshipChoiceTitle(eventID: eventID, response: response),
                    detailToken: .relationshipChoiceDetail(eventID: eventID, response: response)
                )
            }
        } + categorySceneIDs.flatMap { categoryID in
            RelationshipResponse.allCases.map { response in
                RelationshipChoiceCopyDescriptor(
                    scopeID: "category.\(categoryID)",
                    response: response,
                    titleToken: .relationshipCategoryChoiceTitle(categoryID: categoryID, response: response),
                    detailToken: .relationshipCategoryChoiceDetail(categoryID: categoryID, response: response)
                )
            }
        } + RelationshipResponse.allCases.map { response in
            RelationshipChoiceCopyDescriptor(
                scopeID: "fallback",
                response: response,
                titleToken: .relationshipFallbackChoiceTitle(response: response),
                detailToken: .relationshipFallbackChoiceDetail(response: response)
            )
        }

    public static func eventDescriptor(for event: CareerEventContent) -> RelationshipEventCopyDescriptor {
        eventDescriptor(eventID: event.id, categoryID: event.category)
    }

    public static func eventDescriptor(
        eventID: String,
        categoryID: String
    ) -> RelationshipEventCopyDescriptor {
        let isKnownEvent = knownEventIDSet.contains(eventID)
        let isKnownCategory = knownCategoryIDSet.contains(categoryID)
        let categoryKey = isKnownCategory ? categoryID : "fallback"
        return RelationshipEventCopyDescriptor(
            eventID: eventID,
            categoryID: categoryID,
            isKnownEvent: isKnownEvent,
            titleToken: isKnownEvent
                ? .highSchoolEventTitle(eventID: eventID)
                : .relationshipFallbackEventTitle(),
            summaryToken: isKnownEvent
                ? .highSchoolEventSummary(eventID: eventID)
                : .relationshipFallbackEventSummary(),
            categoryLabelToken: .relationshipCategoryLabel(categoryID: categoryKey),
            speakerLabelToken: .relationshipSpeakerLabel(categoryID: categoryKey)
        )
    }

    public static func cardDescriptor(for event: CareerEventContent) -> RelationshipCardCopyDescriptor {
        let eventDescriptor = eventDescriptor(for: event)
        if let scene = RelationshipVoiceCatalog.scenes[event.id], eventDescriptor.isKnownEvent {
            return RelationshipCardCopyDescriptor(
                event: eventDescriptor,
                sceneSpeaker: scene.speaker,
                quoteDescriptors: trustBands.map {
                    RelationshipQuoteCopyDescriptor(
                        eventID: event.id,
                        trustBand: $0,
                        token: .relationshipQuote(eventID: event.id, trustBand: $0)
                    )
                },
                choiceDescriptors: choices(scopeID: event.id, fixedScene: true)
            )
        }
        if let scene = RelationshipVoiceCatalog.categoryScenes[event.category], eventDescriptor.isKnownEvent {
            return RelationshipCardCopyDescriptor(
                event: eventDescriptor,
                sceneSpeaker: scene.speaker,
                quoteDescriptors: [],
                choiceDescriptors: choices(scopeID: event.category, fixedScene: false)
            )
        }
        return RelationshipCardCopyDescriptor(
            event: eventDescriptor,
            sceneSpeaker: .named("fallback"),
            quoteDescriptors: [],
            choiceDescriptors: choices(scopeID: "fallback", fixedScene: false, fallback: true)
        )
    }

    public static func fallbackCardDescriptor(
        eventID: String,
        categoryID: String
    ) -> RelationshipCardCopyDescriptor {
        let event = eventDescriptor(eventID: eventID, categoryID: categoryID)
        return RelationshipCardCopyDescriptor(
            event: event,
            sceneSpeaker: .named("fallback"),
            quoteDescriptors: [],
            choiceDescriptors: choices(scopeID: "fallback", fixedScene: false, fallback: true)
        )
    }

    public static func windDescriptor(
        for wind: CareerWind,
        target: RelationshipTarget
    ) -> RelationshipWindCopyDescriptor {
        let rules = wind.rules
        let favoredEffectToken: CopyToken? =
            rules.favoredRelationship == target && rules.favoredRelationshipBonus != 0
                ? .relationshipWindFavoredEffect(
                    target: target,
                    bonus: rules.favoredRelationshipBonus
                )
                : nil
        let lossEffectToken: CopyToken? = rules.relationshipLossPenalty != 0
            ? .relationshipWindLossEffect(penalty: rules.relationshipLossPenalty)
            : nil
        return RelationshipWindCopyDescriptor(
            target: target,
            careerWind: CareerWindPresentationCatalog.descriptor(for: wind),
            favoredEffectToken: favoredEffectToken,
            lossEffectToken: lossEffectToken
        )
    }

    private static func choices(
        scopeID: String,
        fixedScene: Bool,
        fallback: Bool = false
    ) -> [RelationshipChoiceCopyDescriptor] {
        RelationshipResponse.allCases.map { response in
            let titleToken: CopyToken
            let detailToken: CopyToken
            if fallback {
                titleToken = .relationshipFallbackChoiceTitle(response: response)
                detailToken = .relationshipFallbackChoiceDetail(response: response)
            } else if fixedScene {
                titleToken = .relationshipChoiceTitle(eventID: scopeID, response: response)
                detailToken = .relationshipChoiceDetail(eventID: scopeID, response: response)
            } else {
                titleToken = .relationshipCategoryChoiceTitle(categoryID: scopeID, response: response)
                detailToken = .relationshipCategoryChoiceDetail(categoryID: scopeID, response: response)
            }
            return RelationshipChoiceCopyDescriptor(
                scopeID: fallback ? "fallback" : fixedScene ? scopeID : "category.\(scopeID)",
                response: response,
                titleToken: titleToken,
                detailToken: detailToken
            )
        }
    }
}
