import Foundation

extension Calendar {
    func monthDateInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
    }

    func daysInMonth(containing date: Date) -> [Date] {
        guard let interval = dateInterval(of: .month, for: date) else { return [] }
        var days: [Date] = []
        var current = startOfDay(for: interval.start)

        while current < interval.end {
            days.append(current)
            current = self.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86_400)
        }
        return days
    }
}

