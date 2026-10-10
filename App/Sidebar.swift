import SwiftUI
import HerdCore

enum AgentToolIcon {
    static func asset(for tool: String?) -> String? {
        switch tool?.lowercased() {
        case "codex", "openai-codex": "agent-codex"
        case "claude", "claude-code": "agent-claude"
        case "cursor", "cursor-agent": "agent-cursor"
        case "gemini", "gemini-cli": "agent-gemini"
        case "deepseek": "agent-deepseek"
        case "pi", "omp", "oh-my-pi": "agent-pi"
        case "grok": "agent-grok"
        case "kimi", "kimi-cli": "agent-kimi"
        case "opencode": "agent-opencode"
        case "copilot", "github-copilot": "agent-githubcopilot"
        case "agy", "antigravity": "agent-antigravity"
        default: nil
        }
    }

    static func resource(for tool: String?) -> (image: NSImage, original: Bool)? {
        guard let base = asset(for: tool) else { return nil }
        for name in [base + "-color", base] {
            if let image = NSImage(named: name) { return (image, name.hasSuffix("-color")) }
        }
        return nil
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
            .background(selected ? Color(nsColor: Theme.selection).opacity(filledSelection ? (appearance == .dark ? 0.30 : 0.25) : (appearance == .dark ? 0.20 : 0.13)) : hovered ? Color(nsColor: Theme.foreground).opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(selected ? Color(nsColor: Theme.selection).opacity(filledSelection ? 0 : 0.24) : .clear, lineWidth: 1))
            .onHover { hovered = $0 }.accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct SidebarGroup<Content: View>: View {
    let title: String
    let id: String
    let empty: Bool
    let status: String?
    let statusColor: Color
    @ViewBuilder let content: () -> Content
    @AppStorage private var collapsed: Bool
    init(title: String, id: String, empty: Bool, status: String? = nil, statusColor: Color = .secondary, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.id = id; self.empty = empty; self.content = content; self.status = status; self.statusColor = statusColor
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
                        if let status { Circle().fill(statusColor).frame(width: 6, height: 6).help(status).accessibilityHidden(true) }
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

/// Shared by sidebar metadata and search; unknown tools retain the native terminal fallback.
struct AgentIcon: View {
    let tool: String?
    var size: CGFloat = 12
    var body: some View {
        Group {
            if let resource = AgentToolIcon.resource(for: tool) {
                Image(nsImage: resource.image).resizable().renderingMode(resource.original ? .original : .template).scaledToFit()
                    .background(resource.original && AgentToolIcon.asset(for: tool) == "agent-kimi" ? Color.black : Color.clear, in: RoundedRectangle(cornerRadius: 2))
            } else {
                Image(systemName: "terminal").resizable().scaledToFit()
            }
        }.frame(width: size, height: size).foregroundStyle(Color(nsColor: Theme.foreground)).accessibilityHidden(true)
    }
}

/// Keep the native scroll behavior without the wide legacy gutter when macOS
/// is configured to always show scroll bars. Scoped to the sidebar document.
struct SidebarScrollStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.configure() }
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.configure() }
        }
        func configure() {
            guard let scroll = enclosingScrollView else { return }
            scroll.scrollerStyle = .overlay
            scroll.autohidesScrollers = true
            scroll.verticalScroller?.controlSize = .small
            scroll.drawsBackground = false
        }
    }
}
