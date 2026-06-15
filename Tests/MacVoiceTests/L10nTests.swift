import Foundation
import XCTest
@testable import MacVoice

final class L10nTests: XCTestCase {
    override func tearDown() {
        L10n.userDefaults = .standard
        super.tearDown()
    }

    func testRussianBundle() throws {
        let suite = "MacVoiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("ru", forKey: "preferredLanguage")
        L10n.userDefaults = defaults

        XCTAssertEqual(L10n.text("action.back"), "Назад")
        XCTAssertEqual(L10n.text("onboarding.language.title"), "Выберите язык")
    }

    func testEnglishBundle() throws {
        let suite = "MacVoiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("en", forKey: "preferredLanguage")
        L10n.userDefaults = defaults

        XCTAssertEqual(L10n.text("action.back"), "Back")
        XCTAssertEqual(L10n.text("onboarding.language.title"), "Choose your language")
    }

    func testLocalizationKeyParity() throws {
        let enKeys = try localizationKeys(for: "en")
        let ruKeys = try localizationKeys(for: "ru")
        XCTAssertEqual(enKeys, ruKeys)
    }

    private func localizationKeys(for language: String) throws -> Set<String> {
#if SWIFT_PACKAGE
        let base = Bundle.module
#else
        let base = Bundle.main
#endif
        let path = try XCTUnwrap(base.path(forResource: language, ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let stringsPath = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings"))
        let dictionary = try XCTUnwrap(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
        return Set(dictionary.keys)
    }
}
