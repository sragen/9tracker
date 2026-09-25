import Foundation

/// Talks to the Strava REST API. Every request goes through
/// `StravaAuthService.validAccessToken()` first — never cache a bearer token here.
struct StravaAPIClient {
    let auth: StravaAuthService

    private let baseURL = URL(string: "https://www.strava.com/api/v3")!

    func fetchActivities(after: Date?) async throws -> [StravaActivityDTO] {
        let token = try await auth.validAccessToken()
        var components = URLComponents(url: baseURL.appendingPathComponent("athlete/activities"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "per_page", value: "50")]
        if let after {
            items.append(URLQueryItem(name: "after", value: String(Int(after.timeIntervalSince1970))))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await APIClient.send(request, decodeAs: [StravaActivityDTO].self)
    }

    /// Fetches elevation/heartrate/distance/time streams for one activity.
    /// Called lazily from ActivityDetailView, not during sync — see StravaModels.swift.
    func fetchStreams(activityID: Int) async throws -> [StravaStreamDTO] {
        let token = try await auth.validAccessToken()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("activities/\(activityID)/streams"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "keys", value: "time,distance,altitude,heartrate"),
            URLQueryItem(name: "key_by_type", value: "false"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await APIClient.send(request, decodeAs: [StravaStreamDTO].self)
    }
}
