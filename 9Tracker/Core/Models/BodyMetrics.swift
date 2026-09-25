import Foundation
import SwiftData

/// Monthly InBody scan, manual or OCR-reviewed.
@Model
final class BodyMetrics {
    var date: Date
    var weightKg: Double?
    var bodyFatPercent: Double?
    var skeletalMuscleMassKg: Double?
    var visceralFatLevel: Int?
    var basalMetabolicRateKcal: Double?
    @Attribute(.externalStorage) var sourceImage: Data?

    init(
        date: Date,
        weightKg: Double? = nil,
        bodyFatPercent: Double? = nil,
        skeletalMuscleMassKg: Double? = nil,
        visceralFatLevel: Int? = nil,
        basalMetabolicRateKcal: Double? = nil,
        sourceImage: Data? = nil
    ) {
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.skeletalMuscleMassKg = skeletalMuscleMassKg
        self.visceralFatLevel = visceralFatLevel
        self.basalMetabolicRateKcal = basalMetabolicRateKcal
        self.sourceImage = sourceImage
    }
}
