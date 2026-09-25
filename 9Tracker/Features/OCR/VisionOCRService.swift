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

/// Fase 1 heuristic: scans recognized lines for "label: number" pairs and
/// matches against known Huawei Health screenshot labels. Same caveat as
/// GymOCRParser — real accuracy work happens against real screenshots.
enum RecoveryOCRParser {
    static func parse(_ lines: [VisionOCRService.RecognizedLine]) -> OCRExtractedRecovery? {
        let numberPattern = #/(\d+)/#
        func firstNumber(near keyword: String) -> Int? {
            guard let line = lines.first(where: { $0.text.localizedCaseInsensitiveContains(keyword) }),
                  let match = try? numberPattern.firstMatch(in: line.text) else { return nil }
            return Int(match.1)
        }

        guard let score = firstNumber(near: "score") else { return nil }
        return OCRExtractedRecovery(
            sleepScore: score,
            sleepMinutes: firstNumber(near: "sleep") ?? 0,
            overnightHR: firstNumber(near: "hr") ?? firstNumber(near: "heart") ?? 0,
            hrv: firstNumber(near: "hrv") ?? 0
        )
    }
}

/// Fase 1 heuristic for InBody printout scans — same "label: number" approach.
enum BodyMetricsOCRParser {
    static func parse(_ lines: [VisionOCRService.RecognizedLine]) -> OCRExtractedBodyMetrics? {
        let decimalPattern = #/(\d+\.?\d*)/#
        func firstDecimal(near keyword: String) -> Double? {
            guard let line = lines.first(where: { $0.text.localizedCaseInsensitiveContains(keyword) }),
                  let match = try? decimalPattern.firstMatch(in: line.text) else { return nil }
            return Double(match.1)
        }

        guard let weight = firstDecimal(near: "weight") else { return nil }
        return OCRExtractedBodyMetrics(
            weightKg: weight,
            bodyFatPercent: firstDecimal(near: "fat") ?? 0,
            muscleMassKg: firstDecimal(near: "muscle") ?? 0
        )
    }
}
