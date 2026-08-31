import SwiftUI
import SimulationCore
import BaseballIOSDomain

extension HighSchoolSetupView {
    var styleStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupStyleTitle)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            GameCopyText(AppCopyKey.setupStyleDescription)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(presets, id: \.id) { preset in
                PresetRow(preset: preset, selected: preset.id == selectedPresetID) {
                    selectPreset(preset)
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
