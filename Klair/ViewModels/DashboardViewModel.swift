import Foundation
import SwiftData
import Observation

struct MultiLayerChartPoint: Identifiable, Sendable {
    var id: String { isoDay }
    let isoDay: String; let label: String; let sleepScore: Int
    let hrvValue: Double; let sugarIntake: Double
    let readinessScore: Int; let lateNightCalories: Double
}

struct SleepBreakdown: Sendable {
    let remMinutes: Double; let deepMinutes: Double; let lightMinutes: Double
    let totalMinutes: Double; let efficiency: Double
    var remHours: String { String(format: "%.1f", remMinutes / 60) }
    var deepHours: String { String(format: "%.1f", deepMinutes / 60) }
    var lightHours: String { String(format: "%.1f", lightMinutes / 60) }
    var totalHours: String { String(format: "%.1f", totalMinutes / 60) }
}

struct StressInsight: Sendable {
    let level: String; let description: String; let hrvDropPercent: Double; let peakTime: String?
    var color: String {
        switch level {
        case "Elevated": return "FF4757"
        case "Moderate": return "FF6B35"
        default: return "00C9A7"
        }
    }
}

struct WeekSummary: Sendable {
    let avgReadiness: Int; let avgSleep: Int; let avgHRV: Double
    let bestDay: String; let worstDay: String
    let totalSteps: Int; let avgRHR: Double
    let avgRespiratoryRate: Double; let avgSpO2: Double
}

struct RecoveryCorrelation: Sendable {
    let yesterdayActivity: String; let todayReadinessChange: Int; let description: String
}

@Observable @MainActor
final class DashboardViewModel {
    private let modelContext: ModelContext
    private let oura = OuraAPIService()
    private let gemini = GeminiService()
    var isLoadingAI = false

    var todayReadiness: Int = 0
    var todaySleep: Int = 0
    var todayHRV: Double = 0
    var avgHRV: Double = 0
    var todayCaloriesConsumed: Double = 0
    var dailyCalorieGoal: Double = 2000
    var sleepBreakdown = SleepBreakdown(remMinutes: 0, deepMinutes: 0, lightMinutes: 0, totalMinutes: 0, efficiency: 0)
    var stressInsight = StressInsight(level: "Low", description: "Balanced.", hrvDropPercent: 0, peakTime: nil)
    var cyclePhase: CyclePhase = .follicular
    var cycleDay: Int = 1
    var cycleImpact: String = ""
    var temperatureDeviation: Double = 0
    var restingHeartRate: Double = 0
    var todaySteps: Int = 0
    var todayActiveCalories: Double = 0
    var todayWorkoutType: String = ""
    var recoveryCorrelation: RecoveryCorrelation?
    var healthInsight: String?
    var cycleLine: String = ""
    var workoutsLine: String = ""
    var chartPoints: [MultiLayerChartPoint] = []
    var proactiveInsights: [String] = []
    var isSyncingOura: Bool = false
    var ouraSyncMessage: String?

    var inspirationalQuote: String = ""
    var dailyNarrative: String = ""
    var dailyInsight: String = ""
    var readinessContributors: [(key: String, value: String)] = []
    var respiratoryRate: Double = 0
    var spo2: Double = 0
    var stressScore: Double = 0
    var stressDurationMinutes: Double = 0
    var waterProgress: Double = 0
    var waterIntakeMl: Double = 0
    var waterGoalMl: Double = 2500
    var weekSummary: WeekSummary?
    var healthAlerts: [HealthAlert] = []
    var correlations: [CorrelationResult] = []

    private static let quotes = [
        "Wellness is not a destination — it is a practice of listening.",
        "Your body speaks in rhythms. Sleep is its poetry.",
        "The greatest wealth is health. — Virgil",
        "Listen to your body when it whispers, so you don't have to hear it scream.",
        "Nature itself is the best physician. — Hippocrates",
        "Healing is a matter of time, but it is sometimes a matter of opportunity.",
        "The body achieves what the mind believes.",
    ]

    init(modelContext: ModelContext) { self.modelContext = modelContext }

    func load(health: HealthKitService?) {
        refreshFromStore()
        Task {
            await health?.requestAuthorization()
            await refreshHealthSummaries(health: health)
            await generateAINarrative()
        }
    }

    func refreshFromStore() {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())

        var profileDesc = FetchDescriptor<UserProfile>(); profileDesc.fetchLimit = 1
        if let p = try? modelContext.fetch(profileDesc).first {
            dailyCalorieGoal = p.dailyCalorieGoal; cyclePhase = p.cyclePhase
            cycleDay = p.cycleDay; cycleImpact = p.cyclePhase.readinessImpact
            waterProgress = p.waterProgress; waterIntakeMl = p.waterIntakeMl; waterGoalMl = p.dailyWaterGoalMl
        }

        var metricsDesc = FetchDescriptor<OuraMetrics>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let metrics = (try? modelContext.fetch(metricsDesc)) ?? []
        let todayMetric = metrics.first { cal.isDate($0.date, inSameDayAs: today) }
        let latest = todayMetric ?? metrics.first
        todayReadiness = latest?.readinessScore ?? 0
        todaySleep = latest?.sleepScore ?? 0
        todayHRV = latest?.hrv ?? 0
        temperatureDeviation = latest?.temperatureDeviation ?? 0
        restingHeartRate = latest?.restingHeartRate ?? 0
        respiratoryRate = latest?.respiratoryRate ?? 0
        spo2 = latest?.spo2Percentage ?? 0
        stressScore = latest?.stressScore ?? 0
        stressDurationMinutes = latest?.stressDurationMinutes ?? 0
        readinessContributors = latest?.readinessContributors.sorted(by: { $0.key < $1.key }) ?? []

        let recent = Array(metrics.prefix(7))
        avgHRV = recent.isEmpty ? 0 : recent.map(\.hrv).reduce(0, +) / Double(recent.count)

        if let m = latest {
            sleepBreakdown = SleepBreakdown(remMinutes: m.remSleepMinutes, deepMinutes: m.deepSleepMinutes, lightMinutes: m.lightSleepMinutes, totalMinutes: m.totalSleepMinutes, efficiency: m.sleepEfficiency)
        }
        computeStressInsight(metrics: recent, todayMetric: latest)

        var mealsDesc = FetchDescriptor<MealEntry>()
        let meals = (try? modelContext.fetch(mealsDesc)) ?? []
        todayCaloriesConsumed = meals.filter { cal.isDate($0.timestamp, inSameDayAs: today) }.reduce(0) { $0 + $1.calories }

        var actDesc = FetchDescriptor<OuraActivityDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let acts = (try? modelContext.fetch(actDesc)) ?? []
        let todayAct = acts.first { cal.isDate($0.date, inSameDayAs: today) } ?? acts.first
        todaySteps = todayAct?.steps ?? 0
        todayActiveCalories = todayAct?.activeCalories ?? 0
        todayWorkoutType = todayAct?.workoutType ?? ""

        computeRecoveryCorrelation(acts: acts, metrics: metrics, calendar: cal, today: today)
        healthInsight = computeLateDinnerInsight(metrics: metrics, meals: meals, calendar: cal)
        chartPoints = buildChartPoints(metrics: metrics, meals: meals, acts: acts, calendar: cal, today: today)

        // AlertEngine (11 rules)
        let labs = (try? modelContext.fetch(FetchDescriptor<LabResult>())) ?? []
        let cycleSymptoms = (try? modelContext.fetch(FetchDescriptor<CycleSymptom>())) ?? []
        healthAlerts = AlertEngine.evaluate(
            metrics: metrics, meals: meals, activities: acts,
            profile: (try? modelContext.fetch(profileDesc))?.first,
            labs: labs, cycleSymptoms: cycleSymptoms
        )

        // Pearson Correlations
        correlations = CorrelationEngine.computeAll(
            metrics: metrics, meals: meals, activities: acts,
            profile: (try? modelContext.fetch(profileDesc))?.first
        )

        buildProactiveInsights(metrics: metrics, meals: meals)
        buildWeekSummary(metrics: metrics, acts: acts)
        inspirationalQuote = Self.quotes[cal.component(.day, from: Date()) % Self.quotes.count]

        var narrative: [String] = []
        narrative.append("Your readiness score of \(todayReadiness) reflects \(todayReadiness >= 75 ? "a solid" : "a recovering") night of \(sleepBreakdown.totalHours)h sleep.")
        if cyclePhase == .luteal || cyclePhase == .menstrual {
            narrative.append("Your \(cyclePhase.rawValue.lowercased()) phase may influence HRV and energy — this is normal physiology.")
        }
        if todaySteps > 0 { narrative.append("With \(todaySteps) steps today, \(todayReadiness >= 70 ? "your body is responding well to training load" : "gentle recovery is recommended").") }
        dailyNarrative = narrative.joined(separator: " ")

        if todayReadiness >= 80 { dailyInsight = "Marta, your readiness is high — today is the perfect day for a peak performance workout." }
        else if todayReadiness >= 65 { dailyInsight = "Moderate readiness today. A balanced day of light activity and mindful nutrition will serve you well." }
        else { dailyInsight = "Recovery mode activated. Prioritize rest, hydration, and restorative movement today." }
    }

    func syncOuraFromCloud() async {
        isSyncingOura = true; ouraSyncMessage = nil; defer { isSyncingOura = false }
        if DemoMode.useMockRemoteServices {
            try? await Task.sleep(nanoseconds: 400_000_000)
            ouraSyncMessage = "Demo mode — sample data active."; refreshFromStore(); return
        }
        let end = Date(); let start = Calendar.current.date(byAdding: .day, value: -13, to: end) ?? end
        do {
            let merged = try await oura.fetchMergedDailyMetrics(startDate: start, endDate: end)
            let activity = try await oura.fetchActivityDays(startDate: start, endDate: end)
            guard !merged.isEmpty || !activity.isEmpty else { ouraSyncMessage = "No data."; return }
            try replaceAll(OuraMetrics.self); try replaceAll(OuraActivityDay.self)
            merged.forEach { modelContext.insert($0) }; activity.forEach { modelContext.insert($0) }
            try modelContext.save(); ouraSyncMessage = "Oura synced."
        } catch { ouraSyncMessage = "Sync skipped." }
        refreshFromStore()
    }

    private func computeStressInsight(metrics: [OuraMetrics], todayMetric: OuraMetrics?) {
        guard let t = todayMetric, avgHRV > 0 else {
            stressInsight = StressInsight(level: "Unknown", description: "Insufficient data.", hrvDropPercent: 0, peakTime: nil); return
        }
        let drop = ((avgHRV - t.hrvDaytimeLow) / avgHRV) * 100
        if t.stressFlag || drop > 25 {
            stressInsight = StressInsight(level: "Elevated", description: "HRV dropped \(Int(drop))% below your 7-day average. A breathwork session tonight could help.", hrvDropPercent: drop, peakTime: "~4:00 PM")
        } else if drop > 12 {
            stressInsight = StressInsight(level: "Moderate", description: "Mild HRV dip (\(Int(drop))%). Watch stimulant intake this evening.", hrvDropPercent: drop, peakTime: nil)
        } else {
            stressInsight = StressInsight(level: "Low", description: "HRV stable within your normal range. Autonomic balance is solid.", hrvDropPercent: drop, peakTime: nil)
        }
    }

    private func computeRecoveryCorrelation(acts: [OuraActivityDay], metrics: [OuraMetrics], calendar: Calendar, today: Date) {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let yAct = acts.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) }),
              let tMet = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: today) }),
              let yMet = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) }) else { recoveryCorrelation = nil; return }
        let change = tMet.readinessScore - yMet.readinessScore
        let label = yAct.workoutType.isEmpty ? "\(yAct.steps) steps" : yAct.workoutType
        let desc = yAct.highIntensityMinutes > 20 && change < -5
            ? "Yesterday's \(label) contributed to today's \(abs(change))-point drop. Active recovery recommended."
            : change > 5 ? "Solid recovery. \(label) was well-tolerated." : "Recovery tracking normally after \(label)."
        recoveryCorrelation = RecoveryCorrelation(yesterdayActivity: label, todayReadinessChange: change, description: desc)
    }

    private func buildProactiveInsights(metrics: [OuraMetrics], meals: [MealEntry]) {
        var ins: [String] = []
        if stressInsight.level == "Elevated" { ins.append("HRV-based stress elevated around \(stressInsight.peakTime ?? "afternoon") after your \(todayWorkoutType.isEmpty ? "workout" : todayWorkoutType) — autonomic recovery is lower tonight. Try a 5-minute breathwork session.") }
        let late = meals.filter(\.isLateNight)
        if late.count >= 3 { ins.append("\(late.count) late-night meals this week correlate with ~8% lower sleep efficiency.") }
        let glyc = meals.filter(\.isHighGlycemic)
        if glyc.count >= 3 { ins.append("Multiple high-glycemic meals detected — may drive energy crashes and reduce deep sleep.") }
        if cyclePhase == .luteal { ins.append("Luteal phase (Day \(cycleDay)) — progesterone raises baseline temp and may lower HRV. Normal physiology.") }
        if let rc = recoveryCorrelation, rc.todayReadinessChange < -8 { ins.append("Readiness dropped \(abs(rc.todayReadinessChange)) points. Prioritize hydration and 7.5+ hrs sleep.") }
        proactiveInsights = ins
    }

    private func computeLateDinnerInsight(metrics: [OuraMetrics], meals: [MealEntry], calendar: Calendar) -> String? {
        guard let last = meals.max(by: { $0.timestamp < $1.timestamp }), calendar.component(.hour, from: last.timestamp) >= 21 else { return nil }
        let avg = metrics.sorted { $0.date > $1.date }.prefix(7)
        guard !avg.isEmpty else { return nil }
        let avgHRV = avg.map(\.hrv).reduce(0, +) / Double(avg.count)
        let today = calendar.startOfDay(for: Date())
        guard let hrv = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: today) })?.hrv ?? metrics.max(by: { $0.date < $1.date })?.hrv, hrv < avgHRV else { return nil }
        return "Late dinner correlating with lower recovery signals"
    }

    private func buildChartPoints(metrics: [OuraMetrics], meals: [MealEntry], acts: [OuraActivityDay], calendar: Calendar, today: Date) -> [MultiLayerChartPoint] {
        let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEE"
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withFullDate]
        var pts: [MultiLayerChartPoint] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let start = calendar.startOfDay(for: day)
            let m = metrics.first { calendar.isDate($0.date, inSameDayAs: start) }
            let dm = meals.filter { calendar.isDate($0.timestamp, inSameDayAs: start) }
            pts.append(MultiLayerChartPoint(isoDay: iso.string(from: start), label: dayFmt.string(from: start), sleepScore: m?.sleepScore ?? 0, hrvValue: m?.hrv ?? 0, sugarIntake: dm.filter(\.isHighGlycemic).reduce(0) { $0 + $1.carbs }, readinessScore: m?.readinessScore ?? 0, lateNightCalories: dm.filter(\.isLateNight).reduce(0) { $0 + $1.calories }))
        }
        return pts
    }

    private func buildWeekSummary(metrics: [OuraMetrics], acts: [OuraActivityDay]) {
        let week = Array(metrics.prefix(7))
        guard !week.isEmpty else { weekSummary = nil; return }
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        let avgR = week.map(\.readinessScore).reduce(0, +) / week.count
        let avgS = week.map(\.sleepScore).reduce(0, +) / week.count
        let avgH = week.map(\.hrv).reduce(0, +) / Double(week.count)
        let avgRHR = week.map(\.restingHeartRate).reduce(0, +) / Double(week.count)
        let avgResp = week.map(\.respiratoryRate).reduce(0, +) / Double(week.count)
        let avgSp = week.map(\.spo2Percentage).reduce(0, +) / Double(week.count)
        let best = week.max(by: { $0.readinessScore < $1.readinessScore })
        let worst = week.min(by: { $0.readinessScore < $1.readinessScore })
        let steps = Array(acts.prefix(7)).map(\.steps).reduce(0, +)
        weekSummary = WeekSummary(
            avgReadiness: avgR, avgSleep: avgS, avgHRV: avgH,
            bestDay: best.map { fmt.string(from: $0.date) } ?? "—",
            worstDay: worst.map { fmt.string(from: $0.date) } ?? "—",
            totalSteps: steps, avgRHR: avgRHR,
            avgRespiratoryRate: avgResp, avgSpO2: avgSp
        )
    }

    private func replaceAll<T: SwiftData.PersistentModel>(_ type: T.Type) throws { try modelContext.fetch(FetchDescriptor<T>()).forEach { modelContext.delete($0) } }

    private func refreshHealthSummaries(health: HealthKitService?) async {
        guard let health else { cycleLine = ""; workoutsLine = ""; return }
        let flows = await health.recentMenstrualEvents(limit: 3)
        cycleLine = flows.isEmpty ? (DemoMode.useMockRemoteServices ? "Medium flow 2 days ago" : "Enable Health access") : flows.map { let f = DateFormatter(); f.dateStyle = .medium; return "\(f.string(from: $0.date)) (\($0.flowLabel))" }.joined(separator: " · ")
        let w = await health.recentWorkouts(limit: 3)
        workoutsLine = w.isEmpty ? (DemoMode.useMockRemoteServices ? "Strength 35m · Walk 22m" : "No recent workouts") : w.map { "\($0.activityName) \(Int($0.durationMinutes))m" }.joined(separator: " · ")
    }

    // MARK: - AI-Powered Narrative & Insights

    private func generateAINarrative() async {
        guard !DemoMode.useMockRemoteServices else { return }
        isLoadingAI = true
        defer { isLoadingAI = false }

        let contextJSON = buildDashboardContextJSON()
        guard !contextJSON.isEmpty else { return }

        async let narrativeTask: String? = {
            try? await self.gemini.generateInsight(
                prompt: "Generate a personalized daily health narrative for Marta in 2-3 warm, concise sentences. Reference her readiness score, sleep quality, cycle phase, and any notable patterns. Address her directly.",
                contextJSON: contextJSON
            )
        }()
        async let insightTask: String? = {
            try? await self.gemini.generateInsight(
                prompt: "Give Marta one specific, actionable health tip for today based on her current data. Be warm and practical. One sentence only.",
                contextJSON: contextJSON
            )
        }()

        let (narrativeResult, insightResult) = await (narrativeTask, insightTask)

        if let n = narrativeResult, !n.isEmpty {
            dailyNarrative = n
        }
        if let i = insightResult, !i.isEmpty {
            dailyInsight = i
        }
    }

    private func buildDashboardContextJSON() -> String {
        var profileDesc = FetchDescriptor<UserProfile>(); profileDesc.fetchLimit = 1
        let profile = try? modelContext.fetch(profileDesc).first

        var metricsDesc = FetchDescriptor<OuraMetrics>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        metricsDesc.fetchLimit = 7
        let metrics = (try? modelContext.fetch(metricsDesc)) ?? []

        var mealsDesc = FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        mealsDesc.fetchLimit = 7
        let meals = (try? modelContext.fetch(mealsDesc)) ?? []

        var actDesc = FetchDescriptor<OuraActivityDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        actDesc.fetchLimit = 7
        let acts = (try? modelContext.fetch(actDesc)) ?? []

        let compact: [String: Any] = [
            "readiness": todayReadiness,
            "sleepScore": todaySleep,
            "hrv": todayHRV,
            "avgHRV7d": avgHRV,
            "sleepHours": String(format: "%.1f", sleepBreakdown.totalMinutes / 60),
            "deepSleepMin": sleepBreakdown.deepMinutes,
            "remSleepMin": sleepBreakdown.remMinutes,
            "sleepEfficiency": sleepBreakdown.efficiency,
            "stressLevel": stressInsight.level,
            "cyclePhase": cyclePhase.rawValue,
            "cycleDay": cycleDay,
            "temperatureDeviation": temperatureDeviation,
            "restingHeartRate": restingHeartRate,
            "steps": todaySteps,
            "activeCalories": todayActiveCalories,
            "caloriesConsumed": todayCaloriesConsumed,
            "calorieGoal": dailyCalorieGoal,
            "waterProgress": String(format: "%.0f%%", waterProgress * 100),
            "workout": todayWorkoutType,
            "name": profile?.name ?? "Marta",
            "conditions": profile?.knownConditions ?? "",
            "medications": profile?.medications ?? "",
            "lateMealsThisWeek": meals.filter(\.isLateNight).count,
            "highGIMealsThisWeek": meals.filter(\.isHighGlycemic).count,
            "alertsSummary": healthAlerts.prefix(3).map(\.title).joined(separator: ", ")
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: compact, options: [.sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "" }
        return str
    }
}
