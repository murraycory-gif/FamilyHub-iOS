import SwiftUI
import UIKit

/// Hex values verified for WCAG AA 4.5:1 of label text on Hub surfaces.
/// Light is warm paper. Dark is soft charcoal, not navy.
enum HubPalette {
    static let darkBackground = "2E3338"
    static let darkCard = "3C4248"
    static let darkTable = "343A40"
    static let lightBackground = "F7F2EA"
    static let lightCard = "FFFFFF"
    static let labelDark = "F6F3EE"
    static let labelLight = "241C14"
    static let secondaryDark = "E4DDD4"
    static let secondaryLight = "4A433A"
    static let tertiaryDark = "D0C9BF"
    static let tertiaryLight = "5C5348"
    static let borderLight = "E4D9CC"
    static let borderDark = "4E565E"
    static let chipChoreInkLight = "9F1239"
    static let chipChoreInkDark = "FECDD3"
    static let chipChoreFillLight = "FFE4E6"
    static let chipChoreFillDark = "4C1D2A"
    static let chipReminderInkLight = "9A3412"
    static let chipReminderInkDark = "FDE68A"
    static let chipReminderFillLight = "FFEDD5"
    static let chipReminderFillDark = "4A3218"
    static let chipTodoInkLight = "14532D"
    static let chipTodoInkDark = "BBF7D0"
    static let chipTodoFillLight = "DCFCE7"
    static let chipTodoFillDark = "14352A"
    static let celebrateInkLight = "9A3412"
    static let celebrateInkDark = "FDE68A"
    static let celebrateFillLight = "FFEDD5"
    static let celebrateFillDark = "4A3218"
    static let brand = "0C5F78"
}

/// Warm paper in light, soft charcoal in dark. One teal-blue accent.
enum AppTheme {
    static let blue = Color(hex: HubPalette.brand)
    static let blueSoft = adaptive(light: "D7EEF3", dark: "1A3C48")
    static let blueDeep = Color(hex: "1C1917")
    static let space = Color(hex: "1C1917")

    static let navy = blue
    static let navySoft = blueSoft
    static let navyMuted = adaptive(light: "6B5E52", dark: "D4C8BA")
    static let ice = blue

    static let forest = blue
    static let forestSoft = blueSoft
    static let clay = blueDeep

    static let bg = adaptive(light: HubPalette.lightBackground, dark: HubPalette.darkBackground)
    static let elevated = adaptive(light: HubPalette.lightCard, dark: HubPalette.darkCard)
    static let card = adaptive(light: HubPalette.lightCard, dark: HubPalette.darkCard)
    static let tableFill = adaptive(light: "F4EBE0", dark: HubPalette.darkTable)
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
    /// Warm accent for “Great job” and other celebrations.
    static let celebrateInk = adaptive(light: HubPalette.celebrateInkLight, dark: HubPalette.celebrateInkDark)
    static let celebrateFill = adaptive(light: HubPalette.celebrateFillLight, dark: HubPalette.celebrateFillDark)

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
