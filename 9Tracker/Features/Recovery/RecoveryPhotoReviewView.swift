import SwiftUI

/// Photo-import review for recovery logs (Huawei Health screenshot OCR).
/// Same confirm-before-save pattern as GymPhotoReviewView.
struct RecoveryPhotoReviewView: View {
    let extracted: OCRExtractedRecovery
    var onConfirm: (OCRExtractedRecovery) -> Void

    var body: some View {
        List {
            LabeledContent("Sleep score", value: "\(extracted.sleepScore)")
            LabeledContent("Sleep duration", value: "\(extracted.sleepMinutes) min")
            LabeledContent("Overnight HR", value: "\(extracted.overnightHR) bpm")
            LabeledContent("HRV", value: "\(extracted.hrv) ms")
            Button("Save") { onConfirm(extracted) }
        }
        .navigationTitle("Screenshot review")
    }
}

struct OCRExtractedRecovery {
    var sleepScore: Int
    var sleepMinutes: Int
    var overnightHR: Int
    var hrv: Int
}
