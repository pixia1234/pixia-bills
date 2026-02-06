import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: BillsStore
    @Binding var month: Date

    @State private var type: TransactionType = .expense

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MonthPicker(month: $month)
                        .padding(.top, 8)

                    Picker("", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    TrendCard(dailyTotals: store.dailyTotals(inMonth: month, type: type), type: type)
                        .padding(.horizontal, 16)

                    CategoryBreakdownCard(items: store.categoryTotals(inMonth: month, type: type))
                        .padding(.horizontal, 16)

                    TopTransactionsCard(transactions: store.topTransactions(inMonth: month, type: type))
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("图表")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TrendCard: View {
    let dailyTotals: [DailyTotal]
    let type: TransactionType

    private var values: [Double] {
        dailyTotals.map { NSDecimalNumber(decimal: $0.total).doubleValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(type.displayName)趋势（本月）")
                .font(.headline)

            LineChart(values: values)
                .frame(height: 140)

            let total = dailyTotals.reduce(Decimal(0)) { $0 + $1.total }
            Text("合计：\(MoneyFormatter.string(from: total))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color("SecondaryBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CategoryBreakdownCard: View {
    let items: [CategoryTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分类占比")
                .font(.headline)

            if items.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let total = items.reduce(Decimal(0)) { $0 + $1.total }
                ForEach(items.prefix(8)) { item in
                    CategoryBreakdownRow(item: item, total: total)
                }
            }
        }
        .padding(12)
        .background(Color("SecondaryBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CategoryBreakdownRow: View {
    let item: CategoryTotal
    let total: Decimal

    private var ratio: Double {
        let totalDouble = NSDecimalNumber(decimal: total).doubleValue
        guard totalDouble > 0 else { return 0 }
        return NSDecimalNumber(decimal: item.total).doubleValue / totalDouble
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.category.iconName)
                .frame(width: 18)

            Text(item.category.name)
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(Color("PrimaryYellow"))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)

            Text("\(Int(ratio * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)

            Text(MoneyFormatter.string(from: item.total))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
        .frame(height: 18)
    }
}

private struct TopTransactionsCard: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最大 3 笔交易")
                .font(.headline)

            if transactions.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(transactions) { tx in
                    TransactionRow(transaction: tx)
                }
            }
        }
        .padding(12)
        .background(Color("SecondaryBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct LineChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let maxValue = values.max() ?? 0
            let minValue = values.min() ?? 0
            let range = max(maxValue - minValue, 0.0001)
            let stepX = proxy.size.width / CGFloat(max(values.count - 1, 1))

            Path { path in
                for index in values.indices {
                    let x = CGFloat(index) * stepX
                    let y = proxy.size.height - (CGFloat((values[index] - minValue) / range) * proxy.size.height)
                    if index == values.startIndex {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color("PrimaryYellow"), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

