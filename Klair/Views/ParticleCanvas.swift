import SwiftUI

struct SleepParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var size: Double
    var opacity: Double
    var speed: Double
    var drift: Double
    var hue: Double
}

struct SleepParticleCanvas: View {
    @State private var particles: [SleepParticle] = []
    @State private var time: Double = 0
    let particleCount: Int

    init(particleCount: Int = 30) {
        self.particleCount = particleCount
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let now = context.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let phase = now * p.speed
                    let px = (p.x + sin(phase * 0.3 + p.drift) * 0.08) * size.width
                    let py = (p.y - (now * p.speed * 0.005).truncatingRemainder(dividingBy: 1.2) + 0.2) * size.height
                    let normalizedPy = ((py / size.height) + 1).truncatingRemainder(dividingBy: 1.0)
                    let fadeEdge = min(normalizedPy, 1 - normalizedPy) * 4
                    let alpha = p.opacity * min(1, fadeEdge) * (0.7 + 0.3 * sin(phase * 0.5))

                    let radius = p.size * (0.8 + 0.2 * sin(phase * 0.7))
                    let point = CGPoint(x: px, y: ((py / size.height).truncatingRemainder(dividingBy: 1.0)) * size.height)

                    let color: Color = p.hue < 0.33 ? KlairTheme.indigo : p.hue < 0.66 ? KlairTheme.amethyst : KlairTheme.cyan
                    ctx.opacity = alpha
                    ctx.fill(
                        Circle().path(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color)
                    )
                    if radius > 2.5 {
                        ctx.opacity = alpha * 0.3
                        ctx.fill(
                            Circle().path(in: CGRect(x: point.x - radius * 2, y: point.y - radius * 2, width: radius * 4, height: radius * 4)),
                            with: .color(color)
                        )
                    }
                }
            }
        }
        .onAppear { seedParticles() }
        .allowsHitTesting(false)
    }

    private func seedParticles() {
        particles = (0..<particleCount).map { _ in
            SleepParticle(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1.2),
                size: Double.random(in: 1.5...4),
                opacity: Double.random(in: 0.15...0.45),
                speed: Double.random(in: 0.3...1.2),
                drift: Double.random(in: 0...(.pi * 2)),
                hue: Double.random(in: 0...1)
            )
        }
    }
}
