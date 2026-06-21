import XCTest
import SwiftData
@testable import NoSpend

/// Tests for the pure no-spend logic: streaks, money, badges, month geometry, the SwiftData-backed
/// one-log-per-day model, and the StoreKit product config.
final class NoSpendLogicTests: XCTestCase {

    private let cal = Calendar.current

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: .now))!
    }

    private func entries(noSpend: [Int], slips: [(Int, Double)] = []) -> [DayEntry] {
        var e = noSpend.map { DayEntry(day: day($0), status: .noSpend, slipCost: 0) }
        e += slips.map { DayEntry(day: day($0.0), status: .slip, slipCost: $0.1) }
        return e
    }

    // MARK: Current streak

    func testCurrentStreakCountsTodayBackwards() {
        XCTAssertEqual(StreakEngine.currentStreak(entries: entries(noSpend: [0, 1, 2]), today: .now, cal: cal), 3)
    }

    func testCurrentStreakHoldsWhenTodayNotYetLogged() {
        // Yesterday & the day before logged, not today -> streak still 2 (today still possible).
        XCTAssertEqual(StreakEngine.currentStreak(entries: entries(noSpend: [1, 2]), today: .now, cal: cal), 2)
    }

    func testCurrentStreakBreaksOnSlipAndGap() {
        // Today no-spend, day 1 was a slip -> current streak is just 1.
        let e = entries(noSpend: [0, 2, 3], slips: [(1, 12)])
        XCTAssertEqual(StreakEngine.currentStreak(entries: e, today: .now, cal: cal), 1)
        XCTAssertEqual(StreakEngine.currentStreak(entries: [], today: .now, cal: cal), 0)
    }

    // MARK: Longest streak

    func testLongestStreakPicksBestRun() {
        // Runs: {0,1,2} length 3 and {5,6} length 2 -> longest 3.
        XCTAssertEqual(StreakEngine.longestStreak(entries: entries(noSpend: [0, 1, 2, 5, 6]), cal: cal), 3)
        XCTAssertEqual(StreakEngine.longestStreak(entries: [], cal: cal), 0)
    }

    // MARK: Money

    func testMoneyCountsAndTotals() {
        let e = entries(noSpend: [0, 1, 2, 3], slips: [(4, 10), (5, 30)])
        XCTAssertEqual(StreakEngine.noSpendCount(e), 4)
        XCTAssertEqual(StreakEngine.slipCount(e), 2)
        XCTAssertEqual(StreakEngine.totalSlipSpend(e), 40, accuracy: 0.001)
        // Average slip = 20; estimatedSaved = 4 no-spend days * 20.
        XCTAssertEqual(StreakEngine.averageSlip(e), 20, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.estimatedSaved(e), 80, accuracy: 0.001)
    }

    func testAverageSlipFallbackWhenNoSlips() {
        let e = entries(noSpend: [0, 1])
        XCTAssertEqual(StreakEngine.averageSlip(e, fallback: 15), 15, accuracy: 0.001)
        XCTAssertEqual(StreakEngine.estimatedSaved(e), 2 * 20, accuracy: 0.001) // default fallback 20
    }

    // MARK: Badges

    func testEarnedAndNextBadges() {
        XCTAssertEqual(StreakEngine.earnedBadges(longestStreak: 0).count, 0)
        XCTAssertEqual(StreakEngine.earnedBadges(longestStreak: 10).map(\.days), [3, 7])
        XCTAssertEqual(StreakEngine.earnedBadges(longestStreak: 100).count, StreakEngine.streakBadgeThresholds.count)
        XCTAssertEqual(StreakEngine.nextBadge(longestStreak: 10)?.days, 14)
        XCTAssertNil(StreakEngine.nextBadge(longestStreak: 100))
    }

    // MARK: MonthContext geometry

    func testMonthContextDaysAndLeadingBlanks() {
        // June 2026: 30 days. June 1 2026 is a Monday.
        let june = MonthContext(year: 2026, month: 6)
        XCTAssertEqual(june.daysInMonth, 30)
        // February 2024 is a leap year -> 29 days.
        XCTAssertEqual(MonthContext(year: 2024, month: 2).daysInMonth, 29)
        // weekday symbols always have 7 entries.
        XCTAssertEqual(june.weekdaySymbols.count, 7)
        // Leading blanks are in 0...6.
        XCTAssertTrue((0...6).contains(june.leadingBlanks(cal: cal)))
    }

    func testMonthContextNavigationAndCurrentMonth() {
        let now = MonthContext(containing: .now, cal: cal)
        XCTAssertTrue(now.isCurrentMonth(cal: cal))
        XCTAssertFalse(now.isAfterCurrentMonth(cal: cal))
        let next = now.adding(months: 1, cal: cal)
        XCTAssertTrue(next.isAfterCurrentMonth(cal: cal))
        let prev = now.adding(months: -1, cal: cal)
        XCTAssertFalse(prev.isCurrentMonth(cal: cal))
        XCTAssertFalse(prev.isAfterCurrentMonth(cal: cal))
    }

    // MARK: AppModel — SwiftData one-log-per-day + derived stats

    @MainActor
    private func memoryModel() -> AppModel {
        let c = try! ModelContainer(for: DayLog.self,
                                    configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return AppModel(container: c)
    }

    @MainActor
    func testLogTodayUpdatesStreakAndIsIdempotentPerDay() {
        let model = memoryModel()
        XCTAssertEqual(model.noSpendDays, 0)
        XCTAssertNil(model.todayStatus)

        model.log(date: .now, status: .noSpend)
        XCTAssertEqual(model.noSpendDays, 1)
        XCTAssertEqual(model.currentStreak, 1)
        XCTAssertEqual(model.todayStatus, .noSpend)

        // Re-logging today overwrites — never creates a second row for the same day.
        model.log(date: .now, status: .slip, slipCost: 25, note: "lunch")
        XCTAssertEqual(model.noSpendDays, 0)
        XCTAssertEqual(model.slipDays, 1)
        XCTAssertEqual(model.allLogs().count, 1)
        XCTAssertEqual(model.todayStatus, .slip)
        XCTAssertEqual(model.totalSlipSpend, 25, accuracy: 0.001)
    }

    @MainActor
    func testClearLogRemovesDayAndResets() {
        let model = memoryModel()
        model.log(date: .now, status: .noSpend)
        XCTAssertEqual(model.allLogs().count, 1)
        model.clearLog(date: .now)
        XCTAssertEqual(model.allLogs().count, 0)
        XCTAssertNil(model.todayStatus)
        XCTAssertEqual(model.currentStreak, 0)
    }

    @MainActor
    func testDayKeyIsStablePerCalendarDay() {
        let model = memoryModel()
        let morning = cal.startOfDay(for: .now)
        let evening = cal.date(byAdding: .hour, value: 22, to: morning)!
        XCTAssertEqual(model.dayKey(for: morning), model.dayKey(for: evening))
    }

    // MARK: Store config

    @MainActor
    func testStoreProductIDAndPrice() async {
        let store = Store()
        try? await Task.sleep(for: .seconds(0.3))
        XCTAssertEqual(Store.productID, "nospend_pro_unlock")
        XCTAssertEqual(store.displayPrice, "$0.99")
        XCTAssertFalse(store.isPro, "Pro must start locked")
    }
}
