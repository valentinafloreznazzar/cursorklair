import Foundation
import SwiftData

// MARK: - Real Oura Ring Data + Causally Consistent Synthetic Complement
//
// Sleep scores, durations, and latency are REAL values from Marta's Oura Ring
// (exported Oct 10–23, 2025). All other metrics (HRV, readiness, activity,
// nutrition) are synthetically generated with physiological consistency:
//   • Late meal on Day 7 → deep-sleep crash on Day 6 (score 65)
//   • Clean eating Days 3–2 → peak sleep scores (93)
//   • Luteal-phase temp elevation (+0.2–0.4 °C) from Day 2 onward
//   • HIIT on Day 7 + late meal → next-day readiness collapse

enum MockData {

    static func bootstrapIfNeeded(context: ModelContext) {
        var check = FetchDescriptor<OuraMetrics>(); check.fetchLimit = 1
        if (try? context.fetch(check).isEmpty) == false { return }
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        seedOuraMetrics(context: context, cal: cal, today: today)
        seedActivity(context: context, cal: cal, today: today)
        seedMeals(context: context, cal: cal, today: today)
        seedEnergyActivities(context: context, cal: cal, today: today)
        seedProfile(context: context)
        seedLabResults(context: context, cal: cal, today: today)
        seedCycleSymptoms(context: context, cal: cal, today: today)
        try? context.save()
    }

    // MARK: - Real Oura Sleep + Derived Metrics (14 days)

    private static func seedOuraMetrics(context: ModelContext, cal: Calendar, today: Date) {

        // (offset, sleepScore, totalMin, deepMin, remMin, lightMin, latencyMin)
        // Sleep data from Marta's actual Oura Ring export
        let realSleep: [(off: Int, ss: Int, tot: Double, deep: Double, rem: Double, light: Double, lat: Double)] = [
            (0,  80, 450, 96,  86,  267, 40),
            (1,  88, 503, 104, 98,  301, 23),
            (2,  93, 507, 115, 123, 268, 12),
            (3,  93, 514, 96,  110, 307, 17),
            (4,  78, 420, 65,  95,  260, 25),
            (5,  80, 428, 90,  119, 218, 18),
            (6,  65, 381, 39,  83,  258, 9),     // bad night (post HIIT + late meal)
            (7,  85, 454, 67,  107, 279, 15),
            (8,  87, 468, 110, 98,  260, 28),
            (9,  82, 474, 79,  107, 287, 20),
            (10, 91, 481, 89,  116, 276, 18),
            (11, 80, 386, 66,  74,  245, 16),
            (12, 76, 333, 85,  66,  182, 17),    // short sleep
            (13, 76, 365, 92,  90,  183, 18),
        ]

        // Derived: (readiness, hrv, rhr, tempDev, efficiency, hrvLow, stressFlag, respRate, spo2, stressScore, stressDur, midpointDev)
        let derived: [(rd: Int, hrv: Double, rhr: Double, td: Double, eff: Double, hrvL: Double, sf: Bool, rr: Double, sp: Double, sts: Double, stD: Double, mpd: Double)] = [
            (76, 34, 57, 0.32, 86, 18, false, 15.2, 97, 42, 25, 0.1),
            (83, 40, 54, 0.28, 91, 22, false, 15.0, 98, 28, 12, -0.1),
            (90, 47, 52, 0.24, 95, 28, false, 14.8, 98, 15, 5,  0.0),
            (88, 45, 53, 0.18, 94, 26, false, 14.9, 97, 18, 8,  0.05),
            (71, 31, 59, 0.10, 85, 17, false, 15.4, 97, 48, 30, 0.2),
            (73, 33, 58, 0.05, 87, 19, false, 15.3, 97, 38, 22, 0.15),
            (58, 24, 62, -0.02, 78, 12, true,  15.8, 96, 78, 55, 0.4),
            (80, 38, 55, -0.05, 89, 21, false, 15.1, 98, 35, 18, -0.1),
            (82, 39, 55, -0.08, 88, 23, false, 14.9, 98, 30, 14, -0.15),
            (78, 36, 56, -0.10, 87, 20, false, 15.0, 97, 32, 16, 0.0),
            (85, 42, 54, -0.12, 90, 24, false, 14.8, 98, 22, 10, -0.05),
            (74, 34, 57, -0.15, 84, 18, false, 15.2, 97, 40, 24, 0.1),
            (68, 29, 60, -0.18, 81, 15, true,  15.5, 96, 55, 35, 0.25),
            (72, 32, 58, -0.20, 83, 17, false, 15.3, 97, 45, 28, 0.2),
        ]

        let readinessContribSets: [[String: String]] = [
            ["previous_night_activity": "optimal", "sleep_balance": "good", "body_temperature": "normal", "hrv_balance": "restored", "recovery_index": "good", "resting_heart_rate": "optimal"],
            ["previous_night_activity": "high", "sleep_balance": "fair", "body_temperature": "elevated", "hrv_balance": "strained", "recovery_index": "fair", "resting_heart_rate": "elevated"],
            ["previous_night_activity": "optimal", "sleep_balance": "good", "body_temperature": "normal", "hrv_balance": "good", "recovery_index": "optimal", "resting_heart_rate": "good"],
            ["previous_night_activity": "low", "sleep_balance": "optimal", "body_temperature": "normal", "hrv_balance": "restored", "recovery_index": "good", "resting_heart_rate": "optimal"],
            ["previous_night_activity": "moderate", "sleep_balance": "fair", "body_temperature": "slightly_elevated", "hrv_balance": "fair", "recovery_index": "fair", "resting_heart_rate": "normal"],
        ]

        for (i, s) in realSleep.enumerated() {
            guard let day = cal.date(byAdding: .day, value: -s.off, to: today) else { continue }
            let d = derived[i]
            let contribJSON: String? = {
                let dict = readinessContribSets[i % readinessContribSets.count]
                guard let data = try? JSONEncoder().encode(dict), let str = String(data: data, encoding: .utf8) else { return nil }
                return str
            }()
            context.insert(OuraMetrics(
                readinessScore: d.rd, sleepScore: s.ss, hrv: d.hrv, date: day,
                readinessContributorsJSON: contribJSON,
                remSleepMinutes: s.rem, deepSleepMinutes: s.deep, lightSleepMinutes: s.light,
                totalSleepMinutes: s.tot, sleepEfficiency: d.eff,
                temperatureDeviation: d.td, restingHeartRate: d.rhr,
                hrvDaytimeLow: d.hrvL, stressFlag: d.sf,
                respiratoryRate: d.rr, spo2Percentage: d.sp,
                sleepLatencyMinutes: s.lat, stressScore: d.sts,
                stressDurationMinutes: d.stD, sleepMidpointDeviation: d.mpd
            ))
        }
    }

    // MARK: - Activity (14 days, causally linked)

    private static func seedActivity(context: ModelContext, cal: Calendar, today: Date) {
        let acts: [(off: Int, wt: String, steps: Int, cal: Double, dist: Double, hi: Double, med: Double, vo2: Double, acu: Double, chr: Double)] = [
            (0,  "HIIT",     5200,  310, 4100,  25, 18, 38.8, 380, 350),
            (1,  "Running",  7000,  420, 5600,  18, 28, 39.1, 360, 345),
            (2,  "Strength", 7500,  380, 5900,  12, 35, 38.5, 340, 340),
            (3,  "Cycling",  8100,  450, 6400,  20, 32, 39.4, 355, 338),
            (4,  "Yoga",     5800,  220, 4600,  0,  40, 38.2, 310, 335),
            (5,  "Walking",  6200,  260, 4900,  0,  22, 38.0, 290, 330),
            (6,  "Rest",     3800,  140, 3000,  0,  0,  37.8, 250, 325),
            (7,  "HIIT",     9200,  520, 7300,  32, 22, 39.6, 420, 320),
            (8,  "Pilates",  6500,  280, 5100,  5,  35, 38.5, 330, 318),
            (9,  "Running",  7800,  400, 6200,  16, 25, 39.0, 345, 315),
            (10, "Strength", 8400,  440, 6600,  10, 38, 38.7, 350, 310),
            (11, "Yoga",     7200,  250, 5700,  0,  42, 38.3, 300, 308),
            (12, "Rest",     5400,  180, 4300,  0,  0,  38.0, 260, 305),
            (13, "Walking",  6800,  290, 5400,  0,  20, 38.1, 280, 300),
        ]
        for a in acts {
            guard let day = cal.date(byAdding: .day, value: -a.off, to: today) else { continue }
            context.insert(OuraActivityDay(
                date: day, steps: a.steps, activeCalories: a.cal,
                equivalentWalkingDistanceMeters: a.dist,
                highIntensityMinutes: a.hi, mediumIntensityMinutes: a.med,
                workoutType: a.wt, vo2Max: a.vo2,
                trainingLoadAcute: a.acu, trainingLoadChronic: a.chr
            ))
        }
    }

    // MARK: - Meals (causally consistent with sleep outcomes)

    private static func seedMeals(context: ModelContext, cal: Calendar, today: Date) {
        let microSets: [[String: Double]] = [
            ["magnesium_mg": 85, "sodium_mg": 620, "vitamin_c_mg": 42, "iron_mg": 4.5, "calcium_mg": 220, "fiber_g": 7, "potassium_mg": 410, "zinc_mg": 3.2, "vitamin_b12_mcg": 1.8, "vitamin_d_iu": 120, "chromium_mcg": 12, "omega3_mg": 450],
            ["magnesium_mg": 45, "sodium_mg": 890, "vitamin_c_mg": 15, "iron_mg": 2.1, "calcium_mg": 80, "fiber_g": 3, "potassium_mg": 250, "zinc_mg": 1.5, "vitamin_b12_mcg": 0.4, "vitamin_d_iu": 40, "chromium_mcg": 5, "omega3_mg": 80],
            ["magnesium_mg": 120, "sodium_mg": 340, "vitamin_c_mg": 65, "iron_mg": 6.2, "calcium_mg": 310, "fiber_g": 12, "potassium_mg": 680, "zinc_mg": 4.8, "vitamin_b12_mcg": 3.2, "vitamin_d_iu": 280, "chromium_mcg": 18, "omega3_mg": 1200],
            ["magnesium_mg": 30, "sodium_mg": 1100, "vitamin_c_mg": 8, "iron_mg": 1.5, "calcium_mg": 60, "fiber_g": 2, "potassium_mg": 180, "zinc_mg": 0.8, "vitamin_b12_mcg": 0.2, "vitamin_d_iu": 20, "chromium_mcg": 3, "omega3_mg": 40],
            ["magnesium_mg": 55, "sodium_mg": 480, "vitamin_c_mg": 28, "iron_mg": 3.0, "calcium_mg": 150, "fiber_g": 5, "potassium_mg": 320, "zinc_mg": 2.0, "vitamin_b12_mcg": 1.0, "vitamin_d_iu": 80, "chromium_mcg": 8, "omega3_mg": 220],
        ]

        func microJSON(_ idx: Int) -> String? {
            let d = microSets[idx % microSets.count]
            guard let data = try? JSONEncoder().encode(d), let s = String(data: data, encoding: .utf8) else { return nil }
            return s
        }

        typealias M = (h: Int, m: Int, cal: Double, p: Double, c: Double, f: Double, note: String, gi: Bool, fib: Double, sug: Double, sod: Double, caff: Double, alc: Double, gl: Double)

        let cleanDay: [M] = [
            (8,  10, 420, 22, 48, 16, "Greek yogurt & mixed berries",    false, 3, 12, 180, 0,   0,   22),
            (12, 30, 580, 35, 52, 22, "Grilled chicken & quinoa bowl",   false, 8, 6,  480, 0,   0,   28),
            (16, 0,  45,  1,  0,  0,  "Espresso",                        false, 0, 0,  5,   95,  0,   0),
            (19, 30, 650, 38, 55, 24, "Salmon with roasted vegetables",  false, 6, 8,  520, 0,   0,   26),
        ]

        let lateMealDay: [M] = [
            (7,  30, 350, 20, 42, 12, "Oatmeal with walnuts & banana",   false, 5, 14, 120, 0,   0,   18),
            (12, 0,  620, 32, 58, 20, "Turkey wrap with avocado",        false, 7, 5,  520, 0,   0,   30),
            (15, 30, 90,  1,  0,  0,  "Double espresso",                 false, 0, 0,  5,   190, 0,   0),
            (19, 0,  550, 28, 48, 22, "Stir-fry with brown rice",        false, 6, 6,  480, 0,   0,   28),
            (22, 15, 420, 14, 62, 16, "Late-night pasta & wine",         true,  2, 8,  680, 0,   1.5, 52),
        ]

        let comfortDay: [M] = [
            (9,  0,  380, 12, 58, 14, "Pancakes with maple syrup",       true,  1, 22, 420, 0,   0,   45),
            (13, 0,  710, 22, 78, 32, "Burger with fries",               true,  3, 8,  980, 0,   0,   55),
            (16, 0,  45,  1,  0,  0,  "Espresso",                        false, 0, 0,  5,   95,  0,   0),
            (20, 0,  580, 30, 52, 20, "Chicken stir-fry with noodles",   false, 5, 6,  620, 0,   0,   32),
        ]

        let pristineDay: [M] = [
            (7,  40, 310, 24, 32, 10, "Protein smoothie with spinach",   false, 4, 8,  80,  0,   0,   14),
            (12, 15, 520, 38, 42, 18, "Iron-rich lentil bowl with kale", false, 14, 4, 280, 0,   0,   18),
            (15, 30, 30,  0,  0,  0,  "Herbal tea",                      false, 0, 0,  0,   0,   0,   0),
            (19, 0,  600, 40, 48, 22, "Wild salmon & sweet potato",      false, 7, 6,  380, 0,   0,   22),
        ]

        let todayMeals: [M] = [
            (8,  0,  380, 22, 40, 14, "Overnight oats with chia & berries", false, 6, 10, 140, 0,  0,  16),
            (12, 30, 560, 34, 48, 20, "Mediterranean bowl with falafel",    false, 9, 5,  420, 0,  0,  24),
            (16, 0,  45,  1,  0,  0,  "Espresso",                           false, 0, 0,  5,   95, 0,  0),
            (19, 45, 680, 36, 58, 26, "Grilled chicken with roasted veg",   false, 7, 7,  480, 0,  0,  28),
        ]

        let dayMealMap: [Int: [M]] = [
            0: todayMeals, 1: cleanDay, 2: pristineDay, 3: pristineDay,
            4: cleanDay, 5: cleanDay, 6: comfortDay, 7: lateMealDay,
            8: cleanDay, 9: cleanDay, 10: cleanDay, 11: cleanDay,
            12: cleanDay, 13: cleanDay,
        ]

        for offset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let mealsForDay = dayMealMap[offset] ?? cleanDay
            for (idx, sp) in mealsForDay.enumerated() {
                var c = cal.dateComponents([.year, .month, .day], from: day); c.hour = sp.h; c.minute = sp.m
                let ts = cal.date(from: c) ?? day
                context.insert(MealEntry(
                    timestamp: ts, calories: sp.cal, protein: sp.p, carbs: sp.c, fat: sp.f,
                    userNotes: sp.note, micronutrientsJSON: microJSON(idx),
                    isHighGlycemic: sp.gi, isLateNight: sp.h >= 21,
                    fiber: sp.fib, sugar: sp.sug, sodium: sp.sod,
                    caffeineMg: sp.caff, alcoholUnits: sp.alc, glycemicLoad: sp.gl
                ))
            }
        }
    }

    // MARK: - Energy Activities

    private static func seedEnergyActivities(context: ModelContext, cal: Calendar, today: Date) {
        if (try? context.fetch(FetchDescriptor<EnergyActivity>()))?.isEmpty == false { return }
        let entries: [(h: Int, type: String, int: String, eff: String, ctx: String, delta: Int, hrv: Double, off: Int)] = [
            (7,  "recovery", "low",    "deposit",    "Morning meditation & stretching",  15,  3.2,  0),
            (10, "workout",  "medium", "deposit",    "Pilates class",                    25,  4.5,  0),
            (14, "work",     "high",   "withdrawal", "Stressful deadline meeting",       -20, -6.1, 0),
            (19, "nature",   "low",    "deposit",    "Evening walk in the park",         10,  2.8,  0),
            (8,  "workout",  "high",   "deposit",    "HIIT session",                     30,  5.2,  1),
            (13, "social",   "medium", "withdrawal", "Lunch with large group",           -10, -2.1, 1),
            (21, "social",   "high",   "withdrawal", "Rock concert — 3 hours",           -35, -8.5, 1),
            (7,  "recovery", "low",    "deposit",    "Yoga & journaling",                20,  4.0,  2),
            (11, "illness",  "high",   "withdrawal", "Migraine — stayed in bed",         -40, -10.2, 2),
            (15, "recovery", "low",    "deposit",    "Nap & chamomile tea",              10,  1.5,  2),
            (9,  "nature",   "low",    "deposit",    "Nature hike — 45 min",             20,  3.8,  3),
            (12, "creative", "medium", "deposit",    "Painting workshop",                15,  2.0,  3),
            (17, "work",     "medium", "withdrawal", "Back-to-back video calls",         -15, -3.5, 3),
            (7,  "workout",  "medium", "deposit",    "Morning run — 5K",                 25,  4.8,  4),
            (20, "social",   "low",    "deposit",    "Dinner with close friend",         10,  1.2,  4),
            (10, "travel",   "high",   "withdrawal", "Long taxi + airport stress",       -30, -7.0, 5),
            (8,  "recovery", "low",    "deposit",    "Sleep-in & gentle walk",           15,  3.0,  6),
            (14, "workout",  "medium", "deposit",    "Swimming — 30 laps",               20,  3.5,  6),
            (7,  "workout",  "high",   "deposit",    "HIIT — pushed hard",               30,  5.0,  7),
            (22, "social",   "high",   "withdrawal", "Late dinner party",                -25, -6.0, 7),
            (9,  "nature",   "low",    "deposit",    "Park walk with dog",               18,  3.2,  8),
            (7,  "workout",  "medium", "deposit",    "Strength training",                22,  4.2,  9),
            (10, "workout",  "high",   "deposit",    "CrossFit class",                   28,  5.5,  10),
            (15, "work",     "medium", "withdrawal", "3-hour strategy session",          -12, -2.8, 11),
            (8,  "recovery", "low",    "deposit",    "Yin yoga & meditation",            18,  3.5,  12),
            (9,  "nature",   "low",    "deposit",    "Morning jog in the park",          20,  3.8,  13),
        ]
        for e in entries {
            guard let day = cal.date(byAdding: .day, value: -e.off, to: today) else { continue }
            var c = cal.dateComponents([.year, .month, .day], from: day); c.hour = e.h; c.minute = 0
            let ts = cal.date(from: c) ?? day
            context.insert(EnergyActivity(
                timestamp: ts, activityType: e.type, intensity: e.int,
                energyEffect: e.eff, context: e.ctx, energyDelta: e.delta, linkedHRVChange: e.hrv
            ))
        }
    }

    // MARK: - User Profile

    private static func seedProfile(context: ModelContext) {
        if (try? context.fetch(FetchDescriptor<UserProfile>()))?.isEmpty == false { return }
        context.insert(UserProfile(
            knownConditions: "PCOS, Insulin Sensitivity, Anemia",
            healthGoals: "Optimize Sleep, Manage Stress, Hormonal Health",
            cycleDay: 18, cycleLength: 28, hasCompletedOnboarding: true,
            age: 28, ouraConnected: true,
            medications: "Metformin 500mg, Iron Supplement, Vitamin D3, Inositol 4g",
            waterIntakeMl: 1800, dailyWaterGoalMl: 2500,
            bloodPressureSystolic: 118, bloodPressureDiastolic: 76,
            glucoseMgDl: 92, moodRating: 3, energyRating: 4,
            bodyFatPercentage: 24.5, lastMenstrualFlow: "Medium",
            waistCm: 74, hipCm: 96, sleepGoalHours: 7.5
        ))
    }

    // MARK: - Lab Results

    private static func seedLabResults(context: ModelContext, cal: Calendar, today: Date) {
        if (try? context.fetch(FetchDescriptor<LabResult>()))?.isEmpty == false { return }
        let recent = cal.date(byAdding: .day, value: -13, to: today) ?? today
        let older  = cal.date(byAdding: .day, value: -45, to: today) ?? today
        let labs: [(t: String, v: Double, u: String, lo: Double, hi: Double, d: Date, n: String)] = [
            ("ferritin",           18,    "ng/mL",   20,   200,  recent, "Below range — consistent with iron-deficiency anemia"),
            ("hemoglobin",         11.2,  "g/dL",    12,   16,   recent, "Slightly low — monitor with iron supplementation"),
            ("hba1c",              5.6,   "%",       4.0,  5.7,  recent, "Upper normal — borderline for insulin resistance"),
            ("fasting_insulin",    14.5,  "µIU/mL",  2.6,  11.1, recent, "Elevated — suggests insulin resistance"),
            ("fasting_glucose",    92,    "mg/dL",   70,   100,  recent, "Normal fasting glucose"),
            ("homa_ir",            3.3,   "",        0.5,  2.5,  recent, "Elevated HOMA-IR confirms insulin resistance"),
            ("total_testosterone", 68,    "ng/dL",   15,   46,   recent, "Elevated — hyperandrogenism (PCOS marker)"),
            ("dhea_s",             380,   "µg/dL",   65,   380,  recent, "Upper limit — adrenal androgen contribution"),
            ("tsh",                2.8,   "mIU/L",   0.4,  4.0,  older,  "Normal thyroid function"),
            ("free_t4",            1.1,   "ng/dL",   0.8,  1.8,  older,  "Normal"),
            ("vitamin_d",          22,    "ng/mL",   30,   100,  recent, "Deficient — increase D3 supplementation"),
            ("vitamin_b12",        280,   "pg/mL",   200,  900,  recent, "Low-normal — Metformin may impair absorption"),
            ("total_cholesterol",  195,   "mg/dL",   0,    200,  older,  "Borderline"),
            ("ldl",                118,   "mg/dL",   0,    100,  older,  "Slightly elevated"),
            ("hdl",                52,    "mg/dL",   50,   90,   older,  "Lower end of normal"),
            ("triglycerides",      142,   "mg/dL",   0,    150,  older,  "Normal but watch with insulin resistance"),
            ("crp",                2.8,   "mg/L",    0,    1.0,  recent, "Elevated — indicates systemic inflammation"),
        ]
        for l in labs {
            context.insert(LabResult(
                date: l.d, testType: l.t, value: l.v,
                unit: l.u, referenceRangeLow: l.lo, referenceRangeHigh: l.hi, notes: l.n
            ))
        }
    }

    // MARK: - Cycle Symptoms (aligned with cycle day 18 today → luteal)

    private static func seedCycleSymptoms(context: ModelContext, cal: Calendar, today: Date) {
        if (try? context.fetch(FetchDescriptor<CycleSymptom>()))?.isEmpty == false { return }
        let symptoms: [(off: Int, cd: Int, phase: String, bl: Int, cr: Int, ac: Int, hd: Int, br: Int, cv: Int, md: Int, ft: Int, lb: Int)] = [
            (0,  18, "Luteal",     2, 1, 1, 0, 2, 3, 2, 2, 1),
            (1,  17, "Luteal",     3, 2, 1, 1, 2, 3, 3, 3, 1),
            (2,  16, "Luteal",     2, 1, 0, 0, 1, 2, 1, 2, 2),
            (3,  15, "Ovulation",  0, 0, 0, 0, 0, 1, 0, 0, 4),
            (4,  14, "Ovulation",  0, 0, 0, 0, 0, 0, 0, 0, 4),
            (5,  13, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 3),
            (6,  12, "Follicular", 0, 0, 0, 0, 0, 0, 0, 1, 3),
            (7,  11, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 3),
            (8,  10, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 3),
            (9,   9, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 2),
            (10,  8, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 2),
            (11,  7, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 2),
            (12,  6, "Follicular", 0, 0, 0, 0, 0, 0, 0, 0, 2),
            (13,  5, "Menstrual",  1, 2, 0, 1, 1, 1, 1, 2, 1),
        ]
        for s in symptoms {
            guard let day = cal.date(byAdding: .day, value: -s.off, to: today) else { continue }
            context.insert(CycleSymptom(
                date: day, cycleDay: s.cd, phase: s.phase,
                bloating: s.bl, cramps: s.cr, acne: s.ac, headache: s.hd,
                breastTenderness: s.br, cravings: s.cv, moodSwings: s.md,
                fatigue: s.ft, libido: s.lb
            ))
        }
    }

    // MARK: - Presentation Mode (reset & re-seed with real data)

    static func seedPresentationMode(context: ModelContext) {
        try? context.fetch(FetchDescriptor<OuraMetrics>()).forEach { context.delete($0) }
        try? context.fetch(FetchDescriptor<OuraActivityDay>()).forEach { context.delete($0) }
        try? context.fetch(FetchDescriptor<MealEntry>()).forEach { context.delete($0) }
        try? context.fetch(FetchDescriptor<EnergyActivity>()).forEach { context.delete($0) }
        try? context.fetch(FetchDescriptor<CycleSymptom>()).forEach { context.delete($0) }
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        seedOuraMetrics(context: context, cal: cal, today: today)
        seedActivity(context: context, cal: cal, today: today)
        seedMeals(context: context, cal: cal, today: today)
        seedEnergyActivities(context: context, cal: cal, today: today)
        seedCycleSymptoms(context: context, cal: cal, today: today)
        try? context.save()
    }
}
