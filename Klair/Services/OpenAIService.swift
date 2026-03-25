import Foundation
import UIKit

struct MealMacroEstimate: Decodable, Sendable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var notes: String?
    /// Estimated micronutrients (e.g. vitamin_c_mg, iron_mg); not lab-accurate.
    var micronutrients: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case calories, protein, carbs, fat, notes, micronutrients
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        calories = try c.decodeFlexibleDouble(forKey: .calories)
        protein = try c.decodeFlexibleDouble(forKey: .protein)
        carbs = try c.decodeFlexibleDouble(forKey: .carbs)
        fat = try c.decodeFlexibleDouble(forKey: .fat)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        micronutrients = try c.decodeIfPresent([String: Double].self, forKey: .micronutrients)
    }

    init(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        notes: String? = nil,
        micronutrients: [String: Double]? = nil
    ) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.notes = notes
        self.micronutrients = micronutrients
    }
}

// MARK: - Nourish flow (structured meal analysis)

struct NourishMealEstimate: Decodable, Sendable, Equatable {
    var mealName: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var ingredients: [String]
    var notes: String?
    var micronutrients: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case mealName, meal_name
        case calories, protein, carbs, fat, fats
        case ingredients, notes, micronutrients
    }

    init(
        mealName: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        ingredients: [String] = [],
        notes: String? = nil,
        micronutrients: [String: Double]? = nil
    ) {
        self.mealName = mealName
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.ingredients = ingredients
        self.notes = notes
        self.micronutrients = micronutrients
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mealName = try c.decodeIfPresent(String.self, forKey: .mealName)
            ?? c.decodeIfPresent(String.self, forKey: .meal_name)
            ?? "Meal"
        calories = Self.decodeFlexDouble(c, .calories)
        protein = Self.decodeFlexDouble(c, .protein)
        carbs = Self.decodeFlexDouble(c, .carbs)
        if let v = try? c.decode(Double.self, forKey: .fat) { fat = v }
        else if let v = try? c.decode(Double.self, forKey: .fats) { fat = v }
        else if let i = try? c.decode(Int.self, forKey: .fat) { fat = Double(i) }
        else if let i = try? c.decode(Int.self, forKey: .fats) { fat = Double(i) }
        else { fat = 0 }
        ingredients = (try c.decodeIfPresent([String].self, forKey: .ingredients)) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        micronutrients = try c.decodeIfPresent([String: Double].self, forKey: .micronutrients)
    }

    private static func decodeFlexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        return 0
    }
}

private extension KeyedDecodingContainer where K == MealMacroEstimate.CodingKeys {
    func decodeFlexibleDouble(forKey key: K) throws -> Double {
        if let v = try? decode(Double.self, forKey: key) { return v }
        if let i = try? decode(Int.self, forKey: key) { return Double(i) }
        return 0
    }
}

enum GeminiError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case httpStatus(Int, String?)
    case badResponse
    case decoding(Error)
    case blocked(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Gemini URL."
        case .missingAPIKey: return "Set GEMINI_API_KEY in Xcode → Scheme → Run → Environment Variables."
        case .httpStatus(let c, let b): return "Gemini error \(c): \(b ?? "")"
        case .badResponse: return "Unexpected Gemini response."
        case .decoding: return "Could not parse AI response."
        case .blocked(let reason): return "Response blocked: \(reason)"
        }
    }
}

struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

/// Google Gemini AI service: vision meal analysis, coach chat, and general insight generation.
/// Set `GEMINI_API_KEY` in the Xcode scheme → Run → Arguments → Environment Variables (never commit keys).
final class GeminiService: Sendable {
    private let model = "gemini-2.5-flash"
    private let session: URLSession

    private var apiKey: String {
        ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var endpoint: URL {
        let key = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)")!
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Meal Vision Analysis

    func analyzeMeal(image: UIImage, userText: String) async throws -> NourishMealEstimate {
        if DemoMode.useMockRemoteServices {
            try await Task.sleep(nanoseconds: 900_000_000)
            return NourishMealEstimate(
                mealName: "Demo nourish bowl",
                calories: 520, protein: 28, carbs: 48, fat: 22,
                ingredients: ["Mixed greens", "Grilled chicken", "Quinoa", "Olive oil", "Tomatoes"],
                notes: "Demo estimate: balanced plate with protein and greens (mock).",
                micronutrients: ["vitamin_c_mg": 42, "iron_mg": 4.5, "calcium_mg": 220, "fiber_g": 7]
            )
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.55) else { throw GeminiError.badResponse }
        let b64 = jpeg.base64EncodedString()
        let prompt = userText.isEmpty ? "Analyze this meal photo." : userText

        let schema = """
        Return ONE JSON object only (no markdown) with keys:
        mealName (string), calories (number), protein (number, grams), carbs (number, grams), fats (number, grams of fat),
        ingredients (array of strings, visible or likely items), notes (string, optional short description),
        micronutrients (object, optional) with keys like vitamin_c_mg, iron_mg, calcium_mg, fiber_g.
        """

        let body = GeminiRequest(
            systemInstruction: .init(parts: [
                .init(text: "You are a nutrition vision AI. \(schema) Values are rough visual estimates, not medical facts.")
            ]),
            contents: [
                .init(role: "user", parts: [
                    .init(text: prompt),
                    .init(inlineData: .init(mimeType: "image/jpeg", data: b64))
                ])
            ],
            generationConfig: .init(
                responseMimeType: "application/json",
                temperature: 0.3,
                maxOutputTokens: 1024
            )
        )

        let text = try await sendRequest(body: body)
        let cleaned = Self.stripJSONMarkdown(text)
        let data = Data(cleaned.utf8)
        do {
            return try JSONDecoder().decode(NourishMealEstimate.self, from: data)
        } catch {
            return HeuristicFallback.nourishMealFallback(userNotes: userText)
        }
    }

    private static func stripJSONMarkdown(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```json") { t = String(t.dropFirst(7)) }
        else if t.hasPrefix("```") { t = String(t.dropFirst(3)) }
        if t.hasSuffix("```") { t = String(t.dropLast(3)) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Coach Chat

    func coachReply(contextJSON: String, conversation: [ChatMessage]) async throws -> String {
        try await klairAgentReply(contextJSON: contextJSON, conversation: conversation)
    }

    /// Klair coach: universal Q&A with full context; response uses Summary / Insights / Recommendations.
    func klairAgentReply(contextJSON: String, conversation: [ChatMessage]) async throws -> String {
        if DemoMode.useMockRemoteServices {
            try await Task.sleep(nanoseconds: 650_000_000)
            return Self.mockCoachReply(conversation: conversation)
        }

        let systemPrompt = """
        You are Klair — the in-app AI brain connected to Google Gemini. You receive a FULL JSON snapshot of Marta's health app: profile, Oura (14d), meals, activity, energy logs, labs, cycle symptoms, HealthKit workouts/cycle, computed alerts, and correlations. Answer ANY question she asks about this data (sleep, food, PCOS, iron, readiness, stress, training, etc.).

        Rules:
        - Your name is Klair only.
        - Never diagnose or prescribe; encourage clinicians for medical decisions. Meal micronutrients are estimates.
        - Ground every answer in the Context JSON when relevant; cite concrete numbers (readiness, HRV, sleep score, lab values, meal patterns).
        - Reply in the same language the user writes in (Spanish or English).

        REQUIRED response shape (markdown, bold headings):
        **Summary:** 1–2 sentences.
        **Insights:** 2–4 sentences tied to her actual metrics.
        **Recommendations:** 1–3 numbered actions.

        Context JSON (full app state):
        \(contextJSON)
        """

        var contents: [GeminiContent] = []
        for msg in conversation {
            let role = msg.role == "user" ? "user" : "model"
            contents.append(.init(role: role, parts: [.init(text: msg.content)]))
        }

        let body = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: contents,
            generationConfig: .init(
                responseMimeType: nil,
                temperature: 0.65,
                maxOutputTokens: 4096
            )
        )
        return try await sendRequest(body: body)
    }

    // MARK: - General Insight Generation

    func generateInsight(prompt: String, contextJSON: String) async throws -> String {
        if DemoMode.useMockRemoteServices {
            try await Task.sleep(nanoseconds: 400_000_000)
            return ""
        }

        let systemPrompt = """
        You are Klair, a health analytics AI. Analyze the user's health data and provide concise, actionable insights. Be warm but data-driven. Reference specific metrics. Keep responses to 2-3 sentences max.

        Health Data:
        \(contextJSON)
        """

        let body = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: prompt)])],
            generationConfig: .init(
                responseMimeType: nil,
                temperature: 0.6,
                maxOutputTokens: 512
            )
        )
        return try await sendRequest(body: body)
    }

    // MARK: - Chef Pantry Recipe Generation

    func generateRecipes(pantryItems: String, contextJSON: String) async throws -> [RecipeCard] {
        if DemoMode.useMockRemoteServices {
            try await Task.sleep(nanoseconds: 800_000_000)
            return RecipeCard.mockRecipes
        }

        let systemPrompt = """
        You are Klair Chef, a nutrition-aware recipe AI for Marta. She has PCOS, anemia (low ferritin), and is on Metformin. Generate recipes that address her specific health conditions and current recovery state.
        Never use the name Luna; the app is Klair.

        Return a JSON array of exactly 3 recipe objects. Each object has keys:
        - title (string): recipe name
        - calories (number)
        - protein (number, grams)
        - carbs (number, grams)
        - fat (number, grams)
        - ingredients (array of strings)
        - steps (array of strings, 3-5 short steps)
        - why (string): 1-2 sentences explaining why this recipe helps Marta's specific health state today
        - imageKeyword (string): a single food keyword for image lookup, e.g. "salmon", "lentil", "smoothie"

        Health context:
        \(contextJSON)
        """

        let body = GeminiRequest(
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            contents: [.init(role: "user", parts: [.init(text: "I have these ingredients: \(pantryItems). Generate 3 recipes that use what I have and support my health goals.")])],
            generationConfig: .init(
                responseMimeType: "application/json",
                temperature: 0.7,
                maxOutputTokens: 3072
            )
        )

        let text = try await sendRequest(body: body)
        let cleaned = Self.stripJSONMarkdown(text)
        let data = Data(cleaned.utf8)
        do {
            return try JSONDecoder().decode([RecipeCard].self, from: data)
        } catch {
            throw GeminiError.decoding(error)
        }
    }

    // MARK: - Networking

    private func sendRequest(body: GeminiRequest) async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.missingAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw GeminiError.badResponse }
        guard (200...299).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8)
            throw GeminiError.httpStatus(http.statusCode, s)
        }
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content.parts.first?.text else {
            if let reason = decoded.promptFeedback?.blockReason {
                throw GeminiError.blocked(reason)
            }
            throw GeminiError.badResponse
        }
        return text
    }

    private static func mockCoachReply(conversation: [ChatMessage]) -> String {
        let lastUser = conversation.reversed().first { $0.role == "user" }?.content ?? ""
        let quoted = lastUser.isEmpty ? "your day" : "“\(String(lastUser.prefix(100)))\(lastUser.count > 100 ? "…" : "")”"
        return """
        **Summary:** Klair is running in demo mode with your sample Oura and meal data — no live AI yet.

        **Insights:** You asked about \(quoted). From the snapshot, your sleep scores look steady across the week. Those later-evening snacks line up with the gentle recovery nudge on your dashboard sometimes — totally normal when work runs late.

        **Recommendations:**
        1. When you disable demo mode, I'll read your real context JSON and go deeper with Gemini.
        2. For now, try one wind-down ritual after 9 PM and see if your morning readiness ticks up.
        """
    }
}

// MARK: - Recipe Card Model

struct RecipeCard: Decodable, Identifiable, Sendable {
    var id: String { title }
    let title: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let ingredients: [String]
    let steps: [String]
    let why: String
    let imageKeyword: String

    var macroSummary: String { "P \(Int(protein))g · C \(Int(carbs))g · F \(Int(fat))g" }

    enum CodingKeys: String, CodingKey {
        case title, name
        case calories, protein, carbs, fat, fats
        case ingredients, steps, why, reason
        case imageKeyword, image_keyword
    }

    init(
        title: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        ingredients: [String],
        steps: [String],
        why: String,
        imageKeyword: String
    ) {
        self.title = title
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.ingredients = ingredients
        self.steps = steps
        self.why = why
        self.imageKeyword = imageKeyword
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title)
            ?? c.decode(String.self, forKey: .name)
        calories = RecipeCard.decodeFlex(c, .calories)
        protein = RecipeCard.decodeFlex(c, .protein)
        carbs = RecipeCard.decodeFlex(c, .carbs)
        if let v = try? c.decode(Double.self, forKey: .fat) { fat = v }
        else if let v = try? c.decode(Double.self, forKey: .fats) { fat = v }
        else if let i = try? c.decode(Int.self, forKey: .fat) { fat = Double(i) }
        else if let i = try? c.decode(Int.self, forKey: .fats) { fat = Double(i) }
        else { fat = 0 }
        ingredients = (try c.decodeIfPresent([String].self, forKey: .ingredients)) ?? []
        steps = (try c.decodeIfPresent([String].self, forKey: .steps)) ?? ["Combine pantry ingredients", "Season to taste", "Cook until done"]
        why = try c.decodeIfPresent(String.self, forKey: .why)
            ?? c.decodeIfPresent(String.self, forKey: .reason)
            ?? "Balanced for your goals and recovery."
        imageKeyword = try c.decodeIfPresent(String.self, forKey: .imageKeyword)
            ?? c.decodeIfPresent(String.self, forKey: .image_keyword)
            ?? "healthy food"
    }

    private static func decodeFlex(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        return 0
    }

    static let mockRecipes: [RecipeCard] = [
        RecipeCard(title: "Iron-Rich Lentil Bowl", calories: 480, protein: 26, carbs: 52, fat: 14,
                   ingredients: ["Red lentils", "Spinach", "Lemon", "Cumin", "Brown rice"],
                   steps: ["Cook lentils with cumin 15 min", "Sauté spinach with garlic", "Serve over brown rice with lemon"],
                   why: "High iron + Vitamin C pairing maximizes absorption — critical for your anemia.",
                   imageKeyword: "lentil"),
        RecipeCard(title: "Anti-Inflammatory Salmon", calories: 520, protein: 38, carbs: 28, fat: 26,
                   ingredients: ["Salmon fillet", "Sweet potato", "Broccoli", "Olive oil", "Turmeric"],
                   steps: ["Season salmon with turmeric", "Roast with sweet potato at 400°F 20 min", "Steam broccoli, plate together"],
                   why: "Omega-3s reduce PCOS inflammation; sweet potato provides low-GI complex carbs for stable energy.",
                   imageKeyword: "salmon"),
        RecipeCard(title: "Magnesium Recovery Smoothie", calories: 280, protein: 18, carbs: 32, fat: 10,
                   ingredients: ["Banana", "Spinach", "Almond butter", "Cacao powder", "Greek yogurt"],
                   steps: ["Blend all ingredients with ice", "Add water to desired consistency", "Enjoy within 30 min of exercise"],
                   why: "Magnesium supports luteal phase cramp relief and improves sleep quality — your HRV may benefit tonight.",
                   imageKeyword: "smoothie"),
    ]
}

// MARK: - Heuristic Fallback Engine

enum HeuristicFallback {
    static func coachFallback(for question: String, contextJSON: String) -> String {
        let q = question.lowercased()
        let ctx = contextJSON.lowercased()

        if q.contains("hrv") || q.contains("heart rate variability") {
            return "**Summary:** Your HRV reflects autonomic nervous system balance.\n\n**Insights:** Based on your recent data, late meals and hard evening training often line up with lower next-day HRV; luteal phase can also soften HRV without meaning you’re “unfit.”\n\n**Recommendations:**\n1. Try a 10-minute easy walk and nasal breathing to nudge HRV.\n2. Finish eating by 8 PM tonight.\n3. If readiness in your context looks low, favor light movement tomorrow."
        }
        if q.contains("sleep") || q.contains("insomnia") || q.contains("rest") {
            return "**Summary:** Sleep is the main lever for tomorrow’s readiness.\n\n**Insights:** Your patterns often improve when late calories and afternoon caffeine drop — that matches what we see in many recovery logs.\n\n**Recommendations:**\n1. Set a “kitchen closes” reminder around 8:30 PM.\n2. Swap late caffeine for herbal tea.\n3. Try magnesium glycinate 30 minutes before bed (if appropriate for you)."
        }
        if q.contains("cycle") || q.contains("period") || q.contains("luteal") || q.contains("menstrual") {
            return "**Summary:** Cycle phase changes how recovery “feels” day to day.\n\n**Insights:** In the luteal phase, progesterone can raise temperature and soften HRV — that can be normal physiology, not a training failure.\n\n**Recommendations:**\n1. Prioritize magnesium-rich foods (spinach, nuts, dark chocolate).\n2. Swap HIIT for Pilates or brisk walking when energy dips.\n3. Add iron-friendly meals if you’re approaching your period."
        }
        if q.contains("energy") || q.contains("tired") || q.contains("fatigue") || q.contains("battery") {
            return "**Summary:** Your “energy battery” is fed by sleep, fuel, hydration, and stress load.\n\n**Insights:** Deposits (light movement, protein, daylight) and withdrawals (long meetings, late meals) show up in your energy logs and readiness.\n\n**Recommendations:**\n1. Take a 10-minute walk outside to support HRV and alertness.\n2. Eat 25–40g protein at your next meal to stabilize glucose.\n3. Top up water — even mild dehydration drags perceived energy."
        }
        if q.contains("iron") || q.contains("anemia") || q.contains("ferritin") || ctx.contains("ferritin") {
            return "**Summary:** Iron matters for oxygen delivery — especially with anemia.\n\n**Insights:** Pairing iron with vitamin C helps absorption; coffee/dairy near iron-rich meals works against you. Metformin can affect B12 on top of fatigue.\n\n**Recommendations:**\n1. Pair iron-rich foods with citrus or bell peppers.\n2. Keep coffee away from iron supplements by ~2 hours.\n3. Discuss rechecking ferritin/B12 with your clinician."
        }
        if q.contains("pcos") || q.contains("insulin") {
            return "**Summary:** Stable glucose helps PCOS symptoms and sleep.\n\n**Insights:** High-GI spikes often track with crashes and rougher nights — your meal flags can be a useful early warning.\n\n**Recommendations:**\n1. Pair carbs with protein or healthy fat every time.\n2. Favor lentils, beans, sweet potato, and quinoa over refined starches.\n3. In Fuel → Chef, generate low-GI ideas from your pantry list."
        }
        if q.contains("eat") || q.contains("food") || q.contains("meal") || q.contains("recipe") || q.contains("nutrition") {
            return "**Summary:** Food timing and composition are the fastest levers you control.\n\n**Insights:** Late eating and high-GI patterns often correlate with lower sleep efficiency in your style of data.\n\n**Recommendations:**\n1. Aim for 25–40g protein per meal.\n2. Close your eating window by 8:30 PM when you can.\n3. In Fuel, open the Chef segment and generate recipes from your pantry list."
        }

        return "**Summary:** I’m answering offline using your question and saved health snapshot.\n\n**Insights:** Without the live model, I still see themes around readiness, sleep, cycle, and meal timing in your stored JSON — small consistent habits usually beat perfect plans.\n\n**Recommendations:**\n1. Check Pulse for today’s readiness and sleep drivers.\n2. Ask something specific: HRV, sleep, cycle, iron, or energy.\n3. Use Chef with your pantry list for tailored meal ideas."
    }

    static func nourishMealFallback(userNotes: String) -> NourishMealEstimate {
        let base = mealMacroFromKeywords(userNotes)
        let name: String = {
            let t = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return "Estimated meal" }
            return String(t.prefix(48)) + (t.count > 48 ? "…" : "")
        }()
        return NourishMealEstimate(
            mealName: name,
            calories: base.calories,
            protein: base.protein,
            carbs: base.carbs,
            fat: base.fat,
            ingredients: inferIngredients(from: userNotes),
            notes: base.notes,
            micronutrients: base.micronutrients
        )
    }

    private static func mealMacroFromKeywords(_ notes: String) -> MealMacroEstimate {
        let n = notes.lowercased()
        if n.contains("salad") || n.contains("greens") {
            return MealMacroEstimate(calories: 350, protein: 15, carbs: 25, fat: 18, notes: "Estimated: mixed salad (heuristic)", micronutrients: ["iron_mg": 3, "vitamin_c_mg": 30, "fiber_g": 6])
        }
        if n.contains("chicken") || n.contains("pollo") {
            return MealMacroEstimate(calories: 450, protein: 35, carbs: 30, fat: 16, notes: "Estimated: chicken dish (heuristic)", micronutrients: ["iron_mg": 2, "vitamin_b12_mcg": 0.5, "zinc_mg": 3])
        }
        if n.contains("pasta") || n.contains("spaghetti") {
            return MealMacroEstimate(calories: 550, protein: 18, carbs: 72, fat: 16, notes: "Estimated: pasta dish (heuristic)", micronutrients: ["iron_mg": 3, "fiber_g": 4])
        }
        if n.contains("smoothie") || n.contains("shake") {
            return MealMacroEstimate(calories: 280, protein: 15, carbs: 38, fat: 8, notes: "Estimated: smoothie (heuristic)", micronutrients: ["vitamin_c_mg": 45, "magnesium_mg": 50, "potassium_mg": 400])
        }
        return MealMacroEstimate(calories: 450, protein: 22, carbs: 45, fat: 18, notes: "Rough estimate — edit macros for accuracy (heuristic)", micronutrients: ["iron_mg": 3, "fiber_g": 4])
    }

    private static func inferIngredients(from notes: String) -> [String] {
        let n = notes.lowercased()
        var items: [String] = []
        let dict: [(String, String)] = [
            ("egg", "Eggs"), ("chicken", "Chicken"), ("salmon", "Salmon"), ("rice", "Rice"),
            ("pasta", "Pasta"), ("spinach", "Spinach"), ("tomato", "Tomato"), ("avocado", "Avocado"),
            ("bean", "Beans"), ("lentil", "Lentils"), ("yogurt", "Yogurt"), ("oats", "Oats"),
            ("banana", "Banana"), ("potato", "Potato"), ("tofu", "Tofu"), ("cheese", "Cheese"),
        ]
        for (needle, label) in dict where n.contains(needle) { items.append(label) }
        return items.isEmpty ? ["Mixed ingredients (confirm in review)"] : items
    }

    static func recipesFromPantry(pantryText: String, contextJSON: String) -> [RecipeCard] {
        let p = pantryText.lowercased()
        let ctx = contextJSON.lowercased()
        let anemia = p.contains("spinach") || p.contains("lentil") || p.contains("beef") || ctx.contains("anemia")
            || ctx.contains("ferritin")

        var out: [RecipeCard] = []

        if p.contains("egg") {
            out.append(RecipeCard(
                title: "Herb Baked Eggs & Greens",
                calories: 320, protein: 22, carbs: 12, fat: 22,
                ingredients: ["Eggs", "Spinach", "Olive oil", "Herbs"],
                steps: ["Sauté greens", "Crack in eggs", "Cover until set", "Season"],
                why: anemia
                    ? "Gentle protein plus iron-friendly greens supports anemia recovery without a heavy glycemic spike."
                    : "Complete protein with greens fits a moderate-readiness day — steady fuel without a big glucose swing.",
                imageKeyword: "eggs"
            ))
        }
        if p.contains("chicken") || p.contains("turkey") {
            out.append(RecipeCard(
                title: "Sheet-Pan Protein & Veg",
                calories: 480, protein: 42, carbs: 28, fat: 18,
                ingredients: ["Chicken", "Mixed vegetables", "Olive oil", "Spices"],
                steps: ["Cube protein", "Toss with oil and spices", "Roast 22 min at 200°C"],
                why: "High protein stabilizes glucose — helpful for PCOS-style insulin sensitivity and steady energy.",
                imageKeyword: "chicken"
            ))
        }
        if p.contains("lentil") || p.contains("bean") {
            out.append(RecipeCard(
                title: "Iron-Friendly Pulse Bowl",
                calories: 440, protein: 24, carbs: 58, fat: 12,
                ingredients: ["Lentils or beans", "Lemon", "Olive oil", "Herbs"],
                steps: ["Simmer pulses until tender", "Dress with lemon for vitamin C", "Serve warm"],
                why: anemia
                    ? "Non-heme iron plus vitamin C from lemon improves absorption — aligned with anemia care."
                    : "Fiber-forward carbs that are gentler on glucose than refined starches.",
                imageKeyword: "lentil"
            ))
        }

        if out.count < 3 {
            out.append(RecipeCard(
                title: "Pantry Stir-Fry",
                calories: 410, protein: 28, carbs: 36, fat: 16,
                ingredients: Array(Set(pantryText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(5))),
                steps: ["Chop what you have", "Stir-fry on high 6–8 min", "Finish with soy or lemon"],
                why: "Uses what’s on hand while keeping protein anchor + vegetables for recovery and glucose stability.",
                imageKeyword: "stir fry"
            ))
        }

        if out.count < 3 {
            out.append(contentsOf: RecipeCard.mockRecipes.filter { mock in !out.contains(where: { $0.title == mock.title }) })
        }

        return Array(out.prefix(3))
    }
}

// MARK: - Gemini API Request/Response Types

private struct GeminiRequest: Encodable {
    let systemInstruction: GeminiContent?
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig?

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
        case generationConfig = "generationConfig"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(contents, forKey: .contents)
        if let si = systemInstruction { try c.encode(si, forKey: .systemInstruction) }
        if let gc = generationConfig { try c.encode(gc, forKey: .generationConfig) }
    }
}

private struct GeminiContent: Encodable {
    let role: String?
    let parts: [GeminiPart]

    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let role { try c.encode(role, forKey: .role) }
        try c.encode(parts, forKey: .parts)
    }

    enum CodingKeys: String, CodingKey { case role, parts }
}

private struct GeminiPart: Encodable {
    let text: String?
    let inlineData: InlineData?

    init(text: String? = nil, inlineData: InlineData? = nil) {
        self.text = text
        self.inlineData = inlineData
    }

    struct InlineData: Encodable {
        let mimeType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let text { try c.encode(text, forKey: .text) }
        if let inlineData { try c.encode(inlineData, forKey: .inlineData) }
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

private struct GenerationConfig: Encodable {
    let responseMimeType: String?
    let temperature: Double?
    let maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case responseMimeType = "responseMimeType"
        case temperature
        case maxOutputTokens
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let r = responseMimeType { try c.encode(r, forKey: .responseMimeType) }
        if let t = temperature { try c.encode(t, forKey: .temperature) }
        if let m = maxOutputTokens { try c.encode(m, forKey: .maxOutputTokens) }
    }
}

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]
        }
        let content: Content
    }
    struct PromptFeedback: Decodable {
        let blockReason: String?
    }
    let candidates: [Candidate]?
    let promptFeedback: PromptFeedback?
}

// MARK: - Backward Compatibility Alias
typealias OpenAIService = GeminiService
typealias OpenAIError = GeminiError
