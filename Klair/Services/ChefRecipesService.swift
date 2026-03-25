import Foundation

/// Tries the remote chef-recipes API, then Gemini, then local pantry heuristics.
enum ChefRecipesService {
    private static let session: URLSession = .shared

    static func fetchRecipes(pantryText: String, contextJSON: String) async -> [RecipeCard] {
        let trimmed = pantryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let urlString = ProcessInfo.processInfo.environment["CHEF_RECIPES_API_URL"],
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            if let remote = try? await postChefAPI(url: url, pantry: trimmed, contextJSON: contextJSON),
               remote.count >= 1 {
                return Array(remote.prefix(3))
            }
        }

        let gemini = GeminiService()
        if let ai = try? await gemini.generateRecipes(pantryItems: trimmed, contextJSON: contextJSON),
           !ai.isEmpty {
            return Array(ai.prefix(3))
        }

        return HeuristicFallback.recipesFromPantry(pantryText: trimmed, contextJSON: contextJSON)
    }

    private static func postChefAPI(url: URL, pantry: String, contextJSON: String) async throws -> [RecipeCard] {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["pantry": pantry, "context": contextJSON]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = root["recipes"] as? [[String: Any]] {
            return try decodeRecipeArray(arr)
        }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return try decodeRecipeArray(arr)
        }
        let decoded = try JSONDecoder().decode([RecipeCard].self, from: data)
        return decoded
    }

    private static func decodeRecipeArray(_ arr: [[String: Any]]) throws -> [RecipeCard] {
        let data = try JSONSerialization.data(withJSONObject: arr)
        return try JSONDecoder().decode([RecipeCard].self, from: data)
    }
}
