import SwiftUI
import HerdCore

extension ConnectionState {
    var color: Color {
        if self == .connected { return Color(nsColor: Theme.success) }
        if isBusy || issue?.kind == .localStopped || issue?.kind == .localUnavailable || issue?.kind == .notInstalled { return Color(nsColor: Theme.secondary) }
        return Color(nsColor: Theme.warning)
    }
}

/// Shared by the sidebar, empty canvas and connection settings.
struct ConnectionRecovery: View {
    @EnvironmentObject var desk: Desk
    @Environment(\.openSettings) private var openSettings
    let device: Device
    var centered = false
    var showsSettings = true
    @State private var details = false
    private var state: ConnectionState { desk.connections[device.id] ?? .connecting }
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 6) {
            HStack(spacing: 6) {
                if state.isBusy { ProgressView().controlSize(.mini).accessibilityHidden(true) }
                Text(L(state.title)).font(.system(size: 12, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            }
            if let issue = state.issue {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { actions(issue) }
                    VStack(alignment: centered ? .center : .leading, spacing: 6) { actions(issue) }
                }.font(.system(size: 11)).padding(.top, 2)
            }
            if desk.sessions[device.id] != nil {
                Text("Cached session data · offline").font(.system(size: 11)).foregroundStyle(Color(nsColor: Theme.secondary))
            }
        }.multilineTextAlignment(centered ? .center : .leading).frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .popover(isPresented: $details, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connection Details").font(.headline)
                    if let issue = state.issue { Text(L(issue.guidance)).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true) }
                    ScrollView {
                        Text(DisplayTitle.detail([device.endpoint.target, device.endpoint.socketPath]) + "\n\n" + (state.issue?.detail ?? ""))
                            .font(.system(size: 11)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 180)
                    Button("Copy Details") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(DisplayTitle.detail([device.displayName, device.endpoint.target, device.endpoint.socketPath]) + "\n" + (state.issue?.detail ?? ""), forType: .string)
                    }
                }.padding(16).frame(width: 320)
            }
    }
    @ViewBuilder private func actions(_ issue: ConnectionIssue) -> some View {
        if issue.kind == .notInstalled {
            Link("Install Herdr…", destination: URL(string: "https://herdr.dev/docs/install/")!)
            Button("Retry") { desk.startLocalHerdr(device) }.buttonStyle(.borderless)
        } else if issue.canStart, LocalHerdrTarget(endpoint: device.endpoint) != nil {
            Button("Start Herdr") { desk.startLocalHerdr(device) }.buttonStyle(.bordered).controlSize(.small)
        } else if showsSettings && (issue.kind == .configuration || issue.kind == .localUnavailable) {
            Button("Connections…") {
                UserDefaults.standard.set("Connections", forKey: "settingsPage")
                openSettings()
            }.buttonStyle(.borderless)
        } else {
            Button("Retry") { desk.connect(device) }.buttonStyle(.borderless)
        }
        Button { details = true } label: { Image(systemName: "info.circle").frame(width: 20, height: 20) }
            .buttonStyle(.borderless).help("Connection Details").accessibilityLabel("Connection Details")
    }
}
