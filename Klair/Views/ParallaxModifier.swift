import SwiftUI
import CoreMotion

@MainActor
final class MotionManager: ObservableObject {
    static let shared = MotionManager()
    private let motion = CMMotionManager()

    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    private init() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data = data else { return }
            self?.pitch = data.attitude.pitch
            self?.roll = data.attitude.roll
        }
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }
}

struct ParallaxModifier: ViewModifier {
    @StateObject private var motion = MotionManager.shared
    let magnitude: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(
                x: CGFloat(motion.roll) * magnitude,
                y: CGFloat(motion.pitch) * magnitude * 0.6
            )
            .animation(.interpolatingSpring(stiffness: 50, damping: 10), value: motion.roll)
            .animation(.interpolatingSpring(stiffness: 50, damping: 10), value: motion.pitch)
    }
}

extension View {
    func parallax(magnitude: CGFloat = 15) -> some View {
        modifier(ParallaxModifier(magnitude: magnitude))
    }
}
