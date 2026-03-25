# Klair functional spec (implementation reference)

## Nourish — meal logging

- **Scan / Photos:** Opens camera or photo library; selected image triggers `GeminiService.analyzeMeal`, returning JSON with `mealName`, `calories`, `protein`, `carbs`, `fats` (mapped to `fat`), `ingredients`, optional `notes` / `micronutrients`.
- **Review sheet:** User confirms or edits fields before `MealEntry` is saved (`mealTitle` + macros + notes).
- **Manual entry:** Saves a meal without vision.
- **Heuristic fallback:** If the model response cannot be parsed, `HeuristicFallback.nourishMealFallback` fills a best-effort `NourishMealEstimate` from free text.

## Chef’s Pantry

- **Input:** Free-text pantry list in Fuel → **Chef** segment.
- **Generate:** `ChefRecipesService.fetchRecipes` tries, in order:
  1. HTTP `POST` to `CHEF_RECIPES_API_URL` with JSON `{ "pantry", "context" }` (expects `{ "recipes": [...] }` or a raw array).
  2. `GeminiService.generateRecipes` (same schema as recipe cards).
  3. `HeuristicFallback.recipesFromPantry` (keyword templates).
- **Cards:** Title, macros, **Why** copy tied to anemia / PCOS / readiness context JSON.

## Ask Luna

- **Context:** Profile, **14 days** Oura, **14 days** meals, energy activities, labs, symptoms, HealthKit summaries, and **energyBattery** (self-reported mood/energy + deposit/withdrawal counts and latest summaries).
- **Response shape:** **Summary**, **Insights**, **Recommendations** (1–3 numbered actions), enforced in the Luna system prompt.
- **Heuristic fallback:** On Gemini failure, `HeuristicFallback.coachFallback` uses keyword routing over the question (+ light context hints).
