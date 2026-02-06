import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var month: Date

    @State private var selectedTransactionId: UUID?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .onAppear {
            selectDefaultTransactionIfNeeded(force: false)
        }
        .onChange(of: month) { _ in
            selectDefaultTransactionIfNeeded(force: true)
        }
        .onChange(of: store.transactions.map(\.id)) { _ in
            validateSelection()
        }
    }

    private var monthSections: [TransactionDaySection] {
        store.daySections(inMonth: month)
    }

    private var selectedTransaction: Transaction? {
        guard let selectedTransactionId else { return nil }
        return monthSections
            .flatMap(\.transactions)
            .first(where: { $0.id == selectedTransactionId })
    }

    private var compactLayout: some View {
        NavigationView {
            mainColumn(selectionEnabled: false)
        }
    }

    private var regularLayout: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationSplitView {
                    mainColumn(selectionEnabled: true)
                } detail: {
                    detailColumn
                }
            } else {
                legacyRegularLayout
            }
        }
    }

    private var legacyRegularLayout: some View {
        NavigationView {
            mainColumn(selectionEnabled: true)
            detailColumn
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let transaction = selectedTransaction {
            TransactionDetailPane(
                transaction: transaction,
                onDelete: {
                    deleteTransaction(transaction)
                }
            )
        } else {
            EmptySelectionView()
        }
    }

    private func mainColumn(selectionEnabled: Bool) -> some View {
        VStack(spacing: 12) {
            MonthPicker(month: $month)
                .padding(.top, 8)

            SummaryHeader(summary: store.monthlySummary(for: month))
                .padding(.horizontal, 16)

            transactionsList(selectionEnabled: selectionEnabled)
        }
        .navigationTitle("明细")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func transactionsList(selectionEnabled: Bool) -> some View {
        List {
            ForEach(monthSections) { section in
                Section(header: DaySectionHeader(section: section)) {
                    ForEach(section.transactions) { tx in
                        if selectionEnabled {
                            Button {
                                selectedTransactionId = tx.id
                            } label: {
                                TransactionRow(transaction: tx)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                selectedTransactionId == tx.id
                                    ? Color("PrimaryYellow").opacity(0.18)
                                    : Color.clear
                            )
                        } else {
                            NavigationLink {
                                TransactionDetailRoute(transaction: tx) {
                                    deleteTransaction(tx)
                                }
                            } label: {
                                TransactionRow(transaction: tx)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids: [UUID] = offsets.compactMap { index in
                            guard section.transactions.indices.contains(index) else { return nil }
                            return section.transactions[index].id
                        }
                        store.deleteTransactions(ids: ids)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func deleteTransaction(_ transaction: Transaction) {
        store.deleteTransactions(ids: [transaction.id])
        selectedTransactionId = nil
        selectDefaultTransactionIfNeeded(force: false)
    }

    private func selectDefaultTransactionIfNeeded(force: Bool) {
        let first = monthSections.first?.transactions.first?.id
        if force {
            selectedTransactionId = first
            return
        }
        if selectedTransactionId == nil {
            selectedTransactionId = first
        }
    }

    private func validateSelection() {
        guard let selectedTransactionId else {
            selectDefaultTransactionIfNeeded(force: false)
            return
        }
        let stillExists = monthSections
            .flatMap(\.transactions)
            .contains(where: { $0.id == selectedTransactionId })
        if !stillExists {
            self.selectedTransactionId = nil
            selectDefaultTransactionIfNeeded(force: false)
        }
    }
}

private struct TransactionDetailRoute: View {
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction
    let onDelete: () -> Void

    var body: some View {
        TransactionDetailPane(transaction: transaction) {
            onDelete()
            dismiss()
        }
    }
}

private struct DaySectionHeader: View {
    let section: TransactionDaySection

    var body: some View {
        HStack {
            Text(DateFormatter.dayTitle.string(from: section.date))
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if section.totalExpense > 0 {
                Text("-\(MoneyFormatter.string(from: section.totalExpense))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct TransactionDetailPane: View {
    @EnvironmentObject private var store: BillsStore

    let transaction: Transaction
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: category?.iconName ?? "questionmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 56, height: 56)
                    .background(Color("SecondaryBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(category?.name ?? "未知分类")
                        .font(.title3.weight(.semibold))
                    Text(account?.name ?? "未知账户")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            DetailRow(title: "金额", value: amountText)
            DetailRow(title: "时间", value: "\(DateFormatter.dayTitle.string(from: transaction.date)) \(DateFormatter.timeOnly.string(from: transaction.date))")

            if let note = transaction.note, !note.isEmpty {
                DetailRow(title: "备注", value: note)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除这笔流水", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .navigationTitle("流水详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var category: Category? {
        store.category(for: transaction.categoryId)
    }

    private var account: Account? {
        store.account(for: transaction.accountId)
    }

    private var amountText: String {
        let prefix = transaction.type == .expense ? "-" : "+"
        return prefix + MoneyFormatter.string(from: transaction.amount)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EmptySelectionView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text("请选择一笔流水")
                .font(.headline)
            Text("iPad 下支持分栏查看明细")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
