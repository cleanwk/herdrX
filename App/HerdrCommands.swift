import AppKit
import HerdCore

extension Desk {
    var statusText: String { herdrConfig.status.compactMap { statusOutputs[$0.id] }.filter { !$0.isEmpty }.joined(separator: herdrConfig.separator) }
    func reloadHerdrConfig() {
        let env = ProcessInfo.processInfo.environment
        guard env["HERDRX_STATE_DIR"] == nil || env["HERDRX_CONFIG_PATH"] != nil else { return }
        let path = env["HERDRX_CONFIG_PATH"] ?? NSHomeDirectory() + "/.config/herdr/config.toml"
        do {
            let text = FileManager.default.fileExists(atPath: path) ? try String(contentsOfFile: path, encoding: .utf8) : ""
            guard text != configContents else { return }
            let config = try HerdrConfig(text)
            configContents = text; configError = nil
            guard config != herdrConfig else { return }
            statusTasks.values.forEach { $0.cancel() }; statusTasks = [:]; statusOutputs = [:]
            herdrConfig = config
            for entry in config.status {
                statusTasks[entry.id] = Task { [weak self] in
                    while !Task.isCancelled {
                        do {
                            guard let context = self?.localCommandContext() else { return }
                            let output = try await CommandProcess.run("/bin/zsh", ["-lc", "cd " + quote(context.cwd) + " && " + entry.command], input: Data(), timeout: TimeInterval(entry.timeout), outputLimit: 64 * 1024, environment: context.environment)
                            try Task.checkCancellation()
                            self?.statusOutputs[entry.id] = HerdrConfig.statusText(output)
                        } catch is CancellationError { return }
                        catch { if !Task.isCancelled { self?.statusOutputs[entry.id] = nil } }
                        do { try await Task.sleep(for: .seconds(entry.interval)) } catch { return }
                    }
                }
            }
            reindex()
        } catch {
            // Invalid edits must not leave removed/old commands executing.
            configContents = nil; herdrConfig = HerdrConfig(); statusTasks.values.forEach { $0.cancel() }; statusTasks = [:]; statusOutputs = [:]
            configError = LF("Could not read Herdr config: %@", error.localizedDescription); reindex()
        }
    }
    func attachmentSocket(_ device: Device) -> String {
        if device.endpoint.kind == "tailcat" { return (try? rpc(device.id).path) ?? device.endpoint.socketPath }
        return resolvedSockets[device.id] ?? device.endpoint.socketPath
    }
    func localCommandContext() -> (environment: [String: String], cwd: String) {
        var environment = ProcessInfo.processInfo.environment
        for key in Array(environment.keys) where key.hasPrefix("HERDR_") { environment.removeValue(forKey: key) }
        var cwd = NSHomeDirectory()
        let paths = [NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"] + (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        environment["HERDR_BIN_PATH"] = paths.map { $0 + "/herdr" }.first { FileManager.default.isExecutableFile(atPath: $0) }
        let local = devices.first { $0.id == selectedDevice && $0.endpoint.kind == "local" } ?? devices.first { $0.endpoint.kind == "local" }
        if let local {
            environment["HERDR_SOCKET_PATH"] = local.endpoint.socketPath
            if selectedDevice == local.id {
                environment["HERDR_ACTIVE_WORKSPACE_ID"] = selectedSpace
                environment["HERDR_ACTIVE_TAB_ID"] = selectedTab
                environment["HERDR_ACTIVE_PANE_ID"] = currentPane?.id
                environment["HERDR_ACTIVE_PANE_CWD"] = currentPane?.cwd
                cwd = currentPane?.cwd ?? cwd
            }
        }
        return (environment, cwd)
    }
    func openConfigPopup(_ entry: HerdrConfig.Popup) {
        let (environment, cwd) = localCommandContext()
        let terminal = FloatingTerminal(title: entry.title, command: "cd " + quote(cwd) + " && " + entry.command, environment: environment, width: entry.width, height: entry.height)
        present(terminal)
    }
    func present(_ terminal: FloatingTerminal, pane: PaneKey? = nil) {
        floatingTerminals[terminal.id] = terminal
        terminal.focusChanged = { [weak self] in self?.objectWillChange.send() }
        if let pane { floatingPanes[pane] = terminal.id; terminals.removeValue(forKey: pane)?.stop(); objectWillChange.send() }
        terminal.didClose = { [weak self, weak terminal] in
            guard let self, let terminal else { return }
            floatingTerminals[terminal.id] = nil
            if let pane, floatingPanes[pane] == terminal.id { floatingPanes[pane] = nil; objectWillChange.send() }
        }
        terminal.showWindow(nil)
        terminal.window?.makeKeyAndOrderFront(nil)
    }
    func stopHerdrCommands() {
        statusTasks.values.forEach { $0.cancel() }; statusTasks = [:]
        pluginTasks.values.forEach { $0.cancel() }; pluginTasks = [:]
        for terminal in Array(floatingTerminals.values) { terminal.finish() }
    }
}
