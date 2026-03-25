import Foundation
import SwiftData

@Model
final class MealEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    @Attribute(.externalStorage) var imageData: Data?
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var userNotes: String
    /// Display name from AI or manual entry (e.g. "Greek bowl").
    var mealTitle: String = ""
    var micronutrientsJSON: String?
    var isHighGlycemic: Bool = false
    var isLateNight: Bool = false
    var fiber: Double = 0
    var sugar: Double = 0
    var sodium: Double = 0
    var caffeineMg: Double = 0
    var alcoholUnits: Double = 0
    var glycemicLoad: Double = 0

    init(
        id: UUID = UUID(), timestamp: Date, imageData: Data? = nil,
        calories: Double, protein: Double, carbs: Double, fat: Double,
        userNotes: String = "", mealTitle: String = "", micronutrientsJSON: String? = nil,
        isHighGlycemic: Bool = false, isLateNight: Bool = false,
        fiber: Double = 0, sugar: Double = 0, sodium: Double = 0,
        caffeineMg: Double = 0, alcoholUnits: Double = 0, glycemicLoad: Double = 0
    ) {
        self.id = id; self.timestamp = timestamp; self.imageData = imageData
        self.calories = calories; self.protein = protein; self.carbs = carbs; self.fat = fat
        self.userNotes = userNotes; self.mealTitle = mealTitle; self.micronutrientsJSON = micronutrientsJSON
        self.isHighGlycemic = isHighGlycemic; self.isLateNight = isLateNight
        self.fiber = fiber; self.sugar = sugar; self.sodium = sodium
        self.caffeineMg = caffeineMg; self.alcoholUnits = alcoholUnits
        self.glycemicLoad = glycemicLoad
    }

    var micronutrients: [String: Double] {
        guard let json = micronutrientsJSON,
              let data = json.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }

    var macroSummary: String { "P \(Int(protein))g · C \(Int(carbs))g · F \(Int(fat))g" }

    var timeString: String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: timestamp)
    }

    var hasCaffeine: Bool { caffeineMg > 0 }
    var hasAlcohol: Bool { alcoholUnits > 0 }
}
