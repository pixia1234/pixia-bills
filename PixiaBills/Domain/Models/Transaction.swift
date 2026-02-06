import Foundation

struct Transaction: Identifiable, Codable, Equatable {
    var id: UUID
    var type: TransactionType
    var amount: Decimal
    var date: Date
    var categoryId: UUID
    var accountId: UUID
    var note: String?
    var createdAt: Date
    var updatedAt: Date
}

