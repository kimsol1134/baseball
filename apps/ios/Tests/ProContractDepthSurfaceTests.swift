import Foundation
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain
import SimulationCore

@MainActor
final class ProContractDepthSurfaceTests: XCTestCase {
    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testOfferSurfaceExposesInterestBadgeCounterAndSigningBonus() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/ProContractOfferView.swift")
        XCTAssertTrue(source.contains("pro.contractOffer.interest.\\(interest.level.rawValue)"))
        XCTAssertTrue(source.contains("pro.contractOffer.counter.extra_year"))
        XCTAssertTrue(source.contains("pro.contractOffer.counter.raise_salary"))
        XCTAssertTrue(source.contains("CareerDisplayRules.canRequestContractCounter"))
        XCTAssertTrue(source.contains("career.requestContractCounter(kind:"))
        XCTAssertTrue(source.contains("CareerDisplayRules.totalGuaranteedSalary"))
        XCTAssertFalse(source.contains("ProContractMarketRules."))
        XCTAssertFalse(source.contains("arguments:"))
    }

    func testInvestmentViewAddsEquipmentAndTrainerBehindRulesGate() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/ProOffseasonInvestmentView.swift")
        XCTAssertTrue(source.contains("CareerDisplayRules.offseasonInvestmentOptions(for: state)"))
        XCTAssertTrue(source.contains(".offseasonInvestmentChoiceEquipment"))
        XCTAssertTrue(source.contains(".offseasonInvestmentChoicePersonalTrainer"))
        XCTAssertTrue(source.contains(".equipment, .personalTrainer"))
    }

    func testStoreLogsCounterAndContractBandsAfterPersistence() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/Application/MobileCareerStore+Season.swift")
        XCTAssertTrue(source.contains("requestContractCounter(kind:"))
        XCTAssertTrue(source.contains("CareerTelemetry.log(.proContractCounterRequested"))
        XCTAssertTrue(source.contains("\"kind\""))
        XCTAssertTrue(source.contains("\"accepted\""))
        XCTAssertTrue(source.contains("\"years\""))
        XCTAssertTrue(source.contains("\"signing_bonus_band\""))
        XCTAssertTrue(source.contains("\"interest\""))
        XCTAssertEqual(GameAnalytics.Event.proContractCounterRequested.rawValue, "pro_contract_counter_requested")
    }

    func testNewCopyKeysHaveLanguageParity() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Presentation/Localization/Localizable.xcstrings")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let keys = [
            ProUICopyKey.contractOfferInterestHot,
            .contractOfferInterestWarm,
            .contractOfferInterestCool,
            .contractOfferCounterAction,
            .contractOfferCounterTitle,
            .contractOfferCounterExtraYear,
            .contractOfferCounterRaiseSalary,
            .contractOfferCounterAccepted,
            .contractOfferCounterRejected,
            .offseasonInvestmentChoiceEquipment,
            .offseasonInvestmentChoicePersonalTrainer,
            .offseasonInvestmentEquipmentBenefit,
            .offseasonInvestmentTrainerBenefit,
        ]
        for key in keys {
            let entry = try XCTUnwrap(strings[key.rawValue] as? [String: Any], key.rawValue)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key.rawValue)
            for language in ["ko", "en", "ja"] {
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], "\(key.rawValue):\(language)")
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any])
                XCTAssertEqual(unit["state"] as? String, "translated", "\(key.rawValue):\(language)")
                XCTAssertFalse((unit["value"] as? String ?? "").isEmpty, "\(key.rawValue):\(language)")
            }
        }
    }
}
