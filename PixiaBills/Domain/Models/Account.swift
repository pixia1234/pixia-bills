import Foundation

struct Account: Identifiable, Codable, Equatable {
    enum AccountType: String, Codable, CaseIterable {
        case cash
        case bank
        case credit

        var displayName: String {
            switch self {
            case .cash:
                return "现金"
            case .bank:
                return "银行卡"
            case .credit:
                return "信用卡"
            }
        }
    }

    var id: UUID
    var name: String
    var type: AccountType
    var initialBalance: Decimal
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        name: String,
        type: AccountType,
        initialBalance: Decimal = 0,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case initialBalance
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyTimestamp = Date(timeIntervalSince1970: 0)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(AccountType.self, forKey: .type)
        initialBalance = try container.decodeIfPresent(Decimal.self, forKey: .initialBalance) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? legacyTimestamp
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}
