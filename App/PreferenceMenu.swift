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
        // Separators are menu structure, not choices; unchanged menus must stay open.
        if button.itemArray.filter({ !$0.isSeparatorItem }).map(\.title) != titles {
            button.removeAllItems(); button.addItems(withTitles: titles)
            if items.count > 2, items[1].0 == "herdr" { button.menu?.insertItem(.separator(), at: 2) }
        }
        if let index = items.firstIndex(where: { $0.0 == selection }) { button.selectItem(withTitle: titles[index]) }
        button.isEnabled = enabled
        button.setAccessibilityLabel(L(label))
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? { CGSize(width: proposal.width ?? 180, height: 24) }
    final class Coordinator: NSObject {
        var parent: PreferenceMenu
        init(_ parent: PreferenceMenu) { self.parent = parent }
        @objc func choose(_ sender: NSPopUpButton) { if let value = parent.items.first(where: { L($0.1) == sender.titleOfSelectedItem }) { parent.selection = value.0 } }
    }
}
