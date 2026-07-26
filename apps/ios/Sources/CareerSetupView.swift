import SwiftUI
import SimulationCore

/// 새 커리어 시작 화면. 유료앱에서 앱을 처음 연 사용자가 보는 첫 장면이자
/// App Store 스크린샷 1번 후보다(계획 문서 §2.3).
struct CareerSetupView: View {
    let career: MobileCareerStore

    @State private var playerName = ""
    @State private var selectedPresetID = PitcherPresetCatalog.all.first?.id ?? ""
    @FocusState private var nameFocused: Bool

    private var presets: [PitcherPresetSnapshot] { PitcherPresetCatalog.all }
    private var selectedPreset: PitcherPresetSnapshot? {
        presets.first { $0.id == selectedPresetID } ?? presets.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .careerIntro,
                    eyebrow: "프로 커리어 시작",
                    title: "어떤 투수로 프로에 들어갈지 고르세요"
                )

                BaseballCard(title: "선수 이름") {
                    TextField(selectedPreset?.pitcher.name ?? "이름", text: $playerName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                }

                Text("투수 유형")
                    .font(.headline)
                    .padding(.top, 4)

                ForEach(presets, id: \.id) { preset in
                    PresetCard(
                        preset: preset,
                        selected: preset.id == selectedPresetID,
                        onSelect: { selectedPresetID = preset.id }
                    )
                }

                Text("유형은 시작 능력과 구종 구성만 정합니다. 이후 성장은 매주 고르는 훈련과 승부 결과로 갈립니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)

                Button {
                    nameFocused = false
                    if let selectedPreset {
                        career.startNewCareer(preset: selectedPreset, playerName: playerName)
                    }
                } label: {
                    Text("프로 지명 받기")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedPreset == nil)
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

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).font(.headline)
                        Text(preset.tagline).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 8) {
                    AbilityGaugeView(label: "구위", value: preset.pitcher.stuff, showsMeaning: false)
                    AbilityGaugeView(label: "제구", value: preset.pitcher.command, showsMeaning: false)
                    AbilityGaugeView(label: "변화구", value: preset.pitcher.movement, showsMeaning: false)
                    AbilityGaugeView(label: "체력", value: preset.pitcher.stamina, showsMeaning: false)
                }
                Label(preset.tradeoff, systemImage: "exclamationmark.triangle")
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
