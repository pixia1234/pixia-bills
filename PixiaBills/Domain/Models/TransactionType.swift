import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
}

extension TransactionType {
    var displayName: String {
        switch self {
        case .income:
            return "收入"
        case .expense:
            return "支出"
        }
    }
}

