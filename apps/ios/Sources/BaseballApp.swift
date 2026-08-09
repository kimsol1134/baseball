import SwiftUI
import UIKit

@main
struct BaseballApp: App {
    init() {
        // 분석은 설정이 있을 때만 켜진다 — 없으면 이 호출은 무동작이다.
        GameAnalytics.configure()
    }

    /// UI 스모크 테스트가 저장된 커리어를 지우고 첫 실행 상태에서 시작하도록 하는 인자.
    static let resetLaunchArgument = "-uiTestResetCareer"
    /// UI 테스트가 타이밍 제스처 없이 흐름을 통과하도록 자동 릴리스를 켠다.
    static let autoReleaseLaunchArgument = "-uiTestAutoRelease"
    /// 홍보 영상 촬영용. XCUITest는 자동화를 빠르게 하려고 대상 앱의 애니메이션을 꺼 버리는데,
    /// 그러면 승부 장면이 최종 프레임으로 튀어 녹화에 아무것도 남지 않는다. 촬영할 때만 되돌린다.
    static let promoLaunchArgument = "-uiTestPromoCapture"

    @Environment(\.scenePhase) private var scenePhase
    @State private var highSchool = HighSchoolCareerStore()
    @State private var pro = MobileCareerStore()
    @State private var remoteChangeObserver: NSObjectProtocol?
    /// 이번 세션이 언제 시작됐는가. 세션 깊이(분·진행)를 재는 데만 쓴다.
    @State private var sessionStartedAt = Date()

    /// 세션이 끝날 때 깊이를 남긴다.
    ///
    /// 왜 필요한가: 2026-08 데이터에서 1인당 34.6이벤트·10.6경기였는데, 그게 **한 세션**의
    /// 값인지 여러 번 나눠 온 값인지 구분할 수 없었다. "첫 세션에 1회차를 통째로 끝내고
    /// 떠난다"는 진단은 개별 유저 프로필을 눈으로 읽어서 세운 가설이었다. 이 이벤트가
    /// 그 가설을 집계로 바꾼다.
    private func logSessionEnd() {
        let minutes = Int(Date().timeIntervalSince(sessionStartedAt) / 60)
        GameAnalytics.log(.sessionEnded, [
            "minutes": minutes,
            "life_number": highSchool.state?.lifeNumber ?? highSchool.inheritance.lifeNumber,
            "games": highSchool.state?.performance.importantGamesCompleted ?? 0,
            "phase": highSchool.state?.phase.rawValue ?? "none",
            "act_number": highSchool.state.map {
                HighSchoolPresentation.actNumber(chapter: $0.chapter.number)
            } ?? 0,
            "lives_finished": highSchool.archive.count,
        ])
    }

    var body: some Scene {
        WindowGroup {
            AppShell(highSchool: highSchool, pro: pro)
                // 디자인 시스템은 다크 전용이다(design-system.css의 `color-scheme: dark`).
                // 기기 설정을 따라가면 라이트 모드에서 "Midnight Dugout" 방향이 통째로 사라진다.
                .preferredColorScheme(.dark)
                .task {
                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains(Self.promoLaunchArgument) {
                        UIView.setAnimationsEnabled(true)
                    }
                    if arguments.contains(Self.resetLaunchArgument) {
                        highSchool.deleteCareer()
                        pro.deleteCareer()
                        // 설정도 함께 되돌린다. 앞선 실행이 남긴 자동 릴리스가 다음 테스트로
                        // 새면 조작 경로가 통째로 달라진다.
                        UserDefaults.standard.set(
                            arguments.contains(Self.autoReleaseLaunchArgument),
                            forKey: "baseball.pitch.autoRelease"
                        )
                    } else if arguments.contains(Self.autoReleaseLaunchArgument) {
                        UserDefaults.standard.set(true, forKey: "baseball.pitch.autoRelease")
                    }
                    highSchool.restoreOrCreate()
                    pro.restoreOrCreateCareer()
                    GameAudio.shared.start()
                    AchievementStore.shared.authenticate()
                    SaveSync.prime()
                    // 알림 응답을 받으려면 첫 화면이 뜨기 전에 델리게이트가 붙어 있어야
                    // 한다 — 늦게 붙으면 앱을 깨운 그 알림의 응답이 사라진다.
                    NotificationRouter.shared.register()
                    DailyReminder.refresh()
                }
                .task {
                    // 다른 기기에서 올라온 진행을 받아 화면을 갱신한다.
                    remoteChangeObserver = SaveSync.observeRemoteChanges {
                        highSchool.reloadFromSync()
                        pro.reloadFromSync()
                    }
                }
                .onChange(of: scenePhase) { previous, phase in
                    if phase == .active {
                        GameAudio.shared.start()
                        SaveSync.prime()
                        // 오늘 던졌으면 오늘 저녁 알림을 지우고, 지난 날짜분을 새로 채운다.
                        DailyReminder.refresh()
                        // 백그라운드에서 **돌아온** 때만 세션 시계를 다시 건다. 배너 하나에
                        // 시계가 초기화되면 긴 세션이 짧게 잡힌다.
                        if previous == .background { sessionStartedAt = Date() }
                    } else {
                        highSchool.save()
                        pro.save()
                        GameAudio.shared.stop()
                        // **`.background`에서만** 센다. `.inactive`는 알림 배너·앱 전환기·
                        // 시스템 시트에서도 스쳐 지나가므로, 거기서 세면 한 세션이 여러
                        // 개의 짧은 세션으로 쪼개져 세션 깊이가 통째로 거짓이 된다.
                        if phase == .background { logSessionEnd() }
                    }
                }
        }
    }
}
