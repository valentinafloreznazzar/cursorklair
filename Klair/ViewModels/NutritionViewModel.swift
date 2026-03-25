import Foundation
import SwiftData
import Observation
import UIKit

struct MealCorrelation: Identifiable, Sendable {
    var id: UUID
    let mealNote: String
    let flag: String
    let impact: String
}

@Observable
@MainActor
final class NutritionViewModel {
    private let modelContext: ModelContext
    private let gemini = GeminiService()

    var isAnalyzing = false
    var analysisError: String?
    var pendingImage: UIImage?
    var pendingUserText: String = ""
    /// AI result; user edits in review sheet before save.
    var pendingNourish: NourishMealEstimate?
    var showConfirmation = false

    var recentMeals: [MealEntry] = []
    var selectedMeal: MealEntry?

    var todayCalories: Double = 0
    var todayProtein: Double = 0
    var todayCarbs: Double = 0
    var todayFat: Double = 0
    var dailyCalorieGoal: Double = 2000

    var correlations: [MealCorrelation] = []

    // Chef's Pantry
    var pantryText: String = ""
    var chefRecipes: [RecipeCard] = []
    var isChefGenerating = false
    var chefError: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadRecentMeals() {
        var desc = FetchDescriptor<MealEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        desc.fetchLimit = 30
        recentMeals = (try? modelContext.fetch(desc)) ?? []

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayMeals = recentMeals.filter { cal.isDate($0.timestamp, inSameDayAs: today) }
        todayCalories = todayMeals.reduce(0) { $0 + $1.calories }
        todayProtein = todayMeals.reduce(0) { $0 + $1.protein }
        todayCarbs = todayMeals.reduce(0) { $0 + $1.carbs }
        todayFat = todayMeals.reduce(0) { $0 + $1.fat }

        var profileDesc = FetchDescriptor<UserProfile>()
        profileDesc.fetchLimit = 1
        if let p = try? modelContext.fetch(profileDesc).first {
            dailyCalorieGoal = p.dailyCalorieGoal
        }

        computeCorrelations()
    }

    private func computeCorrelations() {
        let cal = Calendar.current
        var metricsDesc = FetchDescriptor<OuraMetrics>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        metricsDesc.fetchLimit = 14
        let metrics = (try? modelContext.fetch(metricsDesc)) ?? []
        let avgSleep = metrics.isEmpty ? 0 : metrics.map { Double($0.sleepScore) }.reduce(0, +) / Double(metrics.count)

        var items: [MealCorrelation] = []
        let flagged = recentMeals.filter { $0.isHighGlycemic || $0.isLateNight }.prefix(5)

        for meal in flagged {
            let nextDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: meal.timestamp))!
            let nextSleep = metrics.first { cal.isDate($0.date, inSameDayAs: nextDay) }

            let flag = meal.isHighGlycemic && meal.isLateNight ? "High Glycemic + Late Night"
                     : meal.isHighGlycemic ? "High Glycemic"
                     : "Late Night"

            var impact = "No sleep data for correlation"
            if let s = nextSleep {
                let diff = Double(s.sleepScore) - avgSleep
                if diff < -5 {
                    impact = "Next-day sleep score dropped \(Int(abs(diff))) points below your average"
                } else {
                    impact = "No significant sleep impact detected"
                }
            }
            items.append(MealCorrelation(id: meal.id, mealNote: meal.userNotes, flag: flag, impact: impact))
        }
        correlations = items
    }

    func analyze(image: UIImage, notes: String) async {
        isAnalyzing = true
        analysisError = nil
        pendingImage = image
        pendingUserText = notes
        defer { isAnalyzing = false }
        do {
            let est = try await gemini.analyzeMeal(image: image, userText: notes)
            pendingNourish = est
            showConfirmation = true
        } catch {
            pendingNourish = HeuristicFallback.nourishMealFallback(userNotes: notes)
            showConfirmation = true
            analysisError = nil
        }
    }

    func savePendingToSwiftData() {
        guard let img = pendingImage, var est = pendingNourish else { return }
        let microJSON: String? = {
            guard let m = est.micronutrients, !m.isEmpty,
                  let data = try? JSONEncoder().encode(m),
                  let s = String(data: data, encoding: .utf8) else { return nil }
            return s
        }()
        let jpeg = img.jpegData(compressionQuality: 0.5)
        let hour = Calendar.current.component(.hour, from: Date())
        let notesBody = [est.notes, pendingUserText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        let entry = MealEntry(
            timestamp: Date(),
            imageData: jpeg,
            calories: est.calories,
            protein: est.protein,
            carbs: est.carbs,
            fat: est.fat,
            userNotes: notesBody.isEmpty ? est.mealName : notesBody,
            mealTitle: est.mealName,
            micronutrientsJSON: microJSON,
            isHighGlycemic: est.carbs > 60,
            isLateNight: hour >= 21
        )
        modelContext.insert(entry)
        try? modelContext.save()
        resetPending()
        loadRecentMeals()
    }

    func saveManualMeal(title: String, notes: String, calories: Double, protein: Double, carbs: Double, fat: Double) {
        let hour = Calendar.current.component(.hour, from: Date())
        let entry = MealEntry(
            timestamp: Date(),
            imageData: nil,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            userNotes: notes,
            mealTitle: title,
            micronutrientsJSON: nil,
            isHighGlycemic: carbs > 60,
            isLateNight: hour >= 21
        )
        modelContext.insert(entry)
        try? modelContext.save()
        loadRecentMeals()
    }

    func discardPending() { resetPending() }

    private func resetPending() {
        pendingImage = nil
        pendingNourish = nil
        pendingUserText = ""
        showConfirmation = false
    }

    // MARK: - Chef (API → Gemini → heuristic)

    func buildChefContextJSON() -> String {
        var profileDesc = FetchDescriptor<UserProfile>()
        profileDesc.fetchLimit = 1
        let profile = (try? modelContext.fetch(profileDesc).first)

        var metricsDesc = FetchDescriptor<OuraMetrics>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        metricsDesc.fetchLimit = 1
        let latest = (try? modelContext.fetch(metricsDesc).first)

        let obj: [String: Any] = [
            "name": profile?.name ?? "Marta",
            "knownConditions": profile?.knownConditions ?? "",
            "healthGoals": profile?.healthGoals ?? "",
            "medications": profile?.medications ?? "",
            "cyclePhase": profile?.cyclePhase.rawValue ?? "",
            "readiness": latest?.readinessScore ?? 0,
            "sleepScore": latest?.sleepScore ?? 0,
            "hrv": latest?.hrv ?? 0,
            "anemiaFocus": (profile?.knownConditions.lowercased().contains("anemia") ?? false)
                || (profile?.knownConditions.lowercased().contains("iron") ?? false),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    func generateChefRecipes() async {
        let pantry = pantryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pantry.isEmpty else {
            chefError = "Add what you have in the pantry first."
            return
        }
        isChefGenerating = true
        chefError = nil
        defer { isChefGenerating = false }

        let context = buildChefContextJSON()
        let recipes = await ChefRecipesService.fetchRecipes(pantryText: pantry, contextJSON: context)
        if recipes.isEmpty {
            chefError = "Couldn’t build recipes — try adding a few more ingredients."
        } else {
            chefRecipes = recipes
        }
    }
}
