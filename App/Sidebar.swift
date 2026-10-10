import SwiftUI
import HerdCore

enum AgentToolIcon {
    static func symbol(for tool: String?) -> String {
        switch tool?.lowercased() {
        case "claude": "sun.max"
        case "codex": "curlybraces"
        case "cursor": "cursorarrow"
        case "gemini": "sparkles"
        case "grok": "asterisk"
        case "kimi": "moon"
        case "opencode": "chevron.left.forwardslash.chevron.right"
        case "pi", "omp", "oh-my-pi": "function"
        case "copilot": "airplane"
        default: "terminal"
        }
    }
}

struct SidebarRow<Content: View>: View {
    let selected: Bool
    let action: () -> Void
    var verticalPadding: CGFloat = 7
    var radius: CGFloat = 8
    var filledSelection = false
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var appearance
    @State private var hovered = false
    var body: some View {
        Button(action: action) { content().padding(.horizontal, 8).padding(.vertical, verticalPadding).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .background(selected ? Color(nsColor: Theme.accent).opacity(filledSelection ? (appearance == .dark ? 0.30 : 0.25) : (appearance == .dark ? 0.20 : 0.13)) : hovered ? Color(nsColor: Theme.foreground).opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(selected ? Color(nsColor: Theme.accent).opacity(filledSelection ? 0 : 0.24) : .clear, lineWidth: 1))
            .onHover { hovered = $0 }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct SidebarGroup<Content: View>: View {
    let title: String
    let id: String
    let empty: Bool
    let status: String?
    let connected: Bool
    @ViewBuilder let content: () -> Content
    @AppStorage private var collapsed: Bool
    init(title: String, id: String, empty: Bool, status: String? = nil, connected: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.id = id; self.empty = empty; self.content = content; self.status = status; self.connected = connected
        _collapsed = AppStorage(wrappedValue: false, "sidebarCollapsed." + id)
    }
    var body: some View {
        if !empty {
            Section {
                if !collapsed { content() }
            } header: {
                Button { collapsed.toggle() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.system(size: 9, weight: .medium)).frame(width: 12)
                        Text(title).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        if let status { Circle().fill(Color(nsColor: connected ? Theme.success : Theme.failure)).frame(width: 6, height: 6).help(status).accessibilityHidden(true) }
                        Spacer(minLength: 2)
                    }.foregroundStyle(Color(nsColor: Theme.secondary)).padding(.horizontal, 8).frame(height: 28).contentShape(Rectangle())
                }.buttonStyle(.plain).background(Color(nsColor: Theme.content)).accessibilityLabel(title).accessibilityValue(DisplayTitle.detail([L(collapsed ? "Collapsed" : "Expanded"), status])).accessibilityHint(L(collapsed ? "Expand group" : "Collapse group"))
            }
        }
    }
}
struct AgentStatus: View {
    let status: String
    let unread: Bool
    static func color(_ status: String, unread: Bool) -> Color { status == "blocked" ? Color(nsColor: Theme.warning) : status == "working" || unread ? Color(nsColor: Theme.accent) : status == "done" || status == "idle" ? Color(nsColor: Theme.success) : Color(nsColor: Theme.secondary) }
    var body: some View {
        Image(systemName: status == "working" ? "circle.lefthalf.filled" : status == "blocked" || unread ? "circle.fill" : "circle")
            .font(.system(size: 8)).foregroundStyle(status == "done" || status == "idle" ? Color(nsColor: Theme.secondary).opacity(0.6) : Self.color(status, unread: unread))
            .accessibilityLabel(L(status == "unknown" ? "Unknown" : unread ? "Completed, unread" : status))
    }
}
