import Foundation

/// Pure geometry for one calendar month: how many days it has, how many leading blank cells
/// the heat grid needs (so day 1 lands under the right weekday), and per-day date math.
/// Fully testable; no SwiftUI, no app state.
struct MonthContext: Equatable {
    let year: Int
    let month: Int           // 1...12

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// The month containing `date`.
    init(containing date: Date, cal: Calendar) {
        let c = cal.dateComponents([.year, .month], from: date)
        self.year = c.year ?? 2000
        self.month = c.month ?? 1
    }

    /// First day of this month at start-of-day.
    func firstDay(cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }

    var daysInMonth: Int {
        var c = Calendar.current
        c.timeZone = .current
        let date = c.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
        return c.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// Number of empty cells before day 1, honoring the calendar's first weekday.
    func leadingBlanks(cal: Calendar) -> Int {
        let weekday = cal.component(.weekday, from: firstDay(cal: cal)) // 1...7, Sun=1 by default
        return (weekday - cal.firstWeekday + 7) % 7
    }

    var leadingBlanks: Int { leadingBlanks(cal: Calendar.current) }

    /// Localized one-letter weekday header symbols, rotated to the calendar's first weekday.
    var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7] }
    }

    func date(forDay day: Int, cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day)) ?? firstDay(cal: cal)
    }

    func isToday(_ day: Int, cal: Calendar) -> Bool {
        cal.isDateInToday(date(forDay: day, cal: cal))
    }

    func isFuture(_ day: Int, cal: Calendar) -> Bool {
        cal.startOfDay(for: date(forDay: day, cal: cal)) > cal.startOfDay(for: .now)
    }

    /// Display title, e.g. "June 2026".
    var title: String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: firstDay(cal: Calendar.current))
    }

    /// Previous / next month.
    func adding(months: Int, cal: Calendar) -> MonthContext {
        let base = firstDay(cal: cal)
        let next = cal.date(byAdding: .month, value: months, to: base) ?? base
        return MonthContext(containing: next, cal: cal)
    }

    /// True when this month is the current calendar month (the free-tier boundary).
    func isCurrentMonth(cal: Calendar) -> Bool {
        let now = cal.dateComponents([.year, .month], from: .now)
        return now.year == year && now.month == month
    }

    /// True when this month is strictly after the current month (no logging in the future).
    func isAfterCurrentMonth(cal: Calendar) -> Bool {
        let now = MonthContext(containing: .now, cal: cal)
        if year != now.year { return year > now.year }
        return month > now.month
    }
}
