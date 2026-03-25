# Klair (iOS)

SwiftUI + SwiftData health co-pilot: Oura summaries, meal logging with GPT-4o vision, HealthKit (workouts + cycle logs), and a Klair coach chat.

**For judges on iPhone:** ask the team for their **TestFlight** link — that’s the full app without Xcode. Team setup: **[TESTFLIGHT-JUDGES.md](./TESTFLIGHT-JUDGES.md)**.  
**For Mac + Simulator:** you only need **Xcode** (Mac App Store). Follow **[QUICKSTART.md](./QUICKSTART.md)**.

## Demo / mock mode (default)

`DemoMode.useMockRemoteServices` in `Config/DemoMode.swift` is **`true` by default**. That means:

- SwiftData loads a **week of sample** Oura, activity, and meals on first launch (when the store is empty).
- **Fuel** and **Ask** use **canned responses** (with a short delay) instead of OpenAI.
- **Oura refresh** does not call the network; it confirms demo data.
- **Health** lines on the dashboard show **sample** cycle/workout text if Health is empty.

Set `useMockRemoteServices` to **`false`** and configure keys when you want real APIs.

## Open in Xcode

1. Install [Xcode](https://developer.apple.com/xcode/) (iOS 17+ SDK).
2. From this folder, regenerate the project if you add files:
   ```bash
   xcodegen generate
   ```
3. Open `Klair.xcodeproj`, select your team under **Signing & Capabilities**, then run on a simulator or device.

## Secrets

- **Oura:** set `personalAccessToken` in `Services/OuraAPIService.swift` or move it to an `xcconfig` / scheme environment variable. The toolbar refresh pulls `daily_readiness`, `daily_sleep`, and `daily_activity` for the last ~14 days (replaces stored Oura rows when data exists).
- **OpenAI:** set the `OPENAI_API_KEY` environment variable on the Klair scheme, or replace the placeholder in `Services/OpenAIService.swift`.

## Permissions

- Camera and photo library (meal capture).
- HealthKit read for workouts and menstrual flow (optional; Klair works without authorization).

## App icon

`Assets.xcassets/AppIcon` includes a **1024×1024** starter `AppIcon.png` (moon motif). Replace it before App Store submission if you want a custom brand mark.

## Hackathon note

The **repository root** is deployed on Vercel as the **public project page** for Klair (iOS-first copy, links to this folder, plus `/api/gemini` as a small web demo). See root [`DEPLOY.md`](../DEPLOY.md) and [`SUBMISSION.md`](../SUBMISSION.md).
