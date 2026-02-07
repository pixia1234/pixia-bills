import Foundation

struct Category: Identifiable, Codable, Equatable {
    var id: UUID
    var type: TransactionType
    var name: String
    var iconName: String
    var sortOrder: Int
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        type: TransactionType,
        name: String,
        iconName: String,
        sortOrder: Int,
        isDefault: Bool,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case iconName
        case sortOrder
        case isDefault
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyTimestamp = Date(timeIntervalSince1970: 0)

        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(TransactionType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? legacyTimestamp
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

extension Category {
    func with(sortOrder: Int, updatedAt: Date? = nil) -> Category {
        var copy = self
        copy.sortOrder = sortOrder
        if let updatedAt {
            copy.updatedAt = updatedAt
        }
        return copy
    }
}
