import Foundation

/// A pure, value-type snapshot of one logged day. The whole streak/stats pipeline operates on
/// arrays of these so it is fully testable without SwiftData or a running app.
struct DayEntry: Equatable {
    let day: Date          // start-of-day in the working calendar
    let status: DayStatus
    let slipCost: Double
}

/// Pure functions for the no-spend grid: streaks, money saved, slip analytics, badges.
/// Everything here is `nonisolated`/`static` and calendar-injected, so it is deterministic and
/// unit-testable. The app derives all displayed numbers from these — nothing is stored as truth.
enum StreakEngine {

    // MARK: Streaks (consecutive no-spend calendar days)

    /// Current run of consecutive no-spend days ending today (or, if today isn't logged yet,
    /// ending yesterday — so the streak "holds" until the day actually ends).
    /// A logged slip breaks the run; a missing (unlogged) day also breaks it.
    static func currentStreak(entries: [DayEntry], today: Date, cal: Calendar) -> Int {
        let noSpend = noSpendDaySet(entries, cal: cal)
        guard !noSpend.isEmpty else { return 0 }
        var day = cal.startOfDay(for: today)
        // If today isn't a logged no-spend day, the streak still stands as of yesterday.
        if !noSpend.contains(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day),
                  noSpend.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while noSpend.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Longest run of consecutive no-spend days ever recorded.
    static func longestStreak(entries: [DayEntry], cal: Calendar) -> Int {
        let sorted = noSpendDaySet(entries, cal: cal).sorted()
        guard !sorted.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<sorted.count {
            if let next = cal.date(byAdding: .day, value: 1, to: sorted[i - 1]), next == sorted[i] {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    // MARK: Money / counts

    static func noSpendCount(_ entries: [DayEntry]) -> Int {
        entries.filter { $0.status == .noSpend }.count
    }

    static func slipCount(_ entries: [DayEntry]) -> Int {
        entries.filter { $0.status == .slip }.count
    }

    /// Total of all logged slip costs.
    static func totalSlipSpend(_ entries: [DayEntry]) -> Double {
        entries.filter { $0.status == .slip }.reduce(0) { $0 + max(0, $1.slipCost) }
    }

    /// Average daily slip used as the "what a typical spending day costs you" baseline.
    /// Defaults to a gentle estimate when there is not yet a slip to learn from.
    static func averageSlip(_ entries: [DayEntry], fallback: Double = 20) -> Double {
        let slips = entries.filter { $0.status == .slip }.map { max(0, $0.slipCost) }
        guard !slips.isEmpty else { return fallback }
        return slips.reduce(0, +) / Double(slips.count)
    }

    /// Estimated money saved: every no-spend day "saves" the user's average slip amount.
    /// Honest framing — it's an estimate the UI labels as such, never a real bank figure.
    static func estimatedSaved(_ entries: [DayEntry]) -> Double {
        let avg = averageSlip(entries)
        return Double(noSpendCount(entries)) * avg
    }

    // MARK: Badges (earned milestones)

    static let streakBadgeThresholds = [3, 7, 14, 30, 60, 100]

    /// Streak-milestone badges the user has earned, given their best-ever streak.
    static func earnedBadges(longestStreak: Int) -> [Badge] {
        streakBadgeThresholds
            .filter { longestStreak >= $0 }
            .map { Badge(days: $0) }
    }

    /// The next streak badge the user hasn't earned yet (for "x to go" UI), if any.
    static func nextBadge(longestStreak: Int) -> Badge? {
        streakBadgeThresholds.first { longestStreak < $0 }.map { Badge(days: $0) }
    }

    // MARK: Helpers

    /// Set of start-of-day dates that are logged as no-spend (slips excluded).
    static func noSpendDaySet(_ entries: [DayEntry], cal: Calendar) -> Set<Date> {
        Set(entries.filter { $0.status == .noSpend }.map { cal.startOfDay(for: $0.day) })
    }
}

/// An earned achievement badge tied to a streak milestone.
struct Badge: Identifiable, Equatable {
    let days: Int
    var id: Int { days }

    var title: String {
        switch days {
        case 3: return "Getting Started"
        case 7: return "One Week Strong"
        case 14: return "Two Weeks"
        case 30: return "One Month"
        case 60: return "Two Months"
        case 100: return "Centurion"
        default: return "\(days)-Day Streak"
        }
    }

    var subtitle: String { "\(days) no-spend days in a row" }

    /// SF Symbol for the badge tile.
    var symbol: String {
        switch days {
        case 3: return "leaf.fill"
        case 7: return "flame.fill"
        case 14: return "bolt.fill"
        case 30: return "star.fill"
        case 60: return "crown.fill"
        case 100: return "trophy.fill"
        default: return "rosette"
        }
    }
}
