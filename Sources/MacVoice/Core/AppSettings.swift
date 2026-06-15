import AppKit
import Carbon
import Combine
import Foundation
import ServiceManagement

struct HotKey: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultValue = HotKey(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )

    var displayValue: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(KeyCodeName.name(for: keyCode))
        return parts.joined()
    }
}

enum KeyCodeName {
    private static let names: [UInt32: String] = [
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z"
    ]

    static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let autoPaste = "autoPaste"
        static let soundEnabled = "soundEnabled"
        static let historyEnabled = "historyEnabled"
        static let customVocabulary = "customVocabulary"
        static let hotKey = "hotKey"
        static let onboardingCompleted = "onboardingCompleted"
        static let preferredLanguage = "preferredLanguage"
    }

    private let defaults: UserDefaults

    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) } }
    @Published var historyEnabled: Bool { didSet { defaults.set(historyEnabled, forKey: Keys.historyEnabled) } }
    @Published var customVocabulary: String { didSet { defaults.set(customVocabulary, forKey: Keys.customVocabulary) } }
    @Published var hotKey: HotKey {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: Keys.hotKey)
            }
        }
    }
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }
    @Published var preferredLanguage: String {
        didSet { defaults.set(preferredLanguage, forKey: Keys.preferredLanguage) }
    }
    @Published private(set) var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.autoPaste: true,
            Keys.soundEnabled: true,
            Keys.historyEnabled: true,
            Keys.customVocabulary: "",
            Keys.onboardingCompleted: false,
            Keys.preferredLanguage: "system"
        ])
        autoPaste = defaults.bool(forKey: Keys.autoPaste)
        soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        historyEnabled = defaults.bool(forKey: Keys.historyEnabled)
        customVocabulary = defaults.string(forKey: Keys.customVocabulary) ?? ""
        onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        preferredLanguage = defaults.string(forKey: Keys.preferredLanguage) ?? "system"
        if
            let data = defaults.data(forKey: Keys.hotKey),
            let decoded = try? JSONDecoder().decode(HotKey.self, from: data)
        {
            hotKey = decoded
        } else {
            hotKey = .defaultValue
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
