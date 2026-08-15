import Foundation

/// Display-only baseball and currency formatters.
///
/// All inputs remain in the simulation's existing units. In particular, mph is derived from
/// tenths-of-km/h for display and is never fed back into engine thresholds, saves, or analytics.
public enum GameFormatters {
    private static let englishLocale = Locale(identifier: "en_US_POSIX")
    private static let koreanLocale = Locale(identifier: "ko_KR")
    private static let japaneseLocale = Locale(identifier: "ja_JP")

    public static func velocity(tenthsKPH: Int, language: AppLanguage) -> String {
        let kph = Double(max(0, tenthsKPH)) / 10
        switch language {
        case .korean:
            return "\(decimal(kph, places: 1, locale: koreanLocale)) km/h"
        case .english:
            let mph = kph / 1.609344
            return "\(decimal(mph, places: 1, locale: englishLocale)) mph"
        case .japanese:
            return "\(decimal(kph, places: 1, locale: japaneseLocale)) km/h"
        }
    }

    public static func mph(fromTenthsKPH tenthsKPH: Int) -> String {
        velocity(tenthsKPH: tenthsKPH, language: .english)
    }

    public static func distance(tenthsMeters: Int, language: AppLanguage) -> String {
        let meters = Double(max(0, tenthsMeters)) / 10
        switch language {
        case .korean:
            return "\(decimal(meters, places: 0, locale: koreanLocale))m"
        case .english:
            let feet = meters * 3.28084
            return "\(decimal(feet, places: 0, locale: englishLocale)) ft"
        case .japanese:
            return "\(decimal(meters, places: 0, locale: japaneseLocale))m"
        }
    }

    public static func innings(outs: Int, language: AppLanguage) -> String {
        let safeOuts = max(0, outs)
        let full = safeOuts / 3
        let remainder = safeOuts % 3
        switch language {
        case .korean:
            return "\(full).\(remainder)이닝"
        case .english:
            let fraction: String
            switch remainder {
            case 1: fraction = "⅓"
            case 2: fraction = "⅔"
            default: fraction = ""
            }
            return "\(full)\(fraction) IP"
        case .japanese:
            let fraction: String
            switch remainder {
            case 1: fraction = "⅓"
            case 2: fraction = "⅔"
            default: fraction = ""
            }
            return "\(full)\(fraction)回"
        }
    }

    /// Formats an inning number for narrative situation copy without changing the stored value.
    public static func inningLabel(inning: Int, language: AppLanguage) -> String {
        let safeInning = max(0, inning)
        switch language {
        case .korean:
            return "\(safeInning)회"
        case .english:
            return "\(safeInning)\(ordinalSuffix(for: safeInning)) inning"
        case .japanese:
            return "\(safeInning)回"
        }
    }

    public static func ra9(runsAllowed: Int, outs: Int, language: AppLanguage) -> String {
        guard outs > 0 else { return unavailableMetric(suffix: "RA9", language: language) }
        let value = Double(max(0, runsAllowed)) * 27 / Double(outs)
        return metric(value, suffix: "RA9", places: 2, language: language)
    }

    public static func avg(hits: Int, atBats: Int, language: AppLanguage) -> String {
        guard atBats > 0 else { return unavailableMetric(suffix: "AVG", language: language) }
        let value = Double(max(0, hits)) / Double(atBats)
        let formatted = decimal(value, places: 3, locale: locale(for: language))
        let withoutLeadingZero = formatted.hasPrefix("0.") ? String(formatted.dropFirst()) : formatted
        return language == .english ? "\(withoutLeadingZero) AVG" : withoutLeadingZero
    }

    public static func whip(hits: Int, walks: Int, outs: Int, language: AppLanguage) -> String {
        guard outs > 0 else { return unavailableMetric(suffix: "WHIP", language: language) }
        let value = Double(max(0, hits) + max(0, walks)) * 3 / Double(outs)
        return metric(value, suffix: "WHIP", places: 2, language: language)
    }

    /// KRW remains KRW in English. No storefront or exchange-rate conversion is performed.
    public static func krw(_ amount: Int, language: AppLanguage) -> String {
        let value = max(0, amount)
        let formatted = number(value, locale: locale(for: language))
        switch language {
        case .korean: return "\(formatted)원"
        case .english: return "KRW \(formatted)"
        case .japanese: return "\(formatted)ウォン"
        }
    }

    private static func metric(_ value: Double, suffix: String, places: Int, language: AppLanguage) -> String {
        let formatted = decimal(value, places: places, locale: locale(for: language))
        return language == .english ? "\(formatted) \(suffix)" : formatted
    }

    private static func unavailableMetric(suffix: String, language: AppLanguage) -> String {
        language == .english ? "— \(suffix)" : "—"
    }

    private static func locale(for language: AppLanguage) -> Locale {
        switch language {
        case .korean: koreanLocale
        case .english: englishLocale
        case .japanese: japaneseLocale
        }
    }

    private static func ordinalSuffix(for value: Int) -> String {
        let lastTwoDigits = value % 100
        if (11...13).contains(lastTwoDigits) { return "th" }
        switch value % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private static func decimal(_ value: Double, places: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = places
        formatter.maximumFractionDigits = places
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }

    private static func number(_ value: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
