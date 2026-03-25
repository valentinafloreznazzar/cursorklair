# Klair — competitive feature matrix

**Purpose:** Compare Klair’s planned and implemented scope (see repo `README.md` and the Klair MVP plan) to adjacent products. Use this for positioning, demo narrative, and judge Q&A.

**Legend**

| Symbol | Meaning |
|--------|--------|
| **Yes** | First-class, native or primary flow in the product (per public positioning). |
| **Partial** | Via partner app, limited geography, subset of metrics, or add-on. |
| **No** | Not a stated focus, or clearly out of scope. |
| **?** | Not clear from public materials; treat as unknown. |

**Disclaimer:** Rows reflect **marketing sites, App Store copy, and support docs** as of early 2025. Products ship fast—verify before any external claims.

---

## Matrix: integrations & data

| Capability | Klair | Oura app | Wild.AI | Aster | Meealthy | Go Go Gaia | Viya | Vora | Pivot | Typical AI food app* |
|------------|:----:|:--------:|:-------:|:-----:|:--------:|:----------:|:----:|:-----:|:-----:|:--------------------:|
| **Oura readiness / sleep / HRV** (direct API or official integration) | Yes (API) | Yes (device) | Partial (integration) | ? | ? | Partial (integration) | ? | Partial (many integrations) | No (WHOOP) | No |
| **Oura daily activity rollup** | Yes (Phase 3 / implemented in service) | Yes | ? | ? | ? | ? | ? | ? | ? | No |
| **HealthKit workouts** | Yes | ? | Partial (via Apple Health) | ? | ? | Partial | ? | Partial | ? | Partial (common) |
| **HealthKit menstrual / cycle logs** | Yes | No | Partial (via Apple Health) | ? | Yes (positioning) | Yes | ? | ? | ? | No |
| **AI photo → calories / macros** | Yes | Yes (Meals) | ? | Yes | Yes | Partial (MFP etc.) | Yes | Yes | Yes | Yes |
| **AI micronutrient estimates** | Yes (Phase 3) | Partial / limited (per Oura Meals breakdown) | ? | ? | ? | ? | ? | Partial (marketing: many nutrients) | ? | Partial (some apps) |
| **User-owned local store (SwiftData)** | Yes | No (cloud product) | No | No | No | No | No | No | No | No |

\*Representative: photo-first trackers (e.g. Bite AI, Caloringo, Photo Calorie class)—not one specific vendor.

---

## Matrix: product experience

| Capability | Klair | Oura app | Wild.AI | Aster | Meealthy | Go Go Gaia | Viya | Vora | Pivot | Typical AI food app* |
|------------|:----:|:--------:|:-------:|:-----:|:--------:|:----------:|:----:|:-----:|:-----:|:--------------------:|
| **Single-app tab shell: recovery + food + coach** | Yes | Partial (Meals + scores; not same as Klair coach) | Partial | Yes | Yes | Yes | Yes | Yes | Partial | No (food-only) |
| **Explicit “signals” narrative (e.g. late eating + HRV vs baseline)** | Yes (plan) | No (limited correlation story in public docs) | Partial | ? | ? | Partial (patterns) | ? | ? | Partial | No |
| **7-day charts: sleep vs late-night calories** | Yes (plan) | ? | ? | ? | ? | ? | ? | ? | ? | No |
| **Natural-language coach with assembled context** (meals, wearables, profile, HK) | Yes | Partial (AI features vary) | Partial | Yes | ? | ? | Yes | Yes | Yes | Partial (chat w/o full biometrics) |
| **Training / plans / programs** | No | Partial | Yes | ? | ? | Partial | Partial | Partial | Yes | No |
| **Medical diagnosis / hormone blood claims** | No (by design) | No | No | No | No | No | No | No | No | No |

---

## How to talk about Klair in one sentence

**Klair** is a **small, native iOS co-pilot** that combines **Oura API data**, **HealthKit** (workouts + cycle logs the user already tracks), and **GPT-4o meal vision**, then surfaces **recovery-adjacent patterns** (e.g. meal timing vs HRV) and **Ask AI** answers built from **transparent, user-local context**—without claiming to measure cortisol or diagnose conditions.

---

## Suggested judge follow-ups (honest limits)

- **vs. Oura:** They own the ring UX and now Meals; Klair differentiates on **cross-source context** (HK + your schema + coach prompt) and **hackathon-clear** estimate disclaimers.
- **vs. Wild.AI / Gaia:** They lead on **cycle-synced training and community**; Klair is narrower: **readiness + nutrition timing + chat** over **your** stored history.
- **vs. Vora / Pivot / Cora:** Strong **integration breadth** and subscriptions; Klair is **opinionated MVP** and **on-device SwiftData** for demo clarity.
- **vs. AI food apps:** They win on **logging UX scale**; Klair wins when the story is **food + Oura + cycle/workout context together**.

---

## References (starting points)

- [Oura — Meals](https://support.ouraring.com/hc/en-us/articles/40264659421843-Meals)  
- [Oura — App integrations](https://support.ouraring.com/hc/en-us/sections/9721508785171-App-Integrations)  
- [Wild.AI](https://www.wild.ai/) · [Aster](https://www.aster.fit/) · [Meealthy](https://meealthy.com/meealthyapp) · [Go Go Gaia](https://www.go-go-gaia.com/) · [Viya](https://www.getviya.com/) · [Vora](https://askvora.com/) · [Pivot](https://thepivotapp.ai/)
