import Foundation

/// Computes HR zones and derived metrics from raw Strava streams.
/// Pure — no I/O, no SwiftData. See PRD §9: this is intentionally NOT persisted;
/// it's recomputed from streams + the user's HRmax/HRrest every time the
/// activity detail screen opens.
enum HRZoneCalculator {
    struct Zone {
        let name: String
        let lowerBound: Double   // bpm
        let upperBound: Double   // bpm, .infinity for the top zone
        let secondsInZone: Double
    }

    struct Result {
        let zones: [Zone]
        let minutesAboveThreshold: Double
    }

    /// - Parameters:
    ///   - heartRates: bpm samples, one per stream sample (same cadence as `times`)
    ///   - times: seconds elapsed at each sample, same length as `heartRates`
    ///   - hrMax: user's max heart rate (from Settings)
    ///   - hrRest: user's resting heart rate (from Settings)
    ///   - threshold: bpm above which time is reported separately (e.g. a
    ///     "power-hike trigger"); pass nil to skip that calculation
    static func compute(
        heartRates: [Double],
        times: [Double],
        hrMax: Double,
        hrRest: Double,
        threshold: Double? = nil
    ) -> Result {
        precondition(heartRates.count == times.count, "streams must be same length")

        // Heart Rate Reserve (Karvonen) zone bounds — standard 5-zone split.
        let hrr = hrMax - hrRest
        let bounds: [(String, Double, Double)] = [
            ("Z1 Recovery", 0.50, 0.60),
            ("Z2 Easy", 0.60, 0.70),
            ("Z3 Tempo", 0.70, 0.80),
            ("Z4 Threshold", 0.80, 0.90),
            ("Z5 Max", 0.90, 1.5),
        ].map { name, lo, hi in
            (name, hrRest + lo * hrr, hrRest + hi * hrr)
        }

        var secondsPerZone = [Double](repeating: 0, count: bounds.count)
        var secondsAboveThreshold = 0.0

        for i in 1..<max(heartRates.count, 1) where i < heartRates.count {
            let dt = times[i] - times[i - 1]
            guard dt > 0 else { continue }
            let hr = heartRates[i]

            if let zoneIndex = bounds.firstIndex(where: { hr >= $0.1 && hr < $0.2 }) {
                secondsPerZone[zoneIndex] += dt
            } else if hr >= bounds.last!.2 {
                secondsPerZone[bounds.count - 1] += dt
            }

            if let threshold, hr > threshold {
                secondsAboveThreshold += dt
            }
        }

        let zones = zip(bounds, secondsPerZone).map { bound, seconds in
            Zone(name: bound.0, lowerBound: bound.1, upperBound: bound.2, secondsInZone: seconds)
        }

        return Result(zones: zones, minutesAboveThreshold: secondsAboveThreshold / 60)
    }
}
