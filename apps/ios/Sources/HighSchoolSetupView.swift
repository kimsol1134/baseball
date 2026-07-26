import SwiftUI
import SimulationCore

/// 고교 커리어 시작 화면. 2회차 이후에는 계승분과 카르마 선택이 함께 나온다.
struct HighSchoolSetupView: View {
    let career: HighSchoolCareerStore

    @State private var playerName = ""
    @State private var selectedPresetID = PitcherPresetCatalog.all.first?.id ?? ""
    @State private var selectedKarmas: Set<KarmaID> = []
    @State private var harshness: DifficultyLevel = .standard
    @FocusState private var nameFocused: Bool

    private var presets: [PitcherPresetSnapshot] { PitcherPresetCatalog.all }
    private var selectedPreset: PitcherPresetSnapshot? {
        presets.first { $0.id == selectedPresetID } ?? presets.first
    }
    private var isRebirth: Bool { career.inheritance.lifeNumber > 1 }

    /// 카르마 보상 합계(‰). 자발적 핸디캡이 다음 생 계승분을 키운다.
    private var rewardPermille: Int {
        selectedKarmas.reduce(0) { $0 + $1.rewardPermille }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    art: .careerIntro,
                    eyebrow: isRebirth ? "\(career.inheritance.lifeNumber)번째 생" : "고교 커리어 시작",
                    title: isRebirth ? "다시 한 번, 고교 1학년부터" : "어떤 투수로 시작할지 고르세요"
                )

                if isRebirth {
                    BaseballCard(title: "가져온 것", tone: .milestone) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("영혼 \(career.inheritance.soulPoints)").font(.subheadline.bold().monospacedDigit())
                            if career.inheritance.memories.isEmpty {
                                Text("가져온 기억이 없습니다.").font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            } else {
                                ForEach(career.inheritance.memories, id: \.self) { memory in
                                    let copy = HighSchoolPresentation.memory(memory)
                                    Text("· \(copy.title)").font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                                }
                            }
                        }
                    }
                }

                BaseballCard(title: "선수 이름") {
                    TextField(selectedPreset?.pitcher.name ?? "이름", text: $playerName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                }

                Text("투수 유형").font(.headline)
                ForEach(presets, id: \.id) { preset in
                    PresetRow(preset: preset, selected: preset.id == selectedPresetID) {
                        selectedPresetID = preset.id
                    }
                }

                BaseballCard(title: "이번 생의 난이도") {
                    HStack(spacing: 6) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                            Button { harshness = level } label: {
                                Text(Self.difficultyLabel(level))
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                            }
                            .buttonStyle(.plain)
                            .background(
                                harshness == level ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(harshness == level ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                            lineWidth: harshness == level ? 2 : 1)
                            }
                            .accessibilityAddTraits(harshness == level ? .isSelected : [])
                        }
                    }
                }

                Text("짊어질 것").font(.headline)
                Text("고르면 이번 생이 어려워지는 대신 다음 생에 더 많이 남습니다. 지금 +\(rewardPermille / 10)%")
                    .font(.footnote)
                    .foregroundStyle(rewardPermille > 0 ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                ForEach(KarmaID.allCases, id: \.self) { karma in
                    KarmaRow(
                        karma: karma,
                        selected: selectedKarmas.contains(karma),
                        onToggle: {
                            if selectedKarmas.contains(karma) { selectedKarmas.remove(karma) }
                            else { selectedKarmas.insert(karma) }
                        }
                    )
                }

                PrimaryButton(title: isRebirth ? "다시 태어나기" : "고교 1학년 시작", identifier: "hs.start") {
                    nameFocused = false
                    if let selectedPreset {
                        career.startCareer(
                            preset: selectedPreset,
                            playerName: playerName,
                            difficulty: CareerDifficultySnapshot(careerHarshness: harshness),
                            karmas: Array(selectedKarmas).sorted { $0.rawValue < $1.rawValue }
                        )
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
    }

    static func difficultyLabel(_ level: DifficultyLevel) -> String {
        switch level {
        case .relaxed: "여유롭게"
        case .standard: "보통"
        case .challenging: "혹독하게"
        }
    }
}

private struct PresetRow: View {
    let preset: PitcherPresetSnapshot
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name).font(.headline)
                        Text(preset.tagline).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    Spacer()
                }
                AbilityGaugeView(label: "구위", value: preset.pitcher.stuff, showsMeaning: false)
                AbilityGaugeView(label: "제구", value: preset.pitcher.command, showsMeaning: false)
                AbilityGaugeView(label: "변화구", value: preset.pitcher.movement, showsMeaning: false)
                AbilityGaugeView(label: "체력", value: preset.pitcher.stamina, showsMeaning: false)
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

private struct KarmaRow: View {
    let karma: KarmaID
    let selected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? BaseballTheme.warning : BaseballTheme.border)
                VStack(alignment: .leading, spacing: 2) {
                    let copy = HighSchoolPresentation.karma(karma)
                    Text(copy.title).font(.subheadline.weight(.bold))
                    Text(copy.detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("+\(karma.rewardPermille / 10)%")
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
