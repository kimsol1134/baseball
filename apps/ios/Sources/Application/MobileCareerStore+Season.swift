import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    func requestRole(_ role: ProRole) {
        guard let result, CareerDisplayRules.shouldOfferRoleRequest(result.snapshot) else { return }
        let beforeRevision = result.snapshot.revision
        let season = result.snapshot.season
        perform(summary: nil, cue: .success) {
            try engine.requestRole(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                requested: role
            ))
        }
        guard self.result?.snapshot.revision != beforeRevision else { return }
        CareerTelemetry.log(.proRoleRequested, [
            "requested": (role == .setup ? ProRole.longRelief : role).rawValue,
            "outcome": self.result?.snapshot.roleRequest?.outcome.rawValue ?? "",
            "season": season,
        ])
    }

    func applySeasonDecision(decisionID: String, choiceID: String) {
        guard let result,
              let decision = result.snapshot.pendingDecision,
              decision.id == decisionID,
              let choice = decision.choices.first(where: { $0.id == choiceID }) else { return }
        let beforeRevision = result.snapshot.revision
        let fanBefore = result.snapshot.journeyState?.reputation.fanSupport ?? 0
        perform(
            summary: decision.type == .mediaOpportunity ? nil : "\(decision.title) · \(choice.title) — \(choice.effect.summary)",
            cue: .success
        ) {
            try engine.applySeasonDecision(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                decisionID: decision.id,
                choiceID: choice.id
            ))
        }
        guard self.result?.snapshot.revision != beforeRevision,
              self.result?.snapshot.decisionHistory?.last?.decisionID == decision.id else { return }
        CareerTelemetry.log(.proSeasonDecisionSelected, Self.decisionAnalyticsProperties(
            decision: decision,
            choice: choice,
            cadence: ProCareerEngine.usesWeeklyDecisionRules(result.snapshot) ? "weekly3" : "legacy"
        ))
        if decision.type == .mediaOpportunity {
            CareerTelemetry.log(.proEndorsementSelected, Self.endorsementAnalyticsProperties(
                decision: decision,
                choice: choice,
                fanBefore: fanBefore
            ))
        }
    }

    /// 시즌 결정 국면인데 pending 결정이 없는 손상 저장을 사용자가 직접 푼다.
    ///
    /// 이 상태는 엔진의 모든 호출이 거부되는 함정이라, 화면의 복구 버튼이 유일한 출구다.
    /// 성공하면 주간 계획(마지막 주면 시즌 리뷰)으로 되돌아간다.
    @discardableResult
    func recoverStalledSeasonDecision() -> Bool {
        guard let result,
              result.snapshot.phase == .seasonDecision,
              result.snapshot.pendingDecision == nil else { return false }
        let recovered = perform(summary: "시즌 결정을 불러오지 못해 주간 일정으로 되돌렸습니다.", cue: .neutral) {
            try engine.recoverMissingSeasonDecision(.init(seed: result.nextSeed, state: result.snapshot))
        }
        if recovered {
            CareerTelemetry.log(.screenStallRecovered, ["context": "pro_season_decision_missing"])
        }
        return recovered
    }

    static func decisionAnalyticsProperties(
        decision: ProSeasonDecision,
        choice: ProSeasonDecisionChoice,
        cadence: String = "legacy"
    ) -> [String: Any] {
        [
            "decision_id": decision.id,
            "choice_id": choice.id,
            "season": decision.season,
            "week": decision.week,
            "cadence": cadence,
            "decision_type": decision.type.rawValue,
        ]
    }

    static func endorsementAnalyticsProperties(
        decision: ProSeasonDecision,
        choice: ProSeasonDecisionChoice,
        fanBefore: Int
    ) -> [String: Any] {
        let category = String(choice.id.split(separator: ".").last ?? "unknown")
        let income = choice.journeyEffect?.income ?? 0
        return [
            "season": decision.season,
            "choice": category,
            "fan_band": fanBand(fanBefore),
            "income_band": incomeBand(income),
        ]
    }

    static func fanBand(_ value: Int) -> String {
        switch value {
        case 0..<35: "0_34"
        case 35..<60: "35_59"
        case 60..<80: "60_79"
        default: "80_100"
        }
    }

    static func incomeBand(_ value: Int64) -> String {
        switch value {
        case 0: "none"
        case 1..<10_000_000: "under_10m"
        case 10_000_000..<30_000_000: "10m_29m"
        default: "30m_plus"
        }
    }

    static func fundsBand(_ value: Int64) -> String {
        switch value {
        case 0..<20_000_000: "0_19m"
        case 20_000_000..<40_000_000: "20m_39m"
        case 40_000_000..<50_000_000: "40m_49m"
        default: "50m_plus"
        }
    }

    func reviewSeason() {
        guard let result else { return }
        guard featureConfiguration.proCareerJourneyV1 || result.snapshot.journeyState == nil else { return }
        perform(summary: "시즌 기록을 통산 기록에 확정했습니다.", cue: .success) {
            try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
        }
    }

    func acknowledgeSettlement() {
        guard featureConfiguration.proCareerJourneyV1,
              let result,
              let settlement = result.snapshot.journeyState?.lastSettlement else { return }
        perform(summary: nil, cue: .success) {
            try engine.acknowledgeSettlement(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                expectedRevision: result.snapshot.revision,
                settlementID: settlement.id
            ))
        }
    }

    /// Seedless, revision-bound rookie signing. The candidate result is persisted by `perform`
    /// before this store publishes the new contract, finance, goal, or achievement state.
    @discardableResult
    func acceptContract(ambition: ProCareerAmbition?) -> Bool {
        guard let market = result?.snapshot.journeyState?.pendingContractMarket,
              market.kind == .rookie,
              let offer = market.offers.first else { return false }
        return acceptContract(
            marketID: market.id,
            offerID: offer.id,
            ambition: ambition
        )
    }

    @discardableResult
    func acceptContract(
        marketID: String,
        offerID: String,
        ambition: ProCareerAmbition?
    ) -> Bool {
        guard featureConfiguration.proCareerJourneyV1, let current = result else { return false }
        let market = current.snapshot.journeyState?.pendingContractMarket
        let offer = market?.offers.first(where: { $0.id == offerID })
        let accepted = perform(summary: "계약을 확정했습니다.", cue: .success) {
            try engine.acceptContract(.init(
                seed: current.nextSeed,
                state: current.snapshot,
                expectedRevision: current.snapshot.revision,
                marketID: marketID,
                offerID: offerID,
                ambition: ambition
            ))
        }
        guard accepted,
              let updated = result?.snapshot,
              updated.revision == current.snapshot.revision + 1 else { return accepted }
        CareerTelemetry.log(.proContractSigned, [
            "market_kind": market?.kind.rawValue ?? "rookie",
            "offer_kind": offer?.contractKind.rawValue ?? "unknown",
            "outlook": offer?.outlook.rawValue ?? "unknown",
            "role": offer?.rolePromise.rawValue ?? updated.role.rawValue,
            "transfer": offer?.teamID != current.snapshot.team.id,
            "ambition_selected": ambition != nil,
            "years": offer?.years ?? 0,
            "signing_bonus_band": offer.map { CareerDisplayRules.signingBonusBand(for: $0) } ?? "none",
            "interest": offer?.interest?.level.rawValue ?? "none",
        ])
        return accepted
    }

    @discardableResult
    func requestContractCounter(kind: ProContractCounterKind) -> Bool {
        guard featureConfiguration.proCareerJourneyV1, let current = result else { return false }
        guard CareerDisplayRules.canRequestContractCounter(current.snapshot) else { return false }
        if kind == .extraYear, !CareerDisplayRules.canRequestExtraYear(current.snapshot) { return false }
        let requested = perform(summary: nil, cue: .success) {
            try engine.requestContractCounter(.init(
                seed: current.nextSeed,
                state: current.snapshot,
                expectedRevision: current.snapshot.revision,
                kind: kind
            ))
        }
        guard requested,
              let counter = result?.snapshot.journeyState?.pendingContractMarket?.counterOffer else { return requested }
        CareerTelemetry.log(.proContractCounterRequested, [
            "kind": kind.rawValue,
            "accepted": counter.accepted,
        ])
        return requested
    }

    /// Investment selection is persisted before the store publishes the new season. The event
    /// contains only stable categories and a coarse funds band, never raw money or player text.
    @discardableResult
    func chooseInvestment(
        investment: ProOffseasonInvestment,
        focus: ProDevelopmentFocus? = nil
    ) -> Bool {
        guard let current = result,
              let journey = current.snapshot.journeyState else { return false }
        let cost = ProFinanceRules.investmentCost(for: investment)
        let affordable = journey.finances.availableFunds >= cost
        let selected = perform(summary: nil, cue: .success) {
            try engine.chooseInvestment(.init(
                seed: current.nextSeed,
                state: current.snapshot,
                expectedRevision: current.snapshot.revision,
                investment: investment,
                focus: focus
            ))
        }
        guard selected else { return false }
        CareerTelemetry.log(.proOffseasonInvestmentSelected, [
            "season": current.snapshot.season + 1,
            "investment": investment.rawValue,
            "affordable": affordable,
            "funds_band": Self.fundsBand(journey.finances.availableFunds),
        ])
        return true
    }

    /// Compatibility entry point for the pre-Wave 5 store surface. It remains an equal
    /// no-investment choice, while the product UI calls the full parameterized boundary above.
    func chooseInvestment() {
        _ = chooseInvestment(investment: .none)
    }

    func continueCareer() { chooseOffseason(.continueCareer) }

    /// 오프시즌 네 갈래. 코어는 네 가지를 전부 받는데 화면이 잔류 하나만 냈다.
    ///
    /// 그래서 군 복무와 FA 서사가 게임에 존재하지 않았고, 커리어 상한에 도달해
    /// `retirementDecision`으로 넘어가면 화면이 아예 없어 **커리어가 그 자리에서 막혔다.**
    func chooseOffseason(_ decision: OffseasonDecision) {
        guard let result else { return }
        let summary: String
        switch decision {
        case .continueCareer: summary = "현재 구단에서 다음 시즌을 준비합니다."
        case .militaryService: summary = "두 시즌의 군 복무를 마치고 돌아옵니다."
        case .freeAgency: summary = "FA를 신청했습니다."
        case .retire: summary = "은퇴를 선택했습니다."
        }
        perform(summary: summary, cue: decision == .retire ? .neutral : .success) {
            try engine.chooseOffseason(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                decision: decision,
                expectedRevision: result.snapshot.journeyState == nil ? nil : result.snapshot.revision
            ))
        }
    }

    /// FA 신청 자격. 코어와 같은 식(1군 등록 6년)을 쓴다 — 화면이 못 누를 버튼을 내면
    /// 사용자는 오류 메시지로 규칙을 배우게 된다.
    static func freeAgencyService(_ state: ProCareerSnapshot) -> Int {
        if state.journeyState != nil {
            return state.serviceYears
        }
        return state.serviceYears + (state.level == .major ? 1 : 0)
    }

    func acknowledgeGains() {
        pendingGains = []
    }

    /// Dismisses only the current-session explanation. The injury itself stays in the saved
    /// career state; the acknowledgement ID prevents it from returning after relaunch.
    func acknowledgeInjuryEvent() {
        guard let event = pendingInjuryEvent, let result else { return }
        guard persist(
            result: result,
            gameResume: gameResume,
            pendingInjuryEvent: nil,
            preservePendingInjuryEvent: false,
            acknowledgedInjuryEventID: event.stableID
        ) else { return }
        updatePersisted {
            $0.pendingInjuryEvent = nil
            $0.acknowledgedInjuryEventID = event.stableID
        }
        CareerTelemetry.log(.injuryResultAcknowledged, [
            "mode": "pro",
            "cause": event.cause.rawValue,
            "recovery_weeks": event.recoveryWeeks,
        ])
    }
}
