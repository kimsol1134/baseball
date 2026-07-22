import SwiftUI
import SimulationCore
import UIKit

enum BaseballTheme {
    static let canvas = adaptive(light: 0xF3F6F2, dark: 0x080D0B, highContrastLight: 0xFFFFFF, highContrastDark: 0x020503)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x101815, highContrastLight: 0xFFFFFF, highContrastDark: 0x070B09)
    static let surfaceRaised = adaptive(light: 0xE8EEE9, dark: 0x17231E, highContrastLight: 0xF1F5F2, highContrastDark: 0x0B120E)
    static let border = adaptive(light: 0x82958B, dark: 0x3F554B, highContrastLight: 0x405048, highContrastDark: 0xC1CEC7)
    static let textPrimary = adaptive(light: 0x152019, dark: 0xF1F4EE, highContrastLight: 0x000000, highContrastDark: 0xFFFFFF)
    static let textSecondary = adaptive(light: 0x52655B, dark: 0xB4C1BB, highContrastLight: 0x26322C, highContrastDark: 0xE2E8E4)
    static let action = adaptive(light: 0x4F7828, dark: 0xB7F36B, highContrastLight: 0x315A12, highContrastDark: 0xD3FF82)
    static let selection = adaptive(light: 0x447A37, dark: 0x86C96A, highContrastLight: 0x285B1C, highContrastDark: 0xB9ED8D)
    static let milestone = adaptive(light: 0x7E5D17, dark: 0xD8B565, highContrastLight: 0x5F4100, highContrastDark: 0xFFE08A)
    static let positive = adaptive(light: 0x24744E, dark: 0x55C58A, highContrastLight: 0x075A35, highContrastDark: 0x78E6AB)
    static let warning = adaptive(light: 0x8A570F, dark: 0xF0A94A, highContrastLight: 0x663800, highContrastDark: 0xFFC66D)
    static let negative = adaptive(light: 0xAD3E36, dark: 0xEF746A, highContrastLight: 0x821D18, highContrastDark: 0xFF9A91)
    static let information = adaptive(light: 0x236B78, dark: 0x67B6C1, highContrastLight: 0x064C58, highContrastDark: 0x8ED9E2)
    static let teamBlue = adaptive(light: 0x3566A8, dark: 0x5D8FD7, highContrastLight: 0x174C94, highContrastDark: 0x8FBAFF)
    static let teamNavy = adaptive(light: 0x455E78, dark: 0x7189A2, highContrastLight: 0x29445F, highContrastDark: 0xA8BDD2)
    static let teamGold = adaptive(light: 0x805D0E, dark: 0xD3A64C, highContrastLight: 0x604100, highContrastDark: 0xFFD36D)
    static let teamRed = adaptive(light: 0xA03C39, dark: 0xD76C68, highContrastLight: 0x7A1D1A, highContrastDark: 0xFF9691)
    static let teamTeal = adaptive(light: 0x256E65, dark: 0x52AA9E, highContrastLight: 0x07554D, highContrastDark: 0x7EE0D0)
    static let teamOrange = adaptive(light: 0x8A4C16, dark: 0xD8894E, highContrastLight: 0x643100, highContrastDark: 0xFFB477)
    static let teamViolet = adaptive(light: 0x60499A, dark: 0x9A82D2, highContrastLight: 0x422A7B, highContrastDark: 0xC4A9FF)
    static let teamSilver = adaptive(light: 0x52625B, dark: 0xAAB5B0, highContrastLight: 0x34453D, highContrastDark: 0xD7E0DC)

    static func teamDecoration(_ id: String) -> Color {
        switch id {
        case "busan_marines": teamGold
        case "daegu_forge", "jeonju_hanok": teamTeal
        case "daejeon_rockets": teamOrange
        case "gwangju_phoenix": teamRed
        case "suwon_guardians": teamNavy
        case "changwon_meteors": teamViolet
        case "jeju_storm": teamSilver
        default: teamBlue
        }
    }

    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        highContrastLight: UInt32? = nil,
        highContrastDark: UInt32? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let darkMode = traits.userInterfaceStyle == .dark
            let highContrast = traits.accessibilityContrast == .high
            let value = darkMode
                ? (highContrast ? highContrastDark ?? dark : dark)
                : (highContrast ? highContrastLight ?? light : light)
            return platformColor(value)
        })
    }

    private static func platformColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum BaseballCardTone {
    case standard, raised, milestone, positive

    var accent: Color {
        switch self {
        case .standard: BaseballTheme.textSecondary
        case .raised: BaseballTheme.information
        case .milestone: BaseballTheme.milestone
        case .positive: BaseballTheme.positive
        }
    }

    var background: Color {
        switch self {
        case .standard: BaseballTheme.surface
        case .raised: BaseballTheme.surfaceRaised
        case .milestone: BaseballTheme.milestone.opacity(0.1)
        case .positive: BaseballTheme.positive.opacity(0.1)
        }
    }
}

struct BaseballCard<Content: View>: View {
    let title: String
    var tone: BaseballCardTone = .standard
    let content: Content

    init(title: String, tone: BaseballCardTone = .standard, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(tone.accent)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Rectangle().fill(tone.accent).frame(width: 3).clipShape(.rect(cornerRadius: 3))
        }
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(BaseballTheme.border.opacity(0.75), lineWidth: 1) }
    }
}

struct ScoreboardValue: View {
    let value: String
    var body: some View {
        Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(BaseballTheme.textPrimary)
    }
}

enum AppTab: Hashable, CaseIterable, Identifiable {
    case today, career, records
    var id: Self { self }
    var title: String { switch self { case .today: "오늘"; case .career: "커리어"; case .records: "기록" } }
    var icon: String { switch self { case .today: "sun.max"; case .career: "figure.baseball"; case .records: "chart.bar" } }
}

struct AppShell: View {
    let career: MobileCareerStore
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayView(career: career) }.tabItem { Label(AppTab.today.title, systemImage: AppTab.today.icon) }.tag(AppTab.today)
            NavigationStack { CareerFlowView(career: career) }.tabItem { Label(AppTab.career.title, systemImage: AppTab.career.icon) }.tag(AppTab.career)
            NavigationStack { RecordView(career: career) }.tabItem { Label(AppTab.records.title, systemImage: AppTab.records.icon) }.tag(AppTab.records)
        }
        .tint(BaseballTheme.action)
        .foregroundStyle(BaseballTheme.textPrimary)
        .background(BaseballTheme.canvas.ignoresSafeArea())
    }
}

struct TodayView: View {
    let career: MobileCareerStore
    var body: some View {
        Group {
            switch career.loadState {
            case .loading: ProgressView("커리어 불러오는 중")
            case .failed(let message): ContentUnavailableView("커리어를 열 수 없습니다", systemImage: "exclamationmark.triangle", description: Text(message))
            case .ready:
                if let state = career.state { TodayDashboard(state: state) } else { ContentUnavailableView("커리어 없음", systemImage: "baseball") }
            }
        }
        .navigationTitle("오늘의 상태")
    }
}

private struct TodayDashboard: View {
    let state: ProCareerSnapshot
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(BaseballTheme.teamDecoration(state.team.id))
                        .frame(width: 4, height: 24)
                        .accessibilityHidden(true)
                    Text("\(state.team.name) · \(state.season)시즌 \(state.week)주차").font(.headline)
                }
                HStack { Metric(title: "피로", value: "\(state.fatigue)"); Metric(title: "감독 신뢰", value: "\(state.managerTrust)"); Metric(title: "부상", value: state.injuryWeeks > 0 ? "\(state.injuryWeeks)주" : "정상") }
                BaseballCard(title: "다음 행동", tone: .raised) { Text(actionText(state.phase)).font(.body.weight(.semibold)) }
                if let milestone = state.milestones.last { BaseballCard(title: "최근 이정표", tone: .milestone) { Label(milestone, systemImage: "star.fill").foregroundStyle(BaseballTheme.milestone) } }
                BaseballCard(title: "최근 소식") { ForEach(Array(state.news.prefix(3).enumerated()), id: \.offset) { _, item in Text(item).padding(.vertical, 3) } }
            }.padding()
        }
    }
    private func actionText(_ phase: ProCareerPhase) -> String { switch phase { case .weeklyPlan: "이번 주에 가장 신경 쓸 훈련을 고르세요."; case .importantGame: "한 점 차, 1사 2루에서 등판합니다."; case .seasonReview: "올해 경기 기록과 수상 결과를 확인하세요."; case .offseasonDecision: "현재 구단에 남을지 결정하세요."; default: "커리어 탭에서 다음 일정을 확인하세요." } }
}

private struct Metric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading) { Text(title).font(.caption.weight(.semibold)).foregroundStyle(BaseballTheme.textSecondary); ScoreboardValue(value: value) }.frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).accessibilityElement(children: .combine) }
}
