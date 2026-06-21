import Foundation
import SwiftData

/// One logged calendar day. `status` is "noSpend" or "slip"; a slip carries an optional cost.
/// Persisted in a plain local SwiftData store. The store keeps exactly one DayLog per calendar
/// day; `dayKey` (yyyy-MM-dd in the user's calendar) is the de-dupe key enforced in `AppModel`.
@Model
final class DayLog {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// "yyyy-MM-dd" in the user's current calendar — the per-day identity key.
    var dayKey: String = ""
    /// Raw value of `DayStatus` — "noSpend" or "slip".
    var statusRaw: String = DayStatus.noSpend.rawValue
    /// Cost of the slip in the user's currency. Nil / 0 for a no-spend day.
    var slipCost: Double = 0
    /// Optional short note for a slip (e.g. "coffee"). Empty for no-spend days.
    var note: String = ""

    init(id: UUID = UUID(), date: Date = .now, dayKey: String = "",
         status: DayStatus = .noSpend, slipCost: Double = 0, note: String = "") {
        self.id = id
        self.date = date
        self.dayKey = dayKey
        self.statusRaw = status.rawValue
        self.slipCost = slipCost
        self.note = note
    }

    var status: DayStatus {
        get { DayStatus(rawValue: statusRaw) ?? .noSpend }
        set { statusRaw = newValue.rawValue }
    }
}

/// The state of a single day in the heat grid.
enum DayStatus: String, CaseIterable {
    case noSpend
    case slip

    var label: String {
        switch self {
        case .noSpend: return "No-spend day"
        case .slip: return "Slip"
        }
    }
}
