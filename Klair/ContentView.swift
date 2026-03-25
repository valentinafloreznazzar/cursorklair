import SwiftUI
import SwiftData

enum AppPhase {
    case splash, onboarding, main
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Query private var profiles: [UserProfile]
    @State private var phase: AppPhase = .splash
    @State private var selectedTab: KlairTab = .home
    @Namespace private var heroTransition

    private var hasCompletedOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        phase = hasCompletedOnboarding ? .main : .onboarding
                    }
                }
                .transition(.opacity)

            case .onboarding:
                OnboardingView {
                    MockData.bootstrapIfNeeded(context: modelContext)
                    withAnimation(.easeInOut(duration: 0.8)) {
                        phase = .main
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity.combined(with: .scale(scale: 1.02))
                ))

            case .main:
                mainContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: phase)
        .onAppear {
            if hasCompletedOnboarding {
                MockData.bootstrapIfNeeded(context: modelContext)
            }
        }
    }

    private var mainContent: some View {
        Group {
            switch selectedTab {
            case .home: DashboardView()
            case .nutrition: NutritionView()
            case .sleep: SleepView()
            case .activity: ActivityView()
            case .ask: AskAIView()
            case .profile: BioProfileView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        // Inset tab bar into safe area so it does not cover Ask Klair’s TextField, and the keyboard can push content up.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KlairTabBar(selectedTab: $selectedTab)
        }
    }
}
