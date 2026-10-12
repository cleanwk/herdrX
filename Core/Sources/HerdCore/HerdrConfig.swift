import Foundation
import TOMLKit

/// Use a TOML 1.0 parser so inline arrays, quoted keys, literal/multiline
/// commands and comments have the same meaning as in Herdr's config.
public struct HerdrConfig: Equatable, Sendable {
    public struct StatusCommand: Identifiable, Equatable, Sendable {
        public let id: String
        public let command: String
        public let interval: Int
        public let timeout: Int
    }
    public struct Popup: Identifiable, Equatable, Sendable {
        public let id: String
        public let command: String
        public let title: String
        public let key: String
        public let width: JSON
        public let height: JSON
    }
    public var status: [StatusCommand] = []
    public var popups: [Popup] = []
    public var separator = " "
    public init() {}
    public init(_ text: String) throws {
        let table = try TOMLTable(string: text)
        let value = try JSONDecoder().decode(JSON.self, from: Data(table.convert(to: .json).utf8))
        separator = value["ui"]["tab_bar_right_separator"].string ?? " "
        for (index, row) in value["ui"]["tab_bar_right"].array.prefix(16).enumerated() where row["type"].string == "command" {
            let interval = row["interval_seconds"].int ?? 5, timeout = row["timeout_seconds"].int ?? 2
            guard let command = row["command"].string, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...31_536_000).contains(interval), (1...3600).contains(timeout) else { continue }
            status.append(StatusCommand(id: "status-\(index)", command: command, interval: interval, timeout: timeout))
        }
        for (index, row) in value["keys"]["command"].array.enumerated() where row["type"].string == "popup" {
            guard let command = row["command"].string, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            popups.append(Popup(id: "config-popup-\(index)", command: command, title: DisplayTitle.clean(row["description"].string) ?? command, key: row["key"].string ?? "", width: row["width"], height: row["height"]))
        }
    }
    public static func statusText(_ bytes: Data) -> String {
        // Status is plain text, never interpreted as terminal controls.
        let text = String(decoding: bytes, as: UTF8.self)
        let stripped = text.replacingOccurrences(of: "\\u001B\\[[0-?]*[ -/]*[@-~]", with: "", options: .regularExpression)
        let line = stripped.split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? ""
        return String(line.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.map(String.init).joined().prefix(256)).trimmingCharacters(in: .whitespaces)
    }
}
