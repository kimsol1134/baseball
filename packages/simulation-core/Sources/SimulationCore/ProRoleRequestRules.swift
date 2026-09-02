import Foundation

/// Deterministic spring-camp role request. No RNG — thresholds and contract kind only.
public enum ProRoleRequestRules {
    public static let requestableRoles: [ProRole] = [.starter, .longRelief, .closer]
    public static let reviewWeek = 6
    public static let starterAcceptStamina = 55
    public static let starterAcceptTrust = 45
    public static let starterConditionalStamina = 48
    public static let closerAcceptStuff = 58
    public static let closerAcceptCatcherTrust = 45
    public static let closerConditionalStuff = 52

    public static func shouldOffer(_ state: ProCareerSnapshot) -> Bool {
        guard ProCareerEngine.usesWeeklyDecisionRules(state) else { return false }
        guard state.phase == .weeklyPlan else { return false }
        guard state.week == 0 else { return false }
        guard (state.seasonSegment ?? .springCamp) == .springCamp else { return false }
        if let request = state.roleRequest, request.season == state.season { return false }
        if hasBindingOffseasonRolePromise(state) { return false }
        return true
    }

    public static func hasBindingOffseasonRolePromise(_ state: ProCareerSnapshot) -> Bool {
        switch state.contract?.kind {
        case .renewalLong, .proveIt, .freeAgent: true
        case .rookie, nil: false
        }
    }

    /// Same trust bands `planWeek` uses. Duplicated so the weekly RNG stream is untouched.
    public static func trustAssignedRole(for state: ProCareerSnapshot) -> ProRole {
        if state.level == .major {
            return state.managerTrust >= 74 ? .starter : state.managerTrust >= 62 ? .longRelief : .setup
        }
        return state.managerTrust >= 52 ? .starter : .longRelief
    }

    public static func isAlreadyAssigned(_ requested: ProRole, state: ProCareerSnapshot) -> Bool {
        let role = normalized(requested)
        return role == normalized(state.role) || role == normalized(trustAssignedRole(for: state))
    }

    public static func evaluate(state: ProCareerSnapshot, requested: ProRole) -> ProRoleRequestEvaluation {
        let role = normalized(requested)
        if isAlreadyAssigned(role, state: state) {
            return evaluation(role, .accepted)
        }
        switch role {
        case .longRelief, .setup:
            return evaluation(role, .accepted)
        case .starter:
            let trustOK = state.season == 1 || state.managerTrust >= starterAcceptTrust
            if state.pitcher.stamina >= starterAcceptStamina, trustOK {
                return evaluation(role, .accepted)
            }
            if state.pitcher.stamina >= starterConditionalStamina {
                return evaluation(role, .conditional)
            }
            return evaluation(role, .rejected, newsKey: "content.pro-news.role-request.rejected.starter")
        case .closer:
            let trustOK = state.season == 1 || state.catcherTrust >= closerAcceptCatcherTrust
            if state.pitcher.stuff >= closerAcceptStuff, trustOK {
                return evaluation(role, .accepted)
            }
            if state.pitcher.stuff >= closerConditionalStuff {
                return evaluation(role, .conditional)
            }
            return evaluation(role, .rejected, newsKey: "content.pro-news.role-request.rejected.closer")
        }
    }

    private static func normalized(_ role: ProRole) -> ProRole {
        role == .setup ? .longRelief : role
    }

    public static func pendingConditionalReview(_ state: ProCareerSnapshot, week: Int) -> Bool {
        guard ProCareerEngine.usesWeeklyDecisionRules(state),
              let request = state.roleRequest,
              request.season == state.season,
              request.outcome == .conditional,
              week >= request.reviewWeek else { return false }
        let alreadyReviewed = (state.decisionHistory ?? []).contains {
            $0.season == state.season && $0.type == .roleMeeting && $0.week >= request.reviewWeek
        }
        return !alreadyReviewed
    }

    private static func evaluation(
        _ requested: ProRole,
        _ outcome: ProRoleRequestOutcome,
        newsKey: String? = nil
    ) -> ProRoleRequestEvaluation {
        let outlook: ProRoleRequestOutlook = switch outcome {
        case .accepted: .likely
        case .conditional: .conditional
        case .rejected: .difficult
        }
        return ProRoleRequestEvaluation(
            requested: requested,
            outcome: outcome,
            outlook: outlook,
            reviewWeek: outcome == .conditional ? reviewWeek : 0,
            rejectionNewsKey: newsKey
        )
    }
}
