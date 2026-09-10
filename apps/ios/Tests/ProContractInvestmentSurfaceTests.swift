import Foundation
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain

@MainActor
final class ProContractInvestmentSurfaceTests: XCTestCase {
    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testOfferSurfaceUsesPersistedComparableCardsAndExplicitConfirmation() throws {
        let flow = try IOSSourceScan.readAll([
            "apps/ios/Sources/CareerFlowView.swift",
            "apps/ios/Sources/ProContractOfferView.swift",
            "apps/ios/Sources/ProOffseasonInvestmentView.swift",
            "apps/ios/Sources/ProSeasonSettlementView.swift",
            "apps/ios/Sources/ProSeasonDecisionView.swift",
            "apps/ios/Sources/ProOffseasonViews.swift",
            "apps/ios/Sources/CareerFlowChrome.swift",
        ])

        XCTAssertTrue(flow.contains("ForEach(Array(market.offers.enumerated()), id: \\.offset)"))
        XCTAssertTrue(flow.contains("selectable: market.kind != .rookie,"))
        XCTAssertTrue(flow.contains("enabled: goalSelectionComplete"))
        XCTAssertTrue(flow.contains("if market.kind == .rookie, let offer"))
        // 6-D: 확인을 모달에서 같은 화면의 확인 블록으로 옮겼다(iOS 26에서는 알럿마저
        // 팝오버로 떠 취소가 잘렸다). **계약 수락에 명시적 확인 단계가 있다**는 계약은 그대로다.
        let offerScreen = try IOSSourceScan.typeBody(
            "ProContractOfferView",
            in: "apps/ios/Sources/ProContractOfferView.swift"
        )
        XCTAssertFalse(offerScreen.contains(".alert("))
        XCTAssertFalse(offerScreen.contains(".confirmationDialog("))
        XCTAssertTrue(flow.contains("private func confirmBlock(_ market: ProContractMarket)"))
        XCTAssertTrue(flow.contains("identifier: \"pro.contractOffer.confirm.accept\""))
        XCTAssertTrue(flow.contains("pro.contractOffer.confirm.cancel"))
        XCTAssertTrue(flow.contains("career.acceptContract("))
        XCTAssertTrue(flow.contains("identifier: \"\\(prefix).duration\""))
        XCTAssertTrue(flow.contains("identifier: \"\\(prefix).annualSalary\""))
        XCTAssertTrue(flow.contains("identifier: \"\\(prefix).guarantee\""))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"\\(prefix).role\")"))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"\\(prefix).expectation\")"))
        XCTAssertTrue(flow.contains("accessibilityIdentifier(\"\\(prefix).legacy\")"))
        XCTAssertTrue(
            flow.contains("Career totals stay, but the new team's standing starts over")
                || flow.contains("contractOfferConfirmTransferMessage")
                || flow.contains("ProContractCopy.confirmation")
        )
        XCTAssertTrue(flow.contains("case .offseasonInvestment:"))
        XCTAssertTrue(flow.contains("pro.offseasonInvestment.continue"))
    }

    func testCounterChoicesDisableWhenUnavailableAndHideActionWhenBothBlocked() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/ProContractOfferView.swift")
        XCTAssertTrue(source.contains("MobileCareerStore.counterAvailability(for: state, kind: .extraYear)"))
        XCTAssertTrue(source.contains("MobileCareerStore.counterAvailability(for: state, kind: .raiseSalary)"))
        XCTAssertTrue(source.contains(".disabled(!isAvailable)"))
        XCTAssertTrue(source.contains("if extraYearAvailable || raiseSalaryAvailable"))
        XCTAssertTrue(source.contains("stayCounterUnavailableReasons"))
        XCTAssertTrue(source.contains("pro.contractOffer.counter.unavailable"))
        XCTAssertTrue(source.contains("ProContractCopy.counterUnavailable"))
        XCTAssertFalse(source.contains("ProContractMarketRules."))
        XCTAssertFalse(source.contains("arguments:"))

        let store = try IOSSourceScan.read("apps/ios/Sources/Application/MobileCareerStore+Season.swift")
        XCTAssertTrue(store.contains("CareerDisplayRules.counterAvailability(for: current.snapshot, kind: kind).isAvailable"))

        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Presentation/Localization/GameContent.xcstrings")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])
        for key in [
            "content.contract.counter.unavailable.years",
            "content.contract.counter.unavailable.dominance",
            "content.contract.counter.unavailable.salary-band",
        ] {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], key)
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], key)
            for language in ["ko", "en", "ja"] {
                let label = "\(key):\(language)"
                let localization = try XCTUnwrap(localizations[language] as? [String: Any], label)
                let unit = try XCTUnwrap(localization["stringUnit"] as? [String: Any], label)
                XCTAssertEqual(unit["state"] as? String, "translated", label)
                XCTAssertFalse((unit["value"] as? String ?? "").isEmpty, label)
            }
        }
    }

    func testRenewalRequiresGoalBeforeOfferAndKeepsConfirmationGuarded() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/ProContractOfferView.swift")
        let goalBeforeOffers = try XCTUnwrap(source.range(of: "if market.kind != .rookie {\n                    goalSelectionSection(market)"))
        let offers = try XCTUnwrap(source.range(of: "ForEach(Array(market.offers.enumerated()), id: \\.offset)"))
        XCTAssertLessThan(goalBeforeOffers.lowerBound, offers.lowerBound)

        XCTAssertTrue(source.contains(".disabled(!enabled)"))
        XCTAssertTrue(source.contains("guard enabled else { return }"))
        XCTAssertTrue(source.contains("enabled ? .contractOfferReview : .contractOfferAmbitionRequired"))
        // 목표를 고르기 전에는 서명이 열리지 않는다(모달이 사라진 뒤에도 같은 규칙).
        XCTAssertTrue(source.contains("enabled: goalSelectionComplete"))
        XCTAssertTrue(source.contains("guard goalSelectionComplete else { return }"))
        XCTAssertTrue(source.contains("pendingOfferID = nil\n                selectedAmbition = nil"))
    }

    func testStoreLogsContractAnalyticsOnlyAfterPersistenceWithLowCardinalityFields() throws {
        let source = try IOSSourceScan.readAll([
            "apps/ios/Sources/Application/MobileCareerStore.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Lifecycle.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Week.swift",
            "apps/ios/Sources/Application/MobileCareerStore+ImportantGame.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Season.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Persistence.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Queries.swift",
        ])
        let acceptedRange = try XCTUnwrap(source.range(of: "let accepted = perform"))
        let analyticsRange = try XCTUnwrap(source.range(of: "CareerTelemetry.log(.proContractSigned"))
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

    func testContractLocalizedKeysHaveLanguageParity() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Presentation/Localization/Localizable.xcstrings")
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

    func testInvestmentAccessibilityAndMediaContentContracts() throws {
        let flow = try IOSSourceScan.readAll([
            "apps/ios/Sources/CareerFlowView.swift",
            "apps/ios/Sources/ProContractOfferView.swift",
            "apps/ios/Sources/ProOffseasonInvestmentView.swift",
            "apps/ios/Sources/ProSeasonSettlementView.swift",
            "apps/ios/Sources/ProSeasonDecisionView.swift",
            "apps/ios/Sources/ProOffseasonViews.swift",
            "apps/ios/Sources/CareerFlowChrome.swift",
            "apps/ios/Sources/Presentation/ProFeatureCopy.swift",
        ])
        for identifier in [
            "pro.offseasonInvestment.choice.",
            "pro.offseasonInvestment.focus",
            "pro.offseasonInvestment.confirm",
            "pro.settlement.fanReasons",
            "pro.settlement.merchandise",
        ] {
            XCTAssertTrue(flow.contains(identifier), identifier)
        }
        XCTAssertTrue(flow.contains("CareerDisplayRules.investmentCost(for: investment)"))
        XCTAssertTrue(flow.contains("journeySettlementMerchandiseTier"))

        let store = try IOSSourceScan.readAll([
            "apps/ios/Sources/Application/MobileCareerStore.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Lifecycle.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Week.swift",
            "apps/ios/Sources/Application/MobileCareerStore+ImportantGame.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Season.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Persistence.swift",
            "apps/ios/Sources/Application/MobileCareerStore+Queries.swift",
        ])
        XCTAssertTrue(store.contains("investment: investment"))
        XCTAssertTrue(store.contains("focus: focus"))
        XCTAssertTrue(store.contains("proOffseasonInvestmentSelected"))
        XCTAssertTrue(store.contains("proEndorsementSelected"))
        XCTAssertTrue(store.contains("funds_band"))
        XCTAssertFalse(store.contains("annual_salary"))

        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Presentation/Localization/GameContent.xcstrings")
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

    func testInvestmentPresentationExposesBenefitsAndKeepsMoney() throws {
        let flow = try IOSSourceScan.readAll([
            "apps/ios/Sources/CareerFlowView.swift",
            "apps/ios/Sources/ProContractOfferView.swift",
            "apps/ios/Sources/ProOffseasonInvestmentView.swift",
            "apps/ios/Sources/ProSeasonSettlementView.swift",
            "apps/ios/Sources/ProSeasonDecisionView.swift",
            "apps/ios/Sources/ProOffseasonViews.swift",
            "apps/ios/Sources/CareerFlowChrome.swift",
        ])
        let presentation = try IOSSourceScan.readAll([
            "apps/ios/Sources/Presentation/ProCareerPresentation.swift",
            "apps/ios/Sources/Presentation/ProFeatureCopy.swift",
        ])

        XCTAssertTrue(presentation.contains(".offseasonInvestmentPitchLabBenefit"))
        XCTAssertTrue(flow.contains(".offseasonInvestmentRecoveryTeamBenefit"))
        XCTAssertTrue(presentation.contains("decision.type == .mediaOpportunity"))
        XCTAssertTrue(presentation.contains("resolver.resolve(.decisionImmediateEffect)"))
        XCTAssertTrue(presentation.contains("resolver.resolve(.decisionFollowUp)"))
        XCTAssertTrue(flow.contains("decisionTiming(for: decision, resolver: copyResolver)"))
        XCTAssertTrue(presentation.contains("decisionTiming(for: choice, resolver: resolver)"))

        let records = try XCTUnwrap(
            flow.range(of: "BaseballCard(title: ProCareerPresentation.teamName(state.team")
        )
        let legacy = try XCTUnwrap(flow.range(of: "ProSeasonSettlementCopy.legacy"))
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

    func testInvestmentBenefitCatalogsAreExplicitInKoEnJa() throws {
        let catalogURL = repositoryRoot().appendingPathComponent("apps/ios/Sources/Presentation/Localization/Localizable.xcstrings")
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
                    // "RNG"는 내부 용어라 화면에 두지 않는다(4차 검수). 한 번만 쓰고 결과를
                    // 다시 뽑지 않는다는 뜻은 그대로 담는다.
                    "ko": ["첫 부상", "1주", "한 번", "다시 뽑지"],
                    "en": ["first injury", "1 week", "once", "no reroll"],
                    "ja": ["最初の負傷", "1週間", "1回", "引き直"],
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
