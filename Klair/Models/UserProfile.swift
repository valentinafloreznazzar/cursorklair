import Foundation
import SwiftUI
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var profileId: UUID
    var name: String
    var weightKg: Double
    var heightCm: Double
    var dailyCalorieGoal: Double
    var menstruationTrackingEnabled: Bool
    var knownConditions: String = ""
    var healthGoals: String = ""
    var cycleDay: Int = 18
    var cycleLength: Int = 28
    var hasCompletedOnboarding: Bool = false
    var age: Int = 28
    var ouraConnected: Bool = true
    var medications: String = ""
    var waterIntakeMl: Double = 0
    var dailyWaterGoalMl: Double = 2500

    var bloodPressureSystolic: Int = 0
    var bloodPressureDiastolic: Int = 0
    var glucoseMgDl: Double = 0
    var moodRating: Int = 0
    var energyRating: Int = 0
    var bodyFatPercentage: Double = 0
    var lastMenstrualFlow: String = ""
    var waistCm: Double = 0
    var hipCm: Double = 0
    var sleepGoalHours: Double = 7.5

    init(
        profileId: UUID = UUID(), name: String = "Marta",
        weightKg: Double = 62, heightCm: Double = 168,
        dailyCalorieGoal: Double = 2000, menstruationTrackingEnabled: Bool = true,
        knownConditions: String = "", healthGoals: String = "",
        cycleDay: Int = 18, cycleLength: Int = 28,
        hasCompletedOnboarding: Bool = false, age: Int = 28, ouraConnected: Bool = true,
        medications: String = "", waterIntakeMl: Double = 0, dailyWaterGoalMl: Double = 2500,
        bloodPressureSystolic: Int = 0, bloodPressureDiastolic: Int = 0,
        glucoseMgDl: Double = 0, moodRating: Int = 0, energyRating: Int = 0,
        bodyFatPercentage: Double = 0, lastMenstrualFlow: String = "",
        waistCm: Double = 0, hipCm: Double = 0, sleepGoalHours: Double = 7.5
    ) {
        self.profileId = profileId; self.name = name
        self.weightKg = weightKg; self.heightCm = heightCm
        self.dailyCalorieGoal = dailyCalorieGoal
        self.menstruationTrackingEnabled = menstruationTrackingEnabled
        self.knownConditions = knownConditions; self.healthGoals = healthGoals
        self.cycleDay = cycleDay; self.cycleLength = cycleLength
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.age = age; self.ouraConnected = ouraConnected
        self.medications = medications; self.waterIntakeMl = waterIntakeMl
        self.dailyWaterGoalMl = dailyWaterGoalMl
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
        self.glucoseMgDl = glucoseMgDl
        self.moodRating = moodRating; self.energyRating = energyRating
        self.bodyFatPercentage = bodyFatPercentage
        self.lastMenstrualFlow = lastMenstrualFlow
        self.waistCm = waistCm; self.hipCm = hipCm
        self.sleepGoalHours = sleepGoalHours
    }

    var conditionsList: [String] { knownConditions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var goalsList: [String] { healthGoals.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var medicationsList: [String] { medications.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    var cyclePhase: CyclePhase { CyclePhase.from(day: cycleDay, cycleLength: cycleLength) }
    var waterProgress: Double { dailyWaterGoalMl > 0 ? min(1, waterIntakeMl / dailyWaterGoalMl) : 0 }

    var bmi: Double {
        let heightM = heightCm / 100
        guard heightM > 0 else { return 0 }
        return weightKg / (heightM * heightM)
    }

    var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    var bloodPressureString: String {
        guard bloodPressureSystolic > 0 else { return "—" }
        return "\(bloodPressureSystolic)/\(bloodPressureDiastolic)"
    }

    var bpCategory: String {
        if bloodPressureSystolic == 0 { return "Not recorded" }
        if bloodPressureSystolic < 120 && bloodPressureDiastolic < 80 { return "Normal" }
        if bloodPressureSystolic < 130 { return "Elevated" }
        if bloodPressureSystolic < 140 { return "High Stage 1" }
        return "High Stage 2"
    }

    var waistToHipRatio: Double {
        guard hipCm > 0 else { return 0 }
        return waistCm / hipCm
    }

    var whrCategory: String {
        guard waistToHipRatio > 0 else { return "Not recorded" }
        if waistToHipRatio < 0.80 { return "Low Risk" }
        if waistToHipRatio < 0.85 { return "Moderate Risk" }
        return "High Risk"
    }

    var bmr: Double {
        guard heightCm > 0, weightKg > 0, age > 0 else { return 0 }
        return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
    }
}

enum CyclePhase: String, CaseIterable {
    case menstrual = "Menstrual"
    case follicular = "Follicular"
    case ovulation = "Ovulation"
    case luteal = "Luteal"

    var icon: String {
        switch self {
        case .menstrual: return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation: return "sparkles"
        case .luteal: return "moon.fill"
        }
    }

    var phaseColor: Color {
        switch self {
        case .menstrual: return KlairTheme.coral
        case .follicular: return KlairTheme.emerald
        case .ovulation: return KlairTheme.cyan
        case .luteal: return KlairTheme.orange
        }
    }

    var readinessImpact: String {
        switch self {
        case .menstrual: return "Energy may be lower. Prioritize rest and iron-rich foods."
        case .follicular: return "Rising estrogen supports higher energy and recovery."
        case .ovulation: return "Peak energy window. Great time for intense training."
        case .luteal: return "Progesterone rises — expect slightly lower HRV and higher baseline temp."
        }
    }

    var energyLevel: String {
        switch self {
        case .menstrual: return "Low–Moderate"
        case .follicular: return "Rising"
        case .ovulation: return "Peak"
        case .luteal: return "Declining"
        }
    }

    var recommendedWorkout: String {
        switch self {
        case .menstrual: return "Yoga · Walking · Gentle stretching"
        case .follicular: return "HIIT · Strength training · New skills"
        case .ovulation: return "Peak performance · Competitions · Heavy lifts"
        case .luteal: return "Moderate cardio · Pilates · Swimming"
        }
    }

    static func from(day: Int, cycleLength: Int) -> CyclePhase {
        let n = ((day - 1) % max(cycleLength, 1)) + 1
        let ov = cycleLength / 2
        switch n {
        case 1...5: return .menstrual
        case 6..<ov: return .follicular
        case ov...(ov + 1): return .ovulation
        default: return .luteal
        }
    }
}
