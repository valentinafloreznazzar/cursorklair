import SwiftUI

struct WellnessImage: View {
    let keywords: String
    let height: CGFloat
    var cornerRadius: CGFloat = 14
    var overlayGradient: Bool = true

    private var url: URL? {
        if let match = Self.curatedPhotos.first(where: { keywords.localizedCaseInsensitiveContains($0.key) }) {
            return URL(string: match.value)
        }
        let seed = abs(keywords.hashValue) % 1000
        return URL(string: "https://picsum.photos/seed/klair\(seed)/600/400")
    }

    // Curated Unsplash CDN URLs — permanent, no API key needed
    private static let curatedPhotos: [(key: String, value: String)] = [
        // Recipe / Food
        ("lentil",    "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&h=400&fit=crop&q=80"),
        ("salmon",    "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&h=400&fit=crop&q=80"),
        ("smoothie",  "https://images.unsplash.com/photo-1638176066666-ffb2f013c7dd?w=600&h=400&fit=crop&q=80"),
        ("grain",     "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&h=400&fit=crop&q=80"),
        ("avocado",   "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&h=400&fit=crop&q=80"),
        ("bowl",      "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&h=400&fit=crop&q=80"),
        ("salad",     "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=400&fit=crop&q=80"),
        ("chicken",   "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=600&h=400&fit=crop&q=80"),
        ("pasta",     "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=600&h=400&fit=crop&q=80"),
        ("eggs",      "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&h=400&fit=crop&q=80"),
        ("oatmeal",   "https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=600&h=400&fit=crop&q=80"),
        ("yogurt",    "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&h=400&fit=crop&q=80"),
        ("toast",     "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&h=400&fit=crop&q=80"),
        ("steak",     "https://images.unsplash.com/photo-1558030006-450675393462?w=600&h=400&fit=crop&q=80"),
        ("fish",      "https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=600&h=400&fit=crop&q=80"),
        ("rice",      "https://images.unsplash.com/photo-1536304929831-ee1ca9d44906?w=600&h=400&fit=crop&q=80"),
        ("soup",      "https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=400&fit=crop&q=80"),
        ("food",      "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&h=400&fit=crop&q=80"),

        // Meditation / Nature
        ("sunrise",   "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=400&fit=crop&q=80"),
        ("morning",   "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&h=400&fit=crop&q=80"),
        ("forest",    "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=400&fit=crop&q=80"),
        ("nature",    "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=400&fit=crop&q=80"),
        ("night",     "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600&h=400&fit=crop&q=80"),
        ("stars",     "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=600&h=400&fit=crop&q=80"),
        ("ocean",     "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&h=400&fit=crop&q=80"),
        ("waves",     "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&h=400&fit=crop&q=80"),
        ("zen",       "https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=600&h=400&fit=crop&q=80"),
        ("meditation","https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=600&h=400&fit=crop&q=80"),
        ("yoga",      "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=600&h=400&fit=crop&q=80"),
    ]

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.4))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
                    .overlay {
                        if overlayGradient {
                            LinearGradient(
                                colors: [.black.opacity(0.55), .black.opacity(0.15), .clear],
                                startPoint: .bottom, endPoint: .top
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .transition(.opacity)
            case .failure:
                fallbackPlaceholder
            case .empty:
                shimmerPlaceholder
            @unknown default:
                shimmerPlaceholder
            }
        }
    }

    private var shimmerPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [KlairTheme.surfaceHigh.opacity(0.3), KlairTheme.surfaceHigh.opacity(0.6), KlairTheme.surfaceHigh.opacity(0.3)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: height)
            .overlay(ProgressView().tint(KlairTheme.textTertiary))
    }

    private var fallbackPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [KlairTheme.amethyst.opacity(0.3), KlairTheme.indigo.opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(height: height)
            .overlay {
                Image(systemName: "photo.fill").font(.system(size: 24)).foregroundStyle(.white.opacity(0.4))
            }
            .overlay {
                if overlayGradient {
                    LinearGradient(
                        colors: [.black.opacity(0.4), .clear],
                        startPoint: .bottom, endPoint: .top
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
    }
}

// MARK: - Carousel Scroll Effect Modifier

struct CarouselScrollEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition(.animated(.spring(response: 0.35))) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                    .opacity(phase.isIdentity ? 1 : 0.7)
                    .rotation3DEffect(
                        .degrees(phase.isIdentity ? 0 : phase.value * 8),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.4
                    )
            }
    }
}

extension View {
    func carouselEffect() -> some View {
        modifier(CarouselScrollEffect())
    }
}

// MARK: - Klair Logo View (Crescent Moon + Pulse Line)

struct KlairLogo: View {
    var size: CGFloat = 24
    var color: Color = KlairTheme.cyan

    var body: some View {
        ZStack {
            Image(systemName: "moon.fill")
                .font(.system(size: size * 0.65, weight: .light))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-25))
                .offset(x: -size * 0.08, y: -size * 0.04)

            PulseLine()
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round))
                .frame(width: size * 0.45, height: size * 0.2)
                .offset(x: size * 0.06, y: size * 0.12)
        }
        .frame(width: size, height: size)
    }
}
