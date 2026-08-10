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
        record.pitches = 132
        record.outs = 19
        record.hits = 4
        record.abilityStart = .init(PitcherSnapshot(
            id: "start", name: "민서준", stuff: 38, command: 34, movement: 40, stamina: 38,
            pitchProfiles: nil, throwingHand: .right
        ))
        record.abilityFinal = .init(PitcherSnapshot(
            id: "final", name: "민서준", stuff: 52, command: 61, movement: 47, stamina: 45,
            pitchProfiles: nil, throwingHand: .right
        ))

        // 회차 종료 화면이 카드를 담는 **그 컨테이너 그대로** 굽는다. 예전 미리보기는
        // `scaleEffect` 뒤에 `frame(height:)`를 걸어, 600pt 뷰가 432pt 상자에서 세로
        // 가운데로 정렬되는 바람에 카드가 84pt 위로 밀려 잘렸다("삐뚤어져 보인다").
        // 이 스냅숏이 그 자리를 지킨다.
        let screen = BaseballCard(title: "선수 기록 카드", tone: .milestone) {
            LifeCardPreview(record: record)
        }
        .padding(BaseballMetrics.gutter)
        .background(BaseballTheme.canvas)
        .frame(width: 440)
        let screenRenderer = ImageRenderer(content: screen)
        screenRenderer.scale = 3
        screenRenderer.isOpaque = true
        let screenImage = try XCTUnwrap(screenRenderer.uiImage, "회차 종료 화면 카드가 렌더되지 않습니다.")
        // 카드는 내용에 맞춰 자라야 한다. 높이를 못 박으면 성장 막대·투구 지표가 들어온
        // 순간 푸터가 밖으로 밀려 잘린다(실제로 그렇게 잘렸다). 내용이 적은 기록보다
        // 반드시 커야 한다는 것으로 그 성질을 지킨다.
        var sparse = record
        sparse.abilityStart = nil
        sparse.abilityFinal = nil
        sparse.outs = nil
        sparse.chronicle = ["1학년 봄 — 입학."]
        let sparseImage = try XCTUnwrap(LifeCardRenderer.image(for: sparse))
        let richImage = try XCTUnwrap(LifeCardRenderer.image(for: record))
        XCTAssertGreaterThan(
            richImage.size.height, sparseImage.size.height,
            "내용이 늘었는데 카드가 자라지 않았습니다 — 아래쪽이 잘립니다."
        )
        XCTAssertGreaterThanOrEqual(sparseImage.size.height, LifeCardView.size.height,
                                    "내용이 적어도 최소 높이는 지켜야 합니다.")
        if let data = screenImage.pngData() {
            let url = URL(fileURLWithPath: "/tmp/claude-501/run-end-card-screen.png")
            try? data.write(to: url)
            print("SCREEN_CARD \(url.path) size=\(screenImage.size)")
        }

        let image = try XCTUnwrap(LifeCardRenderer.image(for: record), "공유 카드가 렌더되지 않습니다.")
        let data = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: "/tmp/claude-501").appendingPathComponent("shared-life-card.png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try data.write(to: url)
        print("SHARE_CARD \(url.path) size=\(image.size) scale=\(image.scale) px=\(image.size.width * image.scale)x\(image.size.height * image.scale)")
    }
}
