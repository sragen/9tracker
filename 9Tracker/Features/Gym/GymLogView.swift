import SwiftData
import SwiftUI

/// Manual gym log entry. Weight/reps use Stepper anchored to the last logged
/// value for that exercise — see the "reduce input friction" design decision:
/// nudge from a sensible starting point, don't retype from zero.
struct GymLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymSession.date, order: .reverse) private var pastSessions: [GymSession]

    @State private var exerciseName = ""
    @State private var draftSets: [DraftSet] = [DraftSet()]

    private struct DraftSet: Identifiable {
        let id = UUID()
        var reps: Int = 8
        var weightKg: Double = 20
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Exercise name", text: $exerciseName)
                    // TODO: replace with GymTemplateStore-backed picker (favorite exercises)
            }

            Section("Sets") {
                ForEach($draftSets) { $set in
                    HStack {
                        Stepper("Reps: \(set.reps)", value: $set.reps, in: 1...30)
                        Stepper("Kg: \(set.weightKg, specifier: "%.1f")", value: $set.weightKg, in: 0...300, step: 2.5)
                    }
                }
                Button("+ Add set") {
                    draftSets.append(DraftSet(reps: lastReps ?? 8, weightKg: lastWeight ?? 20))
                }
            }

            Button("Finish", action: save)
                .disabled(exerciseName.isEmpty)
        }
        .navigationTitle("New log")
        .onAppear(perform: prefillFromLastSession)
    }

    private var lastExercise: Exercise? {
        pastSessions.first?.exercises.first { $0.name == exerciseName }
    }

    private var lastReps: Int? { lastExercise?.sets.last?.reps }
    private var lastWeight: Double? { lastExercise?.sets.last?.weightKg }

    private func prefillFromLastSession() {
        guard let last = lastExercise?.sets.last else { return }
        draftSets = [DraftSet(reps: last.reps, weightKg: last.weightKg)]
    }

    private func save() {
        let session = GymSession(date: .now)
        let exercise = Exercise(name: exerciseName)
        exercise.sets = draftSets.map { SetEntry(reps: $0.reps, weightKg: $0.weightKg) }
        session.exercises = [exercise]
        modelContext.insert(session)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        GymLogView()
    }
    .modelContainer(for: GymSession.self, inMemory: true)
}
