import SwiftUI

/// Segmented switcher between the three manual-log categories, matching the
/// "Gym / Recovery / Body" tab row in the design mock (surfaces 3/4/5).
struct LogHubView: View {
    private enum Category: String, CaseIterable, Identifiable {
        case gym = "Gym"
        case recovery = "Recovery"
        case body = "Body"
        var id: String { rawValue }
    }

    @State private var category: Category = .gym

    var body: some View {
        VStack(spacing: 0) {
            Picker("Category", selection: $category) {
                ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            switch category {
            case .gym: GymLogView()
            case .recovery: RecoveryLogView()
            case .body: BodyMetricsView()
            }
        }
        .navigationTitle("New log")
    }
}

#Preview {
    NavigationStack {
        LogHubView()
    }
    .modelContainer(for: [GymSession.self, RecoveryLog.self, BodyMetrics.self], inMemory: true)
}
