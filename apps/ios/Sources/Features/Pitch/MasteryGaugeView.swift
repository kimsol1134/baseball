import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// Compact continuation for a base ability that has reached the visible 100 mark.
struct MasteryGaugeView: View {
    let ability: TalentAbility
    let baseInternalRating: Int
    let level: Int
    var progress: Int = 0
    var required: Int = 6

    @Environment(\.gameCopyResolver) private var copyResolver

    @ViewBuilder
    var body: some View {
        if level > 0 {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: copyResolver.resolve(ability.masteryCopyKey))
                        .font(.subheadline.weight(.semibold))
                    Text(verbatim: copyResolver.resolve(
                        .masteryLevel,
                        arguments: [.integer(level)]
                    ))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                    Spacer()
                    if baseInternalRating >= 80 {
                        Text(verbatim: copyResolver.resolve(.abilityBaseComplete))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BaseballTheme.positive)
                    }
                }
                ProgressView(value: Double(min(required, max(0, progress))), total: Double(max(1, required)))
                    .tint(BaseballTheme.milestone)
                // 진행도 한 줄만. "투구 공식의 담당 부분을 최대 N‰ 보정합니다"는 네 줄마다 반복되던
                // 설명이라 화면에서 빼고 접근성 라벨과 용어 사전(숙련)에만 남긴다(1.2.9).
                Text(verbatim: copyResolver.resolve(
                    .masteryProgress,
                    arguments: [.integer(min(required, max(0, progress))), .integer(max(1, required))]
                ))
                .font(BaseballType.annotation.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(copyResolver.resolve(
                .masteryAccessibility,
                arguments: [
                    .userText(copyResolver.resolve(ability.masteryCopyKey)),
                    .integer(level),
                    .integer(min(required, max(0, progress))),
                    .integer(max(1, required)),
                ]
            ))
            .accessibilityIdentifier("pro.mastery.\(ability.rawValue)")
        }
    }
}

private extension TalentAbility {
    var masteryCopyKey: GameCopyKey {
        switch self {
        case .stuff: MetaUICopyKey.masteryStuff.gameCopyKey
        case .command: MetaUICopyKey.masteryCommand.gameCopyKey
        case .movement: MetaUICopyKey.masteryMovement.gameCopyKey
        case .stamina: MetaUICopyKey.masteryStamina.gameCopyKey
        }
    }
}
