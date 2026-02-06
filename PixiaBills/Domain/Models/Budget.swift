import Foundation

struct Budget: Identifiable, Codable, Equatable {
    var id: UUID
    var month: Date
    var type: TransactionType
    var categoryId: UUID?
    var limit: Decimal
    var createdAt: Date
    var updatedAt: Date
}

