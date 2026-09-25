import Foundation
import SwiftData

/// Manual or OCR-reviewed recovery entry (sleep/HRV), one per night.
@Model
final class RecoveryLog {
    var date: Date
    var sleepScore: Int?
    var sleepDurationSeconds: Double?
    var deepSleepDurationSeconds: Double?
    var overnightHeartRate: Double?
    var hrv: Double?
    @Attribute(.externalStorage) var sourceImage: Data?   // set when logged via OCR

    init(
        date: Date,
        sleepScore: Int? = nil,
        sleepDurationSeconds: Double? = nil,
        deepSleepDurationSeconds: Double? = nil,
        overnightHeartRate: Double? = nil,
        hrv: Double? = nil,
        sourceImage: Data? = nil
    ) {
        self.date = date
        self.sleepScore = sleepScore
        self.sleepDurationSeconds = sleepDurationSeconds
        self.deepSleepDurationSeconds = deepSleepDurationSeconds
        self.overnightHeartRate = overnightHeartRate
        self.hrv = hrv
        self.sourceImage = sourceImage
    }
}
