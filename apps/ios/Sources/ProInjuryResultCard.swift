import SwiftUI
import SimulationCore

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
        BaseballCard(title: copyResolver.resolve(
            .injuryResultTitle,
            arguments: [.integer(event.recoveryWeeks)]
        ), tone: .warning) {
            VStack(alignment: .leading, spacing: 8) {
                Text(copyResolver.resolve(.injuryResultBody, arguments: [
                    .integer(event.season),
                    .integer(event.week),
                ]))
                .font(.headline)
                Text(copyResolver.resolve(
                    .injuryResultPlan,
                    arguments: [.userText(planLabel)]
                ))
                .font(.footnote.weight(.semibold))
                Text(copyResolver.resolve(.injuryResultEvidence, arguments: [
                    .integer(event.rawFatigue),
                    .integer(event.effectiveFatigue),
                    .integer(event.pitches),
                ]))
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
