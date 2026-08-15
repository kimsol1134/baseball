/// A stable semantic family used by the presentation boundary.
///
/// These values describe content identity, not a language or a rendered sentence. They are
/// intentionally kept in SimulationCore so every client can agree on the same identifiers.
public enum PresentationCopyFamily: String, CaseIterable, Sendable {
    case event
    case importantGame = "important-game"
    case relationship
    case school
    case chapter
    case draftTeam = "draft-team"
    case rival
    case nickname
    case pitchType = "pitch-type"
    case pitchIntensity = "pitch-intensity"
    case pitchUsage = "pitch-usage"
    case batterSide = "batter-side"
    case pitchOutcome = "pitch-outcome"
    case zoneIntent = "zone-intent"
    case highSchoolPhase = "high-school-phase"
    case trainingFocus = "training-focus"
    case trainingIntensity = "training-intensity"
    case trainingOpportunity = "training-opportunity"
    case trainingOutlook = "training-outlook"
    case trainingAbility = "training-ability"
    case talentGrade = "talent-grade"
    case relationshipTarget = "relationship-target"
    case relationshipResponse = "relationship-response"
    case draftOutcome = "draft-outcome"
    case armHealth = "arm-health"
    case proCareerPhase = "pro-career-phase"
    case proLevel = "pro-level"
    case proRole = "pro-role"
    case proWeekPlan = "pro-week-plan"
    case offseasonDecision = "offseason-decision"
    case proSeasonDecisionType = "pro-season-decision-type"
    case proSeasonSegment = "pro-season-segment"
    case proSeasonTrigger = "pro-season-trigger"
    case awakening
    case awakeningBranch = "awakening-branch"
    case memory
    case signatureLegacy = "signature-legacy"
    case proDecision = "pro-decision"
    case pitcherPreset = "pitcher-preset"
    case careerWind = "career-wind"
    case karma
    case prologue
    case chapterReview = "chapter-review"
    case tournament
    case chapterGoal = "chapter-goal"
    case draftResult = "draft-result"
    case personality
    case chronicle
}

/// Typed values passed across the language-neutral presentation boundary.
///
/// This is deliberately not `Codable`: a presentation token is ephemeral UI input. It must not
/// become part of a save payload, event hash, RNG seed, or persisted simulation state.
public enum CopyArgument: Equatable, Sendable {
    case userText(String)
    case contentID(String)
    case integer(Int)
    case decimal(Double)
}

/// A language-neutral reference to display copy.
///
/// `key` is a semantic ID such as `content.event.evt-catcher-sign.title`; it is never a Korean
/// source sentence. The iOS presentation layer maps this ID to its localized catalog entry.
public struct CopyToken: Equatable, Sendable {
    public let key: String
    public let arguments: [CopyArgument]

    public init(key: String, arguments: [CopyArgument] = []) {
        self.key = key
        self.arguments = arguments
    }
}

/// A closed-set enum value and its stable presentation token.
///
/// The descriptor is an inventory contract for clients: every value that can be rendered by a
/// migrated enum helper appears here, while the enum's raw value remains the only ID component.
public struct PresentationCopyDescriptor: Equatable, Sendable {
    public let family: PresentationCopyFamily
    public let rawValue: String
    public let token: CopyToken

    public init(family: PresentationCopyFamily, rawValue: String, token: CopyToken) {
        self.family = family
        self.rawValue = rawValue
        self.token = token
    }
}

/// An explicit inventory descriptor for every current pitcher-preset display slot.
///
/// This list is presentation metadata only. It intentionally carries the preset ID and slot,
/// never the rendered Korean or English value, so catalog clients can prove coverage without
/// coupling localization to simulation data or persistence.
public struct PitcherPresetCopyDescriptor: Equatable, Sendable {
    public let presetID: String
    public let slot: String
    public let token: CopyToken

    public init(presetID: String, slot: String, token: CopyToken) {
        self.presetID = presetID
        self.slot = slot
        self.token = token
    }
}

/// Presentation-only copy descriptors for the complete awakening catalog.
///
/// The IDs and tokens are ephemeral display metadata. They are deliberately not Codable and do
/// not contain rendered Korean or English strings, so localization cannot enter saves, RNG, or
/// event commitments.
public struct AwakeningCopyDescriptor: Equatable, Sendable {
    public let id: AwakeningID
    public let titleToken: CopyToken
    public let detailToken: CopyToken

    public init(id: AwakeningID, titleToken: CopyToken, detailToken: CopyToken) {
        self.id = id
        self.titleToken = titleToken
        self.detailToken = detailToken
    }
}

/// Presentation-only copy descriptors for the four stable awakening branches.
public struct AwakeningBranchCopyDescriptor: Equatable, Sendable {
    public let branch: AwakeningTree.Branch
    public let titleToken: CopyToken
    public let detailToken: CopyToken

    public init(
        branch: AwakeningTree.Branch,
        titleToken: CopyToken,
        detailToken: CopyToken
    ) {
        self.branch = branch
        self.titleToken = titleToken
        self.detailToken = detailToken
    }
}

/// Semantic key builders shared by core token factories. The builders preserve stable IDs
/// exactly as authored; they do not transliterate, normalize, or look up content values.
public enum PresentationCopyKey {
    public static func stableID(
        family: PresentationCopyFamily,
        id: String,
        slot: String
    ) -> String {
        "content.\(family.rawValue).\(id).\(slot)"
    }

    public static func highSchoolEventTitle(eventID: String) -> String {
        stableID(family: .event, id: eventID, slot: "title")
    }

    public static func highSchoolEventSummary(eventID: String) -> String {
        stableID(family: .event, id: eventID, slot: "summary")
    }

    public static func relationshipQuote(
        eventID: String,
        trustBand: RelationshipVoiceCatalog.TrustBand
    ) -> String {
        stableID(family: .relationship, id: eventID, slot: "quote.\(trustBand.rawValue)")
    }

    public static func relationshipChoiceTitle(
        eventID: String,
        response: RelationshipResponse
    ) -> String {
        stableID(family: .relationship, id: eventID, slot: "choice.\(response.rawValue).title")
    }

    public static func relationshipChoiceDetail(
        eventID: String,
        response: RelationshipResponse
    ) -> String {
        stableID(family: .relationship, id: eventID, slot: "choice.\(response.rawValue).detail")
    }

    public static func schoolName(schoolID: SchoolID) -> String {
        stableID(family: .school, id: schoolID.rawValue, slot: "name")
    }

    public static func schoolPhilosophy(schoolID: SchoolID) -> String {
        stableID(family: .school, id: schoolID.rawValue, slot: "philosophy")
    }

    public static func schoolTradeoff(schoolID: SchoolID) -> String {
        stableID(family: .school, id: schoolID.rawValue, slot: "tradeoff")
    }

    public static func chapterTitle(number: Int) -> String {
        stableID(family: .chapter, id: "chapter-\(number)", slot: "title")
    }

    public static func chapterTheme(number: Int) -> String {
        stableID(family: .chapter, id: "chapter-\(number)", slot: "theme")
    }

    public static func draftTeamName(teamID: String) -> String {
        stableID(family: .draftTeam, id: teamID, slot: "name")
    }

    public static func rivalName(rivalID: String) -> String {
        stableID(family: .rival, id: rivalID, slot: "name")
    }

    public static func nicknameTitle(nicknameID: String) -> String {
        stableID(family: .nickname, id: nicknameID, slot: "title")
    }

    public static func pitchTypeName(pitchType: PitchType) -> String {
        stableID(family: .pitchType, id: pitchType.rawValue, slot: "name")
    }

    public static func closedEnumLabel(
        family: PresentationCopyFamily,
        rawValue: String
    ) -> String {
        stableID(family: family, id: rawValue, slot: "label")
    }

    public static func pitchIntensityLabel(_ intensity: PitchIntensity) -> String {
        closedEnumLabel(family: .pitchIntensity, rawValue: intensity.rawValue)
    }

    public static func pitchUsageRoleLabel(_ role: PitchUsageRole) -> String {
        closedEnumLabel(family: .pitchUsage, rawValue: role.rawValue)
    }

    public static func batterSideLabel(_ side: BatSide) -> String {
        closedEnumLabel(family: .batterSide, rawValue: side.rawValue)
    }

    public static func pitchOutcomeLabel(_ outcome: PitchOutcome) -> String {
        closedEnumLabel(family: .pitchOutcome, rawValue: outcome.rawValue)
    }

    public static func zoneIntentLabel(_ intent: ZoneIntent) -> String {
        closedEnumLabel(family: .zoneIntent, rawValue: intent.rawValue)
    }

    public static func highSchoolCareerPhaseLabel(_ phase: HighSchoolCareerPhase) -> String {
        closedEnumLabel(family: .highSchoolPhase, rawValue: phase.rawValue)
    }

    public static func trainingFocusLabel(_ focus: TrainingFocus) -> String {
        closedEnumLabel(family: .trainingFocus, rawValue: focus.rawValue)
    }

    public static func trainingIntensityLabel(_ intensity: TrainingIntensity) -> String {
        closedEnumLabel(family: .trainingIntensity, rawValue: intensity.rawValue)
    }

    public static func relationshipTargetLabel(_ target: RelationshipTarget) -> String {
        closedEnumLabel(family: .relationshipTarget, rawValue: target.rawValue)
    }

    public static func relationshipResponseLabel(_ response: RelationshipResponse) -> String {
        closedEnumLabel(family: .relationshipResponse, rawValue: response.rawValue)
    }

    public static func draftOutcomeLabel(_ outcome: DraftOutcome) -> String {
        closedEnumLabel(family: .draftOutcome, rawValue: outcome.rawValue)
    }

    public static func armHealthStateLabel(_ state: ArmHealthState) -> String {
        closedEnumLabel(family: .armHealth, rawValue: state.rawValue)
    }

    public static func proCareerPhaseLabel(_ phase: ProCareerPhase) -> String {
        closedEnumLabel(family: .proCareerPhase, rawValue: phase.rawValue)
    }

    public static func proLevelLabel(_ level: ProLevel) -> String {
        closedEnumLabel(family: .proLevel, rawValue: level.rawValue)
    }

    public static func proRoleLabel(_ role: ProRole) -> String {
        closedEnumLabel(family: .proRole, rawValue: role.rawValue)
    }

    public static func proWeekPlanLabel(_ plan: ProWeekPlan) -> String {
        closedEnumLabel(family: .proWeekPlan, rawValue: plan.rawValue)
    }

    public static func offseasonDecisionLabel(_ decision: OffseasonDecision) -> String {
        closedEnumLabel(family: .offseasonDecision, rawValue: decision.rawValue)
    }

    public static func proSeasonDecisionTypeLabel(_ type: ProSeasonDecisionType) -> String {
        closedEnumLabel(family: .proSeasonDecisionType, rawValue: type.rawValue)
    }

    public static func proSeasonSegmentLabel(_ segment: ProSeasonSegment) -> String {
        closedEnumLabel(family: .proSeasonSegment, rawValue: segment.rawValue)
    }

    public static func proSeasonTriggerLabel(_ trigger: ProSeasonTrigger) -> String {
        closedEnumLabel(family: .proSeasonTrigger, rawValue: trigger.rawValue)
    }

    public static func awakeningTitle(awakeningID: AwakeningID) -> String {
        stableID(family: .awakening, id: awakeningID.rawValue, slot: "title")
    }

    public static func awakeningDetail(awakeningID: AwakeningID) -> String {
        stableID(family: .awakening, id: awakeningID.rawValue, slot: "detail")
    }

    public static func awakeningBranchTitle(branch: AwakeningTree.Branch) -> String {
        stableID(family: .awakeningBranch, id: branch.rawValue, slot: "title")
    }

    public static func awakeningBranchDetail(branch: AwakeningTree.Branch) -> String {
        stableID(family: .awakeningBranch, id: branch.rawValue, slot: "detail")
    }

    public static func memoryTitle(memoryID: MemoryCardID) -> String {
        stableID(family: .memory, id: memoryID.rawValue, slot: "title")
    }

    public static func signatureLegacyTitle(id: CareerSignatureLegacyID) -> String {
        stableID(family: .signatureLegacy, id: id.rawValue, slot: "title")
    }

    public static func proDecisionTitle(decisionID: String) -> String {
        stableID(family: .proDecision, id: decisionID, slot: "title")
    }

    public static func pitcherPresetName(presetID: String) -> String {
        stableID(family: .pitcherPreset, id: presetID, slot: "name")
    }

    public static func pitcherPresetTagline(presetID: String) -> String {
        stableID(family: .pitcherPreset, id: presetID, slot: "tagline")
    }

    public static func pitcherPresetStrength(presetID: String, index: Int) -> String {
        stableID(family: .pitcherPreset, id: presetID, slot: "strength.\(index)")
    }

    public static func pitcherPresetTradeoff(presetID: String) -> String {
        stableID(family: .pitcherPreset, id: presetID, slot: "tradeoff")
    }

    public static func pitcherPresetDefaultPlayerName(presetID: String) -> String {
        stableID(family: .pitcherPreset, id: presetID, slot: "default-name")
    }

    public static func careerWindTitle(id: String, rulesVersion: CareerRulesVersion) -> String {
        stableID(family: .careerWind, id: "v\(rulesVersion.rawValue).\(id)", slot: "title")
    }

    public static func careerWindDetail(id: String, rulesVersion: CareerRulesVersion) -> String {
        stableID(family: .careerWind, id: "v\(rulesVersion.rawValue).\(id)", slot: "detail")
    }

    public static func careerWindEffect(
        id: String,
        rulesVersion: CareerRulesVersion,
        slot: String
    ) -> String {
        stableID(
            family: .careerWind,
            id: "v\(rulesVersion.rawValue).\(id)",
            slot: "effect.\(slot)"
        )
    }

    public static func karmaTitle(_ karma: KarmaID) -> String {
        stableID(family: .karma, id: karma.rawValue, slot: "title")
    }

    public static func karmaDetail(_ karma: KarmaID) -> String {
        stableID(family: .karma, id: karma.rawValue, slot: "detail")
    }

    public static func prologueOpener(_ variant: PrologueOpenerVariant) -> String {
        stableID(family: .prologue, id: variant.rawValue, slot: "context")
    }
}

public extension CopyToken {
    static func stableID(
        family: PresentationCopyFamily,
        id: String,
        slot: String,
        arguments: [CopyArgument] = []
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.stableID(family: family, id: id, slot: slot),
            arguments: arguments
        )
    }

    static func highSchoolEventTitle(eventID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.highSchoolEventTitle(eventID: eventID))
    }

    static func highSchoolEventSummary(eventID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.highSchoolEventSummary(eventID: eventID))
    }

    static func relationshipQuote(
        eventID: String,
        trustBand: RelationshipVoiceCatalog.TrustBand,
        playerName: String? = nil
    ) -> CopyToken {
        let arguments: [CopyArgument] = if let playerName,
                                           RelationshipVoiceCatalog.scenes[eventID]?
                                               .quote(trustBand)
                                               .contains("{player}") == true {
            [.userText(playerName)]
        } else {
            []
        }
        return CopyToken(
            key: PresentationCopyKey.relationshipQuote(eventID: eventID, trustBand: trustBand),
            arguments: arguments
        )
    }

    static func relationshipChoiceTitle(
        eventID: String,
        response: RelationshipResponse
    ) -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipChoiceTitle(eventID: eventID, response: response))
    }

    static func relationshipChoiceDetail(
        eventID: String,
        response: RelationshipResponse
    ) -> CopyToken {
        CopyToken(key: PresentationCopyKey.relationshipChoiceDetail(eventID: eventID, response: response))
    }

    static func schoolName(schoolID: SchoolID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolName(schoolID: schoolID))
    }

    static func schoolPhilosophy(schoolID: SchoolID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolPhilosophy(schoolID: schoolID))
    }

    static func schoolTradeoff(schoolID: SchoolID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.schoolTradeoff(schoolID: schoolID))
    }

    static func chapterTitle(number: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterTitle(number: number))
    }

    static func chapterTheme(number: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.chapterTheme(number: number))
    }

    static func draftTeamName(teamID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.draftTeamName(teamID: teamID))
    }

    static func rivalName(rivalID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.rivalName(rivalID: rivalID))
    }

    static func nicknameTitle(nicknameID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.nicknameTitle(nicknameID: nicknameID))
    }

    static func pitchTypeName(pitchType: PitchType) -> CopyToken {
        CopyToken(key: PresentationCopyKey.pitchTypeName(pitchType: pitchType))
    }

    static func closedEnumLabel(
        family: PresentationCopyFamily,
        rawValue: String
    ) -> CopyToken {
        CopyToken(key: PresentationCopyKey.closedEnumLabel(family: family, rawValue: rawValue))
    }

    static func pitchIntensityLabel(_ intensity: PitchIntensity) -> CopyToken {
        closedEnumLabel(family: .pitchIntensity, rawValue: intensity.rawValue)
    }

    static func pitchUsageRoleLabel(_ role: PitchUsageRole) -> CopyToken {
        closedEnumLabel(family: .pitchUsage, rawValue: role.rawValue)
    }

    static func batterSideLabel(_ side: BatSide) -> CopyToken {
        closedEnumLabel(family: .batterSide, rawValue: side.rawValue)
    }

    static func pitchOutcomeLabel(_ outcome: PitchOutcome) -> CopyToken {
        closedEnumLabel(family: .pitchOutcome, rawValue: outcome.rawValue)
    }

    static func zoneIntentLabel(_ intent: ZoneIntent) -> CopyToken {
        closedEnumLabel(family: .zoneIntent, rawValue: intent.rawValue)
    }

    static func highSchoolCareerPhaseLabel(_ phase: HighSchoolCareerPhase) -> CopyToken {
        closedEnumLabel(family: .highSchoolPhase, rawValue: phase.rawValue)
    }

    static func trainingFocusLabel(_ focus: TrainingFocus) -> CopyToken {
        closedEnumLabel(family: .trainingFocus, rawValue: focus.rawValue)
    }

    static func trainingIntensityLabel(_ intensity: TrainingIntensity) -> CopyToken {
        closedEnumLabel(family: .trainingIntensity, rawValue: intensity.rawValue)
    }

    static func relationshipTargetLabel(_ target: RelationshipTarget) -> CopyToken {
        closedEnumLabel(family: .relationshipTarget, rawValue: target.rawValue)
    }

    static func relationshipResponseLabel(_ response: RelationshipResponse) -> CopyToken {
        closedEnumLabel(family: .relationshipResponse, rawValue: response.rawValue)
    }

    static func draftOutcomeLabel(_ outcome: DraftOutcome) -> CopyToken {
        closedEnumLabel(family: .draftOutcome, rawValue: outcome.rawValue)
    }

    static func armHealthStateLabel(_ state: ArmHealthState) -> CopyToken {
        closedEnumLabel(family: .armHealth, rawValue: state.rawValue)
    }

    static func proCareerPhaseLabel(_ phase: ProCareerPhase) -> CopyToken {
        closedEnumLabel(family: .proCareerPhase, rawValue: phase.rawValue)
    }

    static func proLevelLabel(_ level: ProLevel) -> CopyToken {
        closedEnumLabel(family: .proLevel, rawValue: level.rawValue)
    }

    static func proRoleLabel(_ role: ProRole) -> CopyToken {
        closedEnumLabel(family: .proRole, rawValue: role.rawValue)
    }

    static func proWeekPlanLabel(_ plan: ProWeekPlan) -> CopyToken {
        closedEnumLabel(family: .proWeekPlan, rawValue: plan.rawValue)
    }

    static func offseasonDecisionLabel(_ decision: OffseasonDecision) -> CopyToken {
        closedEnumLabel(family: .offseasonDecision, rawValue: decision.rawValue)
    }

    static func proSeasonDecisionTypeLabel(_ type: ProSeasonDecisionType) -> CopyToken {
        closedEnumLabel(family: .proSeasonDecisionType, rawValue: type.rawValue)
    }

    static func proSeasonSegmentLabel(_ segment: ProSeasonSegment) -> CopyToken {
        closedEnumLabel(family: .proSeasonSegment, rawValue: segment.rawValue)
    }

    static func proSeasonTriggerLabel(_ trigger: ProSeasonTrigger) -> CopyToken {
        closedEnumLabel(family: .proSeasonTrigger, rawValue: trigger.rawValue)
    }

    static func awakeningTitle(awakeningID: AwakeningID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.awakeningTitle(awakeningID: awakeningID))
    }

    static func awakeningDetail(awakeningID: AwakeningID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.awakeningDetail(awakeningID: awakeningID))
    }

    static func awakeningBranchTitle(branch: AwakeningTree.Branch) -> CopyToken {
        CopyToken(key: PresentationCopyKey.awakeningBranchTitle(branch: branch))
    }

    static func awakeningBranchDetail(branch: AwakeningTree.Branch) -> CopyToken {
        CopyToken(key: PresentationCopyKey.awakeningBranchDetail(branch: branch))
    }

    static func memoryTitle(memoryID: MemoryCardID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.memoryTitle(memoryID: memoryID))
    }

    static func signatureLegacyTitle(id: CareerSignatureLegacyID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.signatureLegacyTitle(id: id))
    }

    static func proDecisionTitle(decisionID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.proDecisionTitle(decisionID: decisionID))
    }

    static func pitcherPresetName(presetID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.pitcherPresetName(presetID: presetID))
    }

    static func pitcherPresetTagline(presetID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.pitcherPresetTagline(presetID: presetID))
    }

    static func pitcherPresetStrength(presetID: String, index: Int) -> CopyToken {
        CopyToken(key: PresentationCopyKey.pitcherPresetStrength(presetID: presetID, index: index))
    }

    static func pitcherPresetTradeoff(presetID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.pitcherPresetTradeoff(presetID: presetID))
    }

    static func pitcherPresetDefaultPlayerName(presetID: String) -> CopyToken {
        CopyToken(key: PresentationCopyKey.pitcherPresetDefaultPlayerName(presetID: presetID))
    }

    static func careerWindTitle(id: String, rulesVersion: CareerRulesVersion) -> CopyToken {
        CopyToken(key: PresentationCopyKey.careerWindTitle(id: id, rulesVersion: rulesVersion))
    }

    static func careerWindDetail(id: String, rulesVersion: CareerRulesVersion) -> CopyToken {
        CopyToken(key: PresentationCopyKey.careerWindDetail(id: id, rulesVersion: rulesVersion))
    }

    static func careerWindEffect(
        id: String,
        rulesVersion: CareerRulesVersion,
        slot: String,
        arguments: [CopyArgument]
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.careerWindEffect(id: id, rulesVersion: rulesVersion, slot: slot),
            arguments: arguments
        )
    }

    static func karmaTitle(_ karma: KarmaID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.karmaTitle(karma))
    }

    static func karmaDetail(_ karma: KarmaID) -> CopyToken {
        CopyToken(key: PresentationCopyKey.karmaDetail(karma))
    }

    static func prologueOpener(
        variant: PrologueOpenerVariant,
        region: SchoolRegionID?
    ) -> CopyToken {
        CopyToken(
            key: PresentationCopyKey.prologueOpener(variant),
            arguments: region.map { [.contentID($0.rawValue)] } ?? []
        )
    }
}

public extension CareerEventContent {
    var titleCopyToken: CopyToken { .highSchoolEventTitle(eventID: id) }
    var summaryCopyToken: CopyToken { .highSchoolEventSummary(eventID: id) }
}

public extension SchoolID {
    var fallbackNameCopyToken: CopyToken { .schoolFallbackName(schoolID: self) }
    var nameCopyToken: CopyToken { .schoolName(schoolID: self) }
    var philosophyCopyToken: CopyToken { .schoolPhilosophy(schoolID: self) }
    var tradeoffCopyToken: CopyToken { .schoolTradeoff(schoolID: self) }
}

public extension SchoolSnapshot {
    var nameCopyToken: CopyToken { id.nameCopyToken }
    var philosophyCopyToken: CopyToken { id.philosophyCopyToken }
    var tradeoffCopyToken: CopyToken { id.tradeoffCopyToken }
}

public extension CareerChapterSnapshot {
    var titleCopyToken: CopyToken { .chapterTitle(number: number) }
    var themeCopyToken: CopyToken { .chapterTheme(number: number) }
}

public extension DraftTeamSnapshot {
    var nameCopyToken: CopyToken { .draftTeamName(teamID: id) }
}

public extension RivalSnapshot {
    var nameCopyToken: CopyToken { .rivalName(rivalID: id) }
}

public extension Nickname {
    var titleCopyToken: CopyToken { .nicknameTitle(nicknameID: id) }
}

public extension PitcherPresetSnapshot {
    var nameCopyToken: CopyToken { .pitcherPresetName(presetID: id) }
    var taglineCopyToken: CopyToken { .pitcherPresetTagline(presetID: id) }
    var strengthCopyTokens: [CopyToken] {
        strengths.indices.map { .pitcherPresetStrength(presetID: id, index: $0) }
    }
    var tradeoffCopyToken: CopyToken { .pitcherPresetTradeoff(presetID: id) }
    var defaultPlayerNameCopyToken: CopyToken {
        .pitcherPresetDefaultPlayerName(presetID: id)
    }

    /// Alias used by setup screens when the system-provided player name is the only name shown.
    var defaultNameCopyToken: CopyToken { defaultPlayerNameCopyToken }
}

public extension PitchType {
    var nameCopyToken: CopyToken { .pitchTypeName(pitchType: self) }
    var displayCopyToken: CopyToken { nameCopyToken }
}

public extension PitchIntensity {
    var displayCopyToken: CopyToken { .pitchIntensityLabel(self) }
}

public extension PitchUsageRole {
    var displayCopyToken: CopyToken { .pitchUsageRoleLabel(self) }
}

public extension BatSide {
    var displayCopyToken: CopyToken { .batterSideLabel(self) }
}

public extension PitchOutcome {
    var displayCopyToken: CopyToken { .pitchOutcomeLabel(self) }
}

public extension ZoneIntent {
    var displayCopyToken: CopyToken { .zoneIntentLabel(self) }
}

public extension HighSchoolCareerPhase {
    var displayCopyToken: CopyToken { .highSchoolCareerPhaseLabel(self) }
}

public extension TrainingFocus {
    var displayCopyToken: CopyToken { .trainingFocusLabel(self) }
}

public extension TrainingIntensity {
    var displayCopyToken: CopyToken { .trainingIntensityLabel(self) }
}

public extension RelationshipTarget {
    var displayCopyToken: CopyToken { .relationshipTargetLabel(self) }
}

public extension RelationshipResponse {
    var displayCopyToken: CopyToken { .relationshipResponseLabel(self) }
}

public extension DraftOutcome {
    var displayCopyToken: CopyToken { .draftOutcomeLabel(self) }
}

public extension ArmHealthState {
    var displayCopyToken: CopyToken { .armHealthStateLabel(self) }
}

public extension ProCareerPhase {
    var displayCopyToken: CopyToken { .proCareerPhaseLabel(self) }
}

public extension ProLevel {
    var displayCopyToken: CopyToken { .proLevelLabel(self) }
}

public extension ProRole {
    var displayCopyToken: CopyToken { .proRoleLabel(self) }
}

public extension ProWeekPlan {
    var displayCopyToken: CopyToken { .proWeekPlanLabel(self) }
}

public extension OffseasonDecision {
    var displayCopyToken: CopyToken { .offseasonDecisionLabel(self) }
}

public extension ProSeasonDecisionType {
    var displayCopyToken: CopyToken { .proSeasonDecisionTypeLabel(self) }
}

public extension ProSeasonSegment {
    var displayCopyToken: CopyToken { .proSeasonSegmentLabel(self) }
}

public extension ProSeasonTrigger {
    var displayCopyToken: CopyToken { .proSeasonTriggerLabel(self) }
}

public extension AwakeningID {
    var titleCopyToken: CopyToken { .awakeningTitle(awakeningID: self) }
    var detailCopyToken: CopyToken { .awakeningDetail(awakeningID: self) }
}

public extension AwakeningTree.Branch {
    var titleCopyToken: CopyToken { .awakeningBranchTitle(branch: self) }
    var detailCopyToken: CopyToken { .awakeningBranchDetail(branch: self) }
}

public extension MemoryCardID {
    var titleCopyToken: CopyToken { .memoryTitle(memoryID: self) }
}

public extension CareerSignatureLegacyID {
    var titleCopyToken: CopyToken { .signatureLegacyTitle(id: self) }
}

public extension CopyToken {
    /// The complete closed-enum set owned by the SimulationCore presentation boundary.
    ///
    /// Keep this list explicit rather than deriving it from Codable or persistence structures: it
    /// is a localization inventory, not simulation state, and its order has no gameplay meaning.
    static let closedEnumDescriptors: [PresentationCopyDescriptor] = [
        PitchType.allCases.map {
            PresentationCopyDescriptor(family: .pitchType, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        PitchIntensity.allCases.map {
            PresentationCopyDescriptor(family: .pitchIntensity, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        PitchUsageRole.allCases.map {
            PresentationCopyDescriptor(family: .pitchUsage, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        BatSide.allCases.map {
            PresentationCopyDescriptor(family: .batterSide, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        PitchOutcome.allCases.map {
            PresentationCopyDescriptor(family: .pitchOutcome, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        ZoneIntent.allCases.map {
            PresentationCopyDescriptor(family: .zoneIntent, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        HighSchoolCareerPhase.allCases.map {
            PresentationCopyDescriptor(family: .highSchoolPhase, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        TrainingFocus.allCases.map {
            PresentationCopyDescriptor(family: .trainingFocus, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        TrainingIntensity.allCases.map {
            PresentationCopyDescriptor(family: .trainingIntensity, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        RelationshipTarget.allCases.map {
            PresentationCopyDescriptor(family: .relationshipTarget, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        RelationshipResponse.allCases.map {
            PresentationCopyDescriptor(family: .relationshipResponse, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        [DraftOutcome.drafted, .undrafted].map {
            PresentationCopyDescriptor(family: .draftOutcome, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        ArmHealthState.allCases.map {
            PresentationCopyDescriptor(family: .armHealth, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        [
            ProCareerPhase.contractOffer, .weeklyPlan, .seasonDecision, .importantGame,
            .seasonReview, .seasonSettlement, .offseasonDecision, .offseasonInvestment,
            .retirementDecision, .completed,
        ].map {
            PresentationCopyDescriptor(family: .proCareerPhase, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        [ProLevel.minor, .major].map {
            PresentationCopyDescriptor(family: .proLevel, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        [ProRole.starter, .longRelief, .setup, .closer].map {
            PresentationCopyDescriptor(family: .proRole, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        ProWeekPlan.allCases.map {
            PresentationCopyDescriptor(family: .proWeekPlan, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        [OffseasonDecision.continueCareer, .militaryService, .freeAgency, .retire].map {
            PresentationCopyDescriptor(family: .offseasonDecision, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        ProSeasonDecisionType.allCases.map {
            PresentationCopyDescriptor(family: .proSeasonDecisionType, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        ProSeasonSegment.allCases.map {
            PresentationCopyDescriptor(family: .proSeasonSegment, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
        [
            ProSeasonTrigger.openingStatement, .callUpAudition, .majorDebut,
            .recordChase, .roleShowdown, .standingsRace,
        ].map {
            PresentationCopyDescriptor(family: .proSeasonTrigger, rawValue: $0.rawValue, token: $0.displayCopyToken)
        },
    ].flatMap { $0 }

    /// Complete awakening title/detail coverage in `AwakeningID.allCases` order. This order is
    /// an inventory contract only; it is never used to choose or apply an awakening.
    static let awakeningDescriptors: [AwakeningCopyDescriptor] = AwakeningID.allCases.map { id in
        AwakeningCopyDescriptor(
            id: id,
            titleToken: id.titleCopyToken,
            detailToken: id.detailCopyToken
        )
    }

    /// Complete branch title/detail coverage in `AwakeningTree.Branch.allCases` order.
    static let awakeningBranchDescriptors: [AwakeningBranchCopyDescriptor] =
        AwakeningTree.Branch.allCases.map { branch in
            AwakeningBranchCopyDescriptor(
                branch: branch,
                titleToken: branch.titleCopyToken,
                detailToken: branch.detailCopyToken
            )
        }

    /// The complete current pitcher-preset catalog surface, explicitly enumerated by ID and
    /// slot. Do not derive this from Codable fields or historical balance catalogs.
    static let pitcherPresetDescriptors: [PitcherPresetCopyDescriptor] = [
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "name", token: .pitcherPresetName(presetID: "power_prospect")),
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "tagline", token: .pitcherPresetTagline(presetID: "power_prospect")),
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "strength.0", token: .pitcherPresetStrength(presetID: "power_prospect", index: 0)),
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "strength.1", token: .pitcherPresetStrength(presetID: "power_prospect", index: 1)),
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "strength.2", token: .pitcherPresetStrength(presetID: "power_prospect", index: 2)),
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "tradeoff", token: .pitcherPresetTradeoff(presetID: "power_prospect")),
        PitcherPresetCopyDescriptor(presetID: "power_prospect", slot: "default-name", token: .pitcherPresetDefaultPlayerName(presetID: "power_prospect")),

        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "name", token: .pitcherPresetName(presetID: "precision_commander")),
        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "tagline", token: .pitcherPresetTagline(presetID: "precision_commander")),
        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "strength.0", token: .pitcherPresetStrength(presetID: "precision_commander", index: 0)),
        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "strength.1", token: .pitcherPresetStrength(presetID: "precision_commander", index: 1)),
        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "strength.2", token: .pitcherPresetStrength(presetID: "precision_commander", index: 2)),
        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "tradeoff", token: .pitcherPresetTradeoff(presetID: "precision_commander")),
        PitcherPresetCopyDescriptor(presetID: "precision_commander", slot: "default-name", token: .pitcherPresetDefaultPlayerName(presetID: "precision_commander")),

        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "name", token: .pitcherPresetName(presetID: "breaking_ball_artist")),
        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "tagline", token: .pitcherPresetTagline(presetID: "breaking_ball_artist")),
        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "strength.0", token: .pitcherPresetStrength(presetID: "breaking_ball_artist", index: 0)),
        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "strength.1", token: .pitcherPresetStrength(presetID: "breaking_ball_artist", index: 1)),
        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "strength.2", token: .pitcherPresetStrength(presetID: "breaking_ball_artist", index: 2)),
        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "tradeoff", token: .pitcherPresetTradeoff(presetID: "breaking_ball_artist")),
        PitcherPresetCopyDescriptor(presetID: "breaking_ball_artist", slot: "default-name", token: .pitcherPresetDefaultPlayerName(presetID: "breaking_ball_artist")),

        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "name", token: .pitcherPresetName(presetID: "innings_eater")),
        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "tagline", token: .pitcherPresetTagline(presetID: "innings_eater")),
        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "strength.0", token: .pitcherPresetStrength(presetID: "innings_eater", index: 0)),
        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "strength.1", token: .pitcherPresetStrength(presetID: "innings_eater", index: 1)),
        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "strength.2", token: .pitcherPresetStrength(presetID: "innings_eater", index: 2)),
        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "tradeoff", token: .pitcherPresetTradeoff(presetID: "innings_eater")),
        PitcherPresetCopyDescriptor(presetID: "innings_eater", slot: "default-name", token: .pitcherPresetDefaultPlayerName(presetID: "innings_eater")),
    ]
}

public extension RelationshipVoiceCatalog {
    static func quoteCopyToken(
        eventID: String,
        trustBand: TrustBand,
        playerName: String? = nil
    ) -> CopyToken {
        .relationshipQuote(eventID: eventID, trustBand: trustBand, playerName: playerName)
    }

    static func choiceTitleCopyToken(
        eventID: String,
        response: RelationshipResponse
    ) -> CopyToken {
        .relationshipChoiceTitle(eventID: eventID, response: response)
    }

    static func choiceDetailCopyToken(
        eventID: String,
        response: RelationshipResponse
    ) -> CopyToken {
        .relationshipChoiceDetail(eventID: eventID, response: response)
    }
}
