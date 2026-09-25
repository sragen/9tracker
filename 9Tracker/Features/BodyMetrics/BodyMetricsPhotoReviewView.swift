import SwiftUI

/// Photo-import review for InBody scans. Same confirm-before-save pattern
/// as GymPhotoReviewView / RecoveryPhotoReviewView.
struct BodyMetricsPhotoReviewView: View {
    let extracted: OCRExtractedBodyMetrics
    var onConfirm: (OCRExtractedBodyMetrics) -> Void

    var body: some View {
        List {
            LabeledContent("Weight", value: String(format: "%.1f kg", extracted.weightKg))
            LabeledContent("Body fat", value: String(format: "%.1f %%", extracted.bodyFatPercent))
            LabeledContent("Muscle mass", value: String(format: "%.1f kg", extracted.muscleMassKg))
            Button("Save") { onConfirm(extracted) }
        }
        .navigationTitle("Photo review")
    }
}

struct OCRExtractedBodyMetrics {
    var weightKg: Double
    var bodyFatPercent: Double
    var muscleMassKg: Double
}
