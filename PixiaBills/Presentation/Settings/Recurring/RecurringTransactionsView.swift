import SwiftUI

struct RecurringTransactionsView: View {
    @EnvironmentObject private var store: BillsStore

    @State private var showingEditor = false

    var body: some View {
        List {
            Section(header: Text("周期记账")) {
                if store.recurringTransactions.isEmpty {
                    Text("暂无周期规则")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.recurringTransactions.sorted(by: { $0.createdAt > $1.createdAt })) { recurring in
                        RecurringRow(recurring: recurring)
                    }
                    .onDelete { offsets in
                        let list = store.recurringTransactions.sorted(by: { $0.createdAt > $1.createdAt })
                        let ids = offsets.compactMap { index in
                            guard list.indices.contains(index) else { return nil }
                            return list[index].id
                        }
                        store.deleteRecurringTransactions(ids: ids)
                    }
                }
            }
        }
        .navigationTitle("周期记账")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            RecurringEditorSheet()
                .environmentObject(store)
        }
    }
}

private struct RecurringRow: View {
    @EnvironmentObject private var store: BillsStore
    let recurring: RecurringTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.category(for: recurring.categoryId)?.name ?? "未知分类")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Toggle("", isOn: Binding(
                    get: { recurring.isEnabled },
                    set: { store.toggleRecurringTransaction(recurring, isEnabled: $0) }
                ))
            }

            HStack(spacing: 10) {
                Text(recurring.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary)

                Text(recurring.frequency.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary)

                Text("\(MoneyFormatter.string(from: recurring.amount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("起始：\(DateFormatter.dayTitle.string(from: recurring.startDate))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct RecurringEditorSheet: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType = .expense
    @State private var categoryId: UUID?
    @State private var accountId: UUID?
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var frequency: RecurringTransaction.Frequency = .monthly
    @State private var startDate: Date = Date()
    @State private var hasEndDate = false
    @State private var endDate: Date = Date()

    private var categories: [Category] {
        store.categories(ofType: type)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基础信息")) {
                    Picker("类型", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }

                    Picker("分类", selection: Binding<UUID>(
                        get: { categoryId ?? categories.first?.id ?? UUID() },
                        set: { categoryId = $0 }
                    )) {
                        ForEach(categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }

                    Picker("账户", selection: Binding<UUID>(
                        get: { accountId ?? store.defaultAccountId },
                        set: { accountId = $0 }
                    )) {
                        ForEach(store.accounts) { account in
                            Text(account.name).tag(account.id)
                        }
                    }
                }

                Section(header: Text("金额与周期")) {
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("频率", selection: $frequency) {
                        ForEach(RecurringTransaction.Frequency.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                }

                Section(header: Text("日期")) {
                    DatePicker("开始", selection: $startDate, displayedComponents: [.date])

                    Toggle("设置结束日期", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("结束", selection: $endDate, displayedComponents: [.date])
                    }
                }

                Section(header: Text("备注")) {
                    TextField("可选", text: $note)
                }
            }
            .navigationTitle("新增周期")
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
                if categoryId == nil {
                    categoryId = categories.first?.id
                }
                if accountId == nil {
                    accountId = store.accounts.first?.id
                }
            }
            .onChange(of: type) { _ in
                categoryId = categories.first?.id
            }
        }
    }

    private var canSave: Bool {
        guard let amount = DecimalParser.parse(amountText), amount > 0 else { return false }
        guard categoryId != nil, accountId != nil else { return false }
        if hasEndDate {
            return endDate >= startDate
        }
        return true
    }

    private func save() {
        guard let amount = DecimalParser.parse(amountText), amount > 0 else { return }
        guard let categoryId, let accountId else { return }

        store.addRecurringTransaction(
            type: type,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            note: note,
            frequency: frequency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil
        )
        dismiss()
    }
}

