import Foundation
import SwiftUI
import SwiftData

@Model
final class CycleSymptom {
    @Attribute(.unique) var id: UUID
    var date: Date
    var cycleDay: Int
    var phase: String

    var bloating: Int
    var cramps: Int
    var acne: Int
    var headache: Int
    var breastTenderness: Int
    var cravings: Int
    var moodSwings: Int
    var fatigue: Int
    var libido: Int
    var notes: String

    init(
        id: UUID = UUID(), date: Date = Date(), cycleDay: Int = 1, phase: String = "Follicular",
        bloating: Int = 0, cramps: Int = 0, acne: Int = 0, headache: Int = 0,
        breastTenderness: Int = 0, cravings: Int = 0, moodSwings: Int = 0,
        fatigue: Int = 0, libido: Int = 0, notes: String = ""
    ) {
        self.id = id; self.date = date; self.cycleDay = cycleDay; self.phase = phase
        self.bloating = bloating; self.cramps = cramps; self.acne = acne
        self.headache = headache; self.breastTenderness = breastTenderness
        self.cravings = cravings; self.moodSwings = moodSwings
        self.fatigue = fatigue; self.libido = libido; self.notes = notes
    }

    var pmsSeverityScore: Int {
        let total = bloating + cramps + acne + headache + breastTenderness + cravings + moodSwings + fatigue
        return total
    }

    var pmsSeverityLabel: String {
        let s = pmsSeverityScore
        if s <= 5 { return "Minimal" }
        if s <= 12 { return "Mild" }
        if s <= 20 { return "Moderate" }
        return "Severe"
    }

    var pmsSeverityColor: Color {
        let s = pmsSeverityScore
        if s <= 5 { return KlairTheme.emerald }
        if s <= 12 { return KlairTheme.cyan }
        if s <= 20 { return KlairTheme.orange }
        return KlairTheme.coral
    }

    var topSymptoms: [(name: String, severity: Int)] {
        let all: [(String, Int)] = [
            ("Bloating", bloating), ("Cramps", cramps), ("Acne", acne),
            ("Headache", headache), ("Breast Tenderness", breastTenderness),
            ("Cravings", cravings), ("Mood Swings", moodSwings), ("Fatigue", fatigue)
        ]
        return all.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(3).map { (name: $0.0, severity: $0.1) }
    }

    static let symptomIcons: [String: String] = [
        "Bloating": "wind", "Cramps": "bolt.fill", "Acne": "face.dashed",
        "Headache": "brain.head.profile", "Breast Tenderness": "heart.fill",
        "Cravings": "fork.knife", "Mood Swings": "theatermasks.fill",
        "Fatigue": "battery.25percent"
    ]
}
