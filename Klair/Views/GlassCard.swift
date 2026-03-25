import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var hasTapAnimation: Bool

    @State private var isPressed = false

    init(padding: CGFloat = 20, hasTapAnimation: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.hasTapAnimation = hasTapAnimation
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(KlairTheme.card.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear, .black.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: KlairTheme.cloudShadow, radius: isPressed ? 12 : 20, y: isPressed ? 4 : 10)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                guard hasTapAnimation else { return }
                isPressed = pressing
                if pressing { SensoryManager.shared.lightTap() }
            }, perform: {})
    }
}
