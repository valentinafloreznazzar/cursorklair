import Foundation

enum OuraAPIError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case decoding(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Oura URL."
        case .httpStatus(let c): return "Oura API returned status \(c)."
        case .decoding: return "Could not read Oura response."
        case .noData: return "No Oura data for that range."
        }
    }
}

/// Fetches Oura Cloud API v2 collections. Replace `personalAccessToken` with a real PAT for live sync.
final class OuraAPIService: Sendable {
    private let baseURL = URL(string: "https://api.ouraring.com/v2/usercollection/")!
    /// Placeholder — use Xcode scheme environment variable or xcconfig in production.
    private let personalAccessToken = "YOUR_OURA_PERSONAL_ACCESS_TOKEN"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private func authorizedRequest(path: String, start: String, end: String) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        else { throw OuraAPIError.invalidURL }
        components.queryItems = [
            URLQueryItem(name: "start_date", value: start),
            URLQueryItem(name: "end_date", value: end),
        ]
        guard let url = components.url else { throw OuraAPIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(personalAccessToken)", forHTTPHeaderField: "Authorization")
        return req
    }

    func fetchMergedDailyMetrics(startDate: Date, endDate: Date) async throws -> [OuraMetrics] {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let start = fmt.string(from: Calendar.current.startOfDay(for: startDate))
        let end = fmt.string(from: Calendar.current.startOfDay(for: endDate))

        async let readiness = fetchDailyReadiness(start: start, end: end)
        async let sleep = fetchDailySleep(start: start, end: end)

        let rItems = try await readiness
        let sItems = try await sleep

        struct DayMerge {
            var readiness: Int?
            var sleepScore: Int?
            var hrv: Double?
        }
        var byDay: [String: DayMerge] = [:]

        for item in rItems {
            var m = byDay[item.day] ?? DayMerge()
            m.readiness = item.score
            byDay[item.day] = m
        }
        for item in sItems {
            var m = byDay[item.day] ?? DayMerge()
            m.sleepScore = item.score
            m.hrv = item.averageHrv
            byDay[item.day] = m
        }

        let sortedDays = byDay.keys.sorted()
        return sortedDays.compactMap { day in
            guard let parts = byDay[day], let d = Self.parseDay(day) else { return nil }
            return OuraMetrics(
                readinessScore: parts.readiness ?? 0,
                sleepScore: parts.sleepScore ?? 0,
                hrv: parts.hrv ?? 0,
                date: d,
                readinessContributorsJSON: nil
            )
        }
    }

    func fetchActivityDays(startDate: Date, endDate: Date) async throws -> [OuraActivityDay] {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let start = fmt.string(from: Calendar.current.startOfDay(for: startDate))
        let end = fmt.string(from: Calendar.current.startOfDay(for: endDate))
        let items = try await fetchDailyActivity(start: start, end: end)
        return items.compactMap { item in
            guard let d = Self.parseDay(item.day) else { return nil }
            return OuraActivityDay(
                date: d,
                steps: item.steps ?? 0,
                activeCalories: item.activeCalories ?? 0,
                equivalentWalkingDistanceMeters: item.equivalentWalkingDistance ?? 0
            )
        }
    }

    // MARK: - DTOs (subset of Oura v2 JSON)

    private struct ListResponse<T: Decodable>: Decodable {
        let data: [T]
        let nextToken: String?
    }

    private struct ReadinessItem: Decodable {
        let day: String
        let score: Int?
    }

    private struct SleepItem: Decodable {
        let day: String
        let score: Int?
        let averageHrv: Double?
    }

    private struct ActivityItem: Decodable {
        let day: String
        let steps: Int?
        let activeCalories: Double?
        let equivalentWalkingDistance: Double?
    }

    private func fetchDailyReadiness(start: String, end: String) async throws -> [ReadinessItem] {
        let req = try authorizedRequest(path: "daily_readiness", start: start, end: end)
        return try await decodeList(req, as: ReadinessItem.self)
    }

    private func fetchDailySleep(start: String, end: String) async throws -> [SleepItem] {
        let req = try authorizedRequest(path: "daily_sleep", start: start, end: end)
        return try await decodeList(req, as: SleepItem.self)
    }

    private func fetchDailyActivity(start: String, end: String) async throws -> [ActivityItem] {
        let req = try authorizedRequest(path: "daily_activity", start: start, end: end)
        return try await decodeList(req, as: ActivityItem.self)
    }

    private func decodeList<T: Decodable>(_ request: URLRequest, as: T.Type) async throws -> [T] {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OuraAPIError.httpStatus(-1) }
        guard (200...299).contains(http.statusCode) else { throw OuraAPIError.httpStatus(http.statusCode) }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(ListResponse<T>.self, from: data)
            return decoded.data
        } catch {
            throw OuraAPIError.decoding(error)
        }
    }

    private static func parseDay(_ day: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: day)
    }
}
