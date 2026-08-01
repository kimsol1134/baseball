import SwiftUI
import SimulationCore
import UserNotifications

/// 오늘의 이닝 — 하루 한 판, 전국이 같은 타순을 상대한다.
///
/// 이 게임의 결정론 인프라(시드 → 모든 것)가 처음으로 "내일 다시 켤 이유"가 된다:
/// 날짜가 시드라 모든 플레이어의 판이 같고, 점수는 리더보드에서 겨룬다.
/// 커리어와 완전히 분리돼 밸런스에 손대지 않는다.
struct DailyInningView: View {
    let onClose: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64
    @State private var session: PitchSession?
    @State private var finished = false
    @State private var showingBoard = false
    /// 저녁 알림 옵트인. 켜는 순간 권한을 묻는다 — 첫 실행에서 묻는 것보다 늦고 정직하다.
    @AppStorage("baseball.daily.reminder") private var reminderOn = false

    private let dateKey = PitchScenario.todayKey()

    /// 오늘 점수 — 삼진이 크고, 실점이 아프다. 계산식은 화면에 그대로 적는다.
    static func score(strikeouts: Int, outs: Int, walks: Int, runsAllowed: Int) -> Int {
        max(0, strikeouts * 300 + outs * 100 - walks * 50 - runsAllowed * 250
            + (runsAllowed == 0 && outs >= 3 ? 300 : 0))
    }

    private var bestKey: String { "baseball.daily.best.\(dateKey)" }
    private var playedKey: String { "baseball.daily.played.\(dateKey)" }
    private var attemptsKey: String { "baseball.daily.attempts.\(dateKey)" }
    static let dailyAttemptCap = 3

    var body: some View {
        Group {
            if let session {
                PitchView(session: session, onFinish: { finish(session) },
                          onAbort: { self.session = nil })
            } else {
                intro
            }
        }
        .fullScreenCover(isPresented: $finished) {
            settlement
        }
        .sheet(isPresented: $showingBoard) {
            GameCenterBoardView(leaderboardID: Leaderboard.dailyInning.rawValue) {
                showingBoard = false
            }
            .ignoresSafeArea()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(art: .stadiumNight, eyebrow: "오늘의 이닝 · \(dateKey)",
                         title: "전국이 같은 타순을 상대합니다", accent: BaseballTheme.milestone)
            Text("9회초, 한 점 리드, 고정 스펙의 투수. 오늘 자정까지 판이 같습니다. 점수는 Game Center 순위로 겨룹니다.")
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            BaseballCard(title: "점수 계산") {
                Text("삼진 +300 · 아웃 +100 · 볼넷 −50 · 실점 −250 · 무실점 마감 +300")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            if UserDefaults.standard.integer(forKey: bestKey) > 0 {
                BaseballCard(title: "오늘 내 최고", tone: .milestone) {
                    Text("\(UserDefaults.standard.integer(forKey: bestKey))점")
                        .font(BaseballType.heroNumeral)
                        .foregroundStyle(BaseballTheme.milestone)
                }
            }
            if AchievementStore.shared.isGameCenterAuthenticated {
                Button {
                    showingBoard = true
                } label: {
                    Label("오늘 전국 순위 보기", systemImage: "trophy")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.milestone)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                }
                .accessibilityIdentifier("daily.board")
            }
            Toggle(isOn: $reminderOn) {
                Text("저녁마다 새 판 알림 (19:30)")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            .tint(BaseballTheme.action)
            .onChange(of: reminderOn) { _, on in
                if on { DailyReminder.enable { granted in if !granted { reminderOn = false } } }
                else { DailyReminder.disable() }
            }
            Spacer(minLength: 0)
            // 하루 3회 — 같은 판의 결정론 리더보드는 캡이 없으면 실력이 아니라
            // 반복량을 잰다(4차 패널 P1). 중단도 시작 시점에 세므로 소모된다.
            if UserDefaults.standard.integer(forKey: attemptsKey) >= Self.dailyAttemptCap {
                BaseballCard(title: "오늘의 도전을 다 썼습니다", tone: .raised) {
                    Text("하루 \(Self.dailyAttemptCap)번 — 내일 자정에 새 판이 열립니다. 순위는 위에서 확인하세요.")
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            } else {
                PrimaryButton(title: "마운드에 오르기 (남은 도전 \(Self.dailyAttemptCap - UserDefaults.standard.integer(forKey: attemptsKey))회)",
                              identifier: "daily.start") {
                    UserDefaults.standard.set(
                        UserDefaults.standard.integer(forKey: attemptsKey) + 1, forKey: attemptsKey)
                    let created = PitchSession(
                        scenario: .daily(dateKey: dateKey),
                        seed: PitchScenario.dailySessionSeed(dateKey: dateKey)
                    )
                    created.start()
                    session = created
                }
            }
            Button("닫기") { onClose() }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BaseballTheme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
        }
        .padding(BaseballMetrics.gutter)
        .background(BaseballTheme.canvas)
    }

    private var settlement: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Spacer(minLength: 0)
            Text("오늘의 이닝 결과").eyebrowStyle(BaseballTheme.milestone)
            if let session {
                Text("\(Self.score(strikeouts: session.strikeouts, outs: session.outsRecorded, walks: session.walks, runsAllowed: session.runsAllowed))점")
                    .font(.system(size: heroSize, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
                Text("\(session.strikeouts)탈삼진 · \(session.outsRecorded)아웃 · \(session.walks)볼넷 · \(session.runsAllowed)실점")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                // 같은 판 반복 도전은 설계다 — 그렇다면 몇 번째인지, 무엇이 제출되는지 적는다.
                Text("오늘 \(UserDefaults.standard.integer(forKey: attemptsKey))번째 도전 · 최고 기록만 제출됩니다")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
                Text("내일 자정에 새 판이 열립니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textTertiary)
                if AchievementStore.shared.isGameCenterAuthenticated {
                    Button {
                        showingBoard = true
                    } label: {
                        Label("오늘 전국 순위 보기", systemImage: "trophy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                    }
                    .accessibilityIdentifier("daily.board.settlement")
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "닫기", identifier: "daily.close") {
                finished = false
                onClose()
            }
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(BaseballTheme.fieldNight.ignoresSafeArea())
    }

    private func finish(_ session: PitchSession) {
        let score = Self.score(
            strikeouts: session.strikeouts, outs: session.outsRecorded,
            walks: session.walks, runsAllowed: session.runsAllowed
        )
        let best = max(score, UserDefaults.standard.integer(forKey: bestKey))
        UserDefaults.standard.set(best, forKey: bestKey)
        UserDefaults.standard.set(true, forKey: playedKey)
        // 베스트만 제출 — 리더보드 정책이 무엇이든 낮은 재도전이 상위 기록을 덮지 않게.
        AchievementStore.shared.submit([.dailyInning: best])
        GameAnalytics.log(.gameFinished, ["mode": "daily", "score": score])
        finished = true
    }
}


/// 오늘의 이닝 저녁 알림 — 옵트인·하루 한 번·끄면 즉시 사라진다.
enum DailyReminder {
    static let requestID = "baseball.daily.reminder"

    static func enable(completion: @escaping @MainActor (Bool) -> Void) {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { completion(false); return }
            let content = UNMutableNotificationContent()
            content.title = "오늘의 이닝이 열려 있습니다"
            content.body = "전국이 같은 타순을 상대합니다 — 자정 전에 한 이닝."
            content.sound = .default
            var components = DateComponents()
            components.hour = 19
            components.minute = 30
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: requestID, content: content, trigger: trigger))
            completion(true)
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestID])
    }
}
