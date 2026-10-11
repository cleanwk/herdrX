import SwiftUI

struct WorkbenchActions {
    var perform: (String) -> Void
    var enabled: (String) -> Bool
}
private struct WorkbenchActionsKey: FocusedValueKey { typealias Value = WorkbenchActions }
extension FocusedValues {
    var workbenchActions: WorkbenchActions? {
        get { self[WorkbenchActionsKey.self] }
        set { self[WorkbenchActionsKey.self] = newValue }
    }
}
struct WorkbenchCommands: Commands {
    @FocusedValue(\.workbenchActions) private var actions
    func button(_ title: String, _ id: String, _ key: KeyEquivalent, _ modifiers: EventModifiers = .command) -> some View {
        Button(L(title)) { actions?.perform(id) }.keyboardShortcut(key, modifiers: modifiers).disabled(actions?.enabled(id) != true)
    }
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            button("Close", "close", "w")
            Divider()
            button("New Terminal Tab", "terminal", "t")
            button("Quick New Space", "space", "n", [.command, .shift])
        }
        CommandGroup(replacing: .windowSize) {
            button("Close Pane…", "closePane", "w", [.command, .shift])
            button("Close Tab…", "closeTab", "w", [.command, .option])
            Divider()
            button("Toggle Sidebar", "sidebar", "b")
        }
        CommandMenu(L("Terminal")) {
            button("Rename Tab…", "renameTab", "r", [.command, .option])
            Divider()
            Menu(L("Repair Terminal")) {
                button("Restore Input Modes", "repair", "r", [.command, .shift])
                Button("Interrupt Task and Repair TTY…") { actions?.perform("interrupt") }.disabled(actions?.enabled("repair") != true)
            }
        }
        CommandMenu(L("Workspace")) {
            button("Search…", "search", "k")
            button("Next Agent Needing Attention", "attention", "j", [.command, .shift])
            Divider()
            button("Split Right", "splitRight", "d")
            button("Split Down", "splitDown", "d", [.command, .shift])
            button("Zoom / Restore Pane", "zoom", .return, [.command, .shift])
            Divider()
            Menu(L("Focus Pane")) {
                button("Focus Left", "left", .leftArrow, [.command, .option])
                button("Focus Right", "right", .rightArrow, [.command, .option])
                button("Focus Up", "up", .upArrow, [.command, .option])
                button("Focus Down", "down", .downArrow, [.command, .option])
            }
            Menu(L("Resize Pane")) {
                button("Resize Left", "resizeLeft", .leftArrow, [.command, .control])
                button("Resize Right", "resizeRight", .rightArrow, [.command, .control])
                button("Resize Up", "resizeUp", .upArrow, [.command, .control])
                button("Resize Down", "resizeDown", .downArrow, [.command, .control])
            }
            Divider()
            button("Previous Tab", "previous", "[", [.command, .shift])
            button("Next Tab", "next", "]", [.command, .shift])
            Menu(L("Go to Tab")) {
                ForEach(1...9, id: \.self) { number in button(LF("Tab %d", number), "tab\(number)", KeyEquivalent(Character(String(number)))) }
            }
        }
    }
}
