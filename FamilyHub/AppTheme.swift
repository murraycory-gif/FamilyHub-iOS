import SwiftUI

/// Night command-center: near-black navy, steel accent, hairline glass.
enum AppTheme {
    static let navy = Color(hex: "C5CDD6")
    static let navySoft = Color(hex: "1B2330")
    static let navyMuted = Color(hex: "8A96A6")
    static let ice = Color(hex: "9BB0C0")

    static let forest = navy
    static let forestSoft = navySoft
    static let clay = Color(hex: "8FA8B8")

    static let bg = Color(hex: "080B10")
    static let elevated = Color(hex: "11161F")
    static let card = Color(hex: "141A24")
    static let cardBorder = Color.white.opacity(0.10)

    static let text = Color(hex: "EDF1F5")
    static let textSecondary = Color(hex: "9AA6B4")
    static let textTertiary = Color(hex: "6D7886")

    static let radiusL: CGFloat = 20
    static let radiusM: CGFloat = 12
    static let radiusS: CGFloat = 8
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
            (r, g, b) = (197, 205, 214)
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
                    .fill(AppTheme.navy)
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
            .foregroundStyle(AppTheme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                    .background(Capsule(style: .continuous).fill(AppTheme.navySoft))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
