import Foundation

struct MonthlySummary: Equatable {
    let income: Decimal
    let expense: Decimal

    var balance: Decimal {
        income - expense
    }
}

struct DailyTotal: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let total: Decimal
}

struct CategoryTotal: Identifiable, Equatable {
    var id: UUID { category.id }
    let category: Category
    let total: Decimal
}

struct TransactionDaySection: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let transactions: [Transaction]

    var totalExpense: Decimal {
        transactions.filter { $0.type == .expense }.reduce(Decimal(0)) { $0 + $1.amount }
    }
}

