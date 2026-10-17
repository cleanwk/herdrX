import Foundation

/// Native AppKit controls share the in-app language chosen by SwiftUI views.
/// Resolving an .lproj bundle and its strings on every lookup is measurable in
/// body evaluation and drawing loops, so the resolved language, bundle and
/// already-read keys are cached until the preference changes.
private let localizationLock = NSLock()
private var localizedLanguage = ""
private var localizedBundle: Bundle?
private var localizedStrings: [String: String] = [:]

func L(_ key: String) -> String {
    let preference = UserDefaults.standard.string(forKey: "language") ?? "system"
    let language = preference == "system" ? (Locale.preferredLanguages.first ?? "en") : preference
    let name = language.hasPrefix("zh") ? "zh-Hans" : "en"
    localizationLock.lock()
    defer { localizationLock.unlock() }
    if localizedLanguage != name {
        localizedLanguage = name
        localizedBundle = Bundle.main.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:))
        localizedStrings.removeAll(keepingCapacity: true)
    }
    if let cached = localizedStrings[key] { return cached }
    let value = (localizedBundle ?? .main).localizedString(forKey: key, value: key, table: nil)
    localizedStrings[key] = value
    return value
}

func LF(_ format: String, _ args: CVarArg...) -> String { String(format: L(format), arguments: args) }
