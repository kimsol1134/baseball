import SwiftUI
import UIKit
import SimulationCore
import BaseballIOSDomain

struct PresetRow: View {
    let preset: PitcherPresetSnapshot
    let selected: Bool
    let onSelect: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // 스타일 아트 — 3년을 함께할 몸을 고르는 화면이 표(스탯)로만 말하면
                // 첫인상 구간을 통째로 버리는 것이다. 이미지가 없으면 지금 그대로.
                if UIImage(named: "PresetArt-\(preset.id)") != nil {
                    // 가운데 크롭은 와인드업의 머리를 잘랐다(실기기 피드백) —
                    // 위 정렬 밴드로 인물의 상단을 지킨다.
                    Image("PresetArt-\(preset.id)")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        GameCopyText(coreToken: preset.nameCopyToken).font(.headline)
                        GameCopyText(coreToken: preset.taglineCopyToken)
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    Spacer()
                }
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatStuff),
                    value: preset.pitcher.stuff,
                    showsMeaning: false
                )
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatCommand),
                    value: preset.pitcher.command,
                    showsMeaning: false
                )
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatMovement),
                    value: preset.pitcher.movement,
                    showsMeaning: false
                )
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatStamina),
                    value: preset.pitcher.stamina,
                    showsMeaning: false
                )
                Label {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        ForEach(Array(preset.strengthCopyTokens.enumerated()), id: \.offset) { index, token in
                            if index > 0 {
                                Text(verbatim: "·")
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                            GameCopyText(coreToken: token)
                        }
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.positive)
                    .fixedSize(horizontal: false, vertical: true)
                Label {
                    GameCopyText(coreToken: preset.tradeoffCopyToken)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(BaseballMetrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                    .stroke(selected ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hs.preset.\(preset.id)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct KarmaRow: View {
    let karma: KarmaID
    let selected: Bool
    /// 이미 2개를 골랐는가. 선택된 행은 계속 눌러서 해제할 수 있어야 하므로 별도로 받는다.
    var atCapacity: Bool = false
    let onToggle: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    private var locked: Bool { atCapacity && !selected }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? BaseballTheme.warning : BaseballTheme.border.opacity(locked ? 0.4 : 1))
                VStack(alignment: .leading, spacing: 2) {
                    let copy = HighSchoolSetupView.localizedKarmaCopy(karma, resolver: copyResolver)
                    GameCopyText(verbatim: copy.title).font(.subheadline.weight(.bold))
                    GameCopyText(verbatim: copy.detail)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                GameCopyText(
                    AppCopyKey.setupKarmaReward,
                    arguments: [.integer(karma.rewardPermille / 10)]
                )
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? BaseballTheme.warning.opacity(0.12) : BaseballTheme.surface,
                in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(selected ? BaseballTheme.warning : BaseballTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(locked ? copyResolver.resolve(AppCopyKey.setupKarmaCapacityHint) : "")
    }
}
