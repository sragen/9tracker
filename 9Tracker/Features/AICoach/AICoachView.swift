import SwiftData
import SwiftUI

/// AI Coach chat. Always shows the "not a substitute for a coach or doctor"
/// disclaimer (see PRD §4.7) — present but not alarmist.
struct AICoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activities: [Activity]
    @Query private var gymSessions: [GymSession]
    @Query private var recoveryLogs: [RecoveryLog]
    @Query private var bodyMetrics: [BodyMetrics]

    @State private var messages: [DeepSeekClient.Message] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var saveConfirmation: String?

    private let client = DeepSeekClient()

    var body: some View {
        VStack(spacing: 0) {
            Text("AI-generated from your logged data. Useful for planning, not a substitute for a coach or doctor.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)

            List {
                ForEach(Array(messages.enumerated()).filter { $0.element.role != "system" }, id: \.offset) { index, message in
                    VStack(alignment: message.role == "user" ? .trailing : .leading) {
                        Text(message.content)
                            .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                        if message.role == "assistant", let goal = RaceGoalParser.parse(message.content) {
                            Button("Save as race goal") { saveRaceGoal(goal) }
                                .font(.caption)
                        }
                    }
                }
                if let saveConfirmation {
                    Text(saveConfirmation).font(.caption).foregroundStyle(.green)
                }
            }

            HStack {
                TextField("Ask the coach…", text: $draft)
                Button("Send", action: send)
                    .disabled(draft.isEmpty || isSending)
            }
            .padding()
        }
        .navigationTitle("Coach")
    }

    private func send() {
        let userMessage = DeepSeekClient.Message(role: "user", content: draft)
        draft = ""
        messages.append(userMessage)
        isSending = true

        Task {
            defer { isSending = false }
            do {
                let context = ContextBuilder.build(
                    activities: activities,
                    gymSessions: gymSessions,
                    recoveryLogs: recoveryLogs,
                    bodyMetrics: bodyMetrics
                )
                let systemMessage = DeepSeekClient.Message(
                    role: "system",
                    content: "You are a running/gym coach. Use this athlete data:\n\(context)"
                )
                let reply = try await client.send(messages: [systemMessage] + messages)
                messages.append(DeepSeekClient.Message(role: "assistant", content: reply))
            } catch {
                messages.append(DeepSeekClient.Message(role: "assistant", content: "Error: \(error.localizedDescription)"))
            }
        }
    }

    private func saveRaceGoal(_ goal: RaceGoalParser.ParsedGoal) {
        let raceGoal = RaceGoal(
            raceDate: goal.raceDate ?? Date().addingTimeInterval(90 * 86400),
            distanceMeters: goal.distanceMeters,
            targetTimeSeconds: goal.targetTimeSeconds
        )
        modelContext.insert(raceGoal)
        try? modelContext.save()
        saveConfirmation = "Saved: \(String(format: "%.0fkm", goal.distanceMeters / 1000)) race goal."
    }
}

/// Fase 1 heuristic: extracts "<distance>K/km" and "target H:MM" patterns from
/// AI coach replies, so the user can save a pacing plan without retyping it.
/// Does not attempt to parse a real date — user can edit the saved goal later.
enum RaceGoalParser {
    struct ParsedGoal {
        let distanceMeters: Double
        let targetTimeSeconds: Double
        let raceDate: Date?
    }

    static func parse(_ text: String) -> ParsedGoal? {
        let distancePattern = #/(\d+\.?\d*)\s*(?:km|K\b)/#
        let timePattern = #/[Tt]arget\s*(\d+):(\d+)/#

        guard let distanceMatch = try? distancePattern.firstMatch(in: text),
              let distance = Double(distanceMatch.1) else { return nil }
        guard let timeMatch = try? timePattern.firstMatch(in: text),
              let hours = Double(timeMatch.1), let minutes = Double(timeMatch.2) else { return nil }

        return ParsedGoal(
            distanceMeters: distance * 1000,
            targetTimeSeconds: hours * 3600 + minutes * 60,
            raceDate: nil
        )
    }
}

#Preview {
    NavigationStack {
        AICoachView()
    }
    .modelContainer(for: [Activity.self, GymSession.self, RecoveryLog.self, BodyMetrics.self, RaceGoal.self], inMemory: true)
}
