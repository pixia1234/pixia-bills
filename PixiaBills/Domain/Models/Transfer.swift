import Foundation

struct Transfer: Identifiable, Codable, Equatable {
    var id: UUID
    var amount: Decimal
    var date: Date
    var fromAccountId: UUID
    var toAccountId: UUID
    var note: String?
    var createdAt: Date
    var updatedAt: Date
}

