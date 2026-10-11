import AppKit
import CryptoKit
import Security
import SwiftUI
import HerdCore

enum TailcatSecrets {
    private static let service = "io.github.cleanwk.herdrx.tailcat"
    static func read(_ account: String) throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let text = String(data: data, encoding: .utf8) else { throw Failure("Cannot read Tailcat Keychain item (\(status)).") }; return text
    }
    static func save(_ value: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data; add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let result = SecItemAdd(add as CFDictionary, nil); guard result == errSecSuccess else { throw Failure("Cannot save Tailcat credential (\(result)).") }
        } else if status != errSecSuccess { throw Failure("Cannot update Tailcat credential (\(status)).") }
    }
    static func remove(_ account: String) { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary) }
    static func identity(regenerate: Bool = false) throws -> (privateKey: String, publicKey: String) {
        let key: Curve25519.KeyAgreement.PrivateKey
        if !regenerate, let stored = try read("client") {
            guard let bytes = Data(base64Encoded: stored) else { throw Failure("Invalid Tailcat identity in Keychain") }
            key = try .init(rawRepresentation: bytes)
        } else { key = .init(); try save(key.rawRepresentation.base64EncodedString(), account: "client") }
        func hex(_ bytes: Data) -> String { bytes.map { String(format: "%02x", $0) }.joined() }
        return ("privkey:" + hex(key.rawRepresentation), "nodekey:" + hex(key.publicKey.rawRepresentation))
    }
}

final class TailcatConnection {
    let directory: URL
    var path: String { directory.appendingPathComponent("herdr.sock").path }
    private let process = Process()
    private let diagnostic: FileHandle
    init(device: String) throws {
        guard let executable = Bundle.main.url(forAuxiliaryExecutable: "herdrx-tailcat") else { throw Failure("Tailcat transport helper is missing. Build using scripts/build.sh.") }
        guard let token = try TailcatSecrets.read("token." + device) else { throw Failure("Set this device’s Tailcat token in Settings.") }
        let identity = try TailcatSecrets.identity()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("hx-tc-" + UUID().uuidString.prefix(8))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let log = directory.appendingPathComponent("transport.log"); FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600]); diagnostic = try FileHandle(forWritingTo: log)
        let input = Pipe(); process.executableURL = executable; process.arguments = [directory.path]; process.standardInput = input; process.standardOutput = FileHandle.nullDevice; process.standardError = diagnostic
        do { try process.run(); try input.fileHandleForWriting.write(contentsOf: JSONSerialization.data(withJSONObject: ["token": token, "key": identity.privateKey])); try input.fileHandleForWriting.close() }
        catch { stop(); throw error }
    }
    var running: Bool { process.isRunning }
    func stop() { if process.isRunning { process.terminate() }; try? diagnostic.close(); try? FileManager.default.removeItem(at: directory) }
    deinit { stop() }
}

struct TailcatSettings: View {
    @EnvironmentObject var desk: Desk
    @State private var name = ""
    @State private var token = ""
    @State private var publicKey = ""
    @State private var editing: String?
    @State private var error: String?
    var body: some View {
        Form {
            if desk.devices.contains(where: { $0.endpoint.kind == "tailcat" }) {
                Section("Saved devices") {
                    ForEach(desk.devices.filter { $0.endpoint.kind == "tailcat" }) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.displayName).lineLimit(1).truncationMode(.middle).help(device.displayName)
                                Text(L((desk.connections[device.id] ?? .connecting).title)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Edit") { edit(device) }.fixedSize()
                            if !desk.canWrite(device.id) { Button("Retry") { desk.connect(device) }.disabled(desk.connections[device.id]?.isBusy == true).fixedSize() }
                        }
                    }
                }
            }
            Section("Client identity") {
                Text(publicKey.isEmpty ? L("Generate an identity to connect to hosts using an allowlist.") : publicKey).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                Button(LocalizedStringKey(publicKey.isEmpty ? "Generate Client Identity" : "Regenerate Client Identity…")) {
                    if !publicKey.isEmpty {
                        let alert = NSAlert(); alert.messageText = L("Replace Tailcat identity?"); alert.informativeText = L("Every host allowlist must be updated with the new public key. Existing connections will reconnect."); alert.addButton(withTitle: L("Regenerate")); alert.addButton(withTitle: L("Cancel"))
                        guard alert.runModal() == .alertFirstButtonReturn else { return }
                    }
                    do { publicKey = try TailcatSecrets.identity(regenerate: true).publicKey; for device in desk.devices where device.endpoint.kind == "tailcat" { desk.connect(device) } } catch { self.error = error.localizedDescription }
                }
            }
            Section(LocalizedStringKey(editing == nil ? "Add Tailcat device" : "Edit connection")) {
                TextField("Name", text: $name)
                SecureField("Connection token", text: $token, prompt: Text(editing == nil ? "" : "Leave blank to keep the saved token"))
                Text("Use a herdr.tailcat host exposing control port 6464 and terminal port 6465. Tokens and the client key are kept in HerdrX’s Keychain namespace.").font(.caption).foregroundStyle(.secondary)
                Button(LocalizedStringKey(editing == nil ? "Add Device" : "Save Changes")) {
                    guard let cleanName = DisplayTitle.clean(name) else { return }
                    guard editing == nil || desk.devices.contains(where: { $0.id == editing && $0.endpoint.kind == "tailcat" }) else { error = L("This connection is no longer available."); return }
                    let device = Device(id: editing ?? UUID().uuidString, displayName: cleanName, endpoint: .init(kind: "tailcat", socketPath: "/herdr.sock"))
                    do {
                        if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try TailcatSecrets.save(token.trimmingCharacters(in: .whitespacesAndNewlines), account: "token." + device.id) }
                        publicKey = try TailcatSecrets.identity().publicKey
                        if editing != nil { desk.update(device) } else { desk.add(device) }
                        reset()
                    } catch { self.error = error.localizedDescription }
                }.disabled(DisplayTitle.clean(name) == nil || (editing == nil && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                if editing != nil { Button("Cancel Editing") { reset() } }
            }
            if let error { Text(error).foregroundStyle(.red).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
        }.formStyle(.grouped).task { if (try? TailcatSecrets.read("client")) != nil { publicKey = (try? TailcatSecrets.identity().publicKey) ?? "" } }
            .onAppear { receiveEditRequest() }.onChange(of: desk.tailcatEditRequest) { receiveEditRequest() }
            .onChange(of: desk.devices) {
                if let editing, !desk.devices.contains(where: { $0.id == editing && $0.endpoint.kind == "tailcat" }) { reset(); error = L("This connection is no longer available.") }
            }
    }
    private func edit(_ device: Device) { editing = device.id; name = device.displayName; token = ""; error = nil }
    private func reset() { editing = nil; name = ""; token = ""; error = nil }
    private func receiveEditRequest() {
        guard let id = desk.tailcatEditRequest else { return }
        desk.tailcatEditRequest = nil
        guard let device = desk.devices.first(where: { $0.id == id && $0.endpoint.kind == "tailcat" }) else { error = L("This connection is no longer available."); return }
        edit(device)
    }
}
