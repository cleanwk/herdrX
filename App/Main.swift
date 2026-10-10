import SwiftUI
import Sparkle

@main
struct HerdApp: App {
    @StateObject private var desk = Desk()
    @AppStorage("appearance") private var appearance = "system"
    private var scheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }
    var body: some Scene {
        Window("HerdrX", id: "desk") { Workbench().environmentObject(desk).frame(minWidth: 800, minHeight: 500).preferredColorScheme(scheme) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1200, height: 760)
        Settings { Preferences().environmentObject(desk).preferredColorScheme(scheme) }
    }
}
