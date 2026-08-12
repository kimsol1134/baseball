import Foundation

/// The app's display language is deliberately independent from the simulation world and save data.
/// iOS supplies the preferred localization; this type only normalizes the supported language family.
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case korean = "ko"
    case english = "en"

    /// Normalizes `en-US`, `en_GB`, and other language-region identifiers to the supported app language.
    /// Unknown values use the development language, Korean, as required by the release plan.
    public init(localeIdentifier: String, developmentLanguage: AppLanguage = .korean) {
        let normalized = localeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        let languageCode = normalized.split(separator: "-", maxSplits: 1).first.map(String.init)

        switch languageCode {
        case "en": self = .english
        case "ko": self = .korean
        default: self = developmentLanguage
        }
    }

    /// Resolves the same preference list iOS uses for a localized bundle.
    public static func resolve(
        preferredLocalizations: [String],
        developmentLanguage: AppLanguage = .korean
    ) -> AppLanguage {
        for localization in preferredLocalizations {
            let candidate = AppLanguage(localeIdentifier: localization, developmentLanguage: developmentLanguage)
            let normalized = localization
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
                .lowercased()
            if normalized.hasPrefix("en-") || normalized == "en" ||
                normalized.hasPrefix("ko-") || normalized == "ko" {
                return candidate
            }
        }
        return developmentLanguage
    }

    public static func current(bundle: Bundle = .main) -> AppLanguage {
        resolve(preferredLocalizations: bundle.preferredLocalizations)
    }
}
