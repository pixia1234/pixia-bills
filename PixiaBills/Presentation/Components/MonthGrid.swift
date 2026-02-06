import SwiftUI

struct MonthGrid<CellContent: View>: View {
    let month: Date
    let onSelectDay: (Date) -> Void
    let cellContent: (Date) -> CellContent

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            WeekdayHeader()

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(gridItems) { item in
                    if let date = item.date {
                        Button {
                            onSelectDay(date)
                        } label: {
                            cellContent(date)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 58)
                    }
                }
            }
        }
    }

    private var gridItems: [MonthGridItem] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = calendar.startOfDay(for: interval.start)
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7

        let days = calendar.daysInMonth(containing: month)
        var dates: [Date?] = Array(repeating: nil, count: leadingEmpty)
        dates.append(contentsOf: days.map { Optional($0) })

        while dates.count % 7 != 0 {
            dates.append(nil)
        }
        return dates.enumerated().map { MonthGridItem(id: $0.offset, date: $0.element) }
    }
}

private struct MonthGridItem: Identifiable {
    let id: Int
    let date: Date?
}

private struct WeekdayHeader: View {
    private let symbols: [String] = {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(0, min(calendar.firstWeekday - 1, symbols.count))
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
