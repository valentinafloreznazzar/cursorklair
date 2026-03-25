import Foundation

struct CorrelationResult: Identifiable, Sendable {
    var id: String { label }
    let label: String
    let rValue: Double
    let icon: String
    let description: String
    let n: Int

    var strength: String {
        let r = abs(rValue)
        if r >= 0.7 { return "Strong" }
        if r >= 0.4 { return "Moderate" }
        if r >= 0.2 { return "Weak" }
        return "Negligible"
    }
}

enum CorrelationEngine {

    static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n >= 3 else { return 0 }
        let xs = Array(x.prefix(n)), ys = Array(y.prefix(n))
        let xMean = xs.reduce(0, +) / Double(n)
        let yMean = ys.reduce(0, +) / Double(n)
        var num = 0.0, dx2 = 0.0, dy2 = 0.0
        for i in 0..<n {
            let dx = xs[i] - xMean, dy = ys[i] - yMean
            num += dx * dy; dx2 += dx * dx; dy2 += dy * dy
        }
        let denom = (dx2 * dy2).squareRoot()
        guard denom > 0 else { return 0 }
        return num / denom
    }

    static func computeAll(
        metrics: [OuraMetrics],
        meals: [MealEntry],
        activities: [OuraActivityDay],
        profile: UserProfile?
    ) -> [CorrelationResult] {
        let cal = Calendar.current
        let sorted = metrics.sorted { $0.date < $1.date }
        guard sorted.count >= 4 else { return [] }

        var results: [CorrelationResult] = []

        // 1: Late-meal binary → next-day sleep score
        let lateAndSleep = buildLateMealVsSleep(sorted: sorted, meals: meals, cal: cal)
        if lateAndSleep.n >= 4 {
            results.append(CorrelationResult(
                label: "Late Meals → Sleep", rValue: lateAndSleep.r,
                icon: "moon.zzz.fill",
                description: lateMealDescription(r: lateAndSleep.r),
                n: lateAndSleep.n
            ))
        }

        // 2: Total sleep minutes → HRV
        let sleepHRV = pearson(sorted.map(\.totalSleepMinutes), sorted.map(\.hrv))
        results.append(CorrelationResult(
            label: "Sleep Duration → HRV", rValue: sleepHRV,
            icon: "waveform.path.ecg",
            description: sleepHRV > 0.3 ? "Longer sleep consistently boosts your HRV." : "Your HRV is relatively stable regardless of sleep length.",
            n: sorted.count
        ))

        // 3: Steps → next-day readiness
        let stepsReady = buildStepsVsReadiness(metrics: sorted, activities: activities, cal: cal)
        if stepsReady.n >= 4 {
            results.append(CorrelationResult(
                label: "Activity → Readiness", rValue: stepsReady.r,
                icon: "figure.walk",
                description: stepsReady.r < -0.2 ? "Higher activity days tend to lower next-day readiness — recovery matters." : "Your body recovers well from daily activity.",
                n: stepsReady.n
            ))
        }

        // 4: Caffeine intake → sleep latency
        let caffLatency = buildCaffeineVsLatency(metrics: sorted, meals: meals, cal: cal)
        if caffLatency.n >= 4 {
            results.append(CorrelationResult(
                label: "Caffeine → Sleep Onset", rValue: caffLatency.r,
                icon: "cup.and.saucer.fill",
                description: caffLatency.r > 0.2 ? "Caffeine intake correlates with longer time to fall asleep." : "Caffeine doesn't strongly affect your sleep onset.",
                n: caffLatency.n
            ))
        }

        // 5: Deep sleep → readiness
        let deepReady = pearson(sorted.map(\.deepSleepMinutes), sorted.map { Double($0.readinessScore) })
        results.append(CorrelationResult(
            label: "Deep Sleep → Readiness", rValue: deepReady,
            icon: "powersleep",
            description: deepReady > 0.4 ? "Deep sleep is a strong driver of your next-day readiness." : "Your readiness depends on factors beyond deep sleep alone.",
            n: sorted.count
        ))

        return results.sorted { abs($0.rValue) > abs($1.rValue) }
    }

    // MARK: - Paired builders

    private struct PairedResult { let r: Double; let n: Int }

    private static func buildLateMealVsSleep(sorted: [OuraMetrics], meals: [MealEntry], cal: Calendar) -> PairedResult {
        var xs: [Double] = [], ys: [Double] = []
        for m in sorted {
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: m.date) else { continue }
            let prevMeals = meals.filter { cal.isDate($0.timestamp, inSameDayAs: prevDay) }
            let hadLate = prevMeals.contains(where: \.isLateNight) ? 1.0 : 0.0
            xs.append(hadLate); ys.append(Double(m.sleepScore))
        }
        return PairedResult(r: pearson(xs, ys), n: xs.count)
    }

    private static func buildStepsVsReadiness(metrics: [OuraMetrics], activities: [OuraActivityDay], cal: Calendar) -> PairedResult {
        var xs: [Double] = [], ys: [Double] = []
        for m in metrics {
            guard let prevDay = cal.date(byAdding: .day, value: -1, to: m.date),
                  let act = activities.first(where: { cal.isDate($0.date, inSameDayAs: prevDay) }) else { continue }
            xs.append(Double(act.steps)); ys.append(Double(m.readinessScore))
        }
        return PairedResult(r: pearson(xs, ys), n: xs.count)
    }

    private static func buildCaffeineVsLatency(metrics: [OuraMetrics], meals: [MealEntry], cal: Calendar) -> PairedResult {
        var xs: [Double] = [], ys: [Double] = []
        for m in metrics {
            let dayMeals = meals.filter { cal.isDate($0.timestamp, inSameDayAs: m.date) }
            let caff = dayMeals.reduce(0.0) { $0 + $1.caffeineMg }
            xs.append(caff); ys.append(m.sleepLatencyMinutes)
        }
        return PairedResult(r: pearson(xs, ys), n: xs.count)
    }

    private static func lateMealDescription(r: Double) -> String {
        if r < -0.3 { return "Late meals strongly correlate with lower sleep scores the following night." }
        if r < -0.15 { return "A moderate pattern: nights after late meals tend to have slightly lower sleep quality." }
        return "No strong link detected yet — keep logging for better insights."
    }
}
