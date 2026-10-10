import SwiftUI
import AppKit

/// Native popup sizing avoids SwiftUI's centered intrinsic control inside a wide form column.
struct PreferenceMenu: NSViewRepresentable {
    let label: String
    let items: [(String, String)]
    @Binding var selection: String
    @Environment(\.isEnabled) private var enabled
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.font = .systemFont(ofSize: 13)
        button.bezelStyle = .rounded
        button.target = context.coordinator; button.action = #selector(Coordinator.choose(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        let titles = items.map { L($0.1) }
        let choices = button.itemArray.filter { !$0.isSeparatorItem }
        let separatesThemeSources = items.count > 2 && items[1].0 == "herdr"
        // Separators are menu structure, not choices; unchanged menus must stay open.
        if choices.map(\.title) != titles || choices.map({ $0.representedObject as? String }) != items.map({ Optional($0.0) }) || button.itemArray.contains(where: \.isSeparatorItem) != separatesThemeSources {
            button.removeAllItems()
            for (index, item) in items.enumerated() {
                let choice = NSMenuItem(title: titles[index], action: nil, keyEquivalent: "")
                choice.representedObject = item.0
                button.menu?.addItem(choice)
            }
            if separatesThemeSources { button.menu?.insertItem(.separator(), at: 2) }
        }
        button.select(button.itemArray.first { $0.representedObject as? String == selection })
        button.isEnabled = enabled
        button.setAccessibilityLabel(L(label))
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? { CGSize(width: proposal.width ?? 180, height: 24) }
    final class Coordinator: NSObject {
        var parent: PreferenceMenu
        init(_ parent: PreferenceMenu) { self.parent = parent }
        @objc func choose(_ sender: NSPopUpButton) { if let value = sender.selectedItem?.representedObject as? String { parent.selection = value } }
    }
}
