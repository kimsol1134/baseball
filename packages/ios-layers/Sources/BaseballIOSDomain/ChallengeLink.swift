import Foundation

/// 시드 도전 링크. 커스텀 스킴과 HTTPS 유니버설 링크를 같은 토큰 규칙으로 읽는다.
///
/// 토큰 검증은 고교 시작 화면의 `"<seed>-<life>"` 입력(`UInt64` 시드, 회차 1...999)과 같다.
public enum ChallengeLink {
    public static let urlScheme = "yagurebirth"
    public static let pathComponent = "challenge"
    public static let shareTextKey = "app.challenge-link.share-text"
    public static let hostInfoKey = "CHALLENGE_LINK_HOST"

    public struct Pending: Equatable, Sendable {
        public let seed: String
        public let life: Int

        public init(seed: String, life: Int) {
            self.seed = seed
            self.life = life
        }

        public var token: String { "\(seed)-\(life)" }
    }

    public enum Source: String, Equatable, Sendable {
        case scheme
        case universal
    }

    public struct OpenResult: Equatable, Sendable {
        public let source: Source?
        public let valid: Bool
        public let pending: Pending?
        public let showsDeferredBanner: Bool
        public let showsInvalidNotice: Bool

        public init(
            source: Source?,
            valid: Bool,
            pending: Pending?,
            showsDeferredBanner: Bool,
            showsInvalidNotice: Bool
        ) {
            self.source = source
            self.valid = valid
            self.pending = pending
            self.showsDeferredBanner = showsDeferredBanner
            self.showsInvalidNotice = showsInvalidNotice
        }
    }

    /// 두 형식 모두, 대소문자·트레일링 슬래시·쿼리를 무시한다.
    public static func parse(url: URL) -> (seed: String, life: Int)? {
        guard let token = token(from: url) else { return nil }
        return parseToken(token)
    }

    public static func parseToken(_ raw: String) -> (seed: String, life: Int)? {
        let normalized = raw.filter { $0.isNumber || $0 == "-" }
        let parts = normalized.split(separator: "-")
        guard parts.count == 2, UInt64(parts[0]) != nil,
              let life = Int(parts[1]), (1...999).contains(life) else { return nil }
        return (String(parts[0]), life)
    }

    public static func source(of url: URL) -> Source? {
        switch url.scheme?.lowercased() {
        case urlScheme: .scheme
        case "https", "http": .universal
        default: nil
        }
    }

    public static func shareURL(seed: String, life: Int, host: String? = nil) -> URL? {
        guard let pending = pending(seed: seed, life: life) else { return nil }
        let trimmedHost = normalizedHost(host)
        if trimmedHost.isEmpty {
            return URL(string: "\(urlScheme)://\(pathComponent)/\(pending.token)")
        }
        return URL(string: "https://\(trimmedHost)/\(pathComponent)/\(pending.token)")
    }

    /// 카탈로그 키만 반환한다. 문구는 앱 문자열 카탈로그가 맡는다.
    public static func shareText(seed: String, life: Int) -> (key: String, token: String)? {
        guard let pending = pending(seed: seed, life: life) else { return nil }
        return (shareTextKey, pending.token)
    }

    public static func host(from infoDictionary: [String: Any]?) -> String? {
        let raw = infoDictionary?[hostInfoKey] as? String
        let trimmed = normalizedHost(raw)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 시작 화면이 열려 있으면 시드 입력에 넣고, 커리어 진행 중이면 덮어쓰지 않고 미룬다.
    public static func open(url: URL, setupScreenOpen: Bool) -> OpenResult {
        let source = source(of: url)
        guard let parsed = parse(url: url) else {
            return OpenResult(
                source: source,
                valid: false,
                pending: nil,
                showsDeferredBanner: false,
                showsInvalidNotice: source != nil
            )
        }
        let pending = Pending(seed: parsed.seed, life: parsed.life)
        return OpenResult(
            source: source,
            valid: true,
            pending: pending,
            showsDeferredBanner: !setupScreenOpen,
            showsInvalidNotice: false
        )
    }

    public static func shouldShowDeferredBanner(
        hasPending: Bool,
        setupScreenOpen: Bool,
        loadSettled: Bool
    ) -> Bool {
        hasPending && loadSettled && !setupScreenOpen
    }

    public static func setupScreenOpen(
        highSchoolNeedsSetup: Bool,
        highSchoolTabVisible: Bool
    ) -> Bool {
        highSchoolNeedsSetup && highSchoolTabVisible
    }

    private static func pending(seed: String, life: Int) -> Pending? {
        guard let parsed = parseToken("\(seed)-\(life)") else { return nil }
        return Pending(seed: parsed.seed, life: parsed.life)
    }

    private static func normalizedHost(_ host: String?) -> String {
        guard var value = host?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return ""
        }
        if let schemeRange = value.range(of: "://") {
            value = String(value[schemeRange.upperBound...])
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    private static func token(from url: URL) -> String? {
        guard source(of: url) != nil else { return nil }
        var segments: [String] = []
        if url.scheme?.lowercased() == urlScheme, let host = url.host, !host.isEmpty {
            segments.append(host)
        }
        let path = url.path.isEmpty ? (url.pathComponents.isEmpty ? "" : url.path) : url.path
        segments.append(
            contentsOf: path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        )
        guard let index = segments.firstIndex(where: { $0.caseInsensitiveCompare(pathComponent) == .orderedSame }),
              index + 1 < segments.count else { return nil }
        if url.scheme?.lowercased() != urlScheme, index != 0 { return nil }
        return segments[index + 1].removingPercentEncoding ?? segments[index + 1]
    }
}
