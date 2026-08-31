import SwiftUI
import SimulationCore
import BaseballIOSDomain

extension HighSchoolSetupView {
    private func repertoireDetailKey(_ pitch: PitchType) -> GameCopyKey {
        switch pitch {
        case .slider: AppCopyKey.setupRepertoireSliderDetail
        case .curveball: AppCopyKey.setupRepertoireCurveballDetail
        case .changeup: AppCopyKey.setupRepertoireChangeupDetail
        case .fourSeam: AppCopyKey.setupRepertoireFourSeam
        }
    }

    // MARK: - 구종 구성

    var repertoireStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupRepertoireTitle)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            GameCopyText(AppCopyKey.setupRepertoireDescription)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupRepertoireFourSeam), tone: .raised) {
                Text(PitchCopy.localized(.fourSeam, resolver: copyResolver))
                    .font(.headline)
                    .foregroundStyle(BaseballTheme.textPrimary)
            }

            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupRepertoireLearning)) {
                VStack(alignment: .leading, spacing: 8) {
                    GameCopyText(AppCopyKey.setupRepertoireLearningHint)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    ForEach([PitchType.slider, .curveball, .changeup], id: \.self) { pitch in
                        Button {
                            learningPitch = pitch
                            if primaryPitch == pitch { primaryPitch = .fourSeam }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(PitchCopy.localized(pitch, resolver: copyResolver))
                                        .font(.subheadline.weight(.bold))
                                    GameCopyText(repertoireDetailKey(pitch))
                                        .font(.caption)
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let velocity = selectedPreset?.pitcher.profile(for: pitch)?.velocityTenthsKPH {
                                        Text(GameFormatters.velocity(
                                            tenthsKPH: velocity,
                                            language: copyResolver.language
                                        ))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(BaseballTheme.textTertiary)
                                    }
                                }
                                Spacer()
                                Image(systemName: learningPitch == pitch ? "book.closed.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(learningPitch == pitch ? BaseballTheme.milestone : BaseballTheme.positive)
                            }
                            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                            .padding(.horizontal, 12)
                            .background(
                                learningPitch == pitch ? BaseballTheme.milestone.opacity(0.14) : BaseballTheme.surfaceRaised,
                                in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("setup.pitch.\(pitch.rawValue)")
                        .accessibilityAddTraits(learningPitch == pitch ? .isSelected : [])
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("setup.pitch.learning")

            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupRepertoirePrimary)) {
                VStack(alignment: .leading, spacing: 8) {
                    GameCopyText(AppCopyKey.setupRepertoirePrimaryHint)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    ForEach([PitchType.fourSeam] + startingRepertoire.readyBreakingPitches, id: \.self) { pitch in
                        Button { primaryPitch = pitch } label: {
                            HStack {
                                Text(PitchCopy.localized(pitch, resolver: copyResolver))
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Image(systemName: primaryPitch == pitch ? "star.circle.fill" : "circle")
                                    .foregroundStyle(primaryPitch == pitch ? BaseballTheme.selection : BaseballTheme.border)
                            }
                            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("setup.pitch.primary.\(pitch.rawValue)")
                        .accessibilityAddTraits(primaryPitch == pitch ? .isSelected : [])
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("setup.pitch.primary")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup.repertoire")
    }

}
