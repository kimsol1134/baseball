import SwiftUI
import SimulationCore

struct SchoolSelectionCard: View {
    let options: [SchoolSnapshot]
    /// The persisted Korean region is passed only as ephemeral context for semantic copy lookup.
    /// It never crosses into `onChoose` or any saved/model field.
    let region: String
    let onChoose: (SchoolID) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    @State private var pending: SchoolSnapshot?

    private func selectionCopy(for school: SchoolSnapshot) -> SchoolSelectionCopyDescriptor {
        CopyToken.schoolSelection(rawRegion: region, schoolID: school.id)
    }

    private func resolvedStrength(for school: SchoolSnapshot) -> String {
        copyResolver.resolve(school.strength.displayCopyToken)
    }

    private func resolvedRoleName(_ nameToken: CopyToken, key: GameCopyKey) -> String {
        copyResolver.resolve(key, arguments: [.userText(copyResolver.resolve(nameToken))])
    }

    private func accessibilityLabel(for school: SchoolSnapshot) -> String {
        let copy = selectionCopy(for: school)
        let schoolName = copyResolver.resolve(copy.schoolNameToken)
        let philosophy = copyResolver.resolve(copy.philosophyToken)
        let strength = resolvedStrength(for: school)
        let tradeoff = copyResolver.resolve(copy.tradeoffToken)
        let coach = resolvedRoleName(copy.coachNameToken, key: AppCopyKey.schoolSelectionCoach)
        let coachArchetype = copyResolver.resolve(copy.coachArchetypeToken)
        let catcher = resolvedRoleName(copy.catcherNameToken, key: AppCopyKey.schoolSelectionCatcher)
        let catcherArchetype = copyResolver.resolve(copy.catcherArchetypeToken)
        return copyResolver.resolve(
            AppCopyKey.schoolSelectionCardAccessibility,
            arguments: [
                .userText(schoolName), .userText(philosophy), .userText(strength), .userText(tradeoff),
                .userText(coach), .userText(coachArchetype), .userText(catcher), .userText(catcherArchetype),
            ]
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.schoolSelectionTitle).font(.headline)
            ForEach(options, id: \.id) { school in
                let copy = selectionCopy(for: school)
                let coachName = resolvedRoleName(copy.coachNameToken, key: AppCopyKey.schoolSelectionCoach)
                let catcherName = resolvedRoleName(copy.catcherNameToken, key: AppCopyKey.schoolSelectionCatcher)
                Button { pending = school } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        GameCopyText(coreToken: copy.schoolNameToken).font(.headline)
                        GameCopyText(coreToken: copy.philosophyToken)
                            .font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label {
                            GameCopyText(
                                AppCopyKey.schoolSelectionStrength,
                                arguments: [.userText(resolvedStrength(for: school))]
                            )
                        } icon: {
                            Image(systemName: "star.fill")
                        }
                            .font(.footnote).foregroundStyle(BaseballTheme.positive)
                        Label {
                            GameCopyText(coreToken: copy.tradeoffToken)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                            .font(.footnote).foregroundStyle(BaseballTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        // 3년을 함께할 두 사람이다. 이름만 적혀 있으면 학교 선택이
                        // 스펙 비교표가 되고, 누구와 지낼지는 선택에 들어오지 않는다.
                        // 네 학교 인물은 PortraitView의 고정표가 변주를 하나씩 배정해
                        // 나란히 서도 같은 얼굴이 없고, 1:1 장면과 얼굴이 이어진다.
                        AvatarRow(seed: school.coachName, role: .coach,
                                  name: coachName,
                                  caption: copyResolver.resolve(copy.coachArchetypeToken), size: 40)
                        AvatarRow(seed: school.catcherName, role: .catcher,
                                  name: catcherName,
                                  caption: copyResolver.resolve(copy.catcherArchetypeToken), size: 40)
                    }
                    .padding(BaseballMetrics.gutter)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.school.\(school.id.rawValue)")
                .accessibilityLabel(accessibilityLabel(for: school))
            }
        }
        .confirmationDialog(
            pending.map { school in
                let copy = selectionCopy(for: school)
                return copyResolver.resolve(
                    AppCopyKey.schoolSelectionConfirmTitle,
                    arguments: [.userText(copyResolver.resolve(copy.schoolNameToken))]
                )
            } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { school in
            Button(copyResolver.resolve(AppCopyKey.schoolSelectionConfirmAction)) {
                onChoose(school.id)
                pending = nil
            }
            .accessibilityIdentifier("hs.school.confirm")
            // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣어 취소를 항상 보이게 한다.
            Button(copyResolver.resolve(AppCopyKey.schoolSelectionConfirmCancel)) { pending = nil }
        } message: { school in
            let copy = selectionCopy(for: school)
            Text(
                copyResolver.resolve(
                    AppCopyKey.schoolSelectionConfirmMessage,
                    arguments: [
                        .userText(resolvedStrength(for: school)),
                        .userText(copyResolver.resolve(copy.tradeoffToken)),
                    ]
                )
            )
        }
    }
}

struct TrainingCard: View {
    let state: HighSchoolCareerSnapshot
    let armHealth: ArmHealthState
    let onCommit: (TrainingFocus, TrainingIntensity, PitchType?) -> Void
    let onCommitBlock: (TrainingFocus, TrainingIntensity, PitchType?) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    // 직전 선택에서 시작한다. 국면이 오갈 때마다 기본값으로 리셋되면
    // 같은 훈련을 이어가려는 사람이 회차당 16번 재선택을 강요당한다.
    @State private var focus: TrainingFocus
    @State private var intensity: TrainingIntensity
    @State private var targetPitch: PitchType

    init(state: HighSchoolCareerSnapshot, armHealth: ArmHealthState,
         onCommit: @escaping (TrainingFocus, TrainingIntensity, PitchType?) -> Void,
         onCommitBlock: @escaping (TrainingFocus, TrainingIntensity, PitchType?) -> Void) {
        self.state = state
        self.armHealth = armHealth
        self.onCommit = onCommit
        self.onCommitBlock = onCommitBlock
        _focus = State(initialValue: state.lastTraining?.focus ?? .command)
        _intensity = State(initialValue: state.lastTraining?.intensity ?? .standard)
        _targetPitch = State(initialValue: state.pitcher.pitchProfiles?
            .first(where: { $0.pitchType != .fourSeam })?.pitchType ?? .slider)
    }

    /// 전망 계산용. 엔진은 상태가 없어서 화면이 하나 들고 있어도 된다.
    private let engine = HighSchoolCareerEngine()

    /// 학교 특기와 오늘의 기회가 이 훈련에서 겹치는가 — 이 턴이 몰아붙일 턴이다.
    private var doubleBonus: Bool {
        state.school?.strength == focus && state.trainingOpportunity?.focus == focus
    }

    private var outlook: HighSchoolCareerEngine.TrainingGrowthOutlook {
        engine.trainingOutlook(state: state, focus: focus, intensity: intensity)
    }

    private var breakingBalls: [PitchType] {
        (state.pitcher.pitchProfiles ?? []).map(\.pitchType).filter { $0 != .fourSeam }
    }

    private var selectedTarget: PitchType? { focus == .breakingBall ? targetPitch : nil }

    /// 전망을 말로 옮긴다. 확률 숫자가 아니라 구간만 말한다 — 판정의 무작위 폭은 그대로다.
    private func outlookCopy(resolver: GameCopyResolver) -> (text: String, tone: Color) {
        switch outlook {
        case .wall:
            return (resolver.resolve(outlook.detailCopyToken), BaseballTheme.milestone)
        case .two:
            return (resolver.resolve(outlook.detailCopyToken), BaseballTheme.positive)
        case .oneOrTwo:
            return (resolver.resolve(outlook.detailCopyToken), BaseballTheme.positive)
        case .one:
            return (resolver.resolve(outlook.detailCopyToken), BaseballTheme.textSecondary)
        case .zeroOrOne:
            return (resolver.resolve(outlook.detailCopyToken), BaseballTheme.textSecondary)
        case .none:
            return (resolver.resolve(outlook.detailCopyToken), BaseballTheme.warning)
        }
    }

    private func windEffect(for option: TrainingFocus, resolver: GameCopyResolver) -> String? {
        let wind = state.careerWind
        let descriptor = CareerWindPresentationCatalog.descriptor(for: wind)
        let title = resolver.resolve(descriptor.titleToken)
        var effects: [String] = []
        let growth = wind.rules.trainingGrowthBonus(for: option)
        if growth != 0 {
            effects.append(resolver.resolve(
                GameCopyKey.gameContent("content.training-wind.growth"),
                arguments: [.integer(growth)]
            ))
        }
        if option == .recovery, wind.rules.recoveryBonus != 0 {
            let bonus = wind.rules.recoveryBonus
            effects.append(resolver.resolve(
                GameCopyKey.gameContent("content.training-wind.recovery"),
                arguments: [.integer(bonus)]
            ))
        }
        let fatigue = wind.rules.trainingFatigueModifier(for: option)
        if fatigue != 0 {
            effects.append(resolver.resolve(
                GameCopyKey.gameContent("content.training-wind.fatigue"),
                arguments: [.integer(fatigue)]
            ))
        }
        guard !effects.isEmpty else { return nil }
        return resolver.resolve(
            GameCopyKey.gameContent("content.training-wind.effect-line"),
            arguments: [.userText(title), .userText(effects.joined(separator: " · "))]
        )
    }

    /// SwiftUICore가 `ForEach`의 item closure를 다른 executor에서 호출하는 경로를
    /// 피한다. 각 행은 고정된 View로 만들고, actor-bound 상태는 Binding으로만 넘긴다.
    private func focusOptionButton(_ option: TrainingFocus) -> some View {
        TrainingFocusOptionButton(
            option: option,
            title: HighSchoolPresentation.localized(option, resolver: copyResolver),
            detail: HighSchoolPresentation.localizedFocusDetail(option, resolver: copyResolver),
            windEffect: windEffect(for: option, resolver: copyResolver),
            opportunityBadge: copyResolver.resolve(AppCopyKey.trainingBadgeOpportunity),
            schoolStrengthBadge: copyResolver.resolve(AppCopyKey.trainingBadgeSchoolStrength),
            isOpportunity: state.trainingOpportunity?.focus == option,
            isSchoolStrength: state.school?.strength == option,
            selection: $focus
        )
    }

    private func intensityOptionButton(_ option: TrainingIntensity) -> some View {
        TrainingIntensityOptionButton(
            option: option,
            title: HighSchoolPresentation.localized(option, focus: focus, resolver: copyResolver),
            selection: $intensity
        )
    }

    private func targetPitchPicker(title: String) -> some View {
        TrainingTargetPitchPicker(
            title: title,
            availablePitches: Set(breakingBalls),
            sliderTitle: PitchCopy.localized(.slider, resolver: copyResolver),
            curveballTitle: PitchCopy.localized(.curveball, resolver: copyResolver),
            changeupTitle: PitchCopy.localized(.changeup, resolver: copyResolver),
            selection: $targetPitch
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            let health = HighSchoolPresentation.localizedArmHealth(armHealth, resolver: copyResolver)
            if armHealth != .normal {
                BaseballCard(title: health.label, tone: health.tone) {
                    Text(copyResolver.resolve(
                        armHealth == .recovering
                            ? AppCopyKey.trainingArmHealthRecovering
                            : AppCopyKey.trainingArmHealthRisk
                    ))
                        .font(.subheadline)
                }
            }

            if let opportunity = state.trainingOpportunity {
                BaseballCard(
                    title: copyResolver.resolve(
                        AppCopyKey.trainingOpportunityTitle,
                        arguments: [.userText(HighSchoolPresentation.localized(opportunity.focus, resolver: copyResolver))]
                    ),
                    tone: .milestone
                ) {
                    Text(HighSchoolPresentation.localizedOpportunityReason(opportunity, resolver: copyResolver))
                        .font(.subheadline)
                }
            }

            Text(copyResolver.resolve(AppCopyKey.trainingPrompt)).font(.headline)
            // 열거형은 고정 여섯 개다. 명시적 행은 SwiftUICore의 지연 item closure를
            // 만들지 않으면서 CaseIterable 선언 순서와 같은 화면 순서를 보존한다.
            focusOptionButton(.velocity)
            focusOptionButton(.command)
            focusOptionButton(.breakingBall)
            focusOptionButton(.stamina)
            focusOptionButton(.recovery)
            focusOptionButton(.gamePlanning)

            if focus == .breakingBall, !breakingBalls.isEmpty {
                let title = copyResolver.resolve(AppCopyKey.trainingPitchPickerTitle)
                BaseballCard(title: title) {
                    targetPitchPicker(title: title)
                }
            }

            BaseballCard(title: copyResolver.resolve(AppCopyKey.trainingIntensityTitle)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        intensityOptionButton(.light)
                        intensityOptionButton(.standard)
                        intensityOptionButton(.intensive)
                    }
                    if doubleBonus {
                        Text(copyResolver.resolve(AppCopyKey.trainingDoubleBonus))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    let outlookPresentation = outlookCopy(resolver: copyResolver)
                    // localization-safe: resolved-copy
                    Text(outlookPresentation.text)
                        .font(.footnote)
                        .foregroundStyle(outlookPresentation.tone)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("hs.training.outlook")
                    Text(HighSchoolPresentation.localizedFocusTradeoff(focus, resolver: copyResolver))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PrimaryButton(title: copyResolver.resolve(AppCopyKey.trainingCommit), identifier: "hs.training.commit") { onCommit(focus, intensity, selectedTarget) }
            Button {
                onCommitBlock(focus, intensity, selectedTarget)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(copyResolver.resolve(AppCopyKey.trainingRepeatTitle))
                        .font(.subheadline.weight(.semibold))
                    Text(copyResolver.resolve(AppCopyKey.trainingRepeatStopExplanation))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: BaseballMetrics.minimumTapTarget)
            .accessibilityIdentifier("hs.training.commitBlock")
        }
    }
}

struct TrainingFocusOptionButton: View {
    let option: TrainingFocus
    let title: String
    let detail: String
    let windEffect: String?
    let opportunityBadge: String
    let schoolStrengthBadge: String
    let isOpportunity: Bool
    let isSchoolStrength: Bool
    @Binding var selection: TrainingFocus

    private var isSelected: Bool { selection == option }

    var body: some View {
        Button { selection = option } label: {
            HStack(spacing: 12) {
                Image(systemName: HighSchoolPresentation.focusSymbol(option))
                    .font(.title3)
                    .foregroundStyle(isSelected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // localization-safe: resolved-copy
                        Text(title).font(.subheadline.weight(.bold))
                        if isOpportunity {
                            // localization-safe: resolved-copy
                            Text(opportunityBadge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(BaseballTheme.milestone.opacity(0.25), in: Capsule())
                                .foregroundStyle(BaseballTheme.milestone)
                        }
                        // 학교 특기는 3년 내내 붙는 상수 보너스다. 기회와 특기가
                        // 겹치는 턴을 알아보는 것이 훈련의 실제 결정이라 함께 표시한다.
                        if isSchoolStrength {
                            // localization-safe: resolved-copy
                            Text(schoolStrengthBadge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(BaseballTheme.action.opacity(0.25), in: Capsule())
                            .foregroundStyle(BaseballTheme.action)
                        }
                    }
                    // localization-safe: resolved-copy
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    if let windEffect {
                        // localization-safe: resolved-copy
                        Text(windEffect)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.information)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? BaseballTheme.selection : BaseballTheme.border)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(
                isSelected ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(
                        isSelected ? BaseballTheme.selection : BaseballTheme.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hs.focus.\(option.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TrainingIntensityOptionButton: View {
    let option: TrainingIntensity
    let title: String
    @Binding var selection: TrainingIntensity

    private var isSelected: Bool { selection == option }

    var body: some View {
        Button { selection = option } label: {
            // localization-safe: resolved-copy
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .accessibilityIdentifier("hs.intensity.\(option.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct TrainingTargetPitchPicker: View {
    let title: String
    let availablePitches: Set<PitchType>
    let sliderTitle: String
    let curveballTitle: String
    let changeupTitle: String
    @Binding var selection: PitchType

    var body: some View {
        Picker(title, selection: $selection) {
            if availablePitches.contains(.slider) {
                // localization-safe: resolved-copy
                Text(sliderTitle).tag(PitchType.slider)
            }
            if availablePitches.contains(.curveball) {
                // localization-safe: resolved-copy
                Text(curveballTitle).tag(PitchType.curveball)
            }
            if availablePitches.contains(.changeup) {
                // localization-safe: resolved-copy
                Text(changeupTitle).tag(PitchType.changeup)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("hs.training.targetPitch")
    }
}
