import SwiftUI
import SwiftData

@main
struct KlairApp: App {
    @StateObject private var healthKit = HealthKitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKit)
        }
        .modelContainer(for: [
            OuraMetrics.self,
            OuraActivityDay.self,
            MealEntry.self,
            UserProfile.self,
            EnergyActivity.self,
            LabResult.self,
            CycleSymptom.self,
        ])
    }
}
