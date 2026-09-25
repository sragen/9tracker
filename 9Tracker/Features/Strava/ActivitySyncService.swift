import Foundation
import Observation
import SwiftData

/// Polling sync: pulls new Strava activities and upserts them into SwiftData.
/// Called on app foreground / pull-to-refresh — no webhook (see PRD §5: LOCKED, polling only).
@Observable
@MainActor
final class ActivitySyncService {
    private(set) var isSyncing = false
    private(set) var lastSyncError: Error?
    private(set) var lastSyncDate: Date?

    private let client: StravaAPIClient
    private let modelContext: ModelContext

    init(client: StravaAPIClient, modelContext: ModelContext) {
        self.client = client
        self.modelContext = modelContext
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let dtos = try await client.fetchActivities(after: lastSyncDate)
            for dto in dtos {
                upsert(dto)
            }
            try modelContext.save()
            lastSyncDate = Date()
            lastSyncError = nil
        } catch {
            lastSyncError = error
        }
    }

    /// Insert or update by stravaID — dedupe key, since re-syncing may re-fetch
    /// activities already stored (Strava's `after` filter isn't exact-once).
    private func upsert(_ dto: StravaActivityDTO) {
        let stravaID = dto.id
        let descriptor = FetchDescriptor<Activity>(
            predicate: #Predicate { $0.stravaID == stravaID }
        )
        let existing = try? modelContext.fetch(descriptor).first

        let paceSecPerKm = dto.distance > 0
            ? Double(dto.movingTime) / (dto.distance / 1000)
            : 0

        if let existing {
            existing.type = dto.type
            existing.distanceMeters = dto.distance
            existing.durationSeconds = Double(dto.movingTime)
            existing.averagePaceSecPerKm = paceSecPerKm
            existing.elevationGainMeters = dto.totalElevationGain
            existing.averageHeartRate = dto.averageHeartrate
            existing.maxHeartRate = dto.maxHeartrate
            existing.polyline = dto.map?.summaryPolyline
        } else {
            let activity = Activity(
                stravaID: dto.id,
                type: dto.type,
                distanceMeters: dto.distance,
                durationSeconds: Double(dto.movingTime),
                averagePaceSecPerKm: paceSecPerKm,
                elevationGainMeters: dto.totalElevationGain,
                averageHeartRate: dto.averageHeartrate,
                maxHeartRate: dto.maxHeartrate,
                date: dto.startDate,
                polyline: dto.map?.summaryPolyline
            )
            modelContext.insert(activity)
        }
    }
}
