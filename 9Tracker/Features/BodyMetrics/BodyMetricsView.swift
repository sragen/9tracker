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

    var body: some View {
        Form {
            Stepper("Weight: \(weightKg, specifier: "%.1f") kg", value: $weightKg, in: 30...200, step: 0.1)
            Stepper("Body fat: \(bodyFatPercent, specifier: "%.1f") %", value: $bodyFatPercent, in: 3...50, step: 0.1)
            Stepper("Muscle mass: \(muscleMassKg, specifier: "%.1f") kg", value: $muscleMassKg, in: 10...100, step: 0.1)
            Stepper("Visceral fat: \(visceralFat)", value: $visceralFat, in: 1...30)
            Stepper("BMR: \(bmrKcal, specifier: "%.0f") kcal", value: $bmrKcal, in: 800...4000, step: 5)

            Button("Save", action: save)
        }
        .navigationTitle("InBody scan")
        .onAppear(perform: prefillFromLastScan)
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
}

#Preview {
    NavigationStack {
        BodyMetricsView()
    }
    .modelContainer(for: BodyMetrics.self, inMemory: true)
}
