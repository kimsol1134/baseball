import SwiftUI
import SimulationCore

/// 고교 커리어 10단계 화면. 게임 제목("야구 못하면 또 환생함")의 본편이다.
struct HighSchoolCareerView: View {
    let career: HighSchoolCareerStore
    /// 지명을 받고 프로로 넘어갈 때 호출된다.
    let onEnterPro: (DraftResultSnapshot, PitcherSnapshot, PlayerIdentitySnapshot) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var achievements = AchievementStore.shared
    /// 오프닝을 넘겼는가. 저장하지 않는다 — 커리어를 지우면 다시 보는 것이 맞다.
    @State private var openingDismissed = false
    private var audio: GameAudio { .shared }

    var body: some View {
        Group {
            switch career.loadState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .needsSetup:
                // 첫 회차에는 오프닝 장면을 먼저 보여 준다. 앱을 열자마자 폼이 나오면
                // 게임이 시작됐다는 것 자체가 전달되지 않는다.
                if career.inheritance.lifeNumber == 1, !openingDismissed {
                    OpeningView { openingDismissed = true }
                } else {
                    HighSchoolSetupView(career: career)
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("고교 커리어를 열 수 없습니다", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    PrimaryPill(title: "새로 시작", identifier: "hs.restart") { career.deleteCareer() }
                }
            case .ready:
                content
            }
        }
        .background(BaseballTheme.canvas)
        .sensoryFeedback(trigger: career.feedbackTrigger) { _, _ in
            switch career.feedbackCue {
            case .growth: .impact(weight: .heavy)
            case .success: .success
            case .setback: .warning
            case .neutral: .selection
            }
        }
        .onChange(of: career.feedbackTrigger) { _, _ in
            if let cue = GameAudioMapping.cue(for: career.feedbackCue) { audio.play(cue) }
        }
    }

    @ViewBuilder private var content: some View {
        if let state = career.state {
            if state.phase == .prologue, let session = career.tutorialSession {
                PitchView(session: session, onFinish: career.finishTutorialPitch)
            } else if state.phase == .importantGame, let session = career.pitchSession {
                PitchView(session: session, onFinish: career.finishImportantGame)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        ChapterHeader(state: state, lifeNumber: career.inheritance.lifeNumber)

                        if !achievements.freshlyUnlocked.isEmpty {
                            AchievementBanner(achievements: achievements.freshlyUnlocked) {
                                achievements.acknowledge()
                            }
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        if !career.pendingGains.isEmpty {
                            GrowthCelebrationView(gains: career.pendingGains, onDismiss: career.acknowledgeGains)
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        } else if let summary = career.lastSummary {
                            SummaryBanner(summary: summary, cue: career.feedbackCue)
                        }

                        phaseBody(state: state)
                    }
                    .padding(BaseballMetrics.gutter)
                }
                .background(BaseballTheme.canvas)
                .animation(reduceMotion ? nil : .snappy, value: career.feedbackTrigger)
            }
        }
    }

    @ViewBuilder private func phaseBody(state: HighSchoolCareerSnapshot) -> some View {
        switch state.phase {
        case .prologue:
            PrologueCard(
                state: state,
                lifeNumber: career.inheritance.lifeNumber,
                onThrow: career.beginTutorialPitch,
                onSkip: career.completePrologue
            )
        case .schoolSelection:
            SchoolSelectionCard(options: state.schoolOptions, onChoose: career.chooseSchool)
        case .training:
            TrainingCard(state: state, armHealth: career.armHealth) { focus, intensity in
                audio.play(.uiSelect)
                career.commitTraining(focus: focus, intensity: intensity)
            }
        case .relationship:
            RelationshipCard(state: state, onRespond: career.resolveRelationship)
        case .importantGame:
            ImportantGameCard(state: state, onStart: career.beginImportantGame)
        case .awakening:
            AwakeningCard(options: state.awakeningOptions, onChoose: career.chooseAwakening)
        case .chapterReview:
            ChapterReviewCard(state: state, onContinue: career.advanceChapter)
        case .draft:
            DraftCard(state: state, onResolve: career.resolveDraft)
        case .legacy:
            LegacyCard(career: career, state: state)
        case .completed:
            CompletionCard(career: career, state: state, onEnterPro: onEnterPro)
        }
    }
}

// MARK: - 머리말

private struct ChapterHeader: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int

    /// 되돌릴 수 없는 순간에만 전용 그림을 준다. 나머지는 야간 구장 한 장으로 통일한다 —
    /// 모든 화면에 다른 그림이 있으면 어느 것도 특별하지 않다(DOC-19 §7.5).
    static func art(for phase: HighSchoolCareerPhase) -> KeyArt {
        switch phase {
        case .prologue: .careerIntro
        case .schoolSelection: .schoolCrossroads
        case .awakening: .awakening
        case .draft: .draftDay
        case .legacy: .reincarnation
        default: .stadiumNight
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.tightSpacing) {
            KeyArtHeader(
                art: Self.art(for: state.phase),
                // 1회차에는 회차 표시를 하지 않는다. 처음 하는 사람에게 "1회차"는 아무 뜻이 없고,
                // 반복하는 게임이라는 사실은 한 번 죽어 봐야 의미가 생긴다.
                eyebrow: lifeNumber > 1
                    ? "\(lifeNumber)회차 · \(state.chapter.schoolYear)학년 \(state.chapter.season)"
                    : "\(state.chapter.schoolYear)학년 \(state.chapter.season)",
                title: state.school.map { "\($0.name) · \(state.chapter.title)" } ?? state.chapter.title
            )
            HStack(spacing: 10) {
                Metric(title: "피로", value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: "팀의 믿음", value: "\(state.relationshipTrust)")
                Metric(title: "훈련", value: "\(state.totalTrainingsCompleted)")
            }
        }
    }
}

/// 직전 행동의 결과 한 줄. 매 단계 뜨는 서사 문구라 면을 두지 않는다.
///
/// 좌측 강조 레일을 쓰지 않는다. 이 배너는 화면을 넘길 때마다 뜨는 것이라, 왼쪽에 색 막대를
/// 세우면 그 장치가 게임 내내 반복되어 "어디서 본 듯한" 인상을 만든다(DOC-19 §7.2).
/// 좋고 나쁨은 눈썹 한 줄과 글자색으로만 알린다 — 카드가 쓰는 것과 같은 언어다.
private struct SummaryBanner: View {
    let summary: String
    let cue: MobileCareerStore.FeedbackCue

    private var accent: Color {
        switch cue {
        case .setback: BaseballTheme.negative
        case .growth: BaseballTheme.action
        case .success: BaseballTheme.positive
        case .neutral: BaseballTheme.textTertiary
        }
    }

    /// 무슨 일이 있었는지를 한 낱말로. 색만으로는 색각 이상이 있는 사람에게 전달되지 않는다.
    private var label: String {
        switch cue {
        case .setback: "차질"
        case .growth: "성장"
        case .success: "성과"
        case .neutral: "경과"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).eyebrowStyle(accent)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(summary)")
    }
}

// MARK: - 단계 카드

private struct PrologueCard: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int
    let onThrow: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: lifeNumber > 1 ? "다시 태어났습니다" : "첫 등교", tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    // 첫 회차에는 감독이 말을 건다. "무엇을 해야 하는지"를 사람 말로 알려 주는 편이
                    // 안내 문구보다 잘 읽힌다.
                    Text(lifeNumber > 1
                         ? (state.news.first ?? "고교 3년이 다시 시작됩니다.")
                         : "\u{201C}몸부터 풀자. 불펜에서 한 구 던져 봐.\u{201D} — 감독")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    if !state.karmas.isEmpty {
                        Divider()
                        Text("핸디캡").font(.caption.weight(.bold)).foregroundStyle(BaseballTheme.warning)
                        ForEach(state.karmas, id: \.self) { karma in
                            let copy = HighSchoolPresentation.karma(karma)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(copy.title).font(.subheadline.weight(.semibold))
                                Text(copy.detail).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            BaseballCard(title: "지금의 나") {
                VStack(alignment: .leading, spacing: 10) {
                    AbilityGaugeView(label: "구위", value: state.pitcher.stuff)
                    AbilityGaugeView(label: "제구", value: state.pitcher.command)
                    AbilityGaugeView(label: "변화구", value: state.pitcher.movement)
                    AbilityGaugeView(label: "체력", value: state.pitcher.stamina)
                }
            }
            // 이 게임에서 가장 좋은 것은 투구다. 사는 사람이 그걸 두 번째 탭에서 만나게 한다.
            PrimaryButton(title: "첫 공을 던져 본다", identifier: "hs.prologue.throw", action: onThrow)
            Button("바로 학교 고르기", action: onSkip)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.prologue.continue")
        }
    }
}

/// 학교 선택.
///
/// 확인을 한 번 받는다. 학교는 3년을 통째로 결정하는데 되돌릴 수 없고, 카드를 한 번 누르면
/// 바로 확정됐다. 목록을 훑다가 잘못 눌러 3년을 날리는 일은 실제로 일어나고, 그 사람은 게임을
/// 지운다. 확인 창에서 그 학교의 강점과 감수할 것을 한 번 더 읽힌다.
private struct SchoolSelectionCard: View {
    let options: [SchoolSnapshot]
    let onChoose: (SchoolID) -> Void

    @State private var pending: SchoolSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text("어느 학교로 갈지 고르세요").font(.headline)
            ForEach(options, id: \.id) { school in
                Button { pending = school } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(school.name).font(.headline)
                        Text(school.philosophy).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label("강점 · \(HighSchoolPresentation.focus(school.strength))", systemImage: "star.fill")
                            .font(.footnote).foregroundStyle(BaseballTheme.positive)
                        Label(school.tradeoff, systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(BaseballTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text("감독 \(school.coachName) · \(school.coachArchetype)")
                            .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                        Text("포수 \(school.catcherName) · \(school.catcherArchetype)")
                            .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
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
            }
        }
        .confirmationDialog(
            pending.map { "\($0.name)으로 가시겠습니까?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { school in
            Button("이 학교로 간다") {
                onChoose(school.id)
                pending = nil
            }
            .accessibilityIdentifier("hs.school.confirm")
            Button("다시 고른다", role: .cancel) { pending = nil }
        } message: { school in
            Text(
                """
                강점 · \(HighSchoolPresentation.focus(school.strength))
                \(school.tradeoff)

                한 번 정하면 3년 동안 바꿀 수 없습니다.
                """
            )
        }
    }
}

private struct TrainingCard: View {
    let state: HighSchoolCareerSnapshot
    let armHealth: ArmHealthState
    let onCommit: (TrainingFocus, TrainingIntensity) -> Void

    @State private var focus: TrainingFocus = .command
    @State private var intensity: TrainingIntensity = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            let health = HighSchoolPresentation.armHealth(armHealth)
            if armHealth != .normal {
                BaseballCard(title: health.label, tone: health.tone) {
                    Text(armHealth == .recovering
                        ? "부상 회복 중입니다. 회복 훈련만 효과가 있습니다."
                        : "회복 훈련으로 팔 상태를 되돌리지 않으면 부상 위험이 커집니다.")
                        .font(.subheadline)
                }
            }

            if let opportunity = state.trainingOpportunity {
                BaseballCard(title: "오늘의 기회 · \(HighSchoolPresentation.focus(opportunity.focus))", tone: .milestone) {
                    Text(opportunity.reason).font(.subheadline)
                }
            }

            Text("무엇을 훈련할까요").font(.headline)
            ForEach(TrainingFocus.allCases, id: \.self) { option in
                let isOpportunity = state.trainingOpportunity?.focus == option
                Button { focus = option } label: {
                    HStack(spacing: 12) {
                        Image(systemName: HighSchoolPresentation.focusSymbol(option))
                            .font(.title3)
                            .foregroundStyle(focus == option ? BaseballTheme.selection : BaseballTheme.textSecondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(HighSchoolPresentation.focus(option)).font(.subheadline.weight(.bold))
                                if isOpportunity {
                                    Text("기회")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(BaseballTheme.milestone.opacity(0.25), in: Capsule())
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                            }
                            Text(HighSchoolPresentation.focusDetail(option))
                                .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: focus == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(focus == option ? BaseballTheme.selection : BaseballTheme.border)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .background(
                        focus == option ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                        in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(focus == option ? BaseballTheme.selection : BaseballTheme.border, lineWidth: focus == option ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.focus.\(option.rawValue)")
                .accessibilityAddTraits(focus == option ? .isSelected : [])
            }

            BaseballCard(title: "강도") {
                HStack(spacing: 6) {
                    ForEach(TrainingIntensity.allCases, id: \.self) { option in
                        Button { intensity = option } label: {
                            Text(HighSchoolPresentation.intensity(option, focus: focus))
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .background(
                            intensity == option ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(intensity == option ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                        lineWidth: intensity == option ? 2 : 1)
                        }
                        .accessibilityAddTraits(intensity == option ? .isSelected : [])
                    }
                }
            }

            PrimaryButton(title: "훈련하기", identifier: "hs.training.commit") { onCommit(focus, intensity) }
        }
    }
}

private struct RelationshipCard: View {
    let state: HighSchoolCareerSnapshot
    let onRespond: (RelationshipResponse) -> Void

    /// 누가 말을 걸었는지. 이름표가 있어야 대화로 읽힌다.
    static func speaker(for category: String) -> String {
        switch category {
        case "life": "집"
        case "coach": "감독"
        case "catcher": "포수"
        case "rival": "라이벌"
        case "media": "취재"
        case "fan": "팬"
        case "health": "몸 상태"
        case "team": "팀"
        case "draft": "스카우트"
        case "growth": "훈련장"
        case "game": "경기장"
        default: "학교"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 대화가 이 화면의 주인공이다. 예전에는 요약 한 줄이 작은 글씨로 붙고 선택지가
            // 화면을 채워서, 무슨 일이 일어났는지보다 버튼 세 개가 먼저 눈에 들어왔다.
            if let event = state.currentRelationshipEvent {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.speaker(for: event.category)).eyebrowStyle(BaseballTheme.information)
                    Text(event.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Text(event.summary)
                        .font(.body)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            }
            Text("어떻게 답할까요").font(.headline)
            ForEach(RelationshipResponse.allCases, id: \.self) { response in
                Button { onRespond(response) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(HighSchoolPresentation.response(
                            response,
                            category: state.currentRelationshipEvent?.category ?? ""
                        )).font(.subheadline.weight(.bold))
                        Text(HighSchoolPresentation.responseDetail(response))
                            .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.response.\(response.rawValue)")
            }
        }
    }
}

private struct ImportantGameCard: View {
    let state: HighSchoolCareerSnapshot
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if let scenario = state.currentGameScenario {
                BaseballCard(title: scenario.title, tone: .milestone) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(scenario.inning)회 \(scenario.outs)아웃")
                            .font(.subheadline.bold().monospacedDigit())
                        Text(scenario.narrative).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            BaseballCard(title: "상대", tone: .warning) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.rival.name).font(.headline)
                    Text(state.rival.archetype).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    if let record = state.rival.signatureRecord {
                        Text(record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            PrimaryButton(title: "마운드에 오르기", identifier: "hs.game.start", action: onStart)
        }
    }
}

/// 각성 선택.
///
/// 학교 선택과 같은 이유로 확인을 받는다 — 되돌릴 수 없는데 한 번 누르면 확정된다.
/// 카드에 "되돌릴 수 없습니다"라고 적어 두는 것만으로는 오조작을 막지 못한다.
private struct AwakeningCard: View {
    let options: [AwakeningID]
    let onChoose: (AwakeningID) -> Void

    @State private var pending: AwakeningID?

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text("몸이 하나를 기억합니다").font(.headline)
            Text("고른 각성은 되돌릴 수 없습니다.").font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
            ForEach(options, id: \.self) { option in
                let copy = HighSchoolPresentation.awakening(option)
                Button { pending = option } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.title).font(.subheadline.weight(.bold))
                        Text(copy.detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .background(BaseballTheme.milestone.opacity(0.12), in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.milestone, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.awakening.\(option.rawValue)")
            }
        }
        .confirmationDialog(
            pending.map { "'\(HighSchoolPresentation.awakening($0).title)'으로 각성할까요?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { option in
            Button("이걸로 각성한다") {
                onChoose(option)
                pending = nil
            }
            .accessibilityIdentifier("hs.awakening.confirm")
            Button("다시 고른다", role: .cancel) { pending = nil }
        } message: { option in
            Text("\(HighSchoolPresentation.awakening(option).detail)\n\n한 번 고르면 고교 3년 동안 바꿀 수 없습니다.")
        }
    }
}

private struct ChapterReviewCard: View {
    let state: HighSchoolCareerSnapshot
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: "\(state.chapter.title) 마무리", tone: .raised) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.chapter.theme).font(.subheadline)
                    Divider()
                    Text("중요 경기 \(state.performance.importantGamesCompleted)회 · \(state.performance.strikeouts)탈삼진 · \(state.performance.walks)볼넷")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            BaseballCard(title: "능력") {
                VStack(alignment: .leading, spacing: 10) {
                    AbilityGaugeView(label: "구위", value: state.pitcher.stuff)
                    AbilityGaugeView(label: "제구", value: state.pitcher.command)
                    AbilityGaugeView(label: "변화구", value: state.pitcher.movement)
                    AbilityGaugeView(label: "체력", value: state.pitcher.stamina)
                }
            }
            PrimaryButton(title: "다음 챕터로", identifier: "hs.chapter.continue", action: onContinue)
        }
    }
}

private struct DraftCard: View {
    let state: HighSchoolCareerSnapshot
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: "드래프트", tone: .milestone) {
                Text("3년의 기록이 평가됩니다. 지명 여부가 지금 정해집니다.")
                    .font(.subheadline)
            }
            BaseballCard(title: "3년의 기록") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("중요 경기 \(state.performance.importantGamesCompleted)회")
                    Text("\(state.performance.strikeouts)탈삼진 · \(state.performance.walks)볼넷 · \(state.performance.runsAllowed)실점")
                    Text("각성 \(state.selectedAwakenings.count)회 · 훈련 \(state.totalTrainingsCompleted)회")
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            }
            // 자동으로 흘러간 팀 경기도 평가에 들어간다. 여기 보여 주지 않으면
            // 드래프트 카드의 "시즌 기록 +N"이 어디서 나온 숫자인지 알 수 없다.
            if let log = state.seasonLog, !log.isEmpty {
                SeasonRecordCard(log: log)
            }
            PrimaryButton(title: "결과 확인", identifier: "hs.draft.resolve", action: onResolve)
        }
    }
}

private struct LegacyCard: View {
    let career: HighSchoolCareerStore
    let state: HighSchoolCareerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if let draft = state.draftResult {
                BaseballCard(title: draft.outcome == .drafted ? "지명" : "미지명",
                             tone: draft.outcome == .drafted ? .positive : .negative) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(draft.summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        // 무엇이 점수를 만들었는지. 이게 없으면 3년 동안 쌓은 것들이
                        // 결과에 어떻게 반영됐는지 알 방법이 없다.
                        if let breakdown = draft.evaluationBreakdown, !breakdown.isEmpty {
                            Divider()
                            Text("평가 \(draft.evaluationScore)점").eyebrowStyle(BaseballTheme.textTertiary)
                            FlowRow(items: breakdown)
                        }
                    }
                }
            }
            BaseballCard(title: "다음 생으로 가져갈 기억 · \(career.selectedMemories.count)/\(state.memorySlots)", tone: .milestone) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("고른 기억은 다음 생의 시작 능력에 더해집니다.")
                        .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                    // 코어는 정확히 memorySlots장을 요구한다. 부족한 채로 확정하면 오류가 나므로
                    // 화면에서 막고 남은 장수를 알려 준다.
                    if career.selectedMemories.count < state.memorySlots {
                        Text("\(state.memorySlots - career.selectedMemories.count)장 더 고르세요.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.warning)
                    }
                }
            }
            ForEach(state.legacyOptions, id: \.self) { option in
                let copy = HighSchoolPresentation.memory(option)
                let selected = career.selectedMemories.contains(option)
                Button { career.toggleMemory(option) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.border)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy.title).font(.subheadline.weight(.bold))
                            Text(copy.detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selected ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                        in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(selected ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selected ? 2 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.memory.\(option.rawValue)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            PrimaryButton(title: "기억을 확정한다", identifier: "hs.legacy.confirm") { career.confirmLegacy() }
                .disabled(career.selectedMemories.count != state.memorySlots)
        }
    }
}

private struct CompletionCard: View {
    let career: HighSchoolCareerStore
    let state: HighSchoolCareerSnapshot
    let onEnterPro: (DraftResultSnapshot, PitcherSnapshot, PlayerIdentitySnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: "고교 3년 완료", tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.draftResult?.summary ?? "3년이 끝났습니다.")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    // 지명된 회차에서는 아직 계승이 정해지지 않았다. 지난 회차의 것만 보여 준다.
                    if career.inheritance.memories.isEmpty {
                        EmptyView()
                    } else {
                        Text("가져온 기억 \(career.inheritance.memories.count)장 · 야구혼 \(career.inheritance.soulPoints)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
            }

            if let draft = state.draftResult, draft.outcome == .drafted {
                PrimaryButton(title: "프로 커리어 시작", identifier: "hs.enterPro") {
                    onEnterPro(draft, state.pitcher, state.identity)
                }
                Text("이 선수의 이야기는 아직 끝나지 않았습니다.")
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
            }

            // 지명된 회차는 아직 끝나지 않았다. 접겠다고 결정할 때 비로소 기억을 고른다.
            let drafted = state.draftResult?.outcome == .drafted
            Button {
                if drafted { career.openLegacy() } else { career.beginNextLife() }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drafted ? "이 회차를 접고 다시 시작" : "다시 태어나기")
                        .font(.subheadline.weight(.semibold))
                    Text(drafted
                         ? "프로를 포기하고 새 선수로 시작합니다. 남길 기억을 고르게 됩니다."
                         : "\(career.inheritance.lifeNumber)회차를 기억 \(career.inheritance.memories.count)장과 함께 시작합니다.")
                        .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: BaseballMetrics.minimumTapTarget)
            .accessibilityIdentifier("hs.rebirth")
        }
    }
}

/// 화면의 주 행동. 디자인 시스템의 라임 알약 CTA를 쓴다.
struct PrimaryButton: View {
    let title: String
    /// UI 테스트가 문구 변경에 흔들리지 않도록 붙이는 안정적인 식별자.
    var identifier: String?
    let action: () -> Void

    init(title: String, identifier: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.identifier = identifier
        self.action = action
    }

    var body: some View {
        PrimaryPill(title: title, identifier: identifier, action: action)
    }
}

/// 고교 3년의 경기 기록.
///
/// 직접 던진 경기와 자동으로 흘러간 팀 경기를 나눠서 보여 준다. 섞어 놓으면 "내가 만든
/// 성적"이라는 감각이 사라지고, 그러면 자동 경기를 넣은 의미가 없다.
private struct SeasonRecordCard: View {
    let log: [ProGameLine]

    private var played: [ProGameLine] { log.filter(\.played) }
    private var auto: [ProGameLine] { log.filter { !$0.played } }

    var body: some View {
        BaseballCard(title: "시즌 기록") {
            VStack(alignment: .leading, spacing: 12) {
                if !played.isEmpty { summary(title: "직접 등판", lines: played, accent: BaseballTheme.action) }
                if !auto.isEmpty { summary(title: "팀 경기", lines: auto, accent: BaseballTheme.textTertiary) }
                Text("최근 경기")
                    .eyebrowStyle(BaseballTheme.textTertiary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.suffix(5).reversed()) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(line.season)학년")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text(GameLineFormat.role(line))
                                .font(.footnote.weight(.semibold).monospacedDigit())
                            Spacer()
                            Text(GameLineFormat.score(line))
                                .font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            if let decision = GameLineFormat.decisionLabel(line.decision) {
                                Text(decision)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(GameLineFormat.accessibilityLabel(line))
                    }
                }
            }
            .accessibilityIdentifier("hs.seasonRecord")
        }
    }

    private func summary(title: String, lines: [ProGameLine], accent: Color) -> some View {
        let outs = lines.reduce(0) { $0 + $1.outs }
        let strikeouts = lines.reduce(0) { $0 + $1.strikeouts }
        let walks = lines.reduce(0) { $0 + $1.walks }
        let runs = lines.reduce(0) { $0 + $1.runsAllowed }
        return VStack(alignment: .leading, spacing: 3) {
            Text(title).eyebrowStyle(accent)
            Text("\(lines.count)경기 · \(outs / 3)이닝 · \(strikeouts)K \(walks)BB \(runs)실점")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            Text("9이닝당 실점 \(GameLineFormat.runsPerNine(outs: outs, runs: runs))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 평가 항목을 줄바꿈하며 늘어놓는다. 항목 수가 회차마다 달라서 고정 열 배치가 맞지 않는다.
private struct FlowRow: View {
    let items: [String]

    var body: some View {
        // 두 개씩 짝지어 놓는다. iOS 16의 Layout 프로토콜까지 갈 만큼 복잡한 배치가 아니다.
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { index in
                HStack(spacing: 14) {
                    ForEach(items[index..<min(index + 2, items.count)], id: \.self) { item in
                        Text(item)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(
                                item.contains("-") ? BaseballTheme.negative : BaseballTheme.textSecondary
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("평가 항목: " + items.joined(separator: ", "))
    }
}
