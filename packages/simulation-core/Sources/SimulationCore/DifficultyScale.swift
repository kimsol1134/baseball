import Foundation

/// 상대는 시간이 갈수록 세져야 한다.
///
/// 실측으로 드러난 문제(DOC 2026-07-28 §3.5): 고교 3년 동안 상대 능력 증가가 **0**이었다.
/// 라이벌은 회차 시작 시 한 번 만들어지고 그대로였고, 프로 12시즌도 상대가 고정이었다.
/// 그동안 플레이어만 +10~20 성장하므로 **난이도 곡선이 단조 하강**한다 — 뒤로 갈수록 쉬워진다.
/// 계단은 고교→프로 한 곳뿐이었다.
///
/// 여기서 세 축으로 올린다.
/// - **챕터**: 3학년 여름의 상대가 1학년 봄의 상대와 같을 수는 없다.
/// - **회차**: 10회차 플레이어는 1회차보다 훨씬 강하다. 리그가 그대로면 환생이 곧 무쌍이 된다.
/// - **시즌**: 프로도 같은 이유.
///
/// 값은 `AutoOutingSimulator`의 `batterOffset`과 같은 단위다(타자 세 능력에 그대로 더한다).
/// 새 시스템을 만들지 않고 이미 있는 손잡이를 쓴다.
public enum DifficultyScale {
    /// 한 회차 안에서 상대가 세지는 폭의 상한.
    ///
    /// 5로 잡았다가 되돌렸다. 곡선이 평평해지는 것을 넘어 **벽**이 됐다 — 평범한 플레이의
    /// 드래프트 통과율이 30%에서 20%로 떨어졌다(밴드 25~65%). 목표는 뒤로 갈수록 쉬워지는
    /// 것을 막는 것이지 뒤를 어렵게 만드는 것이 아니다.
    ///
    /// 2026-08 실플레이에서 환생 0회 선수가 3~4경기 연속 무실점을 했다. 3은 곡선을
    /// 평평하게 만들 뿐 3학년의 상대를 실제로 무겁게 만들지는 못한다는 뜻이다. 벽이 됐던
    /// 5 대신 4로 올린다 — 마지막 장의 상대가 한 눈금 더 세지되, 통과율이 반토막 나지 않는
    /// 자리다. 나머지 난이도는 타자 기본선(`HighSchoolPresentation.followUpBatters`)과
    /// 릴리스 판정에서 함께 가져온다.
    public static let chapterCeiling = 4
    /// 회차가 쌓이며 리그 전체가 세지는 폭의 상한.
    public static let rebirthCeiling = 4
    /// 프로에서 시즌이 지나며 세지는 폭의 상한.
    public static let seasonCeiling = 8

    /// 고교 상대의 능력 보정.
    ///
    /// - Parameters:
    ///   - chapter: 1~8.
    ///   - lifeNumber: 1부터.
    public static func highSchool(chapter: Int, lifeNumber: Int) -> Int {
        let byChapter = min(chapterCeiling, max(0, chapter - 1) * chapterCeiling / 7)
        // 회차는 천천히 오른다. 2회차에 갑자기 벽이 서면 환생이 벌처럼 느껴진다.
        let byLife = min(rebirthCeiling, max(0, lifeNumber - 1) * 2)
        return byChapter + byLife
    }

    /// 프로 상대의 능력 보정. 시즌이 갈수록 리그가 자신에게 맞춰 온다.
    public static func pro(season: Int) -> Int {
        min(seasonCeiling, max(0, season - 1))
    }

    /// 세 능력에 보정을 더한 타자. 20~80 눈금을 벗어나지 않는다.
    public static func scaled(_ batter: BatterSnapshot, by offset: Int) -> BatterSnapshot {
        guard offset != 0 else { return batter }
        func bump(_ value: Int) -> Int { min(80, max(20, value + offset)) }
        return BatterSnapshot(
            id: batter.id,
            name: batter.name,
            contact: bump(batter.contact),
            discipline: bump(batter.discipline),
            power: bump(batter.power),
            batSide: batter.batSide
        )
    }
}
