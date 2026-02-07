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


    var decimalInputSanitized: String {
        var result = ""
        var hasDecimalSeparator = false
        var hasSign = false

        for (index, char) in self.enumerated() {
            if char.isNumber {
                result.append(char)
                continue
            }

            if (char == "." || char == ",") && !hasDecimalSeparator {
                result.append(".")
                hasDecimalSeparator = true
                continue
            }

            if char == "-", index == 0, !hasSign {
                result.append(char)
                hasSign = true
                continue
            }
        }

        return result
    }
}

