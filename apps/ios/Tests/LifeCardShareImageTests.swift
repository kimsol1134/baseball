import XCTest
import SimulationCore
import SwiftUI
@testable import BaseballIOS

/// 공유되는 **그 이미지**를 실제 경로(`LifeCardRenderer`)로 뽑아 파일로 남긴다.
///
/// "카드가 깨져 보인다"는 제보는 화면 미리보기가 아니라 공유물에서 나온다. 미리보기는
/// SwiftUI가 그리고, 공유물은 `ImageRenderer`가 굽는다 — 둘은 같은 뷰라도 결과가 다를
/// 수 있어서(글꼴 축소·이미지 로드·잘림) 굽힌 결과를 직접 봐야 한다.
final class LifeCardShareImageTests: XCTestCase {
    @MainActor
    func testExportSharedCardImage() throws {
        var record = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 1, playerName: "민서준", schoolName: "서울덕성고", drafted: false,
            evaluationScore: 61, teamName: nil, memories: [], games: 4,
            strikeouts: 5, walks: 1, runsAllowed: 0, soulPoints: 30,
            nicknames: ["제로", "핀포인트"],
            chronicle: [
                "1학년 봄 — 서울덕성고 입학. 3년이 시작됩니다.",
                "2학년 가을 — 성격이 자리 잡았습니다 — '조용한 버팀목'. 끝까지 무너지지 않는 사람이었습니다.",
                "3학년 여름 — '바늘끝 제구'을 익혔습니다. 원하는 코스에 더 꾸준히 던지지만 최고 구속이 조금 줄어듭니다.",
                "3학년 여름 — 무실점 호투 — 20구 · 2탈삼진 · 0볼넷 · 0실점 · 경기 기반 성장 · 구위 +1. 2탈삼진 · 0실점 호투가 가장 강한 구위를 남겼습니다.",
                "3학년 여름 — 드래프트 미지명. 하지만 이 3년은 새 선수의 밑천이 됩니다."
            ],
            coachName: "윤태문", catcherName: "서준호", rivalName: "서하준",
            personality: "조용한 버팀목",
            careerID: "career-17796881230217421145-life-1"
        )
        record.windTitle = "무명의 해"
        record.signatureLegacy = .definition(for: .commandMap)

        let image = try XCTUnwrap(LifeCardRenderer.image(for: record), "공유 카드가 렌더되지 않습니다.")
        let data = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: "/tmp/claude-501").appendingPathComponent("shared-life-card.png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try data.write(to: url)
        print("SHARE_CARD \(url.path) size=\(image.size) scale=\(image.scale) px=\(image.size.width * image.scale)x\(image.size.height * image.scale)")
    }
}
