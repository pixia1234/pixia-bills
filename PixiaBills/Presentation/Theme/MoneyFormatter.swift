import Foundation

enum MoneyFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func string(from decimal: Decimal) -> String {
        formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? decimal.plainString
    }
}

