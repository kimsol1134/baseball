import SwiftUI
import BaseballIOSDomain

enum CopyDensity: String, CaseIterable, Identifiable {
    case automatic
    case expanded
    case compact

    static let storageKey = "baseball.copyDensity"
    var id: String { rawValue }
}

/// 앱 안 글자 크기. 시스템 Dynamic Type을 낮추지는 않고, 사용자가 고른 하한만 보장한다 —
/// "글씨가 작아 안 읽힌다"는 리뷰에 기기 설정을 뒤지게 하지 않기 위한 세 단계다.
enum ReadingSize: String, CaseIterable, Identifiable {
    case standard
    case large
    case extraLarge

    static let storageKey = "baseball.readingSize"
    var id: String { rawValue }

    /// 이 크기가 보장하는 Dynamic Type 하한. 표준은 시스템을 그대로 따른다.
    var minimumDynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .standard: nil
        case .large: .xLarge
        case .extraLarge: .xxxLarge
        }
    }
}

/// 시스템 크기와 앱 설정 중 큰 쪽을 적용한다. 시스템이 이미 더 크면 손대지 않는다.
struct ReadingSizeModifier: ViewModifier {
    @AppStorage(ReadingSize.storageKey) private var readingSizeRaw = ReadingSize.standard.rawValue
    @Environment(\.dynamicTypeSize) private var systemSize

    private var resolvedSize: DynamicTypeSize {
        let preference = ReadingSize(rawValue: readingSizeRaw) ?? .standard
        guard let minimum = preference.minimumDynamicTypeSize else { return systemSize }
        return max(systemSize, minimum)
    }

    func body(content: Content) -> some View {
        content.dynamicTypeSize(resolvedSize)
    }
}

extension View {
    /// 설정의 "글자 크기"를 앱 루트에 한 번 적용한다.
    func readingSize() -> some View {
        modifier(ReadingSizeModifier())
    }
}

struct SeenContentStore {
    static let storageKey = "baseball.seenContent.v1"
    static let timestampsKey = "baseball.seenContent.v2"
    static let freshnessInterval: TimeInterval = 14 * 24 * 60 * 60

    static func migrateIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: timestampsKey) == nil else { return }
        let legacy = defaults.stringArray(forKey: storageKey) ?? []
        guard !legacy.isEmpty else { return }
        let now = Date().timeIntervalSince1970
        var stamps: [String: Double] = [:]
        for id in legacy { stamps[id] = now }
        defaults.set(stamps, forKey: timestampsKey)
    }

    static func timestamps(defaults: UserDefaults = .standard) -> [String: Double] {
        migrateIfNeeded(defaults: defaults)
        return defaults.dictionary(forKey: timestampsKey) as? [String: Double] ?? [:]
    }

    static func seenIDs(defaults: UserDefaults = .standard, now: Date = Date()) -> Set<String> {
        Set(timestamps(defaults: defaults).compactMap { id, stamp in
            now.timeIntervalSince1970 - stamp < freshnessInterval ? id : nil
        })
    }

    static func contains(_ id: String, defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        guard let stamp = timestamps(defaults: defaults)[id] else { return false }
        return now.timeIntervalSince1970 - stamp < freshnessInterval
    }

    static func markSeen(_ id: String, defaults: UserDefaults = .standard, at date: Date = Date()) {
        migrateIfNeeded(defaults: defaults)
        var stamps = timestamps(defaults: defaults)
        stamps[id] = date.timeIntervalSince1970
        defaults.set(stamps, forKey: timestampsKey)
        defaults.set(Array(stamps.keys).sorted(), forKey: storageKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: timestampsKey)
        defaults.removeObject(forKey: CopyDensity.storageKey)
    }
}

/// Repeated system explanations start open once, then remember the user's familiarity locally.
/// Important alerts opt out so compact mode can never hide a required result or action.
struct ProgressiveDisclosure<Detail: View>: View {
    let contentID: String
    let title: String
    let summary: String
    let important: Bool
    /// 카드 안에서 제목을 결과 한 줄(proseLead)로 세울 때 true. 기본은 섹션 제목(headline).
    let leadStyle: Bool
    /// true면 자동 밀도에서도 첫 회를 포함해 접힌 채로 시작한다. 중요한 결과(`important`)와
    /// 펼침 밀도는 이 값을 이긴다.
    let startsCollapsed: Bool
    let detail: () -> Detail

    @AppStorage(CopyDensity.storageKey) private var densityRaw = CopyDensity.automatic.rawValue
    @State private var expanded = true
    @State private var appeared = false
    @Environment(\.gameCopyResolver) private var copyResolver

    private var density: CopyDensity { CopyDensity(rawValue: densityRaw) ?? .automatic }

    init(
        contentID: String,
        title: String,
        summary: String,
        important: Bool = false,
        leadStyle: Bool = false,
        startsCollapsed: Bool = false,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.contentID = contentID
        self.title = title
        self.summary = summary
        self.important = important
        self.leadStyle = leadStyle
        self.startsCollapsed = startsCollapsed
        self.detail = detail
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            detail()
                .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                if leadStyle {
                    Text(verbatim: title).proseLeadStyle()
                } else {
                    Text(verbatim: title).font(.headline)
                }
                if !summary.isEmpty, !expanded || density == .compact {
                    Text(verbatim: summary).detailStyle().multilineTextAlignment(.leading)
                }
            }
        }
        .accessibilityLabel(copyResolver.resolve(
            expanded
                ? MetaUICopyKey.disclosureAccessibilityExpanded
                : MetaUICopyKey.disclosureAccessibilityCollapsed,
            arguments: [.userText(title)]
        ))
        .accessibilityHint(copyResolver.resolve(
            expanded ? MetaUICopyKey.disclosureHintCollapse : MetaUICopyKey.disclosureHintExpand
        ))
        .onAppear {
            guard !appeared else { return }
            appeared = true
            switch density {
            case .expanded: expanded = true
            case .compact: expanded = important
            case .automatic:
                expanded = important || (!startsCollapsed && !SeenContentStore.contains(contentID))
            }
            if expanded { SeenContentStore.markSeen(contentID) }
        }
        .onChange(of: expanded) { _, isExpanded in
            if isExpanded { SeenContentStore.markSeen(contentID) }
        }
        .onChange(of: densityRaw) { _, newValue in
            guard let next = CopyDensity(rawValue: newValue) else { return }
            switch next {
            case .expanded: expanded = true
            case .compact: expanded = important
            case .automatic:
                if !important {
                    expanded = !startsCollapsed && !SeenContentStore.contains(contentID)
                }
            }
        }
    }
}
