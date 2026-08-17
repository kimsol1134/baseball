import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOS

@MainActor
final class SignatureLegacyIntegrationTests: XCTestCase {
    func testPreFeatureInheritanceJSONDecodesWithoutSignatureLegacy() throws {
        let data = Data(
            #"{"lifeNumber":2,"memories":[],"soulPoints":18,"karmas":[]}"#.utf8
        )
        let decoded = try JSONDecoder().decode(HighSchoolCareerStore.Inheritance.self, from: data)
        XCTAssertNil(decoded.equippedSignatureLegacyID)
        XCTAssertNil(decoded.unlockedSignatureLegacies)
        XCTAssertNil(decoded.inheritanceRulesVersion)
        XCTAssertNil(decoded.automaticSoulEarned)
        XCTAssertEqual(decoded.lifeNumber, 2)
        XCTAssertEqual(decoded.soulPoints, 18)
        XCTAssertEqual(decoded.automaticSoulTotal, 18, "옛 단일 총량 저장은 기존 자동 적용 의미를 보존합니다.")
        XCTAssertFalse(HighSchoolCareerStore.usesSignatureLegacyRules(storedRulesVersion: nil))
        XCTAssertTrue(HighSchoolCareerStore.usesSignatureLegacyRules(
            storedRulesVersion: CareerSignatureLegacyRulesVersion.current.rawValue
        ))
    }

    func testPreFeatureLifeRecordDecodesWithoutFrozenSignatureLegacy() throws {
        let data = Data(
            #"{"lifeNumber":1,"playerName":"민서준","schoolName":"한빛고","drafted":false,"evaluationScore":58,"teamName":null,"memories":[],"games":5,"strikeouts":12,"walks":3,"runsAllowed":4,"soulPoints":20}"#.utf8
        )
        let decoded = try JSONDecoder().decode(HighSchoolCareerStore.LifeRecord.self, from: data)
        XCTAssertNil(decoded.signatureLegacy)
        XCTAssertNil(decoded.signatureLegacyCandidates)
        XCTAssertEqual(decoded.playerName, "민서준")
    }

    func testCompletingLifeEquipsOneLegacyAndPermanentlyDiscoversAllCandidates() throws {
        let state = try HighSchoolCareerEngine().start(
            .init(seed: "20260809", presetID: "power_prospect")
        ).snapshot
        let candidates = Array(CareerSignatureLegacyID.allCases.prefix(3)).map {
            CareerSignatureLegacy.definition(for: $0)
        }
        XCTAssertEqual(candidates.count, 3)

        let next = HighSchoolCareerStore.nextInheritance(
            from: state,
            memories: [],
            previous: .firstLife,
            signatureLegacy: candidates[1],
            discoveredSignatureLegacies: candidates
        )

        XCTAssertEqual(next.equippedSignatureLegacyID, candidates[1].id)
        XCTAssertEqual(Set((next.unlockedSignatureLegacies ?? []).map(\.id)), Set(candidates.map(\.id)))
        XCTAssertEqual(next.inheritanceRulesVersion, SoulInheritanceRulesVersion.current.rawValue)
        XCTAssertEqual(next.lifeNumber, 2)
        XCTAssertEqual(next.automaticSoulTotal, next.soulTotal)
    }

    func testSignatureLegacyEffectCopyListsOnlyActualBonuses() throws {
        let legacy = try XCTUnwrap(CareerSignatureLegacyID.allCases.first)
        let definition = CareerSignatureLegacy.definition(for: legacy)
        let line = HighSchoolSetupView.signatureLegacyEffectLine(definition.effect)
        XCTAssertFalse(line.contains("+0"))
        XCTAssertFalse(line.isEmpty)
        XCTAssertEqual(definition.effect.totalRatingBonus, 4)
    }

    func testUnlockedDiscoveryKeepsEvidenceButDisplaysTheCurrentStableEffect() throws {
        let id = CareerSignatureLegacyID.commandMap
        let current = CareerSignatureLegacy.definition(for: id)
        let oldEvidence = CareerSignatureLegacyEvidence(summary: "옛 회차에서 직접 증명한 기록")
        let oldPayload = CareerSignatureLegacy(
            id: id,
            family: current.family,
            title: "옛 문구",
            detail: "옛 설명",
            effect: .init(stuff: 9),
            evidence: oldEvidence
        )
        var inheritance = HighSchoolCareerStore.Inheritance.firstLife
        inheritance.equippedSignatureLegacyID = id
        inheritance.unlockedSignatureLegacies = [oldPayload]

        let playable = try XCTUnwrap(inheritance.equippedSignatureLegacy)
        XCTAssertEqual(playable.title, current.title)
        XCTAssertEqual(playable.effect, current.effect)
        XCTAssertEqual(playable.evidence, oldEvidence)
    }

    func testLifeRecordFreezesAllThreeDiscoveredCandidates() throws {
        let state = try HighSchoolCareerEngine().start(
            .init(seed: "20260810", presetID: "power_prospect")
        ).snapshot
        let candidates = Array(CareerSignatureLegacyID.allCases.prefix(3)).map {
            CareerSignatureLegacy.definition(for: $0)
        }
        let record = HighSchoolCareerStore.lifeRecord(
            from: state,
            memories: [],
            previous: .firstLife,
            signatureLegacy: candidates[0],
            signatureLegacyCandidates: candidates
        )
        let decoded = try JSONDecoder().decode(
            HighSchoolCareerStore.LifeRecord.self,
            from: JSONEncoder().encode(record)
        )
        XCTAssertEqual(decoded.signatureLegacy?.id, candidates[0].id)
        XCTAssertEqual(decoded.signatureLegacyCandidates?.map(\.id), candidates.map(\.id))
    }

    func testRetiredProCareerAtomicallyOpensCombinedLegacyChoiceAndCreditsSoulOnce() throws {
        let sync = SaveSync(key: "pro-signature-\(UUID().uuidString).json")
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let career = try Self.completedDraftedCareer()
        let pro = Self.completedProCareer(highSchoolState: career.result.snapshot)
        let record = HighSchoolCareerStore.SaveRecord(
            result: career.result,
            inheritance: .firstLife,
            archive: [],
            // 실제 구버전 정규 진입에는 source와 entered 영수증이 모두 없었다.
            enteredProCareerID: nil,
            careerStartingPitcher: career.startingPitcher,
            signatureLegacyRulesVersion: CareerSignatureLegacyRulesVersion.current.rawValue,
            revision: career.result.snapshot.revision
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))

        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        let soulBefore = store.inheritance.soulPoints
        let automaticBefore = store.inheritance.automaticSoulTotal
        let lifetimeBefore = store.inheritance.soulTotal
        let expectedBonus = HighSchoolCareerStore.proSoulBonus(for: pro)
        var recordedEvents: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in recordedEvents.append(event) }

        // 명시된 원본 고교가 다르면 현재 선수와 결합하거나 프로 원본을 지울 수 없다.
        XCTAssertFalse(store.recordProLegacy(
            pro,
            sourceHighSchoolCareerID: "different-high-school-career"
        ))
        XCTAssertEqual(store.state?.phase, .completed)
        XCTAssertNil(store.inheritance.creditedProCareerID)

        // source 필드 도입 전 프로 저장은 고교 진입 영수증과 신원이 맞아 안전하게 이어진다.
        XCTAssertTrue(store.recordProLegacy(pro, allowsLegacySourceMigration: true))
        XCTAssertEqual(store.state?.phase, .legacy)
        XCTAssertEqual(store.enteredProCareerID, career.result.snapshot.careerID)
        XCTAssertEqual(store.inheritance.creditedProCareerID, pro.proCareerID)
        XCTAssertEqual(store.inheritance.soulPoints, soulBefore + expectedBonus)
        XCTAssertEqual(store.inheritance.automaticSoulTotal, automaticBefore)
        XCTAssertEqual(store.inheritance.soulTotal, lifetimeBefore + expectedBonus)
        let candidates = try XCTUnwrap(store.state.map { store.signatureLegacyCandidates(for: $0) })
        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(Set(candidates.map(\.id)).count, 3)
        XCTAssertTrue(candidates.allSatisfy { $0.evidence.proPerformance != nil })
        XCTAssertEqual(recordedEvents.filter { $0 == .proLegacyRecorded }.count, 1)

        // 저장을 다시 읽고 같은 은퇴 콜백이 재전달돼도 보상과 후보는 움직이지 않는다.
        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertEqual(reloaded.enteredProCareerID, career.result.snapshot.careerID)
        let soulAfterFirstRecord = reloaded.inheritance.soulPoints
        let automaticAfterFirstRecord = reloaded.inheritance.automaticSoulTotal
        let idsAfterFirstRecord = try XCTUnwrap(
            reloaded.state.map { reloaded.signatureLegacyCandidates(for: $0) }
        ).map(\.id)
        let retainedSelection = try XCTUnwrap(idsAfterFirstRecord.first)
        reloaded.selectSignatureLegacy(retainedSelection)
        XCTAssertTrue(reloaded.recordProLegacy(pro, allowsLegacySourceMigration: true))
        XCTAssertEqual(reloaded.inheritance.soulPoints, soulAfterFirstRecord)
        XCTAssertEqual(reloaded.inheritance.automaticSoulTotal, automaticAfterFirstRecord)
        XCTAssertEqual(reloaded.selectedSignatureLegacyID, retainedSelection)
        XCTAssertEqual(
            try XCTUnwrap(
                reloaded.state.map { reloaded.signatureLegacyCandidates(for: $0) }
            ).map(\.id),
            idsAfterFirstRecord
        )
        XCTAssertEqual(recordedEvents.filter { $0 == .proLegacyRecorded }.count, 1)

        // 프로 tombstone 쓰기가 실패한 사이 고교 탭에서 유산 정산을 끝낼 수 있다. 다음
        // 삭제 재시도는 닫힌 선수를 다시 유산 선택 단계로 열거나 보상을 재지급하면 안 된다.
        reloaded.confirmLegacy()
        XCTAssertEqual(reloaded.state?.phase, .completed)
        let completedRevision = reloaded.state?.revision
        let completedInheritance = reloaded.inheritance
        let completedArchive = reloaded.archive
        XCTAssertTrue(reloaded.recordProLegacy(pro, allowsLegacySourceMigration: true))
        XCTAssertEqual(reloaded.state?.phase, .completed)
        XCTAssertEqual(reloaded.state?.revision, completedRevision)
        XCTAssertEqual(reloaded.inheritance, completedInheritance)
        XCTAssertEqual(reloaded.archive, completedArchive)
        XCTAssertEqual(recordedEvents.filter { $0 == .proLegacyRecorded }.count, 1)

        // 다음 고교 선수가 실제로 시작되면 지난 프로 영수증은 역할을 다했고, 새 프로
        // 커리어를 막지 않도록 비운다. 시작 저장 실패 시에는 Store가 이전 값을 되돌린다.
        reloaded.beginNextLife()
        reloaded.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "다음 선수"
        )
        XCTAssertNil(reloaded.inheritance.creditedProCareerID)
    }

    func testFailedProLegacySaveKeepsCompletedCareerAndDoesNotCreditSoul() throws {
        let directoryName = "pro-signature-failure-\(UUID().uuidString)"
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            GameAnalytics.eventSinkForTesting = nil
        }

        let sync = SaveSync(key: "\(directoryName)/career.json")
        let career = try Self.completedDraftedCareer()
        let pro = Self.completedProCareer(highSchoolState: career.result.snapshot)
        let record = HighSchoolCareerStore.SaveRecord(
            result: career.result,
            inheritance: .firstLife,
            archive: [],
            enteredProCareerID: career.result.snapshot.careerID,
            careerStartingPitcher: career.startingPitcher,
            signatureLegacyRulesVersion: CareerSignatureLegacyRulesVersion.current.rawValue,
            revision: career.result.snapshot.revision
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        let inheritanceBefore = store.inheritance
        let revisionBefore = store.state?.revision
        var recordedEvents: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in recordedEvents.append(event) }
        try FileManager.default.removeItem(at: directory)

        XCTAssertFalse(store.recordProLegacy(
            pro,
            sourceHighSchoolCareerID: career.result.snapshot.careerID
        ))
        XCTAssertEqual(store.state?.phase, .completed)
        XCTAssertEqual(store.state?.revision, revisionBefore)
        XCTAssertEqual(store.inheritance, inheritanceBefore)
        XCTAssertNil(store.inheritance.creditedProCareerID)
        XCTAssertFalse(recordedEvents.contains(.proLegacyRecorded))
        if case .failed = store.loadState {} else {
            XCTFail("저장 실패 뒤 프로 원본을 지울 수 있는 성공 상태가 되면 안 됩니다.")
        }
    }

    func testStandaloneProCareerLeavesOnlySoulAndPreservesHighSchoolState() throws {
        let sync = SaveSync(key: "standalone-pro-\(UUID().uuidString).json")
        defer {
            sync.clear()
            GameAnalytics.eventSinkForTesting = nil
        }
        let highSchoolStore = HighSchoolCareerStore(sync: sync)
        highSchoolStore.restoreOrCreate()
        let highSchoolState = try HighSchoolCareerEngine().start(
            .init(seed: "424242", presetID: "power_prospect")
        ).snapshot
        let pro = Self.completedProCareer(highSchoolState: highSchoolState)
        let expectedBonus = HighSchoolCareerStore.proSoulBonus(for: pro)
        var events: [GameAnalytics.Event] = []
        GameAnalytics.eventSinkForTesting = { event, _ in events.append(event) }

        XCTAssertTrue(highSchoolStore.recordStandaloneProLegacy(pro))
        XCTAssertNil(highSchoolStore.result)
        XCTAssertEqual(highSchoolStore.inheritance.soulPoints, expectedBonus)
        XCTAssertEqual(highSchoolStore.inheritance.soulTotal, expectedBonus)
        XCTAssertEqual(
            highSchoolStore.inheritance.automaticSoulTotal, 0,
            "프로 보너스는 지갑에만 들어가 다음 선수를 몰래 강화하면 안 됩니다."
        )
        XCTAssertNil(highSchoolStore.inheritance.creditedProCareerID)
        XCTAssertEqual(events.filter { $0 == .proLegacyRecorded }.count, 1)

        XCTAssertTrue(highSchoolStore.recordStandaloneProLegacy(pro))
        XCTAssertEqual(highSchoolStore.inheritance.soulPoints, expectedBonus)
        XCTAssertEqual(highSchoolStore.inheritance.automaticSoulTotal, 0)
        XCTAssertEqual(events.filter { $0 == .proLegacyRecorded }.count, 1)

        let reloaded = HighSchoolCareerStore(sync: sync)
        reloaded.restoreOrCreate()
        XCTAssertEqual(reloaded.inheritance.soulPoints, expectedBonus)
        XCTAssertEqual(reloaded.inheritance.automaticSoulTotal, 0)
        XCTAssertNil(reloaded.result)
    }

    func testExplicitDirectProWithSameIdentityDoesNotAttachToCompletedHighSchoolCareer() throws {
        let sync = SaveSync(key: "direct-same-identity-\(UUID().uuidString).json")
        defer { sync.clear() }
        let career = try Self.completedDraftedCareer()
        let pro = Self.completedProCareer(highSchoolState: career.result.snapshot)
        let record = HighSchoolCareerStore.SaveRecord(
            result: career.result,
            inheritance: .firstLife,
            archive: [],
            enteredProCareerID: nil,
            careerStartingPitcher: career.startingPitcher,
            signatureLegacyRulesVersion: CareerSignatureLegacyRulesVersion.current.rawValue,
            revision: career.result.snapshot.revision
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))
        let store = HighSchoolCareerStore(sync: sync)
        store.restoreOrCreate()
        let highSchoolRevision = store.state?.revision

        // 새 direct 저장은 origin=.direct이므로 AppShell이 legacy migration 추론을 켜지 않는다.
        XCTAssertFalse(store.canAttachProLegacy(
            pro,
            sourceHighSchoolCareerID: nil,
            allowsLegacySourceMigration: false
        ))
        XCTAssertTrue(store.recordStandaloneProLegacy(pro))
        XCTAssertEqual(store.state?.phase, .completed)
        XCTAssertEqual(store.state?.revision, highSchoolRevision)
        XCTAssertNil(store.enteredProCareerID)
        XCTAssertNil(store.inheritance.creditedProCareerID)
        XCTAssertNil(store.selectedSignatureLegacyID)

        let mismatchedTeam = try XCTUnwrap(
            HighSchoolCareerEngine.teams.first { $0.id != career.result.snapshot.draftResult?.team?.id }
        )
        let legacyDirect = Self.completedProCareer(
            highSchoolState: career.result.snapshot,
            teamOverride: mismatchedTeam
        )
        XCTAssertFalse(store.canAttachProLegacy(
            legacyDirect,
            sourceHighSchoolCareerID: nil,
            allowsLegacySourceMigration: true
        ))
    }

    func testProSaveRecordPersistsItsSourceHighSchoolCareerID() throws {
        let sync = SaveSync(key: "pro-source-\(UUID().uuidString).json")
        defer { sync.clear() }
        let highSchoolState = try HighSchoolCareerEngine().start(
            .init(seed: "515151", presetID: "power_prospect")
        ).snapshot
        let pro = Self.completedProCareer(highSchoolState: highSchoolState)
        let sourceID = "source-high-school-career"
        let record = MobileCareerStore.ProSaveRecord(
            result: ProCareerResult(snapshot: pro, nextSeed: "12345", events: []),
            sourceHighSchoolCareerID: sourceID,
            origin: .highSchool
        )
        XCTAssertTrue(sync.write(try JSONEncoder().encode(record)))

        let store = MobileCareerStore(sync: sync)
        store.restoreOrCreateCareer()
        XCTAssertEqual(store.sourceHighSchoolCareerID, sourceID)
        XCTAssertEqual(store.careerOrigin, .highSchool)
        XCTAssertEqual(store.state?.proCareerID, pro.proCareerID)
    }

    func testProStartAndDeletionRequireDurableTombstoneBeforeCrossStoreTransition() throws {
        let directoryName = "pro-cross-store-\(UUID().uuidString)"
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sync = SaveSync(key: "\(directoryName)/career.json")
        let highSchool = try Self.completedDraftedCareer()
        let draft = try XCTUnwrap(highSchool.result.snapshot.draftResult)

        // 로컬 원본 경로를 쓸 수 없으면 in-memory ready 상태를 성공으로 돌려주지 않는다.
        try FileManager.default.removeItem(at: directory)
        let failedStart = MobileCareerStore(sync: sync)
        XCTAssertFalse(failedStart.startProCareer(
            draft: draft,
            pitcher: highSchool.result.snapshot.pitcher,
            identity: highSchool.result.snapshot.identity,
            sourceHighSchoolCareerID: highSchool.result.snapshot.careerID
        ))
        XCTAssertNil(failedStart.result)
        XCTAssertNil(failedStart.sourceHighSchoolCareerID)
        XCTAssertNil(failedStart.careerOrigin)
        if case .failed = failedStart.loadState {} else {
            XCTFail("저장 실패한 프로 진입이 ready로 보이면 안 됩니다.")
        }
        XCTAssertFalse(failedStart.deleteCareer())
        if case .failed = failedStart.loadState {} else {
            XCTFail("스냅숏 없는 삭제 실패가 ready로 바뀌면 고교와 프로 화면이 모두 막힙니다.")
        }

        // 정상 저장 뒤 tombstone 쓰기에 실패하면 프로 원본과 source를 그대로 남긴다.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = MobileCareerStore(sync: sync)
        XCTAssertTrue(store.startProCareer(
            draft: draft,
            pitcher: highSchool.result.snapshot.pitcher,
            identity: highSchool.result.snapshot.identity,
            sourceHighSchoolCareerID: highSchool.result.snapshot.careerID
        ))
        let proCareerID = try XCTUnwrap(store.state?.proCareerID)
        try FileManager.default.removeItem(at: directory)
        XCTAssertFalse(store.deleteCareer())
        XCTAssertEqual(store.state?.proCareerID, proCareerID)
        XCTAssertEqual(store.sourceHighSchoolCareerID, highSchool.result.snapshot.careerID)
        XCTAssertEqual(store.careerOrigin, .highSchool)
        XCTAssertEqual(store.loadState, .ready)
        XCTAssertTrue(store.lastSummary?.contains("다시 눌러") == true)

        // 재시도에 성공한 뒤에는 최신 묘비가 옛 프로 저장의 부활을 막는다.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        XCTAssertTrue(store.deleteCareer())
        XCTAssertNil(store.result)
        let reloaded = MobileCareerStore(sync: sync)
        reloaded.restoreOrCreateCareer()
        XCTAssertNil(reloaded.result)
        XCTAssertEqual(reloaded.loadState, .needsSetup)
    }

    private static func completedDraftedCareer() throws -> (
        startingPitcher: PitcherSnapshot,
        result: HighSchoolCareerResult
    ) {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(seed: "20260723", presetID: "power_prospect"))
        let startingPitcher = result.snapshot.pitcher
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            schoolID: .haedongPower
        ))
        for _ in 0..<100 {
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: .velocity,
                    intensity: .intensive
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    response: .listen
                ))
            case .importantGame:
                let number = result.snapshot.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: number,
                        pitches: 18,
                        strikeouts: 4,
                        walks: 0,
                        runsAllowed: 0,
                        expectedDamage: 380,
                        actualDamage: 120,
                        recommendationAccepted: 10,
                        outs: 3
                    )
                ))
            case .awakening:
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            case .draft:
                result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
            case .completed:
                XCTAssertEqual(result.snapshot.draftResult?.outcome, .drafted)
                return (startingPitcher, result)
            case .legacy:
                XCTFail("강한 실제 플레이 fixture가 지명에 실패했습니다.")
                return (startingPitcher, result)
            case .prologue, .schoolSelection:
                XCTFail("학교 선택 뒤 이전 국면으로 돌아가면 안 됩니다.")
                return (startingPitcher, result)
            }
        }
        XCTFail("100번 안에 드래프트를 마치지 못했습니다.")
        return (startingPitcher, result)
    }

    // '다음 선수 준비' 실패는 조용히 삼켜지지 않고 유형별 알림으로 나뉜다.
    // 저장 실패는 스토어가 남긴 원인 메시지를 그대로 보여 주고, 그 외에는 연결이 깨진
    // 저장으로 분류해 계승 포인트만 남기는 출구를 제안한다(1.0.4 진행 불가 리뷰 대응).
    func testLegacyHandoffIssueClassifiesSaveFailureAndLinkageBreakage() {
        let saveFailure = AppShell.legacyHandoffIssue(
            highSchoolLoadState: .failed("저장 공간이 부족합니다.")
        )
        XCTAssertEqual(saveFailure, .saveFailed("저장 공간이 부족합니다."))
        XCTAssertEqual(saveFailure.analyticsReason, "save_failed")

        for state: HighSchoolCareerStore.LoadState in [.ready, .needsSetup, .loading] {
            let issue = AppShell.legacyHandoffIssue(highSchoolLoadState: state)
            XCTAssertEqual(issue, .linkageBroken)
            XCTAssertEqual(issue.analyticsReason, "linkage_broken")
        }
    }

    private static func completedProCareer(
        highSchoolState: HighSchoolCareerSnapshot,
        teamOverride: DraftTeamSnapshot? = nil
    ) -> ProCareerSnapshot {
        let team = teamOverride
            ?? highSchoolState.draftResult?.team
            ?? HighSchoolCareerEngine.teams[0]
        let stats = ProSeasonStats(
            season: 12,
            teamID: team.id,
            games: 31,
            starts: 28,
            inningsOuts: 480,
            strikeouts: 172,
            walks: 38,
            runsAllowed: 42,
            wins: 14,
            losses: 7,
            saves: 0
        )
        let pitcher = PitcherSnapshot(
            id: highSchoolState.pitcher.id,
            name: highSchoolState.pitcher.name,
            stuff: min(80, highSchoolState.pitcher.stuff + 8),
            command: min(80, highSchoolState.pitcher.command + 5),
            movement: min(80, highSchoolState.pitcher.movement + 6),
            stamina: min(80, highSchoolState.pitcher.stamina + 7),
            pitchProfiles: highSchoolState.pitcher.pitchProfiles,
            throwingHand: highSchoolState.pitcher.throwingHand
        )
        return ProCareerSnapshot(
            proCareerID: "pro-combined-legacy",
            revision: 100,
            phase: .completed,
            identity: highSchoolState.identity,
            pitcher: pitcher,
            team: team,
            entitlement: .init(
                status: .active,
                source: .development,
                verifiedAt: "2026-08-09T00:00:00Z"
            ),
            age: 37,
            season: 12,
            week: 24,
            level: .major,
            role: .starter,
            managerTrust: 82,
            catcherTrust: 86,
            fatigue: 0,
            injuryWeeks: 0,
            serviceYears: 12,
            militaryCompleted: true,
            contract: nil,
            currentStats: stats,
            careerStats: [stats],
            awards: ["시즌 12 탈삼진상"],
            milestones: ["프로 은퇴"],
            news: [],
            hallOfFameScore: 75,
            commitment: "test"
        )
    }
}
