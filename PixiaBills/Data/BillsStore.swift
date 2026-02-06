import Foundation

@MainActor
final class BillsStore: ObservableObject {
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var accounts: [Account] = []

    private let transactionsStore = JSONFileStore(filename: "transactions.json")
    private let categoriesStore = JSONFileStore(filename: "categories.json")
    private let accountsStore = JSONFileStore(filename: "accounts.json")

    init() {
        load()
    }

    var defaultAccountId: UUID {
        accounts.first?.id ?? DefaultData.accounts[0].id
    }

    func load() {
        transactions = transactionsStore.load([Transaction].self, default: [])
        categories = categoriesStore.load([Category].self, default: DefaultData.categories)
        accounts = accountsStore.load([Account].self, default: DefaultData.accounts)

        if categories.isEmpty {
            categories = DefaultData.categories
            persistCategories()
        }
        if accounts.isEmpty {
            accounts = DefaultData.accounts
            persistAccounts()
        }
    }

    func addTransaction(
        type: TransactionType,
        amount: Decimal,
        date: Date,
        categoryId: UUID,
        accountId: UUID,
        note: String?
    ) {
        let now = Date()
        let transaction = Transaction(
            id: UUID(),
            type: type,
            amount: amount,
            date: date,
            categoryId: categoryId,
            accountId: accountId,
            note: note?.nilIfEmpty,
            createdAt: now,
            updatedAt: now
        )
        transactions.insert(transaction, at: 0)
        persistTransactions()
    }

    func deleteTransactions(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            guard transactions.indices.contains(index) else { return nil }
            return transactions[index].id
        }
        deleteTransactions(ids: ids)
    }

    func deleteTransactions(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        transactions.removeAll(where: { idSet.contains($0.id) })
        persistTransactions()
    }

    func transactions(inMonth month: Date) -> [Transaction] {
        let range = Calendar.current.monthDateInterval(containing: month)
        return transactions.filter { range.contains($0.date) }
    }

    func transactions(onDay day: Date) -> [Transaction] {
        let calendar = Calendar.current
        return transactions.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func daySections(inMonth month: Date) -> [TransactionDaySection] {
        let calendar = Calendar.current
        let monthTransactions = transactions(inMonth: month)
        let grouped = Dictionary(grouping: monthTransactions) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { day, txs in
                TransactionDaySection(date: day, transactions: txs.sorted(by: { $0.date > $1.date }))
            }
            .sorted(by: { $0.date > $1.date })
    }

    func monthlySummary(for month: Date) -> MonthlySummary {
        let monthTransactions = transactions(inMonth: month)
        var income: Decimal = 0
        var expense: Decimal = 0

        for transaction in monthTransactions {
            switch transaction.type {
            case .income:
                income += transaction.amount
            case .expense:
                expense += transaction.amount
            }
        }
        return MonthlySummary(income: income, expense: expense)
    }

    func categories(ofType type: TransactionType) -> [Category] {
        categories
            .filter { $0.type == type }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    func category(for id: UUID) -> Category? {
        categories.first(where: { $0.id == id })
    }

    func addCategory(type: TransactionType, name: String, iconName: String) {
        let nextOrder = (categories(ofType: type).map { $0.sortOrder }.max() ?? 0) + 1
        let category = Category(
            id: UUID(),
            type: type,
            name: name,
            iconName: iconName,
            sortOrder: nextOrder,
            isDefault: false
        )
        categories.append(category)
        persistCategories()
    }

    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        persistCategories()
    }

    func deleteCategories(at offsets: IndexSet, type: TransactionType) {
        let ids = categories(ofType: type).enumerated().compactMap { offsets.contains($0.offset) ? $0.element.id : nil }
        categories.removeAll(where: { ids.contains($0.id) })
        persistCategories()
    }

    func moveCategories(from source: IndexSet, to destination: Int, type: TransactionType) {
        var typed = categories(ofType: type)
        moveItems(&typed, from: source, to: destination)

        let orderById = Dictionary(uniqueKeysWithValues: typed.enumerated().map { ($1.id, $0) })
        categories = categories.map { category in
            guard category.type == type, let order = orderById[category.id] else { return category }
            return category.with(sortOrder: order)
        }
        persistCategories()
    }

    func dailyTotals(inMonth month: Date, type: TransactionType) -> [DailyTotal] {
        let calendar = Calendar.current
        let days = calendar.daysInMonth(containing: month)
        let monthTransactions = transactions(inMonth: month).filter { $0.type == type }
        let grouped = Dictionary(grouping: monthTransactions) { calendar.startOfDay(for: $0.date) }

        return days.map { day in
            let total = grouped[day, default: []].reduce(Decimal(0)) { $0 + $1.amount }
            return DailyTotal(date: day, total: total)
        }
    }

    func categoryTotals(inMonth month: Date, type: TransactionType) -> [CategoryTotal] {
        let monthTransactions = transactions(inMonth: month).filter { $0.type == type }
        let grouped = Dictionary(grouping: monthTransactions, by: { $0.categoryId })

        return grouped
            .compactMap { categoryId, txs -> CategoryTotal? in
                guard let category = category(for: categoryId) else { return nil }
                let total = txs.reduce(Decimal(0)) { $0 + $1.amount }
                return CategoryTotal(category: category, total: total)
            }
            .sorted(by: { $0.total > $1.total })
    }

    func topTransactions(inMonth month: Date, type: TransactionType, count: Int = 3) -> [Transaction] {
        transactions(inMonth: month)
            .filter { $0.type == type }
            .sorted(by: { $0.amount > $1.amount })
            .prefix(count)
            .map { $0 }
    }

    func exportTransactionsCSV() throws -> URL {
        let iso = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("id,type,amount,date,category,account,note")

        let sorted = transactions.sorted(by: { $0.date < $1.date })
        for tx in sorted {
            let categoryName = category(for: tx.categoryId)?.name ?? ""
            let accountName = accounts.first(where: { $0.id == tx.accountId })?.name ?? ""
            let note = (tx.note ?? "").csvEscaped
            let fields = [
                tx.id.uuidString,
                tx.type.rawValue,
                tx.amount.plainString,
                iso.string(from: tx.date),
                categoryName.csvEscaped,
                accountName.csvEscaped,
                note
            ]
            lines.append(fields.joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n") + "\n"
        let filename = "pixia-bills-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func persistTransactions() {
        transactionsStore.save(transactions)
    }

    private func persistCategories() {
        categoriesStore.save(categories)
    }

    private func persistAccounts() {
        accountsStore.save(accounts)
    }

    private func moveItems<T>(_ array: inout [T], from source: IndexSet, to destination: Int) {
        let sourceIndexes = source.filter { array.indices.contains($0) }.sorted()
        guard !sourceIndexes.isEmpty else { return }

        let items = sourceIndexes.map { array[$0] }
        for index in sourceIndexes.reversed() {
            array.remove(at: index)
        }

        let adjustedDestination = destination - sourceIndexes.filter { $0 < destination }.count
        let insertIndex = max(0, min(adjustedDestination, array.count))
        array.insert(contentsOf: items, at: insertIndex)
    }
}
