import Carbon
import XCTest
@testable import MacVoice

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaultsAndPersistence() throws {
        let suite = "MacVoiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.autoPaste)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.historyEnabled)
        XCTAssertEqual(settings.hotKey, .defaultValue)
        XCTAssertEqual(settings.preferredLanguage, "system")

        settings.autoPaste = false
        settings.customVocabulary = "Codex, SwiftUI"
        settings.preferredLanguage = "ru"
        settings.hotKey = HotKey(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | shiftKey))

        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.autoPaste)
        XCTAssertEqual(restored.customVocabulary, "Codex, SwiftUI")
        XCTAssertEqual(restored.preferredLanguage, "ru")
        XCTAssertEqual(restored.hotKey.displayValue, "⇧⌘R")
    }
}
