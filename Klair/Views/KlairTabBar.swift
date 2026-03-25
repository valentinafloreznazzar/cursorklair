import SwiftUI

enum KlairTab: Int, CaseIterable {
    case home = 0, nutrition, sleep, activity, ask, profile

    var icon: String {
        switch self {
        case .home: return "bolt.heart.fill"
        case .nutrition: return "leaf.fill"
        case .sleep: return "moon.zzz.fill"
        case .activity: return "figure.run"
        case .ask: return "sparkles"
        case .profile: return "person.crop.circle"
        }
    }

    var label: String {
        switch self {
        case .home: return "Pulse"
        case .nutrition: return "Fuel"
        case .sleep: return "Sleep"
        case .activity: return "Move"
        case .ask: return "Klair"
        case .profile: return "Vault"
        }
    }

    var activeColor: Color {
        switch self {
        case .home: return KlairTheme.cyan
        case .nutrition: return KlairTheme.emerald
        case .sleep: return KlairTheme.indigo
        case .activity: return KlairTheme.orange
        case .ask: return KlairTheme.amethyst
        case .profile: return KlairTheme.cyan
        }
    }
}

struct KlairTabBar: View {
    @Binding var selectedTab: KlairTab
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(KlairTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear, .black.opacity(0.03)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: KlairTheme.cloudShadow, radius: 24, y: -4)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
    }

    private func tabButton(_ tab: KlairTab) -> some View {
        Button {
            SensoryManager.shared.lightTap()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .medium))
                    .symbolEffect(.bounce, value: selectedTab == tab)
                Text(tab.label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .kerning(0.5)
            }
            .foregroundStyle(selectedTab == tab ? tab.activeColor : KlairTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tab.activeColor.opacity(0.1))
                        .matchedGeometryEffect(id: "TAB_BG", in: animation)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
