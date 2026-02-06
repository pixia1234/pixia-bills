import Foundation

struct Category: Identifiable, Codable, Equatable {
    var id: UUID
    var type: TransactionType
    var name: String
    var iconName: String
    var sortOrder: Int
    var isDefault: Bool
}

extension Category {
    func with(sortOrder: Int) -> Category {
        var copy = self
        copy.sortOrder = sortOrder
        return copy
    }
}

