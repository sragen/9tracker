import Foundation
import SwiftData

/// A race pacing goal, saved from an AI Coach conversation.
@Model
final class RaceGoal {
    var raceDate: Date
    var distanceMeters: Double
    var targetTimeSeconds: Double
    var elevationProfileNote: String?   // freeform note until GPX import exists

    init(
        raceDate: Date,
        distanceMeters: Double,
        targetTimeSeconds: Double,
        elevationProfileNote: String? = nil
    ) {
        self.raceDate = raceDate
        self.distanceMeters = distanceMeters
        self.targetTimeSeconds = targetTimeSeconds
        self.elevationProfileNote = elevationProfileNote
    }
}
