import SwiftUI
import SimulationCore
import BaseballIOSDomain

extension HighSchoolSetupView {
    var styleStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupStyleTitle)
                .setupQuestionStyle()

            GameCopyText(AppCopyKey.setupStyleDescription)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(presets, id: \.id) { preset in
                PresetRow(preset: preset, selected: preset.id == selectedPresetID) {
                    selectPreset(preset)
                }
            }

            // 투구 손. 플래툰 판정(같은 손 타자 상대 우위)이 실제로 이 값을 읽는다 —
            // "주인공 어느 손 투수인가요? 설정도 할 수 있었으면" 리뷰에 대한 응답.
            VStack(alignment: .leading, spacing: 6) {
                GameCopyText(AppCopyKey.setupHandTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textPrimary)
                Picker(
                    copyResolver.resolve(AppCopyKey.setupHandTitle),
                    selection: $throwingHand
                ) {
                    Text(copyResolver.resolve(AppCopyKey.handRight)).tag(ThrowingHand.right)
                    Text(copyResolver.resolve(AppCopyKey.handLeft)).tag(ThrowingHand.left)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("hs.setup.throwingHand")
                GameCopyText(AppCopyKey.setupHandDetail)
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isRebirth {
                ProgressiveDisclosure(
                    contentID: "hs.setup.repertoire",
                    title: copyResolver.resolve(AppCopyKey.setupRepertoireTitle),
                    summary: PitchCopy.localized(learningPitch, resolver: copyResolver)
                ) {
                    repertoireStep
                }
            }
        }
    }

    private func selectPreset(_ preset: PitcherPresetSnapshot) {
        selectedPresetID = preset.id
        let recommended = CareerDisplayRules.recommendedRepertoire(presetID: preset.id)
        learningPitch = recommended.learningPitch
        primaryPitch = recommended.primaryPitch
    }
}
