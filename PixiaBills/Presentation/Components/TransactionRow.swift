import SwiftUI

struct TransactionRow: View {
    @EnvironmentObject private var store: BillsStore
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            let category = store.category(for: transaction.categoryId)
            Image(systemName: category?.iconName ?? "questionmark")
                .foregroundColor(.primary)
                .frame(width: 34, height: 34)
                .background(Color("SecondaryBackground"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(category?.name ?? "未知分类")
                    .font(.system(size: 16, weight: .semibold))

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(DateFormatter.timeOnly.string(from: transaction.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(amountText)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(transaction.type == .expense ? .primary : .green)
        }
        .padding(.vertical, 4)
    }

    private var amountText: String {
        let value = MoneyFormatter.string(from: transaction.amount)
        switch transaction.type {
        case .expense:
            return "-\(value)"
        case .income:
            return "+\(value)"
        }
    }
}
