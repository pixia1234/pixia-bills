import Foundation

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            let escaped = replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return self
    }
}

