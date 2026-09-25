import Foundation
import Observation

/// Favorite exercise templates (e.g. "Push A", "Pull A") for fast gym-log entry.
/// Backed by UserDefaults for now — this is a small, user-editable list, not
/// data worth a SwiftData model. Revisit only if templates grow relational
/// (e.g. per-exercise target sets/reps history).
@Observable
final class GymTemplateStore {
    private(set) var templates: [String: [String]] = [
        "Push A": ["Bench press", "Incline dumbbell press", "Overhead press", "Cable lateral raise", "Triceps pushdown"],
        "Pull A": ["Deadlift", "Pull-up", "Barbell row", "Face pull", "Barbell curl"],
        "Legs A": ["Squat", "Romanian deadlift", "Leg press", "Leg curl", "Calf raise"],
    ]

    func exercises(for template: String) -> [String] {
        templates[template] ?? []
    }
}
