import Foundation

struct MonthlySummary: Equatable {
    let income: Decimal
    let expense: Decimal

    var balance: Decimal {
        income - expense
    }
}

struct AccountBalance: Identifiable, Equatable {
    var id: UUID { account.id }
    let account: Account
    let balance: Decimal
}

struct BudgetUsage: Identifiable, Equatable {
    var id: UUID { budget.id }
    let budget: Budget
    let spent: Decimal

    var remaining: Decimal {
        budget.limit - spent
    }

    var progress: Double {
        let limitDouble = NSDecimalNumber(decimal: budget.limit).doubleValue
        guard limitDouble > 0 else { return 0 }
        let spentDouble = NSDecimalNumber(decimal: spent).doubleValue
        return min(max(spentDouble / limitDouble, 0), 2)
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
