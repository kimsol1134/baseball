import SwiftUI

@main
struct BaseballApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var career = MobileCareerStore()

    var body: some Scene {
        WindowGroup {
            AppShell(career: career)
                .task { career.restoreOrCreateCareer() }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { career.save() }
                }
        }
    }
}
