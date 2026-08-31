import SwiftUI

enum CopyDensity: String, CaseIterable, Identifiable {
    case automatic
    case expanded
    case compact

    static let storageKey = "baseball.copyDensity"
    var id: String { rawValue }
}

struct SeenContentStore {
    static let storageKey = "baseball.seenContent.v1"

    static func seenIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    static func contains(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        seenIDs(defaults: defaults).contains(id)
    }

    static func markSeen(_ id: String, defaults: UserDefaults = .standard) {
        var ids = seenIDs(defaults: defaults)
        ids.insert(id)
        defaults.set(Array(ids).sorted(), forKey: storageKey)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
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
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.contentID = contentID
        self.title = title
        self.summary = summary
        self.important = important
        self.detail = detail
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            detail()
                .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: title).font(.headline)
                if !expanded || density == .compact {
                    Text(verbatim: summary)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
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
            case .automatic: expanded = important || !SeenContentStore.contains(contentID)
            }
            SeenContentStore.markSeen(contentID)
        }
        .onChange(of: densityRaw) { _, newValue in
            guard let next = CopyDensity(rawValue: newValue) else { return }
            switch next {
            case .expanded: expanded = true
            case .compact: expanded = important
            case .automatic:
                if !important { expanded = !SeenContentStore.contains(contentID) }
            }
        }
    }
}
