import Foundation
import SwiftData
import SwiftUI

@Model
final class EnergyActivity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var activityType: String
    var intensity: String
    var energyEffect: String
    var context: String
    var energyDelta: Int
    var linkedHRVChange: Double

    init(
        id: UUID = UUID(), timestamp: Date = Date(),
        activityType: String = "recovery", intensity: String = "medium",
        energyEffect: String = "deposit", context: String = "",
        energyDelta: Int = 0, linkedHRVChange: Double = 0
    ) {
        self.id = id; self.timestamp = timestamp
        self.activityType = activityType; self.intensity = intensity
        self.energyEffect = energyEffect; self.context = context
        self.energyDelta = energyDelta; self.linkedHRVChange = linkedHRVChange
    }

    var typeEnum: ActivityType { ActivityType(rawValue: activityType) ?? .recovery }
    var intensityEnum: IntensityLevel { IntensityLevel(rawValue: intensity) ?? .medium }
    var effectEnum: EnergyEffect { EnergyEffect(rawValue: energyEffect) ?? .deposit }
    var isDeposit: Bool { effectEnum == .deposit }

    var effectColor: Color { isDeposit ? KlairTheme.cyan : KlairTheme.orange }
    var typeIcon: String { typeEnum.icon }

    var timeString: String {
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: timestamp)
    }
}

enum ActivityType: String, CaseIterable, Codable {
    case workout, social, recovery, illness, creative, nature, work, travel

    var icon: String {
        switch self {
        case .workout: return "figure.run"
        case .social: return "person.2.fill"
        case .recovery: return "bed.double.fill"
        case .illness: return "cross.circle.fill"
        case .creative: return "paintbrush.fill"
        case .nature: return "leaf.fill"
        case .work: return "desktopcomputer"
        case .travel: return "airplane"
        }
    }

    var label: String { rawValue.capitalized }
}

enum IntensityLevel: String, CaseIterable, Codable {
    case low, medium, high

    var color: Color {
        switch self {
        case .low: return KlairTheme.emerald
        case .medium: return KlairTheme.orange
        case .high: return KlairTheme.coral
        }
    }
}

enum EnergyEffect: String, CaseIterable, Codable {
    case deposit, withdrawal

    var icon: String {
        switch self {
        case .deposit: return "arrow.up.circle.fill"
        case .withdrawal: return "arrow.down.circle.fill"
        }
    }
}
