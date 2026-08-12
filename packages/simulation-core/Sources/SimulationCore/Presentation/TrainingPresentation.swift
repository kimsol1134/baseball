/// Semantic presentation descriptors for the high-school chapter and training surfaces.
///
/// These values are derived from stable IDs, closed enums, and the already-persisted legacy
/// values. They are deliberately not Codable: adding English copy must not add fields to a save,
/// alter a state commitment, consume RNG, or change event ordering.

public enum ChapterSeasonID: String, CaseIterable, Sendable {
    case spring
    case summer
    case autumn
    case winter

    public init?(rawSeason: String) {
        switch rawSeason {
        case "봄": self = .spring
        case "여름": self = .summer
        case "가을": self = .autumn
        case "겨울": self = .winter
        default: return nil
        }
    }
}

public struct CareerChapterCopyDescriptor: Equatable, Sendable {
    public let number: Int
    public let actNumber: Int?
    public let titleToken: CopyToken
    public let actTitleToken: CopyToken
    public let seasonToken: CopyToken

    public init(
        number: Int,
        actNumber: Int?,
        titleToken: CopyToken,
        actTitleToken: CopyToken,
        seasonToken: CopyToken
    ) {
        self.number = number
        self.actNumber = actNumber
        self.titleToken = titleToken
        self.actTitleToken = actTitleToken
        self.seasonToken = seasonToken
    }
}

public enum CareerChapterPresentationCatalog {
    public static let descriptors: [CareerChapterCopyDescriptor] = (1...8).map { number in
        let act = actNumber(for: number)
        let season = season(for: number)
        return CareerChapterCopyDescriptor(
            number: number,
            actNumber: act,
            titleToken: .chapterTitle(number: number),
            actTitleToken: .chapterActTitle(number: act),
            seasonToken: .chapterSeason(season)
        )
    }

    public static let fallback = CareerChapterCopyDescriptor(
        number: 0,
        actNumber: nil,
        titleToken: .chapterFallbackTitle(),
        actTitleToken: .chapterFallbackActTitle(),
        seasonToken: .chapterFallbackSeason()
    )

    public static func descriptor(for chapter: CareerChapterSnapshot) -> CareerChapterCopyDescriptor {
        guard let descriptor = descriptors.first(where: { $0.number == chapter.number }),
              let season = ChapterSeasonID(rawSeason: chapter.season) else {
            return fallback
        }
        return CareerChapterCopyDescriptor(
            number: descriptor.number,
            actNumber: descriptor.actNumber,
            titleToken: descriptor.titleToken,
            actTitleToken: descriptor.actTitleToken,
            seasonToken: .chapterSeason(season)
        )
    }

    public static func descriptor(number: Int, rawSeason: String) -> CareerChapterCopyDescriptor {
        guard let chapter = descriptors.first(where: { $0.number == number }),
              let season = ChapterSeasonID(rawSeason: rawSeason) else {
            return fallback
        }
        return CareerChapterCopyDescriptor(
            number: chapter.number,
            actNumber: chapter.actNumber,
            titleToken: chapter.titleToken,
            actTitleToken: chapter.actTitleToken,
            seasonToken: .chapterSeason(season)
        )
    }

    private static func actNumber(for chapter: Int) -> Int {
        min(4, max(1, (chapter + 1) / 2))
    }

    private static func season(for chapter: Int) -> ChapterSeasonID {
        switch chapter {
        case 1, 4: .spring
        case 2, 8: .summer
        case 3, 7: .winter
        default: .autumn
        }
    }
}

public struct TrainingOpportunityCopyDescriptor: Equatable, Sendable {
    public let focus: TrainingFocus
    /// Nil means the persisted reason was not one of the shipped reasons for this focus.
    public let reasonSlot: Int?
    public let token: CopyToken

    public init(focus: TrainingFocus, reasonSlot: Int?, token: CopyToken) {
        self.focus = focus
        self.reasonSlot = reasonSlot
        self.token = token
    }

    public var isFallback: Bool { reasonSlot == nil }
}

public struct TrainingOutlookCopyDescriptor: Equatable, Sendable {
    public let outlook: HighSchoolCareerEngine.TrainingGrowthOutlook
    public let token: CopyToken

    public init(
        outlook: HighSchoolCareerEngine.TrainingGrowthOutlook,
        token: CopyToken
    ) {
        self.outlook = outlook
        self.token = token
    }
}

public extension PresentationCopyKey {
    static func chapterActTitle(number: Int) -> String {
        stableID(family: .chapter, id: "act-\(number)", slot: "title")
    }

    static func chapterSeason(_ season: ChapterSeasonID) -> String {
        stableID(family: .chapter, id: "season-\(season.rawValue)", slot: "name")
    }

    static func chapterFallbackTitle() -> String {
        stableID(family: .chapter, id: "fallback", slot: "title")
    }

    static func chapterFallbackActTitle() -> String {
        stableID(family: .chapter, id: "fallback", slot: "act-title")
    }

    static func chapterFallbackSeason() -> String {
        stableID(family: .chapter, id: "fallback", slot: "season")
    }

    static func trainingFocusDetail(_ focus: TrainingFocus) -> String {
        stableID(family: .trainingFocus, id: focus.rawValue, slot: "detail")
    }

    static func trainingFocusTradeoff(_ focus: TrainingFocus) -> String {
        stableID(family: .trainingFocus, id: focus.rawValue, slot: "tradeoff")
    }

    static func trainingFocusMetric(_ focus: TrainingFocus) -> String {
        stableID(family: .trainingFocus, id: focus.rawValue, slot: "metric")
    }

    static func trainingRecoveryIntensity(_ intensity: TrainingIntensity) -> String {
        stableID(family: .trainingIntensity, id: "recovery.\(intensity.rawValue)", slot: "label")
    }

    static func trainingOpportunityReason(focus: TrainingFocus, slot: Int) -> String {
        stableID(
            family: .trainingOpportunity,
            id: focus.rawValue,
            slot: "reason.\(slot)"
        )
    }

    static func trainingOpportunityFallbackReason(focus: TrainingFocus) -> String {
        stableID(family: .trainingOpportunity, id: focus.rawValue, slot: "reason.fallback")
    }

    static func trainingOutlook(_ outlook: HighSchoolCareerEngine.TrainingGrowthOutlook) -> String {
        let id: String = switch outlook {
        case .wall: "wall"
        case .none: "none"
        case .zeroOrOne: "zero-or-one"
        case .one: "one"
        case .oneOrTwo: "one-or-two"
        case .two: "two"
        }
        return stableID(family: .trainingOutlook, id: id, slot: "detail")
    }

    static func trainingAbility(_ ability: TalentAbility) -> String {
        stableID(family: .trainingAbility, id: ability.rawValue, slot: "label")
    }

    static func talentGrade(_ grade: TalentGrade) -> String {
        stableID(family: .talentGrade, id: grade.rawValue, slot: "label")
    }
}

public extension CopyToken {
    static func chapterActTitle(number: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterActTitle(number: number))
    }

    static func chapterSeason(_ season: ChapterSeasonID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterSeason(season))
    }

    static func chapterFallbackTitle() -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterFallbackTitle())
    }

    static func chapterFallbackActTitle() -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterFallbackActTitle())
    }

    static func chapterFallbackSeason() -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterFallbackSeason())
    }

    static func trainingFocusDetail(_ focus: TrainingFocus) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingFocusDetail(focus))
    }

    static func trainingFocusTradeoff(_ focus: TrainingFocus) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingFocusTradeoff(focus))
    }

    static func trainingFocusMetric(_ focus: TrainingFocus) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingFocusMetric(focus))
    }

    static func trainingRecoveryIntensity(_ intensity: TrainingIntensity) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingRecoveryIntensity(intensity))
    }

    static func trainingOpportunityReason(focus: TrainingFocus, slot: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingOpportunityReason(focus: focus, slot: slot))
    }

    static func trainingOpportunityFallbackReason(focus: TrainingFocus) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingOpportunityFallbackReason(focus: focus))
    }

    static func trainingOutlook(_ outlook: HighSchoolCareerEngine.TrainingGrowthOutlook) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingOutlook(outlook))
    }

    static func trainingAbility(_ ability: TalentAbility) -> CopyToken {
        CopyToken(key: PresentationCopyKey.trainingAbility(ability))
    }

    static func talentGrade(_ grade: TalentGrade) -> CopyToken {
        CopyToken(key: PresentationCopyKey.talentGrade(grade))
    }
}

public extension TrainingFocus {
    var detailCopyToken: CopyToken { .trainingFocusDetail(self) }
    var tradeoffCopyToken: CopyToken { .trainingFocusTradeoff(self) }
    var metricCopyToken: CopyToken { .trainingFocusMetric(self) }
}

public extension TrainingIntensity {
    var recoveryCopyToken: CopyToken { .trainingRecoveryIntensity(self) }
}

public extension HighSchoolCareerEngine.TrainingGrowthOutlook {
    static var allCases: [Self] { [.wall, .none, .zeroOrOne, .one, .oneOrTwo, .two] }

    var detailCopyToken: CopyToken { .trainingOutlook(self) }
}

public extension TalentAbility {
    var displayCopyToken: CopyToken { .trainingAbility(self) }
}

public extension TalentGrade {
    var displayCopyToken: CopyToken { .talentGrade(self) }
}

public extension TrainingOpportunitySnapshot {
    var copyDescriptor: TrainingOpportunityCopyDescriptor {
        TrainingPresentationCatalog.opportunity(self)
    }
}

public enum TrainingPresentationCatalog {
    /// Every shipped opportunity reason has a stable focus + slot identity. The raw Korean text
    /// is used only for this strict reverse lookup and never appears in a copy token.
    public static let opportunityReasonDescriptors: [TrainingOpportunityCopyDescriptor] =
        TrainingFocus.allCases.flatMap { focus in
            (0..<3).map { slot in
                TrainingOpportunityCopyDescriptor(
                    focus: focus,
                    reasonSlot: slot,
                    token: .trainingOpportunityReason(focus: focus, slot: slot)
                )
            }
        }

    public static let opportunityFallbackDescriptors: [TrainingOpportunityCopyDescriptor] =
        TrainingFocus.allCases.map { focus in
            TrainingOpportunityCopyDescriptor(
                focus: focus,
                reasonSlot: nil,
                token: .trainingOpportunityFallbackReason(focus: focus)
            )
        }

    public static let focusDetailDescriptors: [PresentationCopyDescriptor] =
        TrainingFocus.allCases.map {
            PresentationCopyDescriptor(
                family: .trainingFocus,
                rawValue: $0.rawValue,
                token: $0.detailCopyToken
            )
        }

    public static let focusTradeoffDescriptors: [PresentationCopyDescriptor] =
        TrainingFocus.allCases.map {
            PresentationCopyDescriptor(
                family: .trainingFocus,
                rawValue: $0.rawValue,
                token: $0.tradeoffCopyToken
            )
        }

    public static let focusMetricDescriptors: [PresentationCopyDescriptor] =
        TrainingFocus.allCases.map {
            PresentationCopyDescriptor(
                family: .trainingFocus,
                rawValue: $0.rawValue,
                token: $0.metricCopyToken
            )
        }

    public static let recoveryIntensityDescriptors: [PresentationCopyDescriptor] =
        TrainingIntensity.allCases.map {
            PresentationCopyDescriptor(
                family: .trainingIntensity,
                rawValue: $0.rawValue,
                token: $0.recoveryCopyToken
            )
        }

    public static let outlookDescriptors: [TrainingOutlookCopyDescriptor] =
        HighSchoolCareerEngine.TrainingGrowthOutlook.allCases.map {
            TrainingOutlookCopyDescriptor(outlook: $0, token: $0.detailCopyToken)
        }

    public static let abilityDescriptors: [PresentationCopyDescriptor] =
        TalentAbility.allCases.map {
            PresentationCopyDescriptor(
                family: .trainingAbility,
                rawValue: $0.rawValue,
                token: $0.displayCopyToken
            )
        }

    public static let gradeDescriptors: [PresentationCopyDescriptor] =
        TalentGrade.allCases.map {
            PresentationCopyDescriptor(
                family: .talentGrade,
                rawValue: $0.rawValue,
                token: $0.displayCopyToken
            )
        }

    public static func opportunity(
        _ opportunity: TrainingOpportunitySnapshot
    ) -> TrainingOpportunityCopyDescriptor {
        guard let reasons = HighSchoolCareerEngine.opportunityReasons[opportunity.focus],
              let slot = reasons.firstIndex(of: opportunity.reason) else {
            return opportunityFallbackDescriptors.first { $0.focus == opportunity.focus }
                ?? TrainingOpportunityCopyDescriptor(
                    focus: opportunity.focus,
                    reasonSlot: nil,
                    token: .trainingOpportunityFallbackReason(focus: opportunity.focus)
                )
        }
        return TrainingOpportunityCopyDescriptor(
            focus: opportunity.focus,
            reasonSlot: slot,
            token: .trainingOpportunityReason(focus: opportunity.focus, slot: slot)
        )
    }
}

public extension CareerChapterSnapshot {
    var copyDescriptor: CareerChapterCopyDescriptor {
        CareerChapterPresentationCatalog.descriptor(for: self)
    }
}
