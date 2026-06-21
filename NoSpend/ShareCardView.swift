import SwiftUI

/// The shareable streak card. Fixed colors (not theme-dependent) so the exported image is
/// consistent, with a subtle "NoSpend" wordmark + App Store CTA for organic growth.
struct StreakCard: View {
    let currentStreak: Int
    let bestStreak: Int
    let noSpendDays: Int
    let saved: String

    var body: some View {
        ZStack {
            Color.white
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Color.nsAccent.opacity(0.12)).frame(width: 120, height: 120)
                    VStack(spacing: 0) {
                        Text("\(currentStreak)")
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.nsAccent)
                        Text(currentStreak == 1 ? "day" : "days")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(white: 0.5))
                    }
                }
                VStack(spacing: 6) {
                    Text("No-spend streak")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    HStack(spacing: 18) {
                        stat("\(bestStreak)", "best")
                        stat("\(noSpendDays)", "days")
                        stat(saved, "saved")
                    }
                }
                Spacer().frame(height: 4)
                Text("NoSpend")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.nsAccent)
                Text("Track your no-spend days · on the App Store")
                    .font(.caption).foregroundStyle(Color(white: 0.55))
            }
            .padding(40)
        }
        .frame(width: 340, height: 360)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.bold)).foregroundStyle(.black)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(Color(white: 0.5))
        }
    }

    @MainActor func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}
