/// Presentation descriptors for the first screen of a high-school career.
///
/// These values are ephemeral display metadata. They are derived from stable IDs, the stored
/// rules version, and the typed rule fields; they never enter a snapshot, commitment, RNG stream,
/// or analytics payload.

public enum PrologueOpenerVariant: String, CaseIterable, Sendable {
    case firstLife = "first-life"
    case repeatLifeFirst = "repeat-life-1"
    case repeatLifeSecond = "repeat-life-2"
    case repeatLifeThird = "repeat-life-3"
    case fallback

    public static func resolve(lifeNumber: Int) -> Self {
        switch lifeNumber {
        case 1:
            return .firstLife
        case 2...:
            switch (lifeNumber - 2) % 3 {
            case 0: return .repeatLifeFirst
            case 1: return .repeatLifeSecond
            default: return .repeatLifeThird
            }
        default:
            return .fallback
        }
    }
}

public struct PrologueCopyDescriptor: Equatable, Sendable {
    public let variant: PrologueOpenerVariant
    public let region: SchoolRegionID?
    public let openerToken: CopyToken

    public init(lifeNumber: Int, region: SchoolRegionID) {
        let variant = PrologueOpenerVariant.resolve(lifeNumber: lifeNumber)
        self.init(variant: variant, region: variant == .fallback ? nil : region)
    }

    public init(lifeNumber: Int, rawRegion: String) {
        guard let region = SchoolRegionID.strictLookup(rawRegion: rawRegion) else {
            self.init(variant: .fallback, region: nil)
            return
        }
        self.init(lifeNumber: lifeNumber, region: region)
    }

    public init(variant: PrologueOpenerVariant, region: SchoolRegionID?) {
        self.variant = variant
        self.region = variant == .fallback ? nil : region
        self.openerToken = .prologueOpener(
            variant: variant,
            region: variant == .fallback ? nil : region
        )
    }
}

public struct KarmaCopyDescriptor: Equatable, Sendable {
    public let id: KarmaID
    public let titleToken: CopyToken
    public let detailToken: CopyToken

    public init(id: KarmaID) {
        self.id = id
        self.titleToken = .karmaTitle(id)
        self.detailToken = .karmaDetail(id)
    }
}

public struct CareerWindEffectCopyDescriptor: Equatable, Sendable {
    public let slot: String
    public let token: CopyToken

    public init(slot: String, token: CopyToken) {
        self.slot = slot
        self.token = token
    }
}

public struct CareerWindCopyDescriptor: Equatable, Sendable {
    public let id: String
    public let rulesVersion: CareerRulesVersion
    public let titleToken: CopyToken
    public let detailToken: CopyToken
    public let effectDescriptors: [CareerWindEffectCopyDescriptor]

    public init(
        id: String,
        rulesVersion: CareerRulesVersion,
        titleToken: CopyToken,
        detailToken: CopyToken,
        effectDescriptors: [CareerWindEffectCopyDescriptor]
    ) {
        self.id = id
        self.rulesVersion = rulesVersion
        self.titleToken = titleToken
        self.detailToken = detailToken
        self.effectDescriptors = effectDescriptors
    }

    public var effectTokens: [CopyToken] {
        effectDescriptors.map(\.token)
    }
}

public enum ProloguePresentationCatalog {
    public static let openerDescriptors: [PrologueCopyDescriptor] =
        PrologueOpenerVariant.allCases.map { variant in
            PrologueCopyDescriptor(
                variant: variant,
                region: variant == .fallback ? nil : .seoul
            )
        }

    public static let karmaDescriptors: [KarmaCopyDescriptor] = KarmaPresentationCatalog.descriptors

    public static func opener(lifeNumber: Int, region: SchoolRegionID) -> PrologueCopyDescriptor {
        PrologueCopyDescriptor(lifeNumber: lifeNumber, region: region)
    }

    public static func opener(lifeNumber: Int, rawRegion: String) -> PrologueCopyDescriptor {
        PrologueCopyDescriptor(lifeNumber: lifeNumber, rawRegion: rawRegion)
    }

    public static func karma(_ id: KarmaID) -> KarmaCopyDescriptor {
        KarmaPresentationCatalog.descriptor(for: id)
    }
}

public enum KarmaPresentationCatalog {
    public static let descriptors: [KarmaCopyDescriptor] =
        KarmaID.allCases.map(KarmaCopyDescriptor.init(id:))

    public static func descriptor(for id: KarmaID) -> KarmaCopyDescriptor {
        KarmaCopyDescriptor(id: id)
    }
}

public enum CareerWindPresentationCatalog {
    /// The duplicate calm entry in the v1 selector is a compatibility pool slot, not a distinct
    /// display variant. The pool itself remains untouched in CareerWind.all.
    public static let v1PoolDescriptors: [CareerWindCopyDescriptor] = CareerWind.all.map(makeDescriptor)
    public static let v1Winds: [CareerWind] = uniqueWinds(CareerWind.all)
    public static let v2Winds: [CareerWind] = CareerWind.v2All

    public static let v1Descriptors: [CareerWindCopyDescriptor] = v1Winds.map(makeDescriptor)
    public static let v2Descriptors: [CareerWindCopyDescriptor] = v2Winds.map(makeDescriptor)
    public static let descriptors: [CareerWindCopyDescriptor] = v1Descriptors + v2Descriptors

    public static let fallback = CareerWindCopyDescriptor(
        id: "fallback",
        rulesVersion: .v1,
        titleToken: CopyToken(
            key: PresentationCopyKey.stableID(family: .careerWind, id: "fallback", slot: "title")
        ),
        detailToken: CopyToken(
            key: PresentationCopyKey.stableID(family: .careerWind, id: "fallback", slot: "detail")
        ),
        effectDescriptors: []
    )

    public static func descriptor(for wind: CareerWind) -> CareerWindCopyDescriptor {
        guard descriptors.contains(where: { $0.id == wind.id && $0.rulesVersion == wind.rulesVersion }) else {
            return fallback
        }
        return makeDescriptor(wind)
    }

    private static func uniqueWinds(_ winds: [CareerWind]) -> [CareerWind] {
        var seen = Set<String>()
        return winds.filter { wind in
            let key = "\(wind.rulesVersion.rawValue):\(wind.id)"
            return seen.insert(key).inserted
        }
    }

    private static func makeDescriptor(_ wind: CareerWind) -> CareerWindCopyDescriptor {
        CareerWindCopyDescriptor(
            id: wind.id,
            rulesVersion: wind.rulesVersion,
            titleToken: .careerWindTitle(id: wind.id, rulesVersion: wind.rulesVersion),
            detailToken: .careerWindDetail(id: wind.id, rulesVersion: wind.rulesVersion),
            effectDescriptors: effectDescriptors(for: wind)
        )
    }

    /// Mirrors CareerWind.effectDescriptions' order while reading only typed simulation fields.
    private static func effectDescriptors(for wind: CareerWind) -> [CareerWindEffectCopyDescriptor] {
        let rules = wind.rules
        var result: [CareerWindEffectCopyDescriptor] = []

        if let focus = rules.favoredTraining, rules.favoredTrainingBonus != 0 {
            result.append(effect(
                wind: wind,
                slot: "favored-training.\(focus.rawValue)",
                arguments: [.integer(rules.favoredTrainingBonus)]
            ))
        }
        if rules.recoveryBonus != 0 {
            result.append(effect(
                wind: wind,
                slot: "recovery",
                arguments: [.integer(rules.recoveryBonus)]
            ))
        }
        if let target = rules.favoredRelationship, rules.favoredRelationshipBonus != 0 {
            result.append(effect(
                wind: wind,
                slot: "favored-relationship.\(target.rawValue)",
                arguments: [.integer(rules.favoredRelationshipBonus)]
            ))
        }
        if rules.fanInterestGainBonus != 0 {
            result.append(effect(
                wind: wind,
                slot: "fan-interest",
                arguments: [.integer(rules.fanInterestGainBonus)]
            ))
        }
        if rules.draftEvaluationDelta != 0 {
            result.append(effect(
                wind: wind,
                slot: "draft-evaluation",
                arguments: [.integer(rules.draftEvaluationDelta)]
            ))
        }
        if wind.startingFanInterest != 5 {
            result.append(effect(
                wind: wind,
                slot: "starting-fan-interest",
                arguments: [.integer(wind.startingFanInterest)]
            ))
        }
        if wind.rivalBonus != 0 {
            result.append(effect(
                wind: wind,
                slot: "rival-ability",
                arguments: [.integer(wind.rivalBonus)]
            ))
        }
        if rules.trainingFatigueDelta != 0 {
            result.append(effect(
                wind: wind,
                slot: "training-fatigue",
                arguments: [.integer(rules.trainingFatigueDelta)]
            ))
        }
        if let focus = rules.extraFatigueFocus, rules.extraFatigueDelta != 0 {
            result.append(effect(
                wind: wind,
                slot: "extra-fatigue.\(focus.rawValue)",
                arguments: [.integer(rules.extraFatigueDelta)]
            ))
        }
        if rules.relationshipLossPenalty != 0 {
            result.append(effect(
                wind: wind,
                slot: "relationship-loss",
                arguments: [.integer(rules.relationshipLossPenalty)]
            ))
        }
        if wind.rewardBonusPermille != 0 {
            result.append(effect(
                wind: wind,
                slot: "inheritance-bonus",
                arguments: [.integer(wind.rewardBonusPermille / 10)]
            ))
        }
        return result
    }

    private static func effect(
        wind: CareerWind,
        slot: String,
        arguments: [CopyArgument]
    ) -> CareerWindEffectCopyDescriptor {
        CareerWindEffectCopyDescriptor(
            slot: slot,
            token: .careerWindEffect(
                id: wind.id,
                rulesVersion: wind.rulesVersion,
                slot: slot,
                arguments: arguments
            )
        )
    }
}

public extension KarmaID {
    var copyDescriptor: KarmaCopyDescriptor {
        KarmaPresentationCatalog.descriptor(for: self)
    }
}

public extension CareerWind {
    var copyDescriptor: CareerWindCopyDescriptor {
        CareerWindPresentationCatalog.descriptor(for: self)
    }
}
