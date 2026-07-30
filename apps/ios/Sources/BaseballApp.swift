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
                }
                .task {
                    // 다른 기기에서 올라온 진행을 받아 화면을 갱신한다.
                    remoteChangeObserver = SaveSync.observeRemoteChanges {
                        highSchool.reloadFromSync()
                        pro.reloadFromSync()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        GameAudio.shared.start()
                        SaveSync.prime()
                    } else {
                        highSchool.save()
                        pro.save()
                        GameAudio.shared.stop()
                    }
                }
        }
    }
}
