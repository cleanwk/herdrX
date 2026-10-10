import AppKit
import HerdCore

extension Desk {
    private func attachmentTarget(_ key: PaneKey) throws -> (Item, Device, String) {
        guard let pane = sessions[key.device]?.panes.first(where: { $0.id == key.pane }), let kind = pane.agent,
              let device = devices.first(where: { $0.id == key.device }) else { throw Failure("Select a running agent before attaching a file.") }
        let mode = pane.tokens["attachment_mode"]?.string ?? UserDefaults.standard.string(forKey: "attachmentMode." + kind) ?? "unknown"
        return (pane, device, mode)
    }
    func attachFile(to key: PaneKey) {
        do {
            let (pane, device, mode) = try attachmentTarget(key)
            guard mode == "path" else { throw Failure("This agent has not declared support for file path references. Configure its capability in Agent Settings before delivery. Clipboard and source files have not changed.") }
            guard ["local", "ssh"].contains(device.endpoint.kind) else { throw Failure("File delivery is not supported for this connection.") }
            let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let url = panel.url else { return }
            deliverFile(url, to: key, pane: pane, device: device)
        } catch { message = error.localizedDescription }
    }
    /// Text still uses Ghostty's normal bracketed paste. Non-text content is never
    /// silently converted into a local path for a remote agent.
    func pasteAttachment(to key: PaneKey) -> Bool {
        let board = NSPasteboard.general
        let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let hasImage = board.availableType(from: [.png, .tiff]) != nil
        guard !urls.isEmpty || hasImage else { return false }
        do {
            let (pane, device, mode) = try attachmentTarget(key)
            if urls.isEmpty, hasImage, mode == "clipboard" {
                guard device.endpoint.kind == "local" else { throw Failure("A remote agent cannot read this Mac’s clipboard. Use a declared file path capability to stage the image over SSH.") }
                guard terminals[key]?.view.sendKey(.v, modifiers: .ctrl) == true else { throw Failure("The target terminal is unavailable. Clipboard has not changed.") }
                return true
            }
            guard mode == "path" else { throw Failure("Attachment capability is unknown. Choose a file capability in Agent Settings. Clipboard has not changed.") }
            guard ["local", "ssh"].contains(device.endpoint.kind) else { throw Failure("File delivery is not supported for this connection.") }
            if !urls.isEmpty {
                guard urls.count == 1 else { throw Failure("Attach one ordinary file at a time. Clipboard has not changed.") }
                deliverFile(urls[0], to: key, pane: pane, device: device)
            } else {
                guard let image = NSImage(pasteboard: board), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) else { throw Failure("The clipboard image could not be decoded. Clipboard has not changed.") }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-attachment-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                let file = directory.appendingPathComponent("clipboard.png")
                try data.write(to: file, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                deliverFile(file, to: key, pane: pane, device: device, retainedSource: true)
            }
        } catch { message = error.localizedDescription }
        return true
    }
    private func deliverFile(_ url: URL, to key: PaneKey, pane: Item, device: Device, retainedSource: Bool = false) {
        Task {
            var staged: String?
            do {
                let info = try await FileService().info(url.path)
                guard info.kind == "file" else { throw Failure("Only regular files can be attached.") }
                let reference: String
                if device.endpoint.kind == "local" { reference = url.path }
                else {
                    let remote = FileService(endpoint: device.endpoint)
                    let home = try await remote.home()
                    let destination = home + "/.herdrx-attachment-" + UUID().uuidString + "-" + url.lastPathComponent
                    reference = try await FileService().transfer(url.path, to: remote, destination: destination, conflict: .cancel); staged = reference
                }
                guard devices.first(where: { $0.id == key.device })?.endpoint == device.endpoint,
                      sessions[key.device]?.panes.contains(where: { $0.id == key.pane && $0.agent == pane.agent && $0.terminal == pane.terminal }) == true,
                      let terminal = terminals[key], terminal.view.paste(text: quote(reference)) else { throw Failure("The target agent changed or its terminal is unavailable.") }
                if staged != nil || retainedSource { message = "File reference pasted. Staged copy remains at \(reference); remove it after the agent finishes." }
            } catch {
                message = "Attachment was not delivered: " + error.localizedDescription
                    + (staged.map { " Uploaded file remains at " + $0 } ?? "")
                    + (retainedSource ? " Clipboard image retained at " + url.path : "")
            }
        }
    }
}
