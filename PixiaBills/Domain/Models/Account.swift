import Foundation

struct Account: Identifiable, Codable, Equatable {
    enum AccountType: String, Codable, CaseIterable {
        case cash
        case bank
        case credit
    }

    var id: UUID
    var name: String
    var type: AccountType
}

