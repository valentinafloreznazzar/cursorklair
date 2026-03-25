import SwiftUI

enum KlairTheme {
    // MARK: - Surfaces
    static let background = Color(hex: "F5F3F4")
    static let surfaceHigh = Color(hex: "E4E2E3")
    static let surfaceLow = Color(hex: "F5F3F4")
    static let card = Color.white
    static let darkSurface = Color(hex: "1A1A2E")

    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "F7F5F6"), Color(hex: "EFEDEE")],
        startPoint: .top, endPoint: .bottom
    )

    // MARK: - Text
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "5A5A7A")
    static let textTertiary = Color(hex: "9B9DB5")

    // MARK: - Energizing Wellness Palette
    static let cyan = Color(hex: "00D4FF")             // Electric Cyan — primary energy
    static let amethyst = Color(hex: "7B2FBE")          // Deep Amethyst — premium/focus
    static let orange = Color(hex: "FF6B35")             // Sunset Orange — vitality/alerts
    static let emerald = Color(hex: "00C9A7")            // Emerald — recovery/positive
    static let coral = Color(hex: "FF4757")              // Vibrant Coral — warnings
    static let indigo = Color(hex: "4834D4")             // Deep Indigo — sleep/calm
    static let softSlate = Color(hex: "4E5E6D")           // Soft Slate — primary buttons

    // Legacy aliases for backward compatibility
    static let accent = Color(hex: "4834D4")
    static let accentTeal = Color(hex: "00C9A7")
    static let accentOrange = Color(hex: "FF6B35")
    static let accentRed = Color(hex: "FF4757")
    static let accentBlue = Color(hex: "00D4FF")
    static let warm = Color(hex: "FF6B35")
    static let sage = Color(hex: "00C9A7")
    static let slate = Color(hex: "4E5E6D")

    // MARK: - Shadow
    static let cardBorder = Color.clear
    static let cloudShadow = Color(hex: "1A1A2E").opacity(0.06)

    // MARK: - Layout
    static let cornerRadius: CGFloat = 22
    static let smallCornerRadius: CGFloat = 14

    // MARK: - Vibrant Gradients
    static let heroGradient = LinearGradient(
        colors: [amethyst, indigo],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cyanGradient = LinearGradient(
        colors: [cyan, Color(hex: "00B4D8")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let energyGradient = LinearGradient(
        colors: [orange, Color(hex: "FF8C42")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let emeraldGradient = LinearGradient(
        colors: [emerald, Color(hex: "00E5BF")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let sleepGradient = LinearGradient(
        colors: [indigo.opacity(0.9), amethyst.opacity(0.7)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let splashGradient = LinearGradient(
        colors: [Color(hex: "1A1A2E"), Color(hex: "2D1B69")],
        startPoint: .top, endPoint: .bottom
    )

    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...100: return emerald
        case 70..<85: return cyan
        case 55..<70: return orange
        default: return coral
        }
    }
}

// MARK: - Reusable View Modifiers

struct CloudShadowModifier: ViewModifier {
    var radius: CGFloat = 20
    var y: CGFloat = 10
    func body(content: Content) -> some View {
        content.shadow(color: KlairTheme.cloudShadow, radius: radius, y: y)
    }
}

struct TapScaleModifier: ViewModifier {
    @State private var isPressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
                if pressing { SensoryManager.shared.lightTap() }
            }, perform: {})
    }
}

struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(KlairTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
            .shadow(color: KlairTheme.cloudShadow, radius: 20, y: 10)
    }
}

extension View {
    func cloudShadow(radius: CGFloat = 20, y: CGFloat = 10) -> some View {
        modifier(CloudShadowModifier(radius: radius, y: y))
    }

    func tapScale() -> some View {
        modifier(TapScaleModifier())
    }

    func premiumCard() -> some View {
        modifier(PremiumCardModifier())
    }

    func metaLabel() -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .kerning(1.5)
            .foregroundStyle(KlairTheme.textTertiary)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
