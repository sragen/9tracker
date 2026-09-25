import SwiftData
import SwiftUI

@main
struct NineTrackerApp: App {
    let modelContainer: ModelContainer
    @State private var auth = StravaAuthService()
    @State private var profile = ProfileStore()

    init() {
        let schema = Schema([
            Activity.self,
            GymSession.self, Exercise.self, SetEntry.self,
            RecoveryLog.self,
            BodyMetrics.self,
            TrainingPlan.self, PlannedSession.self,
            RaceGoal.self,
        ])
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(profile)
                .environment(ActivitySyncService(
                    client: StravaAPIClient(auth: auth),
                    modelContext: modelContainer.mainContext
                ))
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @Environment(StravaAuthService.self) private var auth

    var body: some View {
        if auth.isAuthenticated {
            TabView {
                DashboardView()
                    .tabItem { Label("Summary", systemImage: "chart.bar") }

                NavigationStack { GymLogView() }
                    .tabItem { Label("Log", systemImage: "plus.circle") }

                NavigationStack { AICoachView() }
                    .tabItem { Label("Coach", systemImage: "message") }

                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        } else {
            LoginView()
        }
    }
}
