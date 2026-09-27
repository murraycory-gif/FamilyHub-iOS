import SwiftUI
import UIKit

/// Hex values verified for WCAG AA 4.5:1 of label text on Hub surfaces.
enum HubPalette {
    static let darkBackground = "0B1220"
    static let darkCard = "152036"
    static let darkTable = "10192B"
    static let lightBackground = "F3F5F8"
    static let lightCard = "FFFFFF"
    static let labelDark = "F2F5FA"
    static let labelLight = "141A29"
    static let secondaryDark = "C5D0E0"
    static let secondaryLight = "3E475C"
    static let tertiaryDark = "B4C0D2"
    static let tertiaryLight = "5C6578"
    static let borderLight = "C5D4E4"
    static let borderDark = "3A4F6E"
    static let chipChoreInkLight = "991B1B"
    static let chipChoreInkDark = "FECACA"
    static let chipChoreFillLight = "FEE2E2"
    static let chipChoreFillDark = "4A2024"
    static let chipReminderInkLight = "92400E"
    static let chipReminderInkDark = "FDE68A"
    static let chipReminderFillLight = "FEF3C7"
    static let chipReminderFillDark = "4A3A14"
    static let chipTodoInkLight = "065F46"
    static let chipTodoInkDark = "A7F3D0"
    static let chipTodoFillLight = "D1FAE5"
    static let chipTodoFillDark = "0F3D32"
}

/// EnviroMap paper in light, navy glass in dark. Brand blue stays Heartbeat 003DA5.
enum AppTheme {
    static let blue = Color(hex: "2B7AE8")
    static let blueSoft = adaptive(light: "D9EAFF", dark: "0B2A4A")
    static let blueDeep = Color(hex: "06101C")
    static let space = Color(hex: "06101C")

    static let navy = blue
    static let navySoft = blueSoft
    static let navyMuted = adaptive(light: "616B80", dark: "9AA6B8")
    static let ice = blue

    static let forest = blue
    static let forestSoft = blueSoft
    static let clay = blueDeep

    static let bg = adaptive(light: HubPalette.lightBackground, dark: HubPalette.darkBackground)
    static let elevated = adaptive(light: HubPalette.lightCard, dark: HubPalette.darkCard)
    static let card = adaptive(light: HubPalette.lightCard, dark: HubPalette.darkCard)
    static let tableFill = adaptive(light: "F7F8FB", dark: HubPalette.darkTable)
    static let cardBorder = adaptive(light: HubPalette.borderLight, dark: HubPalette.borderDark)

    /// Light ink for type and marks that sit on blue or the dark splash.
    static let inkOnFill = Color(hex: HubPalette.labelDark)
    /// Primary label (`UIColor.label`).
    static let text = Color(uiColor: .label)
    /// Secondary label that clears WCAG AA 4.5:1 on Hub surfaces.
    /// System `secondaryLabel` is 60% white/black and misses 4.5:1 on light backgrounds.
    static let textSecondary = adaptive(light: HubPalette.secondaryLight, dark: HubPalette.secondaryDark)
    static let textTertiary = adaptive(light: HubPalette.tertiaryLight, dark: HubPalette.tertiaryDark)

    static let chore = Color(hex: "DC2626")
    static let choreSoft = adaptive(light: "FEE2E2", dark: "3F1515")
    static let reminder = Color(hex: "D97706")
    static let reminderSoft = adaptive(light: "FEF3C7", dark: "3F2E10")
    static let todo = Color(hex: "059669")
    static let todoSoft = adaptive(light: "D1FAE5", dark: "0F2F24")

    static let chipChoreInk = adaptive(light: HubPalette.chipChoreInkLight, dark: HubPalette.chipChoreInkDark)
    static let chipChoreFill = adaptive(light: HubPalette.chipChoreFillLight, dark: HubPalette.chipChoreFillDark)
    static let chipReminderInk = adaptive(light: HubPalette.chipReminderInkLight, dark: HubPalette.chipReminderInkDark)
    static let chipReminderFill = adaptive(light: HubPalette.chipReminderFillLight, dark: HubPalette.chipReminderFillDark)
    static let chipTodoInk = adaptive(light: HubPalette.chipTodoInkLight, dark: HubPalette.chipTodoInkDark)
    static let chipTodoFill = adaptive(light: HubPalette.chipTodoFillLight, dark: HubPalette.chipTodoFillDark)

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

/// Frosted pill. Material and the primary label adapt to light and dark, so the fill is never solid white.
struct HubAdaptivePill: ViewModifier {
    var horizontal: CGFloat = 12
    var vertical: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.primary)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.22), lineWidth: 1))
    }
}

struct HubAdaptiveCircle: ViewModifier {
    var side: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Color.primary)
            .frame(width: side, height: side)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.22), lineWidth: 1))
    }
}

extension View {
    func hubAdaptivePill(horizontal: CGFloat = 12, vertical: CGFloat = 6) -> some View {
        modifier(HubAdaptivePill(horizontal: horizontal, vertical: vertical))
    }

    func hubAdaptiveCircle(side: CGFloat = 28) -> some View {
        modifier(HubAdaptiveCircle(side: side))
    }
}
