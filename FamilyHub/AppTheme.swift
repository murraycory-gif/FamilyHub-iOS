import SwiftUI

/// Light paper surfaces with dark navy ink.
enum AppTheme {
    static let navy = Color(hex: "163A5F")
    static let navySoft = Color(hex: "E6EEF6")
    static let navyMuted = Color(hex: "5C738A")

    /// Legacy names used across the foundation — now navy.
    static let forest = navy
    static let forestSoft = navySoft
    static let clay = Color(hex: "3D6A96")

    static let bg = Color(hex: "F2F5F8")
    static let card = Color.white
    static let cardBorder = Color(hex: "163A5F").opacity(0.08)

    static let text = Color(hex: "0F2236")
    static let textSecondary = Color(hex: "5A6B7D")
    static let textTertiary = Color(hex: "8A97A6")

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
            (r, g, b) = (22, 58, 95)
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
            .foregroundStyle(.white)
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
            .foregroundStyle(AppTheme.navy)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.navySoft)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
