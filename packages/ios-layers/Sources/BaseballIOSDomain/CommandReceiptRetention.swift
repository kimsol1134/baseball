import Foundation

/// 이미 적용한 명령을 두 번 적용하지 않기 위한 영수증.
///
/// 같은 버튼이 두 번 눌리거나 저장이 재시도되면 같은 명령이 두 번 갈 수 있다. 영수증은
/// **저장 revision에 묶여** 있어서, 같은 명령이라도 다른 revision에서 온 것은 다른 영수증이다
/// — 그래서 "3주차의 훈련"과 "5주차의 같은 훈련"이 서로를 막지 않는다.
///
/// 안드로이드 `CommandReceiptRetention`과 같은 규칙이다. 해시만 다르다 — 영수증은 기기 안에서만
/// 쓰이고 플랫폼을 건너지 않으므로 같은 해시일 필요가 없고, 코어의 내부 해시를 이것 하나 때문에
/// 공개로 열 이유도 없다.
public enum CommandReceiptRetention {
    /// 들고 다닐 최근 영수증 수.
    public static let recentLimit = 256

    private static let boundPrefix = "revision:"

    public static func id(revision: UInt64, operation: String) -> String {
        "\(boundPrefix)\(revision):\(fingerprint(operation))"
    }

    /// FNV-1a 64비트. 명령 문자열을 짧고 안정적인 지문으로 줄인다 — 같은 문자열이면 언제나
    /// 같은 값이고, 실수로 두 번 보낸 명령을 가려내는 데는 이것으로 충분하다.
    static func fingerprint(_ value: String) -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 16)
    }

    /// 이 영수증이 묶인 revision. 묶이지 않은 옛 영수증은 nil이다.
    public static func revision(of id: String) -> UInt64? {
        guard id.hasPrefix(boundPrefix) else { return nil }
        let parts = id.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        return UInt64(parts[1])
    }

    /// 이 명령을 지금 적용해도 되는가.
    ///
    /// 이미 적용한 영수증이면 거부한다. 묶인 revision이 지금과 다르면 낡은 명령이므로 역시
    /// 거부한다 — 화면이 들고 있던 옛 상태에서 눌린 버튼이다.
    public static func accepts(_ id: String, at revision: UInt64, seen: [String]) -> Bool {
        if seen.contains(id) { return false }
        if let bound = self.revision(of: id), bound != revision { return false }
        return true
    }

    /// 보관할 영수증을 고른다.
    ///
    /// **묶이지 않은 옛 영수증은 버리지 않는다.** 나이를 알 수 없으므로 버리면 그 명령이
    /// 나중에 다시 적용될 수 있다. 문자열 순서로 나이를 짐작하지도 않는다 — 묶인 것만
    /// revision 순으로 최근 것을 남긴다.
    public static func retaining(_ ids: [String]) -> [String] {
        var unique: [String] = []
        for id in ids where !unique.contains(id) {
            unique.append(id)
        }
        let opaque = unique.filter { revision(of: $0) == nil }
        let bound = unique
            .filter { revision(of: $0) != nil }
            .sorted { (revision(of: $0) ?? 0, $0) < (revision(of: $1) ?? 0, $1) }
            .suffix(recentLimit)
        return (opaque + bound).sorted()
    }
}
