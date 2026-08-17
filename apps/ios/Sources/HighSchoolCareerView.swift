import SwiftUI
import SimulationCore
import UIKit

/// 고교 커리어 10단계 화면. 게임 제목("야구 못하면 또 환생함")의 본편이다.
struct HighSchoolCareerView: View {
    let career: HighSchoolCareerStore
    /// 지명을 받고 프로로 넘어갈 때 호출된다.
    let onEnterPro: (DraftResultSnapshot, PitcherSnapshot, PlayerIdentitySnapshot) -> Void
    /// 이 회차로 프로에 이미 진출했는가. 은퇴 뒤 돌아왔을 때 다시 들어가지 못하게 한다.
    var hasEnteredPro = false
    var weekly: WeeklyProgramStore = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var achievements = AchievementStore.shared
    /// 오프닝을 넘겼는가. 저장하지 않는다 — 커리어를 지우면 다시 보는 것이 맞다.
    @State private var openingDismissed = false
    /// 드래프트 호명 연출. 결과가 **방금 나온** 순간에만 켠다.
    @State private var draftReveal: DraftReveal?
    /// 환생 스탬프를 띄울 회차. 기억을 확정하고 다음 회차로 넘어가는 순간에만 켠다.
    @State private var rebirthStamp: RebirthStamp?
    /// 현재 선수의 스킬 진행을 어느 국면에서든 확인하는 시트.
    @State private var skillTreePreview: SkillTreePreview?
    /// 복귀 알림 권유 카드를 지금 띄우는가. 한 번 답하면 이 세션에서는 다시 묻지 않는다.
    @State private var showsReminderNudge = DailyReminder.shouldOfferOptIn()
    @Environment(\.requestReview) private var requestReview
    @Environment(\.gameCopyResolver) private var copyResolver

    /// A chapter goal is only honest when the chapter gives the player an official game in
    /// which strikeouts can be earned. This mirrors the existing view condition as a pure policy.
    static func showsChapterGoal(
        phase: HighSchoolCareerPhase,
        draftResult: DraftResultSnapshot?,
        chapterNumber: Int,
        schedule: CareerScheduleSnapshot?
    ) -> Bool {
        guard draftResult == nil, phase != .awakening else { return false }
        return (schedule ?? .fixedDefault).hasImportantGame(inChapter: chapterNumber)
    }

    /// `fullScreenCover(item:)`가 요구하는 식별 가능한 값.
    struct RebirthStamp: Identifiable {
        let lifeNumber: Int
        /// 정산 화면에서 곧장 온 스탬프인지 값 자체에 싣는다. 별도 `@State`로 두면
        /// cover가 만들어지는 프레임과 플래그 갱신 프레임이 엇갈려 설정 화면으로 빠질 수 있다.
        var startsImmediately = false
        var id: Int { lifeNumber }
    }

    struct DraftReveal: Identifiable {
        let result: DraftResultSnapshot
        let playerName: String
        let careerID: String
        var id: String { careerID }
    }

    struct SkillTreePreview: Identifiable {
        let id = UUID()
        let selected: [AwakeningID]
        let sparks: Int?
        let beforeFirstGame: Bool
    }
    private var audio: GameAudio { .shared }

    var body: some View {
        Group {
            switch career.loadState {
            case .loading:
                AppLoadingView()
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
                    Label {
                        Text(verbatim: copyResolver.resolve(.careerErrorTitle))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(
                        verbatim: copyResolver.language == .korean
                            ? message : copyResolver.resolve(.careerErrorBody)
                    )
                } actions: {
                    // 비파괴 출구가 먼저다. 시드 오타 하나로 도달하는 화면의 유일한
                    // 버튼이 "전 회차 삭제"면 그건 함정이다(4차 패널 P0).
                    PrimaryPill(title: copyResolver.resolve(.careerErrorRetry), identifier: "hs.retry") {
                        career.returnToSetup()
                    }
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Text(verbatim: copyResolver.resolve(.careerErrorRestart))
                    }
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("hs.restart")
                    .confirmationDialog(
                        copyResolver.resolve(.careerErrorResetTitle),
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button(role: .destructive) {
                            career.deleteCareer()
                        } label: {
                            Text(verbatim: copyResolver.resolve(.careerErrorResetConfirm))
                        }
                        // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                        Button { confirmingReset = false } label: {
                            Text(verbatim: copyResolver.resolve(.careerErrorResetCancel))
                        }
                    } message: {
                        Text(verbatim: copyResolver.resolve(.careerErrorResetMessage))
                    }
                }
            case .ready:
                content
            }
        }
        .background(BaseballTheme.canvas)
        // 정점 연출 둘. 회차당 한 번뿐이라 **전면**을 쓴다.
        //
        // `.overlay`가 아니라 `fullScreenCover`인 이유: 이 화면은 탭 바 안에 있어서
        // 오버레이로 덮으면 탭 바가 그 위에 남고, 화면 맨 아래의 주 행동 버튼이 탭 바에
        // 가려 눌리지 않는다. 실제로 그렇게 만들었다가 UI 테스트가 막혔다.
        .fullScreenCover(item: $draftReveal) { reveal in
            // 호명 그 순간의 카드를 함께 넘긴다 — 감정 최고점에서 바로 자랑할 수 있게.
            DraftRevealView(
                result: reveal.result,
                playerName: reveal.playerName,
                shareRecord: career.state.map { state in
                    HighSchoolCareerStore.lifeRecord(
                        from: state, memories: career.selectedMemories,
                        previous: career.inheritance,
                        nicknames: career.nicknames, chronicle: career.chronicle,
                        personality: career.personality,
                        bondMemories: career.bondMemories,
                        startingPitcher: career.careerStartingPitcher
                    )
                }
            ) { draftReveal = nil }
        }
        // **결과가 나오는 순간**에만 연출한다. 조건식(`draftResult != nil`)으로 띄우면
        // 기억을 고르는 내내 조건이 참이라 화면이 계속 덮인다. `onChange`는 값이 바뀔 때만
        // 불리므로, 저장본을 다시 열었을 때 3년 전의 호명 장면이 되풀이되지도 않는다.
        .onChange(of: career.state?.draftResult?.evaluationScore) { previous, current in
            guard previous == nil, current != nil,
                  let state = career.state, let draft = state.draftResult else { return }
            draftReveal = DraftReveal(
                // 3년의 정산 장면이니 별명을 함께 부른다 — "'제로' 김솔".
                result: draft,
                playerName: HighSchoolConclusionPresentation.localizedDisplayName(
                    baseName: state.identity.name, nicknames: career.nicknames, resolver: copyResolver
                ),
                careerID: state.careerID
            )
        }
        // 스탬프가 **먼저** 뜨고, 닫히면서 회차를 넘긴다.
        //
        // 반대로(회차를 먼저 넘기고 스탬프를 띄우면) 화면이 갈아 끼워지는 순간에 전면
        // 화면을 올리는 셈이라 표시가 들쭉날쭉했다. 연출이 곧 전환이면 그런 경합이 없다.
        .sheet(item: $skillTreePreview) { preview in
            SkillTreeSheet(
                selected: preview.selected,
                sparks: preview.sparks,
                beforeFirstGame: preview.beforeFirstGame
            )
        }
        .fullScreenCover(item: $rebirthStamp) { stamp in
            RebirthStampView(lifeNumber: stamp.lifeNumber) {
                rebirthStamp = nil
                // 정산 화면에서 바로 온 경우엔 설정을 건너뛰고 같은 조건으로 시작한다.
                if stamp.startsImmediately {
                    career.beginNextLife()
                    career.startQuickRebirth(entryPoint: "recap")
                } else {
                    career.beginNextLife()
                }
            }
        }
        // 3년 돌아보기 — 기억을 확정한 순간 위업과 야구혼이 폭발한다. 조용한 전환은
        // 로그라이트의 끝이 아니다: 정산이 다음 회차를 시작하는 이유다.
        .fullScreenCover(item: Binding(
            get: { career.pendingRecap },
            set: { if $0 == nil { career.pendingRecap = nil } }
        )) { recap in
            RunRecapView(
                recap: recap,
                onDismiss: { career.pendingRecap = nil },
                // 설정을 다시 물을 것이 없는 회차는 정산 화면에서 곧장 다음 판으로 간다.
                onQuickRebirth: career.quickRebirthPreset == nil ? nil : {
                    career.pendingRecap = nil
                    rebirthStamp = RebirthStamp(
                        lifeNumber: career.inheritance.lifeNumber,
                        startsImmediately: true
                    )
                },
                onSaveIntent: { intent in
                    _ = career.saveNextRunIntent(intent)
                }
            )
        }
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
        // 별점 요청 — 감정이 양(+)인 순간(첫 무실점 이닝·좋은 3년 마무리·3회차 진입)에
        // 스토어가 신호를 올린다. 신호를 올릴지 말지는 이미 ReviewPrompt가 걸렀으므로
        // 여기서는 그대로 연다.
        .onChange(of: career.reviewMoment) { _, _ in
            requestReview()
        }
    }

    /// 성장 연출 자동 스크롤 앵커.
    private static let celebrationAnchor = "career.celebration"
    /// 훈련을 누른 직후 반드시 화면 안에 들어와야 하는 결과 카드 앵커.
    private static let trainingResultAnchor = "career.trainingResult"
    /// 관계·경기·각성처럼 국면이 바뀐 뒤 이어 할 주 행동의 앵커.
    private static let phaseAnchor = "career.phase"

    /// 한 번의 진행에서 스크롤이 어디로 가야 하는지 판단할 최소 상태.
    ///
    /// `feedbackTrigger`만 보면 이전 훈련 결과가 남아 있는 채 관계 선택을 했을 때도
    /// 훈련 결과로 돌아가 버린다. 누적 훈련 수와 국면을 함께 비교해야 방금 일어난
    /// 동작과 화면에 남아 있는 과거 결과를 구분할 수 있다.
    private struct ProgressScrollState: Equatable {
        let careerID: String
        let phase: String
        let trainingsCompleted: Int
        let feedbackTrigger: Int
    }

    /// 전체 삭제 확인. 파괴적 출구는 반드시 한 번 더 묻는다.
    @State private var confirmingReset = false

    @ViewBuilder private var content: some View {
        if let state = career.state {
            if state.phase == .prologue, let session = career.tutorialSession {
                PitchView(session: session, onFinish: career.finishTutorialPitch,
                          onAbort: career.finishTutorialPitch, isPractice: true,
                          onRetry: career.retryTutorialPitch)
            } else if state.phase == .importantGame, let session = career.pitchSession {
                PitchView(session: session, onFinish: career.finishImportantGame,
                          onAbort: { _ = career.abandonImportantGame() })
            } else {
                let scrollState = ProgressScrollState(
                    careerID: state.careerID,
                    phase: state.phase.rawValue,
                    trainingsCompleted: state.totalTrainingsCompleted,
                    feedbackTrigger: career.feedbackTrigger
                )
                ScrollViewReader { proxy in
                ScrollView {
                    // 이 화면은 많아야 몇 개의 큰 카드만 가진다. LazyVStack은 이 정도
                    // 목록에서 얻는 이득이 없고, 훈련 카드가 더 짧은 관계·각성 카드로
                    // 바뀌는 순간 추정 높이와 기존 하단 오프셋이 어긋나 빈 캔버스를
                    // 보여 줄 수 있다. 모든 카드 높이를 즉시 아는 VStack으로 범위를
                    // 정확히 계산해 스크롤이 콘텐츠 밖에 남지 않게 한다.
                    VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        // 회차 번호는 **스냅숏**에서 읽는다.
                        //
                        // 예전에는 스토어의 계승분(`inheritance.lifeNumber`)을 그대로 썼다. 그건
                        // "다음에 시작할 회차"의 번호라, 기억을 확정한 순간 1 늘어난다. 그래서
                        // 1회차의 마지막 화면(완료)에 "2회차"라고 적혀 있었다 — 아직 끝나지도
                        // 않은 회차가 다음 번호를 미리 달고 있었던 셈이다.
                        ChapterHeader(state: state, lifeNumber: state.lifeNumber)

                        if state.phase != .awakening {
                            SkillTreeSummaryRow(selected: state.selectedAwakenings) {
                                skillTreePreview = SkillTreePreview(
                                    selected: state.selectedAwakenings,
                                    sparks: state.awakeningSparks,
                                    beforeFirstGame: state.performance.importantGamesCompleted == 0
                                )
                            }
                        }

                        if !achievements.freshlyUnlocked.isEmpty {
                            AchievementBanner(achievements: achievements.freshlyUnlocked) {
                                achievements.acknowledge()
                            }
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        // 만개는 성장 축하보다 앞에 온다. 같은 훈련에서 둘 다 나면
                        // 먼저 읽어야 하는 것은 "벽이 열렸다"는 쪽이다.
                        Color.clear.frame(height: 0).id(Self.celebrationAnchor)
                        // 훈련 결과는 주 행동 바로 위의 전용 패널이 맡는다(`TrainingResultPanel`).
                        // 같은 성장·만개를 이 위쪽에도 중복 표시하면 결과가 두 군데로 갈라지므로,
                        // 훈련 영수증이 없는 관계·경기 성장만 이 흐름에 남긴다.
                        if career.trainingReceipt == nil {
                            if let bloom = career.pendingBloom {
                                BloomCelebrationView(ability: bloom.ability, grade: bloom.grade) {
                                    career.acknowledgeBloom()
                                }
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            }
                            if !career.pendingGains.isEmpty {
                                GrowthCelebrationView(gains: career.pendingGains,
                                                      jackpot: career.result?.snapshot.lastTraining?.jackpot ?? false,
                                                      onDismiss: career.acknowledgeGains)
                                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            } else if let summary = career.lastSummary {
                                SummaryBanner(
                                    summary: HighSchoolPresentation.localizedStoreSummary(
                                        summary,
                                        career: career,
                                        state: state,
                                        resolver: copyResolver
                                    ),
                                    cue: career.feedbackCue
                                )
                            }
                        }
                        // 3년에 세 번뿐인 각성 앞에서는 주변 소음을 접는다(QA P2-2) —
                        // 되돌릴 수 없는 선택이 목록 한 줄로 보이면 무게가 사라진다.
                        if state.phase != .awakening {
                            if !career.buzz.isEmpty {
                                CommunityBuzzCard(reactionLines: career.buzz)
                            }
                            if !career.worldNews.isEmpty {
                                CommunityBuzzCard(newsLines: career.worldNews)
                            }
                        }
                        if state.performance.importantGamesCompleted >= 1,
                           state.phase != .importantGame, state.phase != .awakening,
                           state.phase != .prologue {
                            WeeklyProgramSummaryRow(store: weekly)
                        }
                        // 복귀 알림 권유 — 첫 중요 경기를 끝낸 직후(감정이 양)에 딱 한 번.
                        if state.performance.importantGamesCompleted >= 1,
                           state.phase != .importantGame, state.phase != .awakening,
                           showsReminderNudge {
                            ReminderNudgeCard(
                                onEnable: {
                                    DailyReminder.enable(source: "after_first_game")
                                    showsReminderNudge = false
                                },
                                onDismiss: {
                                    DailyReminder.declineOptIn()
                                    showsReminderNudge = false
                                }
                            )
                        }
                        // 걸어 둔 약속 — 내기는 눈앞에 있어야 내기다.
                        if state.draftResult == nil, state.phase != .awakening,
                           let pledge = career.pledge {
                            let progress = pledge.progress(in: .init(
                                state: state, rivalLedger: career.rivalLedger
                            ))
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(BaseballTheme.milestone)
                                    Text(
                                        verbatim: copyResolver.resolve(
                                            .pledgeDashboardTitle,
                                            arguments: [.userText(LegacyPresentation.pledgeTitle(
                                                pledge, resolver: copyResolver
                                            ))]
                                        )
                                    )
                                        .font(.footnote.weight(.bold))
                                    Spacer(minLength: 0)
                                    Text("\(progress.ratioPermille / 10)%")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                                Text(
                                    verbatim: LegacyPresentation.pledgeProgress(
                                        progress, resolver: copyResolver
                                    )
                                )
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                ProgressView(value: Double(progress.ratioPermille), total: 1_000)
                                    .tint(BaseballTheme.milestone)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                LegacyPresentation.pledgeAccessibility(
                                    pledge: pledge, progress: progress, carried: false,
                                    resolver: copyResolver
                                )
                            )
                        }
                        // 드래프트가 끝난 회차에 챕터 숙제는 소음이다. 각성 국면도 접는다.
                        if state.draftResult == nil, state.phase != .awakening {
                            if TournamentBracket.isTournamentChapter(state.chapter.number),
                               let school = state.school {
                                TournamentCard(state: state, school: school)
                            }
                            // 공식 경기가 없는 장에서는 탈삼진 숙제를 내지 않는다 —
                            // 던질 기회를 안 주고 "삼진 5개"를 네 화면에서 반복하면,
                            // 게임이 지키지 못할 약속을 하는 것이 된다.
                            if Self.showsChapterGoal(
                                phase: state.phase,
                                draftResult: state.draftResult,
                                chapterNumber: state.chapter.number,
                                schedule: state.schedule
                            ) {
                                ChapterGoalCard(state: state, career: career)
                            }
                        }

                        // 훈련 결과는 **주 행동 바로 위**에 선다.
                        //
                        // 이 목록의 맨 아래가 "훈련하기"다. 결과를 주 행동 바로 위에 두고
                        // 명시적 앵커로 이동하면, 국면이 바뀌어 카드 높이가 줄어도 결과와
                        // 다음 행동이 같은 흐름에 이어진다.
                        if let receipt = career.trainingReceipt {
                            TrainingResultPanel(receipt: receipt,
                                                onDismiss: career.acknowledgeTrainingReceipt)
                                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                                .id(Self.trainingResultAnchor)
                        }

                        phaseBody(state: state)
                            .id(Self.phaseAnchor)
                        // 선수의 말은 첫 경기 이후 실제 갈림길·건강 신호에서만 보이고,
                        // 그 국면의 주 행동보다 아래에 둔다. 상시 상단 카드가 진행을 밀어내지 않는다.
                        if let presentation = PlayerBondStory.heartlinePresentation(
                            for: state,
                            personality: career.personality
                        ) {
                            PlayerHeartCard(
                                state: state,
                                presentation: presentation,
                                bondMemories: career.bondMemories
                            )
                        }
                    }
                    .padding(BaseballMetrics.gutter)
                    // 완료·유산처럼 긴 화면의 마지막 CTA가 떠 있는 탭 바 뒤로 숨지 않게
                    // 그만큼을 비워 둔다. 12pt로는 모자랐다 — 지명받은 완료 화면에서
                    // 마지막 버튼과 선수의 속마음이 탭 바에 깔려, 스크롤을 끝까지 내려도
                    // 누를 수 없었다.
                    .safeAreaPadding(.bottom, BaseballMetrics.floatingTabBarClearance)
                }
                // 이 화면은 국면마다 본문 높이가 크게 달라진다. 회차뿐 아니라 국면도
                // 스크롤 정체성에 넣어, 훈련 화면의 깊은 하단 위치가 더 짧은 관계·각성
                // 화면에 남아 빈 캔버스를 보여 주지 않게 한다.
                .id("\(state.careerID)|\(state.phase.rawValue)")
                .background(BaseballTheme.canvas)
                // 스크롤 콘텐츠가 상태바 밑을 그대로 지나면 시계와 제목이 겹친다(QA P2-3).
                .topStatusScrim()
                // 국면 전환은 즉시 갱신한다. 화면 전체를 덮는 커튼은 종료 애니메이션이
                // 취소되면 탭 바만 남은 검은 화면이 될 수 있어 사용하지 않는다.
                // 성장·만개는 스택 위쪽에서 터지는데 유저는 방금 맨 아래 "훈련하기"를
                // 눌렀다 — 게임의 최다 보상이 화면 밖에서 소비되고 있었다(3차 패널 P1).
                .onChange(of: scrollState) { previous, current in
                    let sameCareer = previous.careerID == current.careerID
                    let completedTraining = sameCareer
                        && current.trainingsCompleted > previous.trainingsCompleted
                    let changedPhase = sameCareer && current.phase != previous.phase
                    let receivedFeedback = sameCareer
                        && current.feedbackTrigger != previous.feedbackTrigger

                    // 상태 변경과 같은 프레임에 scrollTo를 호출하면 새 결과 카드가 아직
                    // 배치되기 전일 수 있다. 한 번 양보해 갱신된 VStack의 정확한 높이와
                    // 앵커가 준비된 다음 이동한다. 최신 진행만 화면을 움직이게 해 빠른
                    // 연속 입력에서도 오래된 Task가 스크롤을 되돌리지 않는다.
                    Task { @MainActor in
                        await Task.yield()
                        guard let latest = career.state,
                              latest.careerID == current.careerID else { return }

                        if completedTraining {
                            // 묶음 훈련은 마지막 훈련을 저장한 뒤 묶음 요약용
                            // feedbackTrigger를 한 번 더 올린다. 그 값까지 같아야 한다고
                            // 요구하면 정상적인 훈련 스크롤도 오래된 요청으로 오판해
                            // 취소된다. 대신 정확한 훈련 번호를 확인해 앞선 반복에서 만든
                            // Task가 묶음의 최종 결과를 다시 밀어내지 못하게 한다.
                            guard latest.totalTrainingsCompleted == current.trainingsCompleted,
                                  career.trainingReceipt != nil else { return }
                            // 애니메이션 도중 높이가 다시 바뀌는 여지를 없애고 결과를 즉시
                            // 화면 상단에 둔다. 결과와 다음 행동이 이어져 게임을 계속할 수 있다.
                            proxy.scrollTo(Self.trainingResultAnchor, anchor: .top)
                        } else if changedPhase {
                            guard latest.phase.rawValue == current.phase else { return }
                            proxy.scrollTo(Self.phaseAnchor, anchor: .top)
                        } else if receivedFeedback,
                                  latest.totalTrainingsCompleted == current.trainingsCompleted,
                                  career.feedbackTrigger == current.feedbackTrigger,
                                  career.trainingReceipt == nil,
                                  career.pendingBloom != nil || !career.pendingGains.isEmpty {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                                proxy.scrollTo(Self.celebrationAnchor, anchor: .top)
                            }
                        }
                    }
                }
                }
            }
        }
    }

    @ViewBuilder private func phaseBody(state: HighSchoolCareerSnapshot) -> some View {
        switch state.phase {
        case .prologue:
            if !career.isChallengeRun,
               let previous = career.archive.first,
               previous.lifeNumber < state.lifeNumber {
                PreviousPlayerLetterCard(record: previous, currentPlayerName: state.identity.name)
                if let comparison = career.inheritedStartComparison(for: state, previous: previous) {
                    InheritedStartComparisonCard(comparison: comparison)
                }
            }
            PrologueCard(
                state: state,
                lifeNumber: state.lifeNumber,
                onThrow: career.beginTutorialPitch,
                onSkip: career.completePrologue
            )
        case .schoolSelection:
            if !career.isChallengeRun && !career.pledgeDecided {
                PledgeCard(state: state, intent: career.nextRunIntent,
                           rivalLedger: career.rivalLedger, isFirstLife: state.lifeNumber == 1,
                           onChoose: { pledgeID in
                               _ = career.choosePledge(pledgeID)
                           })
            }
            SchoolSelectionCard(
                options: state.schoolOptions,
                region: state.identity.region,
                onChoose: career.chooseSchool
            )
        case .training:
            // 챕터 누적 한 줄 — 100번의 +1이 낱장으로 흩어지지 않게 "한 단위"를 만든다.
            if career.chapterTrainingCount > 0 {
                let summary = career.chapterGains
                    .sorted { $0.key < $1.key }
                    .map { rawLabel, value in
                        let ability = TalentAbility.allCases.first { $0.label == rawLabel }
                        let label = ability.map { copyResolver.resolve($0.displayCopyToken) }
                            ?? (copyResolver.language == .korean ? rawLabel : GameCopyResolver.unavailableText)
                        return "\(label) +\(value)"
                    }
                    .joined(separator: " · ")
                Text(
                    verbatim: copyResolver.resolve(
                        .trainingTally,
                        arguments: [
                            .integer(career.chapterTrainingCount),
                            .userText(summary.isEmpty ? "" : " — \(summary)"),
                        ]
                    )
                )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hs.training.tally")
            }
            TrainingCard(
                state: state,
                armHealth: career.armHealth,
                onCommit: { focus, intensity, targetPitch in
                    audio.play(.uiSelect)
                    career.commitTraining(focus: focus, intensity: intensity, targetPitch: targetPitch)
                },
                onCommitBlock: { focus, intensity, targetPitch in
                    audio.play(.uiSelect)
                    career.commitTrainingBlock(focus: focus, intensity: intensity, targetPitch: targetPitch)
                }
            )
        case .relationship:
            RelationshipCard(state: state, onRespond: career.resolveRelationship)
        case .importantGame:
            ImportantGameCard(state: state, rivalLedger: career.rivalLedger,
                              onStart: career.beginImportantGame)
        case .awakening:
            AwakeningCard(options: state.awakeningOptions, sparks: state.awakeningSparks,
                          beforeFirstGame: state.performance.importantGamesCompleted == 0,
                          selected: state.selectedAwakenings,
                          onChoose: career.chooseAwakening)
        case .chapterReview:
            ChapterReviewCard(state: state, gains: career.chapterGains,
                              trainingCount: career.chapterTrainingCount, onContinue: career.advanceChapter)
        case .draft:
            DraftCard(state: state, chronicle: career.chronicle, career: career, onResolve: career.resolveDraft)
        case .legacy:
            // challenge 모드는 대부분 미지명으로 끝나 여기로 온다 — 기억 확정(실계승 덮어쓰기)
            // 대신 도전 마감으로 보낸다(5차 패널 P0).
            if career.isChallengeRun {
                ChallengeEndCard(state: state) { career.endChallengeRun() }
            } else {
                LegacyCard(career: career, state: state)
            }
        case .completed:
            if career.isChallengeRun {
                ChallengeEndCard(state: state) { career.endChallengeRun() }
            } else {
                CompletionCard(career: career, state: state, hasEnteredPro: hasEnteredPro, onEnterPro: onEnterPro) {
                    rebirthStamp = RebirthStamp(lifeNumber: career.inheritance.lifeNumber)
                }
            }
        }
    }
}

