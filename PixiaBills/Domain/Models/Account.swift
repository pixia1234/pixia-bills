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

    init(id: UUID, name: String, type: AccountType, initialBalance: Decimal = 0) {
        self.id = id
        self.name = name
        self.type = type
        self.initialBalance = initialBalance
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case initialBalance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(AccountType.self, forKey: .type)
        initialBalance = try container.decodeIfPresent(Decimal.self, forKey: .initialBalance) ?? 0
    }
}
