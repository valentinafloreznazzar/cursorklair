import Foundation
import SwiftData

struct HealthAlert: Identifiable, Sendable {
    let id = UUID()
    let rule: String
    let severity: Severity
    let icon: String
    let title: String
    let message: String
    let actionHint: String?

    enum Severity: Int, Comparable, Sendable {
        case info = 0, warning = 1, critical = 2
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

enum AlertEngine {

    static func evaluate(
        metrics: [OuraMetrics],
        meals: [MealEntry],
        activities: [OuraActivityDay],
        profile: UserProfile?,
        labs: [LabResult],
        cycleSymptoms: [CycleSymptom]
    ) -> [HealthAlert] {
        var alerts: [HealthAlert] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let week = metrics.sorted { $0.date > $1.date }.prefix(7)
        let weekMeals = meals.filter { $0.timestamp > (cal.date(byAdding: .day, value: -7, to: today) ?? today) }
        let todayMetric = week.first { cal.isDate($0.date, inSameDayAs: today) } ?? week.first
        let avgHRV = week.isEmpty ? 0 : week.map(\.hrv).reduce(0, +) / Double(week.count)

        // RULE 1 — Late meals → sleep degradation
        let lateMeals = weekMeals.filter(\.isLateNight)
        if lateMeals.count >= 2 {
            let avgEff = computeAvgEfficiencyAfterLateMeals(metrics: Array(week), meals: meals, cal: cal)
            alerts.append(HealthAlert(
                rule: "late_meal_sleep", severity: lateMeals.count >= 4 ? .critical : .warning,
                icon: "moon.zzz.fill",
                title: "Late Meals Impacting Sleep",
                message: "\(lateMeals.count) meals after 9 PM this week.\(avgEff > 0 ? " Avg next-day efficiency: \(Int(avgEff))%." : "") Late eating raises core temperature, reducing deep sleep.",
                actionHint: "Finish eating by 8 PM to protect deep sleep."
            ))
        }

        // RULE 2 — Dehydration → HRV reduction
        if let p = profile, p.waterProgress < 0.6 {
            let pct = Int(p.waterProgress * 100)
            alerts.append(HealthAlert(
                rule: "dehydration_hrv", severity: p.waterProgress < 0.4 ? .critical : .warning,
                icon: "drop.triangle.fill",
                title: "Dehydration Risk",
                message: "Only \(pct)% of daily water goal met. Even 2% dehydration can reduce HRV by 5–8%.",
                actionHint: "Drink 500 ml in the next hour."
            ))
        }

        // RULE 3 — Caffeine cutoff (after 2 PM)
        let todayMeals = weekMeals.filter { cal.isDate($0.timestamp, inSameDayAs: today) }
        let lateCaffeine = todayMeals.filter { $0.caffeineMg > 0 && cal.component(.hour, from: $0.timestamp) >= 14 }
        if !lateCaffeine.isEmpty {
            let totalMg = lateCaffeine.reduce(0.0) { $0 + $1.caffeineMg }
            alerts.append(HealthAlert(
                rule: "caffeine_cutoff", severity: totalMg > 150 ? .critical : .warning,
                icon: "cup.and.saucer.fill",
                title: "Late Caffeine Detected",
                message: "\(Int(totalMg)) mg caffeine after 2 PM. Caffeine half-life is ~5 hours — may delay sleep onset by 20–40 min.",
                actionHint: "Switch to herbal tea or decaf."
            ))
        }

        // RULE 4 — Iron deficit (ferritin < range)
        if let ferritin = labs.first(where: { $0.testType == "ferritin" }), ferritin.value < ferritin.referenceRangeLow {
            alerts.append(HealthAlert(
                rule: "iron_deficit", severity: ferritin.value < 12 ? .critical : .warning,
                icon: "drop.fill",
                title: "Iron Stores Below Range",
                message: "Ferritin at \(String(format: "%.0f", ferritin.value)) \(ferritin.unit) (ref: \(Int(ferritin.referenceRangeLow))–\(Int(ferritin.referenceRangeHigh))). Low ferritin impairs oxygen transport and worsens fatigue.",
                actionHint: "Pair iron supplements with Vitamin C; avoid with coffee/dairy."
            ))
        }

        // RULE 5 — B12 + Metformin interaction
        let onMetformin = profile?.medications.localizedCaseInsensitiveContains("metformin") ?? false
        if let b12 = labs.first(where: { $0.testType == "vitamin_b12" }), b12.value < 400 && onMetformin {
            alerts.append(HealthAlert(
                rule: "b12_metformin", severity: b12.value < 250 ? .critical : .warning,
                icon: "pills.fill",
                title: "B12 & Metformin Interaction",
                message: "B12 at \(Int(b12.value)) pg/mL while on Metformin. Long-term Metformin depletes B12, causing fatigue and neuropathy.",
                actionHint: "Discuss sublingual B12 (1000 mcg) with your doctor."
            ))
        }

        // RULE 6 — Glycemic spikes (multiple high-GI meals)
        let highGI = weekMeals.filter(\.isHighGlycemic)
        if highGI.count >= 3 {
            let avgGL = highGI.map(\.glycemicLoad).reduce(0, +) / Double(highGI.count)
            alerts.append(HealthAlert(
                rule: "glycemic_spikes", severity: highGI.count >= 5 ? .critical : .warning,
                icon: "chart.line.uptrend.xyaxis",
                title: "Glycemic Instability",
                message: "\(highGI.count) high-GI meals this week (avg GL: \(Int(avgGL))). Insulin spikes worsen PCOS symptoms and disrupt deep sleep.",
                actionHint: "Add protein or fat to carb-heavy meals to blunt glucose response."
            ))
        }

        // RULE 7 — Overtraining (acute:chronic > 1.5)
        let recentActs = activities.sorted { $0.date > $1.date }
        if let todayAct = recentActs.first, todayAct.trainingLoadRatio > 1.5 {
            alerts.append(HealthAlert(
                rule: "overtraining", severity: todayAct.trainingLoadRatio > 1.8 ? .critical : .warning,
                icon: "figure.run",
                title: "Overtraining Risk",
                message: "Training load ratio at \(String(format: "%.1f", todayAct.trainingLoadRatio))× (acute/chronic). Injury risk increases above 1.5×.",
                actionHint: "Take a rest day or reduce intensity by 30%."
            ))
        }

        // RULE 8 — Cycle-phase workout mismatch
        if let p = profile {
            let phase = p.cyclePhase
            let todayAct = recentActs.first
            if (phase == .menstrual || phase == .luteal) && (todayAct?.highIntensityMinutes ?? 0) > 20 {
                alerts.append(HealthAlert(
                    rule: "cycle_mismatch", severity: .warning,
                    icon: "figure.cooldown",
                    title: "Cycle-Phase Mismatch",
                    message: "\(phase.rawValue) phase (Day \(p.cycleDay)): high-intensity training detected. Progesterone/estrogen levels may impair recovery.",
                    actionHint: "Swap HIIT for Pilates or moderate-intensity work."
                ))
            }
        }

        // RULE 9 — Stress accumulation (3+ days with elevated stress)
        let stressDays = week.filter { $0.stressScore >= 50 || $0.stressFlag }.count
        if stressDays >= 3 {
            alerts.append(HealthAlert(
                rule: "stress_accumulation", severity: stressDays >= 5 ? .critical : .warning,
                icon: "brain.head.profile.fill",
                title: "Chronic Stress Pattern",
                message: "\(stressDays) of last 7 days with elevated autonomic stress. Sustained cortisol impairs sleep architecture and immune function.",
                actionHint: "Try a 10-min breathwork or cold exposure session tonight."
            ))
        }

        // RULE 10 — Sleep debt accumulation
        if let p = profile {
            let goalMin = p.sleepGoalHours * 60
            let debt = week.map { max(0, goalMin - $0.totalSleepMinutes) }.reduce(0, +)
            let debtHours = debt / 60
            if debtHours > 3 {
                alerts.append(HealthAlert(
                    rule: "sleep_debt", severity: debtHours > 7 ? .critical : .warning,
                    icon: "bed.double.fill",
                    title: "Sleep Debt Accumulating",
                    message: "\(String(format: "%.1f", debtHours))h sleep debt over 7 days. Research shows >5h weekly debt increases insulin resistance by 15%.",
                    actionHint: "Add 30 min to tonight's bedtime. Avoid screens after 10 PM."
                ))
            }
        }

        // RULE 11 — Temperature deviation
        if let t = todayMetric, abs(t.temperatureDeviation) > 0.5 {
            let direction = t.temperatureDeviation > 0 ? "elevated" : "low"
            let isLuteal = profile?.cyclePhase == .luteal
            alerts.append(HealthAlert(
                rule: "temperature_deviation", severity: abs(t.temperatureDeviation) > 1.0 ? .critical : (isLuteal ? .info : .warning),
                icon: "thermometer.medium",
                title: "Temperature \(direction.capitalized)",
                message: "Body temp \(t.temperatureDeviation >= 0 ? "+" : "")\(String(format: "%.2f", t.temperatureDeviation))°C from baseline.\(isLuteal ? " Progesterone-driven rise is expected in luteal phase." : " May indicate inflammation or early illness.")",
                actionHint: isLuteal ? nil : "Monitor symptoms. Rest if feeling unwell."
            ))
        }

        return alerts.sorted { $0.severity > $1.severity }
    }

    private static func computeAvgEfficiencyAfterLateMeals(
        metrics: [OuraMetrics], meals: [MealEntry], cal: Calendar
    ) -> Double {
        var efficiencies: [Double] = []
        for meal in meals where meal.isLateNight {
            let mealDay = cal.startOfDay(for: meal.timestamp)
            guard let nextDay = cal.date(byAdding: .day, value: 1, to: mealDay),
                  let m = metrics.first(where: { cal.isDate($0.date, inSameDayAs: nextDay) }) else { continue }
            efficiencies.append(m.sleepEfficiency)
        }
        guard !efficiencies.isEmpty else { return 0 }
        return efficiencies.reduce(0, +) / Double(efficiencies.count)
    }
}
