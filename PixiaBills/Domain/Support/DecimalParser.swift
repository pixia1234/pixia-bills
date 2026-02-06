import Foundation

enum DecimalParser {
    static func parse(_ text: String) -> Decimal? {
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !sanitized.isEmpty else { return nil }
        return Decimal(string: sanitized, locale: Locale(identifier: "en_US_POSIX"))
    }
}

