import SwiftUI

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

    var body: some View {
        List {
            Section {
                Toggle("자동 릴리스", isOn: $autoRelease)
                Text("켜면 와인드업 타이밍 없이 탭 한 번으로 던집니다. 결과는 릴리스가 딱 중간일 때와 같습니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            } header: {
                Text("조작")
            } footer: {
                // "손해가 없습니다"는 실측과 다르다 — 숙련된 제스처는 중립 릴리스보다 확실히
                // 낫다(피출루 −0.048). 접근성 안내가 사실과 다르면 그게 더 나쁘다.
                Text("타이밍 제스처가 어려우면 켜세요. 항상 안정된 중간 릴리스로 던지므로 진행이 막히는 일은 없습니다. 다만 완벽한 타이밍의 이점도 사라집니다.")
            }

            Section("소리와 진동") {
                Toggle("소리", isOn: Binding(get: { audio.soundEnabled }, set: { audio.soundEnabled = $0 }))
                Toggle("음악", isOn: Binding(get: { audio.musicEnabled }, set: { audio.musicEnabled = $0 }))
                Toggle("진동", isOn: Binding(get: { audio.hapticsEnabled }, set: { audio.hapticsEnabled = $0 }))
                Text("소리는 다른 앱의 음악을 멈추지 않고, 무음 스위치를 따릅니다.")
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }

            // 복귀 알림은 설정에 있어야 한다.
            //
            // 예전에는 이 스위치가 오늘의 이닝 화면 안에만 있었다 — DAU의 7%만 여는
            // 화면이다. 켠 사람을 찾을 수 없으니 끄려는 사람도 찾을 수 없었다.
            Section {
                Toggle("이어하기 알림", isOn: Binding(
                    get: { reminderOn },
                    set: { on in
                        if on { DailyReminder.enable(source: "settings") { granted in reminderOn = granted } }
                        else { DailyReminder.disable(source: "settings") }
                    }
                ))
                .accessibilityIdentifier("settings.reminder")
            } header: {
                Text("알림")
            } footer: {
                Text("매일 저녁 7시 30분, 현재 선수의 다음 목표나 그날의 이닝 중 이어 할 한 가지를 알려 드립니다. 며칠 동안 열지 않으면 저절로 멈춥니다.")
            }

            Section {
                AchievementsView(store: achievements)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            Section("진행") {
                LabeledContent("다음 선수", value: "\(highSchool.inheritance.lifeNumber)번째")
                LabeledContent("가져온 기억", value: "\(highSchool.inheritance.memories.count)장")
                LabeledContent("영혼", value: "\(highSchool.inheritance.soulPoints)")
                if let state = pro.state {
                    LabeledContent("프로", value: "\(state.team.name) \(state.season)시즌")
                }
                // **시드를 보여 준다.**
                //
                // 코어가 완전 결정론이라 같은 시드는 같은 회차를 만든다. 그런데 그 시드를
                // 볼 방법이 없어서 "이 시드 해 봐라"가 성립하지 않았다 — 커뮤니티에서
                // 검증된 바이럴 경로 하나가 통째로 막혀 있었던 셈이다. UI 한 줄이면 된다.
                if let seed = highSchool.state?.careerID {
                    LabeledContent("이번 선수 공유 코드") {
                        HStack(spacing: 8) {
                            Text(seed)
                                .font(.caption.monospaced())
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            ShareLink(item: seed) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("시드 공유")
                            .accessibilityIdentifier("settings.shareSeed")
                        }
                    }
                }
            }

            Section {
                Button("모든 진행 삭제", role: .destructive) { confirmingReset = true }
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            } footer: {
                Text("고교·프로 커리어와 계승 기록이 모두 지워집니다. 되돌릴 수 없습니다.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(BaseballTheme.canvas)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("모든 진행을 삭제할까요?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                // 삭제가 실제로 성공했을 때만 첫 화면으로 되돌린다. 저장 쓰기가 실패하면
                // 진행은 그대로 남아 있는데 화면만 오프닝으로 가서, 되돌릴 수 없는 것을
                // 되돌린 것처럼 보이게 된다.
                let clearedHighSchool = highSchool.deleteCareer()
                let clearedPro = pro.deleteCareer()
                // "모든 진행"에는 UserDefaults의 진행 흔적도 포함된다 — 남기면
                // 새 회차의 첫 신기록·첫 별점 순간이 이미 소모돼 있다.
                UserDefaults.standard.removeObject(forKey: "baseball.bestVelocityTenths")
                UserDefaults.standard.removeObject(forKey: DailyInningView.bestEverKey)
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
            Button("취소") {}
        } message: {
            Text("선수 기록과 계승 유산까지 전부 사라집니다.")
        }
    }
}
