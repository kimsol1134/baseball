import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolPresentation {
    /// 저장 규칙의 8개 진행 구간은 그대로 두고, 사용자가 한 번에 이해할 수 있는 네 장으로
    /// 묶는다. 파생값이라 옛 저장과 결정론을 건드리지 않는다.
    static func actNumber(chapter: Int) -> Int {
        min(4, max(1, (chapter + 1) / 2))
    }

    static func actTitle(chapter: Int) -> String {
        switch actNumber(chapter: chapter) {
        case 1: "1장 · 자리를 얻다"
        case 2: "2장 · 내 공을 만들다"
        case 3: "3장 · 책임을 지다"
        default: "4장 · 이름을 남기다"
        }
    }

    static func phase(_ phase: HighSchoolCareerPhase) -> String {
        switch phase {
        case .prologue: "다시 태어남"
        case .schoolSelection: "학교 선택"
        case .training: "훈련"
        case .relationship: "사람들"
        case .importantGame: "고교 공식 경기"
        case .awakening: "각성"
        case .chapterReview: "이야기 마무리"
        case .draft: "드래프트"
        case .legacy: "새 선수에게 남길 것"
        case .completed: "완료"
        }
    }

    static func localized(_ phase: HighSchoolCareerPhase, resolver: GameCopyResolver) -> String {
        resolver.resolve(phase.displayCopyToken)
    }

    static func localizedChapterTitle(
        _ chapter: CareerChapterSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(CareerChapterPresentationCatalog.descriptor(for: chapter).titleToken)
    }

    /// Reauthors the store's frozen Korean compatibility summary from stable state and typed
    /// numeric captures. Unknown source prose fails closed to neutral English.
    @MainActor static func localizedStoreSummary(
        _ raw: String,
        inheritance: Inheritance,
        pendingRecap: CareerRecap?,
        pledge: RunPledge?,
        trainingReceipt: TrainingReceipt?,
        state: HighSchoolCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else { return raw }

        switch raw {
        case "UI 테스트용 미지명 직전 상태를 준비했습니다.",
             "UI 테스트용 지명 완료 상태를 준비했습니다.":
            return resolver.resolve(.highSchoolSummaryFixture)
        case "현재 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다.",
             "iCloud 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다.":
            return resolver.resolve(.highSchoolSummaryBackupRecovered)
        case "시드는 카드에 적힌 숫자만 입력할 수 있습니다. 다시 확인해 주세요.":
            return resolver.resolve(.highSchoolSummarySeedInvalid)
        case "기록 없는 도전 — 이 판의 결과는 선수 기록과 계승에 남지 않습니다.":
            return resolver.resolve(.highSchoolSummaryChallengeStarted)
        case "고교 첫 해가 시작됩니다.":
            return resolver.resolve(.highSchoolSummaryFirstYear)
        case "프로 커리어를 마치면 고교 시절과 통산 기록을 함께 돌아봅니다.":
            return resolver.resolve(.highSchoolSummaryProPending)
        case "프로 커리어를 마쳤습니다. 이제 당시 규칙대로 남길 기억을 고릅니다.":
            return resolver.resolve(.highSchoolSummaryProMemoryChoice)
        case "고교 시절과 프로 통산 기록에서 대표 유산 세 가지를 찾았습니다.":
            return resolver.resolve(.highSchoolSummaryProLegacyFound)
        case "다른 기기의 진행을 불러왔습니다.":
            return resolver.resolve(.highSchoolSummaryCloudLoaded)
        case "iCloud 환생 기록을 읽지 못해 이 기기의 진행을 유지합니다.":
            return resolver.resolve(.highSchoolSummaryCloudKeptLocal)
        case "등판을 중단했습니다. 다음 마운드는 새 이닝입니다.":
            return resolver.resolve(.highSchoolSummaryOutingAbandoned)
        default:
            break
        }

        if let values = summaryCaptures(raw, pattern: #"^같은 훈련 (\d+)회 완료 · 능력 성장 \+(\d+)$"#),
           values.count == 2, let count = Int(values[0]), let growth = Int(values[1]) {
            return resolver.resolve(
                .highSchoolSummaryRepeatTraining,
                arguments: [.integer(count), .integer(growth)]
            )
        }

        if raw.hasSuffix("번째 선수. 대표 유산 하나로 다시 시작합니다.")
            || raw.contains("번째 선수. 기억 ") {
            let memoryCount = inheritance.memories.count
            let inherited: String
            if inheritance.equippedSignatureLegacyID != nil, memoryCount > 0 {
                inherited = resolver.resolve(.highSchoolSummaryRebirthBoth, arguments: [.integer(memoryCount)])
            } else if inheritance.equippedSignatureLegacyID != nil {
                inherited = resolver.resolve(.highSchoolSummaryRebirthSignature)
            } else {
                inherited = resolver.resolve(.highSchoolSummaryRebirthMemories, arguments: [.integer(memoryCount)])
            }
            return resolver.resolve(
                .highSchoolSummaryRebirthStarted,
                arguments: [.integer(state.lifeNumber), .userText(inherited)]
            )
        }

        if let game = HighSchoolConclusionPresentation.localizedStoreGameSummary(raw, resolver: resolver) {
            return game
        }

        if let values = summaryCaptures(raw, pattern: #"^(.+) 완수\. 삼진 (\d+)개"#),
           values.count == 2, let strikeouts = Int(values[1]),
           let frame = chapterGoalFrame(koreanTitle: values[0]) {
            let title = resolver.resolve(.gameContent("content.chapter-goal.\(frame.rawValue).title"))
            return resolver.resolve(
                .highSchoolSummaryGoalCompleted,
                arguments: [.userText(title), .integer(strikeouts)]
            )
        }

        if let values = summaryCaptures(raw, pattern: #"^이제 사람들이 '([^']+)'"#),
           let rawTitle = values.first {
            let title = HighSchoolConclusionPresentation.localizedNicknameTitle(rawTitle, resolver: resolver)
            return resolver.resolve(.highSchoolSummaryNicknameEarned, arguments: [.userText(title)])
        }

        if let values = summaryCaptures(raw, pattern: #"^기억 (\d+)장을 새 선수에게 남깁니다\.$"#),
           let count = values.first.flatMap(Int.init) {
            return resolver.resolve(.highSchoolSummaryMemoriesLeft, arguments: [.integer(count)])
        }
        if raw.hasSuffix("새 선수에게 남깁니다."),
           let signature = pendingRecap?.record.signatureLegacy {
            let title = HighSchoolConclusionPresentation.localizedSignature(
                signature, resolver: resolver
            ).title
            return resolver.resolve(.highSchoolSummarySignatureLeft, arguments: [.userText(title)])
        }

        if raw.hasPrefix("목표를 정했습니다:"), let pledge {
            return resolver.resolve(
                .highSchoolSummaryPledgeChosen,
                arguments: [
                    .userText(LegacyPresentation.pledgeTitle(pledge, resolver: resolver)),
                    .integer(pledge.rewardPermille / 10),
                ]
            )
        }

        if let receipt = trainingReceipt, raw == receipt.detail {
            return localizedTrainingResultDetail(receipt, resolver: resolver)
        }

        if let relationship = state.lastRelationship,
           let event = HighSchoolContentCatalog.relationshipEvents.first(where: { $0.title == relationship.title }),
           let choice = RelationshipPresentationCatalog.cardDescriptor(for: event).choiceDescriptors
               .first(where: { $0.response == relationship.response }) {
            let abilityChange: String
            if let focus = relationship.growthFocus,
               let before = relationship.abilityBefore,
               let after = relationship.abilityAfter {
                abilityChange = resolver.resolve(
                    .highSchoolSummaryRelationshipAbility,
                    arguments: [
                        .userText(resolver.resolve(focus.displayCopyToken)),
                        .integer(AbilityDisplayScale.displayDelta(before: before, after: after)),
                    ]
                )
            } else {
                abilityChange = ""
            }
            return resolver.resolve(
                .highSchoolSummaryRelationship,
                arguments: [
                    .userText(resolver.resolve(choice.detailToken)),
                    .integer(relationship.trustAfter - relationship.trustBefore),
                    .integer(relationship.fatigueAfter - relationship.fatigueBefore),
                    .integer(relationship.fanInterestAfter - relationship.fanInterestBefore),
                    .userText(abilityChange),
                ]
            )
        }

        let chapter = CareerChapterPresentationCatalog.descriptor(for: state.chapter)
        if raw == "\(state.chapter.title) · \(state.chapter.season)" {
            return resolver.resolve(
                .highSchoolSummaryChapterAdvanced,
                arguments: [
                    .userText(resolver.resolve(chapter.titleToken)),
                    .userText(resolver.resolve(chapter.seasonToken)),
                ]
            )
        }

        if let awakening = state.selectedAwakenings.last,
           raw.contains(HighSchoolPresentation.awakening(awakening).title) {
            return resolver.resolve(
                .highSchoolSummaryAwakening,
                arguments: [
                    .userText(localizedAwakeningTitle(awakening, resolver: resolver)),
                    .userText(localizedAwakeningDetail(awakening, resolver: resolver)),
                ]
            )
        }

        if let draft = state.draftResult {
            return HighSchoolConclusionPresentation.localizedDraftSummary(draft, resolver: resolver)
        }
        return resolver.resolve(.highSchoolSummaryUpdated)
    }

    static func localizedSummaryCue(
        _ cue: FeedbackCue,
        resolver: GameCopyResolver
    ) -> String {
        let key: LegacyUICopyKey = switch cue {
        case .setback: .highSchoolSummaryCueSetback
        case .growth: .highSchoolSummaryCueGrowth
        case .success: .highSchoolSummaryCueSuccess
        case .neutral: .highSchoolSummaryCueNeutral
        }
        return resolver.resolve(key)
    }

    static func localizedPersonalityTraitTitle(
        _ trait: PersonalityTrait,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else { return trait.title }
        return resolver.resolve(.gameContent("content.personality-trait.\(trait.rawValue).title"))
    }

    static func localizedPersonalityTraitActivation(
        _ trait: PersonalityTrait,
        resolver: GameCopyResolver
    ) -> String {
        guard resolver.language != .korean else { return trait.activationLine }
        return resolver.resolve(.gameContent("content.personality-trait.\(trait.rawValue).activation"))
    }

    static func focus(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "구위"
        case .command: "제구"
        case .breakingBall: "변화구"
        case .stamina: "체력"
        case .recovery: "회복"
        case .gamePlanning: "승부 설계"
        }
    }

    static func localized(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.displayCopyToken)
    }

    static func localizedSchoolName(
        _ school: SchoolSnapshot,
        rawRegion: String,
        resolver: GameCopyResolver
    ) -> String {
        if let region = SchoolRegionID.strictLookup(rawRegion: rawRegion) {
            let copy = CopyToken.schoolSelectionDescriptor(region: region, schoolID: school.id)
            return resolver.resolve(copy.schoolNameToken)
        }
        // A legacy Korean region is intentionally left untouched so opening an old career does
        // not rewrite its visible school identity. English uses a non-regional SchoolID fallback
        // rather than the Seoul-specific generic catalog entry.
        if resolver.language == .korean { return school.name }
        return resolver.resolve(school.id.fallbackNameCopyToken)
    }

    static func localizedSchoolCastName(
        _ school: SchoolSnapshot,
        rawRegion: String,
        role: SchoolCastRole,
        resolver: GameCopyResolver
    ) -> String {
        let baseName: String
        if let region = SchoolRegionID.strictLookup(rawRegion: rawRegion) {
            let copy = CopyToken.schoolSelectionDescriptor(region: region, schoolID: school.id)
            let token = role == .coach ? copy.coachNameToken : copy.catcherNameToken
            baseName = resolver.resolve(token)
        } else if resolver.language == .korean {
            // This is the only visible legacy-name path. It preserves the exact Korean payload
            // from an old save; the RelationshipCard itself only calls this semantic resolver.
            baseName = role == .coach ? school.coachName : school.catcherName
        } else {
            baseName = resolver.resolve(
                CopyToken.schoolFallbackCastName(schoolID: school.id, role: role)
            )
        }

        let suffixKey = role == .coach ? AppCopyKey.schoolSelectionCoach : AppCopyKey.schoolSelectionCatcher
        return resolver.resolve(suffixKey, arguments: [.userText(baseName)])
    }

    static func localizedRelationshipSpeaker(
        event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        return resolver.resolve(descriptor.speakerLabelToken)
    }

    static func localizedRelationshipCategory(
        event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        return resolver.resolve(descriptor.categoryLabelToken)
    }

    /// Portrait seeds are visual-only and are never copied into a visible label. Keeping this
    /// legacy-data read here leaves the relationship card's visible source boundary semantic.
    static func relationshipPortraitSeed(
        category: String,
        state: HighSchoolCareerSnapshot
    ) -> (seed: String, role: AvatarFace.Role)? {
        switch category {
        case "coach":
            guard let school = state.school else { return nil }
            return (school.coachName, .coach)
        case "catcher":
            guard let school = state.school else { return nil }
            return (school.catcherName, .catcher)
        case "rival":
            return (state.rival.name, .rival)
        default:
            return nil
        }
    }

    static func localizedRelationshipEventTitle(
        _ event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        if descriptor.isKnownEvent { return resolver.resolve(descriptor.titleToken) }
        return resolver.language == .korean
            ? event.title
            : resolver.resolve(descriptor.titleToken)
    }

    static func localizedRelationshipEventSummary(
        _ event: CareerEventContent,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.eventDescriptor(for: event)
        if descriptor.isKnownEvent { return resolver.resolve(descriptor.summaryToken) }
        return resolver.language == .korean
            ? event.summary
            : resolver.resolve(descriptor.summaryToken)
    }

    static func relationshipTrustBand(
        for event: CareerEventContent,
        manager: Int,
        catcher: Int,
        rival: Int,
        resolver: GameCopyResolver
    ) -> RelationshipVoiceCatalog.TrustBand {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent {
            return RelationshipVoiceCatalog.trustBand(
                for: descriptor.sceneSpeaker,
                manager: manager,
                catcher: catcher,
                rival: rival
            )
        }
        guard resolver.language == .korean,
              let scene = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category) else {
            return .mid
        }
        return RelationshipVoiceCatalog.trustBand(
            for: scene.speaker,
            manager: manager,
            catcher: catcher,
            rival: rival
        )
    }

    static func localizedRelationshipQuote(
        event: CareerEventContent,
        band: RelationshipVoiceCatalog.TrustBand,
        playerName: String,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent {
            guard descriptor.quoteDescriptors.contains(where: { $0.trustBand == band }) else {
                return ""
            }
            return resolver.resolve(
                RelationshipVoiceCatalog.quoteCopyToken(
                    eventID: event.id,
                    trustBand: band,
                    playerName: playerName
                )
            )
        }
        if resolver.language == .korean,
           let scene = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category) {
            return scene.quote(band).replacingOccurrences(of: "{player}", with: playerName)
        }
        return resolver.resolve(.relationshipFallbackQuote())
    }

    static func localizedRelationshipChoiceTitle(
        event: CareerEventContent,
        response: RelationshipResponse,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent,
           let choice = descriptor.choiceDescriptors.first(where: { $0.response == response }) {
            return resolver.resolve(choice.titleToken)
        }
        if resolver.language == .korean,
           let choice = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category)?
               .choices.first(where: { $0.response == response }) {
            return choice.title
        }
        return resolver.resolve(.relationshipFallbackChoiceTitle(response: response))
    }

    static func localizedRelationshipChoiceDetail(
        event: CareerEventContent,
        response: RelationshipResponse,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RelationshipPresentationCatalog.cardDescriptor(for: event)
        if descriptor.event.isKnownEvent,
           let choice = descriptor.choiceDescriptors.first(where: { $0.response == response }) {
            return resolver.resolve(choice.detailToken)
        }
        if resolver.language == .korean,
           let choice = RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category)?
               .choices.first(where: { $0.response == response }) {
            return choice.detail
        }
        return resolver.resolve(.relationshipFallbackChoiceDetail(response: response))
    }

    static func localizedRivalName(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RivalPresentationCatalog.descriptor(for: rival.id)
        if descriptor.isKnownRival { return resolver.resolve(descriptor.nameToken) }
        return resolver.language == .korean ? rival.name : resolver.resolve(descriptor.nameToken)
    }

    static func localizedRivalArchetype(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let descriptor = RivalPresentationCatalog.descriptor(for: rival.id)
        if descriptor.isKnownRival { return resolver.resolve(descriptor.archetypeToken) }
        return resolver.language == .korean
            ? rival.archetype
            : resolver.resolve(descriptor.archetypeToken)
    }

    static func localizedRivalSignature(
        _ rival: RivalSnapshot,
        resolver: GameCopyResolver
    ) -> String? {
        guard rival.signatureRecord != nil || descriptorForRival(rival).isKnownRival else { return nil }
        let descriptor = descriptorForRival(rival)
        if descriptor.isKnownRival { return resolver.resolve(descriptor.signatureToken) }
        return resolver.language == .korean
            ? rival.signatureRecord
            : resolver.resolve(descriptor.signatureToken)
    }
}
