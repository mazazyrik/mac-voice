import XCTest
@testable import MacVoice

final class CachedAPIKeyStoreTests: XCTestCase {
    func testReadsBackingStoreOnlyOnce() throws {
        let backing = CountingAPIKeyStore(key: "secret")
        let store = CachedAPIKeyStore(backing: backing)

        XCTAssertEqual(try store.readAPIKey(), "secret")
        XCTAssertEqual(try store.readAPIKey(), "secret")
        XCTAssertEqual(backing.readCount, 1)
    }

    func testSaveAndDeleteUpdateMemoryCache() throws {
        let backing = CountingAPIKeyStore(key: nil)
        let store = CachedAPIKeyStore(backing: backing)

        try store.saveAPIKey(" updated-key ")
        XCTAssertEqual(try store.readAPIKey(), "updated-key")
        XCTAssertEqual(backing.readCount, 0)

        try store.deleteAPIKey()
        XCTAssertNil(try store.readAPIKey())
        XCTAssertEqual(backing.readCount, 0)
    }
}

private final class CountingAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    private(set) var readCount = 0
    private var key: String?

    init(key: String?) {
        self.key = key
    }

    func readAPIKey() throws -> String? {
        readCount += 1
        return key
    }

    func saveAPIKey(_ key: String) throws {
        self.key = key
    }

    func deleteAPIKey() throws {
        key = nil
    }
}
