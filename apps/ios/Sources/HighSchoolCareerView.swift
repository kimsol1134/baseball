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
                            PlayerHeartCard(state: state, presentation: presentation)
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

// MARK: - 훈련 결과

/// 방금 끝난 훈련이 무엇을 남겼는지, 누른 자리에서 그대로 읽히는 카드.
///
/// 목록의 **주 행동 바로 위**에 선다(`content` 참고). 화면 아래 고정 패널로도 만들어 봤지만
/// 그 방식은 화면 하단을 통째로 점유해 아래 카드의 조작을 가렸다 — UI 스모크가 훈련
/// 버튼을 못 찾고 회차가 그 자리에서 멈췄다. 흐름 안의 카드면 결과와 다음 행동이 세로로
/// 이어져, 스크롤 없이 읽고 그대로 다음 훈련을 누른다.
///
/// 성장이 0인 훈련도 여기 뜬다. 안 오른 것도 결과이고, 아무것도 안 뜨는 것이 가장 나쁘다.
private struct TrainingResultPanel: View {
    let receipt: HighSchoolCareerStore.TrainingReceipt
    let onDismiss: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var grew: Bool { receipt.gains.contains { $0.after > $0.before } }
    private var accent: Color {
        if receipt.bloom != nil || receipt.jackpot { return BaseballTheme.milestone }
        return grew ? BaseballTheme.action : BaseballTheme.textSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: receipt.bloom != nil ? "sparkles"
                      : grew ? "arrow.up.right.circle.fill" : "checkmark.circle")
                    .foregroundStyle(accent)
                Text(HighSchoolPresentation.localizedTrainingResultTitle(receipt, resolver: copyResolver))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(accent)
                if receipt.opportunityHit {
                    Text(copyResolver.resolve(AppCopyKey.trainingResultOpportunityBadge))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(BaseballTheme.milestone)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(BaseballTheme.milestone.opacity(0.22), in: Capsule())
                }
                Spacer(minLength: 0)
                Button(copyResolver.resolve(AppCopyKey.trainingResultDismiss), action: onDismiss)
                    .font(.footnote.weight(.bold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.training.result.dismiss")
            }

            // 오른 값이 주인공이다. 큰 글자 한 줄이면 스치듯 봐도 읽힌다.
            Text(HighSchoolPresentation.localizedTrainingResultHeadline(receipt, resolver: copyResolver))
                .font(BaseballType.scoreboard)
                .foregroundStyle(grew ? accent : BaseballTheme.textSecondary)
                .accessibilityIdentifier("hs.training.result.headline")

            ForEach(receipt.gains.filter { $0.after > $0.before }) { gain in
                Text(HighSchoolPresentation.localizedTrainingGainRow(gain, resolver: copyResolver))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
            }

            if let bloom = receipt.bloom {
                Text(HighSchoolPresentation.localizedTrainingResultBloom(bloom, resolver: copyResolver))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(HighSchoolPresentation.localizedTrainingResultDetail(receipt, resolver: copyResolver))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 피로는 훈련의 가격이다. 결과와 같은 자리에서 보여야 다음 강도를 고를 수 있다.
            HStack(spacing: 6) {
                Image(systemName: "battery.50").font(.caption2)
                Text(HighSchoolPresentation.localizedTrainingFatigue(receipt, resolver: copyResolver))
                    .font(.caption.monospacedDigit().weight(.semibold))
            }
            .foregroundStyle(receipt.fatigueAfter >= 70 ? BaseballTheme.warning : BaseballTheme.textTertiary)
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (receipt.bloom != nil || receipt.jackpot
             ? BaseballTheme.milestone.opacity(0.14)
             : grew ? BaseballTheme.actionSoft : BaseballTheme.surface),
            in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(accent, lineWidth: receipt.bloom != nil || receipt.jackpot ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hs.training.result")
        .onAppear {
            if receipt.bloom != nil || receipt.jackpot { GameAudio.shared.play(.milestone) }
        }
    }
}

/// 복귀 알림 권유. 정직하게 무엇을 언제 보내는지 적고, 거절도 한 탭이다.
private struct ReminderNudgeCard: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let title = copyResolver.resolve(AppCopyKey.reminderNudgeTitle)
        let body = copyResolver.resolve(AppCopyKey.reminderNudgeBody)
        let enable = copyResolver.resolve(AppCopyKey.reminderNudgeEnable)
        let decline = copyResolver.resolve(AppCopyKey.reminderNudgeDecline)
        let accessibility = copyResolver.resolve(
            AppCopyKey.reminderNudgeAccessibility,
            arguments: [
                .userText(title), .userText(body),
                .userText(enable), .userText(decline),
            ]
        )
        BaseballCard(title: title, tone: .raised) {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: body)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PrimaryPill(title: enable, identifier: "hs.reminder.enable", action: onEnable)
                    Button { onDismiss() } label: {
                        Text(verbatim: decline)
                    }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .accessibilityIdentifier("hs.reminder.decline")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: accessibility))
        .onAppear {
            GameAnalytics.logOnce(.reminderOfferShown, ["source": "after_first_game"])
        }
    }
}

// MARK: - Challenge 마감

/// challenge 모드의 끝 — 기록·계승 어디에도 반영되지 않는 판이므로 결과만 정직하게
/// 보여 주고 닫는다. 공유 카드의 "이 시드로 지명 가능?"에 대한 답이 이 화면이다.
private struct ChallengeEndCard: View {
    let state: HighSchoolCareerSnapshot
    let onClose: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var outcomeTitle: String {
        HighSchoolPresentation.localizedChallengeOutcome(
            state.draftResult?.outcome,
            resolver: copyResolver
        )
    }

    var body: some View {
        let eyebrow = copyResolver.resolve(AppCopyKey.challengeEndEyebrow)
        let score = copyResolver.resolve(
            AppCopyKey.challengeEndScore,
            arguments: [.integer(state.draftResult?.evaluationScore ?? 0)]
        )
        let stats = copyResolver.resolve(
            AppCopyKey.challengeEndStats,
            arguments: [
                .integer(state.performance.importantGamesCompleted),
                .integer(state.performance.strikeouts),
                .integer(state.performance.walks),
                .integer(state.performance.runsAllowed),
            ]
        )
        let disclaimer = copyResolver.resolve(AppCopyKey.challengeEndDisclaimer)
        let closeAction = copyResolver.resolve(AppCopyKey.challengeEndCTA)
        let accessibility = copyResolver.resolve(
            AppCopyKey.challengeEndAccessibility,
            arguments: [
                .userText(eyebrow), .userText(outcomeTitle), .userText(score),
                .userText(stats), .userText(disclaimer),
            ]
        )
        let closeHint = copyResolver.resolve(AppCopyKey.challengeEndCloseHint)
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text(verbatim: eyebrow).eyebrowStyle(BaseballTheme.milestone)
            BaseballCard(title: outcomeTitle,
                         tone: state.draftResult?.outcome == .drafted ? .milestone : .raised) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: score)
                        .font(.title3.weight(.heavy).monospacedDigit())
                    Text(verbatim: stats)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            Text(verbatim: disclaimer)
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: closeAction, identifier: "hs.challenge.close", action: onClose)
                .accessibilityHint(Text(verbatim: closeHint))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: accessibility))
        .accessibilityIdentifier("hs.challenge.end")
    }
}

// MARK: - 머리말

private struct ChapterHeader: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int
    @State private var windExpanded = false
    @Environment(\.gameCopyResolver) private var copyResolver

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
            let chapterCopy = state.chapter.copyDescriptor
            let actTitle = copyResolver.resolve(chapterCopy.actTitleToken)
            let season = copyResolver.resolve(chapterCopy.seasonToken)
            let eyebrow = copyResolver.resolve(
                lifeNumber > 1 ? AppCopyKey.chapterHeaderEyebrowRepeat : AppCopyKey.chapterHeaderEyebrowFirst,
                arguments: lifeNumber > 1
                    ? [.integer(lifeNumber), .userText(actTitle), .integer(state.chapter.schoolYear), .userText(season)]
                    : [.userText(actTitle), .integer(state.chapter.schoolYear), .userText(season)]
            )
            KeyArtHeader(
                art: Self.art(for: state.phase),
                // 1회차에는 회차 표시를 하지 않는다. 처음 하는 사람에게 "1회차"는 아무 뜻이 없고,
                // 반복하는 게임이라는 사실은 한 번 죽어 봐야 의미가 생긴다.
                eyebrow: eyebrow,
                title: state.school.map {
                    copyResolver.resolve(
                        AppCopyKey.chapterHeaderTitle,
                        arguments: [
                            .userText(HighSchoolPresentation.localizedSchoolName(
                                $0, rawRegion: state.identity.region, resolver: copyResolver
                            )),
                            .userText(copyResolver.resolve(chapterCopy.titleToken)),
                        ]
                    )
                } ?? copyResolver.resolve(chapterCopy.titleToken)
            )
            HStack(spacing: 10) {
                // 주인공의 얼굴. 게임에서 가장 자주 보는 화면인데 정작 주인공이 없었다.
                // 1학년(챕터 1~3)은 앳된 얼굴, 2학년부터는 에이스 얼굴 — 성장이 눈에 보인다.
                PortraitView(seed: state.identity.name, role: .player, size: 46,
                             playerStage: state.chapter.schoolYear <= 1 ? .freshman : .ace)
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricFatigue), value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricTeamTrust), value: "\(state.relationshipTrust)")
                Metric(title: copyResolver.resolve(AppCopyKey.chapterMetricTraining), value: "\(state.totalTrainingsCompleted)")
            }
            if state.phase != .prologue {
                let wind = CareerWindPresentationCatalog.descriptor(for: state.careerWind)
                let windTitle = copyResolver.resolve(wind.titleToken)
                let windDetail = copyResolver.resolve(wind.detailToken)
                let effects = wind.effectDescriptors.map { copyResolver.resolve($0.token) }
                let windAction = copyResolver.resolve(
                    windExpanded ? AppCopyKey.chapterWindCollapse : AppCopyKey.chapterWindExpand
                )
                Button { windExpanded.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                        // localization-safe: resolved-copy
                        Text(windTitle)
                            .font(.caption.weight(.bold))
                        Spacer(minLength: 0)
                        Image(systemName: windExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(BaseballTheme.information)
                    .padding(.horizontal, 10)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .background(BaseballTheme.surfaceRaised, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("hs.wind.chip")
                .accessibilityLabel(
                    copyResolver.resolve(
                        AppCopyKey.chapterWindAccessibility,
                        arguments: [.userText(windTitle), .userText(windAction)]
                    )
                )

                if windExpanded {
                    VStack(alignment: .leading, spacing: 3) {
                        // localization-safe: resolved-copy
                        Text(windDetail)
                        ForEach(Array(effects.enumerated()), id: \.offset) { _, effect in
                            Text(copyResolver.resolve(
                                AppCopyKey.chapterWindEffect,
                                arguments: [.userText(effect)]
                            ))
                        }
                        if effects.isEmpty {
                            Text(copyResolver.resolve(AppCopyKey.prologueWindNeutralExplanation))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
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
    @Environment(\.gameCopyResolver) private var copyResolver

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
        HighSchoolPresentation.localizedSummaryCue(cue, resolver: copyResolver)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // localization-safe: resolved-copy
            Text(label).eyebrowStyle(accent)
            // localization-safe: resolved-copy
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

    @Environment(\.gameCopyResolver) private var copyResolver

    private var opener: PrologueCopyDescriptor {
        ProloguePresentationCatalog.opener(lifeNumber: lifeNumber, rawRegion: state.identity.region)
    }

    private var regionName: String? {
        guard let region = opener.region else { return nil }
        return copyResolver.resolve(AppCopyKey.setupRegionName(for: region))
    }

    private var wind: CareerWindCopyDescriptor {
        CareerWindPresentationCatalog.descriptor(for: state.careerWind)
    }

    private var milestoneTitle: String {
        copyResolver.resolve(
            lifeNumber == 1 ? AppCopyKey.prologueFirstLifeTitle : AppCopyKey.prologueRebirthTitle
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: milestoneTitle, tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    if opener.variant == .firstLife {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.prologueFirstLifeCoachQuote))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(verbatim: copyResolver.resolve(opener, regionName: regionName))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    let windTitle = copyResolver.resolve(wind.titleToken)
                    let windDetail = copyResolver.resolve(wind.detailToken)
                    let effectCopy = wind.effectDescriptors.map { copyResolver.resolve($0.token) }
                    let neutralWindCopy = copyResolver.resolve(AppCopyKey.prologueWindNeutralExplanation)
                    Divider()
                    BaseballCard(
                        title: copyResolver.resolve(
                            AppCopyKey.prologueWindHeading,
                            arguments: [.userText(windTitle)]
                        ),
                        tone: .raised
                    ) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: windDetail)
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(effectCopy.enumerated()), id: \.offset) { _, effect in
                                Text(verbatim: "· \(effect)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.information)
                            }
                            if effectCopy.isEmpty {
                                Text(verbatim: neutralWindCopy)
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            copyResolver.resolve(
                                AppCopyKey.prologueWindAccessibility,
                                arguments: [
                                    .userText(windTitle),
                                    .userText(windDetail),
                                    .userText(effectCopy.isEmpty ? neutralWindCopy : effectCopy.joined(separator: "; ")),
                                ]
                            )
                        )
                    }
                    if !state.karmas.isEmpty {
                        Divider()
                        Text(verbatim: copyResolver.resolve(AppCopyKey.prologueHandicapHeading))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BaseballTheme.warning)
                        ForEach(state.karmas, id: \.self) { karma in
                            let copy = karma.copyDescriptor
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: copyResolver.resolve(copy.titleToken))
                                    .font(.subheadline.weight(.semibold))
                                Text(verbatim: copyResolver.resolve(copy.detailToken))
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            // 주 행동이 능력치 표보다 먼저다 — 첫 화면에서 "다음에 뭘 누르지"가
            // 접힘선 아래에 있으면 유료 게임의 첫 30초를 버리는 것이다(QA P0-1).
            // 이 게임에서 가장 좋은 것은 투구다. 사는 사람이 그걸 두 번째 탭에서 만나게 한다.
            PrimaryButton(
                title: copyResolver.resolve(AppCopyKey.prologueThrow),
                identifier: "hs.prologue.throw",
                action: onThrow
            )
            Button(copyResolver.resolve(AppCopyKey.prologueSkip), action: onSkip)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.prologue.continue")
            BaseballCard(title: copyResolver.resolve(AppCopyKey.prologueCurrentPlayerTitle)) {
                VStack(alignment: .leading, spacing: 10) {
                    // 재능 등급과 한계선을 함께 보여 준다. 이 회차가 어떤 투수인지가
                    // 시작 수치가 아니라 여기서 정해진다.
                    let talent = state.talent ?? .unlimited
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.velocity.displayCopyToken,
                        value: state.pitcher.stuff,
                        talent: talent.stuff
                    )
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.command.displayCopyToken,
                        value: state.pitcher.command,
                        talent: talent.command
                    )
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.breakingBall.displayCopyToken,
                        value: state.pitcher.movement,
                        talent: talent.movement
                    )
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.stamina.displayCopyToken,
                        value: state.pitcher.stamina,
                        talent: talent.stamina
                    )
                    Text(verbatim: copyResolver.resolve(AppCopyKey.prologueAbilityExplanation))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            let wind = state.careerWind
            GameAnalytics.logOnce(
                .careerWindSeen,
                scope: state.careerID,
                properties: [
                    "wind_id": wind.id,
                    "rules_version": state.effectiveWorldRulesVersion.rawValue,
                ]
            )
        }
    }
}

/// The prologue uses the same rating ladder as the rest of the app, but resolves every visible
/// label locally so English never inherits the legacy Korean strings from `AbilityGaugeView`.
private struct PrologueAbilityGauge: View {
    let labelToken: CopyToken
    let value: Int
    let talent: TalentGrade
    var preservesKoreanAccessibility = false

    @Environment(\.gameCopyResolver) private var copyResolver

    private var label: String {
        copyResolver.resolve(labelToken)
    }

    private var talentText: String {
        copyResolver.resolve(
            AppCopyKey.prologueAbilityTalent,
            arguments: [.userText(talent.label)]
        )
    }

    private var ceilingText: String {
        talent == .s
            ? copyResolver.resolve(AppCopyKey.prologueAbilityNoCeiling)
            : copyResolver.resolve(
                AppCopyKey.prologueAbilityCeiling,
                arguments: [.integer(talent.ceiling)]
            )
    }

    private var meaningKey: GameCopyKey {
        switch RatingScale.steps.first(where: { value >= $0.minimum })?.minimum {
        case 75: AppCopyKey.prologueAbilityMeaningBest
        case 65: AppCopyKey.prologueAbilityMeaningProTop
        case 55: AppCopyKey.prologueAbilityMeaningAbovePro
        case 50: AppCopyKey.prologueAbilityMeaningProAverage
        case 47: AppCopyKey.prologueAbilityMeaningRegional
        case 43: AppCopyKey.prologueAbilityMeaningHighSchool
        case 38: AppCopyKey.prologueAbilityMeaningStarter
        case 33: AppCopyKey.prologueAbilityMeaningDeveloping
        default: AppCopyKey.prologueAbilityMeaningFoundations
        }
    }

    private var meaning: String {
        copyResolver.resolve(meaningKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: label).eyebrowStyle(BaseballTheme.textTertiary)
                Text(verbatim: talentText)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BaseballTheme.actionInk)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RatingScale.tone(talent.ceiling), in: Capsule())
                Text(verbatim: ceilingText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                Spacer()
                Text(verbatim: "\(value)")
                    .font(BaseballType.scoreboard)
                    .foregroundStyle(BaseballTheme.textPrimary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    Capsule()
                        .fill(RatingScale.tone(value))
                        .frame(width: max(4, proxy.size.width * RatingScale.position(value)))
                    if talent != .s {
                        Rectangle()
                            .fill(BaseballTheme.borderStrong)
                            .frame(width: 2)
                            .offset(x: proxy.size.width * RatingScale.position(talent.ceiling))
                    }
                }
            }
            .frame(height: 8)
            Text(verbatim: meaning)
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
            if value >= talent.ceiling, talent != .s {
                Text(verbatim: copyResolver.resolve(AppCopyKey.prologueAbilityCeilingReached))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            preservesKoreanAccessibility && copyResolver.language == .korean
                ? copyResolver.resolve(
                    AppCopyKey.chapterReviewAbilityAccessibility,
                    arguments: [
                        .userText(label), .integer(value), .userText(talent.label),
                        .integer(talent.ceiling), .userText(meaning),
                    ]
                )
                : copyResolver.resolve(
                    AppCopyKey.prologueAbilityAccessibility,
                    arguments: [
                        .userText(label), .integer(value), .userText(talentText), .userText(ceilingText),
                    ]
                )
        )
    }
}

/// 학교 선택.
///
/// 확인을 한 번 받는다. 학교는 3년을 통째로 결정하는데 되돌릴 수 없고, 카드를 한 번 누르면
/// 바로 확정됐다. 목록을 훑다가 잘못 눌러 3년을 날리는 일은 실제로 일어나고, 그 사람은 게임을
/// 지운다. 확인 창에서 그 학교의 강점과 감수할 것을 한 번 더 읽힌다.
private struct SchoolSelectionCard: View {
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

private struct TrainingCard: View {
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
            ForEach(TrainingFocus.allCases, id: \.self) { option in
                let isOpportunity = state.trainingOpportunity?.focus == option
                let isSchoolStrength = state.school?.strength == option
                Button { focus = option } label: {
                    HStack(spacing: 12) {
                        Image(systemName: HighSchoolPresentation.focusSymbol(option))
                            .font(.title3)
                            .foregroundStyle(focus == option ? BaseballTheme.selection : BaseballTheme.textSecondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(HighSchoolPresentation.localized(option, resolver: copyResolver)).font(.subheadline.weight(.bold))
                                if isOpportunity {
                                    Text(copyResolver.resolve(AppCopyKey.trainingBadgeOpportunity))
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(BaseballTheme.milestone.opacity(0.25), in: Capsule())
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                                // 학교 특기는 3년 내내 붙는 상수 보너스인데, 학교 선택 화면
                                // 이후로는 어디에도 안 보였다. 기회와 특기가 겹치는 턴을
                                // 알아보는 것이 훈련의 진짜 결정이라 여기 있어야 한다.
                                if isSchoolStrength {
                                    Text(copyResolver.resolve(AppCopyKey.trainingBadgeSchoolStrength))
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(BaseballTheme.action.opacity(0.25), in: Capsule())
                                        .foregroundStyle(BaseballTheme.action)
                                }
                            }
                            Text(HighSchoolPresentation.localizedFocusDetail(option, resolver: copyResolver))
                                .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            if let windEffect = windEffect(for: option, resolver: copyResolver) {
                                // localization-safe: resolved-copy
                                Text(windEffect)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.information)
                            }
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

            if focus == .breakingBall, !breakingBalls.isEmpty {
                let title = copyResolver.resolve(AppCopyKey.trainingPitchPickerTitle)
                BaseballCard(title: title) {
                    Picker(title, selection: $targetPitch) {
                        ForEach(breakingBalls, id: \.self) { pitch in
                            Text(PitchCopy.localized(pitch, resolver: copyResolver)).tag(pitch)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("hs.training.targetPitch")
                }
            }

            BaseballCard(title: copyResolver.resolve(AppCopyKey.trainingIntensityTitle)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(TrainingIntensity.allCases, id: \.self) { option in
                            Button { intensity = option } label: {
                                Text(HighSchoolPresentation.localized(option, focus: focus, resolver: copyResolver))
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

private struct RelationshipCard: View {
    let state: HighSchoolCareerSnapshot
    let onRespond: (RelationshipResponse) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    private var event: CareerEventContent? {
        state.currentRelationshipEvent
    }

    private var eventCopy: RelationshipCardCopyDescriptor? {
        event.map(RelationshipPresentationCatalog.cardDescriptor(for:))
    }

    private var portraitSeed: (seed: String, role: AvatarFace.Role)? {
        guard let event else { return nil }
        return HighSchoolPresentation.relationshipPortraitSeed(category: event.category, state: state)
    }

    private var band: RelationshipVoiceCatalog.TrustBand {
        guard let event else { return .mid }
        return HighSchoolPresentation.relationshipTrustBand(
            for: event,
            manager: state.managerTrust ?? state.relationshipTrust,
            catcher: state.catcherTrust ?? state.relationshipTrust,
            rival: state.rivalTrust ?? state.relationshipTrust,
            resolver: copyResolver
        )
    }

    private var windEffect: String? {
        guard let category = event?.category else { return nil }
        return HighSchoolPresentation.localizedRelationshipWindLine(
            category: category,
            wind: state.careerWind,
            resolver: copyResolver
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 대화가 이 화면의 주인공이다. 예전에는 요약 한 줄이 작은 글씨로 붙고 선택지가
            // 화면을 채워서, 무슨 일이 일어났는지보다 버튼 세 개가 먼저 눈에 들어왔다.
            if let event, let eventCopy {
                let speaker = copyResolver.resolve(eventCopy.event.speakerLabelToken)
                let title = HighSchoolPresentation.localizedRelationshipEventTitle(
                    event,
                    resolver: copyResolver
                )
                let summary = HighSchoolPresentation.localizedRelationshipEventSummary(
                    event,
                    resolver: copyResolver
                )
                let quote = HighSchoolPresentation.localizedRelationshipQuote(
                    event: event,
                    band: band,
                    playerName: state.identity.name,
                    resolver: copyResolver
                )
                let scene = RelationshipCardPresentationPolicy.scene(
                    quote: quote,
                    summary: summary
                )
                let visibleName: String? = switch event.category {
                case "coach":
                    state.school.map {
                        HighSchoolPresentation.localizedSchoolCastName(
                            $0,
                            rawRegion: state.identity.region,
                            role: .coach,
                            resolver: copyResolver
                        )
                    }
                case "catcher":
                    state.school.map {
                        HighSchoolPresentation.localizedSchoolCastName(
                            $0,
                            rawRegion: state.identity.region,
                            role: .catcher,
                            resolver: copyResolver
                        )
                    }
                case "rival":
                    HighSchoolPresentation.localizedRivalName(state.rival, resolver: copyResolver)
                default:
                    nil
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if let portrait = portraitSeed {
                            PortraitView(seed: portrait.seed, role: portrait.role, size: 44)
                        } else {
                            // 사람이 아닌 화자(집·취재·팬·몸 상태…)는 얼굴 대신 상황 그림.
                            // 없는 인물을 지어내지 않으면서 빈 자리도 남기지 않는다.
                            ArtThumb(assetName: "SceneArt-\(event.category)", size: 44, cornerRadius: 8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: speaker).eyebrowStyle(BaseballTheme.information)
                            if let visibleName {
                                Text(verbatim: visibleName).font(.subheadline.weight(.bold))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    Text(verbatim: title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    // 손으로 쓴 대사가 있으면 그 한 줄이 장면 본문이다. 요약을 다시
                    // 보이지 않아 같은 상황을 두 번 읽게 하지 않는다. 대사가 없는 옛
                    // 이벤트만 요약을 본문으로 쓴다.
                    Text(verbatim: scene.visibleLine)
                        .font(.body)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedRelationshipEventAccessibility(
                    speaker: speaker,
                    name: visibleName ?? "",
                    title: title,
                    primaryText: scene.visibleLine,
                    summary: scene.accessibilitySummary,
                    resolver: copyResolver
                )))
            }
            if let windEffect {
                Label {
                    Text(verbatim: windEffect)
                } icon: {
                    Image(systemName: "wind")
                }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.information)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GameCopyText(coreToken: .relationshipPrompt()).font(.headline)
            ForEach(RelationshipResponse.allCases, id: \.self) { response in
                let choiceTitle = event.map {
                    HighSchoolPresentation.localizedRelationshipChoiceTitle(
                        event: $0,
                        response: response,
                        resolver: copyResolver
                    )
                } ?? copyResolver.resolve(.relationshipFallbackChoiceTitle(response: response))
                let choiceDetail = event.map {
                    HighSchoolPresentation.localizedRelationshipChoiceDetail(
                        event: $0,
                        response: response,
                        resolver: copyResolver
                    )
                } ?? copyResolver.resolve(.relationshipFallbackChoiceDetail(response: response))
                let choice = RelationshipCardPresentationPolicy.choice(
                    title: choiceTitle,
                    detail: choiceDetail
                )
                Button { onRespond(response) } label: {
                    Text(verbatim: choice.visibleLine)
                        .font(.subheadline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: BaseballMetrics.minimumTapTarget,
                        alignment: .leading
                    )
                    .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(BaseballTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedRelationshipChoiceAccessibility(
                    title: choice.visibleLine,
                    detail: choice.accessibilityDetail,
                    resolver: copyResolver
                )))
                .accessibilityIdentifier("hs.response.\(response.rawValue)")
            }
        }
    }
}

/// 관계 카드의 시각 정보량과 접근성 정보량을 각각 정한다.
///
/// 순수 규칙으로 두어 대사/요약과 선택/설명이 다시 동시 노출되는 회귀를
/// 뷰를 실행하지 않고도 검증할 수 있게 한다.
enum RelationshipCardPresentationPolicy {
    struct Scene: Equatable {
        let visibleLine: String
        let accessibilitySummary: String
    }

    struct Choice: Equatable {
        let visibleLine: String
        let accessibilityDetail: String
    }

    static func scene(quote: String, summary: String) -> Scene {
        let hasAuthoredQuote = !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Scene(
            visibleLine: hasAuthoredQuote ? quote : summary,
            accessibilitySummary: hasAuthoredQuote ? summary : ""
        )
    }

    static func choice(title: String, detail: String) -> Choice {
        Choice(visibleLine: title, accessibilityDetail: detail)
    }
}

private struct ImportantGameCard: View {
    let state: HighSchoolCareerSnapshot
    /// Structured counts are formatted at the presentation boundary. The persisted ledger and
    /// its Codable shape remain unchanged.
    let rivalLedger: HighSchoolCareerStore.RivalLedger
    let onStart: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 8챕터 — 이 회차에서 그를 상대하는 마지막 마운드다.
    private var isFinalShowdown: Bool { state.chapter.number == 8 }

    private var rivalName: String {
        HighSchoolPresentation.localizedRivalName(state.rival, resolver: copyResolver)
    }

    private var rivalArchetype: String {
        HighSchoolPresentation.localizedRivalArchetype(state.rival, resolver: copyResolver)
    }

    private var rivalSignature: String? {
        HighSchoolPresentation.localizedRivalSignature(state.rival, resolver: copyResolver)
    }

    private var rivalMatchup: String? {
        HighSchoolPresentation.localizedImportantGameCareerMatchup(
            rivalLedger,
            resolver: copyResolver
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if let scenario = state.currentGameScenario {
                let title = HighSchoolPresentation.localizedImportantGameScenarioTitle(
                    scenario,
                    resolver: copyResolver
                )
                let situation = HighSchoolPresentation.localizedImportantGameSituation(
                    scenario,
                    resolver: copyResolver
                )
                let narrative = HighSchoolPresentation.localizedImportantGameScenarioNarrative(
                    scenario,
                    resolver: copyResolver
                )
                BaseballCard(title: title, tone: .milestone) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: situation)
                            .font(.subheadline.bold().monospacedDigit())
                        Text(verbatim: narrative)
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedImportantGameScenarioAccessibility(
                    title: title,
                    situation: situation,
                    narrative: narrative,
                    resolver: copyResolver
                )))
            }
            let opponentTitle = HighSchoolPresentation.localizedImportantGameOpponentTitle(
                isFinalShowdown: isFinalShowdown,
                resolver: copyResolver
            )
            BaseballCard(title: opponentTitle, tone: .warning) {
                VStack(alignment: .leading, spacing: 8) {
                    AvatarRow(
                        seed: HighSchoolPresentation.importantGameRivalPortraitSeed(state.rival),
                        role: .rival,
                        name: rivalName,
                        caption: rivalArchetype,
                        size: 48
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: HighSchoolPresentation.localizedImportantGameRivalAccessibility(
                        name: rivalName,
                        archetype: rivalArchetype,
                        signature: rivalSignature,
                        resolver: copyResolver
                    )))
                    if let rivalSignature {
                        Text(verbatim: rivalSignature)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    // 쌓인 역사. 전적이 있어야 이 타석이 서사가 된다.
                    if let rivalMatchup {
                        Text(verbatim: rivalMatchup)
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    if isFinalShowdown {
                        Text(verbatim: HighSchoolPresentation.localizedImportantGameFinalShowdownBody(
                            resolver: copyResolver
                        ))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            PrimaryButton(
                title: HighSchoolPresentation.localizedImportantGameStartAction(resolver: copyResolver),
                identifier: "hs.game.start",
                action: onStart
            )
        }
    }
}

/// 각성 스킬트리.
///
/// 회차당 세 번뿐인 선택을 낱장 카드 세 장으로 보여 주면, 세 번이 서로 아무 관계가 없어
/// "이 선수를 이렇게 만들었다"가 남지 않는다. 트리는 그 셋을 한 줄기로 묶는다 — 뿌리를
/// 찍으면 그 갈래의 다음 가지가 열리고, 세 번으로 **한 갈래를 끝까지 파거나 여러 갈래를
/// 얕게 가져가거나**를 고르게 된다.
///
/// 잠긴 가지도 **지운다기보다 보여 준다.** 앞으로 갈 수 있는 길이 보여야 지금의 한 번이
/// 결정처럼 느껴진다. 잠긴 이유(무엇을 먼저 찍어야 하는지)를 그 자리에 적는다.
///
/// 학교 선택과 같은 이유로 확인을 받는다 — 되돌릴 수 없는데 한 번 누르면 확정된다.
private struct AwakeningCard: View {
    let options: [AwakeningID]
    /// 각성의 전조(코어 값). nil은 전조 개념이 없던 저장본이다.
    var sparks: Int? = nil
    /// 아직 중요 경기를 안 던진 회차 초입인가. 증명할 무대가 없었던 선수에게
    /// "전조가 부족해"라고 벌점 문구를 주면 안 된다(4차 패널 P2).
    var beforeFirstGame = false
    /// 이번 회차에서 이미 찍은 각성.
    var selected: [AwakeningID] = []
    /// 평상시 확인 화면에서는 현재·다음 상태만 보여 주고 선택은 받지 않는다.
    var readOnly = false
    let onChoose: (AwakeningID) -> Void

    /// 회차당 각성 횟수. 코어의 마일스톤 배치(2 + 마지막 장 1)와 업적 `awakenedThrice`가
    /// 같은 값을 전제한다.
    static let totalAwakenings = 3

    @State private var pending: AwakeningID?
    @Environment(\.gameCopyResolver) private var copyResolver

    private var availableSet: Set<AwakeningID> { Set(options) }
    private var takenSet: Set<AwakeningID> { Set(selected) }

    /// 전조는 이제 "갈래를 몇 개 보여 줄까"가 아니라 **한 단계를 건너뛸 수 있는가**를
    /// 정한다. 트리에서는 그쪽이 훨씬 분명한 보상이다 — 2단을 건너뛰고 3단에 닿는다.
    private var sparkLine: (text: String, tone: Color) {
        let copy = HighSchoolPresentation.localizedAwakeningSpark(
            sparks: sparks,
            beforeFirstGame: beforeFirstGame,
            resolver: copyResolver
        )
        return (copy.text, copy.tone.accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if readOnly {
                Text(verbatim: HighSchoolPresentation.localizedAwakeningReadOnlySummary(
                    selectedCount: selected.count,
                    total: Self.totalAwakenings,
                    resolver: copyResolver
                ))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hs.skillTree.progress")
                Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningGuide))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // 회차당 세 번뿐인 순간 — 목록이 아니라 무대를 준다(QA P2-2).
                KeyArtHeader(
                    art: .awakening,
                    eyebrow: copyResolver.resolve(AppCopyKey.awakeningEyebrow),
                    title: copyResolver.resolve(AppCopyKey.awakeningKeyArtTitle),
                    accent: BaseballTheme.milestone
                )
                Text(verbatim: HighSchoolPresentation.localizedAwakeningCounter(
                    total: Self.totalAwakenings,
                    current: selected.count + 1,
                    resolver: copyResolver
                ))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hs.awakening.counter")
                Text(verbatim: HighSchoolPresentation.localizedAwakeningSelectionGuidance(
                    total: Self.totalAwakenings,
                    selectedCount: selected.count,
                    resolver: copyResolver
                ))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: sparkLine.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(sparkLine.tone)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(AwakeningTree.Branch.allCases, id: \.self) { branch in
                branchSection(branch)
            }
        }
        // 마지막 선택지가 탭바에 잘리지 않게 — 잘린 선택지는 없는 선택지다.
        .padding(.bottom, 24)
        .confirmationDialog(
            pending.map {
                HighSchoolPresentation.localizedAwakeningConfirmationTitle(
                    $0,
                    resolver: copyResolver
                )
            } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { option in
            Button {
                onChoose(option)
                pending = nil
            } label: {
                Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningConfirmationAction))
            }
            .accessibilityIdentifier("hs.awakening.confirm")
            // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣어 취소를 항상 보이게 한다.
            Button {
                pending = nil
            } label: {
                Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningConfirmationCancel))
            }
        } message: { option in
            Text(verbatim: HighSchoolPresentation.localizedAwakeningConfirmationMessage(
                option,
                resolver: copyResolver
            ))
        }
    }

    @ViewBuilder private func branchSection(_ branch: AwakeningTree.Branch) -> some View {
        let branchNodes = AwakeningTree.nodes.filter { $0.branch == branch }
        let ownedCount = branchNodes.filter { takenSet.contains($0.id) }.count
        BaseballCard(
            title: HighSchoolPresentation.localizedAwakeningBranchCardTitle(
                branch,
                resolver: copyResolver
            ),
            tone: ownedCount > 0 ? .milestone : .standard
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: branch.symbol).foregroundStyle(BaseballTheme.milestone)
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningBranchDetail(
                        branch,
                        resolver: copyResolver
                    ))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if ownedCount > 0 {
                        Text(verbatim: HighSchoolPresentation.localizedAwakeningSelectedCount(
                            ownedCount,
                            resolver: copyResolver
                        ))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
                ForEach(branchNodes, id: \.id) { node in
                    nodeRow(node)
                }
            }
        }
    }

    @ViewBuilder private func nodeRow(_ node: AwakeningTree.Node) -> some View {
        let owned = takenSet.contains(node.id)
        let open = availableSet.contains(node.id)
        // **찍을 수 있는 노드만 버튼이다.**
        //
        // 처음에는 18개 노드를 전부 버튼으로 그리고 잠긴 것을 `.disabled`로 두었다. 화면은
        // 같아 보이지만 접근성 트리에 18개의 조작 요소가 생겨, XCUI가 화면을 한 번 훑는
        // 비용이 폭발했다 — 3년 완주 스모크가 330초에서 685초로 늘고 결국 쿼리 타임아웃으로
        // 죽었다. 실제 사용자에게도 같은 값을 치른다(보이스오버가 못 누르는 항목 18개를
        // 하나씩 읽는다). 누를 수 없는 것은 조작 요소가 아니라 그림이어야 한다.
        if open && !owned && !readOnly {
            Button { pending = node.id } label: { nodeBody(node, owned: false, open: true) }
                .buttonStyle(.plain)
                .accessibilityLabel(nodeVoiceLabel(node, owned: false, open: true))
                .accessibilityIdentifier("hs.awakening.\(node.id.rawValue)")
        } else {
            nodeBody(node, owned: owned, open: readOnly && open)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(nodeVoiceLabel(node, owned: owned, open: readOnly && open))
        }
    }

    @ViewBuilder private func nodeBody(_ node: AwakeningTree.Node, owned: Bool, open: Bool) -> some View {
        let leap = open && AwakeningTree.isLeap(node.id, selected: selected)
        let tone: Color = owned ? BaseballTheme.positive
            : open ? BaseballTheme.milestone : BaseballTheme.textTertiary

        HStack(alignment: .top, spacing: 10) {
            // 단수만큼 들여쓴다. 줄기가 아래로 자라는 모양이 한눈에 읽힌다.
            // 세로 강조 레일은 쓰지 않으므로(DOC-19 §7.2) 여백과 갈래 기호로만 깊이를 말한다.
            if node.tier > 1 {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(tone.opacity(owned || open ? 0.8 : 0.35))
                    .padding(.leading, CGFloat((node.tier - 1) * 12))
                    .accessibilityHidden(true)
            }
            Image(systemName: owned ? "checkmark.circle.fill" : open ? "circle.circle" : "lock.fill")
                .font(.subheadline)
                .foregroundStyle(tone)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningTitle(
                        node.id,
                        resolver: copyResolver
                    ))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(owned || open ? BaseballTheme.textPrimary : BaseballTheme.textTertiary)
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningTierLabel(
                        node.tier,
                        resolver: copyResolver
                    ))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(tone)
                    if leap {
                        Text(verbatim: HighSchoolPresentation.localizedAwakeningLeapLabel(
                            resolver: copyResolver
                        ))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BaseballTheme.canvas)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(BaseballTheme.milestone, in: Capsule())
                    }
                    Spacer(minLength: 0)
                    if open {
                        Text(verbatim: HighSchoolPresentation.localizedAwakeningActionLabel(
                            readOnly: readOnly,
                            resolver: copyResolver
                        ))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
                // 잠긴 가지는 **제목만** 보여 준다. 앞으로 갈 길이 보이는 것이 목적이지
                // 지금 읽을 설명이 아니고, 18개 분량의 설명문이 한 화면에 깔리면 정작
                // 지금 고를 수 있는 네 가지가 그 안에 묻힌다.
                if owned || open {
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningDetail(
                        node.id,
                        resolver: copyResolver
                    ))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let reason = lockReason(node) {
                    // 잠긴 이유는 그 자리에 적는다. "왜 못 누르지"가 남으면 트리가 벽이 된다.
                    Text(verbatim: reason)
                        .font(.caption2)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
        .background(
            owned ? BaseballTheme.positive.opacity(0.12)
                : open ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surfaceRaised.opacity(0.5),
            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                .stroke(tone.opacity(owned || open ? 1 : 0.35), lineWidth: open ? 2 : 1)
        }
        .contentShape(Rectangle())
    }

    private func nodeVoiceLabel(_ node: AwakeningTree.Node, owned: Bool, open: Bool) -> String {
        HighSchoolPresentation.localizedAwakeningNodeVoiceLabel(
            node,
            owned: owned,
            open: open,
            readOnly: readOnly,
            selected: selected,
            resolver: copyResolver
        )
    }

    private func lockReason(_ node: AwakeningTree.Node) -> String? {
        HighSchoolPresentation.localizedAwakeningLockReason(
            node,
            selected: selected,
            resolver: copyResolver
        )
    }
}

/// 현재 국면을 떠나지 않고 보유·다음 스킬을 확인하는 입구.
private struct SkillTreeSummaryRow: View {
    let selected: [AwakeningID]
    let onOpen: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningSummaryTitle(
                        selectedCount: selected.count,
                        total: AwakeningCard.totalAwakenings,
                        resolver: copyResolver
                    ))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Text(verbatim: selected.isEmpty
                          ? HighSchoolPresentation.localizedAwakeningSummaryEmpty(resolver: copyResolver)
                          : selected.map {
                              HighSchoolPresentation.localizedAwakeningTitle(
                                  $0,
                                  resolver: copyResolver
                              )
                          }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(BaseballTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hs.skillTree.open")
    }
}

/// 시트가 닫기 동작을 직접 소유해 호출 화면의 상태를 단순하게 유지한다.
private struct SkillTreeSheet: View {
    let selected: [AwakeningID]
    let sparks: Int?
    let beforeFirstGame: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameCopyResolver) private var copyResolver

    private var nextOptions: [AwakeningID] {
        guard selected.count < AwakeningCard.totalAwakenings else { return [] }
        return AwakeningTree.available(selected: selected, sparks: sparks)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AwakeningCard(
                    options: nextOptions,
                    sparks: sparks,
                    beforeFirstGame: beforeFirstGame,
                    selected: selected,
                    readOnly: true,
                    onChoose: { _ in }
                )
                .padding(BaseballMetrics.gutter)
            }
            .background(BaseballTheme.canvas)
            .navigationTitle(Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningSheetTitle)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningSheetDone))
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct ChapterReviewCard: View {
    let state: HighSchoolCareerSnapshot
    /// 이번 챕터에 오른 능력치(라벨→증가폭). 첫 세션의 마지막 화면이 요약문 한 줄이면
    /// 40분의 훈련이 감정 없이 접힌다 — 여기가 작은 정산이어야 한다(2차 패널 P1).
    let gains: [String: Int]
    let trainingCount: Int
    let onContinue: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let title = HighSchoolPresentation.localizedChapterReviewTitle(state.chapter, resolver: copyResolver)
        let verdict = HighSchoolPresentation.localizedChapterReviewVerdict(state.performance, resolver: copyResolver)
        let statLine = HighSchoolPresentation.localizedChapterReviewStatLine(state.performance, resolver: copyResolver)
        let gainRows = HighSchoolPresentation.localizedChapterReviewGainRows(gains, resolver: copyResolver)
        let growthTitle = copyResolver.resolve(AppCopyKey.chapterReviewGrowthTitle)
        let abilitiesTitle = copyResolver.resolve(AppCopyKey.chapterReviewAbilitiesTitle)
        let continueAction = copyResolver.resolve(AppCopyKey.chapterReviewContinue)
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: title, tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: verdict)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text(verbatim: statLine)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            // 성장 정산 — 훈련이 실제로 몸에 남긴 것. 없으면 없다고 적는다.
            BaseballCard(title: growthTitle, tone: .raised) {
                if gainRows.isEmpty {
                    Text(verbatim: HighSchoolPresentation.localizedChapterReviewGrowthEmpty(
                        trainingCount: trainingCount,
                        resolver: copyResolver
                    ))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(gainRows) { row in
                            HStack {
                                Text(verbatim: row.label).font(.subheadline)
                                Spacer()
                                Text(verbatim: "+\(row.delta)")
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                        Text(verbatim: HighSchoolPresentation.localizedChapterReviewGrowthSummary(
                            trainingCount: trainingCount,
                            resolver: copyResolver
                        ))
                            .font(.caption2)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                }
            }
            BaseballCard(title: abilitiesTitle) {
                VStack(alignment: .leading, spacing: 10) {
                    // 장 정산은 "어디까지 갈 수 있나"를 다시 읽는 자리다. 재능(한계)이
                    // 빠지면 다음 장의 훈련 계획을 세울 근거가 사라진다.
                    let talent = state.talent ?? .unlimited
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.stuff.displayCopyToken,
                        value: state.pitcher.stuff,
                        talent: talent.stuff,
                        preservesKoreanAccessibility: true
                    )
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.command.displayCopyToken,
                        value: state.pitcher.command,
                        talent: talent.command,
                        preservesKoreanAccessibility: true
                    )
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.movement.displayCopyToken,
                        value: state.pitcher.movement,
                        talent: talent.movement,
                        preservesKoreanAccessibility: true
                    )
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.stamina.displayCopyToken,
                        value: state.pitcher.stamina,
                        talent: talent.stamina,
                        preservesKoreanAccessibility: true
                    )
                }
            }
            if let rivalLine = HighSchoolPresentation.localizedChapterReviewRivalLine(
                state.rival,
                resolver: copyResolver
            ) {
                Text(verbatim: rivalLine)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            PrimaryButton(title: continueAction, identifier: "hs.chapter.continue", action: onContinue)
        }
    }
}

/// 대회 대진 — 같은 경기도 "왕중왕전 준결승"이라는 무대 위에서는 무게가 다르다.
/// 커널 일정은 그대로다. 이 카드는 세계를 보여 줄 뿐, 일정에 대해 거짓말하지 않는다.
private struct TournamentCard: View {
    let state: HighSchoolCareerSnapshot
    let school: SchoolSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let playerSchoolName = school.name
        let field = TournamentBracket.field(
            careerID: state.careerID, chapterNumber: state.chapter.number, playerSchool: playerSchoolName
        )
        let playerSchoolCopy = CopyToken.schoolSelection(
            rawRegion: state.identity.region,
            schoolID: school.id
        )
        let tournamentName = HighSchoolPresentation.localizedTournamentName(
            chapterNumber: state.chapter.number,
            resolver: copyResolver
        )
        let aceStart = HighSchoolPresentation.localizedTournamentAceStart(
            round: field.playerRound,
            resolver: copyResolver
        )
        let dash = copyResolver.resolve(AppCopyKey.tournamentDash)
        let nationalNote = copyResolver.resolve(AppCopyKey.tournamentNationalNote)
        BaseballCard(title: tournamentName, tone: .milestone) {
            VStack(alignment: .leading, spacing: 8) {
                // 대회 배너 — 무대는 글보다 그림이 먼저 말한다.
                if UIImage(named: "TournamentBanner\(state.chapter.number)") != nil {
                    Image("TournamentBanner\(state.chapter.number)")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // 배너 아래를 카드 배경으로 녹여 사진과 카드가 한 장으로 붙는다(QA P2-9).
                        .overlay {
                            LinearGradient(colors: [.clear, BaseballTheme.surface.opacity(0.55)],
                                           startPoint: .center, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .allowsHitTesting(false)
                        }
                }
                Text(verbatim: aceStart)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                // 대진: 두 팀씩 한 쌍. 내 학교가 굵게 빛난다.
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<4, id: \.self) { pair in
                        HStack(spacing: 6) {
                            bracketName(
                                field.schools[pair * 2],
                                playerSchoolName: playerSchoolName,
                                playerSchoolCopy: playerSchoolCopy
                            )
                            Text(verbatim: dash).font(.caption2).foregroundStyle(BaseballTheme.textTertiary)
                            bracketName(
                                field.schools[pair * 2 + 1],
                                playerSchoolName: playerSchoolName,
                                playerSchoolCopy: playerSchoolCopy
                            )
                        }
                    }
                }
                Text(verbatim: nationalNote)
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .accessibilityIdentifier("hs.tournament")
    }

    private func bracketName(
        _ rawName: String,
        playerSchoolName: String,
        playerSchoolCopy: SchoolSelectionCopyDescriptor
    ) -> some View {
        let displayName = rawName == playerSchoolName
            ? copyResolver.resolve(playerSchoolCopy.schoolNameToken)
            : HighSchoolPresentation.localizedTournamentOpponentSchool(
                rawSchoolName: rawName,
                resolver: copyResolver
            )
        return Text(verbatim: displayName)
            .font(.footnote.weight(rawName == playerSchoolName ? .bold : .regular))
            .foregroundStyle(rawName == playerSchoolName ? BaseballTheme.action : BaseballTheme.textSecondary)
    }
}

/// 이번 챕터의 숙제. "3년 뒤 드래프트"는 너무 멀다 — 오늘 훈련 하나를
/// 누르게 만드는 것은 이번 챕터의 숫자다.
private struct ChapterGoalCard: View {
    let state: HighSchoolCareerSnapshot
    let career: HighSchoolCareerStore
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let goal = ChapterGoal.goal(careerID: state.careerID, chapterNumber: state.chapter.number)
        let progress = max(0, state.performance.strikeouts - career.chapterStartStrikeouts)
        let done = career.goalCelebratedChapter == state.chapter.number || progress >= goal.targetStrikeouts
        let title = HighSchoolPresentation.localizedChapterGoalTitle(goal, resolver: copyResolver)
        let detail = done
            ? copyResolver.resolve(AppCopyKey.chapterGoalCompleted)
            : HighSchoolPresentation.localizedChapterGoalDetail(goal, resolver: copyResolver)
        let progressLabel = HighSchoolPresentation.localizedChapterGoalProgress(
            progress: min(progress, goal.targetStrikeouts),
            targetStrikeouts: goal.targetStrikeouts,
            resolver: copyResolver
        )
        BaseballCard(title: title, tone: done ? .positive : .raised) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressView(value: Double(min(progress, goal.targetStrikeouts)),
                                 total: Double(goal.targetStrikeouts))
                        .tint(done ? BaseballTheme.positive : BaseballTheme.action)
                    Text(verbatim: progressLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(done ? BaseballTheme.positive : BaseballTheme.textSecondary)
                }
            }
        }
        .accessibilityIdentifier("hs.chapterGoal")
    }
}

/// 어딘가의 게시판에서 모르는 사람들이 내 선수 얘기를 하고 있다.
///
/// 기사와 능력치는 공식 세계다. 애착은 비공식 세계에서 완성된다 — 잘 던지면
/// 감탄하고, 볼넷이 쌓이면 냉정하게 놀리는 익명의 목소리. 그 냉정함까지가 세상이다.
private struct CommunityBuzzCard: View {
    private enum Line {
        case reaction(CommunityBuzzReactionLine)
        case news(CommunityBuzzRivalNewsLine)
    }

    let titleKey: GameCopyKey
    let footnoteKey: GameCopyKey
    private let lines: [Line]
    @Environment(\.gameCopyResolver) private var copyResolver

    init(reactionLines: [CommunityBuzzReactionLine]) {
        titleKey = AppCopyKey.communityBuzzTitle
        footnoteKey = AppCopyKey.communityBuzzFootnote
        lines = reactionLines.map(Line.reaction)
    }

    init(newsLines: [CommunityBuzzRivalNewsLine]) {
        titleKey = AppCopyKey.communityBuzzWorldTitle
        footnoteKey = AppCopyKey.communityBuzzWorldFootnote
        lines = newsLines.map(Line.news)
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(titleKey)) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("└")
                            .font(.caption2)
                            .foregroundStyle(BaseballTheme.textTertiary)
                        Text(verbatim: localized(line))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(verbatim: copyResolver.resolve(footnoteKey))
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .accessibilityIdentifier("hs.buzz")
    }

    private func localized(_ line: Line) -> String {
        switch line {
        case .reaction(let value):
            CommunityBuzzPresentation.localizedReaction(value, resolver: copyResolver)
        case .news(let value):
            CommunityBuzzPresentation.localizedNews(value, resolver: copyResolver)
        }
    }
}

/// 이 회차가 살아온 순간들. 결과(기록 카드)가 아니라 과정을 보여 준다 —
/// 드래프트 직전과 회차를 접는 순간, 두 번의 되돌아보는 자리에 선다.
private struct ChronicleCard: View {
    let entries: [HighSchoolCareerStore.ChronicleEntry]
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        if !entries.isEmpty {
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionChronicleTitle)) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        let localized = HighSchoolConclusionPresentation.localizedChronicleEntry(
                            entry, resolver: copyResolver
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            // localization-safe: resolved-copy
                            Text(localized.stage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BaseballTheme.textTertiary)
                            // localization-safe: resolved-copy
                            Text(localized.text)
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .accessibilityIdentifier("hs.chronicle")
        }
    }
}

private struct DraftCard: View {
    let state: HighSchoolCareerSnapshot
    let chronicle: [HighSchoolCareerStore.ChronicleEntry]
    let career: HighSchoolCareerStore
    let onResolve: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionDraftTitle), tone: .milestone) {
                Text(copyResolver.resolve(AppCopyKey.conclusionDraftIntro))
                    .font(.subheadline)
            }
            if let personality = career.personality {
                let personalityTitle = HighSchoolConclusionPresentation.localizedPersonalityTitle(
                    personality, resolver: copyResolver
                )
                BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionScoutTitle)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("'\(personalityTitle)'")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                        Text(HighSchoolConclusionPresentation.localizedPersonalityScoutLine(
                            personality, resolver: copyResolver
                        ))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionRecordTitle)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionOfficialGames,
                        arguments: [.integer(state.performance.importantGamesCompleted)]
                    ))
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionRecordStats,
                        arguments: [
                            .integer(state.performance.strikeouts), .integer(state.performance.walks),
                            .integer(state.performance.runsAllowed),
                        ]
                    ))
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionAwakeningTraining,
                        arguments: [.integer(state.selectedAwakenings.count), .integer(state.totalTrainingsCompleted)]
                    ))
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            }
            // 자동으로 흘러간 팀 경기도 평가에 들어간다. 여기 보여 주지 않으면
            // 드래프트 카드의 "시즌 기록 +N"이 어디서 나온 숫자인지 알 수 없다.
            if let log = state.seasonLog, !log.isEmpty {
                SeasonRecordCard(log: log)
            }
            ChronicleCard(entries: chronicle)
            PrimaryButton(
                title: copyResolver.resolve(AppCopyKey.conclusionResolveDraft),
                identifier: "hs.draft.resolve",
                action: onResolve
            )
        }
    }
}

private struct LegacyCard: View {
    @State private var confirmingLegacy = false
    @Environment(\.gameCopyResolver) private var copyResolver

    let career: HighSchoolCareerStore
    let state: HighSchoolCareerSnapshot

    var body: some View {
        let signatureCandidates = career.usesSignatureLegacyRules
            ? career.signatureLegacyCandidates(for: state)
            : []
        let selectedSignatureLegacy = signatureCandidates.first {
            $0.id == career.selectedSignatureLegacyID
        }
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 아직 접지 않은 회차의 카드를 미리 만들어 보여 준다. 3년을 함께한
            // 선수의 얼굴·별명·기록이 한 장에 담긴 것을 보고 나서 작별하는 것과,
            // 숫자 목록을 보고 작별하는 것은 다른 경험이다.
            let provisional = HighSchoolCareerStore.lifeRecord(
                from: state, memories: career.selectedMemories, previous: career.inheritance,
                nicknames: career.nicknames, chronicle: career.chronicle,
                personality: career.personality,
                signatureLegacy: selectedSignatureLegacy,
                signatureLegacyCandidates: signatureCandidates,
                startingPitcher: career.careerStartingPitcher
            )
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionPlayerRecordCard), tone: .milestone) {
                VStack(alignment: .leading, spacing: 10) {
                    LifeCardPreview(record: provisional)
                    LifeCardShareButton(record: provisional)
                }
            }
            ChronicleCard(entries: career.chronicle)
            if let draft = state.draftResult {
                let signature = draft.team.map { HighSchoolConclusionPresentation.localizedTeamName($0, resolver: copyResolver) }
                let projected = HighSchoolConclusionPresentation.localizedDraftProjectedRange(
                    draft.projectedRange, resolver: copyResolver
                )
                let summary = HighSchoolConclusionPresentation.localizedDraftSummary(
                    draft, resolver: copyResolver
                )
                let firstSeasonGoal = HighSchoolConclusionPresentation.localizedFirstSeasonGoal(
                    draft.firstSeasonGoal, resolver: copyResolver
                )
                BaseballCard(title: copyResolver.resolve(draft.outcome.displayCopyToken),
                             tone: draft.outcome == .drafted ? .positive : .negative) {
                    VStack(alignment: .leading, spacing: 10) {
                        // localization-safe: resolved-copy
                        Text(summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        // localization-safe: resolved-copy
                        Text(projected)
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                        if let firstSeasonGoal {
                            // localization-safe: resolved-copy
                            Text(firstSeasonGoal)
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let signature {
                            // localization-safe: resolved-copy
                            Text(signature)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BaseballTheme.information)
                        }
                        // 무엇이 점수를 만들었는지. 이게 없으면 3년 동안 쌓은 것들이
                        // 결과에 어떻게 반영됐는지 알 방법이 없다.
                        if let breakdown = HighSchoolConclusionPresentation.localizedEvaluationBreakdown(
                            draft.evaluationBreakdown,
                            resolver: copyResolver
                        ), !breakdown.isEmpty {
                            Divider()
                            Text(copyResolver.resolve(
                                AppCopyKey.conclusionEvaluationScore,
                                arguments: [.integer(draft.evaluationScore)]
                            )).eyebrowStyle(BaseballTheme.textTertiary)
                            FlowRow(items: breakdown, resolver: copyResolver)
                        }
                    }
                }
            }
            WindSettlementCard(wind: state.careerWind)
            if career.usesSignatureLegacyRules {
                let signatureCount = selectedSignatureLegacy == nil ? 0 : 1
                BaseballCard(
                    title: copyResolver.resolve(
                        AppCopyKey.conclusionSignatureTitle,
                        arguments: [.integer(signatureCount)]
                    ),
                    tone: .milestone
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionSignatureDescription))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                        Text(copyResolver.resolve(AppCopyKey.conclusionSignatureRemainder))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .onViewportExposure {
                    guard career.prepareSignatureLegacyCandidates() else { return }
                    GameAnalytics.logOnce(
                        .signatureLegacyOptionsSeen,
                        scope: "signature-options:\(state.careerID)",
                        properties: [
                            "life_number": state.lifeNumber,
                            "drafted": state.draftResult?.outcome == .drafted,
                            "includes_pro_career": signatureCandidates.contains {
                                $0.evidence.proPerformance != nil
                            },
                            "option_ids": Array(Set(signatureCandidates.map { $0.id.rawValue }))
                                .sorted().joined(separator: ","),
                        ]
                    )
                }
                ForEach(signatureCandidates) { legacy in
                    let selected = legacy.id == career.selectedSignatureLegacyID
                    let copy = HighSchoolConclusionPresentation.localizedSignature(
                        legacy, resolver: copyResolver
                    )
                    Button { career.selectSignatureLegacy(legacy.id) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selected ? "checkmark.seal.fill" : "seal")
                                .foregroundStyle(selected ? BaseballTheme.milestone : BaseballTheme.border)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                // localization-safe: resolved-copy
                                Text(copy.title)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                // localization-safe: resolved-copy
                                Text(copy.detail)
                                    .font(.footnote)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                // localization-safe: resolved-copy
                                Text(copy.evidence)
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.information)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(HighSchoolConclusionPresentation.localizedSignatureEffect(
                                    legacy.effect, resolver: copyResolver
                                ))
                                    .font(.caption2.weight(.bold).monospacedDigit())
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selected ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surface,
                            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(selected ? BaseballTheme.milestone : BaseballTheme.border,
                                        lineWidth: selected ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hs.signatureLegacy.\(legacy.id.rawValue)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            if !career.usesSignatureLegacyRules {
                BaseballCard(title: copyResolver.resolve(
                    AppCopyKey.conclusionMemoryTitle,
                    arguments: [.integer(career.selectedMemories.count), .integer(state.memorySlots)]
                ), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionMemoryDescription))
                            .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        // 구규칙은 정확히 memorySlots장을 요구한다. 부족한 채로 확정하면
                        // 오류가 나므로 화면에서 막고 남은 장수를 알려 준다.
                        if career.selectedMemories.count < state.memorySlots {
                            Text(copyResolver.resolve(
                                AppCopyKey.conclusionMemoryMore,
                                arguments: [.integer(state.memorySlots - career.selectedMemories.count)]
                            ))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(BaseballTheme.warning)
                        }
                    }
                }
                ForEach(state.legacyOptions, id: \.self) { option in
                    let copy = HighSchoolConclusionPresentation.localizedMemory(
                        option, resolver: copyResolver
                    )
                    let selected = career.selectedMemories.contains(option)
                    Button { career.toggleMemory(option) } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.border)
                            ArtThumb(assetName: "MemoryArt-\(option.rawValue)", size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                // localization-safe: resolved-copy
                                Text(copy.title).font(.subheadline.weight(.bold))
                                // localization-safe: resolved-copy
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
            }
            let legacyConfirmAction = career.usesSignatureLegacyRules
                ? AppCopyKey.conclusionLegacyConfirmAction
                : AppCopyKey.conclusionMemoryConfirmAction
            let selectedLegacyTitle = selectedSignatureLegacy.map {
                HighSchoolConclusionPresentation.localizedSignature($0, resolver: copyResolver).title
            } ?? copyResolver.resolve(AppCopyKey.conclusionSignatureTitle, arguments: [.integer(0)])
            let legacySubject: String = {
                guard career.usesSignatureLegacyRules else { return selectedLegacyTitle }
                guard copyResolver.language == .korean else { return selectedLegacyTitle }
                return selectedLegacyTitle + KoreanCopy.particle(selectedLegacyTitle, final: "을", open: "를")
            }()
            PrimaryButton(
                title: copyResolver.resolve(legacyConfirmAction),
                identifier: "hs.legacy.confirm"
            ) { confirmingLegacy = true }
                .disabled(
                    career.usesSignatureLegacyRules
                        ? selectedSignatureLegacy == nil
                        : career.selectedMemories.count != state.memorySlots
                )
                .confirmationDialog(
                    copyResolver.resolve(
                        career.usesSignatureLegacyRules
                            ? AppCopyKey.conclusionLegacyConfirmationTitle
                            : AppCopyKey.conclusionMemoryConfirmationTitle,
                        arguments: career.usesSignatureLegacyRules
                            ? [.userText(legacySubject)]
                            : [.integer(career.selectedMemories.count)]
                    ),
                    isPresented: $confirmingLegacy,
                    titleVisibility: .visible
                ) {
                    Button(copyResolver.resolve(AppCopyKey.conclusionConfirmationConfirm)) {
                        career.confirmLegacy()
                    }
                    Button(copyResolver.resolve(AppCopyKey.conclusionConfirmationCancel)) {
                        confirmingLegacy = false
                    }
                } message: {
                    Text(copyResolver.resolve(
                        career.usesSignatureLegacyRules
                            ? AppCopyKey.conclusionLegacyConfirmationMessage
                            : AppCopyKey.conclusionMemoryConfirmationMessage
                    ))
                }
        }
    }
}

private struct CompletionCard: View {
    @State private var confirmingFold = false
    let career: HighSchoolCareerStore
    let state: HighSchoolCareerSnapshot
    /// 이 회차로 프로에 이미 진출했는가.
    let hasEnteredPro: Bool
    let onEnterPro: (DraftResultSnapshot, PitcherSnapshot, PlayerIdentitySnapshot) -> Void
    /// 환생 스탬프를 띄우고 나서 다음 회차로 넘어간다. 화면이 갈아 끼워지기 전에
    /// 회차 번호를 보여 줘야 회차가 쌓이는 감각이 생긴다.
    let onRebirth: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            let completionSummary = state.draftResult.map {
                HighSchoolConclusionPresentation.localizedDraftSummary($0, resolver: copyResolver)
            } ?? copyResolver.resolve(AppCopyKey.conclusionCompletionEnded)
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionCompletionTitle), tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    // localization-safe: resolved-copy
                    Text(completionSummary)
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    // 지명된 회차에서는 아직 계승이 정해지지 않았다. 지난 회차의 것만 보여 준다.
                    if career.inheritance.memories.isEmpty {
                        EmptyView()
                    } else {
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionCarriedMemorySummary,
                            arguments: [
                                .integer(career.inheritance.memories.count),
                                .integer(career.inheritance.soulPoints),
                            ]
                        ))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
            }
            WindSettlementCard(wind: state.careerWind)

            // 지명된 구단에서 누가 기다리는지. 이름만 있으면 "어느 팀"이 문자열 하나이고,
            // 프로 첫 시즌의 경쟁 구도가 시작 전에 서지 않는다.
            if let team = state.draftResult?.team, state.draftResult?.outcome == .drafted {
                let teamName = HighSchoolConclusionPresentation.localizedTeamName(team, resolver: copyResolver)
                let coachName = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: .proCoach, resolver: copyResolver
                )
                let competitorName = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: .positionCompetitor, resolver: copyResolver
                )
                let coachProfile = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: team.coachProfile == nil ? .developmentPlan : .coachProfile,
                    resolver: copyResolver
                )
                let competitorProfile = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: team.competitorProfile == nil ? .positionCompetitor : .competitorProfile,
                    resolver: copyResolver
                )
                BaseballCard(title: copyResolver.resolve(
                    AppCopyKey.conclusionTeamWaiting,
                    arguments: [.userText(teamName)]
                ), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 10) {
                        AvatarRow(seed: team.proCoach, role: .coach,
                                  name: copyResolver.resolve(
                                    AppCopyKey.conclusionCoachName,
                                    arguments: [.userText(coachName)]
                                  ), caption: coachProfile, size: 44)
                        // 경쟁자를 player 역할로 두면 같은 카드에서 코치는 사진, 경쟁자는 벡터로
                        // 갈린다(QA P1-9) — 한 화면 안 화풍 혼재는 미완성으로 읽힌다.
                        AvatarRow(seed: team.positionCompetitor, role: .rival,
                                  name: competitorName,
                                  caption: team.competitorProfile == nil
                                    ? copyResolver.resolve(AppCopyKey.conclusionCompetitorFallback)
                                    : competitorProfile,
                                  size: 44)
                    }
                }
            }

            // 기억을 이미 확정한 회차는 결정이 끝난 회차다. 이 구분이 없던 동안, 지명 회차를
            // 접기로 하고 기억까지 고른 사용자가 "이 회차를 접고 다시 시작"을 누를 때마다
            // 다시 기억 선택으로 끌려갔다 — 환생에 영영 닿지 못하는 무한 순환이었다.
            let legacyConfirmed = !state.selectedMemories.isEmpty
                || career.inheritance.lifeNumber > state.lifeNumber

            // 프로에 이미 다녀왔으면 다시 들어가지 않는다.
            //
            // 예전에는 프로에서 은퇴하고 고교 완료 화면으로 돌아오면 "프로 커리어 시작"이
            // 다시 살아났다. 같은 지명으로 프로 커리어를 무한히 새로 만들 수 있었고, 은퇴
            // 계승(야구혼)도 그때마다 다시 적립될 여지가 있었다.
            if let draft = state.draftResult, draft.outcome == .drafted, !legacyConfirmed, !hasEnteredPro {
                PrimaryButton(title: copyResolver.resolve(AppCopyKey.conclusionEnterPro), identifier: "hs.enterPro") {
                    onEnterPro(draft, state.pitcher, state.identity)
                }
                Text(copyResolver.resolve(AppCopyKey.conclusionNotOver))
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)

                // 잘한 회차일수록 다음 선수 이야기를 못 본다.
                //
                // 지명되면 대표 유산 선택은 프로를 접거나 은퇴한 뒤에야 나온다. 지명률이
                // 회차가 갈수록 오르니 **다수의 회차가 이 경로로 빠지고**, 성공 직후에
                // 환생 동기가 오히려 끊긴다. 고르게 하지는 않되, 무엇이 남을지는 지금
                // 보여 준다 — 이 화면이 다음 회차를 한 글자도 말하지 않던 것을 고친다.
                let upcoming = career.signatureLegacyCandidates(for: state)
                if !upcoming.isEmpty {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionLegacyPreviewTitle), tone: .raised) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(copyResolver.resolve(AppCopyKey.conclusionLegacyPreviewBody))
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(upcoming, id: \.id) { candidate in
                                Label(
                                    HighSchoolConclusionPresentation.localizedSignature(
                                        candidate, resolver: copyResolver
                                    ).title,
                                    systemImage: "seal.fill"
                                )
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                    }
                    .accessibilityIdentifier("hs.legacyPreview")
                }
            }

            // 지명된 회차는 아직 끝나지 않았다. 프로에 들어가지 않았다면 포기 확인 뒤
            // 유산을 고르고, 이미 프로에 들어갔다면 은퇴 기록이 돌아올 때까지 기다린다.
            let awaitsProRetirement = state.draftResult?.outcome == .drafted
                && !legacyConfirmed && hasEnteredPro
            let opensLegacy = state.draftResult?.outcome == .drafted
                && !legacyConfirmed && !hasEnteredPro

            // 이 회차의 카드를 여기서 나눈다.
            //
            // 예전에는 공유 버튼이 기억 선택 화면과 정산 화면에만 있었다. 지명에 성공한
            // 회차는 **정산 화면을 거치지 않고** 곧장 이 화면으로 오므로, 이 게임에서
            // 감정이 가장 높은 순간에 공유 경로가 통째로 없었다(2026-08 기준 공유 5%).
            if legacyConfirmed || state.draftResult != nil {
                LifeCardShareButton(record: HighSchoolCareerStore.lifeRecord(
                    from: state, memories: career.selectedMemories, previous: career.inheritance,
                    nicknames: career.nicknames, chronicle: career.chronicle,
                    personality: career.personality,
                    startingPitcher: career.careerStartingPitcher
                ))
            }

            // 남은 행동이 하나뿐인 화면에서 그 버튼이 회색 테두리면, 화면은 "끝났다"로
            // 읽힌다. 기억까지 확정한 회차의 다음 행동은 환생 하나뿐이므로 주 버튼으로
            // 세운다 — 드래프트를 본 42명 중 27명만 다음 회차를 시작했다(2026-08).
            if awaitsProRetirement {
                BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionAwaitingRetirementTitle), tone: .milestone) {
                    Text(copyResolver.resolve(AppCopyKey.conclusionAwaitingRetirementBody))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if !opensLegacy {
                // 지명 위쪽의 목표.
                //
                // 계승은 4회차 전후에 상한(+20)에 닿고, 그때쯤 "지명"은 거의 자동이 된다.
                // 그 뒤로 회차를 더 도는 이유가 업적 문구뿐이라 목표가 사라진다. 스카우트
                // 평가는 상한이 없고 회차를 가로질러 비교되므로, 다음 회차의 과녁이 된다.
                let bestPast = career.archive
                    .filter { $0.lifeNumber != state.lifeNumber }
                    .map(\.evaluationScore).max() ?? 0
                let thisRun = state.draftResult?.evaluationScore ?? 0
                if bestPast > 0 || thisRun > 0 {
                    let isRecord = thisRun > bestPast
                    BaseballCard(title: copyResolver.resolve(
                        isRecord ? AppCopyKey.conclusionBestEvaluationRecordTitle
                                 : AppCopyKey.conclusionBestEvaluationNextTitle
                    ),
                                 tone: isRecord ? .milestone : .raised) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(
                                verbatim: copyResolver.resolve(
                                    .evaluationPoints,
                                    arguments: [.integer(max(thisRun, bestPast))]
                                )
                            )
                                .font(BaseballType.heroNumeral)
                                .foregroundStyle(isRecord ? BaseballTheme.milestone : BaseballTheme.textPrimary)
                            Text(copyResolver.resolve(
                                isRecord ? AppCopyKey.conclusionBestEvaluationRecordBody
                                         : AppCopyKey.conclusionBestEvaluationNextBody,
                                arguments: [.integer(isRecord ? bestPast : thisRun)]
                            ))
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("hs.bestEvaluation")
                }
                PrimaryButton(title: copyResolver.resolve(
                    AppCopyKey.conclusionRebirthAction,
                    arguments: [.integer(career.inheritance.lifeNumber)]
                ), identifier: "hs.rebirth", action: onRebirth)
                let memoryCount = career.inheritance.memories.count
                let points = career.inheritance.soulPoints
                let summaryKey = copyResolver.language == .korean
                    ? (KoreanCopy.objectParticle(number: points) == "을"
                        ? AppCopyKey.conclusionRebirthSummaryWithEul
                        : AppCopyKey.conclusionRebirthSummaryWithReul)
                    : AppCopyKey.conclusionRebirthSummaryWithEul
                Text(copyResolver.resolve(
                    summaryKey,
                    arguments: [.integer(memoryCount), .integer(points)]
                ))
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    // 프로 포기는 이 게임에서 가장 무거운 되돌릴 수 없는 결정인데
                    // 학교 선택보다 마찰이 낮았다 — 같은 확인 문법을 준다.
                    confirmingFold = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionFoldTitle))
                            .font(.subheadline.weight(.semibold))
                        Text(copyResolver.resolve(AppCopyKey.conclusionFoldBody))
                            .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.rebirth")
                .confirmationDialog(
                    copyResolver.resolve(AppCopyKey.conclusionFoldConfirmationTitle),
                    isPresented: $confirmingFold,
                    titleVisibility: .visible
                ) {
                    Button(copyResolver.resolve(AppCopyKey.conclusionFoldAction), role: .destructive) { career.openLegacy() }
                    // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                    Button(copyResolver.resolve(AppCopyKey.conclusionFoldCancel)) { confirmingFold = false }
                } message: {
                    Text(copyResolver.resolve(AppCopyKey.conclusionFoldMessage))
                }
            }
        }
    }
}

/// 상태바 뒤를 지나가는 본문을 가리는 스크림.
///
/// 이 화면은 내비게이션 바를 숨긴다(키아트가 제목이라 제목이 두 번 나온다). 그래서
/// iOS가 스크롤 가장자리에 걸어 주는 흐림이 없고, 스크롤한 본문이 시계·와이파이·배터리와
/// **같은 자리에 그대로 겹쳐 그려진다** — "글자가 깨져 보인다"는 제보의 실체다.
///
/// 예전 스크림은 **높이 28 고정**이었다. 이 기기(iPhone 17 Pro)의 상단 안전 영역은
/// 62pt라, 띠는 시계 위쪽 여백만 덮고 정작 글자가 겹치는 28~62pt 구간을 비워 두고
/// 있었다 — 시뮬레이터에서 색 띠로 좌표를 재서 확인했다.
///
/// `ignoresSafeArea(edges: .top)`를 **frame 다음에** 걸어야 띠가 화면 맨 위(y=0)를
/// 기준으로 놓인다. 걸지 않으면 안전 영역 아래(62pt)에서 시작한다. 높이는 기기마다
/// 다르므로(다이내믹 아일랜드 62 · 노치 47~54 · SE 20) 배경의 `GeometryReader`로 잰다.
struct TopStatusScrim: ViewModifier {
    @State private var inset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { inset = proxy.safeAreaInsets.top }
                        .onChange(of: proxy.safeAreaInsets.top) { _, value in inset = value }
                }
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: BaseballTheme.canvas, location: 0),
                        .init(color: BaseballTheme.canvas, location: opaqueStop),
                        .init(color: BaseballTheme.canvas.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: inset + Self.fade)
                // 이 한 줄이 띠를 화면 맨 위로 올린다. 순서를 바꾸면 안 된다.
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    /// 상태바 아래로 풀어 주는 길이. 경계가 선처럼 보이지 않을 만큼만.
    private static let fade: CGFloat = 20
    private var opaqueStop: CGFloat { inset <= 0 ? 0 : inset / (inset + Self.fade) }
}

extension View {
    /// 내비게이션 바를 숨긴 화면에서 상태바와 본문이 겹치지 않게 한다.
    func topStatusScrim() -> some View { modifier(TopStatusScrim()) }
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
    @Environment(\.gameCopyResolver) private var copyResolver

    private var played: [ProGameLine] { log.filter(\.played) }
    private var auto: [ProGameLine] { log.filter { !$0.played } }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionSeasonRecordTitle)) {
            VStack(alignment: .leading, spacing: 12) {
                if !played.isEmpty {
                    summary(
                        title: copyResolver.resolve(AppCopyKey.conclusionDirectOutings),
                        lines: played, accent: BaseballTheme.action
                    )
                }
                if !auto.isEmpty {
                    summary(
                        title: copyResolver.resolve(AppCopyKey.conclusionTeamGames),
                        lines: auto, accent: BaseballTheme.textTertiary
                    )
                }
                Text(copyResolver.resolve(AppCopyKey.conclusionRecentGames))
                    .eyebrowStyle(BaseballTheme.textTertiary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.suffix(5).reversed()) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(copyResolver.resolve(
                                AppCopyKey.conclusionSeasonLabel,
                                arguments: [.integer(line.season)]
                            ))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text(HighSchoolConclusionPresentation.localizedSeasonRole(
                                line, resolver: copyResolver
                            ))
                                .font(.footnote.weight(.semibold).monospacedDigit())
                            Spacer()
                            // localization-safe: numeric
                            Text(GameLineFormat.score(line))
                                .font(.footnote.weight(.bold).monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            if let decision = HighSchoolConclusionPresentation.localizedSeasonDecision(
                                line.decision, resolver: copyResolver
                            ) {
                                // localization-safe: resolved-copy
                                Text(decision)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(HighSchoolConclusionPresentation.localizedSeasonLineAccessibility(
                            line, resolver: copyResolver
                        ))
                    }
                }
            }
            .accessibilityIdentifier("hs.seasonRecord")
        }
    }

    private func summary(title: String, lines: [ProGameLine], accent: Color) -> some View {
        return VStack(alignment: .leading, spacing: 3) {
            // localization-safe: resolved-copy
            Text(title).eyebrowStyle(accent)
            Text(HighSchoolConclusionPresentation.localizedSeasonSummary(
                lines: lines, resolver: copyResolver
            ))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            Text(HighSchoolConclusionPresentation.localizedSeasonRA9(
                lines: lines, resolver: copyResolver
            ))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 평가 항목을 줄바꿈하며 늘어놓는다. 항목 수가 회차마다 달라서 고정 열 배치가 맞지 않는다.
private struct FlowRow: View {
    let items: [String]
    let resolver: GameCopyResolver

    var body: some View {
        // 두 개씩 짝지어 놓는다. iOS 16의 Layout 프로토콜까지 갈 만큼 복잡한 배치가 아니다.
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { index in
                HStack(spacing: 14) {
                    ForEach(items[index..<min(index + 2, items.count)], id: \.self) { item in
                        // localization-safe: resolved-copy
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
        .accessibilityLabel(resolver.resolve(
            AppCopyKey.conclusionEvaluationBreakdownAccessibility,
            arguments: [.userText(items.joined(separator: ", "))]
        ))
    }
}

/// 드래프트 점수와 야구혼은 서로 다른 회계다. 회차 바람이 둘 중 어디에 손댔는지
/// 정산에서 따로 보여 줘야 최종 점수와 다음 회차 보상을 역산할 수 있다.
private struct WindSettlementCard: View {
    let wind: CareerWind
    @Environment(\.gameCopyResolver) private var copyResolver

    @ViewBuilder var body: some View {
        if wind.rules.draftEvaluationDelta != 0 || wind.rewardBonusPermille != 0 {
            let localizedWind = HighSchoolConclusionPresentation.localizedWind(
                wind, resolver: copyResolver
            )
            BaseballCard(title: copyResolver.resolve(
                AppCopyKey.conclusionWindReview,
                arguments: [.userText(localizedWind.title)]
            ), tone: .raised) {
                VStack(alignment: .leading, spacing: 5) {
                    if wind.rules.draftEvaluationDelta != 0 {
                        let delta = wind.rules.draftEvaluationDelta
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionDraftAdjustment,
                            arguments: [.integer(delta)]
                        ))
                    }
                    if wind.rewardBonusPermille != 0 {
                        let percent = wind.rewardBonusPermille / 10
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionInheritanceAdjustment,
                            arguments: [.integer(percent)]
                        ))
                    }
                    // localization-safe: resolved-copy
                    Text(localizedWind.detail)
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                .font(.footnote.monospacedDigit().weight(.semibold))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// 고교 3년 목표 — 시작에서 하나를 고른다.
///
/// 학교를 고르는 자리(선택의 국면)에 함께 둔다. 강요하지 않는다 — "약속 없이 간다"도
/// 당당한 선택지다. 건 약속은 대시보드에 상시 노출되고, 등급에 따라 야구혼 +10~35%.
private struct PledgeCard: View {
    let state: HighSchoolCareerSnapshot
    let intent: NextRunIntent?
    let rivalLedger: HighSchoolCareerStore.RivalLedger
    /// 1회차에는 '야구혼'이라는 아직 등장 전인 화폐 대신 결과 언어로 말한다.
    var isFirstLife: Bool = false
    let onChoose: (String?) -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        BaseballCard(title: copyResolver.resolve(.pledgeCardTitle), tone: .milestone) {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    verbatim: copyResolver.resolve(
                        isFirstLife ? .pledgeIntroFirst : .pledgeIntroRepeat
                    )
                )
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                // **누르라고 말한다.**
                //
                // 목표 카드들은 색 있는 면에 테두리까지 둘러 "정보 패널"로 읽혔다 —
                // 실제로 사용자가 이 화면에서 무엇을 눌러야 하는지 몰랐다. 카드가
                // 버튼처럼 안 보이면 지시문 한 줄이 그 일을 대신해야 한다.
                Label {
                    Text(verbatim: copyResolver.resolve(.pledgeHint))
                } icon: {
                    Image(systemName: "hand.tap.fill")
                }
                    .font(.footnote.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hs.pledge.hint")
                ForEach(RunPledge.options(careerID: state.careerID, state: state, intent: intent)) { pledge in
                    let progress = pledge.progress(in: .init(state: state, rivalLedger: rivalLedger))
                    let carried = intent?.pledgeID == pledge.id
                    Button { onChoose(pledge.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if carried {
                                    Text(verbatim: copyResolver.resolve(.pledgeCarried))
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                                Text(
                                    verbatim: LegacyPresentation.pledgeTier(
                                        pledge.tier, resolver: copyResolver
                                    )
                                )
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(pledge.tier == .legendary
                                                     ? BaseballTheme.warning : BaseballTheme.textSecondary)
                                Spacer(minLength: 0)
                                Text(
                                    verbatim: copyResolver.resolve(
                                        .pledgeReward,
                                        arguments: [.integer(pledge.rewardPermille / 10)]
                                    )
                                )
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(
                                    verbatim: LegacyPresentation.pledgeTitle(
                                        pledge, resolver: copyResolver
                                    )
                                )
                                .font(.subheadline.weight(.bold))
                                Spacer(minLength: 0)
                                // 화살표 하나가 "이 줄은 눌린다"를 말한다. 목록 UI의
                                // 가장 값싸고 가장 확실한 신호다.
                                Text(verbatim: copyResolver.resolve(.pledgeChoose))
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.milestone)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            Text(
                                verbatim: LegacyPresentation.pledgeDetail(
                                    pledge, resolver: copyResolver
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            Text(
                                verbatim: LegacyPresentation.pledgeAlignment(
                                    pledge, state: state, resolver: copyResolver
                                )
                            )
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(BaseballTheme.milestone.opacity(0.1), in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(BaseballTheme.milestone.opacity(0.6), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hs.pledge.\(pledge.id)")
                    .accessibilityLabel(
                        LegacyPresentation.pledgeAccessibility(
                            pledge: pledge, progress: progress, carried: carried,
                            resolver: copyResolver
                        )
                    )
                }
                Button { onChoose(nil) } label: {
                    Text(verbatim: copyResolver.resolve(.pledgeSkip))
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.pledge.skip")
            }
        }
    }
}

/// `onAppear`는 긴 `ScrollView`의 아직 보이지 않는 자식에도 호출될 수 있다. 분석 퍼널의
/// 노출은 카드가 실제 화면에 들어온 순간 한 번만 기록한다.
private struct ViewportExposureModifier: ViewModifier {
    @State private var hasReported = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                Color.clear
                    .onAppear { reportIfVisible(frame) }
                    .onChange(of: frame) { _, newFrame in reportIfVisible(newFrame) }
            }
        }
    }

    private func reportIfVisible(_ frame: CGRect) {
        guard !hasReported, frame.width > 0, frame.height > 0 else { return }
        let visible = frame.intersection(UIScreen.main.bounds)
        guard !visible.isNull, visible.height >= min(44, frame.height * 0.25) else { return }
        hasReported = true
        action()
    }
}

private extension View {
    func onViewportExposure(perform action: @escaping () -> Void) -> some View {
        modifier(ViewportExposureModifier(action: action))
    }
}
