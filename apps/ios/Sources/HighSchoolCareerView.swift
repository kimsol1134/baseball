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
    /// 오늘의 이닝(일일 도전) 표시 여부.
    @State private var showsDaily = false
    /// 복귀 알림 권유 카드를 지금 띄우는가. 한 번 답하면 이 세션에서는 다시 묻지 않는다.
    @State private var showsReminderNudge = DailyReminder.shouldOfferOptIn()
    @Environment(\.requestReview) private var requestReview

    /// 오늘의 이닝 입구를 지금 화면에 두어도 되는가. 순수 함수라 테스트할 수 있다.
    ///
    /// 첫 중요 경기를 끝내기 전에는 보여 주지 않는다 — 본편의 손맛을 보기도 전에 곁가지
    /// 모드가 보이면 무엇이 이 게임인지 흐려진다. 그 뒤로는 승부(투구 화면)와 각성
    /// (되돌릴 수 없는 선택) 두 국면만 뺀다.
    static func showsDailyEntry(phase: HighSchoolCareerPhase, gamesCompleted: Int) -> Bool {
        guard gamesCompleted >= 1 else { return false }
        switch phase {
        case .importantGame, .awakening, .prologue: return false
        default: return true
        }
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
                    // 비파괴 출구가 먼저다. 시드 오타 하나로 도달하는 화면의 유일한
                    // 버튼이 "전 회차 삭제"면 그건 함정이다(4차 패널 P0).
                    PrimaryPill(title: "설정으로 돌아가기", identifier: "hs.retry") {
                        career.returnToSetup()
                    }
                    Button("모든 기록을 지우고 새로 시작", role: .destructive) {
                        confirmingReset = true
                    }
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("hs.restart")
                    .confirmationDialog(
                        "모든 선수 기록을 지울까요?",
                        isPresented: $confirmingReset,
                        titleVisibility: .visible
                    ) {
                        Button("야구혼·기억·아카이브를 모두 지운다", role: .destructive) {
                            career.deleteCareer()
                        }
                        // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                        Button("돌아간다") { confirmingReset = false }
                    } message: {
                        Text("환생으로 쌓은 모든 것이 사라집니다. 되돌릴 수 없습니다.")
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
            DraftRevealView(result: reveal.result, playerName: reveal.playerName) { draftReveal = nil }
        }
        // **결과가 나오는 순간**에만 연출한다. 조건식(`draftResult != nil`)으로 띄우면
        // 기억을 고르는 내내 조건이 참이라 화면이 계속 덮인다. `onChange`는 값이 바뀔 때만
        // 불리므로, 저장본을 다시 열었을 때 3년 전의 호명 장면이 되풀이되지도 않는다.
        .onChange(of: career.state?.draftResult?.evaluationScore) { previous, current in
            guard previous == nil, current != nil,
                  let state = career.state, let draft = state.draftResult else { return }
            draftReveal = DraftReveal(
                // 3년의 정산 장면이니 별명을 함께 부른다 — "'제로' 김솔".
                result: draft, playerName: career.displayName(state.identity.name), careerID: state.careerID
            )
        }
        // 스탬프가 **먼저** 뜨고, 닫히면서 회차를 넘긴다.
        //
        // 반대로(회차를 먼저 넘기고 스탬프를 띄우면) 화면이 갈아 끼워지는 순간에 전면
        // 화면을 올리는 셈이라 표시가 들쭉날쭉했다. 연출이 곧 전환이면 그런 경합이 없다.
        .fullScreenCover(isPresented: $showsDaily) {
            DailyInningView(onClose: { showsDaily = false }, source: "career_entry", weekly: weekly)
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
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                        // 회차 번호는 **스냅숏**에서 읽는다.
                        //
                        // 예전에는 스토어의 계승분(`inheritance.lifeNumber`)을 그대로 썼다. 그건
                        // "다음에 시작할 회차"의 번호라, 기억을 확정한 순간 1 늘어난다. 그래서
                        // 1회차의 마지막 화면(완료)에 "2회차"라고 적혀 있었다 — 아직 끝나지도
                        // 않은 회차가 다음 번호를 미리 달고 있었던 셈이다.
                        ChapterHeader(state: state, lifeNumber: state.lifeNumber)

                        if !achievements.freshlyUnlocked.isEmpty {
                            AchievementBanner(achievements: achievements.freshlyUnlocked) {
                                achievements.acknowledge()
                            }
                            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }

                        // 만개는 성장 축하보다 앞에 온다. 같은 훈련에서 둘 다 나면
                        // 먼저 읽어야 하는 것은 "벽이 열렸다"는 쪽이다.
                        Color.clear.frame(height: 0).id(Self.celebrationAnchor)
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
                            SummaryBanner(summary: summary, cue: career.feedbackCue)
                        }
                        // 3년에 세 번뿐인 각성 앞에서는 주변 소음을 접는다(QA P2-2) —
                        // 되돌릴 수 없는 선택이 목록 한 줄로 보이면 무게가 사라진다.
                        if state.phase != .awakening {
                            if !career.buzz.isEmpty {
                                CommunityBuzzCard(lines: career.buzz)
                            }
                            if !career.worldNews.isEmpty {
                                CommunityBuzzCard(title: "전국의 소식", footnote: "라이벌들도 저마다의 3년을 살고 있습니다.", lines: career.worldNews)
                            }
                        }
                        // 오늘의 이닝 — 하루 한 판, 전국 같은 타순. 회차 진행과 무관한
                        // "오늘 3분"의 이유.
                        //
                        // 예전에는 **훈련 국면에서만** 보였다. 2026-08 데이터에서 DAU 43명 중
                        // 이 화면을 연 사람은 3명(7%)이었고 D2 리텐션은 0%였다 — 사람들은 첫
                        // 세션에 1회차를 통째로 끝내고(1인당 10.6경기) 떠나는데, 그 마지막
                        // 화면들(드래프트·기억 선택·완료)에는 내일 켤 이유가 하나도 없었다.
                        // 이제 승부·각성처럼 집중이 필요한 국면만 빼고 늘 보인다.
                        if Self.showsDailyEntry(phase: state.phase,
                                                gamesCompleted: state.performance.importantGamesCompleted) {
                            DailyInningEntryRow { showsDaily = true }
                            WeeklyProgramSummaryRow(store: weekly)
                        }
                        // 복귀 알림 권유 — 첫 중요 경기를 끝낸 직후(감정이 양)에 딱 한 번.
                        // 예전에는 이 스위치가 오늘의 이닝 화면 **안에만** 있었다. 즉 7%만
                        // 여는 화면 안에 리텐션 장치가 갇혀 있었다.
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
                                    Text("목표 · \(pledge.title)")
                                        .font(.footnote.weight(.bold))
                                    Spacer(minLength: 0)
                                    Text("\(progress.ratioPermille / 10)%")
                                        .font(.caption.monospacedDigit().weight(.bold))
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                                Text(progress.line)
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                ProgressView(value: Double(progress.ratioPermille), total: 1_000)
                                    .tint(BaseballTheme.milestone)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(pledge.tier.title) 목표, \(pledge.title), \(progress.line), 보상 야구혼 \(pledge.rewardPermille / 10)퍼센트 추가")
                        }
                        // 드래프트가 끝난 회차에 챕터 숙제는 소음이다. 각성 국면도 접는다.
                        if state.draftResult == nil, state.phase != .awakening {
                            if TournamentBracket.isTournamentChapter(state.chapter.number),
                               let school = state.school {
                                TournamentCard(state: state, schoolName: school.name)
                            }
                            // 공식 경기가 없는 장에서는 탈삼진 숙제를 내지 않는다 —
                            // 던질 기회를 안 주고 "삼진 5개"를 네 화면에서 반복하면,
                            // 게임이 지키지 못할 약속을 하는 것이 된다.
                            if (state.schedule ?? .fixedDefault)
                                .hasImportantGame(inChapter: state.chapter.number) {
                                ChapterGoalCard(state: state, career: career)
                            }
                        }

                        phaseBody(state: state)
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
                    // 완료·유산처럼 긴 화면의 마지막 CTA가 시스템 탭 바와 맞닿지 않게
                    // 실제 안전 영역 안에 한 번 더 숨을 준다.
                    .safeAreaPadding(.bottom, 12)
                }
                // 빠른 환생은 같은 화면 안에서 새 careerID로 즉시 갈아탄다. ScrollView를
                // 재사용하면 직전 결산의 깊은 스크롤 위치가 남아 새 프롤로그·지난 선수의
                // 편지가 화면 위쪽 밖에 갇힌다. 회차마다 새 스크롤 정체성을 줘 맨 위에서
                // 시작한다.
                .id(state.careerID)
                .background(BaseballTheme.canvas)
                // 스크롤 콘텐츠가 상태바 밑을 그대로 지나면 시계와 제목이 겹친다(QA P2-3).
                .topStatusScrim()
                // 화면 전체에 .animation(value:)을 걸면 같은 국면 안의 카드 교체
                // (훈련→훈련)에서 옛 글자와 새 글자가 두 겹으로 보인다(QA P0-2).
                // 갱신은 즉시가 맞다 — 회차당 수백 번 겪는 전환은 연출보다 빠름이 이긴다.
                .phaseCurtain(state.phase, disabled: reduceMotion)
                // 성장·만개는 스택 위쪽에서 터지는데 유저는 방금 맨 아래 "훈련하기"를
                // 눌렀다 — 게임의 최다 보상이 화면 밖에서 소비되고 있었다(3차 패널 P1).
                .onChange(of: career.feedbackTrigger) { _, _ in
                    guard career.pendingBloom != nil || !career.pendingGains.isEmpty else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        proxy.scrollTo(Self.celebrationAnchor, anchor: .top)
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
            SchoolSelectionCard(options: state.schoolOptions, onChoose: career.chooseSchool)
        case .training:
            // 챕터 누적 한 줄 — 100번의 +1이 낱장으로 흩어지지 않게 "한 단위"를 만든다.
            if career.chapterTrainingCount > 0 {
                let summary = career.chapterGains
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key) +\($0.value)" }
                    .joined(separator: " · ")
                Text("이번 이야기 훈련 \(career.chapterTrainingCount)회"
                     + (summary.isEmpty ? "" : " — \(summary)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("hs.training.tally")
            }
            TrainingCard(
                state: state,
                armHealth: career.armHealth,
                onCommit: { focus, intensity in
                    audio.play(.uiSelect)
                    career.commitTraining(focus: focus, intensity: intensity)
                },
                onCommitBlock: { focus, intensity in
                    audio.play(.uiSelect)
                    career.commitTrainingBlock(focus: focus, intensity: intensity)
                }
            )
        case .relationship:
            RelationshipCard(state: state, onRespond: career.resolveRelationship)
        case .importantGame:
            ImportantGameCard(state: state, rivalLine: career.rivalLedger.summaryLine,
                              onStart: career.beginImportantGame)
        case .awakening:
            AwakeningCard(options: state.awakeningOptions, sparks: state.awakeningSparks,
                          beforeFirstGame: state.performance.importantGamesCompleted == 0,
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

// MARK: - 내일 켤 이유

/// 오늘의 이닝 입구 한 줄. 연속 기록이 있으면 그것이 문구가 된다 — 숫자가 쌓여 있으면
/// 하루 건너뛰는 데 비용이 생기고, 그 비용이 내일 켜는 이유다.
private struct DailyInningEntryRow: View {
    let onOpen: () -> Void

    private var todayBest: Int {
        UserDefaults.standard.integer(forKey: "baseball.daily.best.\(PitchScenario.todayKey())")
    }

    var body: some View {
        let streakCaption = DailyStreak.caption()
        // "오늘 아직" 배지는 **오늘의 이닝**을 던졌는지만 묻는다. 연속 일수(캡션)는
        // 커리어 경기까지 세지만, 이 배지까지 그러면 오늘의 이닝을 안 던진 사람에게
        // "다 했다"고 말하게 된다.
        let played = DailyStreak.playedDailyInningToday()
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Image(systemName: played ? "flame.fill" : "calendar.badge.clock")
                    .foregroundStyle(BaseballTheme.milestone)
                VStack(alignment: .leading, spacing: 1) {
                    Text("오늘의 이닝").font(.footnote.weight(.bold))
                    Text(streakCaption
                         ?? (todayBest > 0 ? "오늘 최고 \(todayBest)점 · 재도전"
                             : "전국이 같은 타순 · Game Center 순위"))
                        .font(.caption2).foregroundStyle(BaseballTheme.textSecondary)
                }
                Spacer(minLength: 0)
                // 오늘 아직 안 던졌다는 사실이 한눈에 보여야 배지가 일을 한다.
                if !played {
                    Text("오늘 아직")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BaseballTheme.canvas)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(BaseballTheme.milestone, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(BaseballTheme.milestone.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BaseballTheme.milestone.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hs.daily.entry")
    }
}

/// 복귀 알림 권유. 정직하게 무엇을 언제 보내는지 적고, 거절도 한 탭이다.
private struct ReminderNudgeCard: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        BaseballCard(title: "내일도 이어 던지기", tone: .raised) {
            VStack(alignment: .leading, spacing: 10) {
                Text("매일 저녁 7시 30분, 지금 키우는 선수의 다음 목표나 그날의 이닝 중 이어 할 한 가지를 알려 드립니다. 며칠 안 열면 저절로 멈춥니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PrimaryPill(title: "알림 켜기", identifier: "hs.reminder.enable", action: onEnable)
                    Button("괜찮습니다") { onDismiss() }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                        .accessibilityIdentifier("hs.reminder.decline")
                }
            }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text("기록 없는 도전 결과").eyebrowStyle(BaseballTheme.milestone)
            BaseballCard(title: state.draftResult?.outcome == .drafted ? "지명 성공" : "지명 실패",
                         tone: state.draftResult?.outcome == .drafted ? .milestone : .raised) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("스카우트 평가 \(state.draftResult?.evaluationScore ?? 0)점")
                        .font(.title3.weight(.heavy).monospacedDigit())
                    Text("경기 \(state.performance.importantGamesCompleted) · \(state.performance.strikeouts)탈삼진 · \(state.performance.walks)볼넷 · \(state.performance.runsAllowed)실점")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            Text("이 도전은 선수 기록·야구혼·계승에 남지 않습니다. 원래 진행은 그대로입니다.")
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "도전을 닫는다", identifier: "hs.challenge.close", action: onClose)
        }
    }
}

// MARK: - 머리말

private struct ChapterHeader: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int
    @State private var windExpanded = false

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
                    ? "\(lifeNumber)번째 선수 · \(HighSchoolPresentation.actTitle(chapter: state.chapter.number)) · \(state.chapter.schoolYear)학년 \(state.chapter.season)"
                    : "\(HighSchoolPresentation.actTitle(chapter: state.chapter.number)) · \(state.chapter.schoolYear)학년 \(state.chapter.season)",
                title: state.school.map { "\($0.name) · \(state.chapter.title)" } ?? state.chapter.title
            )
            HStack(spacing: 10) {
                // 주인공의 얼굴. 게임에서 가장 자주 보는 화면인데 정작 주인공이 없었다.
                // 1학년(챕터 1~3)은 앳된 얼굴, 2학년부터는 에이스 얼굴 — 성장이 눈에 보인다.
                PortraitView(seed: state.identity.name, role: .player, size: 46,
                             playerStage: state.chapter.schoolYear <= 1 ? .freshman : .ace)
                Metric(title: "피로", value: "\(state.fatigue)", tone: state.fatigue >= 70 ? .warning : .standard)
                Metric(title: "팀의 믿음", value: "\(state.relationshipTrust)")
                Metric(title: "훈련", value: "\(state.totalTrainingsCompleted)")
            }
            if state.phase != .prologue {
                let wind = state.careerWind
                Button { windExpanded.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                        Text(wind.title)
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
                .accessibilityLabel("이번 3년의 바람, \(wind.title), 효과 설명 \(windExpanded ? "접기" : "펼치기")")

                if windExpanded {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(wind.detail)
                        ForEach(wind.effectDescriptions, id: \.self) { effect in
                            Text("· \(effect)")
                        }
                        if wind.effectDescriptions.isEmpty {
                            Text("· 능력과 보상 보정 없음")
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
                         ? (state.news.first(where: { !$0.hasPrefix("이번 3년의 바람") }) ?? "고교 3년이 다시 시작됩니다.")
                         : "\u{201C}몸부터 풀자. 불펜에서 한 구 던져 봐.\u{201D} — 감독")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    // 1회차에는 코어가 만든 중학교 맥락을 감독의 말 아래에 붙인다.
                    // 이 한 줄이 없으면 "왜 이 학교들이 나를 부르는가"가 화면에 없다.
                    // 바람 뉴스가 첫 줄을 차지할 수 있다 — 중학교 맥락은 바람이 아닌 첫 줄이다.
                    if lifeNumber == 1, let context = state.news.first(where: { !$0.hasPrefix("이번 3년의 바람") }) {
                        Text(context)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // 이번 회차의 바람 — 카르마(내 선택)와 달리 세계가 정한 조건이다.
                    // 판이 다르다는 걸 시작에서 모르면 회차 변주는 없는 것과 같다.
                    let wind = state.careerWind
                    Divider()
                    BaseballCard(title: "이번 3년의 바람 · \(wind.title)", tone: .raised) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(wind.detail).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(wind.effectDescriptions, id: \.self) { effect in
                                Text("· \(effect)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.information)
                            }
                            if wind.effectDescriptions.isEmpty {
                                Text("능력과 보상 보정 없이 실력만으로 승부합니다.")
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                        }
                    }
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
            // 주 행동이 능력치 표보다 먼저다 — 첫 화면에서 "다음에 뭘 누르지"가
            // 접힘선 아래에 있으면 유료 게임의 첫 30초를 버리는 것이다(QA P0-1).
            // 이 게임에서 가장 좋은 것은 투구다. 사는 사람이 그걸 두 번째 탭에서 만나게 한다.
            PrimaryButton(title: "첫 공을 던진다", identifier: "hs.prologue.throw", action: onThrow)
            Button("바로 학교 고르기", action: onSkip)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.prologue.continue")
            BaseballCard(title: "지금의 나") {
                VStack(alignment: .leading, spacing: 10) {
                    // 재능 등급과 한계선을 함께 보여 준다. 이 회차가 어떤 투수인지가
                    // 시작 수치가 아니라 여기서 정해진다.
                    let talent = state.talent ?? .unlimited
                    AbilityGaugeView(label: "구위", value: state.pitcher.stuff, talent: talent.stuff)
                    AbilityGaugeView(label: "제구", value: state.pitcher.command, talent: talent.command)
                    AbilityGaugeView(label: "변화구", value: state.pitcher.movement, talent: talent.movement)
                    AbilityGaugeView(label: "체력", value: state.pitcher.stamina, talent: talent.stamina)
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
                        // 3년을 함께할 두 사람이다. 이름만 적혀 있으면 학교 선택이
                        // 스펙 비교표가 되고, 누구와 지낼지는 선택에 들어오지 않는다.
                        // 네 학교 인물은 PortraitView의 고정표가 변주를 하나씩 배정해
                        // 나란히 서도 같은 얼굴이 없고, 1:1 장면과 얼굴이 이어진다.
                        AvatarRow(seed: school.coachName, role: .coach,
                                  name: "\(school.coachName) 감독", caption: school.coachArchetype, size: 40)
                        AvatarRow(seed: school.catcherName, role: .catcher,
                                  name: "\(school.catcherName) 포수", caption: school.catcherArchetype, size: 40)
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
            pending.map { "\($0.name)\(KoreanCopy.ro($0.name)) 가시겠습니까?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { school in
            Button("이 학교로 간다") {
                onChoose(school.id)
                pending = nil
            }
            .accessibilityIdentifier("hs.school.confirm")
            // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣어 취소를 항상 보이게 한다.
            Button("다시 고른다") { pending = nil }
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
    let onCommitBlock: (TrainingFocus, TrainingIntensity) -> Void

    // 직전 선택에서 시작한다. 국면이 오갈 때마다 기본값으로 리셋되면
    // 같은 훈련을 이어가려는 사람이 회차당 16번 재선택을 강요당한다.
    @State private var focus: TrainingFocus
    @State private var intensity: TrainingIntensity

    init(state: HighSchoolCareerSnapshot, armHealth: ArmHealthState,
         onCommit: @escaping (TrainingFocus, TrainingIntensity) -> Void,
         onCommitBlock: @escaping (TrainingFocus, TrainingIntensity) -> Void) {
        self.state = state
        self.armHealth = armHealth
        self.onCommit = onCommit
        self.onCommitBlock = onCommitBlock
        _focus = State(initialValue: state.lastTraining?.focus ?? .command)
        _intensity = State(initialValue: state.lastTraining?.intensity ?? .standard)
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

    /// 전망을 말로 옮긴다. 확률 숫자가 아니라 구간만 말한다 — 판정의 무작위 폭은 그대로다.
    private var outlookCopy: (text: String, tone: Color) {
        switch outlook {
        case .wall:
            return ("지금은 재능의 벽에 막혀 수치가 오르지 않습니다. 대신 계속 두드리면 벽이 열립니다.", BaseballTheme.milestone)
        case .two:
            return ("크게 오를 훈련입니다. +2가 유력합니다.", BaseballTheme.positive)
        case .oneOrTwo:
            return ("+1은 확실하고, 잘 풀리면 +2까지 오릅니다.", BaseballTheme.positive)
        case .one:
            return ("+1이 확실한 훈련입니다.", BaseballTheme.textSecondary)
        case .zeroOrOne:
            return ("+1이 나올 수도, 성장 없이 지날 수도 있습니다.", BaseballTheme.textSecondary)
        case .none:
            return ("이대로면 성장 없이 지나갑니다. 피로가 높거나 강도가 약합니다.", BaseballTheme.warning)
        }
    }

    private func windEffect(for option: TrainingFocus) -> String? {
        let wind = state.careerWind
        var effects: [String] = []
        let growth = wind.rules.trainingGrowthBonus(for: option)
        if growth != 0 { effects.append("성장 \(growth > 0 ? "+" : "")\(growth)") }
        if option == .recovery, wind.rules.recoveryBonus != 0 {
            let bonus = wind.rules.recoveryBonus
            effects.append("회복 \(bonus > 0 ? "+" : "")\(bonus)")
        }
        let fatigue = wind.rules.trainingFatigueModifier(for: option)
        if fatigue != 0 { effects.append("피로 \(fatigue > 0 ? "+" : "")\(fatigue)") }
        return effects.isEmpty ? nil : "\(wind.title): " + effects.joined(separator: " · ")
    }

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
                let isSchoolStrength = state.school?.strength == option
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
                                // 학교 특기는 3년 내내 붙는 상수 보너스인데, 학교 선택 화면
                                // 이후로는 어디에도 안 보였다. 기회와 특기가 겹치는 턴을
                                // 알아보는 것이 훈련의 진짜 결정이라 여기 있어야 한다.
                                if isSchoolStrength {
                                    Text("특기")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(BaseballTheme.action.opacity(0.25), in: Capsule())
                                        .foregroundStyle(BaseballTheme.action)
                                }
                            }
                            Text(HighSchoolPresentation.focusDetail(option))
                                .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            if let windEffect = windEffect(for: option) {
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

            BaseballCard(title: "강도") {
                VStack(alignment: .leading, spacing: 10) {
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
                    if doubleBonus {
                        Text("오늘은 학교 특기와 기회가 겹칩니다. 몰아붙일 자리입니다.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(outlookCopy.text)
                        .font(.footnote)
                        .foregroundStyle(outlookCopy.tone)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("hs.training.outlook")
                }
            }

            PrimaryButton(title: "훈련하기", identifier: "hs.training.commit") { onCommit(focus, intensity) }
            Button {
                onCommitBlock(focus, intensity)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("같은 훈련 최대 3회")
                        .font(.subheadline.weight(.semibold))
                    Text("대화·각성·공식 경기 또는 높은 피로 앞에서 자동으로 멈춥니다.")
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

    /// 이 대화에 얼굴이 있는가. 감독·포수·라이벌만 사람이고 나머지는 상황이다 —
    /// "팬레터"나 "시험 주간"에 얼굴을 붙이면 없는 인물을 만들어 내는 셈이 된다.
    static func portrait(
        for category: String,
        state: HighSchoolCareerSnapshot
    ) -> (seed: String, role: AvatarFace.Role, name: String)? {
        switch category {
        case "coach":
            guard let school = state.school else { return nil }
            return (school.coachName, .coach, "\(school.coachName) 감독")
        case "catcher":
            guard let school = state.school else { return nil }
            return (school.catcherName, .catcher, "\(school.catcherName) 포수")
        case "rival":
            return (state.rival.name, .rival, state.rival.name)
        default:
            return nil
        }
    }

    /// 이 장면의 목소리. 코어의 `RelationshipVoiceCatalog`가 원본이다.
    private var scene: RelationshipVoiceCatalog.Scene? {
        guard let event = state.currentRelationshipEvent else { return nil }
        return RelationshipVoiceCatalog.scene(eventID: event.id, category: event.category)
    }

    /// 화자의 신뢰도 구간. 같은 사람이라도 신뢰가 낮으면 다른 말을 한다.
    private var band: RelationshipVoiceCatalog.TrustBand {
        guard let scene else { return .mid }
        return RelationshipVoiceCatalog.trustBand(
            for: scene.speaker,
            manager: state.managerTrust ?? state.relationshipTrust,
            catcher: state.catcherTrust ?? state.relationshipTrust,
            rival: state.rivalTrust ?? state.relationshipTrust
        )
    }

    private var windEffect: String? {
        guard let category = state.currentRelationshipEvent?.category else { return nil }
        // Keep this presentation source-of-truth aligned with simulation. Extended
        // moments (growth/game/awakening/fan, for example) still settle against one
        // of the three trust channels and therefore receive the same wind modifier.
        let target = HighSchoolCareerEngine.relationshipTarget(forEventCategory: category)
        let wind = state.careerWind
        var effects: [String] = []
        if target == wind.rules.favoredRelationship, wind.rules.favoredRelationshipBonus != 0 {
            effects.append("믿음 변화 +\(wind.rules.favoredRelationshipBonus)")
        }
        if wind.rules.relationshipLossPenalty != 0 {
            effects.append("실패하면 믿음 손실 \(wind.rules.relationshipLossPenalty) 추가")
        }
        return effects.isEmpty ? nil : "\(wind.title): " + effects.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 대화가 이 화면의 주인공이다. 예전에는 요약 한 줄이 작은 글씨로 붙고 선택지가
            // 화면을 채워서, 무슨 일이 일어났는지보다 버튼 세 개가 먼저 눈에 들어왔다.
            if let event = state.currentRelationshipEvent {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        if let portrait = Self.portrait(for: event.category, state: state) {
                            PortraitView(seed: portrait.seed, role: portrait.role, size: 44)
                        } else {
                            // 사람이 아닌 화자(집·취재·팬·몸 상태…)는 얼굴 대신 상황 그림.
                            // 없는 인물을 지어내지 않으면서 빈 자리도 남기지 않는다.
                            ArtThumb(assetName: "SceneArt-\(event.category)", size: 44, cornerRadius: 8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Self.speaker(for: event.category)).eyebrowStyle(BaseballTheme.information)
                            if let portrait = Self.portrait(for: event.category, state: state) {
                                Text(portrait.name).font(.subheadline.weight(.bold))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    Text(event.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    // 손으로 쓴 인용 대사가 있으면 그것이 본문이고, 요약은 아래로 내려간다.
                    // 없는 장면은 예전처럼 요약만 쓴다 — 없는 대사를 지어내지 않는다.
                    let quote = (scene.map { $0.quote(band) } ?? "")
                        .replacingOccurrences(of: "{player}", with: state.identity.name)
                    if !quote.isEmpty {
                        Text(quote)
                            .font(.body)
                            .foregroundStyle(BaseballTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(event.summary)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(event.summary)
                            .font(.body)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            }
            if let windEffect {
                Label(windEffect, systemImage: "wind")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.information)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("어떻게 답할까요").font(.headline)
            ForEach(RelationshipResponse.allCases, id: \.self) { response in
                let choice = scene?.choices.first { $0.response == response }
                Button { onRespond(response) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(choice?.title ?? HighSchoolPresentation.response(
                            response,
                            category: state.currentRelationshipEvent?.category ?? ""
                        )).font(.subheadline.weight(.bold))
                        Text(choice?.detail ?? HighSchoolPresentation.responseDetail(response))
                            .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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
    /// 숙적과의 이번 회차 상대 전적 한 줄. 타석이 쌓이기 전에는 nil.
    var rivalLine: String? = nil
    let onStart: () -> Void

    /// 8챕터 — 이 회차에서 그를 상대하는 마지막 마운드다.
    private var isFinalShowdown: Bool { state.chapter.number == 8 }

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
            BaseballCard(title: isFinalShowdown ? "숙적 — 마지막 승부" : "상대", tone: .warning) {
                VStack(alignment: .leading, spacing: 8) {
                    AvatarRow(seed: state.rival.name, role: .rival,
                              name: state.rival.name, caption: state.rival.archetype, size: 48)
                    if let record = state.rival.signatureRecord {
                        Text(record).font(.footnote.monospacedDigit()).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    // 쌓인 역사. 전적이 있어야 이 타석이 서사가 된다.
                    if let rivalLine {
                        Text("고교 3년 상대 전적 — \(rivalLine)")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    if isFinalShowdown {
                        Text("3년의 마지막 마운드. 이 승부가 서로의 마지막 기억이 됩니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
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
    /// 각성의 전조(코어 값). nil은 전조 개념이 없던 저장본이다.
    var sparks: Int? = nil
    /// 아직 중요 경기를 안 던진 회차 초입인가. 증명할 무대가 없었던 선수에게
    /// "전조가 부족해"라고 벌점 문구를 주면 안 된다(4차 패널 P2).
    var beforeFirstGame = false
    let onChoose: (AwakeningID) -> Void

    @State private var pending: AwakeningID?

    /// 전조가 각성의 크기를 말한다. 갈래 수(코어가 이미 줄였다)에 서사를 붙여
    /// "왜 이만큼 열렸는지"를 읽게 한다 — 개연성은 숫자가 아니라 문장에서 생긴다.
    private var sparkLine: (text: String, tone: Color) {
        switch sparks ?? 3 {
        case 3...: ("시즌의 호투가 몸을 완전히 깨웠습니다 — 세 갈래가 전부 열렸습니다.", BaseballTheme.milestone)
        default: beforeFirstGame
            ? ("아직 증명할 무대가 없었습니다 — 두 갈래로 시작합니다. 마운드의 호투가 다음 각성을 넓힙니다.", BaseballTheme.textSecondary)
            : ("전조가 부족해 두 갈래만 열렸습니다. 호투(무실점·삼진쇼)와 만개가 다음 각성을 넓힙니다.", BaseballTheme.textSecondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            // 회차당 세 번뿐인 순간 — 목록이 아니라 무대를 준다(QA P2-2).
            KeyArtHeader(art: .awakening, eyebrow: "각성", title: "몸이 하나를 기억합니다", accent: BaseballTheme.milestone)
            Text(sparkLine.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(sparkLine.tone)
                .fixedSize(horizontal: false, vertical: true)
            Text("고른 각성은 되돌릴 수 없습니다.").font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
            ForEach(options, id: \.self) { option in
                let copy = HighSchoolPresentation.awakening(option)
                let family = RunPledge.awakeningFamily(for: option)
                Button { pending = option } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(copy.title).font(.subheadline.weight(.bold))
                        Text("\(family.title) 계열")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
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
                .accessibilityLabel("\(family.title) 계열, \(copy.title), \(copy.detail)")
                .accessibilityIdentifier("hs.awakening.\(option.rawValue)")
            }
        }
        // 마지막 선택지가 탭바에 잘리지 않게 — 잘린 선택지는 없는 선택지다.
        .padding(.bottom, 24)
        .confirmationDialog(
            pending.map {
                let title = HighSchoolPresentation.awakening($0).title
                return "'\(title)'\(KoreanCopy.ro(title)) 각성할까요?"
            } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { option in
            Button("이걸로 각성한다") {
                onChoose(option)
                pending = nil
            }
            .accessibilityIdentifier("hs.awakening.confirm")
            // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣어 취소를 항상 보이게 한다.
            Button("다시 고른다") { pending = nil }
        } message: { option in
            Text("\(RunPledge.awakeningFamily(for: option).title) 계열\n\(HighSchoolPresentation.awakening(option).detail)\n\n한 번 고르면 고교 3년 동안 바꿀 수 없습니다.")
        }
    }
}

private struct ChapterReviewCard: View {
    let state: HighSchoolCareerSnapshot
    /// 이번 챕터에 오른 능력치(라벨→증가폭). 첫 세션의 마지막 화면이 요약문 한 줄이면
    /// 40분의 훈련이 감정 없이 접힌다 — 여기가 작은 정산이어야 한다(2차 패널 P1).
    let gains: [String: Int]
    let trainingCount: Int
    let onContinue: () -> Void

    private var verdict: String {
        let p = state.performance
        if p.importantGamesCompleted == 0 { return "마운드 밖에서 보낸 시기였습니다. 다음 무대는 공으로 말할 차례입니다." }
        if p.walks == 0 && p.strikeouts >= 2 { return "볼넷 없이 지나온 시기 — 스카우트 수첩에 밑줄이 그어졌습니다." }
        if p.strikeouts > p.walks * 2 { return "삼진이 볼넷을 압도했습니다. 공이 소문을 내기 시작합니다." }
        return "숫자보다 과정이 남은 시기입니다. 폼은 거짓말하지 않습니다."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: "\(state.chapter.title) 마무리", tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verdict)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text("고교 공식 경기 \(state.performance.importantGamesCompleted)회 · \(state.performance.strikeouts)탈삼진 · \(state.performance.walks)볼넷")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            // 성장 정산 — 훈련이 실제로 몸에 남긴 것. 없으면 없다고 적는다.
            BaseballCard(title: "이번 이야기의 성장", tone: .raised) {
                if gains.isEmpty {
                    Text(trainingCount == 0
                         ? "훈련 없이 지나간 시기입니다."
                         : "훈련 \(trainingCount)회 — 아직 숫자로 드러나지 않은 성장입니다.")
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(gains.sorted { $0.value > $1.value }, id: \.key) { label, delta in
                            HStack {
                                Text(label).font(.subheadline)
                                Spacer()
                                Text("+\(delta)")
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                        Text("훈련 \(trainingCount)회의 결과입니다.")
                            .font(.caption2)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
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
            if !state.rival.name.isEmpty {
                Text("다음 이야기 — 상대는 더 강해집니다. \(state.rival.name)도 이 시기를 지켜봤습니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            PrimaryButton(title: "다음 이야기로", identifier: "hs.chapter.continue", action: onContinue)
        }
    }
}

/// 대회 대진 — 같은 경기도 "왕중왕전 준결승"이라는 무대 위에서는 무게가 다르다.
/// 커널 일정은 그대로다. 이 카드는 세계를 보여 줄 뿐, 일정에 대해 거짓말하지 않는다.
private struct TournamentCard: View {
    let state: HighSchoolCareerSnapshot
    let schoolName: String

    var body: some View {
        let field = TournamentBracket.field(
            careerID: state.careerID, chapterNumber: state.chapter.number, playerSchool: schoolName
        )
        BaseballCard(title: field.tournamentName, tone: .milestone) {
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
                Text("에이스 등판 — \(field.playerRound)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                // 대진: 두 팀씩 한 쌍. 내 학교가 굵게 빛난다.
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<4, id: \.self) { pair in
                        HStack(spacing: 6) {
                            bracketName(field.schools[pair * 2])
                            Text("—").font(.caption2).foregroundStyle(BaseballTheme.textTertiary)
                            bracketName(field.schools[pair * 2 + 1])
                        }
                    }
                }
                Text("전국 8팀. 스카우트들은 이런 무대의 공 하나를 오래 기억합니다.")
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .accessibilityIdentifier("hs.tournament")
    }

    private func bracketName(_ name: String) -> some View {
        Text(name)
            .font(.footnote.weight(name == schoolName ? .bold : .regular))
            .foregroundStyle(name == schoolName ? BaseballTheme.action : BaseballTheme.textSecondary)
    }
}

/// 이번 챕터의 숙제. "3년 뒤 드래프트"는 너무 멀다 — 오늘 훈련 하나를
/// 누르게 만드는 것은 이번 챕터의 숫자다.
private struct ChapterGoalCard: View {
    let state: HighSchoolCareerSnapshot
    let career: HighSchoolCareerStore

    var body: some View {
        let goal = ChapterGoal.goal(careerID: state.careerID, chapterNumber: state.chapter.number)
        let progress = max(0, state.performance.strikeouts - career.chapterStartStrikeouts)
        let done = career.goalCelebratedChapter == state.chapter.number || progress >= goal.targetStrikeouts
        BaseballCard(title: goal.title, tone: done ? .positive : .raised) {
            VStack(alignment: .leading, spacing: 8) {
                Text(done ? "완수 — 숙제는 끝났고, 다음은 욕심의 영역입니다." : goal.detail)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressView(value: Double(min(progress, goal.targetStrikeouts)),
                                 total: Double(goal.targetStrikeouts))
                        .tint(done ? BaseballTheme.positive : BaseballTheme.action)
                    Text("\(min(progress, goal.targetStrikeouts))/\(goal.targetStrikeouts)")
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
    var title = "그라운드 밖의 목소리"
    var footnote = "익명 야구 게시판의 반응입니다."
    let lines: [String]

    var body: some View {
        BaseballCard(title: title) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("└")
                            .font(.caption2)
                            .foregroundStyle(BaseballTheme.textTertiary)
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .accessibilityIdentifier("hs.buzz")
    }
}

/// 이 회차가 살아온 순간들. 결과(기록 카드)가 아니라 과정을 보여 준다 —
/// 드래프트 직전과 회차를 접는 순간, 두 번의 되돌아보는 자리에 선다.
private struct ChronicleCard: View {
    let entries: [HighSchoolCareerStore.ChronicleEntry]

    var body: some View {
        if !entries.isEmpty {
            BaseballCard(title: "3년의 이야기") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.stage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text(entry.text)
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

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: "드래프트", tone: .milestone) {
                Text("3년의 기록이 평가됩니다. 지명 여부가 지금 정해집니다.")
                    .font(.subheadline)
            }
            if let personality = career.personality {
                BaseballCard(title: "스카우트 평가서 — 기질") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("'\(personality.title)'")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                        Text(personality.scoutLine)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            BaseballCard(title: "3년의 기록") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("고교 공식 경기 \(state.performance.importantGamesCompleted)회")
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
            ChronicleCard(entries: chronicle)
            PrimaryButton(title: "결과 확인", identifier: "hs.draft.resolve", action: onResolve)
        }
    }
}

private struct LegacyCard: View {
    @State private var confirmingLegacy = false

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
                signatureLegacyCandidates: signatureCandidates
            )
            BaseballCard(title: "선수 기록 카드", tone: .milestone) {
                VStack(alignment: .leading, spacing: 10) {
                    LifeCardView(record: provisional)
                        .scaleEffect(0.72, anchor: .top)
                        .frame(height: LifeCardView.size.height * 0.72)
                        .frame(maxWidth: .infinity)
                    LifeCardShareButton(record: provisional)
                }
            }
            ChronicleCard(entries: career.chronicle)
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
            WindSettlementCard(wind: state.careerWind)
            if career.usesSignatureLegacyRules {
                BaseballCard(
                    title: "이 선수가 남길 대표 유산 · \(selectedSignatureLegacy == nil ? "0" : "1")/1",
                    tone: .milestone
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("직접 키운 능력과 실제 경기 기록으로 세 가지 유산이 만들어졌습니다.")
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                        Text("고른 하나는 새 선수에게 바로 이어지고, 나머지도 발견 목록에 남아 다음에 다시 고를 수 있습니다.")
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
                    Button { career.selectSignatureLegacy(legacy.id) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selected ? "checkmark.seal.fill" : "seal")
                                .foregroundStyle(selected ? BaseballTheme.milestone : BaseballTheme.border)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(legacy.title)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                Text(legacy.detail)
                                    .font(.footnote)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(legacy.evidence.summary)
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.information)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(HighSchoolSetupView.signatureLegacyEffectLine(legacy.effect))
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
                BaseballCard(title: "새 선수에게 남길 기억 · \(career.selectedMemories.count)/\(state.memorySlots)", tone: .milestone) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("기능 업데이트 전에 시작한 선수입니다. 당시 규칙대로 기억을 고릅니다.")
                            .font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        // 구규칙은 정확히 memorySlots장을 요구한다. 부족한 채로 확정하면
                        // 오류가 나므로 화면에서 막고 남은 장수를 알려 준다.
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
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.border)
                            ArtThumb(assetName: "MemoryArt-\(option.rawValue)", size: 52)
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
            }
            PrimaryButton(
                title: career.usesSignatureLegacyRules ? "대표 유산을 확정한다" : "기억을 확정한다",
                identifier: "hs.legacy.confirm"
            ) { confirmingLegacy = true }
                .disabled(
                    career.usesSignatureLegacyRules
                        ? selectedSignatureLegacy == nil
                        : career.selectedMemories.count != state.memorySlots
                )
                .confirmationDialog(
                    career.usesSignatureLegacyRules
                        ? "\(selectedSignatureLegacy?.title ?? "대표 유산")\(KoreanCopy.particle(selectedSignatureLegacy?.title ?? "대표 유산", final: "을", open: "를")) 새 선수에게 남길까요?"
                        : "기억 \(career.selectedMemories.count)장을 확정할까요?",
                    isPresented: $confirmingLegacy,
                    titleVisibility: .visible
                ) {
                    Button("확정하고 이 선수의 이야기를 닫는다") { career.confirmLegacy() }
                    Button("다시 고른다") { confirmingLegacy = false }
                } message: {
                    Text(career.usesSignatureLegacyRules
                         ? "이 선수의 고교 3년이 닫히고 되돌릴 수 없습니다. 고른 대표 유산 하나만 새 선수에게 직접 이어집니다."
                         : "기능 업데이트 전에 시작한 선수입니다. 당시 규칙대로 고른 기억만 새 선수에게 이어집니다.")
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
            WindSettlementCard(wind: state.careerWind)

            // 지명된 구단에서 누가 기다리는지. 이름만 있으면 "어느 팀"이 문자열 하나이고,
            // 프로 첫 시즌의 경쟁 구도가 시작 전에 서지 않는다.
            if let team = state.draftResult?.team, state.draftResult?.outcome == .drafted {
                BaseballCard(title: "\(team.name)에서 기다리는 사람", tone: .milestone) {
                    VStack(alignment: .leading, spacing: 10) {
                        AvatarRow(seed: team.proCoach, role: .coach,
                                  name: "\(team.proCoach) 코치", caption: team.coachProfile ?? team.developmentPlan, size: 44)
                        // 경쟁자를 player 역할로 두면 같은 카드에서 코치는 사진, 경쟁자는 벡터로
                        // 갈린다(QA P1-9) — 한 화면 안 화풍 혼재는 미완성으로 읽힌다.
                        AvatarRow(seed: team.positionCompetitor, role: .rival,
                                  name: team.positionCompetitor, caption: team.competitorProfile ?? "같은 자리를 두고 겨룰 선수", size: 44)
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
                PrimaryButton(title: "프로 커리어 시작", identifier: "hs.enterPro") {
                    onEnterPro(draft, state.pitcher, state.identity)
                }
                Text("이 선수의 이야기는 아직 끝나지 않았습니다.")
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
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
                BaseballCard(title: "프로에서 이어지는 이야기", tone: .milestone) {
                    Text("이 선수의 프로 커리어를 마치면 고교 시절과 통산 기록을 함께 돌아보고, 다음 선수에게 남길 대표 유산을 고릅니다.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if !opensLegacy {
                PrimaryButton(title: "\(career.inheritance.lifeNumber)번째 선수로 다시 시작",
                              identifier: "hs.rebirth", action: onRebirth)
                Text("기억 \(career.inheritance.memories.count)장 · 야구혼 \(career.inheritance.soulPoints)"
                     + "\(KoreanCopy.objectParticle(number: career.inheritance.soulPoints)) 안고 시작합니다.")
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    // 프로 포기는 이 게임에서 가장 무거운 되돌릴 수 없는 결정인데
                    // 학교 선택보다 마찰이 낮았다 — 같은 확인 문법을 준다.
                    confirmingFold = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("이 선수의 이야기를 접고 다시 시작")
                            .font(.subheadline.weight(.semibold))
                        Text("프로를 포기하고 새 선수로 시작합니다. 남길 기억을 고르게 됩니다.")
                            .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.rebirth")
                .confirmationDialog(
                    "프로 진출을 포기하고 이 선수의 이야기를 마칠까요?",
                    isPresented: $confirmingFold,
                    titleVisibility: .visible
                ) {
                    Button("접고 기억을 고른다", role: .destructive) { career.openLegacy() }
                    // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                    Button("돌아간다") { confirmingFold = false }
                } message: {
                    Text("프로 커리어를 시작하지 않고 이 선수의 이야기를 끝냅니다. 지명은 사라지고 되돌릴 수 없습니다.")
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

/// 국면이 바뀔 때 아주 짧게 어두워진다.
///
/// 예전에는 `.snappy` 크로스페이드만 있었다. 두 국면의 글자가 서로 비쳐 보였고(품질 평가
/// §3-F3), 무엇보다 **3년의 국면 변화가 전부 같은 질감으로 흘렀다.** 장면이 바뀌었다는
/// 감각이 없으면 학교 선택도 드래프트도 같은 목록을 스크롤하는 일이 된다.
///
/// 커튼은 아래 크로스페이드(.snappy ≈ 0.3초 + 정착)가 **끝날 때까지** 완전히 덮어야 한다.
/// 처음 넣었던 0.07+0.07초 커튼은 전환보다 먼저 걷혀서 전환 후반에 두 국면의 글자가
/// 다시 겹쳐 보였고, 그 프레임이 스토어 스크린샷에 그대로 찍혔다. 전환 자체를 볼거리로
/// 만들지는 않는다 — 정점 연출은 드물어서 정점이다.
private struct PhaseCurtain: ViewModifier {
    let phase: HighSchoolCareerPhase
    let disabled: Bool

    @State private var dim: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                BaseballTheme.canvas
                    .opacity(dim)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onChange(of: phase) { _, _ in
                guard !disabled else { return }
                // 총 0.24초 — 국면 전환은 회차당 수십 번이라, 커튼이 길면 "검은 화면"
                // 프레임이 눈에 밟힐 만큼 자주 보인다(QA P0-2: 무작위 110장 중 2장에 걸림).
                withAnimation(.easeIn(duration: 0.06)) { dim = 1 }
                withAnimation(.easeOut(duration: 0.10).delay(0.08)) { dim = 0 }
            }
    }
}

extension View {
    func phaseCurtain(_ phase: HighSchoolCareerPhase, disabled: Bool) -> some View {
        modifier(PhaseCurtain(phase: phase, disabled: disabled))
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

/// 드래프트 점수와 야구혼은 서로 다른 회계다. 회차 바람이 둘 중 어디에 손댔는지
/// 정산에서 따로 보여 줘야 최종 점수와 다음 회차 보상을 역산할 수 있다.
private struct WindSettlementCard: View {
    let wind: CareerWind

    @ViewBuilder var body: some View {
        if wind.rules.draftEvaluationDelta != 0 || wind.rewardBonusPermille != 0 {
            BaseballCard(title: "3년의 바람 돌아보기 · \(wind.title)", tone: .raised) {
                VStack(alignment: .leading, spacing: 5) {
                    if wind.rules.draftEvaluationDelta != 0 {
                        let delta = wind.rules.draftEvaluationDelta
                        Text("드래프트 평가 보정 \(delta > 0 ? "+" : "")\(delta)점")
                    }
                    if wind.rewardBonusPermille != 0 {
                        let percent = wind.rewardBonusPermille / 10
                        Text("야구혼 보정 \(percent > 0 ? "+" : "")\(percent)%")
                    }
                    Text(wind.detail)
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

    var body: some View {
        BaseballCard(title: "고교 3년 목표", tone: .milestone) {
            VStack(alignment: .leading, spacing: 10) {
                Text(isFirstLife
                     ? "하나를 고르면 3년을 마칠 때 돌아봅니다. 이루면 새 선수가 더 강하게 시작됩니다."
                     : "하나를 고르면 고교 3년을 마칠 때 돌아봅니다. 등급에 따라 야구혼을 더 얻습니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                ForEach(RunPledge.options(careerID: state.careerID, state: state, intent: intent)) { pledge in
                    let progress = pledge.progress(in: .init(state: state, rivalLedger: rivalLedger))
                    let carried = intent?.pledgeID == pledge.id
                    Button { onChoose(pledge.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                if carried {
                                    Text("지난 고교 3년에서 이어짐")
                                        .font(.caption2.weight(.heavy))
                                        .foregroundStyle(BaseballTheme.milestone)
                                }
                                Text(pledge.tier.title)
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(pledge.tier == .legendary
                                                     ? BaseballTheme.warning : BaseballTheme.textSecondary)
                                Spacer(minLength: 0)
                                Text("야구혼 +\(pledge.rewardPermille / 10)%")
                                    .font(.caption.monospacedDigit().weight(.bold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            Text(pledge.title).font(.subheadline.weight(.bold))
                            Text(pledge.detail).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                            Text(pledge.alignmentReason(state: state))
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BaseballTheme.milestone.opacity(0.1), in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(BaseballTheme.milestone.opacity(0.6), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hs.pledge.\(pledge.id)")
                    .accessibilityLabel(pledge.accessibilityLabel(progress: progress, carried: carried))
                }
                Button("목표 없이 시작") { onChoose(nil) }
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
