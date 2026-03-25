import SwiftUI
import SwiftData
import Charts
import UIKit

struct NutritionView: View {
    @Query(sort: \MealEntry.timestamp, order: .reverse) private var meals: [MealEntry]
    @Query private var profiles: [UserProfile]
    @Query(sort: \OuraMetrics.date, order: .reverse) private var metrics: [OuraMetrics]
    @Environment(\.modelContext) private var modelContext

    @State private var fuelSegment = 0
    @State private var nutritionVM: NutritionViewModel?
    @State private var captureForAnalyze: UIImage?
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var showManualMeal = false

    private var profile: UserProfile? { profiles.first }
    private var todayMeals: [MealEntry] {
        let cal = Calendar.current; let start = cal.startOfDay(for: Date())
        return meals.filter { cal.isDate($0.timestamp, inSameDayAs: start) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                fuelSegmentPicker
                if fuelSegment == 1 {
                    chefPantrySection
                }
                if fuelSegment == 0 {
                addMealSection
                macroRingCard
                netCarbsProteinCard
                caffeineAlcoholCard
                foodJournal
                fastingWindowCard
                supplementsSection
                micronutrientBars
                pcosNutrientBars
                recoveryInsightsSection
                nutritionCorrelationChart
                suggestedRecipesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .background(KlairTheme.background.ignoresSafeArea())
        .onAppear {
            if nutritionVM == nil {
                nutritionVM = NutritionViewModel(modelContext: modelContext)
            }
            nutritionVM?.loadRecentMeals()
        }
        .onChange(of: captureForAnalyze) { _, new in
            guard let img = new, let vm = nutritionVM else { return }
            Task {
                await vm.analyze(image: img, notes: "")
                await MainActor.run { captureForAnalyze = nil }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(image: $captureForAnalyze, sourceType: .camera)
        }
        .sheet(isPresented: $showLibraryPicker) {
            ImagePicker(image: $captureForAnalyze, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $showManualMeal) {
            ManualMealEntrySheet(modelContext: modelContext, isPresented: $showManualMeal) {
                nutritionVM?.loadRecentMeals()
            }
        }
        .sheet(isPresented: Binding(
            get: { nutritionVM?.showConfirmation ?? false },
            set: { new in if !new { nutritionVM?.discardPending() } }
        )) {
            if let vm = nutritionVM {
                MealReviewSheet(viewModel: vm)
            }
        }
    }

    // MARK: - Fuel segment (Nourish vs Chef)

    private var fuelSegmentPicker: some View {
        HStack(spacing: 0) {
            segmentChip(0, "Nourish")
            segmentChip(1, "Chef")
        }
        .padding(4)
        .background(KlairTheme.surfaceHigh.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .cloudShadow(radius: 8, y: 3)
    }

    private func segmentChip(_ idx: Int, _ title: String) -> some View {
        Button {
            SensoryManager.shared.lightTap()
            fuelSegment = idx
        } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(fuelSegment == idx ? KlairTheme.cyan : KlairTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fuelSegment == idx ? KlairTheme.cyan.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chef's Pantry

    @ViewBuilder
    private var chefPantrySection: some View {
        let vm = nutritionVM
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "refrigerator.fill").font(.system(size: 12)).foregroundStyle(KlairTheme.cyan)
                Text("CHEF'S PANTRY").font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary)
            }
            Text("What do you have on hand? Klair will suggest meals for your readiness and health goals.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous)
                    .fill(KlairTheme.card)
                    .cloudShadow(radius: 12, y: 4)
                TextEditor(text: Binding(
                    get: { vm?.pantryText ?? "" },
                    set: { nutritionVM?.pantryText = $0 }
                ))
                .frame(minHeight: 120)
                .padding(12)
                .scrollContentBackground(.hidden)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(KlairTheme.textPrimary)
            }
            .frame(minHeight: 132)

            if vm?.isChefGenerating == true {
                HStack(spacing: 8) {
                    ProgressView().tint(KlairTheme.cyan)
                    Text("Generating recipes…").font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary)
                }
            }

            if let err = vm?.chefError, !err.isEmpty {
                Text(err).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.coral)
            }

            Button {
                SensoryManager.shared.success()
                Task { await nutritionVM?.generateChefRecipes() }
            } label: {
                Text("Generate Recipes")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KlairTheme.softSlate)
                    .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                    .cloudShadow(radius: 14, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(vm?.isChefGenerating == true || vm == nil)

            if let recipes = vm?.chefRecipes, !recipes.isEmpty {
                Text("FOR YOU TODAY").font(.system(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(KlairTheme.textTertiary).padding(.top, 8)
                VStack(spacing: 14) {
                    ForEach(recipes) { recipe in
                        chefRecipeCard(recipe)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func chefRecipeCard(_ recipe: RecipeCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                WellnessImage(keywords: recipe.imageKeyword, height: 120, cornerRadius: 14)
                Text("\(Int(recipe.calories)) kcal · \(recipe.macroSummary)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }
            Text(recipe.title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(KlairTheme.textPrimary)
            Text("Why this helps")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(KlairTheme.cyan)
            Text(recipe.why)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlairTheme.textSecondary)
                .lineSpacing(4)
        }
        .padding(14)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .cloudShadow(radius: 16, y: 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Fuel & Nourish")
                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                Spacer()
                KlairLogo(size: 28, color: KlairTheme.cyan.opacity(0.5))
            }
            Text("Log meals at the top · switch to Chef for pantry recipes · scroll for macros & charts")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(KlairTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    // MARK: - Macro Ring

    @ViewBuilder
    private var macroRingCard: some View {
        let totalCal = todayMeals.map(\.calories).reduce(0, +)
        let p = todayMeals.map(\.protein).reduce(0, +), c = todayMeals.map(\.carbs).reduce(0, +), f = todayMeals.map(\.fat).reduce(0, +)
        GlassCard {
            HStack(spacing: 20) {
                MacroRing(protein: p, carbs: c, fat: f, size: 90)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(totalCal)) / \(Int(profile?.dailyCalorieGoal ?? 2000)) kcal")
                        .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                    HStack(spacing: 10) { macroLabel("P", p, KlairTheme.amethyst); macroLabel("C", c, KlairTheme.emerald); macroLabel("F", f, KlairTheme.orange) }
                    HStack(spacing: 10) {
                        macroLabel("Fiber", todayMeals.map(\.fiber).reduce(0, +), KlairTheme.cyan)
                        macroLabel("Sugar", todayMeals.map(\.sugar).reduce(0, +), KlairTheme.coral)
                    }
                }
            }
        }
    }

    private func macroLabel(_ label: String, _ val: Double, _ color: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 6, height: 6); Text("\(label) \(Int(val))g").font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textSecondary) }
    }

    // MARK: - Net Carbs & Per-Meal Protein

    @ViewBuilder
    private var netCarbsProteinCard: some View {
        let totalCarbs = todayMeals.map(\.carbs).reduce(0, +)
        let totalFiber = todayMeals.map(\.fiber).reduce(0, +)
        let netCarbs = max(0, totalCarbs - totalFiber)
        let mealsWithLowProtein = todayMeals.filter { $0.protein < 25 && $0.calories > 100 }

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(netCarbs))g").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("NET CARBS").font(.system(size: 9, weight: .bold)).kerning(0.8).foregroundStyle(KlairTheme.textTertiary)
                        Text("Carbs \(Int(totalCarbs))g − Fiber \(Int(totalFiber))g")
                            .font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                    }
                    Divider().frame(height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: mealsWithLowProtein.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 12)).foregroundStyle(mealsWithLowProtein.isEmpty ? KlairTheme.emerald : KlairTheme.orange)
                            Text("PROTEIN DISTRIBUTION").font(.system(size: 9, weight: .bold)).kerning(0.6).foregroundStyle(KlairTheme.textTertiary)
                        }
                        if mealsWithLowProtein.isEmpty {
                            Text("All meals have 25g+ protein — good for insulin sensitivity")
                                .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.emerald)
                        } else {
                            Text("\(mealsWithLowProtein.count) meal(s) under 25g protein. Aim for 25–40g per meal to stabilize glucose.")
                                .font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.orange)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Caffeine & Alcohol

    @ViewBuilder
    private var caffeineAlcoholCard: some View {
        let totalCaffeine = todayMeals.map(\.caffeineMg).reduce(0, +)
        let totalAlcohol = todayMeals.map(\.alcoholUnits).reduce(0, +)
        if totalCaffeine > 0 || totalAlcohol > 0 {
            GlassCard {
                HStack(spacing: 20) {
                    if totalCaffeine > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill").font(.system(size: 16)).foregroundStyle(KlairTheme.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Int(totalCaffeine))mg").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                                Text("Caffeine").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                                if totalCaffeine > 200 {
                                    Text("Above 200mg may impact sleep").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.coral)
                                }
                            }
                        }
                    }
                    if totalAlcohol > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "wineglass.fill").font(.system(size: 16)).foregroundStyle(KlairTheme.amethyst)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "%.1f", totalAlcohol)).font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                                Text("Alcohol units").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
                                Text("May reduce REM by ~25%").font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.coral)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Food Journal

    @ViewBuilder
    private var foodJournal: some View {
        VStack(alignment: .leading, spacing: 10) {
            meta("FOOD JOURNAL")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(todayMeals.prefix(6).enumerated()), id: \.offset) { idx, meal in
                        photoMealCard(meal, idx)
                    }
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
        }
    }

    private func photoMealCard(_ meal: MealEntry, _ idx: Int) -> some View {
        let keyword = meal.userNotes.split(separator: " ").prefix(3).joined(separator: ",")
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                if let data = meal.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 130, height: 90).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    WellnessImage(keywords: "food,\(keyword)", height: 90, cornerRadius: 14)
                        .frame(width: 130)
                }
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .bottom, endPoint: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if meal.isLateNight {
                    VStack { HStack { Spacer()
                        Image(systemName: "moon.fill").font(.system(size: 10)).foregroundStyle(KlairTheme.coral)
                            .padding(4).background(.ultraThinMaterial).clipShape(Circle())
                    }; Spacer() }.padding(6)
                }
                Text(meal.timeString).font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .padding(6)
            }
            Text(displayMealTitle(meal))
                .font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary).lineLimit(1)
            Text(meal.macroSummary).font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.textTertiary)
            if meal.hasCaffeine {
                HStack(spacing: 3) {
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 7)).foregroundStyle(KlairTheme.orange)
                    Text("Caffeine").font(.system(size: 8, weight: .medium)).foregroundStyle(KlairTheme.orange)
                }
            }
        }
        .frame(width: 150).padding(10)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .cloudShadow(radius: 12, y: 4).tapScale()
        .carouselEffect()
    }

    // MARK: - Fasting Window

    @ViewBuilder
    private var fastingWindowCard: some View {
        let sortedToday = todayMeals.sorted(by: { $0.timestamp < $1.timestamp })
        if let first = sortedToday.first, let last = sortedToday.last, sortedToday.count > 1 {
            let eatingWindow = last.timestamp.timeIntervalSince(first.timestamp) / 3600
            let fastingWindow = 24 - eatingWindow
            GlassCard {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(KlairTheme.surfaceHigh.opacity(0.5), lineWidth: 5).frame(width: 50, height: 50)
                        Circle().trim(from: 0, to: min(1, fastingWindow / 24))
                            .stroke(KlairTheme.emerald, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90)).frame(width: 50, height: 50)
                        Text("\(Int(fastingWindow))h").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FASTING WINDOW").font(.system(size: 10, weight: .bold)).kerning(1).foregroundStyle(KlairTheme.textTertiary)
                        Text("Eating: \(first.timeString) – \(last.timeString)")
                            .font(.system(.caption, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textPrimary)
                        if eatingWindow > 10 {
                            Text("Narrowing your window to 8–10h may improve insulin sensitivity")
                                .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.orange).lineSpacing(2)
                        } else {
                            Text("Good fasting window for metabolic health")
                                .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.emerald)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Supplements & Hydration

    @ViewBuilder
    private var supplementsSection: some View {
        let meds = profile?.medicationsList ?? []; let waterProgress = profile?.waterProgress ?? 0
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                meta("SUPPLEMENTS & HYDRATION")
                if !meds.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(meds, id: \.self) { med in
                                Text(med).font(.system(.caption2, design: .rounded).weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
                                    .foregroundStyle(KlairTheme.amethyst)
                                    .background(KlairTheme.amethyst.opacity(0.08)).clipShape(Capsule())
                            }
                        }
                    }
                }
                HStack(spacing: 14) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(KlairTheme.cyan.opacity(0.06)).frame(width: 60, height: 50)
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(KlairTheme.cyanGradient).frame(width: 60, height: max(4, 50 * waterProgress))
                    }.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(profile?.waterIntakeMl ?? 0)) / \(Int(profile?.dailyWaterGoalMl ?? 2500)) ml")
                            .font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary)
                        Text("Hydration status").font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
                        if waterProgress < 0.5 {
                            Text("Below target — dehydration may lower HRV by ~5%").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.coral)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Micronutrient Bars

    @ViewBuilder
    private var micronutrientBars: some View {
        let allMicros = todayMeals.flatMap { $0.micronutrients }
        let combined: [String: Double] = Dictionary(allMicros, uniquingKeysWith: +)
        let targets: [String: Double] = ["iron_mg": 18, "magnesium_mg": 320, "vitamin_c_mg": 75, "calcium_mg": 1000, "potassium_mg": 2600]
        let colors: [Color] = [KlairTheme.coral, KlairTheme.emerald, KlairTheme.orange, KlairTheme.cyan, KlairTheme.amethyst]

        if !combined.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    meta("MICRONUTRIENTS")
                    ForEach(Array(targets.keys.sorted().enumerated()), id: \.element) { idx, key in
                        let val = combined[key] ?? 0; let target = targets[key] ?? 1
                        microBar(label: key.replacingOccurrences(of: "_", with: " ").capitalized, value: val, target: target, color: colors[idx % colors.count])
                    }
                }
            }
        }
    }

    private func microBar(label: String, value: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textSecondary)
                Spacer()
                Text(String(format: "%.0f / %.0f", value, target)).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.6)).frame(width: geo.size.width * min(1, value / target))
                }
            }.frame(height: 6)
        }
    }

    // MARK: - PCOS-Critical Nutrients

    @ViewBuilder
    private var pcosNutrientBars: some View {
        let allMicros = todayMeals.flatMap { $0.micronutrients }
        let combined: [String: Double] = Dictionary(allMicros, uniquingKeysWith: +)
        let pcosTargets: [(key: String, label: String, target: Double, unit: String, color: Color, warning: String)] = [
            ("zinc_mg", "Zinc", 8, "mg", KlairTheme.cyan, "Zinc reduces androgens — critical for PCOS"),
            ("vitamin_b12_mcg", "Vitamin B12", 2.4, "µg", KlairTheme.amethyst, "Metformin depletes B12 — monitor closely"),
            ("vitamin_d_iu", "Vitamin D", 600, "IU", KlairTheme.orange, "67–85% of PCOS women are D-deficient"),
            ("chromium_mcg", "Chromium", 25, "µg", KlairTheme.emerald, "Improves insulin receptor sensitivity"),
            ("omega3_mg", "Omega-3", 1000, "mg", KlairTheme.indigo, "Anti-inflammatory — reduces PCOS symptoms"),
        ]

        if !combined.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "staroflife.fill").font(.system(size: 11)).foregroundStyle(KlairTheme.coral)
                        meta("PCOS-CRITICAL NUTRIENTS")
                    }
                    ForEach(pcosTargets, id: \.key) { nutrient in
                        let val = combined[nutrient.key] ?? 0
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(nutrient.label).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f / %.0f %@", val, nutrient.target, nutrient.unit))
                                    .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(KlairTheme.textTertiary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(nutrient.color.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 4).fill(nutrient.color.opacity(0.6))
                                        .frame(width: geo.size.width * min(1, val / nutrient.target))
                                }
                            }.frame(height: 6)
                            if val < nutrient.target * 0.5 {
                                Text(nutrient.warning)
                                    .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(nutrient.color).lineSpacing(2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recovery Insights (Nutrition × Recovery)

    private var hasLateMeals: Bool { todayMeals.contains(where: \.isLateNight) }
    private var hasHighGI: Bool { todayMeals.contains(where: \.isHighGlycemic) }
    private var ironIntake: Double {
        var total: Double = 0
        for meal in todayMeals {
            total += meal.micronutrients["iron_mg"] ?? 0
        }
        return total
    }

    @ViewBuilder
    private var recoveryInsightsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 12)).foregroundStyle(KlairTheme.cyan)
                    meta("NUTRITION × RECOVERY")
                }
                if hasLateMeals {
                    impactRow(icon: "moon.fill", text: "Late meals after 9 PM correlated with ~12% lower deep sleep in last 3 nights.", positive: false)
                }
                if hasHighGI {
                    impactRow(icon: "chart.line.uptrend.xyaxis", text: "High glycemic meals spiked blood sugar, reducing next-day readiness by ~8 points.", positive: false)
                }
                if ironIntake < 10 {
                    impactRow(icon: "drop.fill", text: "Iron intake below 10mg today. With anemia, aim for 18mg+ daily for optimal oxygen delivery.", positive: false)
                }
                if !hasLateMeals && !hasHighGI {
                    impactRow(icon: "checkmark.seal.fill", text: "Great nutrition timing today — supporting optimal recovery.", positive: true)
                }
            }
        }
    }

    private func impactRow(icon: String, text: String, positive: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(positive ? KlairTheme.emerald : KlairTheme.coral)
            Text(text).font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary).lineSpacing(3)
        }
    }

    // MARK: - Nutrition × HRV Correlation Chart

    private struct CorrelationPoint: Identifiable {
        let id: Int; let day: String; let hrv: Double; let glycemicLoad: Double
    }

    private var correlationData: [CorrelationPoint] {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        let week = Array(metrics.prefix(7)).reversed()
        return Array(week.enumerated()).map { idx, m in
            let dayMeals = meals.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: m.date) }
            let gl = dayMeals.map(\.glycemicLoad).reduce(0, +)
            return CorrelationPoint(id: idx, day: fmt.string(from: m.date), hrv: m.hrv, glycemicLoad: gl)
        }
    }

    @ViewBuilder
    private var nutritionCorrelationChart: some View {
        let data = correlationData
        if data.count >= 3 {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    meta("GLYCEMIC LOAD × HRV")
                    Chart(data) { pt in
                        LineMark(x: .value("Day", pt.day), y: .value("HRV", pt.hrv))
                            .foregroundStyle(KlairTheme.cyan).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.catmullRom)
                        BarMark(x: .value("Day", pt.day), y: .value("GL", min(40, pt.glycemicLoad / 2)))
                            .foregroundStyle(KlairTheme.orange.opacity(0.25)).cornerRadius(3)
                    }
                    .chartYScale(domain: 0...50)
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)).foregroundStyle(KlairTheme.textTertiary) } }
                    .chartYAxis(.hidden).frame(height: 120)
                    HStack(spacing: 12) { legendDot(KlairTheme.cyan, "HRV"); legendDot(KlairTheme.orange, "Glycemic Load") }
                }
            }
        }
    }

    private func legendDot(_ c: Color, _ l: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 5, height: 5); Text(l).font(.system(size: 10, weight: .medium)).foregroundStyle(KlairTheme.textTertiary) }
    }

    // MARK: - Suggested Recipes

    @ViewBuilder
    private var suggestedRecipesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(KlairTheme.amethyst)
                meta("AI RECIPES FOR MARTA")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    recipeCard(name: "Iron-Rich Lentil Bowl", kcal: 480, reason: "Targets anemia + iron gap", imageKeywords: "lentil,bowl,salad")
                    recipeCard(name: "Anti-Inflammatory Salmon", kcal: 520, reason: "Supports PCOS management", imageKeywords: "salmon,grilled,vegetables")
                    recipeCard(name: "Magnesium Smoothie", kcal: 220, reason: "Luteal phase cramp relief", imageKeywords: "smoothie,green,healthy")
                    recipeCard(name: "Low-GI Power Bowl", kcal: 450, reason: "Insulin sensitivity support", imageKeywords: "grain,bowl,avocado")
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
        }
    }

    private func recipeCard(name: String, kcal: Int, reason: String, imageKeywords: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                WellnessImage(keywords: imageKeywords, height: 100, cornerRadius: 14)
                    .frame(width: 160)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(kcal) kcal")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.ultraThinMaterial).clipShape(Capsule())
                }
                .padding(8)
            }
            Text(name).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(KlairTheme.textPrimary).lineLimit(2)
            Text(reason).font(.system(size: 9, weight: .medium)).foregroundStyle(KlairTheme.emerald).lineLimit(2)
        }
        .frame(width: 160).padding(10)
        .background(KlairTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: KlairTheme.cornerRadius, style: .continuous))
        .cloudShadow(radius: 12, y: 4).tapScale()
        .carouselEffect()
    }

    // MARK: - Add Meal

    @ViewBuilder
    private var addMealSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            meta("LOG FOOD")
            HStack(spacing: 12) {
                addBtn(icon: "camera.fill", label: "Scan Meal", accent: KlairTheme.cyan) {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
                    showCameraPicker = true
                }
                addBtn(icon: "photo.on.rectangle", label: "From Photos", accent: KlairTheme.cyan) {
                    showLibraryPicker = true
                }
                addBtn(icon: "pencil.line", label: "Manual", accent: KlairTheme.softSlate) {
                    showManualMeal = true
                }
            }
            if nutritionVM?.isAnalyzing == true {
                HStack(spacing: 8) {
                    ProgressView().tint(KlairTheme.cyan)
                    Text("Analyzing meal…").font(.system(.caption, design: .rounded)).foregroundStyle(KlairTheme.textSecondary)
                }
            }
            if let err = nutritionVM?.analysisError, !err.isEmpty, nutritionVM?.pendingNourish != nil {
                Text(err).font(.system(.caption2, design: .rounded)).foregroundStyle(KlairTheme.coral)
            }
        }
    }

    private func addBtn(icon: String, label: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button {
            SensoryManager.shared.success()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(accent)
                Text(label).font(.system(.caption2, design: .rounded).weight(.medium)).foregroundStyle(KlairTheme.textSecondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(KlairTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
            .cloudShadow(radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func displayMealTitle(_ meal: MealEntry) -> String {
        let raw = meal.mealTitle.isEmpty ? meal.userNotes : meal.mealTitle
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count <= 22 { return s }
        return String(s.prefix(22)) + "…"
    }

    private func meta(_ t: String) -> some View { Text(t).font(.system(size: 11, weight: .semibold)).kerning(1.5).foregroundStyle(KlairTheme.textTertiary) }
}

// MARK: - Review sheet (Nourish)

struct MealReviewSheet: View {
    @Bindable var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NourishMealEstimate = .init(mealName: "", calories: 0, protein: 0, carbs: 0, fat: 0, ingredients: [])
    @State private var ingredientsLine = ""
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case name, cal, p, c, f, notes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Review meal")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(KlairTheme.textPrimary)
                    Text("Confirm or edit what we detected before saving to your journal.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlairTheme.textSecondary)
                        .lineSpacing(3)

                    fieldLabel("Meal name")
                    TextField("e.g. Mediterranean bowl", text: Binding(
                        get: { draft.mealName },
                        set: { var d = draft; d.mealName = $0; draft = d }
                    ))
                        .focused($focusedField, equals: .name)
                        .padding(14)
                        .background(KlairTheme.surfaceHigh.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack(spacing: 10) {
                        macroField("Cal", text: bindingString(\.calories), field: .cal)
                        macroField("Protein", text: bindingString(\.protein), field: .p)
                    }
                    HStack(spacing: 10) {
                        macroField("Carbs", text: bindingString(\.carbs), field: .c)
                        macroField("Fat", text: bindingString(\.fat), field: .f)
                    }

                    fieldLabel("Ingredients (comma-separated)")
                    TextField("tomato, feta, chickpeas…", text: $ingredientsLine)
                        .padding(14)
                        .background(KlairTheme.surfaceHigh.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    fieldLabel("Notes (optional)")
                    TextField("How it tasted, cooking method…", text: Binding(
                        get: { draft.notes ?? "" },
                        set: { draft.notes = $0.isEmpty ? nil : $0 }
                    ))
                    .focused($focusedField, equals: .notes)
                    .padding(14)
                    .background(KlairTheme.surfaceHigh.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(20)
            }
            .background(KlairTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        viewModel.discardPending()
                        dismiss()
                    }
                    .foregroundStyle(KlairTheme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        syncIngredientsFromLine()
                        viewModel.pendingNourish = draft
                        viewModel.savePendingToSwiftData()
                        dismiss()
                    } label: {
                        Text("Save to journal")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(KlairTheme.softSlate)
                            .clipShape(RoundedRectangle(cornerRadius: KlairTheme.smallCornerRadius, style: .continuous))
                            .cloudShadow(radius: 14, y: 5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(KlairTheme.background)
            }
            .onAppear {
                if let p = viewModel.pendingNourish {
                    draft = p
                    ingredientsLine = p.ingredients.joined(separator: ", ")
                }
            }
        }
    }

    private func fieldLabel(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(KlairTheme.cyan)
    }

    private func macroField(_ title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(title)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .padding(14)
                .background(KlairTheme.surfaceHigh.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private func bindingString(_ keyPath: WritableKeyPath<NourishMealEstimate, Double>) -> Binding<String> {
        Binding(
            get: {
                let v = draft[keyPath: keyPath]
                return v == floor(v) ? String(format: "%.0f", v) : String(format: "%.1f", v)
            },
            set: { newStr in
                let cleaned = newStr.replacingOccurrences(of: ",", with: ".")
                var d = draft
                d[keyPath: keyPath] = Double(cleaned) ?? 0
                draft = d
            }
        )
    }

    private func syncIngredientsFromLine() {
        draft.ingredients = ingredientsLine
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Manual meal entry

struct ManualMealEntrySheet: View {
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mealTitle = ""
    @State private var notes = ""
    @State private var calories = "500"
    @State private var protein = "30"
    @State private var carbs = "45"
    @State private var fat = "18"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    manualField("Meal name", text: $mealTitle, prompt: "e.g. Overnight oats")
                    manualField("Notes", text: $notes, prompt: "Optional", axis: .vertical)
                    manualField("Calories", text: $calories, prompt: "kcal", pad: true)
                    manualField("Protein (g)", text: $protein, prompt: "g", pad: true)
                    manualField("Carbs (g)", text: $carbs, prompt: "g", pad: true)
                    manualField("Fat (g)", text: $fat, prompt: "g", pad: true)
                }
                .padding(20)
            }
            .background(KlairTheme.background)
            .navigationTitle("Manual entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false; dismiss() }
                        .foregroundStyle(KlairTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(KlairTheme.cyan)
                }
            }
        }
    }

    private func manualField(_ title: String, text: Binding<String>, prompt: String, axis: Axis = .horizontal, pad: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(KlairTheme.cyan)
            if axis == .vertical {
                TextField(prompt, text: text, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(KlairTheme.surfaceHigh.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                TextField(prompt, text: text)
                    .keyboardType(pad ? .decimalPad : .default)
                    .padding(14)
                    .background(KlairTheme.surfaceHigh.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func save() {
        let c = Double(calories.replacingOccurrences(of: ",", with: ".")) ?? 0
        let p = Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let cb = Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0
        let f = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let hour = Calendar.current.component(.hour, from: Date())
        let title = mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Manual meal" : mealTitle
        let entry = MealEntry(
            timestamp: Date(),
            calories: c,
            protein: p,
            carbs: cb,
            fat: f,
            userNotes: notes,
            mealTitle: title,
            isHighGlycemic: cb > 60,
            isLateNight: hour >= 21
        )
        modelContext.insert(entry)
        try? modelContext.save()
        onSaved()
        isPresented = false
        dismiss()
    }
}
