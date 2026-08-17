import SwiftUI

/// Warm paper + forest ink. Foundation palette — design pass comes next.
enum AppTheme {
    static let forest = Color(red: 0.184, green: 0.290, blue: 0.235)
    static let forestSoft = Color(red: 0.890, green: 0.918, blue: 0.890)
    static let clay = Color(red: 0.549, green: 0.353, blue: 0.235)

    static let bg = Color(red: 0.957, green: 0.937, blue: 0.902)
    static let card = Color(red: 1.0, green: 0.988, blue: 0.969)
    static let cardBorder = Color.black.opacity(0.06)

    static let text = Color(red: 0.102, green: 0.090, blue: 0.078)
    static let textSecondary = Color(red: 0.420, green: 0.392, blue: 0.361)
    static let textTertiary = Color(red: 0.580, green: 0.545, blue: 0.510)

    static let radiusL: CGFloat = 22
    static let radiusM: CGFloat = 14
    static let radiusS: CGFloat = 10
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (47, 74, 60)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.bg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .fill(AppTheme.forest)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.forest)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.forestSoft)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
