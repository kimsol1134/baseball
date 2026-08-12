import SwiftUI

enum SettingsCopy {
    static let hapticsFooterKey = AppCopyKey.settingsHapticsFooter

    /// Compatibility surface for the existing unit test and non-SwiftUI callers. The view uses
    /// `hapticsFooterKey`; this accessor resolves the same semantic key for the legacy Korean API.
    static var hapticsFooter: String {
        GameCopyResolver(language: .korean, policy: .releaseSafe).resolve(hapticsFooterKey)
    }
}

/// 소리·손맛·접근성 설정. 자동 릴리스는 접근성 항목이라 맨 위에 둔다.
struct SettingsView: View {
    let highSchool: HighSchoolCareerStore
    let pro: MobileCareerStore
    /// 모든 진행을 지운 직후. 앱을 다시 깐 것과 같은 자리(첫 화면)로 돌려보내는 일은
    /// 탭을 소유한 껍데기만 할 수 있다 — 여기서 지우고 그대로 두면 사용자는 삭제된
    /// 설정 화면에 남아 "그래서 뭐가 지워졌지"를 확인할 방법이 없다.
    var onResetAll: () -> Void = {}

    @AppStorage("baseball.pitch.autoRelease") private var autoRelease = false
    @AppStorage(DailyReminder.enabledKey) private var reminderOn = false
    @State private var audio = GameAudio.shared
    @State private var achievements = AchievementStore.shared
    @State private var confirmingReset = false
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        List {
            Section {
                Toggle(copyResolver.resolve(AppCopyKey.settingsAutoRelease), isOn: $autoRelease)
                GameCopyText(AppCopyKey.settingsAutoReleaseDescription)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            } header: {
                GameCopyText(AppCopyKey.settingsControlTitle)
            } footer: {
                // "손해가 없습니다"는 실측과 다르다 — 숙련된 제스처는 중립 릴리스보다 확실히
                // 낫다(피출루 −0.048). 접근성 안내가 사실과 다르면 그게 더 나쁘다.
                GameCopyText(AppCopyKey.settingsAutoReleaseFooter)
            }

            Section {
                Toggle(copyResolver.resolve(.settingsAudioSound), isOn: Binding(get: { audio.soundEnabled }, set: { audio.soundEnabled = $0 }))
                Toggle(copyResolver.resolve(AppCopyKey.settingsMusic), isOn: Binding(get: { audio.musicEnabled }, set: { audio.musicEnabled = $0 }))
                Toggle(copyResolver.resolve(AppCopyKey.settingsHaptics), isOn: Binding(get: { audio.hapticsEnabled }, set: { audio.hapticsEnabled = $0 }))
                GameCopyText(SettingsCopy.hapticsFooterKey)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                GameCopyText(AppCopyKey.settingsAudioFooter)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            } header: {
                GameCopyText(AppCopyKey.settingsAudioSectionTitle)
            }

            // 복귀 알림은 언제든 끌 수 있도록 설정에 둔다.
            Section {
                Toggle(copyResolver.resolve(AppCopyKey.settingsNotificationToggle), isOn: Binding(
                    get: { reminderOn },
                    set: { on in
                        if on { DailyReminder.enable(source: "settings") { granted in reminderOn = granted } }
                        else { DailyReminder.disable(source: "settings") }
                    }
                ))
                .accessibilityIdentifier("settings.reminder")
            } header: {
                GameCopyText(AppCopyKey.settingsNotificationsSectionTitle)
            } footer: {
                GameCopyText(AppCopyKey.settingsNotificationFooter)
            }

            Section {
                AchievementsView(store: achievements)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            Section {
                LabeledContent(
                    copyResolver.resolve(AppCopyKey.settingsNextPlayerLabel),
                    value: copyResolver.resolve(
                        AppCopyKey.settingsNextPlayerValue,
                        arguments: [.integer(highSchool.inheritance.lifeNumber)]
                    )
                )
                LabeledContent(
                    copyResolver.resolve(AppCopyKey.settingsMemoriesLabel),
                    value: copyResolver.resolve(
                        AppCopyKey.settingsMemoriesValue,
                        arguments: [.integer(highSchool.inheritance.memories.count)]
                    )
                )
                LabeledContent(
                    copyResolver.resolve(AppCopyKey.settingsSoulLabel),
                    value: copyResolver.resolve(
                        AppCopyKey.settingsSoulValue,
                        arguments: [.integer(highSchool.inheritance.soulPoints)]
                    )
                )
                if let state = pro.state {
                    LabeledContent(
                        copyResolver.resolve(AppCopyKey.settingsProLabel),
                        value: copyResolver.resolve(
                            AppCopyKey.settingsProValue,
                            arguments: [.userText(state.team.name), .integer(state.season)]
                        )
                    )
                }
                // **시드를 보여 준다.**
                //
                // 코어가 완전 결정론이라 같은 시드는 같은 회차를 만든다. 그런데 그 시드를
                // 볼 방법이 없어서 "이 시드 해 봐라"가 성립하지 않았다 — 커뮤니티에서
                // 검증된 바이럴 경로 하나가 통째로 막혀 있었던 셈이다. UI 한 줄이면 된다.
                if let seed = highSchool.state?.careerID {
                    LabeledContent {
                        HStack(spacing: 8) {
                            Text(verbatim: seed)
                                .font(.caption.monospaced())
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            ShareLink(item: seed) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel(copyResolver.resolve(AppCopyKey.settingsShareCodeAccessibility))
                            .accessibilityIdentifier("settings.shareSeed")
                        }
                    } label: {
                        GameCopyText(AppCopyKey.settingsShareCodeLabel)
                    }
                }
            } header: {
                GameCopyText(AppCopyKey.settingsProgressSectionTitle)
            }

            Section {
                Button(copyResolver.resolve(AppCopyKey.settingsDeleteAction), role: .destructive) { confirmingReset = true }
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            } footer: {
                GameCopyText(AppCopyKey.settingsDeleteFooter)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BaseballTheme.canvas)
        .navigationTitle(copyResolver.resolve(AppCopyKey.settingsNavigationTitle))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            copyResolver.resolve(AppCopyKey.settingsDeleteConfirmationTitle),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(copyResolver.resolve(AppCopyKey.settingsDeleteConfirmationAction), role: .destructive) {
                // 삭제가 실제로 성공했을 때만 첫 화면으로 되돌린다. 저장 쓰기가 실패하면
                // 진행은 그대로 남아 있는데 화면만 오프닝으로 가서, 되돌릴 수 없는 것을
                // 되돌린 것처럼 보이게 된다.
                let clearedHighSchool = highSchool.deleteCareer()
                let clearedPro = pro.deleteCareer()
                // "모든 진행"에는 UserDefaults의 진행 흔적도 포함된다 — 남기면
                // 새 회차의 첫 신기록·첫 별점 순간이 이미 소모돼 있다.
                UserDefaults.standard.removeObject(forKey: "baseball.bestVelocityTenths")
                LegacyDailyInningData.clear()
                ReviewPrompt.reset()
                // 연속 기록도 진행이다. 남기면 새 시작이 "12일 연속"에서 출발한다.
                for key in UserDefaults.standard.dictionaryRepresentation().keys
                where DailyStreak.allPlayKeyPrefixes.contains(where: key.hasPrefix) {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                // 알림 권유는 다시 물어볼 수 있어야 한다 — 지운 사람은 다시 시작할 사람이다.
                UserDefaults.standard.removeObject(forKey: DailyReminder.promptedKey)
                // 지운 다음의 첫 화면은 오프닝이어야 한다. 껍데기가 탭을 고교로 되돌리고
                // 오프닝 표시 상태까지 초기화한다.
                if clearedHighSchool && clearedPro { onResetAll() }
            }
            Button(copyResolver.resolve(AppCopyKey.settingsDeleteConfirmationCancel)) {}
        } message: {
            GameCopyText(AppCopyKey.settingsDeleteConfirmationMessage)
        }
    }
}
