import Foundation

/// 저장을 파일 한 장으로 내보내는 규칙(7-E).
///
/// 저장이 거듭 실패할 때 플레이어에게 남길 수 있는 유일한 것이 이 파일이다. 그래서
/// **읽기만 하고 아무것도 쓰지 않는다** — 내보내기가 저장을 건드리면 마지막 사본마저
/// 위험해진다.
public struct SaveExportBundle: Codable, Equatable, Sendable {
    /// 이 파일이 어떤 앱·언제 만들어졌는지. 나중에 사람이 읽고 판단할 수 있어야 한다.
    public let exportedAt: String
    public let appVersion: String
    public let highSchool: String?
    public let pro: String?

    public init(exportedAt: String, appVersion: String, highSchool: String?, pro: String?) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.highSchool = highSchool
        self.pro = pro
    }

    /// 저장 원본(JSON)을 그대로 담는다. 다시 해석하지 않으므로 스키마가 올라가도
    /// 내보내기가 깨지지 않는다.
    public static func make(
        highSchool: Data?,
        pro: Data?,
        appVersion: String,
        date: Date = Date()
    ) -> SaveExportBundle {
        SaveExportBundle(
            exportedAt: ISO8601DateFormatter().string(from: date),
            appVersion: appVersion,
            highSchool: highSchool.map { $0.base64EncodedString() },
            pro: pro.map { $0.base64EncodedString() }
        )
    }

    /// 담긴 것이 하나도 없으면 내보낼 이유가 없다.
    public var isEmpty: Bool { highSchool == nil && pro == nil }

    /// 사람이 파일 목록에서 알아볼 이름.
    public static func fileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "baseball-save-\(formatter.string(from: date)).json"
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        // 같은 내용이면 같은 바이트가 나오게 둔다 — 사용자가 두 파일을 비교할 수 있다.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }
}
