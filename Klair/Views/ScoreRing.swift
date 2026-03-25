import SwiftUI

struct ScoreRing: View {
    let score: Int
    let maxScore: Int
    let label: String
    let color: Color
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    init(score: Int, maxScore: Int = 100, label: String, color: Color, size: CGFloat = 80) {
        self.score = score; self.maxScore = maxScore; self.label = label; self.color = color; self.size = size
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.1), lineWidth: size * 0.08)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.3), color, color.opacity(0.8)],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.3), radius: 4, y: 0)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                        .foregroundStyle(KlairTheme.textPrimary)
                    if maxScore == 100 {
                        Text("%").font(.system(size: size * 0.12, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                    }
                }
            }
            .frame(width: size, height: size)

            if !label.isEmpty {
                Text(label.uppercased())
                    .font(.system(size: max(8, size * 0.12), weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(KlairTheme.textTertiary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animatedProgress = min(1, Double(score) / Double(max(maxScore, 1)))
            }
        }
    }
}

struct MacroRing: View {
    let protein: Double; let carbs: Double; let fat: Double; let size: CGFloat
    @State private var animatedProgress: Double = 0

    init(protein: Double, carbs: Double, fat: Double, size: CGFloat = 120) {
        self.protein = protein; self.carbs = carbs; self.fat = fat; self.size = size
    }

    private var total: Double { protein + carbs + fat }
    private var proteinFrac: Double { total > 0 ? protein / total : 0 }
    private var carbsFrac: Double { total > 0 ? carbs / total : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(KlairTheme.surfaceHigh.opacity(0.5), lineWidth: size * 0.09)

            Circle()
                .trim(from: 0, to: proteinFrac * animatedProgress)
                .stroke(KlairTheme.amethyst, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: KlairTheme.amethyst.opacity(0.3), radius: 2)

            Circle()
                .trim(from: proteinFrac * animatedProgress, to: (proteinFrac + carbsFrac) * animatedProgress)
                .stroke(KlairTheme.emerald, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: KlairTheme.emerald.opacity(0.3), radius: 2)

            Circle()
                .trim(from: (proteinFrac + carbsFrac) * animatedProgress, to: animatedProgress)
                .stroke(KlairTheme.orange, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: KlairTheme.orange.opacity(0.3), radius: 2)

            VStack(spacing: 2) {
                Text("\(Int(total))").font(.system(size: size * 0.22, weight: .bold, design: .rounded)).foregroundStyle(KlairTheme.textPrimary)
                Text("grams").font(.system(size: size * 0.09, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) { animatedProgress = 1.0 }
        }
    }
}
