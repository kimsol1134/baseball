import XCTest
@testable import SimulationCore

final class ScopedPresentationParityTests: XCTestCase {
    func testScopedPresentationInventoriesAreCompleteAndCollisionFree() {
        XCTAssertEqual(CommunityBuzzReactionTemplateID.allCases.count, 27)
        XCTAssertEqual(Set(CommunityBuzzReactionTemplateID.allCases.map(\.rawValue)).count, 27)
        XCTAssertEqual(CommunityBuzzRivalNewsTemplateID.allCases.count, 5)
        XCTAssertEqual(Set(CommunityBuzzRivalNewsTemplateID.allCases.map(\.rawValue)).count, 5)
        XCTAssertEqual(ProspectRankingPresentationCatalog.surnameDescriptors.count, 20)
        XCTAssertEqual(ProspectRankingPresentationCatalog.givenNameDescriptors.count, 20)
        XCTAssertEqual(ProspectRankingPresentationCatalog.schoolDescriptors.count, 10)
        XCTAssertEqual(ProspectRankingPresentationCatalog.scoutTagDescriptors.count, 10)
        XCTAssertEqual(DraftForecastPresentationCatalog.bandDescriptors.count, 5)
        XCTAssertEqual(DraftTeamPresentationCatalog.descriptors.count, 10)
        XCTAssertEqual(NicknamePresentationCatalog.descriptors.count, NicknameRules.catalogCount)

        let keys = CommunityBuzzPresentationCatalog.reactionDescriptors.map(\.token.key)
            + CommunityBuzzPresentationCatalog.rivalNewsDescriptors.map(\.token.key)
            + ProspectRankingPresentationCatalog.surnameDescriptors.map(\.token.key)
            + ProspectRankingPresentationCatalog.givenNameDescriptors.map(\.token.key)
            + ProspectRankingPresentationCatalog.schoolDescriptors.map(\.token.key)
            + ProspectRankingPresentationCatalog.scoutTagDescriptors.map(\.token.key)
            + DraftForecastPresentationCatalog.bandDescriptors.map(\.token.key)
            + DraftTeamPresentationCatalog.descriptors.map(\.token.key)
            + NicknamePresentationCatalog.descriptors.map(\.titleToken.key)
        XCTAssertEqual(Set(keys).count, keys.count, "Scoped semantic keys must be unique")
        XCTAssertEqual(
            Set(CommunityBuzzPresentationCatalog.semanticKeys).count,
            CommunityBuzzPresentationCatalog.semanticKeys.count
        )
    }

    func testReactionTypedSelectionMatchesLegacyKoreanAcrossDeterministicInputs() {
        let inputs: [(String, Int, Int, Int, Int, Nickname?)] = [
            ("golden-a", 1, 7, 1, 0, nil),
            ("golden-b", 2, 2, 4, 2, nil),
            ("golden-c", 3, 2, 0, 1, Nickname(id: "zero", title: "제로", reason: "")),
            ("golden-d", 4, 5, 1, 0, nil),
            ("golden-e", 5, 2, 1, 4, nil),
        ]

        for (careerID, game, strikeouts, walks, runs, nickname) in inputs {
            let legacy = CommunityBuzz.reactions(
                careerID: careerID,
                gameNumber: game,
                strikeouts: strikeouts,
                walks: walks,
                runsAllowed: runs,
                newNickname: nickname?.title
            )
            let typed = CommunityBuzz.reactionLines(
                careerID: careerID,
                gameNumber: game,
                strikeouts: strikeouts,
                walks: walks,
                runsAllowed: runs,
                newNickname: nickname
            )
            XCTAssertEqual(legacy.count, 3)
            XCTAssertEqual(typed.count, 3)
            XCTAssertEqual(
                typed.map { $0.koreanText(nicknameTitle: nickname?.title) },
                legacy,
                "Typed reaction drift for \(careerID)/\(game)"
            )
            XCTAssertEqual(typed, CommunityBuzz.reactionLines(
                careerID: careerID,
                gameNumber: game,
                strikeouts: strikeouts,
                walks: walks,
                runsAllowed: runs,
                newNickname: nickname
            ))
        }

        for careerIndex in 0..<24 {
            let careerID = "parity-\(careerIndex)"
            for game in 1...12 {
                let strikeouts = (careerIndex * 3 + game) % 9
                let walks = (careerIndex + game) % 6
                let runs = (careerIndex * 2 + game) % 7
                let nickname = game.isMultiple(of: 4)
                    ? Nickname(id: "zero", title: "제로", reason: "")
                    : nil
                let legacy = CommunityBuzz.reactions(
                    careerID: careerID,
                    gameNumber: game,
                    strikeouts: strikeouts,
                    walks: walks,
                    runsAllowed: runs,
                    newNickname: nickname?.title
                )
                let typed = CommunityBuzz.reactionLines(
                    careerID: careerID,
                    gameNumber: game,
                    strikeouts: strikeouts,
                    walks: walks,
                    runsAllowed: runs,
                    newNickname: nickname
                )
                XCTAssertEqual(legacy.count, 3)
                XCTAssertEqual(Set(legacy).count, 3)
                XCTAssertEqual(typed.map { $0.koreanText(nicknameTitle: nickname?.title) }, legacy)
            }
        }
    }

    func testReactionAndNewsGoldenKoreanTextRemainByteForByte() {
        let reactionGoldens: [(String, Int, Int, Int, Int, String?, [String])] = [
            (
                "golden-a", 1, 7, 1, 0, nil,
                [
                    "스카우트들 오늘 수첩에 뭐라고 적었을지 궁금하다",
                    "저 선수 몇 학년임? 체격 좋아 보이던데",
                    "프로 갈 생각 있는 선수임? 벌써 궁금하네",
                ]
            ),
            (
                "golden-b", 2, 2, 4, 2, nil,
                [
                    "오늘 볼넷이 너무 많았음. 본인이 제일 답답했을 듯",
                    "저 선수 몇 학년임? 체격 좋아 보이던데",
                    "저 학교 갑자기 왜 이렇게 강해짐?",
                ]
            ),
            (
                "golden-c", 3, 2, 0, 1, "제로",
                [
                    "별명이 '제로'... 고교야구에서 별명 생기면 진짜라는 뜻임",
                    "훈련을 어떻게 하길래 저렇게 던짐?",
                    "작년에도 이 정도였음? 갑자기 좋아진 것 같은데",
                ]
            ),
            (
                "golden-d", 4, 5, 1, 0, nil,
                [
                    "무실점에 탈삼진 5개면 고교 레벨이 아닌 듯",
                    "저 학교 갑자기 왜 이렇게 강해짐?",
                    "경기 밖에서는 어떤 스타일인지 궁금함",
                ]
            ),
            (
                "golden-e", 5, 2, 1, 4, nil,
                [
                    "4실점... 다음 경기에서 어떻게 나오는지가 진짜 시험임",
                    "저 선수 몇 학년임? 체격 좋아 보이던데",
                    "프로 갈 생각 있는 선수임? 벌써 궁금하네",
                ]
            ),
        ]
        for (careerID, game, strikeouts, walks, runs, nickname, expected) in reactionGoldens {
            XCTAssertEqual(
                CommunityBuzz.reactions(
                    careerID: careerID,
                    gameNumber: game,
                    strikeouts: strikeouts,
                    walks: walks,
                    runsAllowed: runs,
                    newNickname: nickname
                ),
                expected
            )
        }

        let newsGoldens: [(String, Int, [String])] = [
            (
                "golden-a", 1,
                [
                    "조규현(청암고), 부진 끝에 선발에서 밀렸다. 재조정이 필요해 보인다.",
                    "황규현(청암고), 팔꿈치 통증으로 등판을 걸렀다. 관리 실패라는 말과 신중하다는 말이 갈린다.",
                ]
            ),
            (
                "golden-a", 2,
                [
                    "황규현(청암고)이 지역 대회 결승에서 완봉승. 스카우트석이 가득 찼다는 후문.",
                    "차지호(남해정보고)이 한 경기 탈삼진 10개 — 또래 최고 기록에 다가섰다.",
                ]
            ),
            (
                "golden-b", 3,
                [
                    "유은찬(북부상고)이 지역 대회 결승에서 완봉승. 스카우트석이 가득 찼다는 후문.",
                    "문은찬(남해정보고), 부진 끝에 선발에서 밀렸다. 재조정이 필요해 보인다.",
                ]
            ),
            (
                "golden-c", 4,
                [
                    "권서준(북부상고)의 구속이 봄보다 3km/h 올랐다. 겨울에 무엇을 했는지 다들 궁금해한다.",
                    "강석현(청암고)이 한 경기 탈삼진 11개 — 또래 최고 기록에 다가섰다.",
                ]
            ),
            (
                "golden-d", 5,
                [
                    "최석현(북부상고), 팔꿈치 통증으로 등판을 걸렀다. 관리 실패라는 말과 신중하다는 말이 갈린다.",
                    "배준서(북부상고)의 구속이 봄보다 2km/h 올랐다. 겨울에 무엇을 했는지 다들 궁금해한다.",
                ]
            ),
        ]
        for (careerID, chapter, expected) in newsGoldens {
            let legacy = CommunityBuzz.rivalNews(careerID: careerID, chapterNumber: chapter)
            let typed = CommunityBuzz.rivalNewsLines(careerID: careerID, chapterNumber: chapter)
            XCTAssertEqual(legacy, expected)
            XCTAssertEqual(typed.count, 2)
            XCTAssertEqual(typed.map { $0.koreanText() }, legacy)
            XCTAssertEqual(Set(typed.map(\.templateID)).count, 2)
            XCTAssertEqual(Set(typed.map(\.prospect.stableID)).count, 2)
        }
    }

    func testProspectBoardRawGoldenAndPresentationProjectionAreUnchanged() {
        let performance = CareerPerformanceSnapshot(
            importantGamesCompleted: 4,
            pitches: 120,
            strikeouts: 24,
            walks: 2,
            runsAllowed: 2,
            expectedDamage: 0,
            actualDamage: 0
        )
        let expected = [
            "1|고준서|한서고|존 네 귀퉁이를 마음대로 쓰는 완성형 제구|false",
            "2|신민재|대양고|무명 학교에서 혼자 팀을 끌어올린 화제의 투수|false",
            "3|김찬영|중앙체고|이닝을 먹는 체력 — 완투가 기본|false",
            "4|문영웅|북부상고|각이 다른 종변화구 — 헛스윙 유도 1위|false",
            "5|고재민|동성공고|위기에서만 구속이 오르는 승부사|false",
            "6|신현빈|한서고|이닝을 먹는 체력 — 완투가 기본|false",
            "7|고성민|중앙체고|3학년 여름에 만개한 늦깎이 에이스|false",
            "8|신지호|대양고|최고 구속으로 스카우트 보고서 첫 줄을 차지한 파이어볼러|false",
            "9|김솔|서울고|이 명단에서 유일하게 당신이 키우는 선수|true",
            "10|이건우|한서고|3학년 여름에 만개한 늦깎이 에이스|false",
            "11|한지호|대양고|무명 학교에서 혼자 팀을 끌어올린 화제의 투수|false",
            "12|신성민|청암고|최고 구속으로 스카우트 보고서 첫 줄을 차지한 파이어볼러|false",
            "13|도영웅|서령고|존 네 귀퉁이를 마음대로 쓰는 완성형 제구|false",
            "14|조하준|청암고|각이 다른 종변화구 — 헛스윙 유도 1위|false",
            "15|한우진|북부상고|이닝을 먹는 체력 — 완투가 기본|false",
            "16|차시우|청암고|부상 복귀 후 더 강해져 돌아온 재활의 표본|false",
            "17|최하준|삼도고|무명 학교에서 혼자 팀을 끌어올린 화제의 투수|false",
            "18|유건우|북부상고|위기에서만 구속이 오르는 승부사|false",
            "19|도재민|서령고|타자들이 타이밍을 못 잡는 디셉션|false",
            "20|배도현|남해정보고|타자들이 타이밍을 못 잡는 디셉션|false",
        ]
        let board = ProspectRanking.board(
            careerID: "c",
            playerName: "김솔",
            playerSchool: "서울고",
            performance: performance
        )
        XCTAssertEqual(board.map { "\($0.rank)|\($0.name)|\($0.school)|\($0.tag)|\($0.isPlayer)" }, expected)

        let projected = ProspectRanking.presentationBoard(
            careerID: "c",
            playerName: "김솔",
            playerSchool: "서울고",
            playerSchoolID: nil,
            playerRegion: nil,
            performance: performance
        )
        XCTAssertEqual(projected.map { "\($0.rank)|\($0.name)|\($0.school)|\($0.tag)|\($0.isPlayer)" }, expected)
        XCTAssertEqual(projected.map(\.rank), Array(1...20))
        XCTAssertEqual(projected.filter(\.isPlayer).count, 1)
        XCTAssertTrue(projected.allSatisfy { $0.presentationIdentity != nil })
    }

    func testForecastAndPresentationLookupsDoNotChangeSnapshotJSONCommitmentOrEventHash() throws {
        let started = try HighSchoolCareerEngine().start(
            .init(seed: "20260730", presetID: "power_prospect")
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let beforeJSON = try encoder.encode(started.snapshot)
        let beforeCommitment = started.snapshot.stateCommitment
        let beforeEventHash = started.eventHash
        let beforeNextSeed = started.nextSeed

        let forecast = HighSchoolCareerEngine.draftForecast(state: started.snapshot)
        XCTAssertEqual(forecast.score, 52)
        XCTAssertEqual(forecast.threshold, 66)
        XCTAssertEqual(forecast.band, "미지명권 — 아직 명단 밖")
        XCTAssertEqual(forecast.interestedTeam, "대구 포지")
        XCTAssertEqual(forecast.presentation?.bandID, .outside)
        XCTAssertEqual(forecast.presentation?.interestedTeamID, "daegu_forge")

        _ = ProspectRanking.presentationBoard(
            careerID: started.snapshot.careerID,
            playerName: started.snapshot.identity.name,
            playerSchool: started.snapshot.school?.name ?? "학교 미정",
            playerSchoolID: started.snapshot.school?.id,
            playerRegion: SchoolRegionID.strictLookup(rawRegion: started.snapshot.identity.region),
            performance: started.snapshot.performance
        )
        _ = CommunityBuzz.reactionLines(
            careerID: started.snapshot.careerID,
            gameNumber: 1,
            strikeouts: 7,
            walks: 1,
            runsAllowed: 0
        )
        _ = CommunityBuzz.rivalNewsLines(careerID: started.snapshot.careerID, chapterNumber: 1)

        let afterJSON = try encoder.encode(started.snapshot)
        XCTAssertEqual(afterJSON, beforeJSON)
        XCTAssertEqual(started.snapshot.stateCommitment, beforeCommitment)
        XCTAssertEqual(started.eventHash, beforeEventHash)
        XCTAssertEqual(started.nextSeed, beforeNextSeed)
    }

    func testScopedPresentationProjectionIsDeterministicAcrossCareerAndPerformanceFixtures() {
        let performances = [
            CareerPerformanceSnapshot(),
            CareerPerformanceSnapshot(importantGamesCompleted: 1, pitches: 30, strikeouts: 2, walks: 1, runsAllowed: 3, expectedDamage: 0, actualDamage: 0),
            CareerPerformanceSnapshot(importantGamesCompleted: 3, pitches: 90, strikeouts: 15, walks: 3, runsAllowed: 4, expectedDamage: 0, actualDamage: 0),
            CareerPerformanceSnapshot(importantGamesCompleted: 5, pitches: 150, strikeouts: 30, walks: 2, runsAllowed: 0, expectedDamage: 0, actualDamage: 0),
        ]
        for careerID in ["fixture-a", "fixture-b", "fixture-c", "fixture-d"] {
            for performance in performances {
                let first = ProspectRanking.board(
                    careerID: careerID,
                    playerName: "김솔",
                    playerSchool: "서울고",
                    performance: performance
                )
                let second = ProspectRanking.presentationBoard(
                    careerID: careerID,
                    playerName: "김솔",
                    playerSchool: "서울고",
                    playerSchoolID: nil,
                    playerRegion: nil,
                    performance: performance
                )
                XCTAssertEqual(first, second)
                XCTAssertEqual(first.map(\.rank), Array(1...20))
                XCTAssertEqual(Set(first.map(\.name)).count, 20)
            }
        }
    }
}
