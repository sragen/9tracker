import UIKit
import Vision

/// On-device OCR, shared by Gym/Recovery/BodyMetrics photo-import flows.
/// Uses the modern iOS 18+ Vision API (RecognizeTextRequest + async/await) —
/// see PRD §4.3: extraction feeds a review screen, it never writes to
/// SwiftData directly.
enum VisionOCRService {
    struct RecognizedLine {
        let text: String
        let confidence: Float
    }

    static func recognizeText(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // numeric-heavy text (weights, reps, scores)

        let results = try await request.perform(on: cgImage)

        return results.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedLine(text: candidate.string, confidence: candidate.confidence)
        }
    }
}

// MARK: - Parsing heuristics (fase 1, per-category — see rancangan teknis §3.4:
// "bagian PALING custom/rawan", not a generic classifier)

enum GymOCRParser {
    /// Very rough first pass: looks for "<weight> x <reps>" or "<weight> × <reps>" patterns.
    /// Real accuracy work happens once we have real notebook photos to test against.
    static func parse(_ lines: [VisionOCRService.RecognizedLine]) -> [OCRExtractedSet] {
        let pattern = #/(\d+\.?\d*)\s*[x×]\s*(\d+)/#
        var results: [OCRExtractedSet] = []
        var currentExercise = "Unknown"

        for line in lines {
            if let match = try? pattern.firstMatch(in: line.text) {
                let weight = Double(match.1) ?? 0
                let reps = Int(match.2) ?? 0
                results.append(OCRExtractedSet(
                    exerciseName: currentExercise,
                    weightKg: weight,
                    reps: reps,
                    isLowConfidence: line.confidence < 0.6
                ))
            } else if !line.text.isEmpty {
                currentExercise = line.text
            }
        }
        return results
    }
}
