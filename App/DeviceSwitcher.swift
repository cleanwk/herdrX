import SwiftUI
import HerdCore

struct DeviceSwitcher: View {
    @EnvironmentObject var desk: Desk
    @State private var showing = false
    private var selected: Device? { desk.devices.first { $0.id == desk.deviceFilter } }
    var body: some View {
        Button { showing.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: selected.map(symbol) ?? "square.stack.3d.up").font(.system(size: 11))
                Text(selected?.displayName ?? L("All Devices")).font(.system(size: 12, weight: .medium)).lineLimit(1)
                if let selected { connectionDot(selected) }
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(Color(nsColor: Theme.secondary))
            }.padding(.horizontal, 8).frame(height: 28)
                .background(Color(nsColor: Theme.accent).opacity(showing ? 0.18 : 0.055), in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).accessibilityLabel("Device Filter").accessibilityValue(selected?.displayName ?? L("All Devices"))
            .popover(isPresented: $showing, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Devices").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(nsColor: Theme.secondary)).padding(.horizontal, 10).padding(.top, 4)
                    deviceRow(name: L("All Devices"), detail: LF("%d devices · %d connected", desk.devices.count, desk.devices.filter { desk.canWrite($0.id) }.count), symbol: "square.stack.3d.up", id: "", device: nil)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(desk.devices) { device in
                                deviceRow(name: device.displayName, detail: detail(device), symbol: symbol(device), id: device.id, device: device)
                            }
                        }
                    }.frame(maxHeight: min(360, CGFloat(desk.devices.count) * 46))
                    Divider().padding(.horizontal, 8).padding(.vertical, 4)
                    SettingsLink {
                        Label("Add Device…", systemImage: "plus").font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading).padding(10).contentShape(Rectangle())
                    }.buttonStyle(.plain).simultaneousGesture(TapGesture().onEnded { UserDefaults.standard.set("Connections", forKey: "settingsPage"); showing = false })
                }.padding(6).frame(width: 270).foregroundStyle(Color(nsColor: Theme.foreground))
            }
    }
    func symbol(_ device: Device) -> String { device.endpoint.kind == "local" ? "apple.logo" : "server.rack" }
    func detail(_ device: Device) -> String {
        let endpoint = device.endpoint
        if endpoint.kind == "local" { return DisplayTitle.detail([L("This Mac"), URL(fileURLWithPath: endpoint.socketPath).lastPathComponent]) }
        return DisplayTitle.detail([endpoint.target ?? device.displayName, endpoint.kind == "ssh" ? "SSH" : "Tailcat"])
    }
    func connectionDot(_ device: Device) -> some View {
        Circle().fill(Color(nsColor: desk.canWrite(device.id) ? Theme.success : Theme.failure)).frame(width: 6, height: 6)
            .accessibilityLabel(L(desk.canWrite(device.id) ? "Connected" : "Offline"))
    }
    func deviceRow(name: String, detail: String, symbol: String, id: String, device: Device?) -> some View {
        SidebarRow(selected: desk.deviceFilter == id, action: { desk.deviceFilter = id; showing = false }, verticalPadding: 7, radius: 7, filledSelection: true) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 16, weight: .regular)).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) { Text(name).font(.system(size: 13)).lineLimit(1); if let device { connectionDot(device) } }
                    Text(detail).font(.system(size: 11)).lineLimit(1).truncationMode(.middle).foregroundStyle(Color(nsColor: Theme.secondary))
                }.frame(maxWidth: .infinity, alignment: .leading)
                if desk.deviceFilter == id { Image(systemName: "checkmark").font(.system(size: 13, weight: .medium)) }
            }
        }.help(name + "\n" + detail)
    }
}
