import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: BillsStore
    @Binding var month: Date

    @State private var selectedDay: IdentifiableDate?

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                MonthPicker(month: $month)
                    .padding(.top, 8)

                MonthGrid(
                    month: month,
                    onSelectDay: { day in
                        selectedDay = IdentifiableDate(date: day)
                    },
                    cellContent: { day in
                        let expense = store.transactions(onDay: day)
                            .filter { $0.type == .expense }
                            .reduce(Decimal(0)) { $0 + $1.amount }
                        return CalendarDayCell(day: day, expense: expense)
                    }
                )
                .padding(.horizontal, 12)

                Spacer(minLength: 0)
            }
            .navigationTitle("日历")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedDay) { day in
            DayTransactionsSheet(day: day.date)
        }
    }
}

private struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

private struct CalendarDayCell: View {
    let day: Date
    let expense: Decimal

    var body: some View {
        VStack(spacing: 4) {
            Text(Calendar.current.component(.day, from: day).description)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if expense > 0 {
                Text("-\(MoneyFormatter.string(from: expense))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(" ")
                    .font(.caption2)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(height: 58)
        .background(Color("SecondaryBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DayTransactionsSheet: View {
    @EnvironmentObject private var store: BillsStore
    @Environment(\.dismiss) private var dismiss

    let day: Date

    var body: some View {
        NavigationView {
            List {
                let txs = store.transactions(onDay: day).sorted(by: { $0.date > $1.date })
                ForEach(txs) { tx in
                    TransactionRow(transaction: tx)
                }
            }
            .navigationTitle(DateFormatter.dayTitle.string(from: day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
