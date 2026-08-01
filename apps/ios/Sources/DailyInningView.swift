import SwiftUI
import SimulationCore

/// 오늘의 이닝 — 하루 한 판, 전국이 같은 타순을 상대한다.
///
/// 이 게임의 결정론 인프라(시드 → 모든 것)가 처음으로 "내일 다시 켤 이유"가 된다:
/// 날짜가 시드라 모든 플레이어의 판이 같고, 점수는 리더보드에서 겨룬다.
/// 커리어와 완전히 분리돼 밸런스에 손대지 않는다.
struct DailyInningView: View {
    let onClose: () -> Void

    @State private var session: PitchSession?
    @State private var finished = false

    private let dateKey = PitchScenario.todayKey()

    /// 오늘 점수 — 삼진이 크고, 실점이 아프다. 계산식은 화면에 그대로 적는다.
    static func score(strikeouts: Int, outs: Int, walks: Int, runsAllowed: Int) -> Int {
        max(0, strikeouts * 300 + outs * 100 - walks * 50 - runsAllowed * 250
            + (runsAllowed == 0 && outs >= 3 ? 300 : 0))
    }

    private var bestKey: String { "baseball.daily.best.\(dateKey)" }
    private var playedKey: String { "baseball.daily.played.\(dateKey)" }

    var body: some View {
        Group {
            if let session {
                PitchView(session: session, onFinish: { finish(session) })
            } else {
                intro
            }
        }
        .fullScreenCover(isPresented: $finished) {
            settlement
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
            Spacer(minLength: 0)
            PrimaryButton(title: "마운드에 오르기", identifier: "daily.start") {
                let created = PitchSession(
                    scenario: .daily(dateKey: dateKey),
                    seed: PitchScenario.dailySessionSeed(dateKey: dateKey)
                )
                created.start()
                session = created
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
                    .font(.system(size: 64, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
                Text("\(session.strikeouts)탈삼진 · \(session.outsRecorded)아웃 · \(session.walks)볼넷 · \(session.runsAllowed)실점")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textSecondary)
                Text("순위는 Game Center에서 — 내일 자정에 새 판이 열립니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textTertiary)
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
