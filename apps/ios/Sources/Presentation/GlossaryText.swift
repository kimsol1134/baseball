import SwiftUI
import BaseballIOSDomain

struct GlossaryText: View {
    let text: String
    var font: Font = .footnote
    var color: Color = BaseballTheme.textSecondary

    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var selected: GlossaryTerm?

    var body: some View {
        let names = displayNames
        let matches = GlossaryCatalog.matches(in: text, names: names)
        HStack(alignment: .top, spacing: 6) {
            // localization-safe: resolved-copy
            Text(attributed(matches: matches))
                .font(font)
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
            if !matches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(matches, id: \.id) { match in
                        if let term = GlossaryCatalog.term(id: match.id) {
                            Button {
                                selected = term
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(font)
                                    .foregroundStyle(BaseballTheme.information)
                            }
                            .buttonStyle(.plain)
                            .frame(minWidth: 32, minHeight: 32, alignment: .top)
                            .accessibilityLabel(names[term.id] ?? term.id)
                            .accessibilityHint(copyResolver.resolve(MetaUICopyKey.glossaryTermHint))
                            .accessibilityIdentifier("glossary.term.\(term.id)")
                        }
                    }
                }
            }
        }
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
                    .font(.body)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
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
