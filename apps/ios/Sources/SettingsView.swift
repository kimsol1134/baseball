import SwiftUI

/// 소리·손맛·접근성 설정. 자동 릴리스는 접근성 항목이라 맨 위에 둔다.
struct SettingsView: View {
    let highSchool: HighSchoolCareerStore
    let pro: MobileCareerStore

    @AppStorage("baseball.pitch.autoRelease") private var autoRelease = false
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

            Section {
                AchievementsView(store: achievements)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            Section("진행") {
                LabeledContent("회차", value: "\(highSchool.inheritance.lifeNumber)회차")
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
                    LabeledContent("이번 회차 시드") {
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
                highSchool.deleteCareer()
                pro.deleteCareer()
                // "모든 진행"에는 UserDefaults의 진행 흔적도 포함된다 — 남기면
                // 새 회차의 첫 신기록·첫 별점 순간이 이미 소모돼 있다.
                UserDefaults.standard.removeObject(forKey: "baseball.bestVelocityTenths")
                UserDefaults.standard.removeObject(forKey: DailyInningView.bestEverKey)
                ReviewPrompt.reset()
            }
            Button("취소") {}
        } message: {
            Text("회차와 계승 기억까지 전부 사라집니다.")
        }
    }
}
