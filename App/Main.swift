import SwiftUI
import Sparkle

@main
struct HerdApp: App {
    @StateObject private var desk = Desk()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("palette") private var palette = "default"
    @AppStorage("language") private var language = "system"
    @AppStorage("accent") private var accent = "theme"
    private var scheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }
    var body: some Scene {
        Window("HerdrX", id: "desk") { Workbench().environmentObject(desk).frame(minWidth: 980, minHeight: 588).preferredColorScheme(scheme).environment(\.locale, language == "system" ? .current : Locale(identifier: language)).tint(Color(nsColor: Theme.accent)).accentColor(Color(nsColor: Theme.accent)).onChange(of: palette) { Theme.apply() }.onChange(of: accent) { Theme.apply() } }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1200, height: 760)
            .commands { WorkbenchCommands() }
        Settings { Preferences().environmentObject(desk).preferredColorScheme(scheme).environment(\.locale, language == "system" ? .current : Locale(identifier: language)).tint(Color(nsColor: Theme.accent)).accentColor(Color(nsColor: Theme.accent)).onChange(of: palette) { Theme.apply() }.onChange(of: accent) { Theme.apply() } }
    }
}
