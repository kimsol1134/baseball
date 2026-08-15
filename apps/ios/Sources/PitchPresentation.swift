import Foundation
import SimulationCore

/// English-safe presentation for the pitching loop.
///
/// Every English sentence is derived from an enum, stable scenario ID, reason code, or numeric
/// snapshot field. Legacy Korean sentences remain available to Korean saves but are never used as
/// an English fallback.
enum PitchPresentation {
    static func batterName(_ batter: BatterSnapshot, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return batter.name }
        if batter.id == "bullpen-batter" { return resolver.resolve(.batterPractice) }
        if batter.id == "bullpen-batter-2" { return resolver.resolve(.batterPracticeB) }

        let rivalDescriptor = RivalPresentationCatalog.descriptor(for: batter.id)
        if rivalDescriptor.isKnownRival { return resolver.resolve(rivalDescriptor.nameToken) }

        // Frozen shipped-name inventory. These are display spellings only; the Korean names and
        // stable batter IDs remain untouched in saves and simulation inputs.
        let englishNames: [String: String] = [
            "구본휘": "Gu Bon-hwi", "설재빈": "Seol Jae-bin", "천유겸": "Cheon Yu-gyeom",
            "봉시원": "Bong Si-won", "옥준서": "Ok Jun-seo", "석다온": "Seok Da-on",
            "여준호": "Yeo Jun-ho", "심우재": "Sim Woo-jae", "표시윤": "Pyo Si-yoon",
            "명하람": "Myeong Ha-ram", "국지훈": "Guk Ji-hoon", "노경환": "Noh Gyeong-hwan",
            "강도훈": "Kang Do-hoon", "마태오": "Ma Tae-oh", "백건우": "Baek Geon-woo",
            "노진성": "Noh Jin-seong", "천우재": "Cheon Woo-jae", "서강윤": "Seo Kang-yoon",
            "구본혁": "Gu Bon-hyeok", "류성권": "Ryu Seong-gwon", "문태경": "Moon Tae-gyeong",
            "한도결": "Han Do-gyeol", "오재민": "Oh Jae-min",
        ]
        let japaneseNames: [String: String] = [
            "구본휘": "ク・ボンフィ", "설재빈": "ソル・ジェビン", "천유겸": "チョン・ユギョム",
            "봉시원": "ポン・シウォン", "옥준서": "オク・ジュンソ", "석다온": "ソク・ダオン",
            "여준호": "ヨ・ジュノ", "심우재": "シム・ウジェ", "표시윤": "ピョ・シユン",
            "명하람": "ミョン・ハラム", "국지훈": "クク・ジフン", "노경환": "ノ・ギョンファン",
            "강도훈": "カン・ドフン", "마태오": "マ・テオ", "백건우": "ペク・ゴヌ",
            "노진성": "ノ・ジンソン", "천우재": "チョン・ウジェ", "서강윤": "ソ・ガンユン",
            "구본혁": "ク・ボニョク", "류성권": "リュ・ソングォン", "문태경": "ムン・テギョン",
            "한도결": "ハン・ドギョル", "오재민": "オ・ジェミン",
        ]
        let names = resolver.language == .japanese ? japaneseNames : englishNames
        return names[batter.name] ?? resolver.resolve(.batterOpponent)
    }

    static func fielderName(
        _ rawName: String?,
        position: FielderPosition?,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else {
            return rawName ?? fielder(position, resolver: resolver)
        }
        let englishNames: [String: String] = [
            "본인": "You",
            "유시환": "Si-hwan Yu",
            "임태오": "Tae-o Im",
            "나건우": "Geon-woo Na",
            "배준서": "Jun-seo Bae",
            "하민규": "Min-gyu Ha",
            "조유찬": "Yu-chan Cho",
            "신태양": "Tae-yang Shin",
            "도경훈": "Gyeong-hoon Do",
        ]
        let japaneseNames: [String: String] = [
            "본인": "自分",
            "유시환": "ユ・シファン",
            "임태오": "イム・テオ",
            "나건우": "ナ・ゴヌ",
            "배준서": "ペ・ジュンソ",
            "하민규": "ハ・ミンギュ",
            "조유찬": "チョ・ユチャン",
            "신태양": "シン・テヤン",
            "도경훈": "ト・ギョンフン",
        ]
        let names = resolver.language == .japanese ? japaneseNames : englishNames
        return rawName.flatMap { names[$0] } ?? fielder(position, resolver: resolver)
    }

    static func scenarioHeadline(_ scenario: PitchScenario, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return scenario.headline }
        switch scenario.presentationContext {
        case .tutorial:
            return resolver.resolve(.scenarioTutorialTitle)
        case .highSchool(let scenarioID):
            let descriptor = ImportantGamePresentationCatalog.descriptor(for: scenarioID ?? "")
            return resolver.resolve(descriptor.titleToken)
        case .pro(let moment):
            switch moment {
            case .majorDebut: return resolver.resolve(.scenarioProDebutTitle)
            case .callUpAudition: return resolver.resolve(.scenarioProCallUpTitle)
            case .roleShowdown: return resolver.resolve(.scenarioProRoleTitle)
            case .recordChase: return resolver.resolve(.scenarioProRecordTitle)
            case .standingsRace: return resolver.resolve(.scenarioProStandingsTitle)
            case .openingStatement: return resolver.resolve(.scenarioProOpeningTitle)
            }
        }
    }

    static func scenarioDetail(_ scenario: PitchScenario, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return scenario.detail }
        switch scenario.presentationContext {
        case .tutorial:
            return resolver.resolve(.scenarioTutorialBody)
        case .highSchool(let scenarioID):
            let descriptor = ImportantGamePresentationCatalog.descriptor(for: scenarioID ?? "")
            return resolver.resolve(descriptor.narrativeToken)
        case .pro(let moment):
            switch moment {
            case .majorDebut: return resolver.resolve(.scenarioProDebutBody)
            case .callUpAudition: return resolver.resolve(.scenarioProCallUpBody)
            case .roleShowdown: return resolver.resolve(.scenarioProRoleBody)
            case .recordChase(let ahead):
                return resolver.resolve(ahead ? .scenarioProRecordAheadBody : .scenarioProRecordBehindBody)
            case .standingsRace(let ahead):
                return resolver.resolve(ahead ? .scenarioProStandingsAheadBody : .scenarioProStandingsBehindBody)
            case .openingStatement: return resolver.resolve(.scenarioProOpeningBody)
            }
        }
    }

    static func zone(_ zone: PitchZone, batSide: BatSide, resolver: GameCopyResolver) -> String {
        let visualColumn = batSide == .left ? 2 - zone.column : zone.column
        let key: PitchUICopyKey
        switch (zone.row, visualColumn) {
        case (0, 0): key = .zoneHighInside
        case (0, 1): key = .zoneHighMiddle
        case (0, 2): key = .zoneHighOutside
        case (1, 0): key = .zoneMiddleInside
        case (1, 1): key = .zoneMiddleMiddle
        case (1, 2): key = .zoneMiddleOutside
        case (2, 0): key = .zoneLowInside
        case (2, 1): key = .zoneLowMiddle
        case (2, 2): key = .zoneLowOutside
        default: key = .zoneUnknown
        }
        return resolver.resolve(key)
    }

    static func intentDetail(
        _ intent: ZoneIntent,
        zone: PitchZone,
        resolver: GameCopyResolver
    ) -> String {
        switch intent {
        case .strike: return resolver.resolve(.zoneIntentStrikeDetail)
        case .edge: return resolver.resolve(.zoneIntentEdgeDetail)
        case .chase:
            return resolver.resolve(
                ZoneIntent.options(for: zone).count == 2 ? .zoneIntentChaseMiddleDetail : .zoneIntentChaseDetail
            )
        }
    }

    static func shortFeedback(_ snapshot: PlateAppearanceSnapshot, resolver: GameCopyResolver) -> String {
        shortFeedback(snapshot.outcome, legacy: snapshot.shortFeedback, resolver: resolver)
    }

    static func shortFeedback(
        _ outcome: PitchOutcome,
        legacy: String,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else { return legacy }
        let key: PitchUICopyKey = switch outcome {
        case .ball: .feedbackBall
        case .calledStrike: .feedbackCalledStrike
        case .swingingStrike: .feedbackSwingingStrike
        case .foul: .feedbackFoul
        case .inPlayOut: .feedbackInPlayOut
        case .single: .feedbackSingle
        case .double: .feedbackDouble
        case .triple: .feedbackTriple
        case .homeRun: .feedbackHomeRun
        case .hitByPitch: .feedbackHitByPitch
        }
        return resolver.resolve(key)
    }

    static func detailFeedback(_ snapshot: PlateAppearanceSnapshot, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return snapshot.detailFeedback }
        return resolver.resolve(
            .feedbackDetail,
            arguments: [
                .userText(selectionQuality(snapshot.selectionQuality, resolver: resolver)),
                .integer(snapshot.execution.executionQuality),
            ]
        )
    }

    static func selectionQuality(_ value: SelectionQuality, resolver: GameCopyResolver) -> String {
        let key: PitchUICopyKey = switch value {
        case .poor: .feedbackSelectionPoor
        case .risky: .feedbackSelectionRisky
        case .good: .feedbackSelectionGood
        case .excellent: .feedbackSelectionExcellent
        }
        return resolver.resolve(key)
    }

    static func trait(_ trait: PersonalityTrait, resolver: GameCopyResolver) -> String {
        let keys: (PitchUICopyKey, PitchUICopyKey) = switch trait {
        case .closer: (.traitCloserTitle, .traitCloserBody)
        case .anchor: (.traitAnchorTitle, .traitAnchorBody)
        case .tactician: (.traitTacticianTitle, .traitTacticianBody)
        case .opener: (.traitOpenerTitle, .traitOpenerBody)
        }
        return resolver.resolve(
            .traitActive,
            arguments: [.userText(resolver.resolve(keys.0)), .userText(resolver.resolve(keys.1))]
        )
    }

    static func abilityMoment(
        _ kind: PitchAbilityKind,
        readout: PitchAbilityReadout,
        resolver: GameCopyResolver
    ) -> String {
        switch kind {
        case .power:
            return resolver.resolve(.abilityPowerMoment, arguments: [.integer(readout.stuffRating), .integer(readout.whiffRating)])
        case .command:
            return resolver.resolve(.abilityCommandMoment, arguments: [.integer(readout.commandRating)])
        case .movement:
            return resolver.resolve(.abilityMovementMoment, arguments: [.integer(readout.movementRating), .integer(readout.weakContactRating)])
        case .stamina:
            return resolver.resolve(.abilityStaminaMoment, arguments: [.integer(readout.rawFatigue), .integer(readout.effectiveFatigue)])
        }
    }

    static func buildSummary(_ readout: PitchAbilityReadout, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .abilitySummary,
            arguments: [
                .userText(GameFormatters.velocity(tenthsKPH: readout.nominalVelocityTenthsKPH, language: resolver.language)),
                .integer(readout.commandRating), .integer(readout.movementRating),
                .integer(readout.staminaRating), .integer(readout.rawFatigue),
                .integer(readout.effectiveFatigue), .integer(readout.fatigueCost),
                .userText(buildSynergy(readout, resolver: resolver)),
            ]
        )
    }

    static func buildSynergy(_ readout: PitchAbilityReadout, resolver: GameCopyResolver) -> String {
        switch PitchAbilityRules.identity(for: readout) {
        case .power:
            return resolver.resolve(readout.pitchType == .fourSeam ? .buildPowerPrimary : .buildPowerSecondary)
        case .command:
            return resolver.resolve(.buildCommand)
        case .movement:
            return resolver.resolve(readout.pitchType == .fourSeam ? .buildMovementSecondary : .buildMovementPrimary)
        case .stamina:
            return resolver.resolve(.buildStamina, arguments: [.integer(readout.effectiveFatigue)])
        }
    }

    static func sequenceTitle(_ tag: PitchSequenceTag, resolver: GameCopyResolver) -> String {
        resolver.resolve(sequenceKeys(tag).0)
    }

    static func sequenceDetail(_ tag: PitchSequenceTag, resolver: GameCopyResolver) -> String {
        resolver.resolve(sequenceKeys(tag).1)
    }

    private static func sequenceKeys(_ tag: PitchSequenceTag) -> (PitchUICopyKey, PitchUICopyKey) {
        switch tag {
        case .speedLadder: (.sequenceSpeedLadderTitle, .sequenceSpeedLadderDetail)
        case .eyeLevelChange: (.sequenceEyeLevelTitle, .sequenceEyeLevelDetail)
        case .insideOutside: (.sequenceInsideOutsideTitle, .sequenceInsideOutsideDetail)
        case .expandAfterTwoStrikes: (.sequenceExpandTitle, .sequenceExpandDetail)
        case .stealStrike: (.sequenceStealStrikeTitle, .sequenceStealStrikeDetail)
        case .counterRead: (.sequenceCounterReadTitle, .sequenceCounterReadDetail)
        }
    }

    static func adaptation(_ band: RivalAdaptationBand, resolver: GameCopyResolver) -> String {
        let key: PitchUICopyKey = switch band {
        case .noData: .adaptationNoData
        case .watching: .adaptationWatching
        case .learning: .adaptationLearning
        case .lockedOn: .adaptationLocked
        }
        return resolver.resolve(key)
    }

    static func adaptationWarning(
        _ snapshot: RivalAdaptationSnapshot,
        batSide: BatSide,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else { return snapshot.warning }
        switch (snapshot.detectedPitch, snapshot.detectedZone) {
        case let (pitch?, zone?):
            return resolver.resolve(.adaptationPitchAndZone, arguments: [
                .userText(resolver.resolve(pitch.displayCopyToken)),
                .userText(self.zone(zone, batSide: batSide, resolver: resolver)),
            ])
        case let (pitch?, nil):
            return resolver.resolve(.adaptationPitch, arguments: [.userText(resolver.resolve(pitch.displayCopyToken))])
        case let (nil, zone?):
            return resolver.resolve(.adaptationZone, arguments: [.userText(self.zone(zone, batSide: batSide, resolver: resolver))])
        case (nil, nil):
            return snapshot.band == .noData ? "" : resolver.resolve(.adaptationQuiet)
        }
    }

    static func confidence(_ band: AnalysisConfidenceBand, resolver: GameCopyResolver) -> String {
        let key: PitchUICopyKey = switch band {
        case .low: .analysisLow
        case .developing: .analysisDeveloping
        case .reliable: .analysisReliable
        }
        return resolver.resolve(key)
    }

    static func scoutBand(_ band: String, resolver: GameCopyResolver) -> String {
        switch band {
        case "trusted": return resolver.resolve(.analysisReliable)
        case "developing": return resolver.resolve(.analysisDeveloping)
        default: return resolver.resolve(.analysisLow)
        }
    }

    static func analysisPattern(_ analysis: PostgameAnalysisSnapshot, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return analysis.patternWarning }
        return analysis.patternWarning.isEmpty ? "" : resolver.resolve(.analysisPatternWarning)
    }

    static func analysisGrowth(_ analysis: PostgameAnalysisSnapshot, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return analysis.growthSignal }
        return analysis.growthSignal.isEmpty ? "" : resolver.resolve(.analysisGrowthSignal)
    }

    static func catcherReason(_ recommendation: CatcherRecommendationSnapshot, resolver: GameCopyResolver) -> String {
        guard resolver.language != .korean else { return recommendation.shortReason }
        let codes = recommendation.reasonCodes
        let key: PitchUICopyKey
        if codes.contains("rival.pattern_detected") { key = .catcherReasonPattern }
        else if codes.contains("sequence.avoid_repeat") { key = .catcherReasonRepeat }
        else if codes.contains("scouting.pitch_weakness") { key = .catcherReasonWeakness }
        else if codes.contains("count.avoid_walk") { key = .catcherReasonWalk }
        else if codes.contains("count.pitcher_behind") { key = .catcherReasonBehind }
        else if codes.contains("count.pitcher_ahead") { key = .catcherReasonAhead }
        else if codes.contains("count.first_pitch") { key = .catcherReasonFirstPitch }
        else if codes.contains("runners.double_play_setup") { key = .catcherReasonDoublePlay }
        else if codes.contains("runners.suppress_sacrifice_fly") { key = .catcherReasonSacFly }
        else { key = .catcherReasonDefault }
        return resolver.resolve(key)
    }

    static func fielder(_ position: FielderPosition?, resolver: GameCopyResolver) -> String {
        let key: PitchUICopyKey = switch position {
        case .pitcher: .fielderPitcher
        case .catcher: .fielderCatcher
        case .firstBase: .fielderFirstBase
        case .secondBase: .fielderSecondBase
        case .thirdBase: .fielderThirdBase
        case .shortstop: .fielderShortstop
        case .leftField: .fielderLeftField
        case .centerField: .fielderCenterField
        case .rightField: .fielderRightField
        case nil: .fielderCenterField
        }
        return resolver.resolve(key)
    }
}
