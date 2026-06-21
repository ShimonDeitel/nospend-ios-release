import SwiftUI

/// A small labelled metric tile used on Home / Stats.
struct MetricTile: View {
    let value: String
    let label: String
    var accent: Color = .nsAccent
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 6)
        .background(Color.nsCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A single colored cell in the month heat grid.
struct DayCell: View {
    let dayNumber: Int?          // nil = leading blank padding cell
    let status: DayStatus?       // nil = unlogged
    let isToday: Bool
    let isFuture: Bool

    private var fill: Color {
        switch status {
        case .noSpend: return .nsNoSpend
        case .slip: return .nsSlip
        case .none: return Color(uiColor: .tertiarySystemFill)
        }
    }
    private var textColor: Color {
        status == nil ? .secondary : .white
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(dayNumber == nil ? Color.clear : fill)
                .opacity(isFuture ? 0.35 : 1)
            if let dayNumber {
                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isFuture ? Color.secondary : textColor)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.nsAccent, lineWidth: 2)
            }
        }
    }
}

/// The month heat grid: a weekday header row + a 7-column grid of day cells.
/// Tapping a non-future day calls `onTapDay(date)`.
struct MonthGrid: View {
    let month: MonthContext
    let logsByDay: [Int: DayLog]
    let cal: Calendar
    let onTapDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(month.weekdaySymbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                    DayCell(dayNumber: nil, status: nil, isToday: false, isFuture: false)
                }
                ForEach(1...month.daysInMonth, id: \.self) { day in
                    let date = month.date(forDay: day, cal: cal)
                    DayCell(
                        dayNumber: day,
                        status: logsByDay[day]?.status,
                        isToday: month.isToday(day, cal: cal),
                        isFuture: month.isFuture(day, cal: cal)
                    )
                    .onTapGesture {
                        guard !month.isFuture(day, cal: cal) else { return }
                        onTapDay(date)
                    }
                    .accessibilityIdentifier("day-\(day)")
                }
            }
        }
    }
}

/// A legend strip explaining the grid colors.
struct GridLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            legendItem(.nsNoSpend, "No-spend")
            legendItem(.nsSlip, "Slip")
            legendItem(Color(uiColor: .tertiarySystemFill), "Unlogged")
            Spacer(minLength: 0)
        }
    }
    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color).frame(width: 14, height: 14)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// A badge tile shown on Stats (Pro). Locked badges render dimmed with a lock.
struct BadgeTile: View {
    let badge: Badge
    let earned: Bool
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(earned ? Color.nsAccent.opacity(0.15) : Color.nsCard2)
                    .frame(width: 52, height: 52)
                Image(systemName: earned ? badge.symbol : "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(earned ? Color.nsAccent : .secondary)
            }
            Text(badge.title).font(.caption.weight(.semibold))
                .foregroundStyle(earned ? .primary : .secondary)
                .multilineTextAlignment(.center)
            Text("\(badge.days) days").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.nsCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(earned ? 1 : 0.85)
    }
}

/// Wraps UIActivityViewController so we can share a rendered streak card image.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
