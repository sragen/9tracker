import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity

    @Environment(StravaAuthService.self) private var auth
    @State private var streams: [StravaStreamDTO] = []
    @State private var isLoadingStreams = false
    @State private var streamsError: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Distance", value: String(format: "%.2f km", activity.distanceMeters / 1000))
                LabeledContent("Moving time", value: formattedDuration(activity.durationSeconds))
                LabeledContent("Avg pace", value: formattedPace(activity.averagePaceSecPerKm))
                LabeledContent("Elev gain", value: String(format: "%.0f m", activity.elevationGainMeters))
                if let avgHR = activity.averageHeartRate, let maxHR = activity.maxHeartRate {
                    LabeledContent("Avg / max HR", value: "\(Int(avgHR)) / \(Int(maxHR))")
                }
            }

            if isLoadingStreams {
                ProgressView("Loading elevation & HR zones…")
            } else if let streamsError {
                Text(streamsError).foregroundStyle(.red)
            }
            // TODO: HR zone breakdown + elevation chart render here once
            // streams are loaded — computed via HRZoneCalculator.compute(...),
            // never persisted (see PRD §9).
        }
        .navigationTitle(activity.type)
        .task {
            await loadStreams()
        }
    }

    private func loadStreams() async {
        isLoadingStreams = true
        defer { isLoadingStreams = false }
        do {
            let client = StravaAPIClient(auth: auth)
            streams = try await client.fetchStreams(activityID: activity.stravaID)
        } catch {
            streamsError = error.localizedDescription
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "-"
    }

    private func formattedPace(_ secPerKm: Double) -> String {
        let minutes = Int(secPerKm) / 60
        let seconds = Int(secPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
