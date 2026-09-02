import SwiftUI
import BaseballIOSDomain

struct GlossaryText: View {
    let text: String
    var font: Font = BaseballType.detail
    var color: Color = BaseballTheme.textSecondary
    var lineSpacing: CGFloat = BaseballMetrics.detailLineSpacing
    var kerning: CGFloat = 0

    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var selected: GlossaryTerm?

    /// 보조 설명 한 줄(detail). 예전 기본값 footnote는 문장 하한(15pt) 아래였다.
    init(
        text: String,
        font: Font = BaseballType.detail,
        color: Color = BaseballTheme.textSecondary,
        lineSpacing: CGFloat = BaseballMetrics.detailLineSpacing
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
    }

    /// 서사·설명 문단(prose). `proseStyle()`과 같은 17pt·한글 행간·자간을 붙인다.
    init(prose text: String, color: Color = BaseballTheme.textPrimary) {
        self.text = text
        self.font = BaseballType.prose
        self.color = color
        self.lineSpacing = BaseballMetrics.proseLineSpacing
        self.kerning = -0.2
    }

    var body: some View {
        let names = displayNames
        let matches = GlossaryCatalog.matches(in: text, names: names)
        // 밑줄 링크 하나로 충분하다. 예전에는 문단 오른쪽에 info 버튼 열을 따로 세워
        // 본문 폭을 잡아먹었다. VoiceOver는 아래 accessibilityAction으로 같은 정의에 닿는다.
        // localization-safe: resolved-copy
        Text(attributed(matches: matches))
            .font(font)
            .lineSpacing(lineSpacing)
            .kerning(kerning)
            .foregroundStyle(color)
            .tint(BaseballTheme.information)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "glossary",
                      let term = GlossaryCatalog.term(id: url.host ?? "") else {
                    return .systemAction
                }
                selected = term
                return .handled
            })
            .modifier(GlossaryTermActions(
                actions: matches.compactMap { match -> (term: GlossaryTerm, name: String)? in
                    guard let term = GlossaryCatalog.term(id: match.id) else { return nil }
                    let name = copyResolver.resolve(
                        MetaUICopyKey.glossaryTermAction,
                        arguments: [.userText(names[term.id] ?? term.id)]
                    )
                    return (term, name)
                },
                select: { selected = $0 }
            ))
            .sheet(item: $selected) { term in
                GlossaryDefinitionSheet(term: term)
            }
    }

    private var displayNames: [String: String] {
        Dictionary(uniqueKeysWithValues: GlossaryCatalog.terms.map { term in
            (term.id, copyResolver.resolve(.gameContent(term.nameKey)))
        })
    }

    private func attributed(matches: [GlossaryMatch]) -> AttributedString {
        var value = AttributedString(text)
        for match in matches {
            guard let stringRange = GlossaryCatalog.range(in: text, match: match),
                  let attributedRange = Range(stringRange, in: value),
                  let url = URL(string: "glossary://\(match.id)") else { continue }
            value[attributedRange].link = url
            value[attributedRange].underlineStyle = .single
            value[attributedRange].foregroundColor = BaseballTheme.information
        }
        return value
    }
}

/// 문단에 등장한 용어마다 VoiceOver 사용자 지정 동작("구위 뜻 보기")을 하나씩 붙인다.
private struct GlossaryTermActions: ViewModifier {
    let actions: [(term: GlossaryTerm, name: String)]
    let select: (GlossaryTerm) -> Void

    func body(content: Content) -> some View {
        actions.reduce(AnyView(content)) { partial, action in
            AnyView(
                partial.accessibilityAction(named: Text(verbatim: action.name)) {
                    select(action.term)
                }
            )
        }
    }
}

struct GlossaryDefinitionSheet: View {
    let term: GlossaryTerm
    @Environment(\.gameCopyResolver) private var copyResolver
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                Text(verbatim: copyResolver.resolve(.gameContent(term.nameKey)))
                    .font(.title3.weight(.bold))
                Text(verbatim: copyResolver.resolve(.gameContent(term.definitionKey)))
                    .proseStyle(BaseballTheme.textSecondary)
                Spacer()
            }
            .padding(BaseballMetrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BaseballTheme.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copyResolver.resolve(MetaUICopyKey.glossarySheetClose)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("glossary.sheet.\(term.id)")
    }
}

struct GlossaryListView: View {
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var selected: GlossaryTerm?

    var body: some View {
        List {
            ForEach(GlossaryCatalog.terms) { term in
                Button {
                    selected = term
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: copyResolver.resolve(.gameContent(term.nameKey)))
                            .font(.headline)
                            .foregroundStyle(BaseballTheme.textPrimary)
                        Text(verbatim: copyResolver.resolve(.gameContent(term.definitionKey)))
                            .detailStyle()
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("glossary.term.\(term.id)")
                .accessibilityHint(copyResolver.resolve(MetaUICopyKey.glossaryTermHint))
            }
        }
        .scrollContentBackground(.hidden)
        .background(BaseballTheme.canvas)
        .navigationTitle(copyResolver.resolve(MetaUICopyKey.settingsGlossaryTitle))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { term in
            GlossaryDefinitionSheet(term: term)
        }
    }
}
