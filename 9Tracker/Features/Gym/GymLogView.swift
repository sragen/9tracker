import PhotosUI
import SwiftData
import SwiftUI

/// Manual gym log entry. Weight/reps use Stepper anchored to the last logged
/// value for that exercise — see the "reduce input friction" design decision:
/// nudge from a sensible starting point, don't retype from zero.
struct GymLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymSession.date, order: .reverse) private var pastSessions: [GymSession]

    private let templates = GymTemplateStore()

    @State private var selectedTemplate: String?
    @State private var exerciseName = ""
    @State private var draftSets: [DraftSet] = [DraftSet()]

    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessingPhoto = false
    @State private var ocrReview: OCRReview?
    @State private var photoError: String?

    private struct OCRReview: Identifiable, Hashable {
        let id = UUID()
        let sets: [OCRExtractedSet]
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private struct DraftSet: Identifiable {
        let id = UUID()
        var reps: Int = 8
        var weightKg: Double = 20
    }

    var body: some View {
        Form {
            Section("Template") {
                Picker("Template", selection: $selectedTemplate) {
                    Text("Freeform").tag(String?.none)
                    ForEach(Array(templates.templates.keys.sorted()), id: \.self) { name in
                        Text(name).tag(String?.some(name))
                    }
                }
            }

            Section("Exercise") {
                if let selectedTemplate, !templates.exercises(for: selectedTemplate).isEmpty {
                    Picker("Exercise", selection: $exerciseName) {
                        Text("Choose…").tag("")
                        ForEach(templates.exercises(for: selectedTemplate), id: \.self) { Text($0).tag($0) }
                    }
                } else {
                    TextField("Exercise name", text: $exerciseName)
                }
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

            Section("From photo") {
                PhotosPicker("Import from notebook photo", selection: $photoItem, matching: .images)
                if isProcessingPhoto {
                    ProgressView("Reading photo…")
                }
                if let photoError {
                    Text(photoError).foregroundStyle(.red).font(.caption)
                }
            }

            Button("Finish", action: save)
                .disabled(exerciseName.isEmpty)
        }
        .navigationTitle("New log")
        .onAppear(perform: prefillFromLastSession)
        .onChange(of: photoItem) { _, newItem in
            Task { await processPhoto(newItem) }
        }
        .navigationDestination(item: $ocrReview) { review in
            GymPhotoReviewView(extractedSets: review.sets, onConfirm: saveFromPhoto)
        }
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
        let session = GymSession(date: .now, templateName: selectedTemplate)
        let exercise = Exercise(name: exerciseName)
        exercise.sets = draftSets.map { SetEntry(reps: $0.reps, weightKg: $0.weightKg) }
        session.exercises = [exercise]
        modelContext.insert(session)
        try? modelContext.save()
    }

    // MARK: - Photo import

    private func processPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isProcessingPhoto = true
        photoError = nil
        defer { isProcessingPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                photoError = "Couldn't load that photo."
                return
            }
            let lines = try await VisionOCRService.recognizeText(in: image)
            let sets = GymOCRParser.parse(lines)
            guard !sets.isEmpty else {
                photoError = "Couldn't find any weight × reps patterns in that photo."
                return
            }
            ocrReview = OCRReview(sets: sets)
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func saveFromPhoto(_ sets: [OCRExtractedSet]) {
        let session = GymSession(date: .now, templateName: selectedTemplate)
        let grouped = Dictionary(grouping: sets, by: \.exerciseName)
        session.exercises = grouped.map { name, sets in
            let exercise = Exercise(name: name)
            exercise.sets = sets.map { SetEntry(reps: $0.reps, weightKg: $0.weightKg) }
            return exercise
        }
        modelContext.insert(session)
        try? modelContext.save()
        ocrReview = nil
        photoItem = nil
    }
}

#Preview {
    NavigationStack {
        GymLogView()
    }
    .modelContainer(for: GymSession.self, inMemory: true)
}
