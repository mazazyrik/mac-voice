import Foundation
import Security

protocol APIKeyStoring: Sendable {
    func readAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

final class CachedAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    private enum Cache {
        case unloaded
        case loaded(String?)
    }

    private let backing: any APIKeyStoring
    private let lock = NSLock()
    private var cache: Cache = .unloaded

    init(backing: any APIKeyStoring) {
        self.backing = backing
    }

    func readAPIKey() throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        if case .loaded(let key) = cache {
            return key
        }
        let key = try backing.readAPIKey()
        cache = .loaded(key)
        return key
    }

    func saveAPIKey(_ key: String) throws {
        try backing.saveAPIKey(key)
        lock.lock()
        cache = .loaded(key.trimmingCharacters(in: .whitespacesAndNewlines))
        lock.unlock()
    }

    func deleteAPIKey() throws {
        try backing.deleteAPIKey()
        lock.lock()
        cache = .loaded(nil)
        lock.unlock()
    }
}

struct KeychainStore: APIKeyStoring {
    private let service = "com.mazazyrik.MacVoice"
    private let account = "openai-api-key"

    func readAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unhandled(status)
        }
        return String(data: data, encoding: .utf8)
    }

    func saveAPIKey(_ key: String) throws {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw AppError.missingAPIKey }
        let data = Data(normalized.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandled(updateStatus)
        }
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        }
    }
}
