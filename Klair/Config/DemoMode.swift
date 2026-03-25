import Foundation

/// When `true`, Klair skips Oura/Gemini network calls and uses local sample data + canned AI responses.
/// When `false`, Klair uses live Google Gemini AI for coach chat, meal vision, and dashboard insights,
/// while still using seeded Oura/health data from MockData.
enum DemoMode {
    static var useMockRemoteServices: Bool = false

    /// Force-populate 14-day high-impact trends for a polished demo.
    /// Toggle from the Profile screen at runtime.
    static var presentationMode: Bool = false
}
