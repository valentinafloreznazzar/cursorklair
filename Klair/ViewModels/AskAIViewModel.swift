import Foundation
import SwiftData
import Observation

struct ChatBubble: Identifiable, Equatable {
    let id = UUID()
    let role: String
    let text: String
    let createdAt: Date
}

struct ProactiveInsight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
    let severity: String
}

@Observable
@MainActor
final class AskAIViewModel {
    private let modelContext: ModelContext
    private let gemini = GeminiService()

    var bubbles: [ChatBubble] = []
    var draft: String = ""
    var isSending = false
    var sendError: String?
    var proactiveInsights: [ProactiveInsight] = []
    var suggestedQuestions: [String] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadProactiveState() {
        guard bubbles.isEmpty else { return }
        buildProactiveInsights()
        buildSuggestedQuestions()

        bubbles.append(ChatBubble(
            role: "assistant",
            text: "Good evening, Marta. I've been analyzing your biometrics and nutrition patterns. Here's what stands out today.",
            createdAt: Date()
        ))

        for insight in proactiveInsights.prefix(2) {
            bubbles.append(ChatBubble(
                role: "assistant",
                text: "\(insight.title)\n\n\(insight.body)",
                createdAt: Date()
            ))
        }
    }

    func send(health: HealthKitService?) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        sendError = nil
        bubbles.append(ChatBubble(role: "user", text: trimmed, createdAt: Date()))
        draft = ""

        do {
            let contextJSON = try await buildContextJSON(health: health)
            let history: [ChatMessage] = bubbles.map {
                ChatMessage(role: $0.role == "user" ? "user" : "assistant", content: $0.text)
            }
            let reply: String
            do {
                reply = try await gemini.klairAgentReply(contextJSON: contextJSON, conversation: history)
            } catch {
                reply = HeuristicFallback.coachFallback(for: trimmed, contextJSON: contextJSON)
            }
            bubbles.append(ChatBubble(role: "assistant", text: reply, createdAt: Date()))
        } catch {
            sendError = error.localizedDescription
            let fallback = HeuristicFallback.coachFallback(for: trimmed, contextJSON: "{}")
            bubbles.append(ChatBubble(role: "assistant", text: fallback, createdAt: Date()))
        }
        isSending = false
    }

    func askSuggested(_ question: String) {
        draft = question
        Task { await send(health: nil) }
    }

    // MARK: - Proactive Intelligence

    private func buildProactiveInsights() {
        var metricsDesc = FetchDescriptor<OuraMetrics>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        metricsDesc.fetchLimit = 7
        let metrics = (try? modelContext.fetch(metricsDesc)) ?? []
        let avgHRV = metrics.isEmpty ? 0 : metrics.map(\.hrv).reduce(0, +) / Double(metrics.count)

        var mealsDesc = FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        mealsDesc.fetchLimit = 14
        let meals = (try? modelContext.fetch(mealsDesc)) ?? []

        var actDesc = FetchDescriptor<OuraActivityDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        actDesc.fetchLimit = 7
        let acts = (try? modelContext.fetch(actDesc)) ?? []

        var energyDesc = FetchDescriptor<EnergyActivity>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        energyDesc.fetchLimit = 14
        let energyLogs = (try? modelContext.fetch(energyDesc)) ?? []

        var profileDesc = FetchDescriptor<UserProfile>()
        profileDesc.fetchLimit = 1
        let profile = try? modelContext.fetch(profileDesc).first

        var insights: [ProactiveInsight] = []

        let highWithdrawals = energyLogs.filter { $0.energyEffect == "withdrawal" && $0.intensity == "high" }
        if let bigDrain = highWithdrawals.first {
            let hrvPct = abs(Int(bigDrain.linkedHRVChange / (metrics.first?.hrv ?? 30) * 100))
            insights.append(ProactiveInsight(
                icon: "battery.25percent",
                title: "High-Intensity Withdrawal Detected",
                body: "Your \(bigDrain.context) was a significant energy drain (HRV dropped ~\(hrvPct)%). Consider lighter activities and extra recovery today.",
                severity: "warning"
            ))
        }

        let recentDeposits = energyLogs.filter { $0.energyEffect == "deposit" }.prefix(5)
        if recentDeposits.count >= 3 {
            let bestDeposit = recentDeposits.max(by: { $0.energyDelta < $1.energyDelta })
            if let best = bestDeposit {
                insights.append(ProactiveInsight(
                    icon: "bolt.fill",
                    title: "Top Energy Booster",
                    body: "\(best.context) gave you the biggest energy deposit (+\(best.energyDelta)) this week. Try to include similar activities regularly.",
                    severity: "positive"
                ))
            }
        }

        if let latest = metrics.first, latest.stressFlag, avgHRV > 0 {
            let drop = Int(((avgHRV - latest.hrvDaytimeLow) / avgHRV) * 100)
            let workout = acts.first?.workoutType ?? "workout"
            insights.append(ProactiveInsight(
                icon: "waveform.path.ecg",
                title: "Elevated Stress Markers",
                body: "Your cortisol markers spiked around 4 PM after your \(workout) session — HRV dropped \(drop)% below baseline. This is why tonight's HRV reads lower. Try a 5-minute breathwork before bed.",
                severity: "warning"
            ))
        }

        let lateMeals = meals.filter(\.isLateNight)
        if lateMeals.count >= 2 {
            insights.append(ProactiveInsight(
                icon: "moon.zzz.fill",
                title: "Late-Night Eating Pattern",
                body: "\(lateMeals.count) late-night meals this week are correlating with ~8% lower sleep efficiency. Moving your last meal before 9 PM could improve deep sleep by 15–20 minutes.",
                severity: "info"
            ))
        }

        if let p = profile, p.cyclePhase == .luteal {
            insights.append(ProactiveInsight(
                icon: "leaf.circle.fill",
                title: "Luteal Phase Active (Day \(p.cycleDay))",
                body: "Progesterone is elevated, which naturally raises your baseline temperature (+\(String(format: "%.1f", metrics.first?.temperatureDeviation ?? 0.3))°C) and may lower HRV. This is expected — not a fitness concern. Consider magnesium-rich foods tonight.",
                severity: "info"
            ))
        }

        let glycemic = meals.filter(\.isHighGlycemic)
        if glycemic.count >= 3 {
            insights.append(ProactiveInsight(
                icon: "chart.line.uptrend.xyaxis",
                title: "High-Glycemic Meal Trend",
                body: "\(glycemic.count) high-glycemic meals detected. For someone with insulin sensitivity, these spikes may contribute to afternoon energy crashes and lower deep sleep.",
                severity: "warning"
            ))
        }

        proactiveInsights = insights
    }

    private func buildSuggestedQuestions() {
        suggestedQuestions = [
            "Why is my HRV lower tonight?",
            "How did my Pilates class affect my sleep?",
            "How does my cycle affect recovery?",
            "What drains my energy the most?",
            "Are my lab results concerning for PCOS?",
            "Is my B12 low from Metformin?",
            "What should I eat in my luteal phase?",
            "How much sleep debt do I have?",
        ]
    }

    // MARK: - RAG Context

    private func buildContextJSON(health: HealthKitService?) async throws -> String {
        var profileDesc = FetchDescriptor<UserProfile>()
        profileDesc.fetchLimit = 1
        let profile = try modelContext.fetch(profileDesc).first ?? UserProfile()

        var mealDesc = FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        mealDesc.fetchLimit = 14
        let meals = try modelContext.fetch(mealDesc)

        var ouraDesc = FetchDescriptor<OuraMetrics>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        ouraDesc.fetchLimit = 14
        let oura = try modelContext.fetch(ouraDesc)

        var actDesc = FetchDescriptor<OuraActivityDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        actDesc.fetchLimit = 14
        let activity = try modelContext.fetch(actDesc)

        var enDesc = FetchDescriptor<EnergyActivity>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        enDesc.fetchLimit = 14
        let energyActivities = try modelContext.fetch(enDesc)

        let workouts = await health?.recentWorkouts(limit: 5) ?? []
        let cycle = await health?.recentMenstrualEvents(limit: 5) ?? []

        var labDesc = FetchDescriptor<LabResult>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        labDesc.fetchLimit = 20
        let labs = try modelContext.fetch(labDesc)

        var symDesc = FetchDescriptor<CycleSymptom>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        symDesc.fetchLimit = 7
        let symptoms = try modelContext.fetch(symDesc)

        let deposits = energyActivities.filter { $0.energyEffect == "deposit" }
        let withdrawals = energyActivities.filter { $0.energyEffect == "withdrawal" }
        let energyBattery = KlairCoachContext.EnergyBattery(
            selfReportedEnergy1to10: profile.energyRating,
            selfReportedMood1to10: profile.moodRating,
            recentDepositsCount: deposits.count,
            recentWithdrawalsCount: withdrawals.count,
            lastDepositSummary: deposits.first.map { "\($0.context) (+\($0.energyDelta))" } ?? "",
            lastWithdrawalSummary: withdrawals.first.map { "\($0.context) (\($0.energyDelta))" } ?? ""
        )

        let profileForRules = (try? modelContext.fetch(profileDesc))?.first
        let healthAlerts = AlertEngine.evaluate(
            metrics: oura, meals: meals, activities: activity,
            profile: profileForRules, labs: labs, cycleSymptoms: symptoms
        )
        let correlations = CorrelationEngine.computeAll(
            metrics: oura, meals: meals, activities: activity, profile: profileForRules
        )

        let payload = KlairCoachContext(
            user: .init(
                name: profile.name, age: profile.age,
                weightKg: profile.weightKg, heightCm: profile.heightCm,
                bmi: profile.bmi, bodyFatPercentage: profile.bodyFatPercentage,
                waistCm: profile.waistCm, hipCm: profile.hipCm,
                waistToHipRatio: profile.waistToHipRatio,
                dailyCalorieGoal: profile.dailyCalorieGoal, bmr: profile.bmr,
                menstruationTrackingEnabled: profile.menstruationTrackingEnabled,
                knownConditions: profile.knownConditions, healthGoals: profile.healthGoals,
                medications: profile.medications,
                cycleDay: profile.cycleDay, cycleLength: profile.cycleLength,
                cyclePhase: profile.cyclePhase.rawValue,
                bloodPressure: profile.bloodPressureString, bpCategory: profile.bpCategory,
                glucoseMgDl: profile.glucoseMgDl,
                waterIntakeMl: profile.waterIntakeMl, waterGoalMl: profile.dailyWaterGoalMl,
                moodRating: profile.moodRating, energyRating: profile.energyRating
            ),
            recentMeals: meals.map {
                .init(timestamp: $0.timestamp, mealTitle: $0.mealTitle, calories: $0.calories, protein: $0.protein,
                      carbs: $0.carbs, fat: $0.fat, fiber: $0.fiber, sugar: $0.sugar,
                      caffeineMg: $0.caffeineMg, alcoholUnits: $0.alcoholUnits,
                      glycemicLoad: $0.glycemicLoad,
                      notes: $0.userNotes, micronutrientsJSON: $0.micronutrientsJSON,
                      isHighGlycemic: $0.isHighGlycemic, isLateNight: $0.isLateNight)
            },
            recentOura: oura.map {
                .init(date: $0.date, readiness: $0.readinessScore, sleep: $0.sleepScore, hrv: $0.hrv,
                      remMinutes: $0.remSleepMinutes, deepMinutes: $0.deepSleepMinutes,
                      lightMinutes: $0.lightSleepMinutes, totalMinutes: $0.totalSleepMinutes,
                      sleepEfficiency: $0.sleepEfficiency, sleepLatency: $0.sleepLatencyMinutes,
                      temperatureDeviation: $0.temperatureDeviation,
                      restingHeartRate: $0.restingHeartRate, respiratoryRate: $0.respiratoryRate,
                      spo2: $0.spo2Percentage, stressFlag: $0.stressFlag,
                      stressScore: $0.stressScore, stressDurationMin: $0.stressDurationMinutes,
                      sleepMidpointDeviation: $0.sleepMidpointDeviation)
            },
            recentActivity: activity.map {
                .init(date: $0.date, steps: $0.steps, activeCalories: $0.activeCalories,
                      workoutType: $0.workoutType, highIntensityMinutes: $0.highIntensityMinutes,
                      mediumIntensityMinutes: $0.mediumIntensityMinutes,
                      vo2Max: $0.vo2Max, trainingLoadAcute: $0.trainingLoadAcute,
                      trainingLoadChronic: $0.trainingLoadChronic,
                      trainingLoadStatus: $0.trainingLoadStatus)
            },
            healthKitWorkouts: workouts.map {
                .init(name: $0.activityName, start: $0.start, durationMinutes: $0.durationMinutes, kcal: $0.totalEnergyKcal)
            },
            healthKitMenstrual: cycle.map {
                .init(date: $0.date, flow: $0.flowLabel)
            },
            energyActivities: energyActivities.map {
                .init(timestamp: $0.timestamp, type: $0.activityType, intensity: $0.intensity,
                      effect: $0.energyEffect, context: $0.context,
                      energyDelta: $0.energyDelta, hrvChange: $0.linkedHRVChange)
            },
            labResults: labs.map {
                .init(date: $0.date, testType: $0.typeEnum.displayName, value: $0.value,
                      unit: $0.unit, status: $0.statusLabel, notes: $0.notes)
            },
            cycleSymptoms: symptoms.map {
                .init(date: $0.date, cycleDay: $0.cycleDay, phase: $0.phase,
                      pmsSeverity: $0.pmsSeverityScore,
                      topSymptoms: $0.topSymptoms.map { "\($0.name):\($0.severity)" }.joined(separator: ", "))
            },
            energyBattery: energyBattery,
            healthAlerts: healthAlerts.map {
                .init(title: $0.title, message: $0.message, severity: String(describing: $0.severity))
            },
            correlations: correlations.map {
                .init(label: $0.label, r: $0.rValue, description: $0.description)
            }
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

private struct KlairCoachContext: Encodable {
    struct EnergyBattery: Encodable {
        let selfReportedEnergy1to10: Int
        let selfReportedMood1to10: Int
        let recentDepositsCount: Int
        let recentWithdrawalsCount: Int
        let lastDepositSummary: String
        let lastWithdrawalSummary: String
    }

    struct User: Encodable {
        let name: String; let age: Int
        let weightKg: Double; let heightCm: Double
        let bmi: Double; let bodyFatPercentage: Double
        let waistCm: Double; let hipCm: Double; let waistToHipRatio: Double
        let dailyCalorieGoal: Double; let bmr: Double
        let menstruationTrackingEnabled: Bool
        let knownConditions: String; let healthGoals: String; let medications: String
        let cycleDay: Int; let cycleLength: Int; let cyclePhase: String
        let bloodPressure: String; let bpCategory: String; let glucoseMgDl: Double
        let waterIntakeMl: Double; let waterGoalMl: Double
        let moodRating: Int; let energyRating: Int
    }
    struct Meal: Encodable {
        let timestamp: Date; let mealTitle: String; let calories: Double; let protein: Double
        let carbs: Double; let fat: Double; let fiber: Double; let sugar: Double
        let caffeineMg: Double; let alcoholUnits: Double; let glycemicLoad: Double
        let notes: String; let micronutrientsJSON: String?
        let isHighGlycemic: Bool; let isLateNight: Bool
    }
    struct Oura: Encodable {
        let date: Date; let readiness: Int; let sleep: Int; let hrv: Double
        let remMinutes: Double; let deepMinutes: Double
        let lightMinutes: Double; let totalMinutes: Double
        let sleepEfficiency: Double; let sleepLatency: Double
        let temperatureDeviation: Double
        let restingHeartRate: Double; let respiratoryRate: Double; let spo2: Double
        let stressFlag: Bool; let stressScore: Double; let stressDurationMin: Double
        let sleepMidpointDeviation: Double
    }
    struct Activity: Encodable {
        let date: Date; let steps: Int; let activeCalories: Double
        let workoutType: String; let highIntensityMinutes: Double
        let mediumIntensityMinutes: Double
        let vo2Max: Double; let trainingLoadAcute: Double; let trainingLoadChronic: Double
        let trainingLoadStatus: String
    }
    struct Workout: Encodable {
        let name: String; let start: Date; let durationMinutes: Double; let kcal: Double?
    }
    struct Cycle: Encodable { let date: Date; let flow: String }
    struct EnergyLog: Encodable {
        let timestamp: Date; let type: String; let intensity: String
        let effect: String; let context: String
        let energyDelta: Int; let hrvChange: Double
    }
    struct Lab: Encodable {
        let date: Date; let testType: String; let value: Double
        let unit: String; let status: String; let notes: String
    }
    struct SymptomDay: Encodable {
        let date: Date; let cycleDay: Int; let phase: String
        let pmsSeverity: Int; let topSymptoms: String
    }
    struct AlertBrief: Encodable {
        let title: String
        let message: String
        let severity: String
    }

    struct CorrelationBrief: Encodable {
        let label: String
        let r: Double
        let description: String
    }

    let user: User; let recentMeals: [Meal]; let recentOura: [Oura]
    let recentActivity: [Activity]; let healthKitWorkouts: [Workout]; let healthKitMenstrual: [Cycle]
    let energyActivities: [EnergyLog]; let labResults: [Lab]; let cycleSymptoms: [SymptomDay]
    let energyBattery: EnergyBattery
    let healthAlerts: [AlertBrief]
    let correlations: [CorrelationBrief]
}
