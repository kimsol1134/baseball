import Foundation
import XCTest
@testable import BaseballIOS

@MainActor
final class ProCareerContractWave3Tests: XCTestCase {
    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testOfferSurfaceUsesPersistedComparableCardsAndExplicitConfirmation() throws {
        let flow = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/CareerFlowView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(flow.contains("ForEach(Array(market.offers.enumerated()), id: \\.offset)"))
        XCTAssertTrue(flow.contains("offerCard(offer, index: index, selectable: market.kind != .rookie)"))
        XCTAssertTrue(flow.contains("if market.kind == .rookie, let offer"))
        XCTAssertTrue(flow.contains(".confirmationDialog("))
        XCTAssertTrue(flow.contains("career.acceptContract(\n                            marketID: market.id"))
        XCTAssertTrue(flow.contains("identifier: \"\\(prefix).duration\""))
        XCTAssertTrue(flow.contains("identifier: \"\\(prefix).annualSalary\""))
        XCTAssertTrue(flow.contains("identifier: \"\\(prefix).guarantee\""))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"\\(prefix).role\")"))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"\\(prefix).expectation\")"))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"\\(prefix).legacy\")"))
        XCTAssertTrue(flow.contains("Career totals stay, but the new team's standing starts over") || flow.contains("contractOfferConfirmTransferMessage"))
        XCTAssertTrue(flow.contains("case .offseasonInvestment:"))
        XCTAssertTrue(flow.contains("pro.offseasonInvestment.continue"))
    }

    func testStoreLogsContractAnalyticsOnlyAfterPersistenceWithLowCardinalityFields() throws {
        let source = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/MobileCareerStore.swift"),
            encoding: .utf8
        )
        let acceptedRange = try XCTUnwrap(source.range(of: "let accepted = perform"))
        let analyticsRange = try XCTUnwrap(source.range(of: "GameAnalytics.log(.proContractSigned"))
        XCTAssertLessThan(acceptedRange.lowerBound, analyticsRange.lowerBound)
        XCTAssertTrue(source.contains("\"market_kind\""))
        XCTAssertTrue(source.contains("\"offer_kind\""))
        XCTAssertTrue(source.contains("\"outlook\""))
        XCTAssertTrue(source.contains("\"transfer\""))
        XCTAssertTrue(source.contains("\"ambition_selected\""))
        XCTAssertFalse(source.contains("\"market_id\""))
        XCTAssertFalse(source.contains("\"offer_id\""))
        XCTAssertFalse(source.contains("\"annual_salary\""))
        XCTAssertFalse(source.contains("\"team_name\""))
    }

    func testWave3LocalizedKeysHaveKoreanEnglishJapaneseParity() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Localization/Localizable.xcstrings")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let prefixes = [
            "pro.contract.offer.confirm.",
            "pro.contract.offer.market.",
            "pro.contract.offer.guarantee",
            "pro.contract.offer.legacy-",
            "pro.contract.offer.all-ambitions-complete",
            "pro.offseason.renewal.",
            "pro.offseason.open-market.",
            "pro.offseason.active-contract.",
            "pro.offseason.military.journey.",
            "pro.offseason.investment.",
        ]
        let keys = ProUICopyKey.allCases.filter { key in
            prefixes.contains { key.rawValue.hasPrefix($0) }
        }
        XCTAssertGreaterThanOrEqual(keys.count, 24)
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
        }
    }

    func testWave5InvestmentAccessibilityAndMediaContentContracts() throws {
        let flow = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/CareerFlowView.swift"),
            encoding: .utf8
        )
        for identifier in [
            "pro.offseasonInvestment.choice.",
            "pro.offseasonInvestment.focus",
            "pro.offseasonInvestment.confirm",
            "pro.settlement.fanReasons",
            "pro.settlement.merchandise",
        ] {
            XCTAssertTrue(flow.contains(identifier), identifier)
        }
        XCTAssertTrue(flow.contains("ProFinanceRules.investmentCost(for: investment)"))
        XCTAssertTrue(flow.contains("journeySettlementMerchandiseTier"))

        let store = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/MobileCareerStore.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(store.contains("investment: investment"))
        XCTAssertTrue(store.contains("focus: focus"))
        XCTAssertTrue(store.contains("proOffseasonInvestmentSelected"))
        XCTAssertTrue(store.contains("proEndorsementSelected"))
        XCTAssertTrue(store.contains("funds_band"))
        XCTAssertFalse(store.contains("annual_salary"))

        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Localization/GameContent.xcstrings")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let mediaIDs = [
            "content.pro-season-decision-type.media_opportunity.label",
            "content.pro-media-opportunity.title",
            "content.pro-media-opportunity.detail",
            "content.pro-media-opportunity.choice.advertising.title",
            "content.pro-media-opportunity.choice.advertising.detail",
            "content.pro-media-opportunity.choice.fan_together.title",
            "content.pro-media-opportunity.choice.fan_together.detail",
            "content.pro-media-opportunity.choice.focus.title",
            "content.pro-media-opportunity.choice.focus.detail",
        ]
        for id in mediaIDs {
            let entry = try XCTUnwrap(strings[id] as? [String: Any], id)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], id)
            for language in ["ko", "en", "ja"] {
                let label = id + ":" + language
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], label)
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], label)
                XCTAssertEqual(unit["state"] as? String, "translated", label)
                XCTAssertFalse((unit["value"] as? String ?? "").isEmpty, label)
            }
        }
    }

    func testWave5PresentationContractsExposeBenefitsAndKeepMoneyAfterCareerDirection() throws {
        let flow = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/CareerFlowView.swift"),
            encoding: .utf8
        )
        let presentation = try String(
            contentsOf: repositoryRoot().appendingPathComponent("apps/ios/Sources/ProCareerPresentation.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(flow.contains(".offseasonInvestmentPitchLabBenefit"))
        XCTAssertTrue(flow.contains(".offseasonInvestmentRecoveryTeamBenefit"))
        XCTAssertTrue(presentation.contains("decision.type == .mediaOpportunity"))
        XCTAssertTrue(presentation.contains("resolver.resolve(.decisionImmediateEffect)"))
        XCTAssertTrue(presentation.contains("resolver.resolve(.decisionFollowUp)"))
        XCTAssertTrue(flow.contains("decisionTiming(for: decision, resolver: copyResolver)"))
        XCTAssertTrue(flow.contains("decisionTiming(for: choice, resolver: resolver)"))

        let records = try XCTUnwrap(
            flow.range(of: "BaseballCard(title: ProCareerPresentation.teamName(state.team")
        )
        let legacy = try XCTUnwrap(flow.range(of: ".journeySettlementLegacy"))
        let goal = try XCTUnwrap(flow.range(of: "if let goalProgress = settlement.goalProgressAfter"))
        let salary = try XCTUnwrap(flow.range(of: "BaseballCard(title: copyResolver.resolve(.journeySettlementSalaryTitle)"))
        let merchandise = try XCTUnwrap(flow.range(of: "BaseballCard(title: copyResolver.resolve(.journeySettlementMerchandiseTitle)"))

        XCTAssertLessThan(records.lowerBound, legacy.lowerBound)
        XCTAssertLessThan(legacy.lowerBound, goal.lowerBound)
        XCTAssertLessThan(goal.lowerBound, salary.lowerBound)
        XCTAssertLessThan(salary.lowerBound, merchandise.lowerBound)
    }

    func testSettlementMoneyCardsUseSeparateTitleAndAccessibleValueTemplates() {
        let resolver = GameCopyResolver(language: .japanese, policy: .strict)

        XCTAssertEqual(resolver.resolve(.journeySettlementSalaryTitle), "年俸")
        XCTAssertEqual(
            resolver.resolve(.journeySettlementSalary, arguments: [.userText("1億円")]),
            "年俸 1億円"
        )
        XCTAssertEqual(resolver.resolve(.journeySettlementMerchandiseTitle), "応援商品収益")
        XCTAssertEqual(
            resolver.resolve(.journeySettlementMerchandise, arguments: [.userText("500万円")]),
            "応援商品収益 500万円"
        )
    }

    func testWave5BenefitAndImmediateTimingCatalogsAreExplicitInKoEnJa() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Localization/Localizable.xcstrings")
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        let requirements: [(String, [String: [String]])] = [
            (
                "pro.offseason.investment.benefit.pitch-lab",
                [
                    "ko": ["진행률", "1", "능력치", "즉시"],
                    "en": ["progress", "1", "ability rating", "immediately"],
                    "ja": ["進行度", "1", "能力値", "すぐには"],
                ]
            ),
            (
                "pro.offseason.investment.benefit.recovery-team",
                [
                    "ko": ["첫 부상", "1주", "1회 충전", "RNG", "다시 굴리지"],
                    "en": ["first injury", "1 week", "one charge", "RNG", "reroll"],
                    "ja": ["最初の負傷", "1週間", "1チャージ", "RNG", "振り直"],
                ]
            ),
            (
                "pro.decision.immediate-effect",
                [
                    "ko": ["미디어 선택", "즉시 적용", "다음 직접 승부"],
                    "en": ["media choice", "takes effect immediately", "direct matchup"],
                    "ja": ["メディア選択", "すぐに適用", "直接対決"],
                ]
            ),
        ]

        for (id, tokensByLanguage) in requirements {
            let entry = try XCTUnwrap(strings[id] as? [String: Any], id)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], id)
            var values: [String: String] = [:]
            for language in ["ko", "en", "ja"] {
                let label = id + ":" + language
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], label)
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], label)
                XCTAssertEqual(unit["state"] as? String, "translated", label)
                let value = try XCTUnwrap(unit["value"] as? String, label)
                values[language] = value
                for token in try XCTUnwrap(tokensByLanguage[language], label) {
                    XCTAssertTrue(value.localizedCaseInsensitiveContains(token), "\(label) missing \(token): \(value)")
                }
            }
            let orderedValues = try ["ko", "en", "ja"].map { try XCTUnwrap(values[$0]) }
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: orderedValues[0]),
                GameCopyResolver.placeholderKinds(in: orderedValues[1]),
                id
            )
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: orderedValues[0]),
                GameCopyResolver.placeholderKinds(in: orderedValues[2]),
                id
            )
        }
    }
}
