import SwiftUI

struct HomeView: View {
    var forceScreen: String?

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var month = MonthContext(containing: .now, cal: Calendar.current)
    @State private var slipDate: Date?
    @State private var showStats = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var refreshToken = 0   // bump to force grid recompute after a log

    private var cal: Calendar { appModel.cal }

    var body: some View {
        ZStack {
            NoSpendBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    streakBanner
                    monthCard
                    todayActions
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .sheet(item: slipDateItem) { item in
            LogSlipView(date: item.date) { refreshAfterLog() }
        }
        .sheet(isPresented: $showStats) { StatsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            appModel.refresh()
            applyForceScreen()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("NoSpend").font(.title.weight(.bold))
            Spacer()
            Button { Haptics.tap(); showStats = true } label: {
                Image(systemName: "chart.bar.fill").font(.title3)
            }
            .tint(.primary).padding(.trailing, 14)
            .accessibilityIdentifier("open-stats")
            .accessibilityLabel("Statistics")

            Button { Haptics.tap(); showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3)
            }
            .tint(.primary)
            .accessibilityIdentifier("open-settings")
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Streak banner

    private var streakBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current streak").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(appModel.currentStreak > 0 ? Color.nsAccent : .secondary)
                    Text("\(appModel.currentStreak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(appModel.currentStreak == 1 ? "day" : "days")
                        .font(.headline).foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Best").font(.caption).foregroundStyle(.secondary)
                Text("\(appModel.longestStreak)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.nsAccent)
            }
        }
        .nsCard()
    }

    // MARK: Month grid card

    private var monthCard: some View {
        VStack(spacing: 14) {
            monthNav
            // refreshToken keeps the grid in sync after a log without a manual data flow.
            MonthGrid(month: month,
                      logsByDay: appModel.logsByDay(year: month.year, month: month.month),
                      cal: cal) { date in
                handleTap(date)
            }
            .id(refreshToken)
            GridLegend()
        }
        .nsCard()
    }

    private var monthNav: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.headline)
                    .foregroundStyle(canGoBack ? Color.nsAccent : .secondary)
            }
            .disabled(!canGoBack)
            .accessibilityIdentifier("month-prev")

            Spacer()
            HStack(spacing: 6) {
                Text(month.title).font(.headline)
                if !month.isCurrentMonth(cal: cal) && !store.isPro {
                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()

            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").font(.headline)
                    .foregroundStyle(canGoForward ? Color.nsAccent : .secondary)
            }
            .disabled(!canGoForward)
            .accessibilityIdentifier("month-next")
        }
    }

    private var canGoBack: Bool { true }  // gated by Pro inside changeMonth
    private var canGoForward: Bool { !month.isCurrentMonth(cal: cal) }

    // MARK: Today actions

    private var todayActions: some View {
        VStack(spacing: 12) {
            if let status = appModel.todayStatus {
                loggedTodayCard(status)
            } else {
                Button {
                    Haptics.success()
                    appModel.log(date: .now, status: .noSpend)
                    refreshAfterLog()
                } label: {
                    Label("Mark today no-spend", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .prominentButton()
                .accessibilityIdentifier("mark-no-spend")

                Button {
                    Haptics.tap(); slipDate = .now
                } label: {
                    Label("Log a slip", systemImage: "creditcard")
                        .frame(maxWidth: .infinity).padding(.vertical, 4)
                }
                .softButton()
                .accessibilityIdentifier("log-slip")
            }
        }
    }

    private func loggedTodayCard(_ status: DayStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: status == .noSpend ? "checkmark.seal.fill" : "creditcard.fill")
                .font(.title2)
                .foregroundStyle(status == .noSpend ? Color.nsNoSpend : Color.nsSlip)
            VStack(alignment: .leading, spacing: 2) {
                Text(status == .noSpend ? "Today is a no-spend day" : "Slip logged today")
                    .font(.subheadline.weight(.semibold))
                Text("Tap today's square to change it")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .nsCard()
    }

    // MARK: Actions

    private func handleTap(_ date: Date) {
        let targetMonth = MonthContext(containing: date, cal: cal)
        // Free users can only edit the current month.
        if !targetMonth.isCurrentMonth(cal: cal) && !store.isPro {
            Haptics.warning(); showPaywall = true; return
        }
        Haptics.tap()
        slipDate = date
    }

    private func changeMonth(_ delta: Int) {
        let target = month.adding(months: delta, cal: cal)
        if target.isAfterCurrentMonth(cal: cal) { return }     // never the future
        if !target.isCurrentMonth(cal: cal) && !store.isPro && delta < 0 {
            Haptics.warning(); showPaywall = true; return        // history is Pro
        }
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.2)) { month = target }
    }

    private func refreshAfterLog() {
        appModel.refresh()
        refreshToken += 1
    }

    // Wrap the optional Date so it can drive `.sheet(item:)`.
    private var slipDateItem: Binding<SlipDateItem?> {
        Binding(
            get: { slipDate.map(SlipDateItem.init) },
            set: { slipDate = $0?.date }
        )
    }

    private func applyForceScreen() {
        guard let s = forceScreen else { return }
        switch s {
        case "stats": showStats = true
        case "settings": showSettings = true
        case "paywall": showPaywall = true
        case "slip": slipDate = .now
        default: break
        }
    }
}

/// Identifiable wrapper so a tapped day can present the Log sheet via `.sheet(item:)`.
struct SlipDateItem: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}
