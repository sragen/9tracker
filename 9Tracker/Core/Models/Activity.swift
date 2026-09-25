import Foundation
import SwiftData

/// A run/trail-run activity synced from Strava.
/// Source of truth: Strava API. Never edited manually in-app.
@Model
final class Activity {
    @Attribute(.unique) var stravaID: Int
    var type: String              // "Run", "TrailRun", etc. (Strava activity type)
    var distanceMeters: Double
    var durationSeconds: Double
    var averagePaceSecPerKm: Double
    var elevationGainMeters: Double
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var date: Date
    var polyline: String?         // encoded polyline, for map rendering

    init(
        stravaID: Int,
        type: String,
        distanceMeters: Double,
        durationSeconds: Double,
        averagePaceSecPerKm: Double,
        elevationGainMeters: Double,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        date: Date,
        polyline: String? = nil
    ) {
        self.stravaID = stravaID
        self.type = type
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.averagePaceSecPerKm = averagePaceSecPerKm
        self.elevationGainMeters = elevationGainMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.date = date
        self.polyline = polyline
    }
}
