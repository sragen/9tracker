import Foundation

/// Assembles the DeepSeek context from local SwiftData: recent detail +
/// older summary, so token usage doesn't grow unbounded as history piles up.
/// See PRD §8 risk note: "jangan kirim seluruh histori mentah tiap chat".
///
/// ponytail: fixed 7-day-detail / 90-day-summary window. Upgrade to an
/// adaptive/sliding window only if the coach starts losing useful context —
/// don't build that complexity before it's proven needed.
enum ContextBuilder {
    static func build(
        activities: [Activity],
        gymSessions: [GymSession],
        recoveryLogs: [RecoveryLog],
        bodyMetrics: [BodyMetrics]
    ) -> String {
        let now = Date()
        let detailCutoff = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let summaryCutoff = Calendar.current.date(byAdding: .day, value: -90, to: now)!

        var sections: [String] = []

        let recentActivities = activities.filter { $0.date >= detailCutoff }
        let olderActivities = activities.filter { $0.date >= summaryCutoff && $0.date < detailCutoff }
        sections.append(activitySection(recent: recentActivities, older: olderActivities))

        let recentGym = gymSessions.filter { $0.date >= detailCutoff }
        sections.append("Gym sessions (last 7 days): \(recentGym.count) sessions logged.")

        let recentRecovery = recoveryLogs.filter { $0.date >= detailCutoff }
        sections.append(recoverySection(recentRecovery))

        if let latestBody = bodyMetrics.first {
            sections.append("Latest InBody scan (\(latestBody.date.formatted(date: .abbreviated, time: .omitted))): "
                + "weight \(latestBody.weightKg.map { String(format: "%.1f kg", $0) } ?? "n/a"), "
                + "body fat \(latestBody.bodyFatPercent.map { String(format: "%.1f%%", $0) } ?? "n/a")")
        }

        return sections.joined(separator: "\n\n")
    }

    private static func activitySection(recent: [Activity], older: [Activity]) -> String {
        var lines = ["RUNNING — last 7 days (\(recent.count) activities):"]
        for a in recent {
            lines.append("- \(a.date.formatted(date: .abbreviated, time: .omitted)): \(a.type), "
                + String(format: "%.1fkm, %.0fm D+", a.distanceMeters / 1000, a.elevationGainMeters))
        }
        if !older.isEmpty {
            let totalKm = older.reduce(0.0) { $0 + $1.distanceMeters } / 1000
            lines.append("Prior 8-90 days: \(older.count) activities, \(String(format: "%.0f", totalKm)) km total.")
        }
        return lines.joined(separator: "\n")
    }

    private static func recoverySection(_ logs: [RecoveryLog]) -> String {
        guard !logs.isEmpty else { return "RECOVERY: no recent logs." }
        let avgHRV = logs.compactMap(\.hrv).reduce(0, +) / Double(max(logs.compactMap(\.hrv).count, 1))
        return "RECOVERY — last 7 nights: avg HRV \(String(format: "%.0f", avgHRV)) ms."
    }
}
