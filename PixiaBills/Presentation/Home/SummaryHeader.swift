import SwiftUI

struct SummaryHeader: View {
    let summary: MonthlySummary

    var body: some View {
        HStack(spacing: 12) {
            SummaryItem(title: "收入", value: MoneyFormatter.string(from: summary.income), valueColor: .green)
            SummaryItem(title: "支出", value: MoneyFormatter.string(from: summary.expense), valueColor: .primary)
            SummaryItem(title: "结余", value: MoneyFormatter.string(from: summary.balance), valueColor: .primary)
        }
        .padding(12)
        .background(Color("SecondaryBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SummaryItem: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

