import SwiftUI

struct SettingsView: View {
    @Environment(ProfileStore.self) private var profile
    @Environment(StravaAuthService.self) private var auth
    @State private var deepSeekKeyDraft = ""
    @State private var saveError: String?

    var body: some View {
        @Bindable var profile = profile

        Form {
            Section("Heart rate (for zone calculations)") {
                Stepper("Max HR: \(Int(profile.hrMax)) bpm", value: $profile.hrMax, in: 120...220)
                Stepper("Resting HR: \(Int(profile.hrRest)) bpm", value: $profile.hrRest, in: 30...100)
            }

            Section("DeepSeek API key") {
                SecureField("sk-...", text: $deepSeekKeyDraft)
                Button("Save key") { saveKey() }
                if let saveError {
                    Text(saveError).foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button("Log out of Strava", role: .destructive) {
                    try? auth.logout()
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func saveKey() {
        do {
            try KeychainStore.save(deepSeekKeyDraft, for: .deepSeekAPIKey)
            deepSeekKeyDraft = ""
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(ProfileStore())
    .environment(StravaAuthService())
}
