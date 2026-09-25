import SwiftData
import SwiftUI

/// AI Coach chat. Always shows the "not a substitute for a coach or doctor"
/// disclaimer (see PRD §4.7) — present but not alarmist.
struct AICoachView: View {
    @Query private var activities: [Activity]
    @Query private var gymSessions: [GymSession]
    @Query private var recoveryLogs: [RecoveryLog]
    @Query private var bodyMetrics: [BodyMetrics]

    @State private var messages: [DeepSeekClient.Message] = []
    @State private var draft = ""
    @State private var isSending = false

    private let client = DeepSeekClient()

    var body: some View {
        VStack(spacing: 0) {
            Text("AI-generated from your logged data. Useful for planning, not a substitute for a coach or doctor.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)

            List(messages.filter { $0.role != "system" }, id: \.content) { message in
                Text(message.content)
                    .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
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
}

#Preview {
    NavigationStack {
        AICoachView()
    }
    .modelContainer(for: [Activity.self, GymSession.self, RecoveryLog.self, BodyMetrics.self], inMemory: true)
}
