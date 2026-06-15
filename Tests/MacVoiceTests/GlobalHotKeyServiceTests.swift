import Carbon
import XCTest
@testable import MacVoice

@MainActor
final class GlobalHotKeyServiceTests: XCTestCase {
    func testDuplicateRegistrationReportsConflict() throws {
        let first = GlobalHotKeyService()
        let second = GlobalHotKeyService()
        let uncommonHotKey = HotKey(
            keyCode: UInt32(kVK_F18),
            modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey)
        )

        try first.register(uncommonHotKey)
        XCTAssertThrowsError(try second.register(uncommonHotKey)) { error in
            XCTAssertEqual(error as? AppError, .hotKeyConflict)
        }
    }
}
