import Foundation

enum L10n {
    nonisolated(unsafe) static var userDefaults: UserDefaults = .standard

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale.current, arguments: arguments)
    }

    private static var bundle: Bundle {
#if SWIFT_PACKAGE
        localizedBundle(from: .module)
#else
        localizedBundle(from: .main)
#endif
    }

    private static func localizedBundle(from base: Bundle) -> Bundle {
        let language = userDefaults.string(forKey: "preferredLanguage") ?? "system"
        guard language != "system", let path = base.path(forResource: language, ofType: "lproj") else {
            return base
        }
        return Bundle(path: path) ?? base
    }
}
