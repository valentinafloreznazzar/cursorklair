import Foundation
import SwiftUI
import SwiftData

@Model
final class LabResult {
    @Attribute(.unique) var id: UUID
    var date: Date
    var testType: String
    var value: Double
    var unit: String
    var referenceRangeLow: Double
    var referenceRangeHigh: Double
    var notes: String

    init(
        id: UUID = UUID(), date: Date = Date(), testType: String = "",
        value: Double = 0, unit: String = "", referenceRangeLow: Double = 0,
        referenceRangeHigh: Double = 0, notes: String = ""
    ) {
        self.id = id; self.date = date; self.testType = testType
        self.value = value; self.unit = unit
        self.referenceRangeLow = referenceRangeLow
        self.referenceRangeHigh = referenceRangeHigh; self.notes = notes
    }

    var typeEnum: LabTestType { LabTestType(rawValue: testType) ?? .other }
    var isInRange: Bool { value >= referenceRangeLow && value <= referenceRangeHigh }

    var statusLabel: String {
        if value < referenceRangeLow { return "Low" }
        if value > referenceRangeHigh { return "High" }
        return "Normal"
    }

    var statusColor: Color {
        if isInRange { return KlairTheme.emerald }
        let deviation = value < referenceRangeLow
            ? (referenceRangeLow - value) / referenceRangeLow
            : (value - referenceRangeHigh) / referenceRangeHigh
        return deviation > 0.2 ? KlairTheme.coral : KlairTheme.orange
    }

    var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }
}

enum LabTestType: String, CaseIterable, Codable {
    case ferritin = "ferritin"
    case hemoglobin = "hemoglobin"
    case hba1c = "hba1c"
    case fastingInsulin = "fasting_insulin"
    case fastingGlucose = "fasting_glucose"
    case totalTestosterone = "total_testosterone"
    case freeTestosterone = "free_testosterone"
    case dheas = "dhea_s"
    case tsh = "tsh"
    case freeT3 = "free_t3"
    case freeT4 = "free_t4"
    case vitaminD = "vitamin_d"
    case vitaminB12 = "vitamin_b12"
    case totalCholesterol = "total_cholesterol"
    case ldl = "ldl"
    case hdl = "hdl"
    case triglycerides = "triglycerides"
    case homaIR = "homa_ir"
    case crp = "crp"
    case other = "other"

    var displayName: String {
        switch self {
        case .ferritin: return "Ferritin"
        case .hemoglobin: return "Hemoglobin"
        case .hba1c: return "HbA1c"
        case .fastingInsulin: return "Fasting Insulin"
        case .fastingGlucose: return "Fasting Glucose"
        case .totalTestosterone: return "Total Testosterone"
        case .freeTestosterone: return "Free Testosterone"
        case .dheas: return "DHEA-S"
        case .tsh: return "TSH"
        case .freeT3: return "Free T3"
        case .freeT4: return "Free T4"
        case .vitaminD: return "Vitamin D (25-OH)"
        case .vitaminB12: return "Vitamin B12"
        case .totalCholesterol: return "Total Cholesterol"
        case .ldl: return "LDL"
        case .hdl: return "HDL"
        case .triglycerides: return "Triglycerides"
        case .homaIR: return "HOMA-IR"
        case .crp: return "CRP (Inflammation)"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .ferritin, .hemoglobin: return "drop.fill"
        case .hba1c, .fastingInsulin, .fastingGlucose, .homaIR: return "chart.line.uptrend.xyaxis"
        case .totalTestosterone, .freeTestosterone, .dheas: return "figure.stand"
        case .tsh, .freeT3, .freeT4: return "bolt.heart.fill"
        case .vitaminD, .vitaminB12: return "pills.fill"
        case .totalCholesterol, .ldl, .hdl, .triglycerides: return "heart.circle.fill"
        case .crp: return "flame.fill"
        case .other: return "cross.vial.fill"
        }
    }

    var category: String {
        switch self {
        case .ferritin, .hemoglobin: return "Iron & Anemia"
        case .hba1c, .fastingInsulin, .fastingGlucose, .homaIR: return "Insulin & Glucose"
        case .totalTestosterone, .freeTestosterone, .dheas: return "Androgens (PCOS)"
        case .tsh, .freeT3, .freeT4: return "Thyroid"
        case .vitaminD, .vitaminB12: return "Vitamins"
        case .totalCholesterol, .ldl, .hdl, .triglycerides: return "Lipid Panel"
        case .crp: return "Inflammation"
        case .other: return "Other"
        }
    }
}
