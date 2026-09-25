import Foundation

/// Minimal Keychain wrapper for secrets that must never touch SwiftData/UserDefaults:
/// Strava OAuth tokens and the DeepSeek API key (see PRD §6: StravaAuth, DeepSeekConfig).
///
/// Accessible only after first unlock, this device only — never synced, never backed up
/// to iCloud Keychain, since a stolen backup would leak both.
enum KeychainStore {
    enum Key: String {
        case stravaAccessToken = "id.sragen.ninetracker.strava.accessToken"
        case stravaRefreshToken = "id.sragen.ninetracker.strava.refreshToken"
        case stravaExpiresAt = "id.sragen.ninetracker.strava.expiresAt"
        case deepSeekAPIKey = "id.sragen.ninetracker.deepseek.apiKey"
    }

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case unexpectedData
    }

    static func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        let identity: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
        ]

        // Delete any existing item first — SecItemAdd fails on duplicates.
        SecItemDelete(identity as CFDictionary)

        var add = identity
        add[kSecValueData] = data
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func read(_ key: Key) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func delete(_ key: Key) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
