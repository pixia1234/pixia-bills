import SwiftUI

struct MonthPicker: View {
    @Binding var month: Date

    var body: some View {
        HStack(spacing: 14) {
            Button {
                month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)

            Text(DateFormatter.monthTitle.string(from: month))
                .font(.system(size: 16, weight: .bold))

            Button {
                month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

