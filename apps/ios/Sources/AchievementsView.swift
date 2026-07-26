import SwiftUI

/// 업적 목록. Game Center 인증 여부와 무관하게 항상 보인다.
struct AchievementsView: View {
    let store: AchievementStore

    private var unlocked: [Achievement] { Achievement.allCases.filter { store.progress.has($0) } }
    private var locked: [Achievement] { Achievement.allCases.filter { !store.progress.has($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            HStack {
                Text("업적").font(.headline)
                Spacer()
                Text("\(unlocked.count) / \(Achievement.allCases.count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
            }
            ForEach(unlocked) { achievement in
                AchievementRow(achievement: achievement, unlocked: true)
            }
            ForEach(locked) { achievement in
                AchievementRow(achievement: achievement, unlocked: false)
            }
            if !store.isGameCenterAuthenticated {
                Text("Game Center에 연결되지 않았습니다. 달성 기록은 이 기기에 그대로 남습니다.")
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
        }
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: unlocked ? "trophy.fill" : "lock.fill")
                .foregroundStyle(unlocked ? BaseballTheme.milestone : BaseballTheme.border)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(unlocked ? BaseballTheme.textPrimary : BaseballTheme.textSecondary)
                Text(achievement.detail)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            unlocked ? BaseballTheme.milestone.opacity(0.1) : BaseballTheme.surface,
            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                .stroke(unlocked ? BaseballTheme.milestone : BaseballTheme.border.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title). \(unlocked ? "달성" : "미달성"). \(achievement.detail)")
    }
}

/// 방금 달성한 업적을 알리는 배너.
struct AchievementBanner: View {
    let achievements: [Achievement]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("업적 달성", systemImage: "trophy.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                Spacer()
                Button("확인", action: onDismiss)
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
            ForEach(achievements) { achievement in
                Text("· \(achievement.title)").font(.subheadline)
            }
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BaseballTheme.milestone.opacity(0.14), in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(BaseballTheme.milestone, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}
