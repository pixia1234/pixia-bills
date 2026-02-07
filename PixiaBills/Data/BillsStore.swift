import Foundation
import CryptoKit

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
    @Published private(set) var iCloudSyncLogs: [ICloudSyncLog] = []

    private let transactionsStore = JSONFileStore(filename: "transactions.json")
    private let categoriesStore = JSONFileStore(filename: "categories.json")
    private let accountsStore = JSONFileStore(filename: "accounts.json")
    private let budgetsStore = JSONFileStore(filename: "budgets.json")
    private let transfersStore = JSONFileStore(filename: "transfers.json")
    private let recurringTransactionsStore = JSONFileStore(filename: "recurring-transactions.json")
    private let deletedCategoryMarkersStore = JSONFileStore(filename: "deleted-category-markers.json")
    private let deletedAccountMarkersStore = JSONFileStore(filename: "deleted-account-markers.json")

    private struct EntityDeletionMarker: Codable, Equatable {
        let id: UUID
        let deletedAt: Date
    }

    private struct ICloudSnapshot: Codable {
        let syncedAt: Date
        let transactions: [Transaction]
        let categories: [Category]
        let accounts: [Account]
        let budgets: [Budget]
        let transfers: [Transfer]
        let recurringTransactions: [RecurringTransaction]
        let deletedCategoryMarkers: [EntityDeletionMarker]
        let deletedAccountMarkers: [EntityDeletionMarker]

        init(
            syncedAt: Date,
            transactions: [Transaction],
            categories: [Category],
            accounts: [Account],
            budgets: [Budget],
            transfers: [Transfer],
            recurringTransactions: [RecurringTransaction],
            deletedCategoryMarkers: [EntityDeletionMarker] = [],
            deletedAccountMarkers: [EntityDeletionMarker] = []
        ) {
            self.syncedAt = syncedAt
            self.transactions = transactions
            self.categories = categories
            self.accounts = accounts
            self.budgets = budgets
            self.transfers = transfers
            self.recurringTransactions = recurringTransactions
            self.deletedCategoryMarkers = deletedCategoryMarkers
            self.deletedAccountMarkers = deletedAccountMarkers
        }

        private enum CodingKeys: String, CodingKey {
            case syncedAt
            case transactions
            case categories
            case accounts
            case budgets
            case transfers
            case recurringTransactions
            case deletedCategoryMarkers
            case deletedAccountMarkers
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            syncedAt = try container.decode(Date.self, forKey: .syncedAt)
            transactions = try container.decode([Transaction].self, forKey: .transactions)
            categories = try container.decode([Category].self, forKey: .categories)
            accounts = try container.decode([Account].self, forKey: .accounts)
            budgets = try container.decode([Budget].self, forKey: .budgets)
            transfers = try container.decode([Transfer].self, forKey: .transfers)
            recurringTransactions = try container.decode([RecurringTransaction].self, forKey: .recurringTransactions)
            deletedCategoryMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedCategoryMarkers) ?? []
            deletedAccountMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedAccountMarkers) ?? []
        }
    }

    private struct WebDAVSnapshotManifest: Codable {
        let version: Int
        let syncedAt: Date
        let transactionChunkSize: Int
        let totalTransactions: Int
        let transactionChunkFileNames: [String]
        let categories: [Category]
        let accounts: [Account]
        let budgets: [Budget]
        let transfers: [Transfer]
        let recurringTransactions: [RecurringTransaction]
        let deletedCategoryMarkers: [EntityDeletionMarker]
        let deletedAccountMarkers: [EntityDeletionMarker]

        init(
            version: Int,
            syncedAt: Date,
            transactionChunkSize: Int,
            totalTransactions: Int,
            transactionChunkFileNames: [String],
            categories: [Category],
            accounts: [Account],
            budgets: [Budget],
            transfers: [Transfer],
            recurringTransactions: [RecurringTransaction],
            deletedCategoryMarkers: [EntityDeletionMarker] = [],
            deletedAccountMarkers: [EntityDeletionMarker] = []
        ) {
            self.version = version
            self.syncedAt = syncedAt
            self.transactionChunkSize = transactionChunkSize
            self.totalTransactions = totalTransactions
            self.transactionChunkFileNames = transactionChunkFileNames
            self.categories = categories
            self.accounts = accounts
            self.budgets = budgets
            self.transfers = transfers
            self.recurringTransactions = recurringTransactions
            self.deletedCategoryMarkers = deletedCategoryMarkers
            self.deletedAccountMarkers = deletedAccountMarkers
        }

        private enum CodingKeys: String, CodingKey {
            case version
            case syncedAt
            case transactionChunkSize
            case totalTransactions
            case transactionChunkFileNames
            case categories
            case accounts
            case budgets
            case transfers
            case recurringTransactions
            case deletedCategoryMarkers
            case deletedAccountMarkers
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decode(Int.self, forKey: .version)
            syncedAt = try container.decode(Date.self, forKey: .syncedAt)
            transactionChunkSize = try container.decode(Int.self, forKey: .transactionChunkSize)
            totalTransactions = try container.decode(Int.self, forKey: .totalTransactions)
            transactionChunkFileNames = try container.decode([String].self, forKey: .transactionChunkFileNames)
            categories = try container.decode([Category].self, forKey: .categories)
            accounts = try container.decode([Account].self, forKey: .accounts)
            budgets = try container.decode([Budget].self, forKey: .budgets)
            transfers = try container.decode([Transfer].self, forKey: .transfers)
            recurringTransactions = try container.decode([RecurringTransaction].self, forKey: .recurringTransactions)
            deletedCategoryMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedCategoryMarkers) ?? []
            deletedAccountMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedAccountMarkers) ?? []
        }
    }

    private struct WebDAVTransactionChunk: Codable {
        let version: Int
        let chunkIndex: Int
        let transactions: [Transaction]
    }

    private struct WebDAVSnapshotVersionRef {
        let version: Int
        let manifestFileName: String
    }

    private enum CSVImportError: LocalizedError {
        case invalidFormat

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "CSV 格式不正确，请使用应用导出的 CSV 文件"
            }
        }
    }


    private enum WebDAVSyncError: LocalizedError {
        case invalidConfiguration(String)
        case encryptionFailed
        case decryptionFailed
        case emptyRemotePayload
        case snapshotNotFound
        case invalidSnapshotFormat(String)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration(let message):
                return message
            case .encryptionFailed:
                return "数据加密失败，请检查加密密钥"
            case .decryptionFailed:
                return "数据解密失败，请确认加密密钥是否一致"
            case .emptyRemotePayload:
                return "云端文件为空"
            case .snapshotNotFound:
                return "云端不存在可用快照"
            case .invalidSnapshotFormat(let message):
                return message
            }
        }
    }

    struct ICloudSyncLog: Identifiable {
        let id = UUID()
        let date: Date
        let message: String
    }

    private enum ICloudPullMode {
        case replaceLocal
        case mergeWithLocal
    }

    private var iCloudSyncEnabled = false
    private var isApplyingICloudSnapshot = false
    private var webDAVConfiguration = WebDAVSyncConfiguration()
    private let webDAVClient = WebDAVClient()

    private var webDAVAutoSyncTask: Task<Void, Never>?
    private var webDAVAutoSyncToken = UUID()
    private var webDAVAutoSyncTrigger: String?
    private var webDAVAutoSyncDebounceNanoseconds: UInt64 = 900_000_000
    private var webDAVHasPendingLocalChanges = false

    private var deletedCategoryMarkers: [EntityDeletionMarker] = []
    private var deletedAccountMarkers: [EntityDeletionMarker] = []

    private let webDAVSyncProgressDefaults = UserDefaults.standard
    private let webDAVSyncProgressStorageKey = "sync.webdav.last_processed_manifest_versions"

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
        budgets = budgetsStore.load([Budget].self, default: [])
        transfers = transfersStore.load([Transfer].self, default: [])
        recurringTransactions = recurringTransactionsStore.load([RecurringTransaction].self, default: [])
        deletedCategoryMarkers = deletedCategoryMarkersStore.load([EntityDeletionMarker].self, default: [])
        deletedAccountMarkers = deletedAccountMarkersStore.load([EntityDeletionMarker].self, default: [])

        let categoryResolution = resolveEntitiesAgainstDeletionMarkers(
            categories,
            markers: deletedCategoryMarkers,
            updatedAt: \.updatedAt
        )
        categories = categoryResolution.entities
        deletedCategoryMarkers = categoryResolution.markers

        let accountResolution = resolveEntitiesAgainstDeletionMarkers(
            accounts,
            markers: deletedAccountMarkers,
            updatedAt: \.updatedAt
        )
        accounts = accountResolution.entities
        deletedAccountMarkers = accountResolution.markers

        if categories.isEmpty {
            let fallback = resolveEntitiesAgainstDeletionMarkers(
                DefaultData.categories,
                markers: deletedCategoryMarkers,
                updatedAt: \.updatedAt
            )
            categories = fallback.entities
            deletedCategoryMarkers = fallback.markers
            persistCategories()
        }
        if accounts.isEmpty {
            let fallback = resolveEntitiesAgainstDeletionMarkers(
                DefaultData.accounts,
                markers: deletedAccountMarkers,
                updatedAt: \.updatedAt
            )
            accounts = fallback.entities
            deletedAccountMarkers = fallback.markers

            if accounts.isEmpty {
                accounts = [Account(id: UUID(), name: "现金", type: .cash, initialBalance: 0)]
            }
            persistAccounts()
        }

        persistDeletionMarkers(scheduleSync: false)

        ensureBuiltInAccounts()
        applyRecurringTransactionsIfNeeded()
    }

    func updateWebDAVConfiguration(_ configuration: WebDAVSyncConfiguration) {
        webDAVConfiguration = configuration
    }

    func requestAutoWebDAVSync(
        trigger: String = "自动同步",
        debounceNanoseconds: UInt64 = 900_000_000,
        markPendingLocalChanges: Bool = false
    ) {
        guard iCloudSyncEnabled else { return }
        guard !isApplyingICloudSnapshot else { return }

        if markPendingLocalChanges {
            webDAVHasPendingLocalChanges = true
        }

        webDAVAutoSyncTrigger = trigger
        webDAVAutoSyncDebounceNanoseconds = debounceNanoseconds
        webDAVAutoSyncToken = UUID()

        if webDAVAutoSyncTask == nil {
            webDAVAutoSyncTask = Task { @MainActor [weak self] in
                await self?.runWebDAVAutoSyncWorker()
            }
        }
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        if enabled {
            addICloudLog("开始启用 WebDAV 同步")
            iCloudSyncStatus = "检测中"

            guard verifyWebDAVConfiguration(logFailures: true) else {
                iCloudSyncEnabled = false
                return
            }

            iCloudSyncEnabled = true
            Task { @MainActor in
                await enableWebDAVSyncFlow()
            }
        } else {
            iCloudSyncEnabled = false
            webDAVHasPendingLocalChanges = false
            webDAVAutoSyncTrigger = nil
            webDAVAutoSyncTask?.cancel()
            webDAVAutoSyncTask = nil
            iCloudSyncStatus = "未开启"
            addICloudLog("已关闭 WebDAV 同步")
        }
    }

    func setICloudSyncEnabled(_ enabled: Bool, configuration: WebDAVSyncConfiguration) {
        updateWebDAVConfiguration(configuration)
        setICloudSyncEnabled(enabled)
    }

    @discardableResult
    func refreshICloudSyncStatusNow() async -> String {
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return "WebDAV 配置不完整，请先填写协议/地址/路径/加密密钥"
        }

        iCloudSyncEnabled = true
        guard let baseURL = webDAVConfiguration.baseURL else {
            iCloudSyncStatus = "配置不完整"
            addICloudLog("状态检查：WebDAV URL 无效")
            return "WebDAV URL 无效，请检查地址与路径"
        }

        do {
            try await webDAVClient.ping(directoryURL: baseURL, configuration: webDAVConfiguration)
            let refs = try await fetchRemoteSnapshotManifestRefs()

            iCloudSyncStatus = "已连接"
            if let latest = refs.last {
                addICloudLog("状态检查：WebDAV 连接正常，检测到 \(refs.count) 个快照版本（最新 v\(latest.version)）")
                return "WebDAV 连接正常，检测到 \(refs.count) 个快照版本（最新 v\(latest.version)）"
            }

            if (try? await loadLegacySnapshotIfExists()) != nil {
                addICloudLog("状态检查：仅检测到旧版单文件快照，首次同步会自动迁移")
                return "WebDAV 连接正常，仅检测到旧版单文件快照，首次同步会自动迁移"
            }

            addICloudLog("状态检查：WebDAV 连接正常，但云端暂无版本快照")
            return "WebDAV 连接正常，但云端暂无版本快照"
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("状态检查：WebDAV 连接失败（\(error.localizedDescription)）")
            return "WebDAV 连接失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func refreshICloudSyncStatusNow(configuration: WebDAVSyncConfiguration) async -> String {
        updateWebDAVConfiguration(configuration)
        return await refreshICloudSyncStatusNow()
    }

    @discardableResult
    func pullFromICloudNow() async -> String {
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return "WebDAV 配置不完整，请先填写协议/地址/路径/加密密钥"
        }

        iCloudSyncEnabled = true
        iCloudSyncStatus = "同步中"
        let success = await pullSnapshotFromICloud(mode: .mergeWithLocal, trigger: "手动拉取")
        return success ? "拉取成功，已按增量版本合并本地与云端数据" : "拉取失败，请查看同步日志"
    }

    @discardableResult
    func pullFromICloudNow(configuration: WebDAVSyncConfiguration) async -> String {
        updateWebDAVConfiguration(configuration)
        return await pullFromICloudNow()
    }

    @discardableResult
    func pushToICloudNow() async -> String {
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return "WebDAV 配置不完整，请先填写协议/地址/路径/加密密钥"
        }

        iCloudSyncEnabled = true
        iCloudSyncStatus = "同步中"
        let success = await pushSnapshotToICloud(trigger: "手动推送")
        if success {
            webDAVHasPendingLocalChanges = false
        }
        return success ? "推送成功，云端数据已更新" : "推送失败，请查看同步日志"
    }

    @discardableResult
    func pushToICloudNow(configuration: WebDAVSyncConfiguration) async -> String {
        updateWebDAVConfiguration(configuration)
        return await pushToICloudNow()
    }

    func clearICloudSyncLogs() {
        iCloudSyncLogs.removeAll()
    }

    private func enableWebDAVSyncFlow() async {
        guard iCloudSyncEnabled else { return }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return
        }

        iCloudSyncStatus = "同步中"
        do {
            let hasRemote = try await remoteSnapshotExists()
            if hasRemote {
                webDAVHasPendingLocalChanges = hasUserGeneratedData()
                _ = await syncSnapshotWithWebDAV(trigger: "首次开启")
            } else {
                webDAVHasPendingLocalChanges = true
                _ = await pushSnapshotToICloud(trigger: "首次开启")
                webDAVHasPendingLocalChanges = false
            }
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("首次开启：WebDAV 连接失败（\(error.localizedDescription)）")
        }
    }

    private func runWebDAVAutoSyncWorker() async {
        defer {
            webDAVAutoSyncTask = nil
        }

        while iCloudSyncEnabled {
            guard verifyWebDAVConfiguration(logFailures: false) else {
                iCloudSyncStatus = "配置不完整"
                break
            }

            guard let trigger = webDAVAutoSyncTrigger else {
                break
            }

            let token = webDAVAutoSyncToken
            do {
                try await Task.sleep(nanoseconds: webDAVAutoSyncDebounceNanoseconds)
            } catch {
                break
            }

            if !iCloudSyncEnabled {
                break
            }

            if token != webDAVAutoSyncToken {
                continue
            }

            webDAVAutoSyncTrigger = nil
            _ = await syncSnapshotWithWebDAV(trigger: trigger)
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
        removeDeletionMarkers(matching: [account.id], from: &deletedAccountMarkers)
        persistAccounts()
        persistDeletionMarkers(scheduleSync: false)
    }

    func updateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }

        var updated = account
        updated.createdAt = accounts[index].createdAt
        updated.updatedAt = Date()

        accounts[index] = updated
        removeDeletionMarkers(matching: [account.id], from: &deletedAccountMarkers)
        persistAccounts()
        persistDeletionMarkers(scheduleSync: false)
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
        let now = Date()
        accounts.removeAll(where: { idSet.contains($0.id) })
        deletedAccountMarkers = mergeDeletionMarkers(
            deletedAccountMarkers,
            validDelete.map { EntityDeletionMarker(id: $0, deletedAt: now) }
        )
        persistAccounts()
        persistDeletionMarkers(scheduleSync: false)
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
        removeDeletionMarkers(matching: [category.id], from: &deletedCategoryMarkers)
        persistCategories()
        persistDeletionMarkers(scheduleSync: false)
    }

    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }

        var updated = category
        updated.createdAt = categories[index].createdAt
        updated.updatedAt = Date()

        categories[index] = updated
        removeDeletionMarkers(matching: [category.id], from: &deletedCategoryMarkers)
        persistCategories()
        persistDeletionMarkers(scheduleSync: false)
    }

    func deleteCategories(at offsets: IndexSet, type: TransactionType) {
        let ids = categories(ofType: type).enumerated().compactMap { offsets.contains($0.offset) ? $0.element.id : nil }
        guard !ids.isEmpty else { return }

        let now = Date()
        categories.removeAll(where: { ids.contains($0.id) })
        deletedCategoryMarkers = mergeDeletionMarkers(
            deletedCategoryMarkers,
            ids.map { EntityDeletionMarker(id: $0, deletedAt: now) }
        )
        persistCategories()
        persistDeletionMarkers(scheduleSync: false)
    }

    func moveCategories(from source: IndexSet, to destination: Int, type: TransactionType) {
        var typed = categories(ofType: type)
        moveItems(&typed, from: source, to: destination)

        let now = Date()

        let orderById = Dictionary(uniqueKeysWithValues: typed.enumerated().map { ($1.id, $0) })
        categories = categories.map { category in
            guard category.type == type, let order = orderById[category.id] else { return category }
            return category.with(sortOrder: order, updatedAt: now)
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

    @discardableResult
    func importTransactionsCSV(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let content = String(decoding: data, as: UTF8.self)
        let rows = parseCSVRecords(content)

        guard rows.count >= 2 else {
            throw CSVImportError.invalidFormat
        }

        let headers = rows[0].map {
            $0
                .replacingOccurrences(of: "\u{FEFF}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        guard let idIndex = headers.firstIndex(of: "id"),
              let typeIndex = headers.firstIndex(of: "type"),
              let amountIndex = headers.firstIndex(of: "amount"),
              let dateIndex = headers.firstIndex(of: "date"),
              let categoryIndex = headers.firstIndex(of: "category"),
              let accountIndex = headers.firstIndex(of: "account") else {
            throw CSVImportError.invalidFormat
        }

        let noteIndex = headers.firstIndex(of: "note")

        var importedCount = 0
        var categoryChanged = false
        var accountChanged = false
        var knownIds = Set(transactions.map(\.id))

        for row in rows.dropFirst() {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            let typeRaw = csvField(row, at: typeIndex).lowercased()
            guard let type = TransactionType(rawValue: typeRaw) else { continue }

            guard let amount = DecimalParser.parse(csvField(row, at: amountIndex)), amount > 0 else {
                continue
            }

            let categoryName = csvField(row, at: categoryIndex)
            let accountName = csvField(row, at: accountIndex)
            let note = noteIndex.map { csvField(row, at: $0) }.flatMap { $0.nilIfEmpty }
            let date = parseCSVDate(text: csvField(row, at: dateIndex)) ?? Date()

            let category = resolveCategory(name: categoryName, type: type, didCreate: &categoryChanged)
            let account = resolveAccount(name: accountName, didCreate: &accountChanged)

            let idText = csvField(row, at: idIndex)
            let id = UUID(uuidString: idText) ?? UUID()
            if knownIds.contains(id) {
                continue
            }
            knownIds.insert(id)

            let now = Date()
            let transaction = Transaction(
                id: id,
                type: type,
                amount: amount,
                date: date,
                categoryId: category.id,
                accountId: account.id,
                note: note,
                createdAt: now,
                updatedAt: now
            )
            transactions.insert(transaction, at: 0)
            importedCount += 1
        }

        if categoryChanged {
            persistCategories()
        }
        if accountChanged {
            persistAccounts()
        }
        if importedCount > 0 {
            persistTransactions()
        }

        return importedCount
    }

    private func persistTransactions() {
        transactionsStore.save(transactions)
        scheduleWebDAVSyncIfNeeded()
    }

    private func persistCategories() {
        categoriesStore.save(categories)
        scheduleWebDAVSyncIfNeeded()
    }

    private func persistAccounts() {
        accountsStore.save(accounts)
        scheduleWebDAVSyncIfNeeded()
    }

    private func persistBudgets() {
        budgetsStore.save(budgets)
        scheduleWebDAVSyncIfNeeded()
    }

    private func persistTransfers() {
        transfersStore.save(transfers)
        scheduleWebDAVSyncIfNeeded()
    }

    private func persistRecurringTransactions() {
        recurringTransactionsStore.save(recurringTransactions)
        scheduleWebDAVSyncIfNeeded()
    }

    private func ensureBuiltInAccounts() {
        let existing = Set(accounts.map(\.id))
        let deletedById = Dictionary(uniqueKeysWithValues: deletedAccountMarkers.map { ($0.id, $0.deletedAt) })
        var changed = false
        for account in DefaultData.accounts where !existing.contains(account.id) {
            if let deletedAt = deletedById[account.id], deletedAt >= account.updatedAt {
                continue
            }
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

    private func csvField(_ row: [String], at index: Int) -> String {
        guard row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseCSVDate(text: String) -> Date? {
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

        return nil
    }

    private func parseCSVRecords(_ content: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false

        let characters = Array(content)
        var index = 0

        while index < characters.count {
            let char = characters[index]

            if char == "\"" {
                if inQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == ",", !inQuotes {
                record.append(field)
                field = ""
            } else if (char == "\n" || char == "\r"), !inQuotes {
                if char == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }

                record.append(field)
                field = ""

                if !record.allSatisfy({ $0.isEmpty }) {
                    records.append(record)
                }
                record = []
            } else {
                field.append(char)
            }

            index += 1
        }

        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            if !record.allSatisfy({ $0.isEmpty }) {
                records.append(record)
            }
        }

        return records
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
            removeDeletionMarkers(matching: [newCategory.id], from: &deletedCategoryMarkers)
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
        removeDeletionMarkers(matching: [fallbackCategory.id], from: &deletedCategoryMarkers)
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
            removeDeletionMarkers(matching: [account.id], from: &deletedAccountMarkers)
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

    private func scheduleWebDAVSyncIfNeeded() {
        requestAutoWebDAVSync(trigger: "本地变更", markPendingLocalChanges: true)
    }

    @discardableResult
    private func syncSnapshotWithWebDAV(trigger: String) async -> Bool {
        guard iCloudSyncEnabled else { return false }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncStatus = "配置不完整"
            return false
        }

        iCloudSyncStatus = "同步中"

        do {
            let remoteRefs = try await fetchRemoteSnapshotManifestRefs()
            if !remoteRefs.isEmpty {
                let pulled = await pullSnapshotFromICloud(
                    mode: .mergeWithLocal,
                    trigger: "\(trigger)：增量拉取",
                    knownRefs: remoteRefs,
                    requireIncremental: false
                )
                guard pulled else { return false }
            } else if let legacySnapshot = try await loadLegacySnapshotIfExists() {
                let merged = mergeSnapshots(local: localSnapshot(syncedAt: Date()), remote: legacySnapshot)
                applyICloudSnapshot(merged)
                addICloudLog("\(trigger)：已迁移旧版单文件快照")
            }

            guard webDAVHasPendingLocalChanges || remoteRefs.isEmpty else {
                iCloudSyncStatus = "已开启"
                addICloudLog("\(trigger)：无本地新增变更，已跳过推送")
                return true
            }

            let snapshot = localSnapshot(syncedAt: Date())
            let pushed = await pushSnapshotToICloud(trigger: "\(trigger)：版本推送", snapshot: snapshot)
            if pushed {
                webDAVHasPendingLocalChanges = false
            }
            return pushed
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("\(trigger)：WebDAV 同步失败（\(error.localizedDescription)）")
            return false
        }
    }

    @discardableResult
    private func pushSnapshotToICloud(trigger: String, snapshot: ICloudSnapshot? = nil) async -> Bool {
        guard iCloudSyncEnabled else { return false }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return false
        }
        guard let baseURL = webDAVConfiguration.baseURL else {
            iCloudSyncStatus = "同步失败"
            addICloudLog("\(trigger)：WebDAV 目标 URL 无效")
            return false
        }

        let snapshot = snapshot ?? localSnapshot(syncedAt: Date())

        do {
            try await webDAVClient.ensureDirectoryExists(directoryURL: baseURL, configuration: webDAVConfiguration)

            let remoteRefs = try await fetchRemoteSnapshotManifestRefs()
            let nextVersion = (remoteRefs.last?.version ?? 0) + 1
            let chunkSize = max(1, webDAVConfiguration.transactionChunkSize)
            let transactionChunks = chunkedTransactions(snapshot.transactions, chunkSize: chunkSize)
            let chunkFileNames = transactionChunks.indices.map {
                webDAVConfiguration.transactionChunkFileName(version: nextVersion, chunkIndex: $0 + 1)
            }

            for (index, chunkTransactions) in transactionChunks.enumerated() {
                let chunk = WebDAVTransactionChunk(
                    version: nextVersion,
                    chunkIndex: index + 1,
                    transactions: chunkTransactions
                )
                let encodedChunk = try JSONEncoder.appEncoder.encode(chunk)
                let encryptedChunk = try encryptSnapshot(encodedChunk)

                guard let chunkURL = webDAVConfiguration.fileURL(fileName: chunkFileNames[index]) else {
                    throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
                }

                try await webDAVClient.upload(data: encryptedChunk, url: chunkURL, configuration: webDAVConfiguration)
            }

            let manifest = WebDAVSnapshotManifest(
                version: nextVersion,
                syncedAt: snapshot.syncedAt,
                transactionChunkSize: chunkSize,
                totalTransactions: snapshot.transactions.count,
                transactionChunkFileNames: chunkFileNames,
                categories: snapshot.categories,
                accounts: snapshot.accounts,
                budgets: snapshot.budgets,
                transfers: snapshot.transfers,
                recurringTransactions: snapshot.recurringTransactions,
                deletedCategoryMarkers: snapshot.deletedCategoryMarkers,
                deletedAccountMarkers: snapshot.deletedAccountMarkers
            )

            let encodedManifest = try JSONEncoder.appEncoder.encode(manifest)
            let encryptedManifest = try encryptSnapshot(encodedManifest)
            let manifestFileName = webDAVConfiguration.manifestFileName(version: nextVersion)

            guard let manifestURL = webDAVConfiguration.fileURL(fileName: manifestFileName) else {
                throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
            }

            try await webDAVClient.upload(data: encryptedManifest, url: manifestURL, configuration: webDAVConfiguration)

            saveLastProcessedSnapshotVersion(nextVersion)
            iCloudLastSyncedAt = snapshot.syncedAt
            iCloudSyncStatus = "已开启"
            addICloudLog("\(trigger)：WebDAV 推送成功（v\(nextVersion)，分片 \(max(chunkFileNames.count, 1)) 个）")
            return true
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("\(trigger)：WebDAV 推送失败（\(error.localizedDescription)）")
            return false
        }
    }

    @discardableResult
    private func pullSnapshotFromICloud(
        mode: ICloudPullMode,
        trigger: String,
        knownRefs: [WebDAVSnapshotVersionRef]? = nil,
        requireIncremental: Bool = true
    ) async -> Bool {
        guard iCloudSyncEnabled else { return false }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return false
        }

        do {
            let refs: [WebDAVSnapshotVersionRef]
            if let knownRefs {
                refs = knownRefs
            } else {
                refs = try await fetchRemoteSnapshotManifestRefs()
            }

            if refs.isEmpty {
                if let legacySnapshot = try await loadLegacySnapshotIfExists() {
                    switch mode {
                    case .replaceLocal:
                        applyICloudSnapshot(legacySnapshot)
                    case .mergeWithLocal:
                        let merged = mergeSnapshots(local: localSnapshot(syncedAt: Date()), remote: legacySnapshot)
                        applyICloudSnapshot(merged)
                    }
                    iCloudSyncStatus = "已开启"
                    addICloudLog("\(trigger)：已从旧版单文件快照拉取")
                    return true
                }

                iCloudSyncStatus = "云端暂无数据"
                addICloudLog("\(trigger)：云端暂无同步快照")
                return false
            }

            let lastVersion = lastProcessedSnapshotVersion()
            let incrementalRefs = refs.filter { $0.version > lastVersion }
            let targetRefs: [WebDAVSnapshotVersionRef]

            if incrementalRefs.isEmpty {
                if requireIncremental {
                    iCloudSyncStatus = "已开启"
                    addICloudLog("\(trigger)：没有新的增量版本")
                    return true
                }

                guard let latest = refs.last else {
                    throw WebDAVSyncError.snapshotNotFound
                }
                targetRefs = [latest]
            } else {
                targetRefs = incrementalRefs
            }

            var workingSnapshot: ICloudSnapshot? = mode == .replaceLocal ? nil : localSnapshot(syncedAt: Date())
            var appliedVersion = lastVersion

            for ref in targetRefs {
                let remoteSnapshot = try await loadSnapshotVersion(ref)
                switch mode {
                case .replaceLocal:
                    workingSnapshot = remoteSnapshot
                case .mergeWithLocal:
                    if let local = workingSnapshot {
                        workingSnapshot = mergeSnapshots(local: local, remote: remoteSnapshot)
                    } else {
                        workingSnapshot = remoteSnapshot
                    }
                }
                appliedVersion = ref.version
            }

            guard let finalSnapshot = workingSnapshot else {
                throw WebDAVSyncError.invalidSnapshotFormat("无法生成可应用的快照")
            }

            applyICloudSnapshot(finalSnapshot)
            saveLastProcessedSnapshotVersion(appliedVersion)
            iCloudSyncStatus = "已开启"
            addICloudLog("\(trigger)：已应用增量快照至 v\(appliedVersion)")
            return true
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("\(trigger)：WebDAV 拉取失败（\(error.localizedDescription)）")
            return false
        }
    }

    private func chunkedTransactions(_ source: [Transaction], chunkSize: Int) -> [[Transaction]] {
        guard !source.isEmpty else { return [] }

        var chunks: [[Transaction]] = []
        chunks.reserveCapacity((source.count + chunkSize - 1) / chunkSize)

        var cursor = 0
        while cursor < source.count {
            let end = min(cursor + chunkSize, source.count)
            chunks.append(Array(source[cursor..<end]))
            cursor = end
        }

        return chunks
    }

    private func fetchRemoteSnapshotManifestRefs() async throws -> [WebDAVSnapshotVersionRef] {
        guard let baseURL = webDAVConfiguration.baseURL else {
            throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
        }

        let fileNames = try await webDAVClient.listFileNames(directoryURL: baseURL, configuration: webDAVConfiguration)
        return fileNames.compactMap { fileName in
            guard let version = webDAVConfiguration.parseVersion(fromManifestFileName: fileName) else {
                return nil
            }
            return WebDAVSnapshotVersionRef(version: version, manifestFileName: fileName)
        }
        .sorted(by: { $0.version < $1.version })
    }

    private func loadSnapshotVersion(_ ref: WebDAVSnapshotVersionRef) async throws -> ICloudSnapshot {
        guard let manifestURL = webDAVConfiguration.fileURL(fileName: ref.manifestFileName) else {
            throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
        }

        guard let manifestPayload = try await webDAVClient.download(url: manifestURL, configuration: webDAVConfiguration) else {
            throw WebDAVSyncError.snapshotNotFound
        }
        guard !manifestPayload.isEmpty else {
            throw WebDAVSyncError.emptyRemotePayload
        }

        let manifestData = try decryptSnapshot(manifestPayload)
        let manifest = try JSONDecoder.appDecoder.decode(WebDAVSnapshotManifest.self, from: manifestData)

        guard manifest.version == ref.version else {
            throw WebDAVSyncError.invalidSnapshotFormat("云端快照版本不一致")
        }

        var mergedTransactions: [Transaction] = []
        mergedTransactions.reserveCapacity(manifest.totalTransactions)

        for chunkFileName in manifest.transactionChunkFileNames {
            guard let chunkURL = webDAVConfiguration.fileURL(fileName: chunkFileName) else {
                throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
            }

            guard let chunkPayload = try await webDAVClient.download(url: chunkURL, configuration: webDAVConfiguration) else {
                throw WebDAVSyncError.invalidSnapshotFormat("云端快照分片缺失：\(chunkFileName)")
            }
            guard !chunkPayload.isEmpty else {
                throw WebDAVSyncError.emptyRemotePayload
            }

            let chunkData = try decryptSnapshot(chunkPayload)
            let chunk = try JSONDecoder.appDecoder.decode(WebDAVTransactionChunk.self, from: chunkData)
            mergedTransactions.append(contentsOf: chunk.transactions)
        }

        if mergedTransactions.count != manifest.totalTransactions {
            throw WebDAVSyncError.invalidSnapshotFormat(
                "云端快照交易条数不匹配（期望 \(manifest.totalTransactions)，实际 \(mergedTransactions.count)）"
            )
        }

        return ICloudSnapshot(
            syncedAt: manifest.syncedAt,
            transactions: mergedTransactions,
            categories: manifest.categories,
            accounts: manifest.accounts,
            budgets: manifest.budgets,
            transfers: manifest.transfers,
            recurringTransactions: manifest.recurringTransactions,
            deletedCategoryMarkers: manifest.deletedCategoryMarkers,
            deletedAccountMarkers: manifest.deletedAccountMarkers
        )
    }

    private func loadLegacySnapshotIfExists() async throws -> ICloudSnapshot? {
        guard let legacyURL = webDAVConfiguration.legacySnapshotFileURL else { return nil }

        guard let legacyPayload = try await webDAVClient.download(url: legacyURL, configuration: webDAVConfiguration) else {
            return nil
        }
        guard !legacyPayload.isEmpty else {
            throw WebDAVSyncError.emptyRemotePayload
        }

        let decrypted = try decryptSnapshot(legacyPayload)
        return try JSONDecoder.appDecoder.decode(ICloudSnapshot.self, from: decrypted)
    }

    private func lastProcessedSnapshotVersion() -> Int {
        let key = webDAVConfiguration.endpointStateKey
        guard let values = webDAVSyncProgressDefaults.dictionary(forKey: webDAVSyncProgressStorageKey) as? [String: Int] else {
            return 0
        }
        return values[key] ?? 0
    }

    private func saveLastProcessedSnapshotVersion(_ version: Int) {
        let key = webDAVConfiguration.endpointStateKey
        var values = webDAVSyncProgressDefaults.dictionary(forKey: webDAVSyncProgressStorageKey) as? [String: Int] ?? [:]

        if version <= 0 {
            values.removeValue(forKey: key)
        } else {
            values[key] = version
        }

        webDAVSyncProgressDefaults.set(values, forKey: webDAVSyncProgressStorageKey)
    }

    private func remoteSnapshotExists() async throws -> Bool {
        if !(try await fetchRemoteSnapshotManifestRefs()).isEmpty {
            return true
        }

        return try await loadLegacySnapshotIfExists() != nil
    }

    private func verifyWebDAVConfiguration(logFailures: Bool) -> Bool {
        if webDAVConfiguration.baseURL == nil {
            if logFailures {
                iCloudSyncStatus = "配置不完整"
                addICloudLog("请填写 WebDAV 协议、地址与路径")
            }
            return false
        }

        if webDAVConfiguration.normalizedEncryptionKey.isEmpty {
            if logFailures {
                iCloudSyncStatus = "配置不完整"
                addICloudLog("请填写加密密钥（AES-256-GCM）")
            }
            return false
        }

        return true
    }

    private func encryptSnapshot(_ data: Data) throws -> Data {
        let key = try derivedSymmetricKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw WebDAVSyncError.encryptionFailed
        }
        return combined
    }

    private func decryptSnapshot(_ data: Data) throws -> Data {
        let key = try derivedSymmetricKey()

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw WebDAVSyncError.decryptionFailed
        }
    }

    private func derivedSymmetricKey() throws -> SymmetricKey {
        let raw = webDAVConfiguration.normalizedEncryptionKey
        guard !raw.isEmpty else {
            throw WebDAVSyncError.invalidConfiguration("请填写加密密钥")
        }

        let digest = SHA256.hash(data: Data(raw.utf8))
        return SymmetricKey(data: Data(digest))
    }

    private func applyICloudSnapshot(_ snapshot: ICloudSnapshot) {
        isApplyingICloudSnapshot = true
        defer { isApplyingICloudSnapshot = false }

        let normalizedCategories = snapshot.categories.isEmpty ? DefaultData.categories : snapshot.categories
        let normalizedAccounts = snapshot.accounts.isEmpty ? DefaultData.accounts : snapshot.accounts

        let categoryResolution = resolveEntitiesAgainstDeletionMarkers(
            normalizedCategories,
            markers: snapshot.deletedCategoryMarkers,
            updatedAt: \.updatedAt
        )
        let accountResolution = resolveEntitiesAgainstDeletionMarkers(
            normalizedAccounts,
            markers: snapshot.deletedAccountMarkers,
            updatedAt: \.updatedAt
        )

        transactions = snapshot.transactions
        categories = categoryResolution.entities
        accounts = accountResolution.entities
        budgets = snapshot.budgets
        transfers = snapshot.transfers
        recurringTransactions = snapshot.recurringTransactions

        deletedCategoryMarkers = categoryResolution.markers
        deletedAccountMarkers = accountResolution.markers

        ensureBuiltInAccounts()

        transactionsStore.save(transactions)
        categoriesStore.save(categories)
        accountsStore.save(accounts)
        budgetsStore.save(budgets)
        transfersStore.save(transfers)
        recurringTransactionsStore.save(recurringTransactions)
        persistDeletionMarkers(scheduleSync: false)

        iCloudLastSyncedAt = snapshot.syncedAt
        iCloudSyncStatus = "已开启"
    }

    private func localSnapshot(syncedAt: Date) -> ICloudSnapshot {
        ICloudSnapshot(
            syncedAt: syncedAt,
            transactions: transactions,
            categories: categories,
            accounts: accounts,
            budgets: budgets,
            transfers: transfers,
            recurringTransactions: recurringTransactions,
            deletedCategoryMarkers: deletedCategoryMarkers,
            deletedAccountMarkers: deletedAccountMarkers
        )
    }

    private func mergeSnapshots(local: ICloudSnapshot, remote: ICloudSnapshot) -> ICloudSnapshot {
        let mergedTransactions = mergeByLatestUpdate(local.transactions, remote.transactions, updatedAt: \.updatedAt)
            .sorted(by: { $0.date > $1.date })

        let mergedBudgets = mergeByLatestUpdate(local.budgets, remote.budgets, updatedAt: \.updatedAt)
            .sorted(by: { $0.month > $1.month })

        let mergedTransfers = mergeByLatestUpdate(local.transfers, remote.transfers, updatedAt: \.updatedAt)
            .sorted(by: { $0.date > $1.date })

        let mergedRecurring = mergeByLatestUpdate(local.recurringTransactions, remote.recurringTransactions, updatedAt: \.updatedAt)
            .sorted(by: { $0.startDate > $1.startDate })

        let mergedCategoryMarkers = mergeDeletionMarkers(local.deletedCategoryMarkers, remote.deletedCategoryMarkers)
        let mergedAccountMarkers = mergeDeletionMarkers(local.deletedAccountMarkers, remote.deletedAccountMarkers)

        let mergedCategories = mergeCategories(
            local: local.categories,
            remote: remote.categories,
            deletionMarkers: mergedCategoryMarkers
        )
        let mergedAccounts = mergeAccounts(
            local: local.accounts,
            remote: remote.accounts,
            deletionMarkers: mergedAccountMarkers
        )

        return ICloudSnapshot(
            syncedAt: max(local.syncedAt, remote.syncedAt),
            transactions: mergedTransactions,
            categories: mergedCategories,
            accounts: mergedAccounts,
            budgets: mergedBudgets,
            transfers: mergedTransfers,
            recurringTransactions: mergedRecurring,
            deletedCategoryMarkers: mergedCategoryMarkers,
            deletedAccountMarkers: mergedAccountMarkers
        )
    }

    private func mergeAccounts(
        local: [Account],
        remote: [Account],
        deletionMarkers: [EntityDeletionMarker]
    ) -> [Account] {
        let merged = mergeByLatestUpdate(local, remote, updatedAt: \.updatedAt)
        let markerById = Dictionary(uniqueKeysWithValues: deletionMarkers.map { ($0.id, $0.deletedAt) })
        let filtered = merged.filter { account in
            guard let deletedAt = markerById[account.id] else { return true }
            return account.updatedAt > deletedAt
        }

        let localOrder = Dictionary(uniqueKeysWithValues: local.enumerated().map { ($1.id, $0) })
        let remoteOrder = Dictionary(uniqueKeysWithValues: remote.enumerated().map { ($1.id, $0) })

        return filtered.sorted { lhs, rhs in
            let lhsLocal = localOrder[lhs.id]
            let rhsLocal = localOrder[rhs.id]

            switch (lhsLocal, rhsLocal) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }

            let lhsRemote = remoteOrder[lhs.id] ?? Int.max
            let rhsRemote = remoteOrder[rhs.id] ?? Int.max
            if lhsRemote != rhsRemote {
                return lhsRemote < rhsRemote
            }

            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }

    private func mergeCategories(
        local: [Category],
        remote: [Category],
        deletionMarkers: [EntityDeletionMarker]
    ) -> [Category] {
        let merged = mergeByLatestUpdate(local, remote, updatedAt: \.updatedAt)
        let markerById = Dictionary(uniqueKeysWithValues: deletionMarkers.map { ($0.id, $0.deletedAt) })

        return merged
            .filter { category in
                guard let deletedAt = markerById[category.id] else { return true }
                return category.updatedAt > deletedAt
            }
            .sorted { lhs, rhs in
                if lhs.type != rhs.type {
                    return lhs.type.rawValue < rhs.type.rawValue
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
    }

    private func mergeByLatestUpdate<T: Identifiable>(
        _ local: [T],
        _ remote: [T],
        updatedAt: (T) -> Date
    ) -> [T] where T.ID: Hashable {
        var merged: [T.ID: T] = [:]

        for item in remote {
            merged[item.id] = item
        }

        for item in local {
            guard let existing = merged[item.id] else {
                merged[item.id] = item
                continue
            }

            if updatedAt(item) >= updatedAt(existing) {
                merged[item.id] = item
            }
        }

        return Array(merged.values)
    }

    private func mergeByIdentifierPreservingLocalOrder<T: Identifiable>(
        _ local: [T],
        _ remote: [T]
    ) -> [T] where T.ID: Hashable {
        var result: [T] = local
        var known = Set(local.map(\.id))

        for item in remote where !known.contains(item.id) {
            result.append(item)
            known.insert(item.id)
        }

        return result
    }

    private func persistDeletionMarkers(scheduleSync: Bool = true) {
        deletedCategoryMarkersStore.save(deletedCategoryMarkers)
        deletedAccountMarkersStore.save(deletedAccountMarkers)

        if scheduleSync {
            scheduleWebDAVSyncIfNeeded()
        }
    }

    private func mergeDeletionMarkers(
        _ lhs: [EntityDeletionMarker],
        _ rhs: [EntityDeletionMarker]
    ) -> [EntityDeletionMarker] {
        var latestByID: [UUID: Date] = [:]

        for marker in lhs {
            if let existing = latestByID[marker.id], existing >= marker.deletedAt {
                continue
            }
            latestByID[marker.id] = marker.deletedAt
        }

        for marker in rhs {
            if let existing = latestByID[marker.id], existing >= marker.deletedAt {
                continue
            }
            latestByID[marker.id] = marker.deletedAt
        }

        return latestByID
            .map { EntityDeletionMarker(id: $0.key, deletedAt: $0.value) }
            .sorted { lhs, rhs in
                if lhs.deletedAt != rhs.deletedAt {
                    return lhs.deletedAt < rhs.deletedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private func removeDeletionMarkers(matching ids: [UUID], from markers: inout [EntityDeletionMarker]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        markers.removeAll { idSet.contains($0.id) }
    }

    private func resolveEntitiesAgainstDeletionMarkers<T: Identifiable>(
        _ entities: [T],
        markers: [EntityDeletionMarker],
        updatedAt: (T) -> Date
    ) -> (entities: [T], markers: [EntityDeletionMarker]) where T.ID == UUID {
        let normalizedMarkers = mergeDeletionMarkers(markers, [])
        let markerById = Dictionary(uniqueKeysWithValues: normalizedMarkers.map { ($0.id, $0.deletedAt) })

        var activeEntities: [T] = []
        activeEntities.reserveCapacity(entities.count)

        var survivingMarkerDates = markerById

        for entity in entities {
            guard let deletedAt = markerById[entity.id] else {
                activeEntities.append(entity)
                continue
            }

            if updatedAt(entity) > deletedAt {
                activeEntities.append(entity)
                survivingMarkerDates.removeValue(forKey: entity.id)
            }
        }

        let resolvedMarkers = survivingMarkerDates
            .map { EntityDeletionMarker(id: $0.key, deletedAt: $0.value) }
            .sorted { lhs, rhs in
                if lhs.deletedAt != rhs.deletedAt {
                    return lhs.deletedAt < rhs.deletedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        return (activeEntities, resolvedMarkers)
    }

    private func addICloudLog(_ message: String) {
        iCloudSyncLogs.insert(ICloudSyncLog(date: Date(), message: message), at: 0)
        if iCloudSyncLogs.count > 120 {
            iCloudSyncLogs.removeLast(iCloudSyncLogs.count - 120)
        }
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
