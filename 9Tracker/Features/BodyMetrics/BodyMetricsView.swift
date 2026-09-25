import PhotosUI
import SwiftData
import SwiftUI

/// Monthly InBody entry. All fields use Steppers anchored to last month's
/// scan — a real reading can jump further than gym/recovery values, so a
/// "tap to type exact value" fallback exists alongside the stepper.
struct BodyMetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyMetrics.date, order: .reverse) private var pastScans: [BodyMetrics]

    @State private var weightKg: Double = 70
    @State private var bodyFatPercent: Double = 18
    @State private var muscleMassKg: Double = 32
    @State private var visceralFat: Int = 7
    @State private var bmrKcal: Double = 1600

    @State private var photoItem: PhotosPickerItem?
    @State private var isProcessingPhoto = false
    @State private var ocrReview: OCRReview?
    @State private var photoError: String?

    private struct OCRReview: Identifiable, Hashable {
        let id = UUID()
        let extracted: OCRExtractedBodyMetrics
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    var body: some View {
        Form {
            Stepper("Weight: \(weightKg, specifier: "%.1f") kg", value: $weightKg, in: 30...200, step: 0.1)
            Stepper("Body fat: \(bodyFatPercent, specifier: "%.1f") %", value: $bodyFatPercent, in: 3...50, step: 0.1)
            Stepper("Muscle mass: \(muscleMassKg, specifier: "%.1f") kg", value: $muscleMassKg, in: 10...100, step: 0.1)
            Stepper("Visceral fat: \(visceralFat)", value: $visceralFat, in: 1...30)
            Stepper("BMR: \(bmrKcal, specifier: "%.0f") kcal", value: $bmrKcal, in: 800...4000, step: 5)

            Section("From photo") {
                PhotosPicker("Import from InBody scan photo", selection: $photoItem, matching: .images)
                if isProcessingPhoto {
                    ProgressView("Reading scan…")
                }
                if let photoError {
                    Text(photoError).foregroundStyle(.red).font(.caption)
                }
            }

            Button("Save", action: save)
        }
        .navigationTitle("InBody scan")
        .onAppear(perform: prefillFromLastScan)
        .onChange(of: photoItem) { _, newItem in
            Task { await processPhoto(newItem) }
        }
        .navigationDestination(item: $ocrReview) { review in
            BodyMetricsPhotoReviewView(extracted: review.extracted, onConfirm: saveFromPhoto)
        }
    }

    private func prefillFromLastScan() {
        guard let last = pastScans.first else { return }
        weightKg = last.weightKg ?? weightKg
        bodyFatPercent = last.bodyFatPercent ?? bodyFatPercent
        muscleMassKg = last.skeletalMuscleMassKg ?? muscleMassKg
        visceralFat = last.visceralFatLevel ?? visceralFat
        bmrKcal = last.basalMetabolicRateKcal ?? bmrKcal
    }

    private func save() {
        let scan = BodyMetrics(
            date: .now,
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercent,
            skeletalMuscleMassKg: muscleMassKg,
            visceralFatLevel: visceralFat,
            basalMetabolicRateKcal: bmrKcal
        )
        modelContext.insert(scan)
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
            guard let extracted = BodyMetricsOCRParser.parse(lines) else {
                photoError = "Couldn't find a weight reading in that photo."
                return
            }
            ocrReview = OCRReview(extracted: extracted)
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func saveFromPhoto(_ extracted: OCRExtractedBodyMetrics) {
        let scan = BodyMetrics(
            date: .now,
            weightKg: extracted.weightKg,
            bodyFatPercent: extracted.bodyFatPercent,
            skeletalMuscleMassKg: extracted.muscleMassKg
        )
        modelContext.insert(scan)
        try? modelContext.save()
        ocrReview = nil
        photoItem = nil
    }
}

#Preview {
    NavigationStack {
        BodyMetricsView()
    }
    .modelContainer(for: BodyMetrics.self, inMemory: true)
}
