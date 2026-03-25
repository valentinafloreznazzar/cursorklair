import Foundation
import SwiftData

@Model
final class OuraActivityDay {
    var date: Date
    var steps: Int
    var activeCalories: Double
    var equivalentWalkingDistanceMeters: Double
    var highIntensityMinutes: Double = 0
    var mediumIntensityMinutes: Double = 0
    var workoutType: String = ""
    var vo2Max: Double = 0
    var trainingLoadAcute: Double = 0
    var trainingLoadChronic: Double = 0

    init(
        date: Date, steps: Int, activeCalories: Double,
        equivalentWalkingDistanceMeters: Double = 0,
        highIntensityMinutes: Double = 0, mediumIntensityMinutes: Double = 0,
        workoutType: String = "",
        vo2Max: Double = 0, trainingLoadAcute: Double = 0, trainingLoadChronic: Double = 0
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
        self.activeCalories = activeCalories
        self.equivalentWalkingDistanceMeters = equivalentWalkingDistanceMeters
        self.highIntensityMinutes = highIntensityMinutes
        self.mediumIntensityMinutes = mediumIntensityMinutes
        self.workoutType = workoutType
        self.vo2Max = vo2Max
        self.trainingLoadAcute = trainingLoadAcute
        self.trainingLoadChronic = trainingLoadChronic
    }

    var totalActiveMinutes: Double { highIntensityMinutes + mediumIntensityMinutes }

    var intensityLevel: String {
        if highIntensityMinutes > 20 { return "High" }
        if totalActiveMinutes > 30 { return "Moderate" }
        return "Light"
    }

    var trainingLoadRatio: Double {
        trainingLoadChronic > 0 ? trainingLoadAcute / trainingLoadChronic : 1.0
    }

    var trainingLoadStatus: String {
        let r = trainingLoadRatio
        if r > 1.5 { return "Overreaching" }
        if r > 1.2 { return "Productive" }
        if r > 0.8 { return "Maintaining" }
        return "Detraining"
    }
}
