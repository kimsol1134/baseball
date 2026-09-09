import SwiftUI
import SimulationCore
import BaseballIOSDomain

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
                            .proseStyle(BaseballTheme.textSecondary)
                        EffectChip(
                            text: copyResolver.resolve(
                                AppCopyKey.schoolSelectionStrength,
                                arguments: [.userText(resolvedStrength(for: school))]
                            ),
                            tone: .gain, systemImage: "star.fill"
                        )
                        Label {
                            GameCopyText(coreToken: copy.tradeoffToken)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(BaseballTheme.warning)
                        }
                            .detailStyle()
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
                    // 히트 영역은 카드 면 그대로다 — 카드 밖으로 새면 탭 바와 겹친다.
                    .contentShape(RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.school.\(school.id.rawValue)")
                .accessibilityLabel(accessibilityLabel(for: school))
            }
        }
        .alert(
            pending.map { school in
                let copy = selectionCopy(for: school)
                return copyResolver.resolve(
                    AppCopyKey.schoolSelectionConfirmTitle,
                    arguments: [.userText(copyResolver.resolve(copy.schoolNameToken))]
                )
            } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
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

/// 훈련 화면의 선택 상태. 카드(고르기)와 고정 하단 바(훈련하기)가 같은 값을 본다 —
/// 주 버튼을 스크롤 밖으로 빼려면 상태가 카드 밖에 있어야 한다(페르소나 보고서 §2-1).
struct TrainingSelection: Equatable {
    var focus: TrainingFocus
    var intensity: TrainingIntensity
    var targetPitch: PitchType

    /// 변화구 훈련일 때만 대상 구종이 의미 있다.
    var selectedTarget: PitchType? { focus == .breakingBall ? targetPitch : nil }

    /// 직전 선택에서 시작한다. 국면이 오갈 때마다 기본값으로 리셋되면
    /// 같은 훈련을 이어가려는 사람이 회차당 16번 재선택을 강요당한다.
    static func initial(state: HighSchoolCareerSnapshot) -> TrainingSelection {
        let activeProjectPitch = state.pitchLearningProject.flatMap {
            $0.isCompleted ? nil : $0.pitchType
        }
        return TrainingSelection(
            focus: HighSchoolCareerStore.recommendedTraining(state: state),
            intensity: HighSchoolCareerStore.recommendedTrainingIntensity(state: state),
            targetPitch: activeProjectPitch
                ?? state.pitcher.pitchProfiles?.first(where: { $0.pitchType != .fourSeam })?.pitchType
                ?? .slider
        )
    }

    static let placeholder = TrainingSelection(focus: .command, intensity: .standard, targetPitch: .slider)
}

/// 훈련하기 · 같은 훈련 3번 연속 — 스크롤 밖 고정 하단 바. 탭 바 위에 항상 보인다.
struct TrainingCommitBar: View {
    let selection: TrainingSelection
    var recommendedFocus: TrainingFocus? = nil
    var pendingNotice = false
    var onAcknowledgeNotice: (() -> Void)? = nil
    let onCommit: (TrainingFocus, TrainingIntensity, PitchType?) -> Void
    let onCommitBlock: (TrainingFocus, TrainingIntensity, PitchType?) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var showRepeatExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 두 버튼을 한 줄에. 세로로 쌓으면 SE에서 고정 바가 화면의 30%를 먹어
            // 첫 화면에 훈련 카드가 하나도 안 보였다(4차 D3 캡처).
            HStack(spacing: 8) {
                PrimaryButton(
                    title: copyResolver.resolve(
                        AppCopyKey.trainingCommit
                    ),
                    identifier: "hs.training.commit"
                ) {
                    if pendingNotice { onAcknowledgeNotice?() }
                    onCommit(selection.focus, selection.intensity, selection.selectedTarget)
                }
                Button {
                    onCommitBlock(selection.focus, selection.intensity, selection.selectedTarget)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .font(BaseballType.detail.weight(.semibold))
                            .accessibilityHidden(true)
                        // localization-safe: numeric
                        Text(verbatim: "×3")
                            .font(BaseballType.detail.weight(.bold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .frame(minWidth: 72, minHeight: 52)
                    .background(BaseballTheme.surfaceRaised, in: Capsule())
                    .foregroundStyle(BaseballTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.training.commitBlock")
                .accessibilityLabel(copyResolver.resolve(AppCopyKey.trainingRepeatTitle))
            }
            if showRepeatExplanation {
                Text(copyResolver.resolve(
                    recommendedFocus == selection.focus
                        ? AppCopyKey.trainingRepeatRecommendedExplanation
                        : AppCopyKey.trainingRepeatStopExplanation
                ))
                    .detailStyle()
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, BaseballMetrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(BaseballTheme.canvas)
        .overlay(alignment: .top) {
            Rectangle().fill(BaseballTheme.border.opacity(0.45)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hs.training.commitBar")
        .accessibilitySortPriority(-50)
        .onAppear {
            let id = "hs.training.repeat.explained"
            showRepeatExplanation = !SeenContentStore.contains(id)
            if showRepeatExplanation { SeenContentStore.markSeen(id) }
        }
    }
}

struct TrainingCard: View {
    let state: HighSchoolCareerSnapshot
    let armHealth: ArmHealthState
    /// 고르기의 결과. 커밋은 `TrainingCommitBar`가 같은 값으로 한다.
    @Binding var selection: TrainingSelection
    @Environment(\.gameCopyResolver) private var copyResolver

    @State private var trainingChoicesExpanded = false

    private var focus: TrainingFocus { selection.focus }
    private var intensity: TrainingIntensity { selection.intensity }
    private var targetPitch: PitchType { selection.targetPitch }

    /// 학교 특기와 오늘의 기회가 이 훈련에서 겹치는가 — 이 턴이 몰아붙일 턴이다.
    private var doubleBonus: Bool {
        state.school?.strength == focus && state.trainingOpportunity?.focus == focus
    }

    private var outlook: TrainingGrowthOutlook {
        HighSchoolCareerStore.trainingOutlook(state: state, focus: focus, intensity: intensity)
    }

    private var breakingBalls: [PitchType] {
        (state.pitcher.pitchProfiles ?? []).map(\.pitchType).filter { $0 != .fourSeam }
    }

    private func learningStageKey(_ stage: PitchLearningStage) -> GameCopyKey {
        switch stage {
        case .grip: AppCopyKey.trainingPitchLearningGrip
        case .bullpen: AppCopyKey.trainingPitchLearningBullpen
        case .liveTrial: AppCopyKey.trainingPitchLearningLive
        case .completed: AppCopyKey.trainingPitchLearningCompleted
        }
    }

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
    /// 효과·비용·위험 칩. 네 줄짜리 효과 문장 대신 칩 셋으로 읽힌다(1.2.9 가독성 교정).
    /// 피로 값은 현재 고른 강도 기준이라 강도를 바꾸면 여섯 카드의 칩이 함께 바뀐다.
    /// 피로 70부터는 "구위만 누르면 되더라"가 팔과 목표를 동시에 깨뜨린다(페르소나 §4-9).
    static let fatigueWarningThreshold = 70

    private var fatigueIsHigh: Bool { state.fatigue >= Self.fatigueWarningThreshold }

    private func effectChips(for option: TrainingFocus) -> [TrainingEffectChip] {
        var chips: [TrainingEffectChip] = []
        let fatigue = HighSchoolPresentation.trainingFatigueEstimate(
            state: state, focus: option, intensity: intensity
        )
        if option == .recovery {
            if fatigueIsHigh {
                chips.append(TrainingEffectChip(
                    text: copyResolver.resolve(AppCopyKey.trainingChipRecoverySafe),
                    tone: .gain, systemImage: "checkmark.shield"
                ))
            }
            chips.append(TrainingEffectChip(
                text: copyResolver.resolve(AppCopyKey.trainingChipFatigue, arguments: [.integer(fatigue)]),
                tone: fatigue < 0 ? .gain : .cost, systemImage: "battery.100"
            ))
            chips.append(TrainingEffectChip(
                text: copyResolver.resolve(AppCopyKey.trainingChipArmRecovery), tone: .gain, systemImage: nil
            ))
            chips.append(TrainingEffectChip(
                text: copyResolver.resolve(AppCopyKey.trainingChipNoGrowth), tone: .neutral, systemImage: nil
            ))
            return chips
        }
        if fatigueIsHigh {
            chips.append(TrainingEffectChip(
                text: copyResolver.resolve(AppCopyKey.trainingChipFatigueHigh),
                tone: .risk, systemImage: "exclamationmark.triangle"
            ))
        }
        chips.append(TrainingEffectChip(
            text: copyResolver.resolve(
                AppCopyKey.trainingChipGain,
                arguments: [.userText(HighSchoolPresentation.localizedFocusMetric(option, resolver: copyResolver))]
            ),
            tone: .gain, systemImage: nil
        ))
        chips.append(TrainingEffectChip(
            text: copyResolver.resolve(AppCopyKey.trainingChipFatigue, arguments: [.integer(fatigue)]),
            tone: fatigue > 0 ? .cost : .neutral, systemImage: "battery.50"
        ))
        switch HighSchoolPresentation.trainingArmRiskBand(focus: option, intensity: intensity) {
        case .high:
            chips.append(TrainingEffectChip(
                text: copyResolver.resolve(AppCopyKey.trainingChipRiskHigh), tone: .risk, systemImage: "bandage"
            ))
        case .some:
            chips.append(TrainingEffectChip(
                text: copyResolver.resolve(AppCopyKey.trainingChipRiskSome), tone: .neutral, systemImage: "bandage"
            ))
        case .none:
            break
        }
        return chips
    }

    private func focusOptionButton(_ option: TrainingFocus) -> some View {
        TrainingFocusOptionButton(
            option: option,
            title: HighSchoolPresentation.localized(option, resolver: copyResolver),
            growthSummary: HighSchoolPresentation.localizedFocusMetric(option, resolver: copyResolver),
            chips: effectChips(for: option),
            detail: HighSchoolPresentation.localizedFocusDetail(option, resolver: copyResolver),
            tradeoff: HighSchoolPresentation.localizedFocusTradeoff(option, resolver: copyResolver),
            detailTitle: copyResolver.resolve(AppCopyKey.trainingOptionDetailTitle),
            detailSummary: copyResolver.resolve(AppCopyKey.trainingOptionDetailSummary),
            windEffect: windEffect(for: option, resolver: copyResolver),
            opportunityBadge: copyResolver.resolve(AppCopyKey.trainingBadgeOpportunity),
            schoolStrengthBadge: copyResolver.resolve(AppCopyKey.trainingBadgeSchoolStrength),
            isOpportunity: state.trainingOpportunity?.focus == option,
            isSchoolStrength: state.school?.strength == option,
            isRecommended: HighSchoolCareerStore.recommendedTraining(state: state) == option,
            recommendedBadge: copyResolver.resolve(.localizable("mobile.polish.focus-recommended")),
            selection: $selection.focus,
            extras: { expandedExtras }
        )
    }

    private func intensityOptionButton(_ option: TrainingIntensity) -> some View {
        TrainingIntensityOptionButton(
            option: option,
            title: HighSchoolPresentation.localized(option, focus: focus, resolver: copyResolver),
            selection: $selection.intensity
        )
    }

    private func targetPitchPicker(title: String) -> some View {
        TrainingTargetPitchPicker(
            title: title,
            availablePitches: Set(breakingBalls),
            sliderTitle: PitchCopy.localized(.slider, resolver: copyResolver),
            curveballTitle: PitchCopy.localized(.curveball, resolver: copyResolver),
            changeupTitle: PitchCopy.localized(.changeup, resolver: copyResolver),
            selection: $selection.targetPitch
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
                        .proseStyle()
                }
            }

            Text(copyResolver.resolve(AppCopyKey.trainingPrompt)).font(.headline)
            Button(copyResolver.resolve(.localizable("mobile.core.change-training"))) { trainingChoicesExpanded.toggle() }
                .frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("training.change")
            focusOptionButton(focus)
            if focus == .command || focus == .gamePlanning { ControlMilestoneGoal(command: state.pitcher.command) }
            Text(verbatim: copyResolver.resolve(.localizable("mobile.polish.intensity")))
                .font(BaseballType.detail.weight(.semibold))
            HStack(spacing: 6) {
                intensityOptionButton(.light)
                intensityOptionButton(.standard)
                intensityOptionButton(.intensive)
            }
            if trainingChoicesExpanded {
                if focus != .velocity { focusOptionButton(.velocity) }
                if focus != .command { focusOptionButton(.command) }
                if focus != .breakingBall { focusOptionButton(.breakingBall) }
                if focus != .stamina { focusOptionButton(.stamina) }
                if focus != .recovery { focusOptionButton(.recovery) }
                if focus != .gamePlanning { focusOptionButton(.gamePlanning) }
            }

            // 강도·전망은 펼쳐진 추천 카드 안으로 들어간다.
        }
    }

    @ViewBuilder private var expandedExtras: some View {
        if focus == .breakingBall, !breakingBalls.isEmpty {
            let title = copyResolver.resolve(AppCopyKey.trainingPitchPickerTitle)
            if let project = state.pitchLearningProject {
                BaseballCard(
                    title: copyResolver.resolve(
                        AppCopyKey.trainingPitchLearningTitle,
                        arguments: [.userText(PitchCopy.localized(project.pitchType, resolver: copyResolver))]
                    ),
                    tone: project.isCompleted ? .positive : .milestone
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        GameCopyText(learningStageKey(project.stage))
                            .font(.subheadline.weight(.bold))
                        if !project.isCompleted {
                            GameCopyText(
                                AppCopyKey.trainingPitchLearningProgress,
                                arguments: [
                                    .integer(project.practiceCredits),
                                    .integer(CareerDisplayRules.pitchLearningPracticeCap),
                                    .integer(project.qualityUses),
                                    .integer(CareerDisplayRules.pitchLearningQualityUses),
                                ]
                            )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                        }
                    }
                    .accessibilityIdentifier("hs.training.pitchLearning.stage")
                }
                .accessibilityIdentifier("hs.training.pitchLearning")
            }
            BaseballCard(title: title) {
                targetPitchPicker(title: title)
            }
        }
        VStack(alignment: .leading, spacing: 10) {

            if doubleBonus {
                Text(copyResolver.resolve(AppCopyKey.trainingDoubleBonus))
                    .detailStyle(BaseballTheme.textPrimary)
            }
            let outlookPresentation = outlookCopy(resolver: copyResolver)
            // localization-safe: resolved-copy
            Text(outlookPresentation.text)
                .detailStyle(BaseballTheme.textPrimary)
                .accessibilityIdentifier("hs.training.outlook")
        }
    }
}

/// 훈련 카드 한 장의 효과 칩. 값은 이미 풀린 문구다.
struct TrainingEffectChip: Identifiable {
    let text: String
    let tone: EffectChip.Tone
    let systemImage: String?
    var id: String { text }
}

struct TrainingFocusOptionButton<Extras: View>: View {
    let option: TrainingFocus
    let title: String
    /// 오르는 능력 이름. 칩의 첫 장이자 접근성 효과 라벨의 앵커다.
    let growthSummary: String
    let chips: [TrainingEffectChip]
    let detail: String
    let tradeoff: String
    let detailTitle: String
    let detailSummary: String
    let windEffect: String?
    let opportunityBadge: String
    let schoolStrengthBadge: String
    let isOpportunity: Bool
    let isSchoolStrength: Bool
    var isRecommended: Bool = false
    let recommendedBadge: String
    @Binding var selection: TrainingFocus
    @ViewBuilder var extras: () -> Extras

    private var isSelected: Bool { selection == option }
    private var compactChips: [TrainingEffectChip] { Array(chips.prefix(2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button { selection = option } label: {
                HStack(spacing: 12) {
                    Image(systemName: HighSchoolPresentation.focusSymbol(option))
                        .font(.title3)
                        .foregroundStyle(isSelected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        EffectChipFlow(spacing: 6) {
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
                            if isRecommended {
                                Text(verbatim: recommendedBadge)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(BaseballTheme.action.opacity(0.25), in: Capsule())
                                    .foregroundStyle(BaseballTheme.action)
                            }
                            if isSchoolStrength {
                                // localization-safe: resolved-copy
                                Text(schoolStrengthBadge)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(BaseballTheme.action.opacity(0.25), in: Capsule())
                                .foregroundStyle(BaseballTheme.action)
                            }
                        }
                        if !isSelected {
                            EffectChipFlow {
                                ForEach(compactChips) { chip in
                                    EffectChip(text: chip.text, tone: chip.tone, systemImage: chip.systemImage)
                                }
                            }
                            .accessibilityIdentifier("hs.focus.effect.\(option.rawValue)")
                        }
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? BaseballTheme.selection : BaseballTheme.border)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hs.focus.\(option.rawValue)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityElement(children: .combine)
            if isSelected {
            VStack(alignment: .leading, spacing: 6) {
                EffectChipFlow {
                    ForEach(chips) { chip in
                        EffectChip(text: chip.text, tone: chip.tone, systemImage: chip.systemImage)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: chips.map(\.text).joined(separator: ", ")))
                .accessibilityIdentifier("hs.focus.effect.\(option.rawValue)")
                if let windEffect {
                    EffectChip(text: windEffect, tone: .neutral, systemImage: "wind")
                }
                ProgressiveDisclosure(
                    contentID: "hs.training.option.\(option.rawValue)",
                    title: detailTitle,
                    summary: detailSummary,
                    important: false,
                    startsCollapsed: true
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        GlossaryText(
                            text: detail,
                            font: BaseballType.detail,
                            color: BaseballTheme.textSecondary
                        )
                        GlossaryText(
                            text: tradeoff,
                            font: BaseballType.detail,
                            color: BaseballTheme.textSecondary
                        )
                        extras()
                    }
                }
            }
            .padding(.leading, 40)
            }
        }
        .padding(isSelected ? 12 : 8)
        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
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
                .font(BaseballType.annotation.weight(.semibold))
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
