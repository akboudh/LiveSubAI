import Foundation
import Security

final class SettingsManager {
    private let service = "com.livesubai.app"
    private let deepgramAccount = "deepgram-api-key"
    private let deepLAccount = "deepl-api-key"

    func deepgramAPIKey() throws -> String? {
        try apiKey(account: deepgramAccount)
    }

    func setDeepgramAPIKey(_ key: String) throws {
        try setAPIKey(key, account: deepgramAccount)
    }

    func deepLAPIKey() throws -> String? {
        try apiKey(account: deepLAccount)
    }

    func setDeepLAPIKey(_ key: String) throws {
        try setAPIKey(key, account: deepLAccount)
    }

    private func apiKey(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw keychainError(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func setAPIKey(_ key: String, account: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let data = Data(trimmed.utf8)
        let query = baseQuery(account: account)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw keychainError(addStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw keychainError(status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(_ status: OSStatus) -> NSError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        return NSError(domain: "LiveSubAI.Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
    }
}
