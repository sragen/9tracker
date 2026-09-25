import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(ActivitySyncService.self) private var syncService
    @Query(sort: \Activity.date, order: .reverse) private var activities: [Activity]

    var body: some View {
        NavigationStack {
            List {
                if let error = syncService.lastSyncError {
                    Section {
                        Text("Sync failed: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Running") {
                    if let weekly = weeklyDistanceKm {
                        LabeledContent("This week", value: String(format: "%.1f km", weekly))
                    }
                    ForEach(activities.prefix(10)) { activity in
                        NavigationLink(value: activity) {
                            ActivityRow(activity: activity)
                        }
                    }
                }
            }
            .navigationTitle("Summary")
            .navigationDestination(for: Activity.self) { activity in
                ActivityDetailView(activity: activity)
            }
            .refreshable {
                await syncService.sync()
            }
            .task {
                await syncService.sync()
            }
        }
    }

    private var weeklyDistanceKm: Double? {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let recent = activities.filter { $0.date >= weekAgo }
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0) { $0 + $1.distanceMeters } / 1000
    }
}

private struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading) {
            Text(activity.type)
                .font(.headline)
            Text(String(format: "%.1f km · %@", activity.distanceMeters / 1000, activity.date.formatted(date: .abbreviated, time: .omitted)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Activity.self, inMemory: true)
        .environment(ActivitySyncService(
            client: StravaAPIClient(auth: StravaAuthService()),
            modelContext: ModelContext(try! ModelContainer(for: Activity.self))
        ))
}
