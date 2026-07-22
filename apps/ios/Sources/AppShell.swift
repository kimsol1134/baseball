import SwiftUI
import SimulationCore
import UIKit

enum BaseballTheme {
    static let action = adaptive(light: 0x4F7828, dark: 0xB7F36B)
    static let selection = adaptive(light: 0x447A37, dark: 0x86C96A)
    static let milestone = adaptive(light: 0x7E5D17, dark: 0xD8B565)
    static let positive = adaptive(light: 0x24744E, dark: 0x55C58A)
    static let warning = adaptive(light: 0x8A570F, dark: 0xF0A94A)
    static let negative = adaptive(light: 0xAD3E36, dark: 0xEF746A)
    static let information = adaptive(light: 0x236B78, dark: 0x67B6C1)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            platformColor(traits.userInterfaceStyle == .dark ? dark : light)
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
                Text("\(state.team.name) · \(state.season)시즌 \(state.week)주차").font(.headline)
                HStack { Metric(title: "피로", value: "\(state.fatigue)"); Metric(title: "감독 신뢰", value: "\(state.managerTrust)"); Metric(title: "부상", value: state.injuryWeeks > 0 ? "\(state.injuryWeeks)주" : "정상") }
                GroupBox("다음 행동") { Text(actionText(state.phase)).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) }
                if let milestone = state.milestones.last { GroupBox("최근 이정표") { Label(milestone, systemImage: "star.fill").foregroundStyle(BaseballTheme.milestone).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) } }
                GroupBox("최근 소식") { ForEach(Array(state.news.prefix(3).enumerated()), id: \.offset) { _, item in Text(item).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4) } }
            }.padding()
        }
    }
    private func actionText(_ phase: ProCareerPhase) -> String { switch phase { case .weeklyPlan: "이번 주에 가장 신경 쓸 훈련을 고르세요."; case .importantGame: "한 점 차, 1사 2루에서 등판합니다."; case .seasonReview: "올해 경기 기록과 수상 결과를 확인하세요."; case .offseasonDecision: "현재 구단에 남을지 결정하세요."; default: "커리어 탭에서 다음 일정을 확인하세요." } }
}

private struct Metric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.bold()) }.frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).accessibilityElement(children: .combine) }
}
