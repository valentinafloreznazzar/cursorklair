import Foundation
import HealthKit

struct WorkoutSummary: Codable, Sendable, Identifiable {
    var id: String { "\(start.timeIntervalSince1970)-\(activityName)" }
    let activityName: String
    let start: Date
    let end: Date
    let durationMinutes: Double
    let totalEnergyKcal: Double?
}

struct MenstrualEventSummary: Codable, Sendable, Identifiable {
    var id: String { "\(date.timeIntervalSince1970)-\(flowRaw)" }
    let date: Date
    let flowRaw: Int
    let flowLabel: String
}

/// Read-only HealthKit access for cycle + workouts. Handles denied authorization gracefully.
@MainActor
final class HealthKitService: ObservableObject {
    private let store = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else { return }
        var typesToRead: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) {
            typesToRead.insert(flow)
        }
        do {
            try await store.requestAuthorization(toShare: [], read: typesToRead)
        } catch {
            // User denied or restricted — UI should still function.
        }
    }

    func recentWorkouts(limit: Int = 8) async -> [WorkoutSummary] {
        guard isHealthDataAvailable else { return [] }
        let type = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -30, to: Date()), end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let mapped = workouts.map { w in
                    WorkoutSummary(
                        activityName: w.workoutActivityType.name,
                        start: w.startDate,
                        end: w.endDate,
                        durationMinutes: w.duration / 60,
                        totalEnergyKcal: w.totalEnergyBurned.map { $0.doubleValue(for: .kilocalorie()) }
                    )
                }
                cont.resume(returning: mapped)
            }
            store.execute(q)
        }
    }

    func recentMenstrualEvents(limit: Int = 10) async -> [MenstrualEventSummary] {
        guard isHealthDataAvailable else { return [] }
        guard let flowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return [] }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .day, value: -60, to: Date()), end: Date())
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: flowType, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let items = (samples as? [HKCategorySample]) ?? []
                let mapped = items.map { s in
                    MenstrualEventSummary(
                        date: s.endDate,
                        flowRaw: s.value,
                        flowLabel: Self.flowLabel(s.value)
                    )
                }
                cont.resume(returning: mapped)
            }
            store.execute(q)
        }
    }

    private static func flowLabel(_ value: Int) -> String {
        guard let flow = HKCategoryValueMenstrualFlow(rawValue: value) else {
            return "unknown"
        }
        switch flow {
        case .unspecified: return "logged"
        case .none: return "none"
        case .light: return "light"
        case .medium: return "medium"
        case .heavy: return "heavy"
        @unknown default:
            return "unknown"
        }
    }
}

private extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .traditionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        @unknown default:
            return "Workout"
        }
    }
}
