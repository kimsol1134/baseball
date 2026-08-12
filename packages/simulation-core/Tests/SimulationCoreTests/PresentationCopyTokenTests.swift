import Foundation
import XCTest
@testable import SimulationCore

final class PresentationCopyTokenTests: XCTestCase {
    func testAwakeningPresentationDescriptorsCoverEveryStableIDExactlyOnce() {
        let descriptors = CopyToken.awakeningDescriptors

        XCTAssertEqual(descriptors.count, AwakeningID.allCases.count)
        XCTAssertEqual(descriptors.map(\.id), AwakeningID.allCases)
        XCTAssertEqual(Set(descriptors.map(\.id)).count, 18)

        for descriptor in descriptors {
            XCTAssertEqual(
                descriptor.titleToken.key,
                "content.awakening.\(descriptor.id.rawValue).title"
            )
            XCTAssertEqual(
                descriptor.detailToken.key,
                "content.awakening.\(descriptor.id.rawValue).detail"
            )
            XCTAssertTrue(descriptor.titleToken.arguments.isEmpty)
            XCTAssertTrue(descriptor.detailToken.arguments.isEmpty)
        }
    }

    func testAwakeningBranchPresentationDescriptorsCoverEveryStableBranchExactlyOnce() {
        let descriptors = CopyToken.awakeningBranchDescriptors

        XCTAssertEqual(descriptors.count, AwakeningTree.Branch.allCases.count)
        XCTAssertEqual(descriptors.map(\.branch), AwakeningTree.Branch.allCases)
        XCTAssertEqual(Set(descriptors.map(\.branch)).count, 4)

        for descriptor in descriptors {
            XCTAssertEqual(
                descriptor.titleToken.key,
                "content.awakening-branch.\(descriptor.branch.rawValue).title"
            )
            XCTAssertEqual(
                descriptor.detailToken.key,
                "content.awakening-branch.\(descriptor.branch.rawValue).detail"
            )
            XCTAssertTrue(descriptor.titleToken.arguments.isEmpty)
            XCTAssertTrue(descriptor.detailToken.arguments.isEmpty)
        }
    }

    func testAwakeningPresentationLookupLeavesTreeOrderAndRulesUntouched() {
        let expected = [
            "explosive_fastball|power|1|",
            "rising_four_seam|power|2|explosive_fastball",
            "iron_arm|power|2|explosive_fastball",
            "late_inning_reserve|power|3|iron_arm",
            "pinpoint_edge|command|1|",
            "repeatable_release|command|2|pinpoint_edge",
            "first_pitch_strike|command|2|pinpoint_edge",
            "calm_under_pressure|command|3|repeatable_release",
            "scout_composure|command|3|first_pitch_strike",
            "disappearing_breaker|breaking|1|",
            "sweeping_slider|breaking|2|disappearing_breaker",
            "curveball_clock|breaking|2|disappearing_breaker",
            "frozen_changeup|breaking|3|sweeping_slider",
            "sinker_tunnel|breaking|3|curveball_clock",
            "battery_sync|game|1|",
            "two_strike_plan|game|2|battery_sync",
            "pickoff_rhythm|game|2|battery_sync",
            "traffic_controller|game|3|two_strike_plan",
        ]
        let actual = AwakeningTree.nodes.map { node in
            "\(node.id.rawValue)|\(node.branch.rawValue)|\(node.tier)|\(node.parents.map(\.rawValue).joined(separator: ","))"
        }
        XCTAssertEqual(actual, expected)

        XCTAssertEqual(
            AwakeningTree.available(selected: [], sparks: 0),
            [.explosiveFastball, .pinpointEdge, .disappearingBreaker, .batterySync]
        )
        XCTAssertEqual(
            AwakeningTree.available(selected: [.explosiveFastball], sparks: 0),
            [.risingFourSeam, .ironArm, .pinpointEdge, .disappearingBreaker, .batterySync]
        )
        XCTAssertEqual(
            AwakeningTree.available(selected: [.explosiveFastball], sparks: AwakeningTree.leapSparks),
            [.risingFourSeam, .ironArm, .lateInningReserve, .pinpointEdge, .disappearingBreaker, .batterySync]
        )
    }

    func testAwakeningPresentationLookupHasNoSaveRNGOrEventHashEffects() throws {
        let params = StartHighSchoolCareerParams(seed: "20260813", presetID: "power_prospect")
        let engine = HighSchoolCareerEngine()
        let before = try engine.start(params)
        let beforeSaveBytes = try JSONEncoder().encode(before.snapshot)

        for descriptor in CopyToken.awakeningDescriptors {
            _ = descriptor.id.titleCopyToken
            _ = descriptor.id.detailCopyToken
        }
        for descriptor in CopyToken.awakeningBranchDescriptors {
            _ = descriptor.branch.titleCopyToken
            _ = descriptor.branch.detailCopyToken
        }

        let after = try engine.start(params)
        let afterSaveBytes = try JSONEncoder().encode(after.snapshot)
        XCTAssertEqual(before.snapshot, after.snapshot)
        XCTAssertEqual(
            try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: beforeSaveBytes),
            try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: afterSaveBytes)
        )
        XCTAssertEqual(before.nextSeed, after.nextSeed)
        XCTAssertEqual(before.eventHash, after.eventHash)
        XCTAssertEqual(before.snapshot.stateCommitment, after.snapshot.stateCommitment)
        XCTAssertEqual(before.events, after.events)
    }

    func testRepresentativeFactoriesUseStableIDsAndTypedArguments() throws {
        let event = try XCTUnwrap(
            HighSchoolContentCatalog.events.first { $0.id == "evt-catcher-sign" }
        )
        let scenario = try XCTUnwrap(
            HighSchoolContentCatalog.scenarios.first { $0.id == "game-rival-rematch" }
        )

        XCTAssertEqual(event.titleCopyToken.key, "content.event.evt-catcher-sign.title")
        XCTAssertEqual(event.summaryCopyToken.key, "content.event.evt-catcher-sign.summary")
        XCTAssertEqual(scenario.titleCopyToken.key, "content.important-game.game-rival-rematch.title")
        XCTAssertEqual(
            scenario.narrativeCopyToken.key,
            "content.important-game.game-rival-rematch.narrative"
        )
        XCTAssertEqual(
            SchoolID.hanbitTraditional.nameCopyToken.key,
            "content.school.hanbit_traditional.name"
        )

        let quote = RelationshipVoiceCatalog.quoteCopyToken(
            eventID: event.id,
            trustBand: .high,
            playerName: "사용자 입력"
        )
        XCTAssertEqual(quote.key, "content.relationship.evt-catcher-sign.quote.high")
        XCTAssertEqual(quote.arguments, [.userText("사용자 입력")])

        let choice = RelationshipVoiceCatalog.choiceTitleCopyToken(
            eventID: event.id,
            response: .challenge
        )
        XCTAssertEqual(
            choice.key,
            "content.relationship.evt-catcher-sign.choice.challenge.title"
        )
        XCTAssertTrue(choice.arguments.isEmpty)
    }

    func testStableIDFamiliesCoverDirectlyReusableContentIDs() {
        XCTAssertEqual(
            CopyToken.draftTeamName(teamID: "seoul_comets").key,
            "content.draft-team.seoul_comets.name"
        )
        XCTAssertEqual(
            CopyToken.rivalName(rivalID: "rival-seo").key,
            "content.rival.rival-seo.name"
        )
        XCTAssertEqual(
            CopyToken.pitchTypeName(pitchType: .fourSeam).key,
            "content.pitch-type.four_seam.name"
        )
        XCTAssertEqual(
            CopyToken.signatureLegacyTitle(id: .commandMap).key,
            "content.signature-legacy.command_map.title"
        )
        XCTAssertEqual(
            CopyToken.stableID(
                family: .proDecision,
                id: "season-decision-01",
                slot: "title",
                arguments: [.integer(1), .decimal(2.5)]
            ).arguments,
            [.integer(1), .decimal(2.5)]
        )
    }

    func testSchoolSelectionDescriptorsHaveCompleteStableRegionAndPoolCoverage() {
        let expectedRegionSlugs = [
            "seoul", "incheon", "suwon", "daejeon", "gwangju", "daegu", "busan", "changwon",
            "ulsan", "sejong", "gyeonggi", "gangwon", "chungbuk", "chungnam", "jeonbuk",
            "jeonnam", "gyeongbuk", "gyeongnam", "jeju",
        ]
        XCTAssertEqual(SchoolRegionID.allCases.map(\.rawValue), expectedRegionSlugs)
        XCTAssertEqual(SchoolRegionID.allCases.count, HighSchoolCareerEngine.regions.count)
        for (region, rawRegion) in zip(SchoolRegionID.allCases, HighSchoolCareerEngine.regions) {
            XCTAssertEqual(SchoolRegionID.from(rawRegion: rawRegion), region)
            XCTAssertEqual(SchoolRegionID.strictLookup(rawRegion: rawRegion), region)
        }
        XCTAssertEqual(SchoolRegionID.from(rawRegion: "알 수 없는 지역"), .seoul)
        XCTAssertNil(SchoolRegionID.strictLookup(rawRegion: "알 수 없는 지역"))

        let regional = CopyToken.schoolRegionalNameDescriptors
        XCTAssertEqual(regional.count, 19 * 4)
        XCTAssertEqual(
            regional.map { "\($0.region.rawValue).\($0.schoolID.rawValue)" },
            SchoolRegionID.allCases.flatMap { region in
                SchoolID.allCases.map { "\(region.rawValue).\($0.rawValue)" }
            }
        )
        XCTAssertEqual(regional.first?.token.key, "content.school.region.seoul.hanbit_traditional.name")
        XCTAssertEqual(regional.last?.token.key, "content.school.region.jeju.cheongam_development.name")

        let cast = CopyToken.schoolCastNameDescriptors
        XCTAssertEqual(cast.count, 4 * 2 * 5)
        XCTAssertEqual(
            cast.map { "\($0.schoolID.rawValue).\($0.role.rawValue).\($0.poolIndex)" },
            SchoolID.allCases.flatMap { schoolID in
                SchoolCastRole.allCases.flatMap { role in
                    (0..<5).map { "\(schoolID.rawValue).\(role.rawValue).\($0)" }
                }
            }
        )
        XCTAssertEqual(cast.first?.token.key, "content.school.cast.hanbit_traditional.coach.0.name")
        XCTAssertEqual(cast.last?.token.key, "content.school.cast.cheongam_development.catcher.4.name")

        XCTAssertEqual(CopyToken.schoolPhilosophyDescriptors.count, 4)
        XCTAssertEqual(CopyToken.schoolTradeoffDescriptors.count, 4)
        XCTAssertEqual(CopyToken.schoolArchetypeDescriptors.count, 8)
        XCTAssertEqual(CopyToken.schoolSelectionDescriptors.count, 19 * 4)

        for region in SchoolRegionID.allCases {
            for schoolID in SchoolID.allCases {
                let descriptor = CopyToken.schoolSelectionDescriptor(region: region, schoolID: schoolID)
                XCTAssertEqual(descriptor.castPoolIndex, region.ordinal % 5)
                XCTAssertEqual(
                    descriptor.schoolNameToken.key,
                    "content.school.region.\(region.rawValue).\(schoolID.rawValue).name"
                )
                XCTAssertEqual(
                    descriptor.coachNameToken.key,
                    "content.school.cast.\(schoolID.rawValue).coach.\(region.castPoolIndex).name"
                )
                XCTAssertEqual(
                    descriptor.catcherNameToken.key,
                    "content.school.cast.\(schoolID.rawValue).catcher.\(region.castPoolIndex).name"
                )
                XCTAssertTrue(descriptor.schoolNameToken.arguments.isEmpty)
            }
        }
    }

    func testSchoolSelectionPresentationLeavesRawSchoolSnapshotsAndAvatarSeedsUntouched() {
        let expectedSchoolIDs = SchoolID.allCases
        let expectedRegionalNames = [
            ["서울덕성고", "서울배성고", "서울충림고", "서울경원고"],
            ["인천해문결고", "인천동림고", "인천항성고", "인천송해고"],
            ["수원화성빛고", "수원장림고", "수원화담결고", "수원매화솔고"],
            ["대전갑천별고", "대전들샘결고", "대전유진고", "대전중원고"],
            ["광주무등결고", "광주예향결고", "광주서빛람고", "광주무원고"],
            ["대구팔공결고", "대구능금결고", "대구달원고", "대구청림고"],
            ["부산해남고", "부산항성고", "부산항해솔고", "부산오륙결고"],
            ["마산해강고", "창원가람솔고", "창원누리결고", "진해동림고"],
            ["울산대명고", "울산문성고", "울산태원고", "울산장생고"],
            ["세종한별고", "세종새빛고", "세종금빛고", "세종연서고"],
            ["성남유림고", "고양서람빛고", "시흥소명고", "용인청림고"],
            ["강릉해람고", "원주원흥고", "춘천호반고", "속초설해고"],
            ["청주직지솔고", "청주세명고", "충주성문고", "진천덕원고"],
            ["공주금강고", "천안능수결고", "아산곡교결고", "서산해명고"],
            ["전주한옥솔고", "군산새만결고", "정읍인원고", "익산보석고"],
            ["화순화원고", "순천정원솔고", "목포항남고", "여수진원고"],
            ["포항해오름고", "경주월림고", "구미도원고", "안동하회고"],
            ["마산달빛결고", "김해수로결고", "양산물빛고", "거제푸른섬고"],
            ["제주한라원고", "서귀포해원고", "제주탐라빛고", "제주오름고"],
        ]
        let expectedCoachPools = [
            ["윤태문", "강일도", "백승관", "임동혁", "조범석"],
            ["노재형", "한기표", "유상민", "신정록", "곽태윤"],
            ["오승렬", "마동준", "채희성", "도진광", "하병철"],
            ["배도환", "어재원", "편상욱", "소진철", "반석호"],
        ]
        let expectedCatcherPools = [
            ["서준호", "김도현", "박성재", "이재영", "정우빈"],
            ["한도윤", "송지헌", "오세민", "권혁준", "남기율"],
            ["차민석", "변진서", "육정환", "구자헌", "표재신"],
            ["문하진", "안시후", "방준서", "석민규", "탁이현"],
        ]
        let expectedStrengths: [TrainingFocus] = [.stamina, .gamePlanning, .velocity, .breakingBall]
        let expectedPhilosophies = ["기본기와 긴 이닝", "기록을 활용한 타자 상대법", "빠른 직구와 공격적인 승부", "개인별 투구 동작과 변화구 훈련"]
        let expectedTradeoffs = ["새 구종을 시험할 기회가 적습니다.", "데이터가 적을 때 판단이 흔들릴 수 있습니다.", "빠른 공을 많이 던질수록 피로가 쌓이고 제구가 흔들립니다.", "팀이 연패하면 개인 훈련 시간이 줄어듭니다."]
        let expectedCoachArchetypes = ["원칙형", "분석형", "승부형", "육성형"]
        let expectedCatcherArchetypes = ["안정형", "분석형", "공격형", "공감형"]

        for (regionIndex, rawRegion) in HighSchoolCareerEngine.regions.enumerated() {
            let baseline = HighSchoolCareerEngine.schools(for: rawRegion)
            XCTAssertEqual(baseline.map(\.id), expectedSchoolIDs, rawRegion)
            XCTAssertEqual(baseline.map(\.name), expectedRegionalNames[regionIndex], rawRegion)
            XCTAssertEqual(baseline.map(\.strength), expectedStrengths, rawRegion)
            XCTAssertEqual(baseline.map(\.philosophy), expectedPhilosophies, rawRegion)
            XCTAssertEqual(baseline.map(\.tradeoff), expectedTradeoffs, rawRegion)
            XCTAssertEqual(baseline.map(\.coachArchetype), expectedCoachArchetypes, rawRegion)
            XCTAssertEqual(baseline.map(\.catcherArchetype), expectedCatcherArchetypes, rawRegion)
            XCTAssertEqual(
                baseline.map(\.coachName),
                expectedCoachPools.map { $0[regionIndex % 5] },
                rawRegion
            )
            XCTAssertEqual(
                baseline.map(\.catcherName),
                expectedCatcherPools.map { $0[regionIndex % 5] },
                rawRegion
            )

            _ = baseline.map { CopyToken.schoolSelection(rawRegion: rawRegion, schoolID: $0.id) }
            let afterPresentationLookup = HighSchoolCareerEngine.schools(for: rawRegion)
            XCTAssertEqual(afterPresentationLookup, baseline, rawRegion)
            XCTAssertEqual(afterPresentationLookup.map(\.id), expectedSchoolIDs, rawRegion)
            XCTAssertEqual(
                afterPresentationLookup.flatMap { [$0.coachName, $0.catcherName] },
                baseline.flatMap { [$0.coachName, $0.catcherName] },
                rawRegion
            )
        }
    }

    func testPitcherPresetDescriptorsEnumerateEveryCurrentIDAndDisplaySlot() throws {
        let expectedIDs = [
            "power_prospect",
            "precision_commander",
            "breaking_ball_artist",
            "innings_eater",
        ]
        let expectedSlots = [
            "name", "tagline", "strength.0", "strength.1", "strength.2", "tradeoff", "default-name",
        ]
        let descriptors = CopyToken.pitcherPresetDescriptors

        XCTAssertEqual(PitcherPresetCatalog.all.map(\.id), expectedIDs)
        XCTAssertEqual(descriptors.count, expectedIDs.count * expectedSlots.count)
        XCTAssertEqual(Set(descriptors.map(\.presetID)), Set(expectedIDs))
        XCTAssertEqual(
            Set(descriptors.map { "\($0.presetID).\($0.slot)" }).count,
            descriptors.count
        )

        for presetID in expectedIDs {
            let presetDescriptors = descriptors.filter { $0.presetID == presetID }
            XCTAssertEqual(presetDescriptors.map(\.slot), expectedSlots, presetID)
            for descriptor in presetDescriptors {
                XCTAssertEqual(
                    descriptor.token.key,
                    "content.pitcher-preset.\(presetID).\(descriptor.slot)"
                )
            }
        }

        let preset = try XCTUnwrap(PitcherPresetCatalog.all.first)
        XCTAssertEqual(preset.nameCopyToken.key, "content.pitcher-preset.power_prospect.name")
        XCTAssertEqual(preset.taglineCopyToken.key, "content.pitcher-preset.power_prospect.tagline")
        XCTAssertEqual(
            preset.strengthCopyTokens.map(\.key),
            [
                "content.pitcher-preset.power_prospect.strength.0",
                "content.pitcher-preset.power_prospect.strength.1",
                "content.pitcher-preset.power_prospect.strength.2",
            ]
        )
        XCTAssertEqual(preset.tradeoffCopyToken.key, "content.pitcher-preset.power_prospect.tradeoff")
        XCTAssertEqual(
            preset.defaultPlayerNameCopyToken.key,
            "content.pitcher-preset.power_prospect.default-name"
        )
    }

    func testClosedEnumDescriptorsCoverEveryCaseWithStableRawValueIDs() {
        let descriptors = CopyToken.closedEnumDescriptors

        XCTAssertEqual(
            Set(descriptors.map(\.token.key)).count,
            descriptors.count
        )
        XCTAssertTrue(descriptors.allSatisfy { $0.token.arguments.isEmpty })

        func assertFamily(
            _ family: PresentationCopyFamily,
            rawValues: [String]
        ) {
            let familyDescriptors = descriptors.filter { $0.family == family }
            XCTAssertEqual(familyDescriptors.map(\.rawValue), rawValues, family.rawValue)
            XCTAssertEqual(
                familyDescriptors.map { $0.token.key },
                rawValues.map {
                    let slot = family == .pitchType ? "name" : "label"
                    return "content.\(family.rawValue).\($0).\(slot)"
                },
                family.rawValue
            )
        }

        assertFamily(.pitchType, rawValues: ["four_seam", "slider", "curveball", "changeup"])
        assertFamily(.pitchIntensity, rawValues: ["controlled", "normal", "max_effort"])
        assertFamily(.pitchUsage, rawValues: ["primary", "secondary", "development"])
        assertFamily(.batterSide, rawValues: ["right", "left", "switch"])
        assertFamily(
            .pitchOutcome,
            rawValues: [
                "ball", "called_strike", "swinging_strike", "foul", "in_play_out",
                "single", "double", "triple", "home_run", "hit_by_pitch",
            ]
        )
        assertFamily(.zoneIntent, rawValues: ["strike", "edge", "chase"])
        assertFamily(
            .highSchoolPhase,
            rawValues: [
                "prologue", "school_selection", "training", "relationship", "important_game",
                "awakening", "chapter_review", "draft", "legacy", "completed",
            ]
        )
        assertFamily(
            .trainingFocus,
            rawValues: ["velocity", "command", "breaking_ball", "stamina", "recovery", "game_planning"]
        )
        assertFamily(.trainingIntensity, rawValues: ["light", "standard", "intensive"])
        assertFamily(.relationshipTarget, rawValues: ["coach", "catcher", "rival"])
        assertFamily(.relationshipResponse, rawValues: ["listen", "explain", "challenge"])
        assertFamily(.draftOutcome, rawValues: ["drafted", "undrafted"])
        assertFamily(.armHealth, rawValues: ["normal", "caution", "warning", "recovering"])
        assertFamily(
            .proCareerPhase,
            rawValues: [
                "contract_offer", "weekly_plan", "season_decision", "important_game",
                "season_review", "offseason_decision", "retirement_decision", "completed",
            ]
        )
        assertFamily(.proLevel, rawValues: ["minor", "major"])
        assertFamily(.proRole, rawValues: ["starter", "long_relief", "setup", "closer"])
        assertFamily(
            .proWeekPlan,
            rawValues: [
                "develop_stuff", "develop_movement", "develop_weapon", "refine_command",
                "build_stamina", "recover", "earn_trust",
            ]
        )
        assertFamily(
            .offseasonDecision,
            rawValues: ["continue", "military_service", "free_agency", "retire"]
        )
        assertFamily(
            .proSeasonDecisionType,
            rawValues: [
                "extra_bullpen", "catcher_game_plan", "role_meeting", "record_chase",
                "rival_analysis", "season_finale",
            ]
        )
        assertFamily(
            .proSeasonSegment,
            rawValues: ["spring_camp", "opening", "first_half", "all_star_break", "pennant_race", "season_finale"]
        )
        assertFamily(
            .proSeasonTrigger,
            rawValues: [
                "opening_statement", "call_up_audition", "major_debut", "record_chase",
                "role_showdown", "standings_race",
            ]
        )
    }

    func testPresentationTokensDoNotChangeCatalogOrderOrStableIDs() throws {
        let eventIDsBefore = HighSchoolContentCatalog.events.map(\.id)
        let scenarioIDsBefore = HighSchoolContentCatalog.scenarios.map(\.id)
        let schoolIDsBefore = SchoolID.allCases.map(\.rawValue)

        _ = HighSchoolContentCatalog.events.map { [$0.titleCopyToken, $0.summaryCopyToken] }
        _ = HighSchoolContentCatalog.scenarios.map { [$0.titleCopyToken, $0.narrativeCopyToken] }
        _ = SchoolID.allCases.map(\.nameCopyToken)

        XCTAssertEqual(HighSchoolContentCatalog.events.map(\.id), eventIDsBefore)
        XCTAssertEqual(HighSchoolContentCatalog.scenarios.map(\.id), scenarioIDsBefore)
        XCTAssertEqual(SchoolID.allCases.map(\.rawValue), schoolIDsBefore)
    }

    func testRelationshipPresentationRegistryCoversEveryCurrentSemanticSurface() throws {
        let currentEventIDs = HighSchoolContentCatalog.relationshipEvents.map(\.id)
        XCTAssertEqual(RelationshipPresentationCatalog.eventIDs, currentEventIDs)
        XCTAssertEqual(Set(RelationshipPresentationCatalog.eventIDs).count, currentEventIDs.count)
        XCTAssertEqual(RelationshipPresentationCatalog.eventDescriptors.count, currentEventIDs.count)

        let sceneIDs = RelationshipVoiceCatalog.scenes.keys.sorted()
        XCTAssertEqual(RelationshipPresentationCatalog.sceneIDs, sceneIDs)
        XCTAssertEqual(
            RelationshipPresentationCatalog.quoteDescriptors.count,
            sceneIDs.count * 3
        )
        XCTAssertEqual(
            Set(RelationshipPresentationCatalog.quoteDescriptors.map(\.token.key)).count,
            RelationshipPresentationCatalog.quoteDescriptors.count
        )
        for descriptor in RelationshipPresentationCatalog.quoteDescriptors {
            XCTAssertEqual(
                descriptor.token.key,
                "content.relationship.\(descriptor.eventID).quote.\(descriptor.trustBand.rawValue)"
            )
        }

        let expectedChoiceCount = sceneIDs.count * 3
            + RelationshipVoiceCatalog.categoryScenes.count * 3
            + RelationshipResponse.allCases.count
        XCTAssertEqual(RelationshipPresentationCatalog.choiceDescriptors.count, expectedChoiceCount)
        XCTAssertEqual(
            Set(RelationshipPresentationCatalog.choiceDescriptors.flatMap {
                [$0.titleToken.key, $0.detailToken.key]
            }).count,
            expectedChoiceCount * 2
        )

        for event in HighSchoolContentCatalog.relationshipEvents {
            let card = RelationshipPresentationCatalog.cardDescriptor(for: event)
            XCTAssertEqual(card.event.eventID, event.id)
            XCTAssertTrue(card.event.isKnownEvent, event.id)
            if RelationshipVoiceCatalog.scenes[event.id] != nil {
                XCTAssertEqual(card.quoteDescriptors.count, 3, event.id)
                XCTAssertEqual(card.choiceDescriptors.count, 3, event.id)
                XCTAssertTrue(card.choiceDescriptors.allSatisfy { $0.scopeID == event.id }, event.id)
            } else {
                XCTAssertTrue(card.quoteDescriptors.isEmpty, event.id)
                XCTAssertEqual(card.choiceDescriptors.count, 3, event.id)
                XCTAssertTrue(
                    card.choiceDescriptors.allSatisfy {
                        $0.scopeID == "category.\(event.category)"
                    },
                    event.id
                )
            }
        }

        XCTAssertEqual(
            Set(RelationshipPresentationCatalog.categoryIDs),
            Set(HighSchoolContentCatalog.relationshipEvents.map(\.category))
        )
        XCTAssertEqual(
            Set(RelationshipPresentationCatalog.categorySceneIDs),
            Set(RelationshipVoiceCatalog.categoryScenes.keys)
        )
        let fallback = RelationshipPresentationCatalog.fallbackCardDescriptor(
            eventID: "legacy-event",
            categoryID: "legacy-category"
        )
        XCTAssertFalse(fallback.event.isKnownEvent)
        XCTAssertEqual(fallback.event.titleToken.key, "content.relationship.fallback.event.title")
        XCTAssertEqual(fallback.choiceDescriptors.count, RelationshipResponse.allCases.count)
        XCTAssertFalse(
            fallback.choiceDescriptors.contains {
                $0.titleToken.key.contains("legacy") || $0.detailToken.key.contains("legacy")
            }
        )

        XCTAssertEqual(RivalPresentationCatalog.descriptors.count, 8)
        XCTAssertEqual(
            Set(RivalPresentationCatalog.descriptors.map(\.rivalID)).count,
            RivalPresentationCatalog.descriptors.count
        )
        let unknownRival = RivalPresentationCatalog.descriptor(for: "legacy-rival")
        XCTAssertFalse(unknownRival.isKnownRival)
        XCTAssertEqual(unknownRival.nameToken.key, "content.rival.fallback.name")
        XCTAssertEqual(unknownRival.archetypeToken.key, "content.rival.fallback.archetype")
        XCTAssertEqual(unknownRival.signatureToken.key, "content.rival.fallback.signature")

        XCTAssertEqual(CopyToken.schoolFallbackDescriptors.count, SchoolID.allCases.count * 3)
        XCTAssertEqual(
            Set(CopyToken.schoolFallbackDescriptors.map(\.token.key)).count,
            CopyToken.schoolFallbackDescriptors.count
        )
        for schoolID in SchoolID.allCases {
            XCTAssertEqual(
                schoolID.fallbackNameCopyToken.key,
                "content.school.fallback.\(schoolID.rawValue).name"
            )
            XCTAssertEqual(
                CopyToken.schoolFallbackCastName(schoolID: schoolID, role: .coach).key,
                "content.school.fallback.\(schoolID.rawValue).coach.name"
            )
            XCTAssertEqual(
                CopyToken.schoolFallbackCastName(schoolID: schoolID, role: .catcher).key,
                "content.school.fallback.\(schoolID.rawValue).catcher.name"
            )
        }
    }

    func testImportantGamePresentationRegistryCoversAllCurrentScenariosAndFallbacks() throws {
        let scenarios = HighSchoolContentCatalog.scenarios
        XCTAssertEqual(scenarios.count, 30)
        XCTAssertEqual(ImportantGamePresentationCatalog.scenarioIDs, scenarios.map(\.id))
        XCTAssertEqual(
            ImportantGamePresentationCatalog.scenarioDescriptors.count,
            scenarios.count
        )
        XCTAssertEqual(
            Set(ImportantGamePresentationCatalog.scenarioDescriptors.map(\.scenarioID)).count,
            scenarios.count
        )

        for (scenario, descriptor) in zip(scenarios, ImportantGamePresentationCatalog.scenarioDescriptors) {
            XCTAssertEqual(descriptor.scenarioID, scenario.id)
            XCTAssertTrue(descriptor.isKnownScenario, scenario.id)
            XCTAssertEqual(
                descriptor.titleToken.key,
                "content.important-game.\(scenario.id).title"
            )
            XCTAssertEqual(
                descriptor.narrativeToken.key,
                "content.important-game.\(scenario.id).narrative"
            )
            XCTAssertTrue(descriptor.titleToken.arguments.isEmpty, scenario.id)
            XCTAssertTrue(descriptor.narrativeToken.arguments.isEmpty, scenario.id)
        }

        let unknown = ImportantGamePresentationCatalog.descriptor(for: "legacy-scenario")
        XCTAssertFalse(unknown.isKnownScenario)
        XCTAssertEqual(unknown.titleToken.key, "content.important-game.fallback.title")
        XCTAssertEqual(unknown.narrativeToken.key, "content.important-game.fallback.narrative")
        XCTAssertFalse(unknown.titleToken.key.contains("legacy-scenario"))
        XCTAssertFalse(unknown.narrativeToken.key.contains("legacy-scenario"))

    }

    func testImportantGamePresentationLookupIsTransientAndDoesNotTouchSaveOrRNG() throws {
        let started = try HighSchoolCareerEngine().start(
            .init(seed: "20260813", presetID: "power_prospect", lifeNumber: 2)
        )
        let beforeData = try JSONEncoder().encode(started.snapshot)
        let beforeSnapshot = started.snapshot
        let beforeNextSeed = started.nextSeed
        let beforeEventHash = started.eventHash
        let beforeCommitment = started.snapshot.stateCommitment

        for scenario in HighSchoolContentCatalog.scenarios {
            _ = ImportantGamePresentationCatalog.descriptor(for: scenario.id)
            _ = scenario.titleCopyToken
            _ = scenario.narrativeCopyToken
        }
        _ = ImportantGamePresentationCatalog.descriptor(for: "legacy-scenario")

        XCTAssertEqual(try JSONEncoder().encode(started.snapshot), beforeData)
        XCTAssertEqual(started.snapshot, beforeSnapshot)
        XCTAssertEqual(started.snapshot.stateCommitment, beforeCommitment)
        XCTAssertEqual(started.nextSeed, beforeNextSeed)
        XCTAssertEqual(started.eventHash, beforeEventHash)

        var baseline = SplitMix64(seed: 0x1A2B3C)
        var presented = SplitMix64(seed: 0x1A2B3C)
        _ = ImportantGamePresentationCatalog.scenarioDescriptors
        XCTAssertEqual(presented.next(), baseline.next())
        XCTAssertEqual(presented.state, baseline.state)
    }

    func testRelationshipPresentationLookupIsTransientAndDoesNotTouchSnapshotOrRNG() throws {
        let engine = HighSchoolCareerEngine()
        let started = try engine.start(
            .init(seed: "20260813", presetID: "power_prospect", lifeNumber: 2)
        )
        let beforeData = try JSONEncoder().encode(started.snapshot)
        let beforeSnapshot = started.snapshot
        let beforeNextSeed = started.nextSeed
        let beforeEventHash = started.eventHash

        for event in HighSchoolContentCatalog.relationshipEvents {
            _ = RelationshipPresentationCatalog.cardDescriptor(for: event)
        }
        _ = RelationshipPresentationCatalog.fallbackCardDescriptor(
            eventID: "legacy-event",
            categoryID: "legacy-category"
        )
        _ = RivalPresentationCatalog.descriptor(for: started.snapshot.rival.id)
        _ = RivalPresentationCatalog.descriptor(for: "legacy-rival")
        for region in SchoolRegionID.allCases {
            for schoolID in SchoolID.allCases {
                _ = CopyToken.schoolSelectionDescriptor(region: region, schoolID: schoolID)
            }
        }
        _ = RelationshipPresentationCatalog.windDescriptor(
            for: started.snapshot.careerWind,
            target: .catcher
        )

        XCTAssertEqual(try JSONEncoder().encode(started.snapshot), beforeData)
        XCTAssertEqual(started.snapshot, beforeSnapshot)
        XCTAssertEqual(started.nextSeed, beforeNextSeed)
        XCTAssertEqual(started.eventHash, beforeEventHash)

        var baseline = SplitMix64(seed: 0x5EED)
        var presented = SplitMix64(seed: 0x5EED)
        _ = RelationshipPresentationCatalog.eventDescriptors
        XCTAssertEqual(presented.next(), baseline.next())
        XCTAssertEqual(presented.state, baseline.state)
    }

    func testPresentationTokensDoNotChangeRNGOrSimulationEventHash() throws {
        let params = SimulatePitchParams(
            seed: "20260721",
            pitcher: PitcherSnapshot(
                id: "pitcher-1", name: "테스트 투수", stuff: 62, command: 54,
                movement: 58, stamina: 60
            ),
            batter: BatterSnapshot(
                id: "batter-1", name: "테스트 타자", contact: 56, discipline: 52, power: 58
            ),
            count: CountState(balls: 1, strikes: 1),
            fatigue: 12,
            selection: PitchSelection(
                pitchType: .slider,
                zone: PitchZone(row: 2, column: 0),
                intensity: .normal
            )
        )
        let engine = SimulationEngine()
        let baseline = try engine.simulatePitch(params)

        let token = CopyToken.highSchoolEventTitle(eventID: "evt-catcher-sign")
        XCTAssertEqual(token.key, "content.event.evt-catcher-sign.title")

        let presented = try engine.simulatePitch(params)
        XCTAssertEqual(presented, baseline)
        XCTAssertEqual(presented.events.map(\.eventHash), baseline.events.map(\.eventHash))

        var baselineRNG = SplitMix64(seed: 0x1234)
        var presentedRNG = SplitMix64(seed: 0x1234)
        XCTAssertEqual(baselineRNG.state, presentedRNG.state)
        _ = CopyToken.relationshipQuote(
            eventID: "evt-catcher-sign", trustBand: .mid, playerName: "선수"
        )
        XCTAssertEqual(presentedRNG.next(), baselineRNG.next())
        XCTAssertEqual(presentedRNG.state, baselineRNG.state)
    }

    func testExistingSaveDecodesWithoutPresentationFields() throws {
        let started = try HighSchoolCareerEngine().start(
            .init(seed: "20260725", presetID: "power_prospect")
        )
        let encodedBeforePresentation = try JSONEncoder().encode(started.snapshot)
        _ = started.snapshot.currentGameScenario?.titleCopyToken
        _ = started.snapshot.currentRelationshipEvent?.summaryCopyToken
        let decoded = try JSONDecoder().decode(
            HighSchoolCareerSnapshot.self,
            from: encodedBeforePresentation
        )

        XCTAssertEqual(decoded, started.snapshot)
        XCTAssertFalse(String(decoding: encodedBeforePresentation, as: UTF8.self).contains("copyToken"))
        XCTAssertFalse(String(decoding: encodedBeforePresentation, as: UTF8.self).contains("presentation"))
    }

    func testPrologueCatalogEnumeratesExactCurrentVersionsEffectsKarmasAndOpeners() {
        XCTAssertEqual(
            PrologueOpenerVariant.allCases.map(\.rawValue),
            ["first-life", "repeat-life-1", "repeat-life-2", "repeat-life-3", "fallback"]
        )
        XCTAssertEqual(ProloguePresentationCatalog.openerDescriptors.count, 5)
        XCTAssertEqual(
            ProloguePresentationCatalog.openerDescriptors.map(\.openerToken.key),
            [
                "content.prologue.first-life.context",
                "content.prologue.repeat-life-1.context",
                "content.prologue.repeat-life-2.context",
                "content.prologue.repeat-life-3.context",
                "content.prologue.fallback.context",
            ]
        )
        XCTAssertEqual(
            PrologueOpenerVariant.resolve(lifeNumber: 1), .firstLife
        )
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 2), .repeatLifeFirst)
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 5), .repeatLifeFirst)
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 3), .repeatLifeSecond)
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 6), .repeatLifeSecond)
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 4), .repeatLifeThird)
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 7), .repeatLifeThird)
        XCTAssertEqual(PrologueOpenerVariant.resolve(lifeNumber: 0), .fallback)
        XCTAssertEqual(
            ProloguePresentationCatalog.opener(lifeNumber: 4, region: .busan).openerToken.arguments,
            [.contentID("busan")]
        )
        XCTAssertEqual(
            ProloguePresentationCatalog.opener(lifeNumber: 0, region: .busan).openerToken.arguments,
            []
        )

        let knownRawLifeTwo = ProloguePresentationCatalog.opener(
            lifeNumber: 2,
            rawRegion: "부산"
        )
        XCTAssertEqual(knownRawLifeTwo.variant, .repeatLifeFirst)
        XCTAssertEqual(knownRawLifeTwo.region, .busan)
        XCTAssertEqual(knownRawLifeTwo.openerToken.arguments, [.contentID("busan")])

        let knownRawLifeThree = ProloguePresentationCatalog.opener(
            lifeNumber: 3,
            rawRegion: "부산"
        )
        XCTAssertEqual(knownRawLifeThree.variant, .repeatLifeSecond)
        XCTAssertEqual(knownRawLifeThree.region, .busan)

        let knownRawLifeFour = ProloguePresentationCatalog.opener(
            lifeNumber: 4,
            rawRegion: "부산"
        )
        XCTAssertEqual(knownRawLifeFour.variant, .repeatLifeThird)
        XCTAssertEqual(knownRawLifeFour.region, .busan)

        let unknownRaw = ProloguePresentationCatalog.opener(
            lifeNumber: 2,
            rawRegion: "legacy-region"
        )
        XCTAssertEqual(unknownRaw.variant, .fallback)
        XCTAssertNil(unknownRaw.region)
        XCTAssertEqual(unknownRaw.openerToken.key, "content.prologue.fallback.context")
        XCTAssertEqual(unknownRaw.openerToken.arguments, [])

        XCTAssertEqual(CareerWind.all.count, 5)
        XCTAssertEqual(
            CareerWindPresentationCatalog.v1PoolDescriptors.map { "\($0.rulesVersion.rawValue):\($0.id)" },
            ["1:calm", "1:calm", "1:monster_generation", "1:scout_frenzy", "1:quiet_season"]
        )
        XCTAssertEqual(
            CareerWindPresentationCatalog.v1Descriptors.map { "\($0.rulesVersion.rawValue):\($0.id)" },
            ["1:calm", "1:monster_generation", "1:scout_frenzy", "1:quiet_season"]
        )
        XCTAssertEqual(
            CareerWindPresentationCatalog.v2Descriptors.map { "\($0.rulesVersion.rawValue):\($0.id)" },
            [
                "2:calm", "2:monster_generation", "2:scout_frenzy", "2:quiet_season", "2:heatwave",
                "2:command_year", "2:power_year", "2:battery_year", "2:spotlight_year", "2:underdog_year",
            ]
        )
        XCTAssertEqual(CareerWindPresentationCatalog.v1Descriptors.count, 4)
        XCTAssertEqual(CareerWindPresentationCatalog.v2Descriptors.count, 10)
        XCTAssertEqual(CareerWindPresentationCatalog.descriptors.count, 14)
        XCTAssertEqual(CareerWindPresentationCatalog.v1PoolDescriptors.map(\.id), CareerWind.all.map(\.id))
        XCTAssertEqual(CareerWindPresentationCatalog.v2Descriptors.map(\.id), CareerWind.v2All.map(\.id))

        for descriptor in CareerWindPresentationCatalog.descriptors {
            XCTAssertEqual(
                descriptor.titleToken.key,
                "content.career-wind.v\(descriptor.rulesVersion.rawValue).\(descriptor.id).title"
            )
            XCTAssertEqual(
                descriptor.detailToken.key,
                "content.career-wind.v\(descriptor.rulesVersion.rawValue).\(descriptor.id).detail"
            )
        }

        let expectedEffectSlots: [String: [String]] = [
            "1:calm": [],
            "1:monster_generation": ["rival-ability", "inheritance-bonus"],
            "1:scout_frenzy": ["starting-fan-interest"],
            "1:quiet_season": ["starting-fan-interest", "rival-ability", "inheritance-bonus"],
            "2:calm": [],
            "2:monster_generation": ["fan-interest", "rival-ability", "inheritance-bonus"],
            "2:scout_frenzy": ["starting-fan-interest"],
            "2:quiet_season": ["starting-fan-interest", "rival-ability", "inheritance-bonus"],
            "2:heatwave": ["recovery", "training-fatigue", "inheritance-bonus"],
            "2:command_year": ["favored-training.command", "extra-fatigue.velocity", "inheritance-bonus"],
            "2:power_year": ["favored-training.velocity", "rival-ability", "inheritance-bonus"],
            "2:battery_year": ["favored-relationship.catcher", "starting-fan-interest", "inheritance-bonus"],
            "2:spotlight_year": ["fan-interest", "relationship-loss", "inheritance-bonus"],
            "2:underdog_year": ["draft-evaluation", "starting-fan-interest", "rival-ability", "inheritance-bonus"],
        ]

        let allWindDescriptors = CareerWindPresentationCatalog.descriptors
        XCTAssertEqual(
            allWindDescriptors.flatMap(\.effectDescriptors).count,
            32
        )
        XCTAssertEqual(
            Set(allWindDescriptors.map(\.titleToken.key) + allWindDescriptors.map(\.detailToken.key)).count,
            14 * 2
        )
        XCTAssertEqual(
            Set(allWindDescriptors.flatMap { $0.effectDescriptors.map(\.token.key) }).count,
            32
        )

        func expectedArgument(for wind: CareerWind, slot: String) -> Int? {
            switch slot {
            case "favored-training.command", "favored-training.velocity":
                return wind.rules.favoredTrainingBonus
            case "recovery":
                return wind.rules.recoveryBonus
            case "favored-relationship.catcher":
                return wind.rules.favoredRelationshipBonus
            case "fan-interest":
                return wind.rules.fanInterestGainBonus
            case "draft-evaluation":
                return wind.rules.draftEvaluationDelta
            case "starting-fan-interest":
                return wind.startingFanInterest
            case "rival-ability":
                return wind.rivalBonus
            case "training-fatigue":
                return wind.rules.trainingFatigueDelta
            case "extra-fatigue.velocity":
                return wind.rules.extraFatigueDelta
            case "relationship-loss":
                return wind.rules.relationshipLossPenalty
            case "inheritance-bonus":
                return wind.rewardBonusPermille / 10
            default:
                return nil
            }
        }

        for descriptor in allWindDescriptors {
            let variant = "\(descriptor.rulesVersion.rawValue):\(descriptor.id)"
            let expected = expectedEffectSlots[variant] ?? []
            XCTAssertEqual(descriptor.effectDescriptors.map(\.slot), expected, variant)
            XCTAssertEqual(
                descriptor.effectDescriptors.map(\.token.key),
                expected.map {
                    "content.career-wind.v\(descriptor.rulesVersion.rawValue).\(descriptor.id).effect.\($0)"
                },
                variant
            )
            let rawWind = (CareerWind.all + CareerWind.v2All).first {
                $0.id == descriptor.id && $0.rulesVersion == descriptor.rulesVersion
            }!
            for effect in descriptor.effectDescriptors {
                XCTAssertEqual(effect.token.arguments.count, 1, effect.slot)
                guard case .integer(let value) = effect.token.arguments.first else {
                    XCTFail("Effect argument is not numeric: \(effect.token.key)")
                    continue
                }
                XCTAssertEqual(value, expectedArgument(for: rawWind, slot: effect.slot), effect.slot)
            }
        }

        XCTAssertEqual(KarmaPresentationCatalog.descriptors.count, 6)
        XCTAssertEqual(
            KarmaID.allCases.map(\.rawValue),
            ["unknown_land", "stubborn_coach", "single_weapon", "genius_generation", "erased_memory", "no_last_chance"]
        )
        XCTAssertEqual(KarmaID.allCases.map(\.rewardPermille), [150, 150, 200, 250, 250, 350])
        XCTAssertEqual(
            KarmaPresentationCatalog.descriptors.map(\.titleToken.key),
            KarmaID.allCases.map { "content.karma.\($0.rawValue).title" }
        )
        XCTAssertEqual(
            KarmaPresentationCatalog.descriptors.map(\.detailToken.key),
            KarmaID.allCases.map { "content.karma.\($0.rawValue).detail" }
        )
    }

    func testProloguePresentationDescriptorsDoNotTouchSnapshotNewsSaveOrRNGInputs() throws {
        let engine = HighSchoolCareerEngine()
        let started = try engine.start(.init(seed: "20260813", presetID: "power_prospect", lifeNumber: 2))
        let beforeData = try JSONEncoder().encode(started.snapshot)
        let beforeNews = started.snapshot.news
        let beforeWind = started.snapshot.careerWind

        _ = ProloguePresentationCatalog.opener(lifeNumber: started.snapshot.lifeNumber, rawRegion: started.snapshot.identity.region)
        _ = CareerWindPresentationCatalog.descriptor(for: started.snapshot.careerWind)
        _ = KarmaPresentationCatalog.descriptors
        var rngBefore = SplitMix64(seed: 0xC0FFEE)
        var rngAfter = SplitMix64(seed: 0xC0FFEE)
        _ = rngAfter.next()
        _ = rngBefore.next()

        let afterData = try JSONEncoder().encode(started.snapshot)
        XCTAssertEqual(
            try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: afterData),
            try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: beforeData)
        )
        XCTAssertFalse(String(decoding: afterData, as: UTF8.self).contains("presentation"))
        XCTAssertFalse(String(decoding: afterData, as: UTF8.self).contains("copyToken"))
        XCTAssertEqual(started.snapshot.news, beforeNews)
        XCTAssertEqual(started.snapshot.careerWind, beforeWind)
        XCTAssertEqual(rngAfter.state, rngBefore.state)
    }

    func testChapterAndTrainingPresentationRegistriesAreCompleteAndFallbackSafe() {
        let chapters = CareerChapterPresentationCatalog.descriptors
        XCTAssertEqual(chapters.map(\.number), Array(1...8))
        XCTAssertEqual(chapters.map(\.actNumber), [1, 1, 2, 2, 3, 3, 4, 4])
        XCTAssertEqual(chapters.count, Set(chapters.map(\.number)).count)

        let chapterTokens = chapters.flatMap { [$0.titleToken, $0.actTitleToken, $0.seasonToken] }
        XCTAssertEqual(Set(chapterTokens.map(\.key)).count, 16)
        XCTAssertTrue(chapterTokens.allSatisfy { !$0.key.contains("낯선") && !$0.key.contains("봄") })

        XCTAssertEqual(TrainingPresentationCatalog.focusDetailDescriptors.count, 6)
        XCTAssertEqual(TrainingPresentationCatalog.focusTradeoffDescriptors.count, 6)
        XCTAssertEqual(TrainingPresentationCatalog.focusMetricDescriptors.count, 6)
        XCTAssertEqual(TrainingPresentationCatalog.recoveryIntensityDescriptors.count, 3)
        XCTAssertEqual(TrainingPresentationCatalog.outlookDescriptors.count, 6)
        XCTAssertEqual(TrainingPresentationCatalog.abilityDescriptors.count, 4)
        XCTAssertEqual(TrainingPresentationCatalog.gradeDescriptors.count, 5)

        let trainingDescriptorTokens =
            TrainingPresentationCatalog.focusDetailDescriptors.map(\.token)
            + TrainingPresentationCatalog.focusTradeoffDescriptors.map(\.token)
            + TrainingPresentationCatalog.focusMetricDescriptors.map(\.token)
            + TrainingPresentationCatalog.recoveryIntensityDescriptors.map(\.token)
            + TrainingPresentationCatalog.outlookDescriptors.map(\.token)
            + TrainingPresentationCatalog.abilityDescriptors.map(\.token)
            + TrainingPresentationCatalog.gradeDescriptors.map(\.token)
        XCTAssertEqual(
            Set(trainingDescriptorTokens.map(\.key)).count,
            trainingDescriptorTokens.count
        )

        let opportunities = TrainingPresentationCatalog.opportunityReasonDescriptors
        let fallbacks = TrainingPresentationCatalog.opportunityFallbackDescriptors
        XCTAssertEqual(opportunities.count, TrainingFocus.allCases.count * 3)
        XCTAssertEqual(fallbacks.count, TrainingFocus.allCases.count)
        XCTAssertEqual(Set(opportunities.map(\.token.key)).count, opportunities.count)
        XCTAssertEqual(Set(fallbacks.map(\.token.key)).count, fallbacks.count)

        for focus in TrainingFocus.allCases {
            let reasons = HighSchoolCareerEngine.opportunityReasons[focus] ?? []
            XCTAssertEqual(reasons.count, 3, focus.rawValue)
            for (slot, reason) in reasons.enumerated() {
                let descriptor = TrainingOpportunitySnapshot(focus: focus, reason: reason).copyDescriptor
                XCTAssertEqual(descriptor.reasonSlot, slot, "\(focus.rawValue):\(slot)")
                XCTAssertEqual(
                    descriptor.token.key,
                    "content.training-opportunity.\(focus.rawValue).reason.\(slot)"
                )
            }

            let unknownRaw = "legacy-opportunity-\(focus.rawValue)-한국어"
            let fallback = TrainingOpportunitySnapshot(focus: focus, reason: unknownRaw).copyDescriptor
            XCTAssertTrue(fallback.isFallback, focus.rawValue)
            XCTAssertFalse(fallback.token.key.contains(unknownRaw), focus.rawValue)
            XCTAssertEqual(
                fallback.token.key,
                "content.training-opportunity.\(focus.rawValue).reason.fallback"
            )
        }

        let unknownChapter = CareerChapterSnapshot(
            number: 99,
            title: "legacy Korean title",
            schoolYear: 9,
            season: "legacy Korean season",
            theme: "legacy Korean theme"
        )
        let fallbackChapter = unknownChapter.copyDescriptor
        XCTAssertEqual(fallbackChapter, CareerChapterPresentationCatalog.fallback)
        XCTAssertFalse(fallbackChapter.titleToken.key.contains("legacy"))
    }

    func testChapterAndTrainingPresentationIsTransientAndDoesNotTouchSaveCommitment() throws {
        let started = try HighSchoolCareerEngine().start(
            .init(seed: "202608131234", presetID: "power_prospect")
        )
        let beforeData = try JSONEncoder().encode(started.snapshot)
        let beforeCommitment = started.snapshot.stateCommitment

        _ = started.snapshot.chapter.copyDescriptor
        _ = TrainingFocus.allCases.flatMap { focus in
            [focus.detailCopyToken, focus.tradeoffCopyToken, focus.metricCopyToken]
        }
        _ = TrainingPresentationCatalog.opportunity(
            TrainingOpportunitySnapshot(focus: .velocity, reason: "legacy Korean raw")
        )
        _ = TrainingPresentationCatalog.outlookDescriptors
        _ = TalentAbility.allCases.map(\.displayCopyToken)
        _ = TalentGrade.allCases.map(\.displayCopyToken)

        let afterData = try JSONEncoder().encode(started.snapshot)
        XCTAssertEqual(
            try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: beforeData),
            try JSONDecoder().decode(HighSchoolCareerSnapshot.self, from: afterData)
        )
        XCTAssertEqual(beforeCommitment, started.snapshot.stateCommitment)
        XCTAssertFalse(String(decoding: afterData, as: UTF8.self).contains("presentation"))
        XCTAssertFalse(String(decoding: afterData, as: UTF8.self).contains("copyToken"))
    }

    func testNextHighSchoolPresentationInventoriesAreExactAndTyped() {
        XCTAssertEqual(
            ChapterReviewPresentationCatalog.verdictDescriptors.map(\.id),
            ChapterReviewVerdictID.allCases
        )
        XCTAssertEqual(ChapterReviewPresentationCatalog.verdictDescriptors.count, 4)
        XCTAssertTrue(
            ChapterReviewPresentationCatalog.verdictDescriptors.allSatisfy { $0.token.arguments.isEmpty }
        )

        XCTAssertEqual(
            TournamentPresentationCatalog.tournamentNameDescriptors.map(\.chapterNumber),
            [2, 4, 6, 8]
        )
        XCTAssertEqual(TournamentPresentationCatalog.roundDescriptors.count, 3)
        XCTAssertEqual(
            TournamentPresentationCatalog.roundDescriptors.map(\.rawValue),
            ["8강", "준결승", "결승"]
        )
        XCTAssertEqual(TournamentPresentationCatalog.opponentSchoolDescriptors.count, 12)
        XCTAssertEqual(
            TournamentPresentationCatalog.opponentSchoolDescriptors.map(\.rawSchoolName),
            ["북부상고", "남해정보고", "동성공고", "서령고", "중앙체고", "한서고", "대양고", "청암고", "금강고", "삼도고", "백파고", "운암공고"]
        )
        let tournamentTokens = TournamentPresentationCatalog.tournamentNameDescriptors.map(\.token)
            + TournamentPresentationCatalog.roundDescriptors.map(\.token)
            + TournamentPresentationCatalog.opponentSchoolDescriptors.map(\.token)
        XCTAssertEqual(Set(tournamentTokens.map(\.key)).count, tournamentTokens.count)
        XCTAssertTrue(tournamentTokens.allSatisfy { $0.arguments.isEmpty })

        XCTAssertEqual(ChapterGoalPresentationCatalog.descriptors.count, 4)
        XCTAssertEqual(
            ChapterGoalPresentationCatalog.descriptors.map(\.frame),
            ChapterGoal.Frame.allCases
        )
        XCTAssertTrue(
            ChapterGoalPresentationCatalog.descriptors.allSatisfy {
                $0.titleToken.arguments.isEmpty && $0.detailToken.arguments.isEmpty
            }
        )
        XCTAssertEqual(
            Set(ChapterGoalPresentationCatalog.descriptors.flatMap { [$0.titleToken.key, $0.detailToken.key] }).count,
            8
        )
    }

    func testTournamentAndGoalPresentationLookupsDoNotChangeDeterministicOutputs() throws {
        let careerIDs = ["presentation-a", "presentation-b", "20260813", "legacy-career"]
        for careerID in careerIDs {
            for chapter in [2, 4, 6, 8] {
                let before = TournamentBracket.field(
                    careerID: careerID,
                    chapterNumber: chapter,
                    playerSchool: "서울덕성고"
                )

                _ = TournamentPresentationCatalog.tournamentNameDescriptor(for: chapter)
                _ = TournamentPresentationCatalog.roundDescriptor(for: before.playerRound)
                for rawSchool in before.schools {
                    _ = TournamentPresentationCatalog.opponentSchoolDescriptor(for: rawSchool)
                }

                let after = TournamentBracket.field(
                    careerID: careerID,
                    chapterNumber: chapter,
                    playerSchool: "서울덕성고"
                )
                XCTAssertEqual(after, before, "bracket parity (careerID):(chapter)")
            }
        }

        let started = try HighSchoolCareerEngine().start(
            .init(seed: "202608130813", presetID: "power_prospect")
        )
        let beforeData = try JSONEncoder().encode(started.snapshot)
        let beforeCommitment = started.snapshot.stateCommitment
        let beforeHash = started.eventHash

        for careerID in careerIDs {
            for chapter in 1...8 {
                let goal = ChapterGoal.goal(careerID: careerID, chapterNumber: chapter)
                let descriptor = ChapterGoalPresentationCatalog.descriptor(for: goal)
                _ = CopyToken.chapterGoalDetail(
                    descriptor.frame,
                    targetStrikeouts: goal.targetStrikeouts
                )
            }
        }

        let afterData = try JSONEncoder().encode(started.snapshot)
        XCTAssertEqual(beforeData, afterData)
        XCTAssertEqual(beforeCommitment, started.snapshot.stateCommitment)
        XCTAssertEqual(beforeHash, started.eventHash)
    }
}
