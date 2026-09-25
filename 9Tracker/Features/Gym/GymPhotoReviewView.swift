import SwiftUI

/// Photo-import review for gym logs. Extracted OCR fields are never
/// auto-saved — user must confirm each low-confidence value first
/// (see PRD §4.3: "OCR does not auto-trust").
struct GymPhotoReviewView: View {
    let extractedSets: [OCRExtractedSet]
    var onConfirm: ([OCRExtractedSet]) -> Void

    var body: some View {
        List {
            ForEach(extractedSets) { set in
                HStack {
                    Text(set.exerciseName)
                    Spacer()
                    Text("\(set.weightKg, specifier: "%.1f") kg × \(set.reps)")
                        .foregroundStyle(set.isLowConfidence ? .orange : .primary)
                }
            }
            Button("Save") { onConfirm(extractedSets) }
        }
        .navigationTitle("Photo review")
    }
}

/// One OCR-extracted set awaiting user confirmation.
struct OCRExtractedSet: Identifiable {
    let id = UUID()
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var isLowConfidence: Bool
}
