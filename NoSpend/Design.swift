import SwiftUI
import UIKit

// MARK: - Minimalist, Apple-native color system
// Flat surfaces, system semantic colors (so Light AND Dark both look right),
// a single Apple-blue accent. No gradients.

extension Color {
    static let nsAccent = Color(hex: "#007AFF")          // the single accent
    static let nsCard = Color(uiColor: .secondarySystemBackground)
    static let nsCard2 = Color(uiColor: .tertiarySystemBackground)
    static let nsField = Color(uiColor: .tertiarySystemFill)
    static let nsHair = Color(uiColor: .separator)

    // Heat-grid status colors. Green = no-spend, red = slip, accent = neutral.
    static let nsNoSpend = Color(hex: "#34C759")          // system green
    static let nsSlip = Color(hex: "#FF3B30")             // system red
}

// MARK: - Flat surfaces (cards / pills / buttons)

extension View {
    func nsCard(cornerRadius: CGFloat = 20) -> some View {
        self.padding(16)
            .background(Color.nsCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func nsPill() -> some View {
        self.padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.nsCard, in: Capsule())
    }

    /// Primary action — a clean, flat Apple-blue filled capsule.
    func prominentButton() -> some View { self.buttonStyle(FilledAccentButtonStyle()) }
    /// Secondary action — flat tinted capsule.
    func softButton() -> some View { self.buttonStyle(SoftButtonStyle()) }
}

struct FilledAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .background(Color.nsAccent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Color.nsAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(Color.nsCard, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Background (flat, adapts to light/dark)

struct NoSpendBackground: View {
    var body: some View { Color(uiColor: .systemBackground).ignoresSafeArea() }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
