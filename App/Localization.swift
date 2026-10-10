import Foundation

/// Native AppKit controls share the in-app language chosen by SwiftUI views.
func L(_ key: String) -> String {
    let preference = UserDefaults.standard.string(forKey: "language") ?? "system"
    let language = preference == "system" ? (Locale.preferredLanguages.first ?? "en") : preference
    let name = language.hasPrefix("zh") ? "zh-Hans" : "en"
    let bundle = Bundle.main.path(forResource: name, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    return bundle.localizedString(forKey: key, value: key, table: nil)
}

func LF(_ format: String, _ args: CVarArg...) -> String { String(format: L(format), arguments: args) }
