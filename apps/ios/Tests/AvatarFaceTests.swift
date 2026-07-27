import XCTest
@testable import BaseballIOS

/// 같은 이름은 언제나 같은 얼굴이어야 한다.
///
/// 초상은 저장되지 않는다 — 이름에서 매번 다시 만들어진다. 그래서 파츠 선택이 흔들리면
/// **앱을 다시 켤 때마다 감독의 얼굴이 바뀐다.** 3년을 함께한 사람이라는 감각이 그 자리에서
/// 무너지므로, 결정론은 이 기능의 부가 조건이 아니라 기능 자체다.
final class AvatarFaceTests: XCTestCase {
    func testSameSeedGivesSameFace() {
        let first = AvatarParts(seed: "김도현", role: .coach)
        let second = AvatarParts(seed: "김도현", role: .coach)
        XCTAssertEqual(first, second)
    }

    /// 역할이 시드에 섞인다. 같은 이름의 감독과 포수가 쌍둥이로 보이면 안 된다.
    func testRoleChangesTheFace() {
        XCTAssertNotEqual(AvatarParts(seed: "김도현", role: .coach), AvatarParts(seed: "김도현", role: .catcher))
    }

    /// 데스크톱 `hashSeed`와 같은 FNV-1a 32비트여야 한다. 두 플랫폼에서 같은 사람이
    /// 다르게 생기면 그건 같은 사람이 아니다.
    func testHashMatchesDesktopFnv1a() {
        XCTAssertEqual(AvatarParts.hash(""), 0x811c_9dc5)
        // FNV-1a("a") = 0xe40c292c — 참조 구현의 표준 벡터다.
        XCTAssertEqual(AvatarParts.hash("a"), 0xe40c_292c)
        XCTAssertEqual(AvatarParts.hash("foobar"), 0xbf9c_f968)
    }

    /// 이름 표본을 돌려 파츠가 실제로 흩어지는지 본다. 한 값에 몰리면 모두가 같은 얼굴이 된다.
    func testFacesVaryAcrossNames() {
        let names = ["김도현", "박서준", "이민재", "최우성", "정하늘", "강태현", "윤지호", "임건우",
                     "오세훈", "한동엽", "신재호", "조민석", "배성우", "노경민", "황시원", "문재윤"]
        let faces = names.map { AvatarParts(seed: $0, role: .player) }
        XCTAssertGreaterThanOrEqual(Set(faces.map(\.skinIndex)).count, 3, "피부색이 거의 한 값에 몰렸습니다.")
        XCTAssertGreaterThanOrEqual(Set(faces.map(\.eyeStyle)).count, 2)
        XCTAssertGreaterThanOrEqual(Set(faces.map(\.mouthStyle)).count, 3)
        // 얼굴 전체가 같은 조합인 이름이 표본 안에 둘 이상 있으면 안 된다.
        XCTAssertEqual(Set(faces).count, names.count, "서로 다른 이름이 완전히 같은 얼굴을 받았습니다.")
    }

    /// 라이벌은 헬멧, 포수는 마스크. 역할 소품은 조건이 아니라 규칙이다.
    func testRivalNeverWearsTheCap() {
        for name in ["문재윤", "강태현", "정하늘", "임건우"] {
            let parts = AvatarParts(seed: name, role: .rival)
            XCTAssertTrue(parts.showHat, "라이벌은 항상 머리 장비를 쓴다(헬멧으로 그려진다).")
        }
    }

    /// 파츠 인덱스가 팔레트 범위를 넘지 않는다. 넘으면 그리는 순간 인덱스 오류로 죽는다.
    func testIndicesStayInPaletteRange() {
        for number in 0..<500 {
            let parts = AvatarParts(seed: "선수\(number)", role: .player)
            XCTAssertTrue((0..<5).contains(parts.skinIndex))
            XCTAssertTrue((0...3).contains(parts.hairColorIndex))
            XCTAssertTrue((0..<5).contains(parts.jerseyIndex))
            XCTAssertTrue((0..<3).contains(parts.faceShape))
            XCTAssertTrue((0..<5).contains(parts.hairStyle))
        }
    }
}
