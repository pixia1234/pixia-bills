import SwiftUI

struct AccountsView: View {
    @EnvironmentObject private var store: BillsStore

    @State private var accountSheet: AccountSheet?
    @State private var showingTransferEditor = false

    var body: some View {
        List {
            Section(header: Text("账户余额")) {
                let balances = store.accountBalances()
                if balances.isEmpty {
                    Text("暂无账户")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(balances) { item in
                        Button {
                            accountSheet = .edit(item.account)
                        } label: {
                            AccountBalanceRow(item: item)
                        }
                    }
                    .onDelete { offsets in
                        let ids: [UUID] = offsets.compactMap { index in
                            guard balances.indices.contains(index) else { return nil }
                            return balances[index].account.id
                        }
                        store.deleteAccounts(ids: ids)
                    }
                }
            }

            Section(header: Text("转账记录")) {
                let transfers = store.transfers(inMonth: Date())
                if transfers.isEmpty {
                    Text("本月暂无转账")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(transfers) { transfer in
                        TransferRow(transfer: transfer)
                    }
                }
            }
        }
        .navigationTitle("账户与转账")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingTransferEditor = true
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }

                Button {
                    accountSheet = .create
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $accountSheet) { destination in
            AccountEditorSheet(account: destination.account)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingTransferEditor) {
            TransferEditorSheet()
                .environmentObject(store)
        }
    }
}

private enum AccountSheet: Identifiable {
    case create
    case edit(Account)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let account):
            return account.id.uuidString
        }
    }

    var account: Account? {
        switch self {
        case .create:
            return nil
        case .edit(let account):
            return account
        }
    }
}

private struct AccountBalanceRow: View {
    let item: AccountBalance

    private var balanceColor: Color {
        item.balance < 0 ? .red : .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(.primary)
                .frame(width: 34, height: 34)
                .background(Color("SecondaryBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.account.name)
                    .font(.system(size: 16, weight: .semibold))

                Text(item.account.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(MoneyFormatter.string(from: item.balance))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(balanceColor)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.account.type {
        case .cash:
            return "banknote"
        case .bank:
            return "building.columns"
        case .credit:
            return "creditcard"
        }
    }
}

private struct TransferRow: View {
    @EnvironmentObject private var store: BillsStore
    let transfer: Transfer

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundColor(.primary)
                .frame(width: 34, height: 34)
                .background(Color("SecondaryBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.account(for: transfer.fromAccountId)?.name ?? "未知") → \(store.account(for: transfer.toAccountId)?.name ?? "未知")")
                    .font(.system(size: 15, weight: .semibold))

                Text(DateFormatter.dayTitle.string(from: transfer.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(MoneyFormatter.string(from: transfer.amount))
                .font(.system(size: 15, weight: .bold))
        }
        .padding(.vertical, 4)
    }
}

private struct AccountEditorSheet: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    let account: Account?

    @State private var name: String = ""
    @State private var type: Account.AccountType = .cash
    @State private var initialBalanceText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("账户信息")) {
                    TextField("名称", text: $name)

                    Picker("类型", selection: $type) {
                        ForEach(Account.AccountType.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                }

                Section(header: Text("初始余额")) {
                    TextField("0", text: $initialBalanceText)
                        .keyboardType(.decimalPad)
                        .onChange(of: initialBalanceText) { value in
                            let sanitized = value.decimalInputSanitized
                            if sanitized != value {
                                initialBalanceText = sanitized
                            }
                        }
                }
            }
            .navigationTitle(account == nil ? "新增账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let account {
                    name = account.name
                    type = account.type
                    initialBalanceText = account.initialBalance.plainString
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let balance = DecimalParser.parse(initialBalanceText) ?? 0

        if var account {
            account.name = trimmed
            account.type = type
            account.initialBalance = balance
            store.updateAccount(account)
        } else {
            store.addAccount(name: trimmed, type: type, initialBalance: balance)
        }
        dismiss()
    }
}

private struct TransferEditorSheet: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    @State private var fromAccountId: UUID?
    @State private var toAccountId: UUID?
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("账户")) {
                    Picker("转出", selection: Binding<UUID>(
                        get: { fromAccountId ?? store.defaultAccountId },
                        set: { fromAccountId = $0 }
                    )) {
                        ForEach(store.accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }

                    Picker("转入", selection: Binding<UUID>(
                        get: { toAccountId ?? defaultToAccountId },
                        set: { toAccountId = $0 }
                    )) {
                        ForEach(store.accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }
                }

                Section(header: Text("金额与时间")) {
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: amountText) { value in
                            let sanitized = value.decimalInputSanitized
                            if sanitized != value {
                                amountText = sanitized
                            }
                        }
                    DatePicker("日期", selection: $date, displayedComponents: [.date])
                }

                Section(header: Text("备注")) {
                    TextField("可选", text: $note)
                }
            }
            .navigationTitle("账户转账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if fromAccountId == nil {
                    fromAccountId = store.accounts.first?.id
                }
                if toAccountId == nil {
                    toAccountId = store.accounts.dropFirst().first?.id ?? store.accounts.first?.id
                }
            }
        }
    }

    private var defaultToAccountId: UUID {
        store.accounts.dropFirst().first?.id ?? store.defaultAccountId
    }

    private var canSave: Bool {
        guard let amount = DecimalParser.parse(amountText), amount > 0 else { return false }
        guard let fromAccountId, let toAccountId else { return false }
        return fromAccountId != toAccountId
    }

    private func save() {
        guard let amount = DecimalParser.parse(amountText), amount > 0 else { return }
        guard let fromAccountId, let toAccountId else { return }

        store.addTransfer(
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            amount: amount,
            date: date,
            note: note
        )
        dismiss()
    }
}
