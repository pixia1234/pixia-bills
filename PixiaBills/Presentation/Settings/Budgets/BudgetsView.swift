import SwiftUI

struct BudgetsView: View {
    @EnvironmentObject private var store: BillsStore

    @State private var type: TransactionType = .expense
    @State private var month: Date = Date()
    @State private var showingEditor = false

    var body: some View {
        List {
            Section {
                MonthPicker(month: $month)

                Picker("类型", selection: $type) {
                    ForEach(TransactionType.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("预算使用")) {
                let usages = store.budgetUsages(inMonth: month, type: type)
                if usages.isEmpty {
                    Text("当前月份暂无预算")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(usages) { usage in
                        BudgetUsageRow(usage: usage)
                    }
                    .onDelete { offsets in
                        for index in offsets where usages.indices.contains(index) {
                            store.deleteBudget(usages[index].budget)
                        }
                    }
                }
            }
        }
        .navigationTitle("预算")
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
            BudgetEditorSheet(month: month, type: type)
                .environmentObject(store)
        }
    }
}

private struct BudgetUsageRow: View {
    @EnvironmentObject private var store: BillsStore
    let usage: BudgetUsage

    private var barColor: Color {
        usage.progress > 1 ? .red : Color("PrimaryYellow")
    }

    private var subtitle: String {
        "已用 \(MoneyFormatter.string(from: usage.spent)) / 预算 \(MoneyFormatter.string(from: usage.budget.limit))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.categoryName(for: usage.budget.categoryId))
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Text(usage.remaining >= 0 ? "剩余 \(MoneyFormatter.string(from: usage.remaining))" : "超支 \(MoneyFormatter.string(from: absDecimal(usage.remaining)))")
                    .font(.caption)
                    .foregroundColor(usage.remaining >= 0 ? .secondary : .red)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(barColor)
                        .frame(width: proxy.size.width * usage.progress)
                }
            }
            .frame(height: 8)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func absDecimal(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }
}

private struct BudgetEditorSheet: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    let month: Date
    let type: TransactionType

    @State private var selectedCategoryId: UUID?
    @State private var limitText: String = ""

    private var categories: [Category] {
        store.categories(ofType: type)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("范围")) {
                    Picker("分类", selection: Binding<UUID?>(
                        get: { selectedCategoryId },
                        set: { selectedCategoryId = $0 }
                    )) {
                        Text("全部分类").tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                }

                Section(header: Text("预算金额")) {
                    TextField("0", text: $limitText)
                        .keyboardType(.decimalPad)
                        .onChange(of: limitText) { value in
                            let sanitized = value.decimalInputSanitized
                            if sanitized != value {
                                limitText = sanitized
                            }
                        }
                }
            }
            .navigationTitle("新增预算")
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
        }
    }

    private var canSave: Bool {
        guard let limit = DecimalParser.parse(limitText) else { return false }
        return limit > 0
    }

    private func save() {
        guard let limit = DecimalParser.parse(limitText), limit > 0 else { return }
        store.upsertBudget(month: month, type: type, categoryId: selectedCategoryId, limit: limit)
        dismiss()
    }
}

