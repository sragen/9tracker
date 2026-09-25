import Testing
@testable import NineTracker

@Suite("HRZoneCalculator")
struct HRZoneCalculatorTests {
    @Test("all time in Z2 when HR stays flat in that band")
    func flatZ2() {
        // hrMax 190, hrRest 50 -> hrr 140. Z2 = 60-70% = 134-148 bpm.
        let times: [Double] = [0, 60, 120, 180]
        let heartRates: [Double] = [140, 140, 140, 140]

        let result = HRZoneCalculator.compute(
            heartRates: heartRates, times: times, hrMax: 190, hrRest: 50
        )

        let z2 = result.zones.first { $0.name == "Z2 Easy" }!
        #expect(z2.secondsInZone == 180)
        for zone in result.zones where zone.name != "Z2 Easy" {
            #expect(zone.secondsInZone == 0)
        }
    }

    @Test("minutesAboveThreshold counts only samples over the trigger")
    func threshold() {
        let times: [Double] = [0, 60, 120]
        let heartRates: [Double] = [140, 155, 140] // one sample above 150

        let result = HRZoneCalculator.compute(
            heartRates: heartRates, times: times, hrMax: 190, hrRest: 50, threshold: 150
        )

        #expect(result.minutesAboveThreshold == 1.0) // 60s segment between sample 1->2
    }
}
