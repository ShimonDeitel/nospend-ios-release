import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store of `DayLog`s, derives streaks/stats live, and enforces
/// one log per calendar day. Stats are ALWAYS derived from logs — never stored as truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var currentStreak = 0
    @Published private(set) var longestStreak = 0
    @Published private(set) var noSpendDays = 0
    @Published private(set) var slipDays = 0
    @Published private(set) var totalSlipSpend: Double = 0
    @Published private(set) var estimatedSaved: Double = 0
    @Published private(set) var todayStatus: DayStatus?
    @Published private(set) var earnedBadges: [Badge] = []

    /// Working calendar — the user's current calendar. Held as a property so logic is consistent.
    let cal = Calendar.current

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container (local-only on-device persistence; no CloudKit, no special capabilities)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([DayLog.self])
        // Plain local SwiftData store. No iCloud / CloudKit involvement at all.
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Day keys

    static func dayKey(for date: Date, cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func dayKey(for date: Date) -> String { Self.dayKey(for: date, cal: cal) }

    // MARK: Logging (one log per calendar day; re-logging the same day overwrites it)

    func log(date: Date = .now, status: DayStatus, slipCost: Double = 0, note: String = "") {
        let ctx = container.mainContext
        let key = dayKey(for: date)
        let day = cal.startOfDay(for: date)

        if let existing = dayLog(forKey: key) {
            existing.date = day
            existing.status = status
            existing.slipCost = status == .slip ? max(0, slipCost) : 0
            existing.note = status == .slip ? note : ""
        } else {
            ctx.insert(DayLog(date: day, dayKey: key, status: status,
                              slipCost: status == .slip ? max(0, slipCost) : 0,
                              note: status == .slip ? note : ""))
        }
        try? ctx.save()
        refresh()
    }

    func clearLog(date: Date) {
        let ctx = container.mainContext
        if let existing = dayLog(forKey: dayKey(for: date)) {
            ctx.delete(existing)
            try? ctx.save()
            refresh()
        }
    }

    func dayLog(forKey key: String) -> DayLog? {
        let d = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dayKey == key })
        return (try? container.mainContext.fetch(d))?.first
    }

    func dayLog(for date: Date) -> DayLog? { dayLog(forKey: dayKey(for: date)) }

    func allLogs() -> [DayLog] {
        let d = FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? container.mainContext.fetch(d)) ?? []
    }

    /// Logs for a given month (year/month), keyed by day-of-month for the heat grid.
    func logsByDay(year: Int, month: Int) -> [Int: DayLog] {
        var result: [Int: DayLog] = [:]
        for log in allLogs() {
            let c = cal.dateComponents([.year, .month, .day], from: log.date)
            if c.year == year, c.month == month, let d = c.day { result[d] = log }
        }
        return result
    }

    // MARK: Stats (all derived)

    func refresh() {
        let entries = allLogs().map {
            DayEntry(day: cal.startOfDay(for: $0.date), status: $0.status, slipCost: $0.slipCost)
        }
        currentStreak = StreakEngine.currentStreak(entries: entries, today: .now, cal: cal)
        longestStreak = StreakEngine.longestStreak(entries: entries, cal: cal)
        noSpendDays = StreakEngine.noSpendCount(entries)
        slipDays = StreakEngine.slipCount(entries)
        totalSlipSpend = StreakEngine.totalSlipSpend(entries)
        estimatedSaved = StreakEngine.estimatedSaved(entries)
        earnedBadges = StreakEngine.earnedBadges(longestStreak: longestStreak)
        todayStatus = dayLog(for: .now)?.status
    }

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: DayLog.self)
        try? ctx.save()
        refresh()
    }

    // MARK: Currency

    /// User's locale currency formatter, shared everywhere money is shown.
    func currency(_ amount: Double) -> String {
        amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var currencySymbol: String {
        Locale.current.currencySymbol ?? "$"
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let n = env["NOSPEND_SEED"].flatMap(Int.init), n > 0 else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<DayLog>()))?.isEmpty ?? true) {
            for offset in 0..<n {
                guard let day = cal.date(byAdding: .day, value: -offset, to: .now) else { continue }
                let start = cal.startOfDay(for: day)
                // Mostly no-spend with the occasional seeded slip every 5th day.
                let isSlip = offset % 5 == 4
                ctx.insert(DayLog(date: start, dayKey: Self.dayKey(for: start, cal: cal),
                                  status: isSlip ? .slip : .noSpend,
                                  slipCost: isSlip ? Double(10 + (offset % 4) * 7) : 0,
                                  note: isSlip ? "Takeout" : ""))
            }
            try? ctx.save()
        }
    }
    #endif
}
