import SwiftUI
import UIKit

/// EnviroMap paper in light, navy glass in dark. Brand blue stays Heartbeat 003DA5.
enum AppTheme {
    static let blue = Color(hex: "0090FF")
    static let blueSoft = adaptive(light: "D6ECFF", dark: "0B2A4A")
    static let blueDeep = Color(hex: "0066C2")

    static let navy = blue
    static let navySoft = blueSoft
    static let navyMuted = adaptive(light: "616B80", dark: "9AA6B8")
    static let ice = blue

    static let forest = blue
    static let forestSoft = blueSoft
    static let clay = blueDeep

    static let bg = adaptive(light: "F3F5F8", dark: "0B1220")
    static let elevated = adaptive(light: "FFFFFF", dark: "152036")
    static let card = adaptive(light: "FFFFFF", dark: "152036")
    static let tableFill = adaptive(light: "F7F8FB", dark: "10192B")
    static let cardBorder = adaptive(light: "B7D9F8", dark: "1C4A78")

    static let text = adaptive(light: "141A29", dark: "F2F5FA")
    static let textSecondary = adaptive(light: "616B80", dark: "A8B4C8")
    static let textTertiary = adaptive(light: "8C93A3", dark: "7D8AA0")

    static let chore = Color(hex: "DC2626")
    static let choreSoft = adaptive(light: "FEE2E2", dark: "3F1515")
    static let reminder = Color(hex: "D97706")
    static let reminderSoft = adaptive(light: "FEF3C7", dark: "3F2E10")
    static let todo = Color(hex: "059669")
    static let todoSoft = adaptive(light: "D1FAE5", dark: "0F2F24")

    static let radiusL: CGFloat = 20
    static let radiusM: CGFloat = 14
    static let radiusS: CGFloat = 10

    static func paint(_ size: CGFloat) -> Font {
        .custom("RubikWetPaint-Regular", size: size)
    }

    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

extension HubAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
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
            (r, g, b) = (0, 61, 165)
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
                    .fill(AppTheme.blue)
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
            .foregroundStyle(AppTheme.blue)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.blueSoft)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.blue)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct HubPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
