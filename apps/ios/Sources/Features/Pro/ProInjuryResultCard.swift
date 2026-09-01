import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct ProInjuryResultCard: View {
    let event: ProInjuryEventSnapshot
    let onAcknowledge: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    private var planLabel: String {
        switch event.plan {
        case .developStuff:
            copyResolver.resolve(.weeklyDevelopStuffStarter)
        case .developMovement:
            copyResolver.resolve(.weeklyDevelopMovementTitle)
        case .developWeapon:
            "\(copyResolver.resolve(.weeklyDevelopStuffStarter)) · \(copyResolver.resolve(.weeklyDevelopMovementTitle))"
        case .refineCommand:
            copyResolver.resolve(.weeklyCommandTitle)
        case .buildStamina:
            copyResolver.resolve(.weeklyStaminaStarterTitle)
        case .recover:
            copyResolver.resolve(.weeklyRecoveryTitle)
        case .earnTrust:
            copyResolver.resolve(.weeklyTrustStarterTitle)
        }
    }

    var body: some View {
        BaseballCard(title: ProInjuryCopy.title(
            recoveryWeeks: event.recoveryWeeks,
            resolver: copyResolver
        ), tone: .warning) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: ProInjuryCopy.body(
                    season: event.season,
                    week: event.week,
                    resolver: copyResolver
                ))
                .font(.headline)
                Text(verbatim: ProInjuryCopy.plan(planLabel, resolver: copyResolver))
                .font(.footnote.weight(.semibold))
                Text(verbatim: ProInjuryCopy.evidence(
                    rawFatigue: event.rawFatigue,
                    effectiveFatigue: event.effectiveFatigue,
                    pitches: event.pitches,
                    resolver: copyResolver
                ))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
                Text(copyResolver.resolve(.injuryResultNextAction))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.warning)
                Button(copyResolver.resolve(.injuryResultAcknowledge), action: onAcknowledge)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("pro.injury.result.acknowledge")
            }
        }
        .accessibilityElement(children: .contain)
    }
}
