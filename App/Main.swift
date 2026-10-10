import SwiftUI
import Sparkle

@main
struct HerdApp: App {
    @StateObject private var desk = Desk()
    var body: some Scene {
        Window("HerdrX", id: "desk") { Workbench().environmentObject(desk).frame(minWidth: 800, minHeight: 500) }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1200, height: 760)
        Settings { Preferences().environmentObject(desk) }
    }
}
