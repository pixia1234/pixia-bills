import Foundation

extension Date {
    func startOfDay(using calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}

