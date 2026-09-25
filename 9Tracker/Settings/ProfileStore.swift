import Foundation
import Observation

/// Small user-settable profile values used elsewhere (HRZoneCalculator needs
/// hrMax/hrRest; see rancangan teknis §9 catatan — these are NOT new
/// data-model fields, just plain settings, backed by UserDefaults).
@Observable
final class ProfileStore {
    var hrMax: Double {
        didSet { UserDefaults.standard.set(hrMax, forKey: "profile.hrMax") }
    }
    var hrRest: Double {
        didSet { UserDefaults.standard.set(hrRest, forKey: "profile.hrRest") }
    }

    init() {
        let defaults = UserDefaults.standard
        hrMax = defaults.object(forKey: "profile.hrMax") as? Double ?? 188
        hrRest = defaults.object(forKey: "profile.hrRest") as? Double ?? 52
    }
}
