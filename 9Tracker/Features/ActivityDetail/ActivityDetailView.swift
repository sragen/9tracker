import Charts
import SwiftUI

struct ActivityDetailView: View {
    let activity: Activity

    @Environment(StravaAuthService.self) private var auth
    @Environment(ProfileStore.self) private var profile
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
            } else if !streams.isEmpty {
                if let elevationPoints = elevationSeries() {
                    Section("Elevation") {
                        Chart(elevationPoints, id: \.distanceKm) { point in
                            AreaMark(x: .value("km", point.distanceKm), y: .value("m", point.altitude))
                        }
                        .frame(height: 120)
                    }
                }

                if let zoneResult = hrZoneResult() {
                    Section("Heart rate zones") {
                        ForEach(zoneResult.zones, id: \.name) { zone in
                            HStack {
                                Text(zone.name)
                                Spacer()
                                Text(formattedDuration(zone.secondsInZone))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if zoneResult.minutesAboveThreshold > 0 {
                            Text(String(format: "%.0f min above your power-hike trigger", zoneResult.minutesAboveThreshold))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(activity.type)
        .task {
            await loadStreams()
        }
    }

    // MARK: - Stream helpers

    private struct ElevationPoint {
        let distanceKm: Double
        let altitude: Double
    }

    private func elevationSeries() -> [ElevationPoint]? {
        guard let altitude = streams.first(where: { $0.type == "altitude" })?.data,
              let distance = streams.first(where: { $0.type == "distance" })?.data,
              altitude.count == distance.count else { return nil }
        return zip(distance, altitude).map { ElevationPoint(distanceKm: $0 / 1000, altitude: $1) }
    }

    private func hrZoneResult() -> HRZoneCalculator.Result? {
        guard let heartRates = streams.first(where: { $0.type == "heartrate" })?.data,
              let times = streams.first(where: { $0.type == "time" })?.data,
              heartRates.count == times.count, !heartRates.isEmpty else { return nil }
        return HRZoneCalculator.compute(
            heartRates: heartRates,
            times: times,
            hrMax: profile.hrMax,
            hrRest: profile.hrRest,
            threshold: 150
        )
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
