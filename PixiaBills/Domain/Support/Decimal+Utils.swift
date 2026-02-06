import Foundation

extension Decimal {
    var plainString: String {
        NSDecimalNumber(decimal: self).stringValue
    }
}

