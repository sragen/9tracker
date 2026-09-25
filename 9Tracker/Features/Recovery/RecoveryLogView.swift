import SwiftData
import SwiftUI

/// Manual recovery entry. Sleep/deep-sleep use Picker Wheels (hours+minutes,
/// like a timer); score/HR/HRV use Sliders and Steppers anchored to the
/// 7-night average or last night's value — see input-friction design decision.
struct RecoveryLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryLog.date, order: .reverse) private var pastLogs: [RecoveryLog]

    @State private var sleepScore: Double = 79
    @State private var sleepHours = 6
    @State private var sleepMinutes = 50
    @State private var deepSleepHours = 1
    @State private var deepSleepMinutes = 12
    @State private var overnightHR: Double = 55
    @State private var hrv: Double = 45

    var body: some View {
        Form {
            Section("Sleep score") {
                Slider(value: $sleepScore, in: 0...100, step: 1)
                Text("\(Int(sleepScore)) / 100")
            }

            Section("Sleep duration") {
                HStack {
                    Picker("Hours", selection: $sleepHours) {
                        ForEach(0..<12) { Text("\($0) h").tag($0) }
                    }
                    Picker("Minutes", selection: $sleepMinutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
            }

            Section("Deep sleep") {
                HStack {
                    Picker("Hours", selection: $deepSleepHours) {
                        ForEach(0..<6) { Text("\($0) h").tag($0) }
                    }
                    Picker("Minutes", selection: $deepSleepMinutes) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
            }

            Section("Heart") {
                Stepper("Overnight HR: \(Int(overnightHR)) bpm", value: $overnightHR, in: 30...120)
                Stepper("HRV: \(Int(hrv)) ms", value: $hrv, in: 10...150)
            }

            Button("Save", action: save)
        }
        .navigationTitle("New log")
        .onAppear(perform: prefillFromLastNight)
    }

    private func prefillFromLastNight() {
        guard let last = pastLogs.first else { return }
        if let score = last.sleepScore { sleepScore = Double(score) }
        if let hr = last.overnightHeartRate { overnightHR = hr }
        if let hrvValue = last.hrv { hrv = hrvValue }
    }

    private func save() {
        let log = RecoveryLog(
            date: .now,
            sleepScore: Int(sleepScore),
            sleepDurationSeconds: Double(sleepHours * 3600 + sleepMinutes * 60),
            deepSleepDurationSeconds: Double(deepSleepHours * 3600 + deepSleepMinutes * 60),
            overnightHeartRate: overnightHR,
            hrv: hrv
        )
        modelContext.insert(log)
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        RecoveryLogView()
    }
    .modelContainer(for: RecoveryLog.self, inMemory: true)
}
