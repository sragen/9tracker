import PhotosUI
import SwiftData
import SwiftUI

/// Manual recovery entry. Sleep/deep-sleep use Picker Wheels (hours+minutes,
/// like a timer); score/HR/HRV use Sliders and Steppers anchored to the
/// 7-night average or last night's value — see input-friction design decision.
struct RecoveryLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryLog.date, order: .reverse) private var pastLogs: [RecoveryLog]

    @State private var sleepScore: Double = 79
    @State private var sleepHours = 6
    @State private var sleepMinutes = 50
    @State private var deepSleepHours = 1
    @State private var deepSleepMinutes = 12
    @State private var overnightHR: Double = 55
    @State private var hrv: Double = 45

    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessingPhoto = false
    @State private var ocrReview: OCRReview?
    @State private var photoError: String?

    private struct OCRReview: Identifiable, Hashable {
        let id = UUID()
        let extracted: OCRExtractedRecovery
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var body: some View {
        Form {
            Section("Sleep score") {
                Slider(value: $sleepScore, in: 0...100, step: 1)
                Text("\(Int(sleepScore)) / 100")
            }

            Section("Sleep duration") {
                HStack {
                    Picker("Hours", selection: $sleepHours) {
                        ForEach(0..<12) { Text("\($0) h").tag($0) }
                    }
                    Picker("Minutes", selection: $sleepMinutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
            }

            Section("Deep sleep") {
                HStack {
                    Picker("Hours", selection: $deepSleepHours) {
                        ForEach(0..<6) { Text("\($0) h").tag($0) }
                    }
                    Picker("Minutes", selection: $deepSleepMinutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
            }

            Section("Heart") {
                Stepper("Overnight HR: \(Int(overnightHR)) bpm", value: $overnightHR, in: 30...120)
                Stepper("HRV: \(Int(hrv)) ms", value: $hrv, in: 10...150)
            }

            Section("From screenshot") {
                PhotosPicker("Import from Huawei Health screenshot", selection: $photoItem, matching: .images)
                if isProcessingPhoto {
                    ProgressView("Reading screenshot…")
                }
                if let photoError {
                    Text(photoError).foregroundStyle(.red).font(.caption)
                }
            }

            Button("Save", action: save)
        }
        .navigationTitle("New log")
        .onAppear(perform: prefillFromLastNight)
        .onChange(of: photoItem) { _, newItem in
            Task { await processPhoto(newItem) }
        }
        .navigationDestination(item: $ocrReview) { review in
            RecoveryPhotoReviewView(extracted: review.extracted, onConfirm: saveFromPhoto)
        }
    }

    private func prefillFromLastNight() {
        guard let last = pastLogs.first else { return }
        if let score = last.sleepScore { sleepScore = Double(score) }
        if let hr = last.overnightHeartRate { overnightHR = hr }
        if let hrvValue = last.hrv { hrv = hrvValue }
    }

    private func save() {
        let log = RecoveryLog(
            date: .now,
            sleepScore: Int(sleepScore),
            sleepDurationSeconds: Double(sleepHours * 3600 + sleepMinutes * 60),
            deepSleepDurationSeconds: Double(deepSleepHours * 3600 + deepSleepMinutes * 60),
            overnightHeartRate: overnightHR,
            hrv: hrv
        )
        modelContext.insert(log)
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
            guard let extracted = RecoveryOCRParser.parse(lines) else {
                photoError = "Couldn't find a sleep score in that screenshot."
                return
            }
            ocrReview = OCRReview(extracted: extracted)
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func saveFromPhoto(_ extracted: OCRExtractedRecovery) {
        let log = RecoveryLog(
            date: .now,
            sleepScore: extracted.sleepScore,
            sleepDurationSeconds: Double(extracted.sleepMinutes * 60),
            overnightHeartRate: Double(extracted.overnightHR),
            hrv: Double(extracted.hrv)
        )
        modelContext.insert(log)
        try? modelContext.save()
        ocrReview = nil
        photoItem = nil
    }
}

#Preview {
    NavigationStack {
        RecoveryLogView()
    }
    .modelContainer(for: RecoveryLog.self, inMemory: true)
}
