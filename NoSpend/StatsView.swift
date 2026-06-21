import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var shareImage: ShareImage?

    private let cols = [GridItem(.flexible()), GridItem(.flexible())]
    private let badgeCols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                NoSpendBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        metricGrid
                        savedCard
                        badgesSection
                        slipAnalyticsSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Your progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.isPro {
                        Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                            .accessibilityIdentifier("share-streak")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.nsAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(item: $shareImage) { item in ShareSheet(items: [item.image]) }
        }
    }

    // MARK: Metrics

    private var metricGrid: some View {
        LazyVGrid(columns: cols, spacing: 12) {
            MetricTile(value: "\(appModel.currentStreak)", label: "Current streak")
            MetricTile(value: "\(appModel.longestStreak)", label: "Best streak")
            MetricTile(value: "\(appModel.noSpendDays)", label: "No-spend days", accent: .nsNoSpend)
            MetricTile(value: "\(appModel.slipDays)", label: "Slip days", accent: .nsSlip)
        }
    }

    private var savedCard: some View {
        VStack(spacing: 6) {
            Text("Estimated saved").font(.subheadline).foregroundStyle(.secondary)
            Text(appModel.currency(appModel.estimatedSaved))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.nsNoSpend)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text("Based on your average slip across \(appModel.noSpendDays) no-spend days.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.nsCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Badges

    @ViewBuilder
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Badges").font(.headline)
                Spacer()
                if !store.isPro {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            if store.isPro {
                LazyVGrid(columns: badgeCols, spacing: 12) {
                    ForEach(StreakEngine.streakBadgeThresholds, id: \.self) { t in
                        BadgeTile(badge: Badge(days: t), earned: appModel.longestStreak >= t)
                    }
                }
            } else {
                lockedRow(title: "Earn achievement badges",
                          subtitle: "Hit 3, 7, 14, 30, 60 and 100-day streaks")
            }
        }
    }

    // MARK: Slip analytics

    @ViewBuilder
    private var slipAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Slip analytics").font(.headline)
                Spacer()
                if !store.isPro {
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            if store.isPro {
                VStack(spacing: 0) {
                    analyticsRow("Total spent on slips", appModel.currency(appModel.totalSlipSpend))
                    Divider().padding(.leading, 16)
                    analyticsRow("Slip days", "\(appModel.slipDays)")
                    if appModel.slipDays > 0 {
                        Divider().padding(.leading, 16)
                        analyticsRow("Average slip",
                                     appModel.currency(appModel.totalSlipSpend / Double(appModel.slipDays)))
                    }
                }
                .background(Color.nsCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                lockedRow(title: "See where your money goes",
                          subtitle: "Total spent, slip days and your average slip")
            }
        }
    }

    private func analyticsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 13).padding(.horizontal, 16)
    }

    private func lockedRow(title: String, subtitle: String) -> some View {
        Button { Haptics.tap(); showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").foregroundStyle(Color.nsAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color.nsCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Share

    private func share() {
        let card = StreakCard(currentStreak: appModel.currentStreak,
                              bestStreak: appModel.longestStreak,
                              noSpendDays: appModel.noSpendDays,
                              saved: appModel.currency(appModel.estimatedSaved))
        if let img = card.render() {
            Haptics.tap()
            shareImage = ShareImage(image: img)
        }
    }
}

/// Identifiable wrapper so a rendered share image can drive `.sheet(item:)`.
struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
