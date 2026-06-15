import XCTest

@MainActor
final class MacVoiceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingLanguageStepLaunchesFirst() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.otherElements["onboarding-language-step"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["onboarding-welcome-title"].exists)
    }

    func testOnboardingLanguageSwitchUpdatesText() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.otherElements["onboarding-language-step"].waitForExistence(timeout: 5))

        app.buttons["onboarding-continue"].click()
        XCTAssertTrue(app.staticTexts["onboarding-welcome-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Speak. Paste. Done."].exists)

        app.buttons["onboarding-back"].click()
        app.segmentedControls["onboarding-language-picker"].buttons.element(boundBy: 0).click()
        app.buttons["onboarding-continue"].click()
        XCTAssertTrue(app.staticTexts["Скажите. Вставьте. Готово."].waitForExistence(timeout: 5))
    }

    func testKeychainStepIsReachable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-reset",
            "--ui-testing-has-api-key",
            "-AppleLanguages",
            "(en)"
        ]
        app.launch()
        XCTAssertTrue(app.otherElements["onboarding-language-step"].waitForExistence(timeout: 5))
        app.buttons["onboarding-continue"].click()
        app.buttons["onboarding-continue"].click()
        app.buttons["onboarding-continue"].click()
        XCTAssertTrue(app.otherElements["onboarding-keychain-step"].waitForExistence(timeout: 5))
    }

    func testAutoPasteSettingPersists() {
        var app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset", "--ui-testing-onboarded", "-AppleLanguages", "(en)"]
        app.launch()
        XCTAssertTrue(app.buttons["open-settings"].waitForExistence(timeout: 5))
        app.buttons["open-settings"].click()

        let toggle = app.switches["auto-paste-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String == "1" {
            toggle.click()
        }
        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing-onboarded", "-AppleLanguages", "(en)"]
        app.launch()
        app.buttons["open-settings"].click()
        let restoredToggle = app.switches["auto-paste-toggle"]
        XCTAssertTrue(restoredToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredToggle.value as? String, "0")
    }
}
