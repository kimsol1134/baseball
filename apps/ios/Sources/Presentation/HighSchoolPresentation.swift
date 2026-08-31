import Foundation
import SimulationCore
import BaseballIOSDomain

/// 고교 커리어 화면이 쓰는 표시 문구와 파생값. 데스크톱 `HighSchoolCareerView.tsx`의 라벨 표와
/// 같은 값을 쓰므로 두 플랫폼의 각성·기억 카드 설명이 갈리지 않는다.
enum HighSchoolPresentation {
    struct ChapterReviewGainRow: Identifiable, Equatable {
        /// Raw/stable identity used by SwiftUI diffing. The localized label is display-only.
        let id: String
        let label: String
        let delta: Int
    }
}
