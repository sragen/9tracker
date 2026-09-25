import Foundation

/// Decodes Strava's `SummaryActivity` shape — only the fields 9Tracker needs.
/// https://developers.strava.com/docs/reference/#api-Activities-getLoggedInAthleteActivities
struct StravaActivityDTO: Decodable {
    let id: Int
    let type: String
    let distance: Double            // meters
    let movingTime: Int             // seconds
    let totalElevationGain: Double  // meters
    let startDate: Date
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let map: StravaMap?

    enum CodingKeys: String, CodingKey {
        case id, type, distance
        case movingTime = "moving_time"
        case totalElevationGain = "total_elevation_gain"
        case startDate = "start_date"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
        case map
    }

    struct StravaMap: Decodable {
        let summaryPolyline: String?
        enum CodingKeys: String, CodingKey {
            case summaryPolyline = "summary_polyline"
        }
    }
}

/// Decodes a single stream from GET /activities/{id}/streams — used lazily
/// by ActivityDetailView, never during bulk sync (see PRD §9: streams are
/// fetched on-demand to stay under Strava's rate limit).
struct StravaStreamDTO: Decodable {
    let type: String
    let data: [Double]
}
