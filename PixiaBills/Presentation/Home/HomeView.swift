import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: BillsStore
    @Binding var month: Date

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                MonthPicker(month: $month)
                    .padding(.top, 8)

                SummaryHeader(summary: store.monthlySummary(for: month))
                    .padding(.horizontal, 16)

                List {
                    let sections = store.daySections(inMonth: month)
                    ForEach(sections) { section in
                        Section(header: DaySectionHeader(section: section)) {
                            ForEach(section.transactions) { tx in
                                TransactionRow(transaction: tx)
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
            .navigationTitle("明细")
            .navigationBarTitleDisplayMode(.inline)
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
