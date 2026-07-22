import SwiftUI

struct RecordView: View {
    let career: MobileCareerStore
    var body: some View {
        List {
            if let state = career.state {
                Section("현재 시즌") { LabeledContent("경기", value: "\(state.currentStats.games)"); LabeledContent("탈삼진", value: "\(state.currentStats.strikeouts)"); LabeledContent("승", value: "\(state.currentStats.wins)") }
                Section("통산 시즌") { ForEach(state.careerStats, id: \.season) { season in LabeledContent("시즌 \(season.season)", value: "\(season.games)G · \(season.strikeouts)K") } }
                Section("수상") { if state.awards.isEmpty { Text("아직 수상 기록이 없습니다.").foregroundStyle(.secondary) } else { ForEach(state.awards, id: \.self, content: Text.init) } }
                Section("커리어 이정표") { ForEach(Array(state.milestones.reversed()), id: \.self) { milestone in Label(milestone, systemImage: "star.circle") } }
            }
        }
        .navigationTitle("기록")
    }
}
