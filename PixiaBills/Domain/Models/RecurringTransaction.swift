import Foundation

struct RecurringTransaction: Identifiable, Codable, Equatable {
    enum Frequency: String, Codable, CaseIterable {
        case daily
        case weekly
        case monthly

        var displayName: String {
            switch self {
            case .daily:
                return "每天"
            case .weekly:
                return "每周"
            case .monthly:
                return "每月"
            }
        }
    }

    var id: UUID
    var type: TransactionType
    var amount: Decimal
    var categoryId: UUID
    var accountId: UUID
    var note: String?
    var frequency: Frequency
    var startDate: Date
    var endDate: Date?
    var lastGeneratedAt: Date?
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}

