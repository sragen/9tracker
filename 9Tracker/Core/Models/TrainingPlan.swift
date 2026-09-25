import Foundation
import SwiftData

/// AI-generated training plan, saved from an AI Coach conversation.
@Model
final class TrainingPlan {
    var weekStart: Date
    var goal: String              // "race" | "general"
    @Relationship(deleteRule: .cascade, inverse: \PlannedSession.plan)
    var sessions: [PlannedSession] = []

    init(weekStart: Date, goal: String) {
        self.weekStart = weekStart
        self.goal = goal
    }
}

@Model
final class PlannedSession {
    var date: Date
    var summary: String            // e.g. "Z2 easy 8km" or "Push A"
    var plan: TrainingPlan?

    init(date: Date, summary: String) {
        self.date = date
        self.summary = summary
    }
}
