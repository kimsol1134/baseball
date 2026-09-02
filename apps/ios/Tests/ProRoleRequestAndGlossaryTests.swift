import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain
import BaseballIOSPersistence

@MainActor
final class ProRoleRequestAndGlossaryTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testSpringCampStoreRequestSetsStarterAndLogsAnalyticsContract() throws {
        var result = try springCamp(seed: 9_301)
        result = try stamped(result, managerTrust: 50, stamina: 60)
        XCTAssertTrue(CareerDisplayRules.shouldOfferRoleRequest(result.snapshot))
        XCTAssertEqual(ProRoleRequestCopy.accessibilityID(for: .starter), "pro.roleRequest.starter")
        XCTAssertEqual(ProRoleRequestCopy.accessibilityID(for: .longRelief), "pro.roleRequest.long_relief")
        XCTAssertEqual(ProRoleRequestCopy.accessibilityID(for: .closer), "pro.roleRequest.closer")

        let sync = isolatedSync("role-request-accept")
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        store.updatePersisted { $0.result = result }
        store.loadState = .ready

        let seed = store.result?.nextSeed
        store.requestRole(.starter)
        XCTAssertEqual(store.result?.nextSeed, seed)
        XCTAssertEqual(store.state?.rolePreference, .starter)
        XCTAssertEqual(store.state?.roleRequest?.outcome, .accepted)
        XCTAssertEqual(GameAnalytics.Event.proRoleRequested.rawValue, "pro_role_requested")

        let state = try XCTUnwrap(store.state)
        let renderer = ImageRenderer(content:
            ScrollView {
                WeeklyPlanView(career: store, state: state)
                    .padding()
            }
            .frame(width: 390, height: 920)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 4_000)
    }

    func testOffseasonRolePromiseHidesTheCard() throws {
        var result = try springCamp(seed: 9_302)
        let contract = ProContractSnapshot(
            yearsRemaining: 2,
            annualSalary: 120_000_000,
            rolePromise: .starter,
            kind: .renewalLong
        )
        result = try stamped(result, contract: contract)
        XCTAssertFalse(CareerDisplayRules.shouldOfferRoleRequest(result.snapshot))
    }

    func testAssignedStarterOutlookIsLikelyForSeasonOneRookie() throws {
        let result = try springCamp(seed: 9_304)
        XCTAssertEqual(result.snapshot.season, 1)
        XCTAssertEqual(result.snapshot.role, .starter)
        XCTAssertLessThan(result.snapshot.managerTrust, 45)
        let evaluation = CareerDisplayRules.roleRequestEvaluation(
            state: result.snapshot,
            requested: .starter
        )
        XCTAssertEqual(evaluation.outcome, .accepted)
        XCTAssertEqual(evaluation.outlook, .likely)
        let korean = GameCopyResolver(language: .korean, policy: .releaseSafe)
        XCTAssertEqual(ProRoleRequestCopy.outlook(evaluation.outlook, resolver: korean), "유력")
        XCTAssertEqual(
            ProRoleRequestCopy.condition(
                role: .starter,
                evaluation: evaluation,
                state: result.snapshot,
                resolver: korean
            ),
            korean.resolve(ProUICopyKey.roleRequestConditionAssigned)
        )
    }

    func testWeekSpanLabelCoversSpringCampSingleWeekAndRange() {
        let korean = GameCopyResolver(language: .korean, policy: .releaseSafe)
        let english = GameCopyResolver(language: .english, policy: .releaseSafe)
        let japanese = GameCopyResolver(language: .japanese, policy: .releaseSafe)
        XCTAssertEqual(
            ProCareerPresentation.weekSpanLabel(beforeWeek: 0, afterWeek: 0, resolver: korean),
            "스프링캠프"
        )
        XCTAssertEqual(
            ProCareerPresentation.weekSpanLabel(beforeWeek: 0, afterWeek: 0, resolver: english),
            "Spring camp"
        )
        XCTAssertEqual(
            ProCareerPresentation.weekSpanLabel(beforeWeek: 0, afterWeek: 0, resolver: japanese),
            "スプリングキャンプ"
        )
        XCTAssertEqual(
            ProCareerPresentation.weekSpanLabel(beforeWeek: 2, afterWeek: 3, resolver: korean),
            "3주차"
        )
        XCTAssertEqual(
            ProCareerPresentation.weekSpanLabel(beforeWeek: 0, afterWeek: 3, resolver: korean),
            "1~3주차"
        )
        let inverted = ProCareerPresentation.weekSpanLabel(
            beforeWeek: 4,
            afterWeek: 0,
            resolver: korean
        )
        XCTAssertEqual(inverted, "스프링캠프")
        XCTAssertFalse(inverted.contains("~"))
        let stillAtWeek = ProCareerPresentation.weekSpanLabel(
            beforeWeek: 3,
            afterWeek: 3,
            resolver: korean
        )
        XCTAssertEqual(stillAtWeek, "3주차")
        XCTAssertFalse(stillAtWeek.contains("~"))
    }

    func testProgressSummaryAfterRoleRequestUsesSpringCampLabel() throws {
        var result = try springCamp(seed: 9_305)
        result = try stamped(result, managerTrust: 42, stamina: 40)
        let sync = isolatedSync("role-request-summary")
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync)
        store.updatePersisted { $0.result = result }
        store.loadState = .ready
        store.requestRole(.starter)
        let summary = try XCTUnwrap(store.lastSummary)
        XCTAssertTrue(summary.hasPrefix("스프링캠프"), summary)
        XCTAssertFalse(summary.contains("1~0주차"), summary)
        XCTAssertFalse(
            summary.range(of: #"\d+~\d+주차"#, options: .regularExpression) != nil
                && summary.hasPrefix("1~0"),
            summary
        )
    }

    func testProWeeklyGrowthDoesNotResolvePrologueAbilityMeaningKeys() throws {
        let flow = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/CareerFlowView.swift")
        XCTAssertTrue(flow.contains("stageContext: .pro"))
        XCTAssertFalse(flow.contains("prologue.ability.meaning"))
        let growth = try IOSSourceScan.read("apps/ios/Sources/Features/Shell/GrowthCelebrationView.swift")
        XCTAssertFalse(growth.contains("prologue.ability.meaning"))
        for value in [20, 33, 38, 43, 47, 50, 55, 65, 75] {
            let key = MetaPresentation.ratingMeaningKey(value, context: .pro)
            XCTAssertFalse(
                key.rawValue.hasPrefix("prologue.ability.meaning."),
                "pro weekly next-stage used \(key.rawValue) for \(value)"
            )
        }
        let korean = GameCopyResolver(language: .korean, policy: .releaseSafe)
        XCTAssertEqual(
            MetaPresentation.ratingMeaning(38, context: .pro, resolver: korean),
            "보직 경쟁"
        )
        XCTAssertEqual(
            MetaPresentation.ratingMeaning(38, context: .highSchool, resolver: korean),
            "고교 주전 경쟁"
        )
    }

    func testV8CareerDoesNotOfferRoleRequest() throws {
        var result = try engine.start(startParams(seed: "9303", proRulesVersion: 8))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        XCTAssertFalse(CareerDisplayRules.shouldOfferRoleRequest(result.snapshot))
        XCTAssertNil(result.snapshot.roleRequest)
    }

    func testDecisionChoicePutsEffectSummaryAboveDetailInSource() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/ProSeasonDecisionView.swift")
        let effect = try XCTUnwrap(source.range(of: "combinedEffect("))
        let detail = try XCTUnwrap(source.range(of: "choiceDetail(choice"))
        XCTAssertLessThan(effect.lowerBound, detail.lowerBound)
    }

    func testTrainingFocusPutsGrowthSummaryAboveDetailInSource() throws {
        let source = try IOSSourceScan.read("apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift")
        let growth = try XCTUnwrap(source.range(of: "growthSummary"))
        let detail = try XCTUnwrap(source.range(of: "text: detail"))
        XCTAssertLessThan(growth.lowerBound, detail.lowerBound)
    }

    func testGlossaryTextIsOutsideParentChoiceButtons() throws {
        let decision = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/ProSeasonDecisionView.swift")
        let choiceButton = try XCTUnwrap(
            decision.range(of: "Button { pendingChoice = choice }")
        )
        let choiceID = try XCTUnwrap(
            decision.range(of: ".accessibilityIdentifier(\"pro.seasonDecision.choice.\\(choice.id)\")")
        )
        let nestedChoice = decision[choiceButton.lowerBound..<choiceID.upperBound]
        XCTAssertFalse(
            nestedChoice.contains("GlossaryText("),
            "choice-card GlossaryText must sit outside the select Button"
        )

        let role = try IOSSourceScan.read("apps/ios/Sources/Features/Pro/ProWeeklyPlanView.swift")
        XCTAssertTrue(
            role.contains(".animation(nil, value: state.roleRequest != nil)"),
            "role-request card must leave the hierarchy without a ghosted collapse"
        )
        XCTAssertTrue(role.contains(".transition(.identity)"))
        let roleButton = try XCTUnwrap(role.range(of: "career.requestRole(role)"))
        let roleTail = role[roleButton.lowerBound...]
        let roleStyle = try XCTUnwrap(roleTail.range(of: ".buttonStyle(.plain)"))
        XCTAssertFalse(
            role[roleButton.lowerBound..<roleStyle.upperBound].contains("GlossaryText("),
            "role-request GlossaryText must sit outside the select Button"
        )

        let training = try IOSSourceScan.read("apps/ios/Sources/Features/HighSchool/HighSchoolTrainingViews.swift")
        let focusButton = try XCTUnwrap(training.range(of: "Button { selection = option }"))
        let focusID = try XCTUnwrap(
            training.range(of: ".accessibilityIdentifier(\"hs.focus.\\(option.rawValue)\")")
        )
        XCTAssertFalse(
            training[focusButton.lowerBound..<focusID.upperBound].contains("GlossaryText("),
            "training-card GlossaryText must sit outside the select Button"
        )
    }

    func testGlossaryMatchesFirstKoreanManagerFaithAndIgnoresLaterRepeats() {
        let names = ["manager-faith": "감독의 믿음", "stuff": "구위"]
        let text = "감독의 믿음이 얇아졌습니다. 구위는 살아 있고 감독의 믿음은 다시 쌓을 수 있습니다."
        let matches = GlossaryCatalog.matches(in: text, names: names)
        XCTAssertEqual(matches.map(\.id), ["manager-faith", "stuff"])
        XCTAssertEqual(matches.first?.location, 0)
        XCTAssertEqual(GlossaryCatalog.terms.count, 20)
        XCTAssertEqual(Set(GlossaryCatalog.terms.map(\.id)).count, 20)
    }

    func testGlossaryLatinTermsStayWholeWords() {
        let names = ["era": "ERA", "qs": "QS"]
        let matches = GlossaryCatalog.matches(in: "OPERA night and a QS start", names: names)
        XCTAssertEqual(matches.map(\.id), ["qs"])
    }

    private func springCamp(seed: UInt64) throws -> ProCareerResult {
        try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "보직지원",
            seed: seed,
            engine: engine
        )
    }

    private func stamped(
        _ result: ProCareerResult,
        managerTrust: Int? = nil,
        stamina: Int? = nil,
        contract: ProContractSnapshot? = nil
    ) throws -> ProCareerResult {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        if let managerTrust { object["managerTrust"] = managerTrust }
        if let stamina {
            var pitcher = try XCTUnwrap(object["pitcher"] as? [String: Any])
            pitcher["stamina"] = stamina
            object["pitcher"] = pitcher
        }
        if let contract {
            object["contract"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(contract))
        }
        object["commitment"] = ""
        let unsigned = try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let signed = engine.resignFixtureForTesting(unsigned)
        return ProCareerResult(snapshot: signed, nextSeed: result.nextSeed, events: result.events)
    }

    private func startParams(seed: String, proRulesVersion: Int?) -> StartProCareerParams {
        .init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: .init(id: "v8", name: "레거시", stuff: 58, command: 55, movement: 56, stamina: 57),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3라운드",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: "2군 선발",
                summary: "지명"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-09-02"),
            sourceFanInterest: nil,
            startingRepertoire: nil,
            repertoireRulesVersion: nil,
            pitchLearningProject: nil,
            proRulesVersion: proRulesVersion
        )
    }

    private func isolatedSync(_ prefix: String) -> SaveSync {
        SaveSync(key: "\(prefix)-\(UUID().uuidString).json")
    }
}
