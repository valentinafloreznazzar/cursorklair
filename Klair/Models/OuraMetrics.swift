import Foundation
import SwiftData

@Model
final class OuraMetrics {
    var readinessScore: Int
    var sleepScore: Int
    var hrv: Double
    var date: Date
    var readinessContributorsJSON: String?

    var remSleepMinutes: Double = 0
    var deepSleepMinutes: Double = 0
    var lightSleepMinutes: Double = 0
    var totalSleepMinutes: Double = 0
    var sleepEfficiency: Double = 0
    var temperatureDeviation: Double = 0
    var restingHeartRate: Double = 0
    var hrvDaytimeLow: Double = 0
    var stressFlag: Bool = false

    var respiratoryRate: Double = 0
    var spo2Percentage: Double = 0
    var sleepLatencyMinutes: Double = 0
    var stressScore: Double = 0
    var stressDurationMinutes: Double = 0
    var sleepMidpointDeviation: Double = 0

    init(
        readinessScore: Int, sleepScore: Int, hrv: Double, date: Date,
        readinessContributorsJSON: String? = nil,
        remSleepMinutes: Double = 0, deepSleepMinutes: Double = 0,
        lightSleepMinutes: Double = 0, totalSleepMinutes: Double = 0,
        sleepEfficiency: Double = 0, temperatureDeviation: Double = 0,
        restingHeartRate: Double = 0, hrvDaytimeLow: Double = 0,
        stressFlag: Bool = false,
        respiratoryRate: Double = 15.5, spo2Percentage: Double = 97,
        sleepLatencyMinutes: Double = 12, stressScore: Double = 0,
        stressDurationMinutes: Double = 0, sleepMidpointDeviation: Double = 0
    ) {
        self.readinessScore = readinessScore
        self.sleepScore = sleepScore
        self.hrv = hrv
        self.date = Calendar.current.startOfDay(for: date)
        self.readinessContributorsJSON = readinessContributorsJSON
        self.remSleepMinutes = remSleepMinutes
        self.deepSleepMinutes = deepSleepMinutes
        self.lightSleepMinutes = lightSleepMinutes
        self.totalSleepMinutes = totalSleepMinutes
        self.sleepEfficiency = sleepEfficiency
        self.temperatureDeviation = temperatureDeviation
        self.restingHeartRate = restingHeartRate
        self.hrvDaytimeLow = hrvDaytimeLow
        self.stressFlag = stressFlag
        self.respiratoryRate = respiratoryRate
        self.spo2Percentage = spo2Percentage
        self.sleepLatencyMinutes = sleepLatencyMinutes
        self.stressScore = stressScore
        self.stressDurationMinutes = stressDurationMinutes
        self.sleepMidpointDeviation = sleepMidpointDeviation
    }

    var sleepHours: Double { totalSleepMinutes / 60.0 }
    var remPercentage: Double { totalSleepMinutes > 0 ? (remSleepMinutes / totalSleepMinutes) * 100 : 0 }
    var deepPercentage: Double { totalSleepMinutes > 0 ? (deepSleepMinutes / totalSleepMinutes) * 100 : 0 }

    var readinessContributors: [String: String] {
        guard let json = readinessContributorsJSON,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    var stressLevel: String {
        if stressScore >= 75 { return "High" }
        if stressScore >= 40 { return "Moderate" }
        if stressScore > 0 { return "Low" }
        return stressFlag ? "Elevated" : "Balanced"
    }
}
