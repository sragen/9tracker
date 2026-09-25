import Foundation
import SwiftData

/// A single logged gym session (manual entry or OCR-reviewed photo import).
@Model
final class GymSession {
    var date: Date
    var templateName: String?     // e.g. "Push A" — nil if freeform
    @Relationship(deleteRule: .cascade, inverse: \Exercise.session)
    var exercises: [Exercise] = []

    init(date: Date, templateName: String? = nil) {
        self.date = date
        self.templateName = templateName
    }
}

@Model
final class Exercise {
    var name: String
    var session: GymSession?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
    var sets: [SetEntry] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class SetEntry {
    var reps: Int
    var weightKg: Double
    var exercise: Exercise?

    init(reps: Int, weightKg: Double) {
        self.reps = reps
        self.weightKg = weightKg
    }
}
