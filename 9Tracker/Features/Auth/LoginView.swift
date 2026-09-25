import SwiftUI

struct LoginView: View {
    @Environment(StravaAuthService.self) private var auth
    @State private var errorMessage: String?
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 24) {
            Text("9Tracker")
                .font(.largeTitle.bold())

            Text("Connect your Strava account to sync runs and trail runs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await login() }
            } label: {
                if isLoggingIn {
                    ProgressView()
                } else {
                    Text("Log in with Strava")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoggingIn)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    private func login() async {
        isLoggingIn = true
        defer { isLoggingIn = false }
        do {
            try await auth.login()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environment(StravaAuthService())
}
