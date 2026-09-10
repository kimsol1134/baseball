import Foundation
import SimulationCore
import BaseballIOSDomain

/// 프로 구단의 가상 인물. 같은 구단·같은 역할이면 재시작 뒤에도 같은 사람이다.
///
/// 안드로이드 `ProPeoplePresentation`의 이식이다. 한 가지만 다르다 — 안드로이드는 감독과
/// 스태프가 같은 이름 표를 같은 색인으로 읽어 **한 구단에서 두 사람이 같은 이름**을 갖는다.
/// 여기서는 역할을 시드에 넣어 갈라 둔다.
enum ProPeoplePresentation {
    /// 초상 시드. 같은 구단·역할이면 같은 얼굴이다.
    static func seed(teamID: String, role: ProConversationRole) -> String {
        "pro-staff:\(teamID):\(role.rawValue)"
    }

    static func portraitRole(_ role: ProConversationRole) -> AvatarFace.Role {
        switch role {
        case .catcher: .catcher
        case .coach, .staff: .coach
        }
    }

    static func roleLabel(_ role: ProConversationRole, resolver: GameCopyResolver) -> String {
        switch role {
        case .coach: resolver.resolve(.conversationRoleCoach)
        case .catcher: resolver.resolve(.conversationRoleCatcher)
        case .staff: resolver.resolve(.conversationRoleStaff)
        }
    }

    static func name(teamID: String, role: ProConversationRole, resolver: GameCopyResolver) -> String {
        let pool = role == .catcher ? catcherNameKeys : coachNameKeys
        return resolver.resolve(.gameContent(pool[index(teamID: teamID, role: role, count: pool.count)]))
    }

    /// 이름만으로는 누구인지 알 수 없다. 결 한 줄이 같이 있어야 사람이 된다.
    static func personality(
        teamID: String,
        role: ProConversationRole,
        resolver: GameCopyResolver
    ) -> String {
        let variant = index(teamID: teamID, role: role, count: 2)
        return resolver.resolve(.gameContent("content.pro-people.personality.\(role.rawValue).\(variant)"))
    }

    private static let catcherNameKeys = [
        "content.pro-people.catcher.0",
        "content.pro-people.catcher.1",
        "content.pro-people.catcher.2",
        "content.pro-people.catcher.3",
    ]

    private static let coachNameKeys = [
        "content.pro-people.coach.0",
        "content.pro-people.coach.1",
        "content.pro-people.coach.2",
        "content.pro-people.coach.3",
    ]

    /// `String.hashValue`는 실행마다 달라져 같은 구단이 매번 다른 사람을 만난다.
    /// 저장에 남지 않는 값이라도 화면에서는 사람이 바뀌어 보이므로 고정 해시를 쓴다.
    private static func index(teamID: String, role: ProConversationRole, count: Int) -> Int {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in "\(teamID)|\(role.rawValue)".utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return Int(hash % UInt64(max(1, count)))
    }
}
