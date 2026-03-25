import SwiftUI

struct SplashView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.8
    @State private var taglineOpacity: Double = 0
    @State private var pulsePhase: Double = 0
    @State private var ringRotation: Double = 0
    @State private var glowPulse: Bool = false

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            KlairTheme.splashGradient.ignoresSafeArea()

            Circle()
                .fill(KlairTheme.amethyst.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -60, y: -120)
                .parallax(magnitude: 20)

            Circle()
                .fill(KlairTheme.cyan.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 80, y: 100)
                .parallax(magnitude: -15)

            SleepParticleCanvas(particleCount: 15)
                .opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(KlairTheme.cyan.opacity(0.12), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(ringRotation))

                    Circle()
                        .stroke(KlairTheme.amethyst.opacity(0.08), lineWidth: 1)
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(-ringRotation * 0.6))

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [KlairTheme.amethyst, KlairTheme.indigo],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 55
                                )
                            )
                            .frame(width: 110, height: 110)
                            .shadow(color: KlairTheme.amethyst.opacity(glowPulse ? 0.4 : 0.2), radius: glowPulse ? 30 : 20, y: 0)

                        Image(systemName: "moon.fill")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(.white.opacity(0.9))
                            .rotationEffect(.degrees(-25))
                            .offset(x: -4, y: -2)

                        PulseLine()
                            .stroke(
                                KlairTheme.cyan,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 50, height: 20)
                            .offset(x: 8, y: 16)
                            .opacity(0.7)
                    }
                }
                .opacity(logoOpacity)
                .scaleEffect(logoScale)

                VStack(spacing: 10) {
                    Text("KLAIR")
                        .font(.system(size: 32, weight: .thin, design: .rounded))
                        .kerning(12)
                        .foregroundStyle(.white)

                    Text("Bio-Intelligence Platform")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(taglineOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            SensoryManager.shared.playZenChime()
            SensoryManager.shared.mediumTap()

            withAnimation(.easeOut(duration: 1.4)) {
                logoOpacity = 1.0
                logoScale = 1.0
            }
            withAnimation(.easeOut(duration: 1.0).delay(0.6)) {
                taglineOpacity = 1.0
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                onFinished()
            }
        }
    }
}

struct PulseLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height, mid = rect.midY
        path.move(to: CGPoint(x: 0, y: mid))
        path.addLine(to: CGPoint(x: w * 0.25, y: mid))
        path.addLine(to: CGPoint(x: w * 0.35, y: mid - h * 0.8))
        path.addLine(to: CGPoint(x: w * 0.45, y: mid + h * 0.6))
        path.addLine(to: CGPoint(x: w * 0.55, y: mid - h * 0.4))
        path.addLine(to: CGPoint(x: w * 0.65, y: mid))
        path.addLine(to: CGPoint(x: w, y: mid))
        return path
    }
}
