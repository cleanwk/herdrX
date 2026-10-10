import Foundation

public struct FileEntry: Codable, Identifiable, Equatable, Sendable {
    public let path: String
    public let name: String
    public let kind: String
    public let size: Int64
    public let modified: Double
    public var id: String { path }
}
public enum FileConflict: String, Sendable { case cancel, replace, keepBoth }

/// File operations are separate from Herdr control RPC and terminal byte streams.
/// SSH requires Python 3 on the target; a missing helper is reported as an error.
public struct FileService: Sendable {
    public static let previewLimit = 2 * 1024 * 1024
    public let endpoint: Device.Endpoint
    public init(endpoint: Device.Endpoint = .init(kind: "local", socketPath: "")) { self.endpoint = endpoint }
    public func list(_ path: String, hidden: Bool = false) async throws -> [FileEntry] {
        let data = try await operation("list", path: path)
        return try JSONDecoder().decode([FileEntry].self, from: data).filter { hidden || !$0.name.hasPrefix(".") }.sorted {
            if ($0.kind == "directory") != ($1.kind == "directory") { return $0.kind == "directory" }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    public func info(_ path: String) async throws -> FileEntry {
        try JSONDecoder().decode(FileEntry.self, from: await operation("stat", path: path))
    }
    public func home() async throws -> String {
        let data = try await operation("home", path: "/")
        guard let path = String(data: data, encoding: .utf8), path.hasPrefix("/") else { throw Failure("Cannot determine home directory") }; return path
    }
    public func preview(_ path: String) async throws -> Data {
        let entry = try await info(path)
        guard entry.kind == "file" else { throw Failure("Directories and symbolic links cannot be previewed.") }
        guard entry.size <= Self.previewLimit else { throw Failure("Preview is limited to 2 MiB.") }
        let data = try await operation("read", path: path, count: Self.previewLimit + 1)
        guard data.count <= Self.previewLimit else { throw Failure("File grew beyond the 2 MiB preview limit.") }
        return data
    }
    public func transfer(_ source: String, to target: FileService, destination: String, conflict: FileConflict, progress: @escaping @Sendable (Int64, Int64) async -> Void = { _, _ in }) async throws -> String {
        let entry = try await info(source)
        guard entry.kind == "file" else { throw Failure("Select a single regular file. Directory and link transfer is not supported.") }
        let stage = destination + ".herdrx-" + UUID().uuidString + ".part"
        do {
            var offset: Int64 = 0
            _ = try await target.operation("create", path: stage)
            while offset < entry.size {
                try Task.checkCancellation()
                let chunk = try await operation("read", path: source, offset: offset, count: Int(min(131072, entry.size - offset)))
                guard !chunk.isEmpty else { throw Failure("Source changed during transfer.") }
                _ = try await target.operation("write", path: stage, offset: offset, bytes: chunk)
                offset += Int64(chunk.count); await progress(offset, entry.size)
            }
            try Task.checkCancellation()
            let current = try await info(source)
            guard current.size == entry.size, current.modified == entry.modified else { throw Failure("Source changed during transfer.") }
            let result = try await Task.detached { try await target.operation("commit", path: stage, destination: destination, conflict: conflict) }.value
            guard let final = String(data: result, encoding: .utf8) else { throw Failure("Invalid destination response") }
            await progress(offset, entry.size); return final
        } catch {
            _ = await Task.detached { try? await target.operation("remove", path: stage) }.value
            throw error
        }
    }
    private func operation(_ action: String, path: String, offset: Int64 = 0, count: Int = 0, bytes: Data = Data(), destination: String = "", conflict: FileConflict = .cancel) async throws -> Data {
        guard ["local", "ssh"].contains(endpoint.kind) else { throw Failure("File operations are not supported for this connection type.") }
        guard path.hasPrefix("/"), !path.contains("\0") else { throw Failure("Use an absolute path without NUL characters.") }
        if endpoint.kind == "local" {
            return try await Task.detached {
                let fm = FileManager.default, url = URL(fileURLWithPath: path)
                func stat(_ path: String) throws -> FileEntry {
                    let a = try fm.attributesOfItem(atPath: path)
                    let type = a[.type] as? FileAttributeType
                    return FileEntry(path: path, name: URL(fileURLWithPath: path).lastPathComponent, kind: type == .typeDirectory ? "directory" : type == .typeRegular ? "file" : type == .typeSymbolicLink ? "symlink" : "other", size: (a[.size] as? NSNumber)?.int64Value ?? 0, modified: (a[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
                }
                switch action {
                case "home": return Data(fm.homeDirectoryForCurrentUser.path.utf8)
                case "list": return try JSONEncoder().encode(fm.contentsOfDirectory(atPath: path).map { try stat(url.appendingPathComponent($0).path) })
                case "stat": return try JSONEncoder().encode(stat(path))
                case "read":
                    guard try stat(path).kind == "file" else { throw Failure("Only regular files can be read.") }
                    let fd = open(path, O_RDONLY | O_NOFOLLOW); guard fd >= 0 else { throw Failure("Cannot open file: \(String(cString: strerror(errno)))") }
                    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true); defer { try? file.close() }
                    try file.seek(toOffset: UInt64(offset)); return try file.read(upToCount: count) ?? Data()
                case "create":
                    let fd = open(path, O_CREAT | O_EXCL | O_WRONLY, 0o600); guard fd >= 0 else { throw Failure("Cannot create transfer staging file.") }; close(fd); return Data()
                case "write":
                    let fd = open(path, O_WRONLY | O_NOFOLLOW); guard fd >= 0 else { throw Failure("Cannot open staging file.") }
                    let file = FileHandle(fileDescriptor: fd, closeOnDealloc: true); defer { try? file.close() }; try file.seek(toOffset: UInt64(offset)); try file.write(contentsOf: bytes); return Data()
                case "remove": try fm.removeItem(atPath: path); return Data()
                case "commit":
                    var final = destination
                    if conflict == .replace {
                        if let existing = try? stat(final), existing.kind != "file" { throw Failure("Only an existing regular file can be replaced.") }
                        guard rename(path, final) == 0 else { throw Failure("Cannot replace destination.") }
                    } else {
                        var number = 1
                        while link(path, final) != 0 {
                            guard errno == EEXIST, conflict == .keepBoth else { throw Failure("Destination exists or cannot be created. Choose Replace or Keep Both.") }
                            let dest = URL(fileURLWithPath: destination); let ext = dest.pathExtension
                            final = dest.deletingPathExtension().path + " (\(number))" + (ext.isEmpty ? "" : "." + ext); number += 1
                        }
                        try fm.removeItem(atPath: path)
                    }
                    return Data(final.utf8)
                default: throw Failure("Unsupported file operation")
                }
            }.value
        }
        guard let host = endpoint.target, !host.isEmpty, !host.hasPrefix("-"), !host.contains(where: \.isWhitespace) else { throw Failure("Invalid SSH target") }
        let input = try JSONSerialization.data(withJSONObject: ["action": action, "path": path, "offset": offset, "count": count, "data": bytes.base64EncodedString(), "destination": destination, "conflict": conflict.rawValue])
        let command = "python3 -c " + shellQuote(Self.helper)
        return try await FileProcess.run("/usr/bin/ssh", (endpoint.sshConfig.map { ["-F", $0] } ?? []) + ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"] + (endpoint.port.map { ["-p", String($0)] } ?? []) + [host, command], input: input)
    }
    private static let helper = #"""
import os,sys,json,stat,base64
q=json.load(sys.stdin); p=q['path']; a=q['action']
def info(p):
 s=os.lstat(p); k='directory' if stat.S_ISDIR(s.st_mode) else 'file' if stat.S_ISREG(s.st_mode) else 'symlink' if stat.S_ISLNK(s.st_mode) else 'other'
 return dict(path=p,name=os.path.basename(p),kind=k,size=s.st_size,modified=s.st_mtime)
try:
 if a=='home': sys.stdout.write(os.path.expanduser('~'))
 elif a=='list': json.dump([info(os.path.join(p,n)) for n in os.listdir(p)],sys.stdout)
 elif a=='stat': json.dump(info(p),sys.stdout)
 elif a=='read':
  assert info(p)['kind']=='file','Only regular files can be read'
  with os.fdopen(os.open(p,os.O_RDONLY|os.O_NOFOLLOW),'rb') as f: f.seek(q['offset']); sys.stdout.buffer.write(f.read(q['count']))
 elif a=='create': os.close(os.open(p,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600))
 elif a=='write':
  with os.fdopen(os.open(p,os.O_WRONLY|os.O_NOFOLLOW),'r+b') as f: f.seek(q['offset']); f.write(base64.b64decode(q['data']))
 elif a=='remove': os.unlink(p)
 elif a=='commit':
  d=q['destination']; c=q['conflict']; final=d; n=1
  if c=='replace':
   assert not os.path.lexists(d) or info(d)['kind']=='file','Only regular files can be replaced'
   os.replace(p,d)
  else:
   while True:
    try: os.link(p,final); break
    except FileExistsError:
     if c!='keepBoth': raise Exception('Destination exists; choose Replace or Keep Both')
     stem,ext=os.path.splitext(d); final=stem+' ('+str(n)+')'+ext; n+=1
   os.unlink(p)
  sys.stdout.write(final)
except Exception as e:
 print(str(e),file=sys.stderr); sys.exit(1)
"""#
}
private func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

public final class FileProcess: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    private var cancelled = false
    func cancel() { lock.lock(); defer { lock.unlock() }; cancelled = true; if process.isRunning { process.terminate() } }
    public static func run(_ executable: String, _ arguments: [String], input: Data) async throws -> Data {
        let runner = FileProcess()
        return try await withTaskCancellationHandler {
            try await Task.detached { try runner.execute(executable, arguments, input: input) }.value
        } onCancel: { runner.cancel() }
    }
    private func execute(_ executable: String, _ arguments: [String], input: Data) throws -> Data {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("herdrx-file-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); defer { try? FileManager.default.removeItem(at: dir) }
        let inURL = dir.appendingPathComponent("in"), outURL = dir.appendingPathComponent("out"), errURL = dir.appendingPathComponent("err")
        try input.write(to: inURL); FileManager.default.createFile(atPath: outURL.path, contents: nil); FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let stdin = try FileHandle(forReadingFrom: inURL), stdout = try FileHandle(forWritingTo: outURL), stderr = try FileHandle(forWritingTo: errURL)
        defer { try? stdin.close(); try? stdout.close(); try? stderr.close() }
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments; process.standardInput = stdin; process.standardOutput = stdout; process.standardError = stderr
        lock.lock()
        if cancelled { lock.unlock(); throw CancellationError() }
        do { try process.run() } catch { lock.unlock(); throw error }; lock.unlock()
        process.waitUntilExit()
        lock.lock(); let wasCancelled = cancelled; lock.unlock()
        if wasCancelled { throw CancellationError() }
        guard process.terminationStatus == 0 else { throw Failure(String(decoding: try Data(contentsOf: errURL), as: UTF8.self)) }
        return try Data(contentsOf: outURL)
    }
}
