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
    @Published private(set) var syncV2Conflicts: [SyncV2Conflict] = []

    private let transactionsStore = JSONFileStore(filename: "transactions.json")
    private let categoriesStore = JSONFileStore(filename: "categories.json")
    private let accountsStore = JSONFileStore(filename: "accounts.json")
    private let budgetsStore = JSONFileStore(filename: "budgets.json")
    private let transfersStore = JSONFileStore(filename: "transfers.json")
    private let recurringTransactionsStore = JSONFileStore(filename: "recurring-transactions.json")
    private let deletedTransactionMarkersStore = JSONFileStore(filename: "deleted-transaction-markers.json")
    private let deletedCategoryMarkersStore = JSONFileStore(filename: "deleted-category-markers.json")
    private let deletedAccountMarkersStore = JSONFileStore(filename: "deleted-account-markers.json")
    private let deletedBudgetMarkersStore = JSONFileStore(filename: "deleted-budget-markers.json")
    private let deletedTransferMarkersStore = JSONFileStore(filename: "deleted-transfer-markers.json")
    private let deletedRecurringMarkersStore = JSONFileStore(filename: "deleted-recurring-markers.json")
    private let syncV2OutboxStore = JSONFileStore(filename: "sync-v2-outbox.json")
    private let syncV2AppliedEventIDsStore = JSONFileStore(filename: "sync-v2-applied-event-ids.json")
    private let syncV2IgnoredEventIDsStore = JSONFileStore(filename: "sync-v2-ignored-event-ids.json")
    private let syncV2ConflictsStore = JSONFileStore(filename: "sync-v2-conflicts.json")

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
        let deletedTransactionMarkers: [EntityDeletionMarker]
        let deletedCategoryMarkers: [EntityDeletionMarker]
        let deletedAccountMarkers: [EntityDeletionMarker]
        let deletedBudgetMarkers: [EntityDeletionMarker]
        let deletedTransferMarkers: [EntityDeletionMarker]
        let deletedRecurringMarkers: [EntityDeletionMarker]

        init(
            syncedAt: Date,
            transactions: [Transaction],
            categories: [Category],
            accounts: [Account],
            budgets: [Budget],
            transfers: [Transfer],
            recurringTransactions: [RecurringTransaction],
            deletedTransactionMarkers: [EntityDeletionMarker] = [],
            deletedCategoryMarkers: [EntityDeletionMarker] = [],
            deletedAccountMarkers: [EntityDeletionMarker] = [],
            deletedBudgetMarkers: [EntityDeletionMarker] = [],
            deletedTransferMarkers: [EntityDeletionMarker] = [],
            deletedRecurringMarkers: [EntityDeletionMarker] = []
        ) {
            self.syncedAt = syncedAt
            self.transactions = transactions
            self.categories = categories
            self.accounts = accounts
            self.budgets = budgets
            self.transfers = transfers
            self.recurringTransactions = recurringTransactions
            self.deletedTransactionMarkers = deletedTransactionMarkers
            self.deletedCategoryMarkers = deletedCategoryMarkers
            self.deletedAccountMarkers = deletedAccountMarkers
            self.deletedBudgetMarkers = deletedBudgetMarkers
            self.deletedTransferMarkers = deletedTransferMarkers
            self.deletedRecurringMarkers = deletedRecurringMarkers
        }

        private enum CodingKeys: String, CodingKey {
            case syncedAt
            case transactions
            case categories
            case accounts
            case budgets
            case transfers
            case recurringTransactions
            case deletedTransactionMarkers
            case deletedCategoryMarkers
            case deletedAccountMarkers
            case deletedBudgetMarkers
            case deletedTransferMarkers
            case deletedRecurringMarkers
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
            deletedTransactionMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedTransactionMarkers) ?? []
            deletedCategoryMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedCategoryMarkers) ?? []
            deletedAccountMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedAccountMarkers) ?? []
            deletedBudgetMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedBudgetMarkers) ?? []
            deletedTransferMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedTransferMarkers) ?? []
            deletedRecurringMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedRecurringMarkers) ?? []
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
        let deletedTransactionMarkers: [EntityDeletionMarker]
        let deletedCategoryMarkers: [EntityDeletionMarker]
        let deletedAccountMarkers: [EntityDeletionMarker]
        let deletedBudgetMarkers: [EntityDeletionMarker]
        let deletedTransferMarkers: [EntityDeletionMarker]
        let deletedRecurringMarkers: [EntityDeletionMarker]

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
            deletedTransactionMarkers: [EntityDeletionMarker] = [],
            deletedCategoryMarkers: [EntityDeletionMarker] = [],
            deletedAccountMarkers: [EntityDeletionMarker] = [],
            deletedBudgetMarkers: [EntityDeletionMarker] = [],
            deletedTransferMarkers: [EntityDeletionMarker] = [],
            deletedRecurringMarkers: [EntityDeletionMarker] = []
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
            self.deletedTransactionMarkers = deletedTransactionMarkers
            self.deletedCategoryMarkers = deletedCategoryMarkers
            self.deletedAccountMarkers = deletedAccountMarkers
            self.deletedBudgetMarkers = deletedBudgetMarkers
            self.deletedTransferMarkers = deletedTransferMarkers
            self.deletedRecurringMarkers = deletedRecurringMarkers
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
            case deletedTransactionMarkers
            case deletedCategoryMarkers
            case deletedAccountMarkers
            case deletedBudgetMarkers
            case deletedTransferMarkers
            case deletedRecurringMarkers
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
            deletedTransactionMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedTransactionMarkers) ?? []
            deletedCategoryMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedCategoryMarkers) ?? []
            deletedAccountMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedAccountMarkers) ?? []
            deletedBudgetMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedBudgetMarkers) ?? []
            deletedTransferMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedTransferMarkers) ?? []
            deletedRecurringMarkers = try container.decodeIfPresent([EntityDeletionMarker].self, forKey: .deletedRecurringMarkers) ?? []
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
    private var isApplyingSyncV2Remote = false
    private var webDAVConfiguration = WebDAVSyncConfiguration()
    private let webDAVClient = WebDAVClient()

    private var webDAVAutoSyncTask: Task<Void, Never>?
    private var webDAVAutoSyncToken = UUID()
    private var webDAVAutoSyncTrigger: String?
    private var webDAVAutoSyncDebounceNanoseconds: UInt64 = 900_000_000
    private var webDAVHasPendingLocalChanges = false

    private var deletedTransactionMarkers: [EntityDeletionMarker] = []
    private var deletedCategoryMarkers: [EntityDeletionMarker] = []
    private var deletedAccountMarkers: [EntityDeletionMarker] = []
    private var deletedBudgetMarkers: [EntityDeletionMarker] = []
    private var deletedTransferMarkers: [EntityDeletionMarker] = []
    private var deletedRecurringMarkers: [EntityDeletionMarker] = []

    private var syncV2Outbox: [SyncV2Event] = []
    private var syncV2AppliedEventIDs: Set<UUID> = []
    private var syncV2IgnoredEventIDs: Set<UUID> = []
    private var syncV2DeviceID: String = UUID().uuidString

    private let webDAVSyncProgressDefaults = UserDefaults.standard
    private let webDAVSyncProgressStorageKey = "sync.webdav.last_processed_manifest_versions"
    private let webDAVSyncV2ProgressStorageKey = "sync.webdav.v2.last_processed_sequence"
    private let webDAVSyncV2DeviceIDStorageKey = "sync.webdav.v2.device_id"

    init() {
        load()
    }

    var defaultAccountId: UUID {
        accounts.first?.id ?? DefaultData.accounts[0].id
    }

    var hasPendingSyncV2Conflicts: Bool {
        !syncV2Conflicts.isEmpty
    }

    func load() {
        transactions = transactionsStore.load([Transaction].self, default: [])
        categories = categoriesStore.load([Category].self, default: DefaultData.categories)
        accounts = accountsStore.load([Account].self, default: DefaultData.accounts)
        budgets = budgetsStore.load([Budget].self, default: [])
        transfers = transfersStore.load([Transfer].self, default: [])
        recurringTransactions = recurringTransactionsStore.load([RecurringTransaction].self, default: [])
        deletedTransactionMarkers = deletedTransactionMarkersStore.load([EntityDeletionMarker].self, default: [])
        deletedCategoryMarkers = deletedCategoryMarkersStore.load([EntityDeletionMarker].self, default: [])
        deletedAccountMarkers = deletedAccountMarkersStore.load([EntityDeletionMarker].self, default: [])
        deletedBudgetMarkers = deletedBudgetMarkersStore.load([EntityDeletionMarker].self, default: [])
        deletedTransferMarkers = deletedTransferMarkersStore.load([EntityDeletionMarker].self, default: [])
        deletedRecurringMarkers = deletedRecurringMarkersStore.load([EntityDeletionMarker].self, default: [])

        syncV2Outbox = syncV2OutboxStore.load([SyncV2Event].self, default: [])
        syncV2AppliedEventIDs = Set(syncV2AppliedEventIDsStore.load([UUID].self, default: []))
        syncV2IgnoredEventIDs = Set(syncV2IgnoredEventIDsStore.load([UUID].self, default: []))
        syncV2Conflicts = syncV2ConflictsStore.load([SyncV2Conflict].self, default: [])
        syncV2Conflicts.removeAll {
            syncV2AppliedEventIDs.contains($0.remoteEvent.id) || syncV2IgnoredEventIDs.contains($0.remoteEvent.id)
        }
        if let savedDeviceID = webDAVSyncProgressDefaults.string(forKey: webDAVSyncV2DeviceIDStorageKey), !savedDeviceID.isEmpty {
            syncV2DeviceID = savedDeviceID
        } else {
            syncV2DeviceID = UUID().uuidString
            webDAVSyncProgressDefaults.set(syncV2DeviceID, forKey: webDAVSyncV2DeviceIDStorageKey)
        }

        let transactionResolution = resolveEntitiesAgainstDeletionMarkers(
            transactions,
            markers: deletedTransactionMarkers,
            updatedAt: \.updatedAt
        )
        transactions = transactionResolution.entities
        deletedTransactionMarkers = transactionResolution.markers

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

        let budgetResolution = resolveEntitiesAgainstDeletionMarkers(
            budgets,
            markers: deletedBudgetMarkers,
            updatedAt: \.updatedAt
        )
        budgets = budgetResolution.entities
        deletedBudgetMarkers = budgetResolution.markers

        let transferResolution = resolveEntitiesAgainstDeletionMarkers(
            transfers,
            markers: deletedTransferMarkers,
            updatedAt: \.updatedAt
        )
        transfers = transferResolution.entities
        deletedTransferMarkers = transferResolution.markers

        let recurringResolution = resolveEntitiesAgainstDeletionMarkers(
            recurringTransactions,
            markers: deletedRecurringMarkers,
            updatedAt: \.updatedAt
        )
        recurringTransactions = recurringResolution.entities
        deletedRecurringMarkers = recurringResolution.markers

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
            if let index = try await fetchRemoteSyncV2Index() {
                iCloudSyncStatus = "已连接"
                addICloudLog("状态检查：WebDAV 连接正常，检测到 v2 变更版本 \(index.latestSequence)")
                return "WebDAV 连接正常，检测到 v2 变更版本 \(index.latestSequence)"
            }

            iCloudSyncStatus = "已连接"
            addICloudLog("状态检查：WebDAV 连接正常，但云端暂无 v2 变更数据")
            return "WebDAV 连接正常，但云端暂无 v2 变更数据"
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
        let success = await pullChangesFromWebDAVV2(trigger: "手动拉取")
        if !syncV2Conflicts.isEmpty {
            return "拉取完成，但有 \(syncV2Conflicts.count) 个冲突等待选择"
        }
        return success ? "拉取成功，已按变更日志应用到本地" : "拉取失败，请查看同步日志"
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
        let success = await pushChangesToWebDAVV2(trigger: "手动推送")
        if success {
            webDAVHasPendingLocalChanges = false
        }
        return success ? "推送成功，云端变更已更新" : "推送失败，请查看同步日志"
    }

    @discardableResult
    func pushToICloudNow(configuration: WebDAVSyncConfiguration) async -> String {
        updateWebDAVConfiguration(configuration)
        return await pushToICloudNow()
    }

    func clearICloudSyncLogs() {
        iCloudSyncLogs.removeAll()
    }

    func resolveSyncV2Conflict(_ conflict: SyncV2Conflict, resolution: SyncV2ConflictResolution) {
        guard let index = syncV2Conflicts.firstIndex(where: { $0.id == conflict.id }) else { return }

        switch resolution {
        case .useLocal:
            syncV2IgnoredEventIDs.insert(conflict.remoteEvent.id)
            syncV2AppliedEventIDs.insert(conflict.remoteEvent.id)
            addICloudLog("冲突已解决：保留本地 \(conflict.entityType.rawValue) \(conflict.entityId.uuidString.prefix(8))")
        case .useRemote:
            isApplyingSyncV2Remote = true
            applyRemoteSyncV2Event(conflict.remoteEvent, force: true)
            isApplyingSyncV2Remote = false
            syncV2Outbox.removeAll {
                $0.entityType == conflict.entityType && $0.entityId == conflict.entityId
            }
            syncV2AppliedEventIDs.insert(conflict.remoteEvent.id)
            addICloudLog("冲突已解决：采用云端 \(conflict.entityType.rawValue) \(conflict.entityId.uuidString.prefix(8))")
        }

        syncV2Conflicts.remove(at: index)
        persistSyncV2Metadata(scheduleSync: false)
    }

    func resolveFirstSyncV2Conflict(resolution: SyncV2ConflictResolution) {
        guard let first = syncV2Conflicts.first else { return }
        resolveSyncV2Conflict(first, resolution: resolution)
    }

    private func enableWebDAVSyncFlow() async {
        guard iCloudSyncEnabled else { return }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return
        }

        iCloudSyncStatus = "同步中"
        _ = await syncChangesWithWebDAVV2(trigger: "首次开启")
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
            _ = await syncChangesWithWebDAVV2(trigger: trigger)
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
        removeDeletionMarkers(matching: [transaction.id], from: &deletedTransactionMarkers)
        queueSyncV2TransactionUpsert(transaction, baseUpdatedAt: nil)
        persistTransactions()
        persistDeletionMarkers(scheduleSync: false)
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
            removeDeletionMarkers(matching: [transaction.id], from: &deletedTransactionMarkers)
            queueSyncV2TransactionUpsert(transaction, baseUpdatedAt: nil)
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
            persistDeletionMarkers(scheduleSync: false)
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
        queueSyncV2AccountUpsert(account, baseUpdatedAt: nil)
        persistAccounts()
        persistDeletionMarkers(scheduleSync: false)
    }

    func updateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }

        var updated = account
        updated.createdAt = accounts[index].createdAt
        let baseUpdatedAt = accounts[index].updatedAt
        updated.updatedAt = Date()

        accounts[index] = updated
        removeDeletionMarkers(matching: [account.id], from: &deletedAccountMarkers)
        queueSyncV2AccountUpsert(updated, baseUpdatedAt: baseUpdatedAt)
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

        let existingIds = Set(accounts.map(\.id))
        var deletableIds = Set(ids)
            .intersection(existingIds)
            .subtracting(usedIds)

        guard !deletableIds.isEmpty else { return }

        if deletableIds.count >= accounts.count, let keepId = accounts.first?.id {
            deletableIds.remove(keepId)
        }

        guard !deletableIds.isEmpty else { return }

        let now = Date()
        accounts.removeAll(where: { deletableIds.contains($0.id) })
        deletedAccountMarkers = mergeDeletionMarkers(
            deletedAccountMarkers,
            deletableIds.map { EntityDeletionMarker(id: $0, deletedAt: now) }
        )
        for id in deletableIds {
            queueSyncV2AccountDelete(id: id, deletedAt: now, baseUpdatedAt: nil)
        }
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
        removeDeletionMarkers(matching: [transfer.id], from: &deletedTransferMarkers)
        queueSyncV2TransferUpsert(transfer, baseUpdatedAt: nil)
        persistTransfers()
        persistDeletionMarkers(scheduleSync: false)
    }

    func deleteTransfers(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        let now = Date()
        transfers.removeAll(where: { idSet.contains($0.id) })
        deletedTransferMarkers = mergeDeletionMarkers(
            deletedTransferMarkers,
            ids.map { EntityDeletionMarker(id: $0, deletedAt: now) }
        )
        for id in ids {
            queueSyncV2TransferDelete(id: id, deletedAt: now, baseUpdatedAt: nil)
        }
        persistTransfers()
        persistDeletionMarkers(scheduleSync: false)
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
            let baseUpdatedAt = budgets[index].updatedAt
            budgets[index].limit = limit
            budgets[index].updatedAt = Date()
            removeDeletionMarkers(matching: [budgets[index].id], from: &deletedBudgetMarkers)
            queueSyncV2BudgetUpsert(budgets[index], baseUpdatedAt: baseUpdatedAt)
        } else {
            let now = Date()
            let budget = Budget(
                id: UUID(),
                month: start,
                type: type,
                categoryId: categoryId,
                limit: limit,
                createdAt: now,
                updatedAt: now
            )
            budgets.append(budget)
            removeDeletionMarkers(matching: [budget.id], from: &deletedBudgetMarkers)
            queueSyncV2BudgetUpsert(budget, baseUpdatedAt: nil)
        }
        persistBudgets()
        persistDeletionMarkers(scheduleSync: false)
    }

    func deleteBudget(_ budget: Budget) {
        budgets.removeAll(where: { $0.id == budget.id })
        let now = Date()
        let marker = EntityDeletionMarker(id: budget.id, deletedAt: now)
        deletedBudgetMarkers = mergeDeletionMarkers(deletedBudgetMarkers, [marker])
        queueSyncV2BudgetDelete(id: budget.id, deletedAt: now, baseUpdatedAt: nil)
        persistBudgets()
        persistDeletionMarkers(scheduleSync: false)
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
        removeDeletionMarkers(matching: [recurring.id], from: &deletedRecurringMarkers)
        queueSyncV2RecurringUpsert(recurring, baseUpdatedAt: nil)
        persistRecurringTransactions()
        persistDeletionMarkers(scheduleSync: false)
        applyRecurringTransactionsIfNeeded()
    }

    func toggleRecurringTransaction(_ recurring: RecurringTransaction, isEnabled: Bool) {
        guard let index = recurringTransactions.firstIndex(where: { $0.id == recurring.id }) else { return }
        let baseUpdatedAt = recurringTransactions[index].updatedAt
        recurringTransactions[index].isEnabled = isEnabled
        recurringTransactions[index].updatedAt = Date()
        removeDeletionMarkers(matching: [recurring.id], from: &deletedRecurringMarkers)
        queueSyncV2RecurringUpsert(recurringTransactions[index], baseUpdatedAt: baseUpdatedAt)
        persistRecurringTransactions()
        persistDeletionMarkers(scheduleSync: false)

        if isEnabled {
            applyRecurringTransactionsIfNeeded()
        }
    }

    func deleteRecurringTransactions(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        let now = Date()
        recurringTransactions.removeAll(where: { idSet.contains($0.id) })
        deletedRecurringMarkers = mergeDeletionMarkers(
            deletedRecurringMarkers,
            ids.map { EntityDeletionMarker(id: $0, deletedAt: now) }
        )
        for id in ids {
            queueSyncV2RecurringDelete(id: id, deletedAt: now, baseUpdatedAt: nil)
        }
        persistRecurringTransactions()
        persistDeletionMarkers(scheduleSync: false)
    }

    func updateTransaction(
        id: UUID,
        type: TransactionType,
        amount: Decimal,
        date: Date,
        categoryId: UUID,
        accountId: UUID,
        note: String?
    ) {
        guard amount > 0 else { return }
        guard category(for: categoryId)?.type == type else { return }
        guard account(for: accountId) != nil else { return }
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return }

        var transaction = transactions[index]
        let baseUpdatedAt = transaction.updatedAt
        transaction.type = type
        transaction.amount = amount
        transaction.date = date
        transaction.categoryId = categoryId
        transaction.accountId = accountId
        transaction.note = note?.nilIfEmpty
        transaction.updatedAt = Date()

        transactions[index] = transaction
        removeDeletionMarkers(matching: [transaction.id], from: &deletedTransactionMarkers)
        queueSyncV2TransactionUpsert(transaction, baseUpdatedAt: baseUpdatedAt)
        persistTransactions()
        persistDeletionMarkers(scheduleSync: false)
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
        let now = Date()
        transactions.removeAll(where: { idSet.contains($0.id) })
        deletedTransactionMarkers = mergeDeletionMarkers(
            deletedTransactionMarkers,
            ids.map { EntityDeletionMarker(id: $0, deletedAt: now) }
        )
        for id in ids {
            queueSyncV2TransactionDelete(id: id, deletedAt: now, baseUpdatedAt: nil)
        }
        persistTransactions()
        persistDeletionMarkers(scheduleSync: false)
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
        queueSyncV2CategoryUpsert(category, baseUpdatedAt: nil)
        persistCategories()
        persistDeletionMarkers(scheduleSync: false)
    }

    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }

        var updated = category
        updated.createdAt = categories[index].createdAt
        let baseUpdatedAt = categories[index].updatedAt
        updated.updatedAt = Date()

        categories[index] = updated
        removeDeletionMarkers(matching: [category.id], from: &deletedCategoryMarkers)
        queueSyncV2CategoryUpsert(updated, baseUpdatedAt: baseUpdatedAt)
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
        for id in ids {
            queueSyncV2CategoryDelete(id: id, deletedAt: now, baseUpdatedAt: nil)
        }
        persistCategories()
        persistDeletionMarkers(scheduleSync: false)
    }

    func moveCategories(from source: IndexSet, to destination: Int, type: TransactionType) {
        var typed = categories(ofType: type)
        moveItems(&typed, from: source, to: destination)

        let now = Date()
        let previousById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

        let orderById = Dictionary(uniqueKeysWithValues: typed.enumerated().map { ($1.id, $0) })
        categories = categories.map { category in
            guard category.type == type, let order = orderById[category.id] else { return category }
            return category.with(sortOrder: order, updatedAt: now)
        }

        for category in categories where category.type == type {
            guard let previous = previousById[category.id] else { continue }
            guard previous.sortOrder != category.sortOrder else { continue }
            queueSyncV2CategoryUpsert(category, baseUpdatedAt: previous.updatedAt)
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
            removeDeletionMarkers(matching: [transaction.id], from: &deletedTransactionMarkers)
            queueSyncV2TransactionUpsert(transaction, baseUpdatedAt: nil)
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
            persistDeletionMarkers(scheduleSync: false)
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
            queueSyncV2AccountUpsert(account, baseUpdatedAt: nil)
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
                    queueSyncV2TransactionUpsert(transaction, baseUpdatedAt: nil)
                    transactionsChanged = true
                    didGenerate = true
                    lastGeneratedDate = cursor
                }
                cursor = nextDate(after: cursor, frequency: recurring.frequency, calendar: calendar)
            }

            if didGenerate, let lastGeneratedDate {
                let baseUpdatedAt = recurring.updatedAt
                recurring.lastGeneratedAt = lastGeneratedDate
                recurring.updatedAt = Date()
                recurringTransactions[index] = recurring
                queueSyncV2RecurringUpsert(recurring, baseUpdatedAt: baseUpdatedAt)
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
        !transactions.isEmpty ||
        !budgets.isEmpty ||
        !transfers.isEmpty ||
        !recurringTransactions.isEmpty ||
        !deletedTransactionMarkers.isEmpty ||
        !deletedCategoryMarkers.isEmpty ||
        !deletedAccountMarkers.isEmpty ||
        !deletedBudgetMarkers.isEmpty ||
        !deletedTransferMarkers.isEmpty ||
        !deletedRecurringMarkers.isEmpty
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
            queueSyncV2CategoryUpsert(newCategory, baseUpdatedAt: nil)
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
        queueSyncV2CategoryUpsert(fallbackCategory, baseUpdatedAt: nil)
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
            queueSyncV2AccountUpsert(account, baseUpdatedAt: nil)
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
        await syncChangesWithWebDAVV2(trigger: trigger)
    }


    @discardableResult
    private func pushSnapshotToICloud(trigger: String, snapshot: ICloudSnapshot? = nil) async -> Bool {
        await pushChangesToWebDAVV2(trigger: trigger)
    }


    @discardableResult
    private func pullSnapshotFromICloud(
        mode: ICloudPullMode,
        trigger: String,
        knownRefs: [WebDAVSnapshotVersionRef]? = nil,
        requireIncremental: Bool = true
    ) async -> Bool {
        await pullChangesFromWebDAVV2(trigger: trigger)
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
            deletedTransactionMarkers: manifest.deletedTransactionMarkers,
            deletedCategoryMarkers: manifest.deletedCategoryMarkers,
            deletedAccountMarkers: manifest.deletedAccountMarkers,
            deletedBudgetMarkers: manifest.deletedBudgetMarkers,
            deletedTransferMarkers: manifest.deletedTransferMarkers,
            deletedRecurringMarkers: manifest.deletedRecurringMarkers
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

        let transactionResolution = resolveEntitiesAgainstDeletionMarkers(
            snapshot.transactions,
            markers: snapshot.deletedTransactionMarkers,
            updatedAt: \.updatedAt
        )

        let budgetResolution = resolveEntitiesAgainstDeletionMarkers(
            snapshot.budgets,
            markers: snapshot.deletedBudgetMarkers,
            updatedAt: \.updatedAt
        )

        let transferResolution = resolveEntitiesAgainstDeletionMarkers(
            snapshot.transfers,
            markers: snapshot.deletedTransferMarkers,
            updatedAt: \.updatedAt
        )

        let recurringResolution = resolveEntitiesAgainstDeletionMarkers(
            snapshot.recurringTransactions,
            markers: snapshot.deletedRecurringMarkers,
            updatedAt: \.updatedAt
        )

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

        transactions = transactionResolution.entities
        categories = categoryResolution.entities
        accounts = accountResolution.entities
        budgets = budgetResolution.entities
        transfers = transferResolution.entities
        recurringTransactions = recurringResolution.entities

        deletedTransactionMarkers = transactionResolution.markers
        deletedCategoryMarkers = categoryResolution.markers
        deletedAccountMarkers = accountResolution.markers
        deletedBudgetMarkers = budgetResolution.markers
        deletedTransferMarkers = transferResolution.markers
        deletedRecurringMarkers = recurringResolution.markers

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
            deletedTransactionMarkers: deletedTransactionMarkers,
            deletedCategoryMarkers: deletedCategoryMarkers,
            deletedAccountMarkers: deletedAccountMarkers,
            deletedBudgetMarkers: deletedBudgetMarkers,
            deletedTransferMarkers: deletedTransferMarkers,
            deletedRecurringMarkers: deletedRecurringMarkers
        )
    }

    private func mergeSnapshots(local: ICloudSnapshot, remote: ICloudSnapshot) -> ICloudSnapshot {
        let mergedCategoryMarkers = mergeDeletionMarkers(local.deletedCategoryMarkers, remote.deletedCategoryMarkers)
        let mergedAccountMarkers = mergeDeletionMarkers(local.deletedAccountMarkers, remote.deletedAccountMarkers)
        let mergedTransactionMarkers = mergeDeletionMarkers(local.deletedTransactionMarkers, remote.deletedTransactionMarkers)
        let mergedBudgetMarkers = mergeDeletionMarkers(local.deletedBudgetMarkers, remote.deletedBudgetMarkers)
        let mergedTransferMarkers = mergeDeletionMarkers(local.deletedTransferMarkers, remote.deletedTransferMarkers)
        let mergedRecurringMarkers = mergeDeletionMarkers(local.deletedRecurringMarkers, remote.deletedRecurringMarkers)

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

        let transactionMarkerByID = Dictionary(uniqueKeysWithValues: mergedTransactionMarkers.map { ($0.id, $0.deletedAt) })
        let budgetMarkerByID = Dictionary(uniqueKeysWithValues: mergedBudgetMarkers.map { ($0.id, $0.deletedAt) })
        let transferMarkerByID = Dictionary(uniqueKeysWithValues: mergedTransferMarkers.map { ($0.id, $0.deletedAt) })
        let recurringMarkerByID = Dictionary(uniqueKeysWithValues: mergedRecurringMarkers.map { ($0.id, $0.deletedAt) })

        let mergedBudgets = mergeByLatestUpdate(local.budgets, remote.budgets, updatedAt: \.updatedAt)
            .filter { budget in
                guard let deletedAt = budgetMarkerByID[budget.id] else { return true }
                return budget.updatedAt > deletedAt
            }
            .sorted(by: { $0.month > $1.month })

        let mergedTransfers = mergeByLatestUpdate(local.transfers, remote.transfers, updatedAt: \.updatedAt)
            .filter { transfer in
                guard let deletedAt = transferMarkerByID[transfer.id] else { return true }
                return transfer.updatedAt > deletedAt
            }
            .sorted(by: { $0.date > $1.date })

        let mergedRecurring = mergeByLatestUpdate(local.recurringTransactions, remote.recurringTransactions, updatedAt: \.updatedAt)
            .filter { item in
                guard let deletedAt = recurringMarkerByID[item.id] else { return true }
                return item.updatedAt > deletedAt
            }
            .sorted(by: { $0.startDate > $1.startDate })

        let mergedTransactions = mergeByLatestUpdate(local.transactions, remote.transactions, updatedAt: \.updatedAt)
            .filter { transaction in
                guard let deletedAt = transactionMarkerByID[transaction.id] else { return true }
                return transaction.updatedAt > deletedAt
            }
            .sorted(by: { $0.date > $1.date })

        return ICloudSnapshot(
            syncedAt: max(local.syncedAt, remote.syncedAt),
            transactions: mergedTransactions,
            categories: mergedCategories,
            accounts: mergedAccounts,
            budgets: mergedBudgets,
            transfers: mergedTransfers,
            recurringTransactions: mergedRecurring,
            deletedTransactionMarkers: mergedTransactionMarkers,
            deletedCategoryMarkers: mergedCategoryMarkers,
            deletedAccountMarkers: mergedAccountMarkers,
            deletedBudgetMarkers: mergedBudgetMarkers,
            deletedTransferMarkers: mergedTransferMarkers,
            deletedRecurringMarkers: mergedRecurringMarkers
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

            if updatedAt(item) > updatedAt(existing) {
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
        deletedTransactionMarkersStore.save(deletedTransactionMarkers)
        deletedCategoryMarkersStore.save(deletedCategoryMarkers)
        deletedAccountMarkersStore.save(deletedAccountMarkers)
        deletedBudgetMarkersStore.save(deletedBudgetMarkers)
        deletedTransferMarkersStore.save(deletedTransferMarkers)
        deletedRecurringMarkersStore.save(deletedRecurringMarkers)

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

private extension BillsStore {
    struct SyncV2LocalEntityState {
        let payload: Data?
        let payloadHash: String?
        let updatedAt: Date?
        let deletedAt: Date?
    }

    struct SyncV2RemoteRef {
        let sequence: Int
        let fileName: String
    }

    func queueSyncV2TransactionUpsert(_ transaction: Transaction, baseUpdatedAt: Date?) {
        guard let payload = encodedSyncV2Payload(transaction) else { return }
        queueSyncV2Event(
            operation: .upsert,
            entityType: .transaction,
            entityId: transaction.id,
            payload: payload,
            entityUpdatedAt: transaction.updatedAt,
            deletedAt: nil,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2TransactionDelete(id: UUID, deletedAt: Date, baseUpdatedAt: Date?) {
        queueSyncV2Event(
            operation: .delete,
            entityType: .transaction,
            entityId: id,
            payload: nil,
            entityUpdatedAt: deletedAt,
            deletedAt: deletedAt,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2CategoryUpsert(_ category: Category, baseUpdatedAt: Date?) {
        guard let payload = encodedSyncV2Payload(category) else { return }
        queueSyncV2Event(
            operation: .upsert,
            entityType: .category,
            entityId: category.id,
            payload: payload,
            entityUpdatedAt: category.updatedAt,
            deletedAt: nil,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2CategoryDelete(id: UUID, deletedAt: Date, baseUpdatedAt: Date?) {
        queueSyncV2Event(
            operation: .delete,
            entityType: .category,
            entityId: id,
            payload: nil,
            entityUpdatedAt: deletedAt,
            deletedAt: deletedAt,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2AccountUpsert(_ account: Account, baseUpdatedAt: Date?) {
        guard let payload = encodedSyncV2Payload(account) else { return }
        queueSyncV2Event(
            operation: .upsert,
            entityType: .account,
            entityId: account.id,
            payload: payload,
            entityUpdatedAt: account.updatedAt,
            deletedAt: nil,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2AccountDelete(id: UUID, deletedAt: Date, baseUpdatedAt: Date?) {
        queueSyncV2Event(
            operation: .delete,
            entityType: .account,
            entityId: id,
            payload: nil,
            entityUpdatedAt: deletedAt,
            deletedAt: deletedAt,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2BudgetUpsert(_ budget: Budget, baseUpdatedAt: Date?) {
        guard let payload = encodedSyncV2Payload(budget) else { return }
        queueSyncV2Event(
            operation: .upsert,
            entityType: .budget,
            entityId: budget.id,
            payload: payload,
            entityUpdatedAt: budget.updatedAt,
            deletedAt: nil,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2BudgetDelete(id: UUID, deletedAt: Date, baseUpdatedAt: Date?) {
        queueSyncV2Event(
            operation: .delete,
            entityType: .budget,
            entityId: id,
            payload: nil,
            entityUpdatedAt: deletedAt,
            deletedAt: deletedAt,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2TransferUpsert(_ transfer: Transfer, baseUpdatedAt: Date?) {
        guard let payload = encodedSyncV2Payload(transfer) else { return }
        queueSyncV2Event(
            operation: .upsert,
            entityType: .transfer,
            entityId: transfer.id,
            payload: payload,
            entityUpdatedAt: transfer.updatedAt,
            deletedAt: nil,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2TransferDelete(id: UUID, deletedAt: Date, baseUpdatedAt: Date?) {
        queueSyncV2Event(
            operation: .delete,
            entityType: .transfer,
            entityId: id,
            payload: nil,
            entityUpdatedAt: deletedAt,
            deletedAt: deletedAt,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2RecurringUpsert(_ recurring: RecurringTransaction, baseUpdatedAt: Date?) {
        guard let payload = encodedSyncV2Payload(recurring) else { return }
        queueSyncV2Event(
            operation: .upsert,
            entityType: .recurring,
            entityId: recurring.id,
            payload: payload,
            entityUpdatedAt: recurring.updatedAt,
            deletedAt: nil,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2RecurringDelete(id: UUID, deletedAt: Date, baseUpdatedAt: Date?) {
        queueSyncV2Event(
            operation: .delete,
            entityType: .recurring,
            entityId: id,
            payload: nil,
            entityUpdatedAt: deletedAt,
            deletedAt: deletedAt,
            baseUpdatedAt: baseUpdatedAt
        )
    }

    func queueSyncV2Event(
        operation: SyncV2Operation,
        entityType: SyncV2EntityType,
        entityId: UUID,
        payload: Data?,
        entityUpdatedAt: Date,
        deletedAt: Date?,
        baseUpdatedAt: Date?
    ) {
        guard !isApplyingICloudSnapshot else { return }
        guard !isApplyingSyncV2Remote else { return }

        let payloadHash = payload.map(sha256Hex)

        if let latest = syncV2Outbox.last(where: { $0.entityType == entityType && $0.entityId == entityId }) {
            if latest.operation == operation,
               latest.payloadHash == payloadHash,
               latest.deletedAt == deletedAt {
                return
            }
        }

        let event = SyncV2Event(
            deviceId: syncV2DeviceID,
            createdAt: Date(),
            entityType: entityType,
            operation: operation,
            entityId: entityId,
            baseUpdatedAt: baseUpdatedAt,
            entityUpdatedAt: entityUpdatedAt,
            payload: payload,
            payloadHash: payloadHash,
            deletedAt: deletedAt
        )

        syncV2Outbox.append(event)
        webDAVHasPendingLocalChanges = true
        persistSyncV2Metadata(scheduleSync: true)
    }

    func persistSyncV2Metadata(scheduleSync: Bool = false) {
        syncV2OutboxStore.save(syncV2Outbox)
        syncV2AppliedEventIDsStore.save(syncV2AppliedEventIDs.map(\.self).sorted { $0.uuidString < $1.uuidString })
        syncV2IgnoredEventIDsStore.save(syncV2IgnoredEventIDs.map(\.self).sorted { $0.uuidString < $1.uuidString })
        syncV2ConflictsStore.save(syncV2Conflicts)

        if scheduleSync {
            scheduleWebDAVSyncIfNeeded()
        }
    }

    func encodedSyncV2Payload<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder.appEncoder.encode(value)
    }

    func decodedSyncV2Payload<T: Decodable>(_ data: Data?, as type: T.Type) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder.appDecoder.decode(type, from: data)
    }

    func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func syncV2Digest(for events: [SyncV2Event]) -> String {
        struct Signature: Codable {
            let entityType: SyncV2EntityType
            let operation: SyncV2Operation
            let entityId: UUID
            let payloadHash: String?
            let deletedAt: Date?
            let baseUpdatedAt: Date?
            let entityUpdatedAt: Date
        }

        let signatures = events.map {
            Signature(
                entityType: $0.entityType,
                operation: $0.operation,
                entityId: $0.entityId,
                payloadHash: $0.payloadHash,
                deletedAt: $0.deletedAt,
                baseUpdatedAt: $0.baseUpdatedAt,
                entityUpdatedAt: $0.entityUpdatedAt
            )
        }

        let data = (try? JSONEncoder.appEncoder.encode(signatures)) ?? Data()
        return sha256Hex(data)
    }

    func lastProcessedSyncV2Sequence() -> Int {
        let key = webDAVConfiguration.endpointStateKey
        guard let values = webDAVSyncProgressDefaults.dictionary(forKey: webDAVSyncV2ProgressStorageKey) as? [String: Int] else {
            return 0
        }
        return values[key] ?? 0
    }

    func saveLastProcessedSyncV2Sequence(_ sequence: Int) {
        let key = webDAVConfiguration.endpointStateKey
        var values = webDAVSyncProgressDefaults.dictionary(forKey: webDAVSyncV2ProgressStorageKey) as? [String: Int] ?? [:]
        if sequence <= 0 {
            values.removeValue(forKey: key)
        } else {
            values[key] = sequence
        }
        webDAVSyncProgressDefaults.set(values, forKey: webDAVSyncV2ProgressStorageKey)
    }

    func fetchRemoteSyncV2Index() async throws -> SyncV2Index? {
        guard let indexURL = webDAVConfiguration.syncV2IndexFileURL else {
            throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
        }

        guard let encrypted = try await webDAVClient.download(url: indexURL, configuration: webDAVConfiguration) else {
            return nil
        }
        guard !encrypted.isEmpty else {
            throw WebDAVSyncError.emptyRemotePayload
        }

        let data = try decryptSnapshot(encrypted)
        return try JSONDecoder.appDecoder.decode(SyncV2Index.self, from: data)
    }

    func loadRemoteSyncV2Changeset(fileName: String) async throws -> SyncV2Changeset {
        guard let url = webDAVConfiguration.fileURL(fileName: fileName) else {
            throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
        }

        guard let encrypted = try await webDAVClient.download(url: url, configuration: webDAVConfiguration) else {
            throw WebDAVSyncError.snapshotNotFound
        }
        guard !encrypted.isEmpty else {
            throw WebDAVSyncError.emptyRemotePayload
        }

        let data = try decryptSnapshot(encrypted)
        return try JSONDecoder.appDecoder.decode(SyncV2Changeset.self, from: data)
    }

    func uploadRemoteSyncV2Changeset(_ changeset: SyncV2Changeset, fileName: String) async throws {
        guard let url = webDAVConfiguration.fileURL(fileName: fileName) else {
            throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
        }

        let encoded = try JSONEncoder.appEncoder.encode(changeset)
        let encrypted = try encryptSnapshot(encoded)
        try await webDAVClient.upload(data: encrypted, url: url, configuration: webDAVConfiguration)
    }

    func uploadRemoteSyncV2Index(_ index: SyncV2Index) async throws {
        guard let indexURL = webDAVConfiguration.syncV2IndexFileURL else {
            throw WebDAVSyncError.invalidConfiguration("WebDAV URL 无效")
        }

        let encoded = try JSONEncoder.appEncoder.encode(index)
        let encrypted = try encryptSnapshot(encoded)
        try await webDAVClient.upload(data: encrypted, url: indexURL, configuration: webDAVConfiguration)
    }

    func parseSyncV2RemoteRefs(from index: SyncV2Index, after sequence: Int) -> [SyncV2RemoteRef] {
        index.changesetFileNames
            .compactMap { fileName -> SyncV2RemoteRef? in
                guard let parsed = webDAVConfiguration.parseSyncV2Sequence(fromChangesetFileName: fileName) else {
                    return nil
                }
                guard parsed > sequence else { return nil }
                return SyncV2RemoteRef(sequence: parsed, fileName: fileName)
            }
            .sorted { $0.sequence < $1.sequence }
    }

    @discardableResult
    func syncChangesWithWebDAVV2(trigger: String) async -> Bool {
        guard iCloudSyncEnabled else { return false }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncStatus = "配置不完整"
            return false
        }

        iCloudSyncStatus = "同步中"

        let pulled = await pullChangesFromWebDAVV2(trigger: "\(trigger)：拉取")
        guard pulled else { return false }

        guard syncV2Conflicts.isEmpty else {
            iCloudSyncStatus = "冲突待处理"
            addICloudLog("\(trigger)：检测到 \(syncV2Conflicts.count) 个冲突，等待手动选择")
            return true
        }

        guard webDAVHasPendingLocalChanges || !syncV2Outbox.isEmpty else {
            iCloudSyncStatus = "已开启"
            addICloudLog("\(trigger)：无本地新增变更，跳过推送")
            return true
        }

        let pushed = await pushChangesToWebDAVV2(trigger: "\(trigger)：推送")
        if pushed {
            webDAVHasPendingLocalChanges = false
        }
        return pushed
    }

    @discardableResult
    func pullChangesFromWebDAVV2(trigger: String) async -> Bool {
        guard iCloudSyncEnabled else { return false }
        guard verifyWebDAVConfiguration(logFailures: true) else {
            iCloudSyncEnabled = false
            return false
        }

        do {
            guard let index = try await fetchRemoteSyncV2Index() else {
                iCloudSyncStatus = "已开启"
                addICloudLog("\(trigger)：云端暂无 v2 变更")
                return true
            }

            let refs = parseSyncV2RemoteRefs(from: index, after: lastProcessedSyncV2Sequence())
            if refs.isEmpty {
                iCloudSyncStatus = syncV2Conflicts.isEmpty ? "已开启" : "冲突待处理"
                addICloudLog("\(trigger)：没有新的 v2 变更")
                return true
            }

            var maxSequence = lastProcessedSyncV2Sequence()
            for ref in refs {
                let changeset = try await loadRemoteSyncV2Changeset(fileName: ref.fileName)
                for event in changeset.changes {
                    processRemoteSyncV2Event(event)
                }
                maxSequence = max(maxSequence, changeset.sequence)
            }

            saveLastProcessedSyncV2Sequence(maxSequence)
            persistSyncV2Metadata(scheduleSync: false)
            iCloudLastSyncedAt = Date()

            if syncV2Conflicts.isEmpty {
                iCloudSyncStatus = "已开启"
                addICloudLog("\(trigger)：已应用 \(refs.count) 个变更分片（最新序号 \(maxSequence)）")
            } else {
                iCloudSyncStatus = "冲突待处理"
                addICloudLog("\(trigger)：已拉取，但存在 \(syncV2Conflicts.count) 个冲突")
            }

            return true
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("\(trigger)：拉取失败（\(error.localizedDescription)）")
            return false
        }
    }

    @discardableResult
    func pushChangesToWebDAVV2(trigger: String) async -> Bool {
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

        do {
            try await webDAVClient.ensureDirectoryExists(directoryURL: baseURL, configuration: webDAVConfiguration)

            syncV2Outbox.removeAll { syncV2AppliedEventIDs.contains($0.id) || syncV2IgnoredEventIDs.contains($0.id) }
            guard !syncV2Outbox.isEmpty else {
                iCloudSyncStatus = "已开启"
                addICloudLog("\(trigger)：无待推送变更")
                persistSyncV2Metadata(scheduleSync: false)
                return true
            }

            let remoteIndex = try await fetchRemoteSyncV2Index()
            let digest = syncV2Digest(for: syncV2Outbox)

            if let remoteIndex, let latestFile = remoteIndex.changesetFileNames.last {
                if let latest = try? await loadRemoteSyncV2Changeset(fileName: latestFile), latest.digest == digest {
                    syncV2AppliedEventIDs.formUnion(syncV2Outbox.map(\.id))
                    syncV2Outbox.removeAll()
                    webDAVHasPendingLocalChanges = false
                    persistSyncV2Metadata(scheduleSync: false)
                    iCloudSyncStatus = "已开启"
                    addICloudLog("\(trigger)：变更内容与云端最新一致，未创建新版本")
                    return true
                }
            }

            let nextSequence = (remoteIndex?.latestSequence ?? 0) + 1
            let changesetFileName = webDAVConfiguration.syncV2ChangesetFileName(sequence: nextSequence)
            let changeset = SyncV2Changeset(
                protocolVersion: 2,
                sequence: nextSequence,
                deviceId: syncV2DeviceID,
                createdAt: Date(),
                digest: digest,
                changes: syncV2Outbox
            )

            try await uploadRemoteSyncV2Changeset(changeset, fileName: changesetFileName)

            let nextFileNames = (remoteIndex?.changesetFileNames ?? []) + [changesetFileName]
            let nextIndex = SyncV2Index(
                protocolVersion: 2,
                latestSequence: nextSequence,
                updatedAt: Date(),
                changesetFileNames: nextFileNames
            )
            try await uploadRemoteSyncV2Index(nextIndex)

            syncV2AppliedEventIDs.formUnion(syncV2Outbox.map(\.id))
            syncV2Outbox.removeAll()
            webDAVHasPendingLocalChanges = false
            saveLastProcessedSyncV2Sequence(nextSequence)
            persistSyncV2Metadata(scheduleSync: false)

            iCloudLastSyncedAt = Date()
            iCloudSyncStatus = "已开启"
            addICloudLog("\(trigger)：推送成功（v2 序号 \(nextSequence)，变更 \(changeset.changes.count) 条）")
            return true
        } catch {
            iCloudSyncStatus = "同步失败"
            addICloudLog("\(trigger)：推送失败（\(error.localizedDescription)）")
            return false
        }
    }

    func processRemoteSyncV2Event(_ event: SyncV2Event) {
        if syncV2AppliedEventIDs.contains(event.id) || syncV2IgnoredEventIDs.contains(event.id) {
            return
        }

        if event.deviceId == syncV2DeviceID {
            syncV2AppliedEventIDs.insert(event.id)
            syncV2Outbox.removeAll { $0.id == event.id }
            return
        }

        if syncV2Conflicts.contains(where: { $0.remoteEvent.id == event.id }) {
            return
        }

        let localState = localSyncV2EntityState(entityType: event.entityType, entityId: event.entityId)

        if shouldCreateSyncV2Conflict(for: event, localState: localState) {
            let conflict = SyncV2Conflict(
                detectedAt: Date(),
                entityType: event.entityType,
                entityId: event.entityId,
                remoteEvent: event,
                localPayload: localState.payload,
                localUpdatedAt: localState.updatedAt,
                localDeletedAt: localState.deletedAt
            )
            syncV2Conflicts.append(conflict)
            return
        }

        if event.operation == .upsert,
           let hash = localState.payloadHash,
           hash == event.payloadHash,
           localState.updatedAt == event.entityUpdatedAt {
            syncV2Outbox.removeAll {
                $0.entityType == event.entityType &&
                $0.entityId == event.entityId &&
                $0.operation == .upsert &&
                $0.payloadHash == event.payloadHash
            }
            syncV2AppliedEventIDs.insert(event.id)
            return
        }

        if event.operation == .delete,
           let deletedAt = localState.deletedAt,
           let remoteDeletedAt = event.deletedAt,
           deletedAt >= remoteDeletedAt {
            syncV2Outbox.removeAll {
                $0.entityType == event.entityType &&
                $0.entityId == event.entityId &&
                $0.operation == .delete
            }
            syncV2AppliedEventIDs.insert(event.id)
            return
        }

        isApplyingSyncV2Remote = true
        applyRemoteSyncV2Event(event, force: false)
        isApplyingSyncV2Remote = false
        syncV2AppliedEventIDs.insert(event.id)
    }

    func shouldCreateSyncV2Conflict(for event: SyncV2Event, localState: SyncV2LocalEntityState) -> Bool {
        if event.operation == .upsert,
           let localHash = localState.payloadHash,
           localHash == event.payloadHash {
            return false
        }

        if event.operation == .delete,
           let localDeletedAt = localState.deletedAt,
           let remoteDeletedAt = event.deletedAt,
           localDeletedAt >= remoteDeletedAt {
            return false
        }

        let localPending = syncV2Outbox.last(where: { $0.entityType == event.entityType && $0.entityId == event.entityId })
        if let localPending {
            let isSameMutation =
                localPending.operation == event.operation &&
                localPending.payloadHash == event.payloadHash &&
                localPending.deletedAt == event.deletedAt
            if !isSameMutation {
                return true
            }
        }

        guard let base = event.baseUpdatedAt else { return false }

        if let localUpdatedAt = localState.updatedAt, localUpdatedAt > base {
            return true
        }
        if let localDeletedAt = localState.deletedAt, localDeletedAt > base {
            return true
        }
        return false
    }

    func localSyncV2EntityState(entityType: SyncV2EntityType, entityId: UUID) -> SyncV2LocalEntityState {
        switch entityType {
        case .transaction:
            let entity = transactions.first(where: { $0.id == entityId })
            let payload = entity.flatMap(encodedSyncV2Payload)
            let deletedAt = deletedTransactionMarkers.first(where: { $0.id == entityId })?.deletedAt
            return SyncV2LocalEntityState(payload: payload, payloadHash: payload.map(sha256Hex), updatedAt: entity?.updatedAt, deletedAt: deletedAt)
        case .category:
            let entity = categories.first(where: { $0.id == entityId })
            let payload = entity.flatMap(encodedSyncV2Payload)
            let deletedAt = deletedCategoryMarkers.first(where: { $0.id == entityId })?.deletedAt
            return SyncV2LocalEntityState(payload: payload, payloadHash: payload.map(sha256Hex), updatedAt: entity?.updatedAt, deletedAt: deletedAt)
        case .account:
            let entity = accounts.first(where: { $0.id == entityId })
            let payload = entity.flatMap(encodedSyncV2Payload)
            let deletedAt = deletedAccountMarkers.first(where: { $0.id == entityId })?.deletedAt
            return SyncV2LocalEntityState(payload: payload, payloadHash: payload.map(sha256Hex), updatedAt: entity?.updatedAt, deletedAt: deletedAt)
        case .budget:
            let entity = budgets.first(where: { $0.id == entityId })
            let payload = entity.flatMap(encodedSyncV2Payload)
            let deletedAt = deletedBudgetMarkers.first(where: { $0.id == entityId })?.deletedAt
            return SyncV2LocalEntityState(payload: payload, payloadHash: payload.map(sha256Hex), updatedAt: entity?.updatedAt, deletedAt: deletedAt)
        case .transfer:
            let entity = transfers.first(where: { $0.id == entityId })
            let payload = entity.flatMap(encodedSyncV2Payload)
            let deletedAt = deletedTransferMarkers.first(where: { $0.id == entityId })?.deletedAt
            return SyncV2LocalEntityState(payload: payload, payloadHash: payload.map(sha256Hex), updatedAt: entity?.updatedAt, deletedAt: deletedAt)
        case .recurring:
            let entity = recurringTransactions.first(where: { $0.id == entityId })
            let payload = entity.flatMap(encodedSyncV2Payload)
            let deletedAt = deletedRecurringMarkers.first(where: { $0.id == entityId })?.deletedAt
            return SyncV2LocalEntityState(payload: payload, payloadHash: payload.map(sha256Hex), updatedAt: entity?.updatedAt, deletedAt: deletedAt)
        }
    }

    func applyRemoteSyncV2Event(_ event: SyncV2Event, force: Bool) {
        switch (event.entityType, event.operation) {
        case (.transaction, .upsert):
            guard let entity = decodedSyncV2Payload(event.payload, as: Transaction.self) else { return }
            if let index = transactions.firstIndex(where: { $0.id == entity.id }) {
                if !force, transactions[index].updatedAt > entity.updatedAt { return }
                transactions[index] = entity
            } else {
                transactions.insert(entity, at: 0)
            }
            transactions.sort(by: { $0.date > $1.date })
            removeDeletionMarkers(matching: [entity.id], from: &deletedTransactionMarkers)
            transactionsStore.save(transactions)
            persistDeletionMarkers(scheduleSync: false)

        case (.transaction, .delete):
            let deletedAt = event.deletedAt ?? event.entityUpdatedAt
            transactions.removeAll(where: { $0.id == event.entityId })
            deletedTransactionMarkers = mergeDeletionMarkers(
                deletedTransactionMarkers,
                [EntityDeletionMarker(id: event.entityId, deletedAt: deletedAt)]
            )
            transactionsStore.save(transactions)
            persistDeletionMarkers(scheduleSync: false)

        case (.category, .upsert):
            guard let entity = decodedSyncV2Payload(event.payload, as: Category.self) else { return }
            if let index = categories.firstIndex(where: { $0.id == entity.id }) {
                if !force, categories[index].updatedAt > entity.updatedAt { return }
                categories[index] = entity
            } else {
                categories.append(entity)
            }
            categories.sort {
                if $0.type != $1.type { return $0.type.rawValue < $1.type.rawValue }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }
            removeDeletionMarkers(matching: [entity.id], from: &deletedCategoryMarkers)
            categoriesStore.save(categories)
            persistDeletionMarkers(scheduleSync: false)

        case (.category, .delete):
            let deletedAt = event.deletedAt ?? event.entityUpdatedAt
            categories.removeAll(where: { $0.id == event.entityId })
            deletedCategoryMarkers = mergeDeletionMarkers(
                deletedCategoryMarkers,
                [EntityDeletionMarker(id: event.entityId, deletedAt: deletedAt)]
            )
            categoriesStore.save(categories)
            persistDeletionMarkers(scheduleSync: false)

        case (.account, .upsert):
            guard let entity = decodedSyncV2Payload(event.payload, as: Account.self) else { return }
            if let index = accounts.firstIndex(where: { $0.id == entity.id }) {
                if !force, accounts[index].updatedAt > entity.updatedAt { return }
                accounts[index] = entity
            } else {
                accounts.append(entity)
            }
            removeDeletionMarkers(matching: [entity.id], from: &deletedAccountMarkers)
            accountsStore.save(accounts)
            persistDeletionMarkers(scheduleSync: false)

        case (.account, .delete):
            let deletedAt = event.deletedAt ?? event.entityUpdatedAt
            accounts.removeAll(where: { $0.id == event.entityId })
            if accounts.isEmpty {
                accounts = [Account(id: UUID(), name: "现金", type: .cash, initialBalance: 0)]
            }
            deletedAccountMarkers = mergeDeletionMarkers(
                deletedAccountMarkers,
                [EntityDeletionMarker(id: event.entityId, deletedAt: deletedAt)]
            )
            accountsStore.save(accounts)
            persistDeletionMarkers(scheduleSync: false)

        case (.budget, .upsert):
            guard let entity = decodedSyncV2Payload(event.payload, as: Budget.self) else { return }
            if let index = budgets.firstIndex(where: { $0.id == entity.id }) {
                if !force, budgets[index].updatedAt > entity.updatedAt { return }
                budgets[index] = entity
            } else {
                budgets.append(entity)
            }
            budgets.sort(by: { $0.month > $1.month })
            removeDeletionMarkers(matching: [entity.id], from: &deletedBudgetMarkers)
            budgetsStore.save(budgets)
            persistDeletionMarkers(scheduleSync: false)

        case (.budget, .delete):
            let deletedAt = event.deletedAt ?? event.entityUpdatedAt
            budgets.removeAll(where: { $0.id == event.entityId })
            deletedBudgetMarkers = mergeDeletionMarkers(
                deletedBudgetMarkers,
                [EntityDeletionMarker(id: event.entityId, deletedAt: deletedAt)]
            )
            budgetsStore.save(budgets)
            persistDeletionMarkers(scheduleSync: false)

        case (.transfer, .upsert):
            guard let entity = decodedSyncV2Payload(event.payload, as: Transfer.self) else { return }
            if let index = transfers.firstIndex(where: { $0.id == entity.id }) {
                if !force, transfers[index].updatedAt > entity.updatedAt { return }
                transfers[index] = entity
            } else {
                transfers.append(entity)
            }
            transfers.sort(by: { $0.date > $1.date })
            removeDeletionMarkers(matching: [entity.id], from: &deletedTransferMarkers)
            transfersStore.save(transfers)
            persistDeletionMarkers(scheduleSync: false)

        case (.transfer, .delete):
            let deletedAt = event.deletedAt ?? event.entityUpdatedAt
            transfers.removeAll(where: { $0.id == event.entityId })
            deletedTransferMarkers = mergeDeletionMarkers(
                deletedTransferMarkers,
                [EntityDeletionMarker(id: event.entityId, deletedAt: deletedAt)]
            )
            transfersStore.save(transfers)
            persistDeletionMarkers(scheduleSync: false)

        case (.recurring, .upsert):
            guard let entity = decodedSyncV2Payload(event.payload, as: RecurringTransaction.self) else { return }
            if let index = recurringTransactions.firstIndex(where: { $0.id == entity.id }) {
                if !force, recurringTransactions[index].updatedAt > entity.updatedAt { return }
                recurringTransactions[index] = entity
            } else {
                recurringTransactions.append(entity)
            }
            recurringTransactions.sort(by: { $0.startDate > $1.startDate })
            removeDeletionMarkers(matching: [entity.id], from: &deletedRecurringMarkers)
            recurringTransactionsStore.save(recurringTransactions)
            persistDeletionMarkers(scheduleSync: false)

        case (.recurring, .delete):
            let deletedAt = event.deletedAt ?? event.entityUpdatedAt
            recurringTransactions.removeAll(where: { $0.id == event.entityId })
            deletedRecurringMarkers = mergeDeletionMarkers(
                deletedRecurringMarkers,
                [EntityDeletionMarker(id: event.entityId, deletedAt: deletedAt)]
            )
            recurringTransactionsStore.save(recurringTransactions)
            persistDeletionMarkers(scheduleSync: false)
        }
    }
}
