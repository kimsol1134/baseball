import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOS

private final class JourneyWave1MemoryRemoteStore: SaveSyncRemoteStoring {
    private(set) var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    @discardableResult func synchronize() -> Bool { true }
}

@MainActor
final class ProCareerJourneyWave1Tests: XCTestCase {
    private var preset: PitcherPresetSnapshot { PitcherPresetCatalog.all[0] }

    func testProductionFeatureFlagKeepsLegacyStartAndRejectsJourneyWrites() throws {
        XCTAssertFalse(AppFeatureConfiguration.production.proCareerJourneyV1)
        XCTAssertTrue(AppFeatureConfiguration.journeyV1Tests.proCareerJourneyV1)

        let appSource = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/BaseballApp.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(appSource.contains("#if DEBUG"))
        XCTAssertTrue(appSource.contains("proCareerJourneyLaunchArgument"))
        XCTAssertTrue(appSource.contains("AppFeatureConfiguration.journeyV1Tests : .production"))
        XCTAssertTrue(appSource.contains("let proConfiguration = AppFeatureConfiguration.production"))

        var writes: [Data] = []
        let legacyCloud = JourneyWave1MemoryRemoteStore()
        let legacySync = SaveSync(key: "wave1-production-\(UUID().uuidString).json", store: legacyCloud)
        legacySync.clear()
        defer { legacySync.clear() }
        let store = MobileCareerStore(
            sync: legacySync,
            saveWriter: { writes.append($0); return true },
            configuration: .production
        )
        XCTAssertTrue(store.startNewCareer(preset: preset, playerName: "웨이브1레거시"))
        let legacyState = try XCTUnwrap(store.state)
        XCTAssertNil(legacyState.journeyState)
        XCTAssertEqual(writes.count, 1)
        let legacyRecord = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: writes[0]
        )
        XCTAssertEqual(legacyRecord.schemaVersion, MobileCareerStore.legacySaveSchemaVersion)

        let journeyResult = try journeyFixture()
        store.result = journeyResult
        XCTAssertFalse(store.save())
        XCTAssertEqual(writes.count, 1, "production must not write journey saves")

        var journeyWrites: [Data] = []
        let journeyCloud = JourneyWave1MemoryRemoteStore()
        let journeySync = SaveSync(key: "wave1-schema-\(UUID().uuidString).json", store: journeyCloud)
        defer { journeySync.clear() }
        let journeyStore = MobileCareerStore(
            sync: journeySync,
            saveWriter: { journeyWrites.append($0); return true },
            configuration: .journeyV1Tests
        )
        journeyStore.result = journeyResult
        journeyStore.loadState = .ready
        XCTAssertTrue(journeyStore.save())
        let journeyRecord = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: try XCTUnwrap(journeyWrites.first)
        )
        XCTAssertEqual(journeyRecord.schemaVersion, MobileCareerStore.journeySaveSchemaVersion)
        XCTAssertNotNil(journeyRecord.result?.snapshot.journeyState)
    }

    func testWave2EnabledStartShowsAndPersistsRookieContractOfferSchema3() throws {
        var writes: [Data] = []
        let store = MobileCareerStore(
            saveWriter: { writes.append($0); return true },
            configuration: .journeyV1Tests
        )

        XCTAssertTrue(store.startNewCareer(preset: preset, playerName: "웨이브2신인"))
        let state = try XCTUnwrap(store.state)
        XCTAssertEqual(state.phase, .contractOffer)
        XCTAssertNil(state.contract)
        XCTAssertEqual(state.journeyState?.pendingContractMarket?.offers.count, 1)
        XCTAssertEqual(writes.count, 1)
        let record = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: try XCTUnwrap(writes.first)
        )
        XCTAssertEqual(record.schemaVersion, MobileCareerStore.journeySaveSchemaVersion)
        XCTAssertEqual(record.result?.snapshot.phase, .contractOffer)
        XCTAssertNil(record.result?.snapshot.contract)
    }

    func testWave2StoreAcceptPersistsBeforePublishingAndFailureIsAtomic() throws {
        var writes: [Data] = []
        let store = MobileCareerStore(
            saveWriter: { writes.append($0); return true },
            configuration: .journeyV1Tests
        )
        XCTAssertTrue(store.startNewCareer(preset: preset, playerName: "웨이브2서명"))
        let offer = try XCTUnwrap(store.state?.journeyState?.pendingContractMarket?.offers.first)
        let beforeSummary = store.lastSummary
        XCTAssertTrue(store.acceptContract(ambition: .recordBook))
        XCTAssertEqual(store.state?.phase, .weeklyPlan)
        XCTAssertEqual(store.state?.journeyState?.finances.transactions.filter { $0.kind == .signingBonus }.count, 1)
        XCTAssertEqual(writes.count, 2)
        let acceptedRecord = try JSONDecoder().decode(
            MobileCareerStore.ProSaveRecord.self,
            from: try XCTUnwrap(writes.last)
        )
        XCTAssertEqual(acceptedRecord.result?.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(acceptedRecord.result?.snapshot.journeyState?.activeGoal?.ambition, .recordBook)
        XCTAssertNotEqual(store.lastSummary, beforeSummary)
        XCTAssertFalse(acceptedRecord.result?.snapshot.journeyState?.pendingContractMarket?.offers.contains(where: { $0.id == offer.id }) == true)

        let start = try ProCareerEngine(journeyEnabled: true).start(.init(
            seed: "220302",
            identity: .defaultPitcher,
            pitcher: .init(id: "wave2-failure", name: "Wave 2", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3라운드",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: nil,
                summary: "지명"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-15")
        ))
        let failing = MobileCareerStore(
            saveWriter: { _ in false },
            configuration: .journeyV1Tests
        )
        failing.result = start
        failing.loadState = .ready
        failing.lastSummary = "before"
        let failedRevision = start.snapshot.revision
        XCTAssertFalse(failing.acceptContract(ambition: .franchiseIcon))
        XCTAssertEqual(failing.state?.revision, failedRevision)
        XCTAssertEqual(failing.state?.phase, .contractOffer)
        XCTAssertEqual(failing.lastSummary, "before")
        XCTAssertEqual(failing.state?.journeyState?.finances.transactions.count, 0)
    }

    func testWave2HighSchoolFanInterestReachesJourneyStart() throws {
        let store = MobileCareerStore(
            saveWriter: { _ in true },
            configuration: .journeyV1Tests
        )
        let draft = DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: 72,
            projectedRange: "2~3라운드",
            team: ProCareerEngine.proTeams[0],
            round: 2,
            overallPick: 18,
            signingBonus: 120_000_000,
            firstSeasonGoal: nil,
            summary: "지명"
        )
        XCTAssertTrue(store.startProCareer(
            draft: draft,
            pitcher: .init(id: "wave2-fan", name: "Wave 2", stuff: 58, command: 55, movement: 56, stamina: 57),
            identity: .defaultPitcher,
            sourceHighSchoolCareerID: "high-school-wave2",
            sourceFanInterest: 50
        ))
        XCTAssertEqual(store.state?.journeyState?.reputation.fanSupport, 30)
    }

    func testWave2OfferUIHasStableAccessibilityAndRetainsCurrentGoalByDefault() throws {
        let flow = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/CareerFlowView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(flow.contains("struct ProContractOfferView: View"))
        XCTAssertTrue(flow.contains("case .contractOffer:"))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"pro.contractOffer\")"))
        XCTAssertTrue(flow.contains("identifier: \"pro.contractOffer.sign\""))
        XCTAssertTrue(flow.contains("identifier: \"pro.seasonReview.confirm\""))
        XCTAssertTrue(flow.contains(".accessibilityElement(children: .contain)\n        .accessibilityIdentifier(\"pro.seasonDecision\")"))
        XCTAssertTrue(flow.contains("pro.contractOffer.ambition.\\(ambition.rawValue)"))
        XCTAssertTrue(flow.contains("@State private var selectedAmbition: ProCareerAmbition?"))
        XCTAssertTrue(flow.contains(".task(id: market.id)"))
        XCTAssertTrue(flow.contains("selectedAmbition = activeGoal.ambition"))
        XCTAssertTrue(flow.contains("contractOfferGuaranteedSalary"))
        XCTAssertTrue(flow.contains("contractOfferSigningBonus"))
        XCTAssertTrue(flow.contains("contractOfferDurationTitle"))
        XCTAssertTrue(flow.contains("contractOfferDuration, arguments:"))
        XCTAssertTrue(flow.contains("contractOfferOutlook"))
        XCTAssertTrue(flow.contains("contractOfferOutlookLine"))
    }

    func testWave2ContractCopyHasKoreanEnglishJapaneseParity() throws {
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/Localization/Localizable.xcstrings"))
            ) as? [String: Any]
        )
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let keys = ProUICopyKey.allCases.filter {
            $0.rawValue.hasPrefix("pro.contract.offer.") || $0.rawValue.hasPrefix("pro.offseason.contract.")
        }
        XCTAssertGreaterThan(keys.count, 20)
        for key in keys {
            let entry = try XCTUnwrap(strings[key.rawValue] as? [String: Any], key.rawValue)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key.rawValue)
            let values = try ["ko", "en", "ja"].map { language -> String in
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], key.rawValue + ":" + language)
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], key.rawValue + ":" + language)
                XCTAssertEqual(unit["state"] as? String, "translated", key.rawValue + ":" + language)
                return try XCTUnwrap(unit["value"] as? String, key.rawValue + ":" + language)
            }
            XCTAssertEqual(GameCopyResolver.placeholderKinds(in: values[0]), GameCopyResolver.placeholderKinds(in: values[1]), key.rawValue)
            XCTAssertEqual(GameCopyResolver.placeholderKinds(in: values[0]), GameCopyResolver.placeholderKinds(in: values[2]), key.rawValue)
        }
    }

    func testWave4ViewsConsumeSharedProjectionsAndExposeStableAccessibilityIDs() throws {
        let sourceFiles = ["AppShell.swift", "CareerFlowView.swift", "RecordView.swift"].map {
            try! String(contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/\($0)"), encoding: .utf8)
        }.joined(separator: "\n")
        XCTAssertTrue(sourceFiles.contains("ProCareerGoalMetricsView"))
        XCTAssertTrue(sourceFiles.contains("ProCareerPresentation.teamRecords(for: state)"))
        XCTAssertTrue(sourceFiles.contains("ProCareerEngine.retirementPreview(for: state)"))
        XCTAssertTrue(sourceFiles.contains("RetirementHonorsCard"))
        XCTAssertTrue(sourceFiles.contains("pro.careerDirection.toggle"))
        XCTAssertTrue(sourceFiles.contains("pro.careerDirection.records"))
        XCTAssertTrue(sourceFiles.contains("pro.settlement.goal"))
        XCTAssertTrue(sourceFiles.contains("record.teamCareerRecords"))
        XCTAssertTrue(sourceFiles.contains("ProTeamCareerRecordsCard"))
        XCTAssertTrue(sourceFiles.contains("accessibilityPrefix: \"pro.retirement\""))
        XCTAssertTrue(sourceFiles.contains("recordsAccessibilityIdentifier"))
        XCTAssertTrue(sourceFiles.contains("recordAccessibilityIdentifier"))
        XCTAssertTrue(sourceFiles.contains("pro.retirement.preview"))
        XCTAssertTrue(sourceFiles.contains("pro.retirement.final.score"))
        XCTAssertTrue(sourceFiles.contains("pro.retirement.honors"))
        XCTAssertTrue(sourceFiles.contains("pro.retirement.honor.\\(honor.id)"))
        XCTAssertTrue(sourceFiles.contains("accessibilityReduceMotion"))
    }

    func testRetirementProjectionAndHonorsPreserveChildAccessibilityIDs() throws {
        let flow = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/CareerFlowView.swift"),
            encoding: .utf8
        )
        let previewStart = try XCTUnwrap(flow.range(of: "private struct RetirementPreviewCard: View"))
        let retiredStart = try XCTUnwrap(flow.range(of: "private struct RetiredView: View"))
        let honorsStart = try XCTUnwrap(flow.range(of: "private struct RetirementHonorsCard: View"))
        let totalsStart = try XCTUnwrap(flow.range(of: "private struct CareerTotals: View"))
        let preview = flow[previewStart.lowerBound..<retiredStart.lowerBound]
        let honors = flow[honorsStart.lowerBound..<totalsStart.lowerBound]

        XCTAssertTrue(preview.contains(".accessibilityElement(children: .contain)"))
        XCTAssertTrue(preview.contains("pro.retirement.preview.score"))
        XCTAssertTrue(preview.contains("pro.retirement.preview.retired-number"))
        XCTAssertTrue(honors.contains(".accessibilityElement(children: .contain)"))
        XCTAssertTrue(honors.contains("pro.retirement.honor.\\(honor.id)"))
    }

    func testWave4CopyHasKoreanEnglishJapaneseParityAndProjectionLanguage() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Localization/Localizable.xcstrings")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let prefixes = [
            "pro.journey.direction.",
            "pro.journey.goal.metric.",
            "pro.team-records.",
            "pro.retirement.preview.",
            "pro.retirement.honors.",
            "pro.retirement.honor.",
        ]
        let keys = ProUICopyKey.allCases.filter { key in prefixes.contains { key.rawValue.hasPrefix($0) } }
        XCTAssertGreaterThanOrEqual(keys.count, 30)
        let hangul = try NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]")
        for key in keys {
            let entry = try XCTUnwrap(strings[key.rawValue] as? [String: Any], key.rawValue)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key.rawValue)
            let values = try ["ko", "en", "ja"].map { language -> String in
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], key.rawValue + ":" + language)
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], key.rawValue + ":" + language)
                XCTAssertEqual(unit["state"] as? String, "translated", key.rawValue + ":" + language)
                return try XCTUnwrap(unit["value"] as? String, key.rawValue + ":" + language)
            }
            XCTAssertEqual(GameCopyResolver.placeholderKinds(in: values[0]), GameCopyResolver.placeholderKinds(in: values[1]), key.rawValue)
            XCTAssertEqual(GameCopyResolver.placeholderKinds(in: values[0]), GameCopyResolver.placeholderKinds(in: values[2]), key.rawValue)
            XCTAssertNil(hangul.firstMatch(in: values[1], range: NSRange(location: 0, length: values[1].utf16.count)), key.rawValue)
        }
    }

    func testEnabledStoreMigratesAtSeasonReviewAndAcknowledgesExactlyOnce() throws {
        var writes: [Data] = []
        let store = MobileCareerStore(
            saveWriter: { writes.append($0); return true },
            configuration: .journeyV1Tests
        )
        let legacyResult = try seasonReviewFixture()
        let salary = try XCTUnwrap(legacyResult.snapshot.contract?.annualSalary)
        store.result = legacyResult

        store.reviewSeason()

        let settled = try XCTUnwrap(store.state)
        let journey = try XCTUnwrap(
            settled.journeyState,
            "store did not produce a journey state; phase=" + settled.phase.rawValue + " load=" + String(describing: store.loadState)
        )
        XCTAssertEqual(settled.phase, .seasonSettlement)
        XCTAssertEqual(journey.lastSettlement?.salaryIncome, Int64(salary))
        XCTAssertEqual(journey.finances.transactions.filter { $0.kind == .salary }.count, 1)
        XCTAssertEqual(writes.count, 1)
        let savedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: writes[0]) as? [String: Any])
        let savedResult = try XCTUnwrap(savedObject["result"] as? [String: Any])
        let savedSnapshot = try XCTUnwrap(savedResult["snapshot"] as? [String: Any])
        XCTAssertNotNil(savedSnapshot["journeyState"])

        let settlementID = try XCTUnwrap(journey.lastSettlement?.id)
        store.acknowledgeSettlement()
        let acknowledged = try XCTUnwrap(store.state)
        XCTAssertEqual(acknowledged.phase, .offseasonDecision)
        XCTAssertTrue(acknowledged.journeyState?.settlementAcknowledged == true)
        let revision = acknowledged.revision
        XCTAssertEqual(acknowledged.journeyState?.finances.transactions.filter { $0.kind == .salary }.count, 1)
        XCTAssertFalse(acknowledged.journeyState?.migration.financeNoticePending == true)

        store.acknowledgeSettlement()
        XCTAssertEqual(store.state?.revision, revision)
        XCTAssertEqual(store.state?.journeyState?.lastSettlement?.id, settlementID)
        XCTAssertEqual(store.state?.journeyState?.finances.transactions.filter { $0.kind == .salary }.count, 1)
    }

    func testEnabledRestoreMigratesOffseasonBeforeExposureAndPersistsAtomically() throws {
        let cloud = JourneyWave1MemoryRemoteStore()
        let sync = SaveSync(key: "wave1-offseason-restore-\(UUID().uuidString).json", store: cloud)
        sync.clear()
        defer { sync.clear() }

        let legacy = try legacyOffseasonFixture()
        let originalData = try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: legacy,
                schemaVersion: MobileCareerStore.legacySaveSchemaVersion,
                syncRevision: legacy.snapshot.revision
            )
        )
        XCTAssertTrue(sync.write(originalData))

        let store = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        store.restoreOrCreateCareer()

        XCTAssertEqual(store.loadState, .ready)
        let restored = try XCTUnwrap(store.result)
        XCTAssertEqual(restored.nextSeed, legacy.nextSeed, "safe restore migration must not consume RNG")
        XCTAssertEqual(restored.snapshot.phase, .offseasonDecision)
        XCTAssertNotNil(restored.snapshot.journeyState)
        XCTAssertGreaterThan(restored.snapshot.revision, legacy.snapshot.revision)

        let persistedData = try XCTUnwrap(cloud.data(forKey: sync.key))
        let persisted = try JSONDecoder().decode(MobileCareerStore.ProSaveRecord.self, from: persistedData)
        XCTAssertEqual(persisted.schemaVersion, MobileCareerStore.journeySaveSchemaVersion)
        XCTAssertEqual(persisted.result, restored)
        XCTAssertNotEqual(persistedData, originalData)
    }

    func testEnabledRestoreLeavesWeeklyReviewPendingAndCompletedLegacySavesByteUntouched() throws {
        let fixtures: [(String, ProCareerResult)] = [
            ("weeklyPlan", try legacyResult(at: .weeklyPlan)),
            ("seasonReview", try legacyResult(at: .seasonReview)),
            ("seasonDecision", try legacyResult(at: .seasonDecision)),
            ("importantGame", try legacyResult(at: .importantGame)),
            ("contractOffer", try legacyContractOfferFixture()),
            ("completed", try legacyCompletedFixture()),
        ]

        for (label, legacy) in fixtures {
            try assertLegacyRestoreUntouched(legacy, label: label)
        }
    }

    func testEnabledOffseasonRestoreFailureDoesNotExposeMigratedState() throws {
        let cloud = JourneyWave1MemoryRemoteStore()
        let directoryName = "wave1-offseason-restore-failure-\(UUID().uuidString)"
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent(directoryName, isDirectory: true)
        let sync = SaveSync(key: "\(directoryName)/career.json", store: cloud)
        defer {
            sync.clear()
            try? FileManager.default.removeItem(at: directory)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = try legacyOffseasonFixture()
        let originalData = try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: legacy,
                schemaVersion: MobileCareerStore.legacySaveSchemaVersion,
                syncRevision: legacy.snapshot.revision
            )
        )
        XCTAssertTrue(sync.write(originalData))
        try FileManager.default.removeItem(at: directory)

        let store = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        store.restoreOrCreateCareer()

        XCTAssertEqual(store.loadState, .failed(MobileCareerStore.unreadableSaveMessage))
        XCTAssertNil(store.result, "a failed migration must not expose its unpersisted journey state")
        XCTAssertEqual(cloud.data(forKey: sync.key), originalData)
    }

    func testLegacySchemaCannotCarryJourneyAndIsNotDecodedOrOverwritten() throws {
        let cloud = JourneyWave1MemoryRemoteStore()
        let sync = SaveSync(key: "wave1-downgrade-\(UUID().uuidString).json", store: cloud)
        sync.clear()
        defer { sync.clear() }

        let journeyResult = try journeyFixture()
        let invalidData = try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: journeyResult,
                schemaVersion: MobileCareerStore.legacySaveSchemaVersion,
                syncRevision: journeyResult.snapshot.revision
            )
        )
        XCTAssertTrue(sync.write(invalidData))

        let store = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        store.restoreOrCreateCareer()
        XCTAssertEqual(store.loadState, .failed(MobileCareerStore.unreadableSaveMessage))
        XCTAssertNil(store.result)
        XCTAssertEqual(cloud.data(forKey: sync.key), invalidData)
    }

    func testJourneyDeletionTombstoneBlocksLegacySchemaWrite() throws {
        let cloud = JourneyWave1MemoryRemoteStore()
        let sync = SaveSync(key: "wave1-tombstone-gate-\(UUID().uuidString).json", store: cloud)
        sync.clear()
        defer { sync.clear() }

        let journeyStore = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        journeyStore.result = try journeyFixture()
        journeyStore.loadState = .ready
        XCTAssertTrue(journeyStore.save())
        XCTAssertTrue(journeyStore.deleteCareer())
        let tombstoneData = try XCTUnwrap(cloud.data(forKey: sync.key))
        let tombstone = try JSONDecoder().decode(MobileCareerStore.ProSaveRecord.self, from: tombstoneData)
        XCTAssertEqual(tombstone.schemaVersion, MobileCareerStore.journeySaveSchemaVersion)
        XCTAssertNil(tombstone.result)

        let legacyStore = MobileCareerStore(sync: sync, configuration: .production)
        legacyStore.restoreOrCreateCareer()
        XCTAssertEqual(legacyStore.loadState, .needsSetup)
        XCTAssertFalse(legacyStore.startNewCareer(preset: preset, playerName: "구버전 덮어쓰기"))
        XCTAssertEqual(cloud.data(forKey: sync.key), tombstoneData)
    }

    func testEnabledRestoreLeavesCompletedLegacySaveUntouched() throws {
        let cloud = JourneyWave1MemoryRemoteStore()
        let sync = SaveSync(key: "wave1-completed-restore-\(UUID().uuidString).json", store: cloud)
        sync.clear()
        defer { sync.clear() }

        let review = try legacyOffseasonFixture()
        let completed = try ProCareerEngine().chooseOffseason(.init(
            seed: review.nextSeed,
            state: review.snapshot,
            decision: .retire
        ))
        let originalData = try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: completed,
                schemaVersion: MobileCareerStore.legacySaveSchemaVersion,
                syncRevision: completed.snapshot.revision
            )
        )
        XCTAssertTrue(sync.write(originalData))

        let store = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        store.restoreOrCreateCareer()

        XCTAssertEqual(store.loadState, .ready)
        XCTAssertEqual(store.result, completed)
        XCTAssertNil(store.state?.journeyState)
        XCTAssertEqual(cloud.data(forKey: sync.key), originalData)
    }

    func testWave1SwiftUISurfacesHaveStableAccessibilityRootsAndStoredProjectionInputs() throws {
        let root = repositoryRoot()
        let flow = try String(
            contentsOf: root.appendingPathComponent("apps/ios/Sources/CareerFlowView.swift"),
            encoding: .utf8
        )
        let shell = try String(
            contentsOf: root.appendingPathComponent("apps/ios/Sources/AppShell.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(flow.contains("struct ProSeasonSettlementView: View"))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"pro.seasonSettlement\")"))
        XCTAssertTrue(flow.contains("identifier: \"pro.settlement.acknowledge\""))
        XCTAssertTrue(flow.contains("settlement.salaryIncome"))
        XCTAssertTrue(flow.contains("settlement.teamLegacyBefore"))
        XCTAssertFalse(flow.contains("ProTeamLegacyRules.score"), "settlement UI must render stored projections")

        XCTAssertTrue(shell.contains("struct CareerDirectionCard: View"))
        XCTAssertTrue(shell.contains("accessibilityIdentifier(\"pro.careerDirection\")"))
        XCTAssertTrue(shell.contains("ProTeamLegacyRules.score(record:"))
        XCTAssertTrue(shell.contains("ProCareerEngine.hallOfFameProjection(for: state)"))
        XCTAssertTrue(shell.contains("ProCareerGoalRules.progress(state: state, goal: goal)"))
    }

    func testWave1CopyKeysHaveKoreanEnglishJapaneseParityAndNoRealClubCopy() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Localization/Localizable.xcstrings")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let keys = ProUICopyKey.allCases.filter {
            $0.rawValue == "pro.action.season-settlement"
                || $0.rawValue.hasPrefix("pro.journey.")
                || $0.rawValue.hasPrefix("pro.settlement.")
        }
        XCTAssertGreaterThan(keys.count, 20)

        let forbidden = Set([
            "KBO", "NPB", "두산", "LG", "기아", "삼성", "롯데", "한화", "SSG", "키움", "NC", "KT",
            "베어스", "타이거즈", "자이언츠", "이글스", "라이온즈", "트윈스", "위즈", "다이노스", "히어로즈",
        ])
        for key in keys {
            let entry = try XCTUnwrap(strings[key.rawValue] as? [String: Any], key.rawValue)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key.rawValue)
            let values = try ["ko", "en", "ja"].map { language -> String in
                let label = key.rawValue + ":" + language
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], label)
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], label)
                XCTAssertEqual(unit["state"] as? String, "translated", label)
                return try XCTUnwrap(unit["value"] as? String, label)
            }
            XCTAssertEqual(GameCopyResolver.placeholderKinds(in: values[0]), GameCopyResolver.placeholderKinds(in: values[1]), key.rawValue)
            XCTAssertEqual(GameCopyResolver.placeholderKinds(in: values[0]), GameCopyResolver.placeholderKinds(in: values[2]), key.rawValue)
            for value in values {
                let words = value.split { !$0.isLetter && !$0.isNumber }.map { $0.uppercased() }
                XCTAssertTrue(words.allSatisfy { !forbidden.contains($0) }, "real club or league copy in " + key.rawValue)
            }
        }
    }

    private func journeyFixture() throws -> ProCareerResult {
        let legacy = try seasonReviewFixture()
        return try ProCareerEngine(journeyEnabled: true).migrateJourneyIfSafe(.init(
            seed: legacy.nextSeed,
            state: legacy.snapshot
        ))
    }

    private func legacyOffseasonFixture() throws -> ProCareerResult {
        let review = try seasonReviewFixture()
        return try ProCareerEngine().reviewSeason(.init(seed: review.nextSeed, state: review.snapshot))
    }

    private func legacyResult(at target: ProCareerPhase) throws -> ProCareerResult {
        if target == .contractOffer {
            return try legacyContractOfferFixture()
        }
        let engine = ProCareerEngine()
        var result = try CareerBootstrap.startCareer(
            preset: preset,
            playerName: "웨이브1경계",
            seed: 20_260_817,
            engine: engine
        )
        for _ in 0..<180 {
            if result.snapshot.phase == target { return result }
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: try XCTUnwrap(decision.choices.first?.id)
                ))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.week,
                        pitches: 18,
                        strikeouts: 2,
                        walks: 0,
                        runsAllowed: 0,
                        expectedDamage: 400,
                        actualDamage: 200,
                        recommendationAccepted: 10
                    )
                ))
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decision: .continueCareer
                ))
            default:
                throw SimulationError.invalidProCareer("iOS Wave 1 restore fixture entered \(result.snapshot.phase.rawValue)")
            }
        }
        throw SimulationError.invalidProCareer("iOS Wave 1 restore fixture exceeded \(target.rawValue) bound")
    }

    private func legacyContractOfferFixture() throws -> ProCareerResult {
        try ProCareerEngine().start(.init(
            seed: "20260818",
            identity: .defaultPitcher,
            pitcher: .init(id: "wave1-contract-offer", name: "Wave 1", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: nil,
                summary: "fixture"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-15")
        ))
    }

    private func legacyCompletedFixture() throws -> ProCareerResult {
        let offseason = try legacyOffseasonFixture()
        return try ProCareerEngine().chooseOffseason(.init(
            seed: offseason.nextSeed,
            state: offseason.snapshot,
            decision: .retire
        ))
    }

    private func assertLegacyRestoreUntouched(
        _ legacy: ProCareerResult,
        label: String
    ) throws {
        let cloud = JourneyWave1MemoryRemoteStore()
        let sync = SaveSync(key: "wave1-restore-untouched-\(label)-\(UUID().uuidString).json", store: cloud)
        defer { sync.clear() }

        let originalData = try JSONEncoder().encode(
            MobileCareerStore.ProSaveRecord(
                result: legacy,
                schemaVersion: MobileCareerStore.legacySaveSchemaVersion,
                syncRevision: legacy.snapshot.revision
            )
        )
        XCTAssertTrue(sync.write(originalData), label)

        let store = MobileCareerStore(sync: sync, configuration: .journeyV1Tests)
        store.restoreOrCreateCareer()

        XCTAssertEqual(store.loadState, .ready, label)
        XCTAssertEqual(store.state, legacy.snapshot, label)
        XCTAssertEqual(store.result?.nextSeed, legacy.nextSeed, label)
        XCTAssertNil(store.state?.journeyState, label)
        XCTAssertEqual(cloud.data(forKey: sync.key), originalData, label)
    }

    private func seasonReviewFixture() throws -> ProCareerResult {
        let engine = ProCareerEngine()
        var result = try CareerBootstrap.startCareer(
            preset: preset,
            playerName: "웨이브1투수",
            seed: 20_260_816,
            engine: engine
        )
        for _ in 0..<160 {
            if result.snapshot.phase == .seasonReview { return result }
            switch result.snapshot.phase {
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .earnTrust))
            case .seasonDecision:
                let decision = try XCTUnwrap(result.snapshot.pendingDecision)
                let choice = try XCTUnwrap(decision.choices.first)
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: choice.id
                ))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.week,
                        pitches: 18,
                        strikeouts: 2,
                        walks: 0,
                        runsAllowed: 0,
                        expectedDamage: 400,
                        actualDamage: 200,
                        recommendationAccepted: 10
                    )
                ))
            default:
                throw SimulationError.invalidProCareer("iOS Wave 1 fixture entered " + result.snapshot.phase.rawValue)
            }
        }
        throw SimulationError.invalidProCareer("iOS Wave 1 fixture exceeded its season-review bound")
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
