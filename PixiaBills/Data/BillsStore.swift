import Foundation

@MainActor
final class BillsStore: ObservableObject {
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var budgets: [Budget] = []
    @Published private(set) var transfers: [Transfer] = []
    @Published private(set) var recurringTransactions: [RecurringTransaction] = []
    @Published private(set) var iCloudSyncStatus: String = "未开启"
    @Published private(set) var iCloudLastSyncedAt: Date?

    private let transactionsStore = JSONFileStore(filename: "transactions.json")
    private let categoriesStore = JSONFileStore(filename: "categories.json")
    private let accountsStore = JSONFileStore(filename: "accounts.json")
    private let budgetsStore = JSONFileStore(filename: "budgets.json")
    private let transfersStore = JSONFileStore(filename: "transfers.json")
    private let recurringTransactionsStore = JSONFileStore(filename: "recurring-transactions.json")

    private enum ICloudKeys {
        static let snapshot = "pixia-bills.snapshot.v1"
    }

    private struct ICloudSnapshot: Codable {
        let syncedAt: Date
        let transactions: [Transaction]
        let categories: [Category]
        let accounts: [Account]
        let budgets: [Budget]
        let transfers: [Transfer]
        let recurringTransactions: [RecurringTransaction]
    }

    private var iCloudSyncEnabled = false
    private var isApplyingICloudSnapshot = false
    private var iCloudObserver: NSObjectProtocol?

    init() {
        load()
    }

    deinit {
        stopObservingICloud()
    }

    var defaultAccountId: UUID {
        accounts.first?.id ?? DefaultData.accounts[0].id
    }

    func load() {
        transactions = transactionsStore.load([Transaction].self, default: [])
        categories = categoriesStore.load([Category].self, default: DefaultData.categories)
        accounts = accountsStore.load([Account].self, default: DefaultData.accounts)
        budgets = budgetsStore.load([Budget].self, default: [])
        transfers = transfersStore.load([Transfer].self, default: [])
        recurringTransactions = recurringTransactionsStore.load([RecurringTransaction].self, default: [])

        if categories.isEmpty {
            categories = DefaultData.categories
            persistCategories()
        }
        if accounts.isEmpty {
            accounts = DefaultData.accounts
            persistAccounts()
        }

        ensureBuiltInAccounts()
        applyRecurringTransactionsIfNeeded()
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        iCloudSyncEnabled = enabled

        if enabled {
            iCloudSyncStatus = "同步中"
            startObservingICloudIfNeeded()
            _ = NSUbiquitousKeyValueStore.default.synchronize()

            let hasLocalData = hasUserGeneratedData()
            let pulled = pullSnapshotFromICloud(force: !hasLocalData)
            if !pulled {
                pushSnapshotToICloud()
            }
            iCloudSyncStatus = "已开启"
        } else {
            stopObservingICloud()
            iCloudSyncStatus = "未开启"
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

    @discardableResult
    func importTransactionsFromLLM(_ drafts: [LLMImportedTransactionDraft]) -> Int {
        guard !drafts.isEmpty else { return 0 }

        var imported = 0
        var categoryChanged = false
        var accountChanged = false
        let now = Date()

        for draft in drafts {
            let normalizedType = draft.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let type = TransactionType(rawValue: normalizedType) else { continue }
            guard let amount = DecimalParser.parse(draft.amount), amount > 0 else { continue }

            let category = resolveCategory(
                name: draft.categoryName,
                type: type,
                didCreate: &categoryChanged
            )
            let account = resolveAccount(name: draft.accountName, didCreate: &accountChanged)

            let transaction = Transaction(
                id: UUID(),
                type: type,
                amount: amount,
                date: parseLLMDate(text: draft.dateText) ?? now,
                categoryId: category.id,
                accountId: account.id,
                note: draft.note.nilIfEmpty,
                createdAt: now,
                updatedAt: now
            )
            transactions.insert(transaction, at: 0)
            imported += 1
        }

        if categoryChanged {
            persistCategories()
        }
        if accountChanged {
            persistAccounts()
        }
        if imported > 0 {
            persistTransactions()
        }

        return imported
    }

    func addAccount(name: String, type: Account.AccountType, initialBalance: Decimal) {
        let account = Account(
            id: UUID(),
            name: name,
            type: type,
            initialBalance: initialBalance
        )
        accounts.append(account)
        persistAccounts()
    }

    func updateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        persistAccounts()
    }

    func deleteAccounts(at offsets: IndexSet) {
        let ids: [UUID] = offsets.compactMap { index in
            guard accounts.indices.contains(index) else { return nil }
            return accounts[index].id
        }
        deleteAccounts(ids: ids)
    }

    func deleteAccounts(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let usedIds = Set(
            transactions.map(\.accountId) +
            transfers.flatMap { [$0.fromAccountId, $0.toAccountId] } +
            recurringTransactions.map(\.accountId)
        )

        let validDelete = ids.filter { id in
            id != defaultAccountId && !usedIds.contains(id)
        }
        guard !validDelete.isEmpty else { return }

        let idSet = Set(validDelete)
        accounts.removeAll(where: { idSet.contains($0.id) })
        persistAccounts()
    }

    func account(for id: UUID) -> Account? {
        accounts.first(where: { $0.id == id })
    }

    func accountBalances() -> [AccountBalance] {
        accounts
            .map { account in
                let accountTransactions = transactions.filter { $0.accountId == account.id }
                var balance = account.initialBalance
                for transaction in accountTransactions {
                    switch transaction.type {
                    case .income:
                        balance += transaction.amount
                    case .expense:
                        balance -= transaction.amount
                    }
                }

                let accountTransfers = transfers.filter {
                    $0.fromAccountId == account.id || $0.toAccountId == account.id
                }
                for transfer in accountTransfers {
                    if transfer.fromAccountId == account.id {
                        balance -= transfer.amount
                    }
                    if transfer.toAccountId == account.id {
                        balance += transfer.amount
                    }
                }

                return AccountBalance(account: account, balance: balance)
            }
            .sorted(by: { $0.balance > $1.balance })
    }

    func addTransfer(fromAccountId: UUID, toAccountId: UUID, amount: Decimal, date: Date, note: String?) {
        guard fromAccountId != toAccountId, amount > 0 else { return }
        guard account(for: fromAccountId) != nil, account(for: toAccountId) != nil else { return }

        let now = Date()
        let transfer = Transfer(
            id: UUID(),
            amount: amount,
            date: date,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            note: note?.nilIfEmpty,
            createdAt: now,
            updatedAt: now
        )
        transfers.insert(transfer, at: 0)
        persistTransfers()
    }

    func deleteTransfers(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        transfers.removeAll(where: { idSet.contains($0.id) })
        persistTransfers()
    }

    func transfers(inMonth month: Date) -> [Transfer] {
        let range = Calendar.current.monthDateInterval(containing: month)
        return transfers.filter { range.contains($0.date) }.sorted(by: { $0.date > $1.date })
    }

    func upsertBudget(month: Date, type: TransactionType, categoryId: UUID?, limit: Decimal) {
        guard limit > 0 else { return }
        let start = month.startOfDay()
        if let index = budgets.firstIndex(where: {
            Calendar.current.isDate($0.month, equalTo: start, toGranularity: .month) &&
            $0.type == type &&
            $0.categoryId == categoryId
        }) {
            budgets[index].limit = limit
            budgets[index].updatedAt = Date()
        } else {
            let now = Date()
            budgets.append(
                Budget(
                    id: UUID(),
                    month: start,
                    type: type,
                    categoryId: categoryId,
                    limit: limit,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }
        persistBudgets()
    }

    func deleteBudget(_ budget: Budget) {
        budgets.removeAll(where: { $0.id == budget.id })
        persistBudgets()
    }

    func budgetUsages(inMonth month: Date, type: TransactionType) -> [BudgetUsage] {
        let monthBudgets = budgets
            .filter { Calendar.current.isDate($0.month, equalTo: month, toGranularity: .month) && $0.type == type }

        guard !monthBudgets.isEmpty else { return [] }
        let monthTransactions = transactions(inMonth: month).filter { $0.type == type }

        return monthBudgets
            .map { budget in
                let spent: Decimal
                if let categoryId = budget.categoryId {
                    spent = monthTransactions
                        .filter { $0.categoryId == categoryId }
                        .reduce(Decimal(0)) { $0 + $1.amount }
                } else {
                    spent = monthTransactions.reduce(Decimal(0)) { $0 + $1.amount }
                }
                return BudgetUsage(budget: budget, spent: spent)
            }
            .sorted(by: { $0.budget.limit > $1.budget.limit })
    }

    func addRecurringTransaction(
        type: TransactionType,
        amount: Decimal,
        categoryId: UUID,
        accountId: UUID,
        note: String?,
        frequency: RecurringTransaction.Frequency,
        startDate: Date,
        endDate: Date?
    ) {
        guard amount > 0 else { return }
        guard category(for: categoryId)?.type == type else { return }
        guard account(for: accountId) != nil else { return }

        let now = Date()
        let recurring = RecurringTransaction(
            id: UUID(),
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            note: note?.nilIfEmpty,
            frequency: frequency,
            startDate: startDate,
            endDate: endDate,
            lastGeneratedAt: nil,
            isEnabled: true,
            createdAt: now,
            updatedAt: now
        )
        recurringTransactions.append(recurring)
        persistRecurringTransactions()
        applyRecurringTransactionsIfNeeded()
    }

    func toggleRecurringTransaction(_ recurring: RecurringTransaction, isEnabled: Bool) {
        guard let index = recurringTransactions.firstIndex(where: { $0.id == recurring.id }) else { return }
        recurringTransactions[index].isEnabled = isEnabled
        recurringTransactions[index].updatedAt = Date()
        persistRecurringTransactions()

        if isEnabled {
            applyRecurringTransactionsIfNeeded()
        }
    }

    func deleteRecurringTransactions(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        recurringTransactions.removeAll(where: { idSet.contains($0.id) })
        persistRecurringTransactions()
    }

    func deleteTransactions(at offsets: IndexSet) {
        let ids: [UUID] = offsets.compactMap { index in
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

    func categoryName(for categoryId: UUID?) -> String {
        guard let categoryId else { return "全部分类" }
        return category(for: categoryId)?.name ?? "未知分类"
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
        pushSnapshotToICloudIfNeeded()
    }

    private func persistCategories() {
        categoriesStore.save(categories)
        pushSnapshotToICloudIfNeeded()
    }

    private func persistAccounts() {
        accountsStore.save(accounts)
        pushSnapshotToICloudIfNeeded()
    }

    private func persistBudgets() {
        budgetsStore.save(budgets)
        pushSnapshotToICloudIfNeeded()
    }

    private func persistTransfers() {
        transfersStore.save(transfers)
        pushSnapshotToICloudIfNeeded()
    }

    private func persistRecurringTransactions() {
        recurringTransactionsStore.save(recurringTransactions)
        pushSnapshotToICloudIfNeeded()
    }

    private func ensureBuiltInAccounts() {
        let existing = Set(accounts.map(\.id))
        var changed = false
        for account in DefaultData.accounts where !existing.contains(account.id) {
            accounts.append(account)
            changed = true
        }

        if changed {
            persistAccounts()
        }
    }

    private func applyRecurringTransactionsIfNeeded(referenceDate: Date = Date()) {
        guard !recurringTransactions.isEmpty else { return }
        var transactionsChanged = false
        var recurringChanged = false
        let calendar = Calendar.current

        for index in recurringTransactions.indices {
            var recurring = recurringTransactions[index]
            guard recurring.isEnabled else { continue }

            let start = recurring.startDate.startOfDay(using: calendar)
            if let endDate = recurring.endDate, start > endDate {
                continue
            }

            let firstTarget: Date
            if let last = recurring.lastGeneratedAt {
                firstTarget = nextDate(after: last, frequency: recurring.frequency, calendar: calendar)
            } else {
                firstTarget = start
            }

            var cursor = firstTarget
            var lastGeneratedDate: Date?
            var didGenerate = false
            while cursor <= referenceDate {
                if let endDate = recurring.endDate, cursor > endDate {
                    break
                }

                if !hasTransactionGenerated(by: recurring.id, on: cursor, calendar: calendar) {
                    let generatedNote = [recurring.note, "[周期:", recurring.id.uuidString, "]"]
                        .compactMap { $0 }
                        .joined(separator: "")

                    let transaction = Transaction(
                        id: UUID(),
                        type: recurring.type,
                        amount: recurring.amount,
                        date: cursor,
                        categoryId: recurring.categoryId,
                        accountId: recurring.accountId,
                        note: generatedNote.nilIfEmpty,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    transactions.insert(transaction, at: 0)
                    transactionsChanged = true
                    didGenerate = true
                    lastGeneratedDate = cursor
                }
                cursor = nextDate(after: cursor, frequency: recurring.frequency, calendar: calendar)
            }

            if didGenerate, let lastGeneratedDate {
                recurring.lastGeneratedAt = lastGeneratedDate
                recurring.updatedAt = Date()
                recurringTransactions[index] = recurring
                recurringChanged = true
            }
        }

        if transactionsChanged {
            persistTransactions()
        }
        if recurringChanged {
            persistRecurringTransactions()
        }
    }

    private func nextDate(after date: Date, frequency: RecurringTransaction.Frequency, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let value: Int
        switch frequency {
        case .daily:
            component = .day
            value = 1
        case .weekly:
            component = .weekOfYear
            value = 1
        case .monthly:
            component = .month
            value = 1
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }

    private func hasTransactionGenerated(by recurringId: UUID, on date: Date, calendar: Calendar) -> Bool {
        let marker = "[周期:\(recurringId.uuidString)]"
        return transactions.contains(where: {
            calendar.isDate($0.date, inSameDayAs: date) && ($0.note?.contains(marker) ?? false)
        })
    }

    private func hasUserGeneratedData() -> Bool {
        !transactions.isEmpty || !budgets.isEmpty || !transfers.isEmpty || !recurringTransactions.isEmpty
    }

    private func resolveCategory(name: String, type: TransactionType, didCreate: inout Bool) -> Category {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let existing = categories.first(where: {
                $0.type == type && $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
            }) {
                return existing
            }

            let nextOrder = (categories(ofType: type).map { $0.sortOrder }.max() ?? 0) + 1
            let newCategory = Category(
                id: UUID(),
                type: type,
                name: trimmed,
                iconName: defaultIconName(for: type),
                sortOrder: nextOrder,
                isDefault: false
            )
            categories.append(newCategory)
            didCreate = true
            return newCategory
        }

        if let fallback = categories(ofType: type).first {
            return fallback
        }

        let fallbackCategory = Category(
            id: UUID(),
            type: type,
            name: type == .expense ? "未分类支出" : "未分类收入",
            iconName: defaultIconName(for: type),
            sortOrder: 0,
            isDefault: false
        )
        categories.append(fallbackCategory)
        didCreate = true
        return fallbackCategory
    }

    private func resolveAccount(name: String, didCreate: inout Bool) -> Account {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let existing = accounts.first(where: { $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame }) {
                return existing
            }

            let account = Account(id: UUID(), name: trimmed, type: .cash, initialBalance: 0)
            accounts.append(account)
            didCreate = true
            return account
        }

        return accounts.first ?? DefaultData.accounts[0]
    }

    private func parseLLMDate(text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = full.date(from: trimmed) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: trimmed) {
            return date
        }

        return DateFormatter.dayTitle.date(from: trimmed)
    }

    private func defaultIconName(for type: TransactionType) -> String {
        switch type {
        case .income:
            return "banknote"
        case .expense:
            return "cart"
        }
    }

    private func pushSnapshotToICloudIfNeeded() {
        guard iCloudSyncEnabled else { return }
        guard !isApplyingICloudSnapshot else { return }
        pushSnapshotToICloud()
    }

    private func pushSnapshotToICloud() {
        guard iCloudSyncEnabled else { return }

        let snapshot = ICloudSnapshot(
            syncedAt: Date(),
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            budgets: budgets,
            transfers: transfers,
            recurringTransactions: recurringTransactions
        )

        do {
            let data = try JSONEncoder.appEncoder.encode(snapshot)
            let store = NSUbiquitousKeyValueStore.default
            store.set(data, forKey: ICloudKeys.snapshot)
            store.synchronize()
            iCloudLastSyncedAt = Date()
            iCloudSyncStatus = "已开启"
        } catch {
            iCloudSyncStatus = "同步失败"
        }
    }

    @discardableResult
    private func pullSnapshotFromICloud(force: Bool) -> Bool {
        let store = NSUbiquitousKeyValueStore.default
        guard let data = store.data(forKey: ICloudKeys.snapshot) else { return false }

        do {
            let snapshot = try JSONDecoder.appDecoder.decode(ICloudSnapshot.self, from: data)
            if !force, hasUserGeneratedData() {
                return false
            }
            applyICloudSnapshot(snapshot)
            return true
        } catch {
            iCloudSyncStatus = "同步失败"
            return false
        }
    }

    private func applyICloudSnapshot(_ snapshot: ICloudSnapshot) {
        isApplyingICloudSnapshot = true
        defer { isApplyingICloudSnapshot = false }

        transactions = snapshot.transactions
        categories = snapshot.categories.isEmpty ? DefaultData.categories : snapshot.categories
        accounts = snapshot.accounts.isEmpty ? DefaultData.accounts : snapshot.accounts
        budgets = snapshot.budgets
        transfers = snapshot.transfers
        recurringTransactions = snapshot.recurringTransactions

        ensureBuiltInAccounts()

        transactionsStore.save(transactions)
        categoriesStore.save(categories)
        accountsStore.save(accounts)
        budgetsStore.save(budgets)
        transfersStore.save(transfers)
        recurringTransactionsStore.save(recurringTransactions)

        iCloudLastSyncedAt = snapshot.syncedAt
        iCloudSyncStatus = "已开启"
    }

    private func startObservingICloudIfNeeded() {
        guard iCloudObserver == nil else { return }

        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.pullSnapshotFromICloud(force: true)
        }
    }

    private func stopObservingICloud() {
        if let observer = iCloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        iCloudObserver = nil
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
