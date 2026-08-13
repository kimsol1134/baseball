import SwiftUI
import SimulationCore

/// 새 커리어 시작 화면. 유료앱에서 앱을 처음 연 사용자가 보는 첫 장면이자
/// App Store 스크린샷 1번 후보다(계획 문서 §2.3).
struct CareerSetupView: View {
    let career: MobileCareerStore

    @State private var playerName = ""
    @State private var selectedPresetID = PitcherPresetCatalog.all.first?.id ?? ""
    @FocusState private var nameFocused: Bool
    @Environment(\.gameCopyResolver) private var copyResolver

    private var presets: [PitcherPresetSnapshot] { PitcherPresetCatalog.all }
    private var selectedPreset: PitcherPresetSnapshot? {
        presets.first { $0.id == selectedPresetID } ?? presets.first
    }

    private var suggestedName: String {
        selectedPreset.map { copyResolver.resolve($0.defaultPlayerNameCopyToken) }
            ?? copyResolver.resolve(.careerSetupNamePlaceholder)
    }

    private var submittedPlayerName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? suggestedName
            : playerName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .careerIntro,
                    eyebrow: copyResolver.resolve(.careerSetupEyebrow),
                    title: copyResolver.resolve(.careerSetupTitle)
                )

                BaseballCard(title: copyResolver.resolve(.careerSetupPlayerName)) {
                    TextField(suggestedName, text: $playerName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                }

                Text(verbatim: copyResolver.resolve(.careerSetupPitcherType))
                    .font(.headline)
                    .padding(.top, 4)

                ForEach(presets, id: \.id) { preset in
                    PresetCard(
                        preset: preset,
                        selected: preset.id == selectedPresetID,
                        onSelect: { selectedPresetID = preset.id }
                    )
                }

                Text(verbatim: copyResolver.resolve(.careerSetupExplanation))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)

                PrimaryPill(
                    title: copyResolver.resolve(.careerSetupAction),
                    identifier: "pro.setup.start",
                    enabled: selectedPreset != nil
                ) {
                    nameFocused = false
                    if let selectedPreset {
                        career.startNewCareer(preset: selectedPreset, playerName: submittedPlayerName)
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct PresetCard: View {
    let preset: PitcherPresetSnapshot
    let selected: Bool
    let onSelect: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // 고교 온보딩과 같은 프리셋 아트. 같은 선택인데 여기만 게이지 표였다.
                if UIImage(named: "PresetArt-\(preset.id)") != nil {
                    Image("PresetArt-\(preset.id)")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 110, alignment: .top)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                        .accessibilityHidden(true)
                }
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: copyResolver.resolve(preset.nameCopyToken)).font(.headline)
                        Text(verbatim: copyResolver.resolve(preset.taglineCopyToken))
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
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
                }
                Label {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        ForEach(Array(preset.strengthCopyTokens.enumerated()), id: \.offset) { index, token in
                            if index > 0 {
                                Text(verbatim: "·")
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                            Text(verbatim: copyResolver.resolve(token))
                        }
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.positive)
                    .fixedSize(horizontal: false, vertical: true)
                Label {
                    Text(verbatim: copyResolver.resolve(preset.tradeoffCopyToken))
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
